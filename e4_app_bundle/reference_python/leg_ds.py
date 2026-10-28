"""leg_ds: exercise 4 (standing hip abduction, a LEG exercise) - from one pose file to per-rep samples, with the SAME
sample format as shoulder_ds.analyze_video, so every model of the earlier notebooks (and the joint network) can read it:

    import leg_ds as lds
    out = lds.analyze_video(sl.load_npz(path), side="left", seg_cfg=dict(min_rep_s=0.6), n_geo=3, key="e4_good_p05_left")
    out["X"]   (G, R, n, C, T) float32: G pose versions (0 = as recorded, 1.. = geometric augmentations), R range versions
               (0 = full range, 1.. = the top of the lift cut: a smaller movement, as an early-rehab patient makes it),
               n reps, C channels, T frames
    out["F"]   (G, R, n, F) per-rep measures
    out["rows"] one dict per rep (also partial / unusable ones)

'side' = the LIFTED leg (anatomical). Everything is mirrored so the lifted leg is always on the same side, so left and right
videos are comparable. Suffix _a = lifted leg (the working limb), _o = standing leg.
All channel and measure names start with 'g4_' (except log_duration); their body part is given by part_of() / part_of_feature():
  'arm'           -> the lifted leg (the working limb; the name is shared with the shoulder heads of the joint network)
  'other_arm'     -> the standing leg
  'shoulder_head' -> upper body (head, shoulders, hands on the chair / hip)
  'trunk'         -> trunk and pelvis (lean, pelvis tilt)
"""
import numpy as np

import shoulder_lib as sl
import shoulder_ds as sds

# MediaPipe ids ('left' = the person's left)
NOSE = 0
LEG = {"left": dict(hip=23, knee=25, ank=27, heel=29, foot=31, sh=11, wr=15),
       "right": dict(hip=24, knee=26, ank=28, heel=30, foot=32, sh=12, wr=16)}
OTHER = {"left": "right", "right": "left"}
COUNT_SIGNAL = "abd_leg_a"            # leg (hip -> ankle) away from the body axis: one rise and fall per rep

POINTS = ["nose", "sh_a", "sh_o", "wr_a", "wr_o", "hip_a", "hip_o", "knee_a", "knee_o", "ank_a", "ank_o", "foot_a", "foot_o"]
ANGLES = ["abd_leg_a", "abd_thigh_a", "abd_leg_o", "knee2d_a", "knee2d_o", "knee3d_a", "knee3d_o", "lean_to_leg",
          "pelvis_tilt", "sh_tilt", "ank_h_a", "ank_lat_a", "foot_sep", "head_lat", "trunk_shift"]
DEPTH = ["knee_dz_a", "ank_dz_a", "abd3d_a", "lean3d"]
BASE_POINTS = ["nose", "sh_a", "sh_o", "hip_a", "hip_o"]
BASE_ANGLES = ["lean_to_leg", "pelvis_tilt", "sh_tilt", "knee2d_a", "knee2d_o", "abd_leg_a", "head_lat"]
DEG = {"abd_leg_a", "abd_thigh_a", "abd_leg_o", "knee2d_a", "knee2d_o", "knee3d_a", "knee3d_o", "lean_to_leg",
       "pelvis_tilt", "sh_tilt", "abd3d_a", "lean3d"}          # stored / 90
TRUNK = ("lean", "pelvis", "sh_tilt", "head_lat", "trunk_shift", "hip_a", "hip_o")
UPPER = ("nose", "sh_a", "sh_o", "wr_a", "wr_o")
OTHER_LEG = ("knee_o", "ank_o", "foot_o", "knee2d_o", "knee3d_o", "abd_leg_o")
TIME = {"duration_s", "up_s", "down_s", "up_ratio", "amp", "valid_frac"}
GROUP_ORDER = ["coords", "angles", "depth", "base_pts", "base_ang", "shld", "gap", "base_new", "sil", "gated", "dur"]


def g4(n):
    return f"g4_{n}"


def channel_groups(ex="e4"):
    """Same group keys as shoulder_ds.channel_groups (empty where the leg has nothing comparable)."""
    return {"coords": [g4(f"{p}_{ax}") for p in POINTS for ax in "xy"],
            "angles": [g4(k) for k in ANGLES],
            "depth": [g4(k) for k in DEPTH],
            "base_pts": [g4(f"{p}_{ax}_rel") for p in BASE_POINTS for ax in "xy"],
            "base_ang": [g4(f"{k}_rel") for k in BASE_ANGLES],
            "shld": [], "gap": [], "base_new": [], "sil": [], "gated": [],
            "dur": ["log_duration"]}


