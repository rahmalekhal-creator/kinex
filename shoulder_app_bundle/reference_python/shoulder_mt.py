"""shoulder_mt (Step 3): ONE network shared by the three shoulder exercises, one head per exercise.

    net = MTNet(spec, tinfo)                 # tinfo: one dict per head (classes, channels, features, body parts)
    logits = net.forward_task(t, x, f)       # one exercise: x (B, C_t, T) normalised channels, f (B, F_t) features
    head = ExportHead(net, t, stats)         # stand-alone graph for the app: raw channels + raw features -> probabilities
    pred = MTPredictor(model_dir)            # loads models/mt_final.json + .pt; predict_proba(analyze_video output, "e2")
"""
import json
import math
import time
from pathlib import Path

import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F

PART_ORDER = ["arm", "other_arm", "shoulder_head", "trunk"]


def conv_bn(cin, cout, k, drop=0.0):
    layers = [nn.Conv1d(cin, cout, k, padding=k // 2, bias=False), nn.BatchNorm1d(cout), nn.ReLU()]
    if drop:
        layers.append(nn.Dropout(drop))
    return nn.Sequential(*layers)


class FiLM(nn.Module):
    """Per-exercise scale and shift of a feature map (starts as the identity)."""
    def __init__(self, n_tasks, ch):
        super().__init__()
        self.ch = ch
        self.emb = nn.Embedding(n_tasks, 2 * ch)
        nn.init.zeros_(self.emb.weight)

    def forward(self, h, tid):
        p = self.emb.weight[tid].unsqueeze(0) if isinstance(tid, int) else self.emb(tid)
        return h * (1 + p[:, :self.ch].unsqueeze(-1)) + p[:, self.ch:].unsqueeze(-1)


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


class IncTrunk(nn.Module):
    """InceptionTime encoder (6 modules, 2 residual shortcuts), as the final notebook's InceptionTime."""
    def __init__(self, c_in, n_tasks, film=False, depth=6, nf=32, **kw):
        super().__init__()
        mods, shorts, cin, res_in = [], [], c_in, c_in
        for i in range(depth):
            mods.append(InceptionModule(cin, nf))
            cin = nf * 4
            if i % 3 == 2:
                shorts.append(nn.Sequential(nn.Conv1d(res_in, cin, 1, bias=False), nn.BatchNorm1d(cin)))
                res_in = cin
        self.mods, self.shorts = nn.ModuleList(mods), nn.ModuleList(shorts)
        self.film = nn.ModuleList([FiLM(n_tasks, cin) for _ in range(depth)]) if film else None
        self.out_ch = cin

    def forward(self, h, tid):
        res, j = h, 0
        for i, m in enumerate(self.mods):
            h = m(h)
            if self.film is not None:
                h = self.film[i](h, tid)
            if i % 3 == 2:
                h = F.relu(h + self.shorts[j](res))
                res, j = h, j + 1
        return h


class DSBlock(nn.Module):
    """Depthwise-separable residual block: per-channel dilated convolution, then 1x1 mixing."""
    def __init__(self, ch, k=9, dil=1, drop=0.1):
        super().__init__()
        self.dw = nn.Conv1d(ch, ch, k, padding=dil * (k - 1) // 2, dilation=dil, groups=ch, bias=False)
        self.bn1 = nn.BatchNorm1d(ch)
        self.pw = nn.Conv1d(ch, ch, 1, bias=False)
        self.bn2 = nn.BatchNorm1d(ch)
        self.drop = nn.Dropout(drop)

    def forward(self, x):
        h = F.relu(self.bn1(self.dw(x)))
        return F.relu(x + self.drop(self.bn2(self.pw(h))))


class TCNTrunk(nn.Module):
    """Light temporal CNN: 1x1 stem + 6 depthwise-separable blocks (dilations 1-8; sees the whole 64-frame window)."""
    def __init__(self, c_in, n_tasks, film=False, width=64, dilations=(1, 2, 4, 8, 1, 2), k=9, **kw):
        super().__init__()
        self.stem = nn.Sequential(nn.Conv1d(c_in, width, 1, bias=False), nn.BatchNorm1d(width), nn.ReLU())
        self.blocks = nn.ModuleList([DSBlock(width, k, d) for d in dilations])
        self.film = nn.ModuleList([FiLM(n_tasks, width) for _ in dilations]) if film else None
        self.out_ch = width

    def forward(self, h, tid):
        h = self.stem(h)
        for i, b in enumerate(self.blocks):
            h = b(h)
            if self.film is not None:
                h = self.film[i](h, tid)
        return h


class GRUTrunk(nn.Module):
    def __init__(self, c_in, n_tasks, film=False, width=64, **kw):
        super().__init__()
        self.stem = nn.Sequential(nn.Conv1d(c_in, width, 1, bias=False), nn.BatchNorm1d(width), nn.ReLU())
        self.film = FiLM(n_tasks, width) if film else None
        self.gru = nn.GRU(width, width, batch_first=True, bidirectional=True)
        self.out_ch = 2 * width

    def forward(self, h, tid):
        h = self.stem(h)
        if self.film is not None:
            h = self.film(h, tid)
        o, _ = self.gru(h.transpose(1, 2))
        return o.transpose(1, 2)


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
    def __init__(self, d, heads=4, ff=128, drop=0.1):
        super().__init__()
        self.ln1, self.att, self.ln2 = nn.LayerNorm(d), SelfAttention(d, heads, drop), nn.LayerNorm(d)
        self.ff = nn.Sequential(nn.Linear(d, ff), nn.ReLU(), nn.Dropout(drop), nn.Linear(ff, d))
        self.drop = nn.Dropout(drop)

    def forward(self, x):
        x = x + self.drop(self.att(self.ln1(x)))
        return x + self.drop(self.ff(self.ln2(x)))


class PartTrunk(nn.Module):
    """Body-part tokens shared across exercises: per (exercise, part) a 1x1 adapter, then ONE encoder per body part
    shared by all exercises, temporal attention inside each part, and self-attention across the parts."""
    def __init__(self, task_parts, n_tasks, film=False, d=64, a=32, **kw):
        super().__init__()
        self.task_parts = [{p: list(idx) for p, idx in tp.items()} for tp in task_parts]
        self.adapt = nn.ModuleDict({f"t{t}_{p}": nn.Conv1d(len(idx), a, 1) for t, tp in enumerate(self.task_parts)
                                    for p, idx in tp.items()})
        for t, tp in enumerate(self.task_parts):
            for p, idx in tp.items():
                self.register_buffer(f"idx_t{t}_{p}", torch.tensor(idx, dtype=torch.long))
        used = [p for p in PART_ORDER if any(p in tp for tp in self.task_parts)]
        self.enc = nn.ModuleDict({p: nn.Sequential(conv_bn(a, 48, 7, 0.1), conv_bn(48, d, 5)) for p in used})
        self.tatt = nn.ModuleDict({p: nn.Conv1d(d, 1, 1) for p in used})
        self.empty = nn.Parameter(torch.zeros(len(PART_ORDER), d))
        self.part_emb = nn.Parameter(torch.zeros(1, len(PART_ORDER), d))
        self.cls = nn.Parameter(torch.zeros(1, 1, d))
        nn.init.trunc_normal_(self.part_emb, std=0.02)
        self.task_emb = nn.Embedding(n_tasks, d) if film else None
        if film:
            nn.init.zeros_(self.task_emb.weight)
        self.blocks = nn.Sequential(TBlock(d), TBlock(d))
        self.out_ch, self.d = d, d

    def forward(self, xs):
        """xs: {task index: (B_t, C_t, T)} -> {task index: (B_t, 1 + parts, d)} tokens (CLS first)."""
        tasks = sorted(xs)
        sizes = [xs[t].shape[0] for t in tasks]
        T = xs[tasks[0]].shape[-1]
        tok = {t: [None] * len(PART_ORDER) for t in tasks}
        tw = {t: [None] * len(PART_ORDER) for t in tasks}
        for k, p in enumerate(PART_ORDER):
            have = [t for t in tasks if p in self.task_parts[t]]
            if not have:
                continue
            h = torch.cat([self.adapt[f"t{t}_{p}"](torch.index_select(xs[t], 1, getattr(self, f"idx_t{t}_{p}"))) for t in have], 0)
            h = self.enc[p](h)
            w = torch.softmax(self.tatt[p](h).squeeze(1), dim=-1)
            z = (h * w.unsqueeze(1)).sum(-1)
            if len(have) == 1:                         # one exercise (prediction, export): no split needed
                tok[have[0]][k], tw[have[0]][k] = z, w
            else:
                nb = [xs[t].shape[0] for t in have]
                for t, zt, wt in zip(have, torch.split(z, nb, 0), torch.split(w, nb, 0)):
                    tok[t][k], tw[t][k] = zt, wt
        out, atts = [], []
        for t, B in zip(tasks, sizes):
            ref = next(v for v in tok[t] if v is not None)
            toks = [v if v is not None else self.empty[k].unsqueeze(0).expand(B, -1) for k, v in enumerate(tok[t])]
            out.append(torch.stack(toks, 1))
            atts.append(torch.stack([v if v is not None else torch.zeros(B, T, device=ref.device) for v in tw[t]], 1))
        z = torch.cat(out, 0) + self.part_emb
        z = torch.cat([self.cls.expand(z.shape[0], -1, -1), z], 1)
        if self.task_emb is not None:
            if len(tasks) == 1:
                z = z + self.task_emb.weight[tasks[0]].view(1, 1, -1)
            else:
                tid = torch.cat([torch.full((B,), t, dtype=torch.long, device=z.device) for t, B in zip(tasks, sizes)])
                z = z + self.task_emb(tid).unsqueeze(1)
        z = self.blocks(z)
        self.last_part_att = self.blocks[-1].att.last_att[:, 0, 1:]
        self.last_time_att = torch.cat(atts, 0).detach()
        return {tasks[0]: z} if len(tasks) == 1 else dict(zip(tasks, torch.split(z, sizes, 0)))


class QueryPool(nn.Module):
    """Per-exercise attention over the part tokens (partnet with pool='att')."""
    def __init__(self, d):
        super().__init__()
        self.q = nn.Parameter(torch.zeros(d))

    def forward(self, z):
        w = torch.softmax((z * self.q).sum(-1) / math.sqrt(z.shape[-1]), dim=-1)
        return (z * w.unsqueeze(-1)).sum(1)


class MTHead(nn.Module):
    """Head of one exercise: [embedding, per-rep feature branch] -> classes."""
    def __init__(self, d, K, n_feat, kind="linear", feat="head", ln=False, p=0.3):
        super().__init__()
        self.norm = nn.LayerNorm(d) if ln else nn.Identity()
        self.n_feat = n_feat if feat != "none" else 0
        if self.n_feat:
            layers = [nn.Dropout(0.2), nn.Linear(n_feat, 32)] + ([nn.GELU()] if feat == "head" else [])
            self.fin = nn.Sequential(*layers)
        e = d + (32 if self.n_feat else 0)
        self.rep_dim = e
        if kind == "mlp":
            self.out = nn.Sequential(nn.Dropout(p), nn.Linear(e, 64), nn.GELU(), nn.Dropout(p), nn.Linear(64, K))
        else:
            self.out = nn.Sequential(nn.Dropout(p), nn.Linear(e, K))

    def represent(self, e, f=None, shared=None):
        e = self.norm(e)
        if self.n_feat:
            h = self.fin(f)
            if shared is not None:
                h = shared(h)
            e = torch.cat([e, h], 1)
        return e

    def forward(self, e, f=None, shared=None):
        return self.out(self.represent(e, f, shared))


class MTNet(nn.Module):
    """tinfo: one dict per head: name, K (classes), c_in (input channels incl. velocities), n_feat (per-rep features),
    parts ({body part: channel indices}), map_idx / n_map (common: positions of the common channels in this head's
    input; union: position of each of this head's channels in the union)."""
    def __init__(self, spec, tinfo):
        super().__init__()
        self.spec = dict(spec)
        self.n_tasks = len(tinfo)
        self.names = [ti["name"] for ti in tinfo]
        self.arch, self.inp = spec["arch"], spec["inp"]
        film = spec.get("cond") == "film"
        if self.arch == "partnet":
            self.trunk = PartTrunk([ti["parts"] for ti in tinfo], self.n_tasks, film, d=spec.get("width", 64))
        else:
            if self.inp == "adapter":
                d_in = spec.get("adapter_dim", 64)
                self.adapt = nn.ModuleList([nn.Conv1d(ti["c_in"], d_in, 1) for ti in tinfo])
            else:
                n_map = tinfo[0]["n_map"]
                for t, ti in enumerate(tinfo):
                    M = torch.zeros(n_map, ti["c_in"])
                    if self.inp == "common":
                        for r, c in enumerate(ti["map_idx"]):
                            M[r, c] = 1.0
                    else:
                        for c, r in enumerate(ti["map_idx"]):
                            M[r, c] = 1.0
                    self.register_buffer(f"sel{t}", M)
                self.register_buffer("onehot", torch.eye(self.n_tasks))
                d_in = n_map + (self.n_tasks if self.inp == "union" else 0)
            Trunk = {"inception": IncTrunk, "tcn": TCNTrunk, "gru": GRUTrunk}[self.arch]
            self.trunk = Trunk(d_in, self.n_tasks, film, width=spec.get("width", 64))
        C = self.trunk.out_ch
        self.emb_dim = C
        if spec.get("pool") == "att":
            self.pool_att = nn.ModuleList([QueryPool(C) if self.arch == "partnet" else nn.Conv1d(C, 1, 1) for _ in tinfo])
        feat = spec.get("feat", "head")
        self.fshared = nn.Sequential(nn.GELU(), nn.Linear(32, 32), nn.GELU()) if feat == "shared" else None
        self.heads = nn.ModuleList([MTHead(C, ti["K"], ti["n_feat"], spec.get("head", "linear"), feat, ln=self.arch == "partnet")
                                    for ti in tinfo])
        if spec.get("ssl_epochs", 0) and self.arch != "partnet":
            self.dec = nn.ModuleList([nn.Conv1d(C, ti["c_in"], 1) for ti in tinfo])

    # ---- encoder input of one head
    def _in(self, t, x):
        if self.inp == "adapter":
            return self.adapt[t](x)
        z = torch.matmul(getattr(self, f"sel{t}"), x)
        if self.inp == "union":
            z = torch.cat([z, self.onehot[t].view(1, -1, 1).expand(x.shape[0], -1, x.shape[-1])], 1)
        return z

    def features(self, xs):
        """Time-resolved encoder output {t: (B_t, C, T)} (inception / tcn / gru)."""
        tasks = sorted(xs)
        hs = [self._in(t, xs[t]) for t in tasks]
        if len(tasks) == 1:
            return {tasks[0]: self.trunk(hs[0], tasks[0])}
        tid = torch.cat([torch.full((h.shape[0],), t, dtype=torch.long, device=h.device) for t, h in zip(tasks, hs)])
        fm = self.trunk(torch.cat(hs, 0), tid)
        return dict(zip(tasks, torch.split(fm, [h.shape[0] for h in hs], 0)))

    def embed(self, xs):
        att = self.spec.get("pool") == "att"
        if self.arch == "partnet":
            z = self.trunk(xs)
            return {t: (self.pool_att[t](zt[:, 1:]) if att else zt[:, 0]) for t, zt in z.items()}
        out = {}
        for t, h in self.features(xs).items():
            if att:
                w = torch.softmax(self.pool_att[t](h).squeeze(1), dim=-1)
                out[t] = (h * w.unsqueeze(1)).sum(-1)
            else:
                out[t] = h.mean(-1)
        return out

    def forward(self, xs, fs=None):
        fs = fs or {}
        return {t: self.heads[t](e, fs.get(t), self.fshared) for t, e in self.embed(xs).items()}

    def forward_task(self, t, x, f=None):
        return self.forward({t: x}, {t: f})[t]

    def represent(self, t, x, f=None):
        """What the head of exercise t sees (embedding + feature branch): used for the classical heads on top."""
        return self.heads[t].represent(self.embed({t: x})[t], f, self.fshared)

    # ---- parameters of one head vs shared (fine-tuning, size per exercise)
    def task_param_names(self, t):
        pre = (f"heads.{t}.", f"adapt.{t}.", f"pool_att.{t}.", f"dec.{t}.", f"trunk.adapt.t{t}_")
        return {n for n, _ in self.named_parameters() if n.startswith(pre)}

    def shared_param_names(self):
        task = set().union(*[self.task_param_names(t) for t in range(self.n_tasks)])
        return {n for n, _ in self.named_parameters() if n not in task}

    def set_shared_eval(self):
        """Fine-tuning: keep the shared encoder fixed (its batch-norm statistics too)."""
        self.trunk.eval()
        if self.fshared is not None:
            self.fshared.eval()
        if self.arch == "partnet":                     # the per-exercise adapters inside the part encoder keep training
            self.trunk.adapt.train()


def count_params(net, t=None):
    """Weights of the whole network, or of what the app needs for exercise t (shared part + that head)."""
    names = net.shared_param_names() | net.task_param_names(t) if t is not None else {n for n, _ in net.named_parameters()}
    return int(sum(p.numel() for n, p in net.named_parameters() if n in names and not n.startswith("dec.")))


class ExportHead(nn.Module):
    """One exercise as a stand-alone graph for the app: raw stored channels (B, C_sel, T) and raw per-rep features
    (B, F) in, class probabilities out. Normalisation, velocity channels and missing features (NaN) are handled inside,
    exactly as in training."""
    def __init__(self, net, t, stats):
        super().__init__()
        self.net, self.t = net, t
        f32 = lambda v: torch.tensor(np.asarray(v, np.float32))
        self.register_buffer("mu", f32(stats["mu"]).view(1, -1, 1))
        self.register_buffer("sd", f32(stats["sd"]).view(1, -1, 1))
        self.has_vel = bool(stats.get("vel"))
        if self.has_vel:
            self.register_buffer("vel", torch.tensor(stats["vel"], dtype=torch.long))
            self.register_buffer("mu_v", f32(stats["mu_v"]).view(1, -1, 1))
            self.register_buffer("sd_v", f32(stats["sd_v"]).view(1, -1, 1))
        self.has_feat = bool(stats.get("use_feat")) and len(stats.get("mu_f", [])) > 0
        if self.has_feat:
            self.register_buffer("mu_f", f32(stats["mu_f"]).view(1, -1))
            self.register_buffer("sd_f", f32(stats["sd_f"]).view(1, -1))

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
        return torch.softmax(self.net.forward_task(self.t, x, f), dim=1)


def build_net(ck, device="cpu"):
    nets = []
    for st in ck["states"]:
        net = MTNet(ck["spec"], ck["tinfo"])
        net.load_state_dict(st)
        nets.append(net.to(device).eval())
    return nets


class MTPredictor:
    """Loads models/mt_final.json + mt_final.pt and predicts per-rep class probabilities for the output of
    shoulder_ds.analyze_video(...) of any of the three exercises."""
    def __init__(self, model_dir, device="cpu", name="mt_final"):
        model_dir = Path(model_dir)
        self.cfg = json.loads((model_dir / f"{name}.json").read_text())
        try:
            ck = torch.load(model_dir / self.cfg["weights_file"], map_location=device, weights_only=False)
        except TypeError:
            ck = torch.load(model_dir / self.cfg["weights_file"], map_location=device)
        self.device, self.tasks, self.stats = device, ck["tasks"], ck["stats"]
        self.nets = build_net(ck, device)
        self.heads = {ex: [ExportHead(n, t, ck["stats"][ex]).to(device).eval() for n in self.nets] for t, ex in enumerate(self.tasks)}
        self.tta = bool(self.cfg.get("tta", False))
        self.n_geo = int(self.cfg["analyze_video"]["N_GEO"]) if self.tta else 0
        self.model_name = self.cfg.get("name", "multi-task network")

    def classes(self, ex):
        return self.cfg["heads"][ex]["classes"]

    def inputs(self, out, ex, g=0):
        st = self.stats[ex]
        X = np.asarray(out["X"][g, 0], np.float32)[:, st["sel"]]
        x = X.astype(np.float16).astype(np.float32)               # training data were stored as float16
        raw, F_ = out["feature_names"], np.asarray(out["F"][g, 0], np.float32)
        f = np.full((len(F_), len(st["fnames"])), np.nan, np.float32)
        for j, n in enumerate(st["fnames"]):
            if n in raw:
                f[:, j] = F_[:, raw.index(n)]
        return x, f

    @torch.no_grad()
    def predict_proba(self, out, ex):
        G = out["X"].shape[0] if self.tta else 1
        ps = []
        for g in range(G):
            x, f = self.inputs(out, ex, g)
            xt, ft = torch.from_numpy(x).to(self.device), torch.from_numpy(f).to(self.device)
            ps += [h(xt, ft).float().cpu().numpy() for h in self.heads[ex]]
        return np.mean(ps, 0)


# ---- the final notebook's networks (only to measure their size and speed in section 8)
class FinalHead(nn.Module):
    def __init__(self, d, n_cls, n_feat=0, p=0.3, ln=False):
        super().__init__()
        self.norm = nn.LayerNorm(d) if ln else nn.Identity()
        self.fmlp = nn.Sequential(nn.Dropout(0.2), nn.Linear(n_feat, 32), nn.GELU()) if n_feat else None
        self.out = nn.Sequential(nn.Dropout(p), nn.Linear(d + (32 if n_feat else 0), n_cls))

    def forward(self, e, f=None):
        e = self.norm(e)
        if self.fmlp is not None:
            e = torch.cat([e, self.fmlp(f)], 1)
        return self.out(e)


class FinalInceptionTime(nn.Module):
    def __init__(self, c_in, n_cls, n_feat=0):
        super().__init__()
        self.trunk = IncTrunk(c_in, 1)
        self.head = FinalHead(self.trunk.out_ch, n_cls, n_feat)

    def forward(self, x, f=None):
        return self.head(self.trunk(x, 0).mean(-1), f)


class FinalPartNet(nn.Module):
    def __init__(self, parts, n_cls, n_feat=0, d=64):
        super().__init__()
        self.trunk = PartTrunk([parts], 1, False, d=d)
        self.head = FinalHead(d, n_cls, n_feat, p=0.2, ln=True)

    def forward(self, x, f=None):
        return self.head(self.trunk({0: x})[0][:, 0], f)


@torch.no_grad()
def cpu_ms(module, args, n=30, threads=1):
    """Median time of one forward pass on the CPU (ms)."""
    old = torch.get_num_threads()
    torch.set_num_threads(threads)
    try:
        module.eval()
        for _ in range(3):
            module(*args)
        ts = []
        for _ in range(n):
            t0 = time.perf_counter()
            module(*args)
            ts.append(time.perf_counter() - t0)
        return 1000 * float(np.median(ts))
    finally:
        torch.set_num_threads(old)
