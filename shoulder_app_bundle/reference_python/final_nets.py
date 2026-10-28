"""final_nets: the per-exercise networks of the final notebook (InceptionTime, body-part network), copied unchanged
from its section 5.1, plus SepHead: one exercise as a stand-alone graph for the app (raw channels + raw features in,
probabilities out, the networks of all saved seeds averaged), with the same interface as the multi-task ONNX files.
"""
import json
import math
from pathlib import Path

import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F

import shoulder_ds as sds

T_LEN = 64


def conv_bn(cin, cout, k, drop=0.0):
    layers = [nn.Conv1d(cin, cout, k, padding=k // 2, bias=False), nn.BatchNorm1d(cout), nn.ReLU()]
    if drop:
        layers.append(nn.Dropout(drop))
    return nn.Sequential(*layers)


class Head(nn.Module):
    """Classifier head; optional side branch for the per-rep features (hybrid model)."""
    def __init__(self, d, n_cls, n_feat=0, p=0.3, ln=False):
        super().__init__()
        self.norm = nn.LayerNorm(d) if ln else nn.Identity()
        self.fmlp = nn.Sequential(nn.Dropout(0.2), nn.Linear(n_feat, 32), nn.GELU()) if n_feat else None
        self.emb_dim = d + (32 if n_feat else 0)
        self.out = nn.Sequential(nn.Dropout(p), nn.Linear(self.emb_dim, n_cls))

    def forward(self, e, f=None):
        e = self.norm(e)
        if self.fmlp is not None:
            e = torch.cat([e, self.fmlp(f)], 1)
        return self.out(e)


class SelfAttention(nn.Module):
    def __init__(self, d, heads=4, drop=0.1):
        super().__init__()
        self.h, self.dk = heads, d // heads
        self.qkv, self.proj, self.drop = nn.Linear(d, 3 * d), nn.Linear(d, d), nn.Dropout(drop)

    def forward(self, x):
        B, L, d = x.shape
        q, k, v = self.qkv(x).reshape(B, L, 3, self.h, self.dk).permute(2, 0, 3, 1, 4)
        att = torch.softmax(q @ k.transpose(-2, -1) / math.sqrt(self.dk), dim=-1)
        self.last_att = att.mean(1).detach()
        return self.proj((self.drop(att) @ v).transpose(1, 2).reshape(B, L, d))


class TBlock(nn.Module):
    """Pre-norm transformer block."""
    def __init__(self, d, heads=4, ff=128, drop=0.1):
        super().__init__()
        self.ln1, self.att, self.ln2 = nn.LayerNorm(d), SelfAttention(d, heads, drop), nn.LayerNorm(d)
        self.ff = nn.Sequential(nn.Linear(d, ff), nn.ReLU(), nn.Dropout(drop), nn.Linear(ff, d))
        self.drop = nn.Dropout(drop)

    def forward(self, x):
        x = x + self.drop(self.att(self.ln1(x)))
        return x + self.drop(self.ff(self.ln2(x)))


class InceptionModule(nn.Module):
    def __init__(self, cin, nf=32, ks=(5, 11, 23), bott=32):
        super().__init__()
        self.bott = nn.Conv1d(cin, bott, 1, bias=False) if cin > bott else nn.Identity()
        cb = bott if cin > bott else cin
        self.convs = nn.ModuleList([nn.Conv1d(cb, nf, k, padding=k // 2, bias=False) for k in ks])
        self.mp = nn.Sequential(nn.MaxPool1d(3, stride=1, padding=1), nn.Conv1d(cin, nf, 1, bias=False))
        self.bn = nn.BatchNorm1d(nf * (len(ks) + 1))

    def forward(self, x):
        b = self.bott(x)
        return F.relu(self.bn(torch.cat([c(b) for c in self.convs] + [self.mp(x)], 1)))


class InceptionTime(nn.Module):
    def __init__(self, c_in, n_cls, T=64, n_feat=0, depth=6, nf=32, **kw):
        super().__init__()
        mods, shorts, cin, res_in = [], [], c_in, c_in
        for i in range(depth):
            mods.append(InceptionModule(cin, nf))
            cin = nf * 4
            if i % 3 == 2:
                shorts.append(nn.Sequential(nn.Conv1d(res_in, cin, 1, bias=False), nn.BatchNorm1d(cin)))
                res_in = cin
        self.mods, self.shorts = nn.ModuleList(mods), nn.ModuleList(shorts)
        self.head = Head(cin, n_cls, n_feat)

    def forward(self, x, f=None):
        res, h, j = x, x, 0
        for i, m in enumerate(self.mods):
            h = m(h)
            if i % 3 == 2:
                h = F.relu(h + self.shorts[j](res))
                res, j = h, j + 1
        return self.head(h.mean(-1), f)


class PartNet(nn.Module):
    """Body-part attention network. parts = [(name, [input channel indices])]."""
    def __init__(self, c_in, n_cls, T=64, n_feat=0, parts=None, d=64, **kw):
        super().__init__()
        self.part_names = [p for p, _ in parts]
        self.part_idx = [list(idx) for _, idx in parts]
        self.enc = nn.ModuleList([nn.Sequential(conv_bn(len(idx), 48, 7, 0.1), conv_bn(48, d, 5)) for _, idx in parts])
        self.tatt = nn.ModuleList([nn.Conv1d(d, 1, 1) for _ in parts])
        self.part_emb = nn.Parameter(torch.zeros(1, len(parts), d))
        self.cls = nn.Parameter(torch.zeros(1, 1, d))
        nn.init.trunc_normal_(self.part_emb, std=0.02)
        self.blocks = nn.Sequential(TBlock(d), TBlock(d))
        self.head = Head(d, n_cls, n_feat, p=0.2, ln=True)

    def forward(self, x, f=None):
        toks, tws = [], []
        for idx, enc, ta in zip(self.part_idx, self.enc, self.tatt):
            h = enc(x[:, idx])
            w = torch.softmax(ta(h).squeeze(1), dim=-1)
            tws.append(w.detach())
            toks.append((h * w.unsqueeze(1)).sum(-1))
        z = torch.stack(toks, 1) + self.part_emb
        z = self.blocks(torch.cat([self.cls.expand(z.shape[0], -1, -1), z], 1))
        self.last_part_att = self.blocks[-1].att.last_att[:, 0, 1:]
        self.last_time_att = torch.stack(tws, 1)
        return self.head(z[:, 0], f)


MODEL_ZOO = {"inception": InceptionTime, "partnet": PartNet}
PART_ORDER = ["arm", "other_arm", "shoulder_head", "trunk"]


def make_parts(in_names):
    t_idx = [i for i, n in enumerate(in_names) if sds.part_of(n) == "time"]
    parts = []
    for p in PART_ORDER:
        idx = [i for i, n in enumerate(in_names) if sds.part_of(n) == p]
        if idx:
            parts.append((p, idx + t_idx))
    return parts


def make_model(cfg, in_names, K, n_feat):
    parts = make_parts(in_names) if cfg["arch"] == "partnet" else None
    return MODEL_ZOO[cfg["arch"]](len(in_names), K, T_LEN, n_feat=n_feat if cfg.get("feat") else 0, parts=parts)


def load_checkpoint(path, device="cpu"):
    try:
        return torch.load(path, map_location=device, weights_only=False)
    except TypeError:
        return torch.load(path, map_location=device)


class SepHead(nn.Module):
    """Raw stored channels x (B, C_sel, T) and raw features f (B, F) -> probabilities, averaged over the saved
    networks (seeds). Same steps as the final notebook's make_batch(train=False) + predict."""
    def __init__(self, ck, n_nets=None):
        super().__init__()
        s, cfg = ck["stats"], ck["cfg"]
        states = ck["states"][:n_nets] if n_nets else ck["states"]
        nets = []
        for st in states:
            net = make_model(cfg, s["in_names"], ck["K"], s["n_feat"])
            net.load_state_dict(st)
            nets.append(net.eval())
        self.nets = nn.ModuleList(nets)
        f32 = lambda v: torch.tensor(np.asarray(v, np.float32))
        self.register_buffer("mu", f32(s["mu"]).view(1, -1, 1))
        self.register_buffer("sd", f32(s["sd"]).view(1, -1, 1))
        self.has_vel = bool(s.get("vel"))
        if self.has_vel:
            self.register_buffer("vel", torch.tensor(s["vel"], dtype=torch.long))
            self.register_buffer("mu_v", f32(s["mu_v"]).view(1, -1, 1))
            self.register_buffer("sd_v", f32(s["sd_v"]).view(1, -1, 1))
        self.has_feat = bool(cfg.get("feat")) and int(s.get("n_feat") or 0) > 0
        if self.has_feat:
            self.register_buffer("mu_f", f32(s["mu_f"]).view(1, -1))
            self.register_buffer("sd_f", f32(s["sd_f"]).view(1, -1))

    def forward(self, x, f=None):
        x = (x - self.mu) / self.sd
        if self.has_vel:
            xv = torch.index_select(x, 1, self.vel)
            v = xv - torch.cat([xv[:, :, :1], xv[:, :, :-1]], -1)
            x = torch.cat([x, (v - self.mu_v) / self.sd_v], 1)
        if self.has_feat:
            f = (f - self.mu_f) / self.sd_f
            f = torch.where(torch.isnan(f), torch.zeros_like(f), f).clamp(-6.0, 6.0)
        else:
            f = None
        ps = [torch.softmax(net(x, f), dim=1) for net in self.nets]
        out = ps[0]
        for p in ps[1:]:
            out = out + p
        return out / len(ps)


def head_description(ck, classes, stored_channels, all_features, onnx_file, name):
    """The per-exercise entry of models/separate.json (same keys as mt_final.json heads)."""
    s, cfg = ck["stats"], ck["cfg"]
    fsel = s.get("fsel", list(range(int(s.get("n_feat") or 0))))
    fnames = s.get("fnames") or [all_features[j] for j in fsel]
    has_feat = bool(cfg.get("feat")) and int(s.get("n_feat") or 0) > 0
    in_names = list(s["in_names"])
    return dict(name=name, classes=list(classes), stored_channels=list(stored_channels), input_selection=list(s["sel"]),
                input_channels=in_names, velocity_of=list(s.get("vel") or []), features=list(fnames) if has_feat else [],
                use_features=has_feat, onnx_file=onnx_file, networks=len(ck["states"]), arch=cfg["arch"],
                needs_silhouette=bool(any("sil" in n for n in in_names) or any("sil" in n for n in (fnames if has_feat else []))),
                recipe=cfg)