def channel_names(ex="e4"):
    g = channel_groups(ex)
    return [c for name in GROUP_ORDER for c in g[name]]


def _core(name):
    n = name[2:] if name.startswith("d_") else name
    n = n[3:] if n.startswith("g4_") else n
    if n.startswith("ph_"):
        n = n.split("_", 3)[-1]
    for suf in ("_rel", "_d0"):
        if n.endswith(suf):
            n = n[: -len(suf)]
    return n


def is_leg_name(name):
    return name.startswith(("g4_", "d_g4_"))


def leg_part(name):
    n = _core(name)
    if n in TIME:
        return "time"
    if n.startswith(TRUNK):
        return "trunk"
    if n.startswith(UPPER):
        return "shoulder_head"
    if n.startswith(OTHER_LEG):
        return "other_arm"
    return "arm"


PART_LABEL = {"arm": "lifted leg", "other_arm": "standing leg", "shoulder_head": "upper body", "trunk": "trunk + pelvis",
              "time": "time"}


def install_part_names():
    """Teach shoulder_ds the body parts of the leg channels / measures (joint network, occlusion test)."""
    if getattr(sds, "_leg_parts_installed", False):
        return
    po, pf = sds.part_of, sds.part_of_feature
    sds.part_of = lambda n: leg_part(n) if is_leg_name(n) else po(n)
    sds.part_of_feature = lambda n: leg_part(n) if is_leg_name(n) else pf(n)
    sds._leg_parts_installed = True


# ----------------------------------------------------------------------------- helpers
def _unit(v):
    n = np.linalg.norm(v, axis=-1, keepdims=True)
    return v / np.where(n > 1e-9, n, np.nan)


def _nanmed(x):
    x = np.asarray(x, float)
    return float(np.nanmedian(x)) if np.isfinite(x).any() else float("nan")


def _nanmin(x):
    x = np.asarray(x, float)
    return float(np.nanmin(x)) if np.isfinite(x).any() else float("nan")


def _nanmax(x):
    x = np.asarray(x, float)
    return float(np.nanmax(x)) if np.isfinite(x).any() else float("nan")


def _nanmean(x):
    x = np.asarray(x, float)
    return float(np.nanmean(x)) if np.isfinite(x).any() else float("nan")


def _signed_angle(v, ref_down, ref_out):
    """Angle (deg) of v away from ref_down, + toward ref_out (all (T, 2))."""
    return np.degrees(np.arctan2((v * ref_out).sum(1), (v * ref_down).sum(1)))


# ----------------------------------------------------------------------------- quality and side
def leg_quality(d):
    lm, meta = d["lm"], d.get("meta", {})
    det = np.isfinite(lm[:, 0, 0])
    q = dict(frames=int(len(lm)), detect_rate=float(det.mean()) if len(lm) else float("nan"))
    if det.sum() < 3:
        return q
    L = lm[det]
    legs = [25, 26, 27, 28]
    q["vis_legs_mean"] = float(np.nanmean(L[:, legs, 3]))
    xy = L[:, legs, :2]
    q["leg_out_of_frame"] = float(((xy < 0) | (xy > 1)).any(axis=(1, 2)).mean())
    W, H = float(meta.get("width") or 1.0), float(meta.get("height") or 1.0)
    P = L[:, :, :2] * np.array([W, H], np.float32)
    TL = sl.torso_len(P)
    an = P[:, [27, 28]]
    acc = np.linalg.norm(an[2:] - 2 * an[1:-1] + an[:-2], axis=-1).max(axis=1)
    q["jitter_pct"] = 100 * _nanmed(acc) / TL if TL and TL > 0 else float("nan")
    q["torso_frac_h"] = TL / H
    npz = np.asarray(d.get("n_poses", np.ones(len(lm))))
    q["multi_person_frac"] = float((npz > 1).mean())
    return q


def choose_leg(r, side=None):
    """The lifted leg = the ankle that moves most sideways (torso lengths); the file name decides when unclear."""
    P = r["P"]
    TL = sl.torso_len(P)
    hip_mid = 0.5 * (P[:, 23] + P[:, 24])
    span = {}
    for s in ("left", "right"):
        x = (P[:, LEG[s]["ank"], 0] - hip_mid[:, 0]) / (TL if TL and TL > 0 else 1.0)
        span[s] = float(np.nanpercentile(x, 95) - np.nanpercentile(x, 5)) if np.isfinite(x).any() else 0.0
    moving = "left" if span["left"] >= span["right"] else "right"
    clear = max(span.values()) / max(min(span.values()), 1e-6) >= 1.5
    leg = moving if (clear or side is None) else side
    return leg, bool(side is not None and clear and moving != side), span


# ----------------------------------------------------------------------------- per-frame signals
def compute_signals(r, leg, smooth_s=0.25):
    """Per-frame signals of the lifted leg (a) and the standing leg (o).
    abd_leg_a    leg line (hip -> ankle) away from the body's own vertical axis, + = outward (the count signal)
    abd_thigh_a  same for the thigh (hip -> knee)
    abd_leg_o    standing leg away from the body axis, + = outward
    knee2d/3d    knee angle (180 = straight); 3D from the MediaPipe world landmarks
    lean_to_leg  sideways trunk tilt (deg), + = toward the lifted leg ('lean in'), - = away from it ('lean out')
    pelvis_tilt  hip line (deg), + = the lifted-leg hip higher (hip hike)
    sh_tilt      shoulder line (deg), + = the lifted-leg side higher
    ank_h_a      lifted ankle above the standing ankle (leg lengths); ank_lat_a lifted ankle off the body midline (torso lengths)
    foot_sep     distance between the ankles (torso lengths); head_lat nose off the hip midline toward the lifted leg
    trunk_shift  shoulder midpoint off the hip midpoint toward the lifted leg (torso lengths)
    knee_dz_a / ank_dz_a   knee / ankle in front of (-) or behind (+) the hip (3D, leg lengths): the leg going forward
    abd3d_a      thigh away from the trunk in the trunk's frontal plane (3D, deg); lean3d sideways trunk tilt (3D, deg)"""
    P, Wd, fs = r["P"].astype(np.float64), r["world"].astype(np.float64), r["fs"]
    a, o = LEG[leg], LEG[OTHER[leg]]
    hip_mid, sh_mid = 0.5 * (P[:, 23] + P[:, 24]), 0.5 * (P[:, 11] + P[:, 12])
    trunk = sh_mid - hip_mid
    TL = _nanmed(np.linalg.norm(trunk, axis=1))
    TL = TL if np.isfinite(TL) and TL > 0 else 1.0
    out_sign = float(np.sign(_nanmed(P[:, a["hip"], 0] - hip_mid[:, 0])) or 1.0)     # +1: lifted leg on the image's right
    up = _unit(trunk)
    down = -up
    lat = out_sign * np.stack([-up[:, 1], up[:, 0]], 1)           # sideways, toward the lifted leg
    Ll = np.nanpercentile(np.linalg.norm(P[:, o["ank"]] - P[:, o["hip"]], axis=1), 95) if np.isfinite(P[:, o["ank"]]).any() else TL
    Ll = Ll if np.isfinite(Ll) and Ll > 0 else TL
    leg_a, thigh_a, leg_o = P[:, a["ank"]] - P[:, a["hip"]], P[:, a["knee"]] - P[:, a["hip"]], P[:, o["ank"]] - P[:, o["hip"]]
    ang = lambda u, v: sl._ang(u, v)
    sig = {"abd_leg_a": _signed_angle(leg_a, down, lat), "abd_thigh_a": _signed_angle(thigh_a, down, lat),
           "abd_leg_o": _signed_angle(leg_o, down, -lat),
           "knee2d_a": ang(P[:, a["hip"]] - P[:, a["knee"]], P[:, a["ank"]] - P[:, a["knee"]]),
           "knee2d_o": ang(P[:, o["hip"]] - P[:, o["knee"]], P[:, o["ank"]] - P[:, o["knee"]]),
           "knee3d_a": ang(Wd[:, a["hip"]] - Wd[:, a["knee"]], Wd[:, a["ank"]] - Wd[:, a["knee"]]),
           "knee3d_o": ang(Wd[:, o["hip"]] - Wd[:, o["knee"]], Wd[:, o["ank"]] - Wd[:, o["knee"]]),
           "lean_to_leg": out_sign * np.degrees(np.arctan2(trunk[:, 0], -trunk[:, 1]))}
    hd = P[:, a["hip"]] - P[:, o["hip"]]
    sig["pelvis_tilt"] = np.degrees(np.arctan2(-hd[:, 1], np.abs(hd[:, 0]) + 1e-9))
    sd = P[:, a["sh"]] - P[:, o["sh"]]
    sig["sh_tilt"] = np.degrees(np.arctan2(-sd[:, 1], np.abs(sd[:, 0]) + 1e-9))
    sig["ank_h_a"] = (P[:, o["ank"], 1] - P[:, a["ank"], 1]) / Ll
    sig["ank_lat_a"] = ((P[:, a["ank"]] - hip_mid) * lat).sum(1) / TL
    sig["foot_sep"] = np.linalg.norm(P[:, a["ank"]] - P[:, o["ank"]], axis=1) / TL
    sig["head_lat"] = ((P[:, NOSE] - hip_mid) * lat).sum(1) / TL
    sig["trunk_shift"] = (trunk * lat).sum(1) / TL
    # 3D (MediaPipe world landmarks, metres, hip-centred, z < 0 = toward the camera)
    hip_w, sh_w = 0.5 * (Wd[:, 23] + Wd[:, 24]), 0.5 * (Wd[:, 11] + Wd[:, 12])
    upw = _unit(sh_w - hip_w)
    across = Wd[:, a["hip"]] - Wd[:, o["hip"]]
    outw = _unit(across - (across * upw).sum(1, keepdims=True) * upw)
    th_w = Wd[:, a["knee"]] - Wd[:, a["hip"]]
    sig["abd3d_a"] = np.degrees(np.arctan2((th_w * outw).sum(1), -(th_w * upw).sum(1)))
    Lw = _nanmed(np.linalg.norm(Wd[:, o["ank"]] - Wd[:, o["hip"]], axis=1))
    Lw = Lw if np.isfinite(Lw) and Lw > 1e-6 else 1.0
    sig["knee_dz_a"] = (Wd[:, a["knee"], 2] - Wd[:, a["hip"], 2]) / Lw
    sig["ank_dz_a"] = (Wd[:, a["ank"], 2] - Wd[:, a["hip"], 2]) / Lw
    osw = float(np.sign(_nanmed(Wd[:, a["hip"], 0] - hip_w[:, 0])) or 1.0)
    tw = sh_w - hip_w
    sig["lean3d"] = osw * np.degrees(np.arctan2(tw[:, 0], -tw[:, 1]))
    if smooth_s:
        sig = {k: sl.smooth_nan(v, fs, smooth_s) for k, v in sig.items()}
    return sig, dict(TL=TL, Ll=Ll, out_sign=out_sign)


def canonical_coords(r, leg, smooth_s=0.25):
    """(T, 26): hip-centred, torso-length units, y up, mirrored so the lifted leg is on +x."""
    P = r["P"].astype(np.float64)
    hip_mid = 0.5 * (P[:, 23] + P[:, 24])
    TL = sl.torso_len(P)
    Q = (P - hip_mid[:, None, :]) / (TL if np.isfinite(TL) and TL > 0 else 1.0)
    Q[..., 1] *= -1.0
    a, o = LEG[leg], LEG[OTHER[leg]]
    s = np.nanmedian(Q[:, a["hip"], 0]) if np.isfinite(Q[:, a["hip"], 0]).any() else 1.0
    Q[..., 0] *= (1.0 if s >= 0 else -1.0)
    ids = [NOSE, a["sh"], o["sh"], a["wr"], o["wr"], a["hip"], o["hip"], a["knee"], o["knee"], a["ank"], o["ank"],
           a["foot"], o["foot"]]
    C = Q[:, ids, :].reshape(len(Q), -1)
    if smooth_s:
        C = np.stack([sl.smooth_nan(C[:, j], r["fs"], smooth_s) for j in range(C.shape[1])], 1)
    return C


# ----------------------------------------------------------------------------- per-rep measures
PHASE = [("knee2d_a", "min"), ("knee3d_a", "min"), ("lean_to_leg", "absmax"), ("pelvis_tilt", "absmax"),
         ("abd_leg_a", "max")]


def rep_features(sm, marks, fs):
    """Per-rep measures of one (possibly augmented) sample window; sm = per-frame signals on the window."""
    st, pk, en = marks
    seg = slice(st, en + 1)
    v = lambda k: np.asarray(sm[k], float)
    at = lambda k, i: float(v(k)[i]) if np.isfinite(v(k)[i]) else float("nan")
    rel = lambda k: v(k) - (at(k, st) if np.isfinite(at(k, st)) else _nanmean(v(k)[seg]))
    c = v("_count")
    f = dict(duration_s=(en - st) / fs, up_s=(pk - st) / fs, down_s=(en - pk) / fs, up_ratio=(pk - st) / max(en - st, 1),
             amp=float(c[pk] - min(c[st], c[en])))
    f.update(abd_leg_peak=at("abd_leg_a", pk), abd_leg_max=_nanmax(v("abd_leg_a")[seg]),
             abd_leg_rom=at("abd_leg_a", pk) - at("abd_leg_a", st), abd_thigh_peak=at("abd_thigh_a", pk),
             abd3d_peak=at("abd3d_a", pk), abd_leg_o_max=_nanmax(rel("abd_leg_o")[seg]),
             knee2d_a_min=_nanmin(v("knee2d_a")[seg]), knee3d_a_min=_nanmin(v("knee3d_a")[seg]),
             knee2d_a_peak=at("knee2d_a", pk), knee_bend_top=at("knee2d_a", st) - at("knee2d_a", pk),
             knee3d_bend_top=at("knee3d_a", st) - at("knee3d_a", pk), knee2d_o_min=_nanmin(v("knee2d_o")[seg]),
             knee3d_o_min=_nanmin(v("knee3d_o")[seg]),
             lean_delta_peak=float(rel("lean_to_leg")[pk]), lean_delta_max=_nanmax(rel("lean_to_leg")[seg]),
             lean_delta_min=_nanmin(rel("lean_to_leg")[seg]), lean_absmax=_nanmax(np.abs(rel("lean_to_leg")[seg])),
             lean3d_delta_peak=float(rel("lean3d")[pk]), lean3d_delta_max=_nanmax(rel("lean3d")[seg]),
             lean3d_delta_min=_nanmin(rel("lean3d")[seg]),
             pelvis_delta_peak=float(rel("pelvis_tilt")[pk]), pelvis_delta_max=_nanmax(rel("pelvis_tilt")[seg]),
             pelvis_delta_min=_nanmin(rel("pelvis_tilt")[seg]), sh_tilt_delta_peak=float(rel("sh_tilt")[pk]),
             head_lat_delta_peak=float(rel("head_lat")[pk]), head_lat_delta_max=_nanmax(rel("head_lat")[seg]),
             head_lat_delta_min=_nanmin(rel("head_lat")[seg]), trunk_shift_delta_peak=float(rel("trunk_shift")[pk]),
             ank_h_peak=at("ank_h_a", pk), ank_lat_peak=at("ank_lat_a", pk), foot_sep_peak=at("foot_sep", pk),
             knee_dz_peak=at("knee_dz_a", pk), ank_dz_peak=at("ank_dz_a", pk),
             abd_rest_before=_nanmin(v("abd_leg_a")[:st + 1]), abd_rest_after=_nanmin(v("abd_leg_a")[en:]))
    for k in BASE_ANGLES:                              # relative to the person's own posture before rep 1 (first break)
        x = v(f"{k}_rel")
        f[f"{k}_relpeak"] = float(x[pk])
        f[f"{k}_relmax"] = _nanmax(np.abs(x[seg]))
    for k, how in PHASE:                               # the way up and the way down separately
        x = v(k) if how != "absmax" else np.abs(rel(k))
        for ph, part in (("up", x[st:pk + 1]), ("dn", x[pk:en + 1])):
            f[f"ph_{ph}_{how}_{k}"] = _nanmin(part) if how == "min" else _nanmax(part)
    return {g4(k): val for k, val in f.items()}


# ----------------------------------------------------------------------------- one video -> all samples
def _frame_matrix(r, sig, leg, b0, b1):
    C = canonical_coords(r, leg)
    A = np.stack([np.asarray(sig[k], float) / (90.0 if k in DEG else 1.0) for k in ANGLES], 1)
    Dp = np.stack([np.asarray(sig[k], float) / (90.0 if k in DEG else 1.0) for k in DEPTH], 1)
    pid = {p: i for i, p in enumerate(POINTS)}
    cols = [2 * pid[p] + j for p in BASE_POINTS for j in (0, 1)]
    Cb = C[:, cols]
    ok = lambda M: np.isfinite(M[b0:b1]).any()
    bC = np.nanmedian(Cb[b0:b1], axis=0) if ok(Cb) else np.nanmedian(Cb, axis=0)
    Ab = np.stack([np.asarray(sig[k], float) for k in BASE_ANGLES], 1)
    bA = np.nanmedian(Ab[b0:b1], axis=0) if ok(Ab) else np.nanmedian(Ab, axis=0)
    bA, bC = np.where(np.isfinite(bA), bA, 0.0), np.where(np.isfinite(bC), bC, 0.0)
    relA = (Ab - bA) / np.array([90.0 if k in DEG else 1.0 for k in BASE_ANGLES])
    M = sds._fill_cols(np.concatenate([C, A, Dp, Cb - bC, relA], 1))
    sd = dict(sig)
    for j, k in enumerate(BASE_ANGLES):
        sd[f"{k}_rel"] = Ab[:, j] - bA[j]
    sd["_count"] = sig[COUNT_SIGNAL]
    keys = list(sd)
    raw = np.stack([np.asarray(sd[k], float) for k in keys], 1)
    S = sds._fill_cols(raw)
    S[:, ~np.isfinite(raw).any(0)] = np.nan
    return M, S, keys


def analyze_video(d, side=None, fs=30.0, max_gap_s=0.5, seg_cfg=None, T=64, margin_s=0.5, min_valid=0.8, n_geo=0,
                  geo_cfg=None, base_cfg=None, key="", seed=0, rr_levels=()):
    r = sl.resample(d, fs, max_gap_s)
    if r is None:
        return None
    leg, conflict, span = choose_leg(r, side)
    sig, scal = compute_signals(r, leg)
    reps, s = sl.segment_reps(sig[COUNT_SIGNAL], fs, **(seg_cfg or {}))
    n = len(r["t"])
    b0, b1, bsrc = sds.baseline_frames(reps, s, n, fs, **(base_cfg or {}))
    rows = []
    cnt = np.asarray(sig[COUNT_SIGNAL], float)
    for k, rp in enumerate(reps):
        i0, i1 = rp["i_start"], rp["i_end"]
        vf = float(np.mean(np.asarray(r["valid"])[i0:i1 + 1]))
        w0, w1 = sds.rep_window(rp, n, fs, margin_s)
        rb, ra = _nanmin(cnt[w0:i0 + 1]), _nanmin(cnt[i1:w1 + 1])
        usable = bool((not rp["partial"]) and vf >= min_valid and w1 - w0 >= 3)
        rows.append(dict(rep=k + 1, partial=rp["partial"], usable=usable, i_start=i0, i_peak=rp["i_peak"], i_end=i1,
                         t_start=float(r["t"][i0]), t_peak=float(r["t"][rp["i_peak"]]), t_end=float(r["t"][i1]),
                         rest_before=rb, rest_after=ra, rest_max=_nanmax([rb, ra]), valid_frac=vf,
                         peak_abd=float(cnt[rp["i_peak"]]), amp=rp["amp"]))
    use = [i for i, row in enumerate(rows) if row["usable"]]
    versions = [(r, sig)]
    for g in range(1, n_geo + 1):
        rg, _ = sds.geo_version(r, sds.version_rng(key, g, seed), **(geo_cfg or {}))
        versions.append((rg, compute_signals(rg, leg)[0]))
    X, F, fnames = None, None, None
    levels = [None] + list(rr_levels)                 # reduced range: the top of the lift cut at these fractions
    s_full = sl.fill_nan(s) if s is not None else None
    for g, (rv, sv) in enumerate(versions):
        M, S, keys = _frame_matrix(rv, sv, leg, b0, b1)
        for ri, lev in enumerate(levels):
            for j, i in enumerate(use):
                ia, ib, w, marks, dur = sds.window_map(reps[i], n, fs, margin_s, s_full, lev)
                xs = sds.to_T(sds.apply_map(M, ia, ib, w), T)
                fd = rep_features(dict(zip(keys, sds.apply_map(S, ia, ib, w).T)), marks, fs)
                if X is None:
                    fnames = list(fd)
                    X = np.zeros((len(versions), len(levels), len(use), xs.shape[1] + 1, T), np.float32)
                    F = np.full((len(versions), len(levels), len(use), len(fnames)), np.nan, np.float32)
                X[g, ri, j, :-1] = xs.T
                X[g, ri, j, -1] = np.log(max(dur / fs, 0.1))
                F[g, ri, j] = [fd.get(k, np.nan) for k in fnames]
    return dict(r=r, sig=sig, scal=scal, leg=leg, side_conflict=conflict, span=span, reps=reps, s=s, rows=rows, use=use,
                X=X, F=F, feature_names=fnames, baseline=(b0, b1, bsrc))
