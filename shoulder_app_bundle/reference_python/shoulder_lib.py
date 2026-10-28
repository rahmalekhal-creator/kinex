"""shoulder_lib: reusable processing for the shoulder-exercise pose cache (written by the Step-1 notebook).

Later notebooks and the app port should import THIS file so numbers stay consistent:
    import sys; sys.path.append(".../shoulder_step1/code"); import shoulder_lib as sl
    r = sl.resample(sl.load_npz(path), fs=30)            # uniform 30 Hz, short gaps interpolated
    sig, scal = sl.compute_signals(r, "e2", arm="right")  # angles and distances per frame
    reps, s = sl.segment_reps(sig[sl.COUNT_SIGNAL["e2"]], 30)
"""
from __future__ import annotations

import json
import warnings

import numpy as np
from scipy.signal import find_peaks, savgol_filter

warnings.filterwarnings("ignore", category=RuntimeWarning)

# MediaPipe Pose landmark ids ('left' = the person's left)
NOSE, L_EAR, R_EAR = 0, 7, 8
L_SH, R_SH, L_EL, R_EL, L_WR, R_WR = 11, 12, 13, 14, 15, 16
L_HIP, R_HIP = 23, 24
ARM = {"left": dict(sh=L_SH, el=L_EL, wr=L_WR, hip=L_HIP, ear=L_EAR),
       "right": dict(sh=R_SH, el=R_EL, wr=R_WR, hip=R_HIP, ear=R_EAR)}
OTHER = {"left": "right", "right": "left"}
KEY_JOINTS = [L_SH, R_SH, L_EL, R_EL, L_WR, R_WR, L_HIP, R_HIP]
ARM_JOINTS = [L_EL, R_EL, L_WR, R_WR]
SKELETON = [(11, 12), (11, 13), (13, 15), (12, 14), (14, 16), (11, 23), (12, 24), (23, 24),
            (23, 25), (25, 27), (24, 26), (26, 28), (0, 7), (0, 8)]
COUNT_SIGNAL = {"e1": "lift", "e2": "elev_a", "e3": "rot"}   # 1-D signal that goes up and down once per rep


# ----------------------------------------------------------------------------- small helpers
def _norm(v):
    return np.linalg.norm(v, axis=-1)


def _ang(v1, v2):
    """Angle in degrees between vectors (..., d)."""
    v1 = np.asarray(v1, float)
    v2 = np.broadcast_to(np.asarray(v2, float), v1.shape)
    with np.errstate(invalid="ignore", divide="ignore"):
        c = np.einsum("...i,...i->...", v1, v2) / (_norm(v1) * _norm(v2))
    return np.degrees(np.arccos(np.clip(c, -1.0, 1.0)))


def _nanmed(x):
    x = np.asarray(x, float)
    return float(np.nanmedian(x)) if np.isfinite(x).any() else float("nan")


def _nanpct(x, q):
    x = np.asarray(x, float)
    return float(np.nanpercentile(x, q)) if np.isfinite(x).any() else float("nan")


def fill_nan(x):
    """Linear interpolation over NaNs (edges held); None if fewer than 2 valid samples."""
    x = np.asarray(x, float)
    m = np.isfinite(x)
    if m.sum() < 2:
        return None
    i = np.arange(len(x))
    return np.interp(i, i[m], x[m])


def smooth_nan(x, fs, win_s=0.25):
    """Savitzky-Golay smoothing that keeps NaN positions NaN."""
    x = np.asarray(x, float)
    m = np.isfinite(x)
    n = max(5, int(round(win_s * fs)) | 1)
    if m.sum() <= n:
        return x
    y = savgol_filter(fill_nan(x), n, 2)
    y[~m] = np.nan
    return y


# ----------------------------------------------------------------------------- loading / resampling
def load_npz(path) -> dict:
    with np.load(path, allow_pickle=False) as z:
        d = {k: z[k] for k in z.files}
    d["meta"] = json.loads(str(d["meta"])) if "meta" in d else {}
    return d


def resample(d, fs=30.0, max_gap_s=0.5):
    """Uniform time grid at fs Hz. Gaps without detection up to max_gap_s are linearly interpolated,
    longer gaps stay NaN (valid=False). Returns t (s, video time), P (T,33,2) pixels, Z, VIS, world (T,33,3)."""
    t = np.asarray(d["t_ms"], np.float64) / 1000.0
    lm = np.asarray(d["lm"], np.float32)
    wl = np.asarray(d["world"], np.float32)
    ok = np.isfinite(lm[:, 0, 0]) & np.isfinite(t)
    if ok.sum() < 2:
        return None
    idx = np.flatnonzero(ok)
    tv = t[idx]
    if np.any(np.diff(tv) <= 0):                     # should not happen (worker writes increasing times)
        tv, first = np.unique(tv, return_index=True)
        idx = idx[first]
    grid = np.arange(tv[0], tv[-1] + 0.5 / fs, 1.0 / fs)
    j = np.searchsorted(tv, grid, side="right")
    j0, j1 = np.clip(j - 1, 0, len(tv) - 1), np.clip(j, 0, len(tv) - 1)
    t0, t1 = tv[j0], tv[j1]
    span = t1 - t0
    w = np.clip(np.where(span > 0, (grid - t0) / np.where(span > 0, span, 1.0), 0.0), 0, 1).astype(np.float32)
    near = np.minimum(np.abs(grid - t0), np.abs(t1 - grid)) <= 0.5 / fs
    valid = (span <= max_gap_s) | near
    A, B = lm[idx], wl[idx]
    lm_u = A[j0] * (1 - w)[:, None, None] + A[j1] * w[:, None, None]
    wl_u = B[j0] * (1 - w)[:, None, None] + B[j1] * w[:, None, None]
    lm_u[~valid] = np.nan
    wl_u[~valid] = np.nan
    meta = d.get("meta", {})
    W, H = float(meta.get("width") or 1.0), float(meta.get("height") or 1.0)
    P = lm_u[:, :, :2] * np.array([W, H], np.float32)
    return dict(t=grid, P=P, Z=lm_u[:, :, 2], VIS=lm_u[:, :, 3], world=wl_u, valid=valid, W=W, H=H, fs=fs, meta=meta)


# ----------------------------------------------------------------------------- quality
def pose_quality(d):
    lm, meta = d["lm"], d.get("meta", {})
    W, H = float(meta.get("width") or 1.0), float(meta.get("height") or 1.0)
    det = np.isfinite(lm[:, 0, 0])
    q = dict(frames=int(len(lm)), detect_rate=float(det.mean()) if len(lm) else float("nan"))
    if det.sum() < 3:
        return q
    L = lm[det]
    q["vis_key_mean"] = float(np.nanmean(L[:, KEY_JOINTS, 3]))
    q["vis_wrist_p10"] = _nanpct(L[:, [L_WR, R_WR], 3], 10)
    xy = L[:, ARM_JOINTS, :2]
    q["arm_out_of_frame"] = float(((xy < 0) | (xy > 1)).any(axis=(1, 2)).mean())
    P = L[:, :, :2] * np.array([W, H], np.float32)
    sh_mid, hip_mid = 0.5 * (P[:, L_SH] + P[:, R_SH]), 0.5 * (P[:, L_HIP] + P[:, R_HIP])
    TL = _nanmed(_norm(sh_mid - hip_mid))
    q["torso_frac_h"] = TL / H                                  # person size in the frame (camera distance)
    q["center_x"] = _nanmed(0.5 * (sh_mid[:, 0] + hip_mid[:, 0])) / W
    wr = P[:, [L_WR, R_WR]]
    acc = _norm(wr[2:] - 2 * wr[1:-1] + wr[:-2]).max(axis=1)    # frame-to-frame jerkiness of the wrists
    q["jitter_pct"] = 100 * _nanmed(acc) / TL if TL > 0 else float("nan")
    npz = np.asarray(d.get("n_poses", np.ones(len(lm))))
    q["multi_person_frac"] = float((npz > 1).mean())
    return q


# ----------------------------------------------------------------------------- side evidence
def torso_len(P):
    return _nanmed(_norm(0.5 * (P[:, L_SH] + P[:, R_SH]) - 0.5 * (P[:, L_HIP] + P[:, R_HIP])))


def side_evidence(r):
    """How much each (anatomical) arm moves, and how high each elbow goes (95th percentile)."""
    P = r["P"]
    TL = torso_len(P)
    out = {}
    for s in ("left", "right"):
        a = ARM[s]
        rel = (P[:, a["wr"]] - P[:, a["sh"]]) / TL
        span = np.nanpercentile(rel, 95, axis=0) - np.nanpercentile(rel, 5, axis=0)
        out[f"motion_{s}"] = float(_norm(span))
        Lu = _nanpct(_norm(P[:, a["el"]] - P[:, a["sh"]]), 95)
        est = np.degrees(np.arccos(np.clip((P[:, a["el"], 1] - P[:, a["sh"], 1]) / Lu, -1, 1)))
        out[f"elev95_{s}"] = _nanpct(est, 95)
    return out


# ----------------------------------------------------------------------------- signals
def compute_signals(r, ex, arm, smooth_s=0.25):
    """Per-frame signals. arm = arm of interest ('left'/'right', anatomical). Suffix _a = that arm, _o = other.
    elev_*      humerus vs vertical, 2D (true abduction angle for e2)
    abd_trunk_* humerus vs the same-side trunk line, 2D
    elev_est_*  elevation from vertical elbow position only (works for flexion too, e1): arccos(dy / upper-arm length)
    elbow2d/3d  elbow angle (180 = straight); 3D uses MediaPipe world landmarks
    elev3d_*    humerus vs trunk in 3D
    wr_h_*      wrist height above the shoulder line, in torso lengths
    ua_ratio_*  projected upper-arm length / its max (1 = arm in the frontal plane)
    lean_to_arm lateral trunk tilt (deg), + = toward the arm-of-interest side
    hike        arm-side shoulder above the other one ALONG THE TRUNK AXIS (x shoulder width), so a trunk
                lean is not mistaken for a shrug; ear_sh = ear-to-shoulder gap along the same axis
    e1: lift (mean hand height), stick_tilt (+ = injured hand lower), asym, elev_mean
    e3: rot (outward forearm displacement / forearm length ~ sin(rotation)), rot_deg, el_out (elbow off the body)
    """
    P, Wd, fs = r["P"], r["world"], r["fs"]
    a, o = ARM[arm], ARM[OTHER[arm]]
    sh_mid, hip_mid = 0.5 * (P[:, L_SH] + P[:, R_SH]), 0.5 * (P[:, L_HIP] + P[:, R_HIP])
    TL, SW = _nanmed(_norm(sh_mid - hip_mid)), _nanmed(_norm(P[:, L_SH] - P[:, R_SH]))
    out_sign = float(np.sign(_nanmed(P[:, a["sh"], 0] - sh_mid[:, 0])) or 1.0)   # +1: arm on the image's right
    down = np.array([0.0, 1.0])
    trunk = sh_mid - hip_mid
    up = trunk / _norm(trunk)[:, None]            # unit vector hips -> shoulders (the body's own "up")
    sig = {"lean_to_arm": out_sign * np.degrees(np.arctan2(trunk[:, 0], -trunk[:, 1]))}
    Lu = {}
    for tag, j in (("a", a), ("o", o)):
        sh, el, wr, hip = P[:, j["sh"]], P[:, j["el"]], P[:, j["wr"]], P[:, j["hip"]]
        ua = el - sh
        Lu[tag] = _nanpct(_norm(ua), 95)
        sig[f"elev_{tag}"] = _ang(ua, down)
        sig[f"abd_trunk_{tag}"] = _ang(ua, hip - sh)
        sig[f"elev_est_{tag}"] = np.degrees(np.arccos(np.clip((el[:, 1] - sh[:, 1]) / Lu[tag], -1, 1)))
        sig[f"elbow2d_{tag}"] = _ang(sh - el, wr - el)
        sig[f"wr_h_{tag}"] = (sh_mid[:, 1] - wr[:, 1]) / TL
        sig[f"ua_ratio_{tag}"] = _norm(ua) / Lu[tag]
        shw, elw, wrw, hipw = Wd[:, j["sh"]], Wd[:, j["el"]], Wd[:, j["wr"]], Wd[:, j["hip"]]
        sig[f"elbow3d_{tag}"] = _ang(shw - elw, wrw - elw)
        sig[f"elev3d_{tag}"] = _ang(elw - shw, hipw - shw)
    sig["hike"] = np.einsum("ij,ij->i", P[:, a["sh"]] - P[:, o["sh"]], up) / SW
    sig["ear_sh"] = np.einsum("ij,ij->i", P[:, a["ear"]] - P[:, a["sh"]], up) / SW
    if ex == "e1":
        sig["lift"] = np.nanmean(np.stack([sig["wr_h_a"], sig["wr_h_o"]]), axis=0)
        dy = P[:, a["wr"], 1] - P[:, o["wr"], 1]
        dx = np.abs(P[:, a["wr"], 0] - P[:, o["wr"], 0])
        sig["stick_tilt"] = np.degrees(np.arctan2(dy, dx))
        sig["asym"] = sig["elev_est_o"] - sig["elev_est_a"]
        sig["elev_mean"] = 0.5 * (sig["elev_est_a"] + sig["elev_est_o"])
    elif ex == "e3":
        sh, el, wr, hip = P[:, a["sh"]], P[:, a["el"]], P[:, a["wr"]], P[:, a["hip"]]
        Lf = max(_nanpct(_norm(wr - el), 95), 0.78 * Lu["a"])       # forearm length (fallback: anthropometric ratio)
        sig["rot"] = out_sign * (wr[:, 0] - el[:, 0]) / Lf
        sig["rot_deg"] = np.degrees(np.arcsin(np.clip(sig["rot"], -1, 1)))
        dyb = hip[:, 1] - sh[:, 1]
        frac = (el[:, 1] - sh[:, 1]) / np.where(np.abs(dyb) > 1e-6, dyb, np.nan)
        sig["el_out"] = out_sign * (el[:, 0] - (sh[:, 0] + (hip[:, 0] - sh[:, 0]) * frac)) / SW
    if smooth_s:
        sig = {k: smooth_nan(v, fs, smooth_s) for k, v in sig.items()}
    scal = dict(TL=TL, SW=SW, out_sign=out_sign, Lu_a=Lu["a"], Lu_o=Lu["o"])
    return sig, scal


# ----------------------------------------------------------------------------- rep segmentation
def count_polarity(x, fs):
    """+1 if reps are upward excursions of x, -1 if downward (rest = where the signal spends most time)."""
    s = fill_nan(x)
    if s is None:
        return 1.0
    p5, med, p95 = np.percentile(smooth_nan(s, fs, 0.4), [5, 50, 95])
    return -1.0 if (med - p5) > (p95 - med) else 1.0


def segment_reps(x, fs, min_rep_s=0.6, max_rep_s=20.0, prominence=0.35, onset=0.10, min_rel_amp=0.35,
                 min_dur_s=0.4, polarity=1.0, smooth_s=0.4, edge_pad_s=1.0):
    """Offline rep segmentation on a 1-D count signal.
    Peaks need a prominence >= `prominence` x (p95-p5) of the video and >= min_rel_amp x the median peak, and must be
    at least 0.8 x min_rep_s apart (0.6 s default: fast performers do a rep every ~1 s).
    The signal is padded at both ends with its rest level, so a rep that is already under way when the video starts,
    or not finished when it stops, is still found; such reps get partial=True (keep them for counting, drop them
    from training samples).
    Start/end = where the signal is within `onset` (10 %) of the rep's amplitude from its valleys, so rests are trimmed.
    Returns (reps, s): list of dict(i_start, i_peak, i_end, i_valley_l, i_valley_r, prominence, amp, partial) on the
    signal's grid (valley indices are -1 when outside the video), and the smoothed, polarity-corrected signal."""
    s = fill_nan(x)
    if s is None or len(s) < int(2 * fs):
        return [], None
    s = polarity * smooth_nan(s, fs, smooth_s)
    lo, hi = np.percentile(s, [5, 95])
    rng = hi - lo
    if not np.isfinite(rng) or rng <= 1e-9:
        return [], s
    n, pad = len(s), max(1, int(round(edge_pad_s * fs)))
    sp = np.concatenate([np.full(pad, lo), s, np.full(pad, lo)])
    peaks, props = find_peaks(sp, prominence=prominence * rng, distance=max(1, int(0.8 * min_rep_s * fs)))
    inside = (peaks >= pad) & (peaks < pad + n)
    peaks, proms = peaks[inside], props["prominences"][inside]
    if len(peaks) == 0:
        return [], s
    keep = proms >= min_rel_amp * np.median(proms)
    peaks, proms = peaks[keep], proms[keep]
    N, maxw = len(sp), int(max_rep_s * fs)
    reps = []
    for k, p in enumerate(peaks):
        lb = peaks[k - 1] if k > 0 else max(0, p - maxw)
        rb = peaks[k + 1] if k < len(peaks) - 1 else min(N - 1, p + maxw)
        vl = lb + int(np.argmin(sp[lb:p + 1]))
        vr = p + int(np.argmin(sp[p:rb + 1]))
        thr_l = sp[vl] + onset * (sp[p] - sp[vl])
        thr_r = sp[vr] + onset * (sp[p] - sp[vr])
        below_l = np.flatnonzero(sp[vl:p + 1] <= thr_l)
        below_r = np.flatnonzero(sp[p:vr + 1] <= thr_r)
        start = vl + (int(below_l[-1]) if len(below_l) else 0)
        end = p + (int(below_r[0]) if len(below_r) else vr - p)
        dur = (end - start) / fs
        if dur < min_dur_s or dur > max_rep_s:
            continue
        partial = bool(start < pad or end > pad + n - 1)
        to_real = lambda i: int(min(max(i - pad, 0), n - 1))
        reps.append(dict(i_start=to_real(start), i_peak=int(p - pad), i_end=to_real(end),
                         i_valley_l=int(vl - pad) if pad <= vl < pad + n else -1,
                         i_valley_r=int(vr - pad) if pad <= vr < pad + n else -1,
                         prominence=float(proms[k]), amp=float(sp[p] - min(sp[vl], sp[vr])), partial=partial))
    return reps, s


def online_count(x, fs, ref_amp, up=0.3, drop=0.3, tau_s=0.1, polarity=1.0):
    """Causal counter as an app would run it: exponential smoothing, then a rep = a rise of up*ref_amp above
    the last low point followed by a fall of drop*ref_amp below the rep's high point. Returns (count, frame ids)."""
    alpha = 1.0 - np.exp(-1.0 / (fs * tau_s))
    y = lo = hi = None
    state, count, events = 0, 0, []
    for i, v in enumerate(np.asarray(x, float)):
        if not np.isfinite(v):
            continue
        v *= polarity
        y = v if y is None else y + alpha * (v - y)
        if state == 0:
            lo = y if lo is None else min(lo, y)
            if y >= lo + up * ref_amp:
                state, hi = 1, y
        else:
            hi = max(hi, y)
            if y <= hi - drop * ref_amp:
                count += 1
                events.append(i)
                state, lo = 0, y
    return count, events


# ----------------------------------------------------------------------------- per-rep features
def _seg(x, i0, i1, fn):
    v = np.asarray(x[i0:i1 + 1], float)
    v = v[np.isfinite(v)]
    return float(fn(v)) if len(v) else float("nan")


def _at(x, i):
    v = float(x[i])
    return v if np.isfinite(v) else float("nan")


def rep_features(sig, ex, rep, fs, polarity=1.0, valid=None):
    """Kinematic summary of one rep (side-relative, so left and right videos are comparable)."""
    i0, ip, i1 = rep["i_start"], rep["i_peak"], rep["i_end"]
    mx = lambda k: _seg(sig[k], i0, i1, np.max)
    mn = lambda k: _seg(sig[k], i0, i1, np.min)
    me = lambda k: _seg(sig[k], i0, i1, np.mean)
    at = lambda k, i=ip: _at(sig[k], i)
    f = dict(duration_s=(i1 - i0) / fs, up_s=(ip - i0) / fs, down_s=(i1 - ip) / fs,
             up_ratio=(ip - i0) / max(i1 - i0, 1), amp=rep.get("amp", float("nan")))
    if valid is not None:
        f["valid_frac"] = float(np.mean(np.asarray(valid)[i0:i1 + 1]))
    f["lean_absmax"] = _seg(np.abs(sig["lean_to_arm"] - at("lean_to_arm", i0)), i0, i1, np.max)
    f["hike_delta"] = at("hike") - at("hike", i0)
    # bottom of the rep = the rest position in the valleys before/after it (does the arm come all the way down?)
    valleys = [i for i in (rep.get("i_valley_l", -1), rep.get("i_valley_r", -1)) if i is not None and i >= 0]
    bottom = lambda k, sign=1.0: (float(np.nanmean([sign * _at(sig[k], i) for i in valleys]))
                                  if valleys else float("nan"))
    if ex == "e1":
        f.update(elev_mean_bottom=bottom("elev_mean"), lift_bottom=bottom("lift"))
        f["elev_mean_rom"] = at("elev_mean") - f["elev_mean_bottom"]
    elif ex == "e2":
        f.update(elev_bottom=bottom("elev_a"))
        f["elev_rom"] = at("elev_a") - f["elev_bottom"]
    elif ex == "e3":
        f.update(rot_deg_bottom=bottom("rot_deg", polarity))
        f["rot_deg_rom"] = polarity * at("rot_deg") - f["rot_deg_bottom"]
    if ex == "e1":
        f.update(lift_peak=at("lift"), elev_mean_peak=at("elev_mean"), elev_inj_peak=at("elev_est_a"),
                 elev_oth_peak=at("elev_est_o"), asym_peak=at("asym"), elev3d_inj_max=mx("elev3d_a"),
                 elev3d_oth_max=mx("elev3d_o"), stick_tilt_peak=at("stick_tilt"), stick_tilt_mean=me("stick_tilt"),
                 stick_tilt_absmax=_seg(np.abs(sig["stick_tilt"]), i0, i1, np.max),
                 elbow3d_min=np.nanmin([mn("elbow3d_a"), mn("elbow3d_o")]),
                 elbow2d_peak=np.nanmean([at("elbow2d_a"), at("elbow2d_o")]))
    elif ex == "e2":
        f.update(elev_peak=at("elev_a"), abd_trunk_peak=at("abd_trunk_a"),
                 elev_minus_trunk=at("elev_a") - at("abd_trunk_a"),
                 lean_delta=at("lean_to_arm") - at("lean_to_arm", i0), ear_sh_delta=at("ear_sh") - at("ear_sh", i0),
                 elbow2d_peak=at("elbow2d_a"), elbow2d_min=mn("elbow2d_a"), elbow3d_min=mn("elbow3d_a"),
                 ua_ratio_peak=at("ua_ratio_a"), other_elev_max=mx("elev_o"), wr_h_peak=at("wr_h_a"))
    elif ex == "e3":
        f.update(rot_peak=polarity * at("rot"), rot_deg_peak=polarity * at("rot_deg"), el_out_max=mx("el_out"),
                 el_out_mean=me("el_out"), el_out_delta=at("el_out") - at("el_out", i0), abd_max=mx("elev_a"),
                 elbow3d_mean=me("elbow3d_a"))
    return f


# ----------------------------------------------------------------------------- drawing
def read_frame(path, t_s):
    import cv2
    cap = cv2.VideoCapture(str(path))
    if not cap.isOpened():
        return None
    cap.set(cv2.CAP_PROP_POS_MSEC, max(0.0, float(t_s) * 1000.0))
    ok, fr = cap.read()
    cap.release()
    return cv2.cvtColor(fr, cv2.COLOR_BGR2RGB) if ok and fr is not None else None


def draw_pose(img, P, arm=None, color=(42, 120, 214), arm_color=(235, 104, 52)):
    """Skeleton on an RGB image; P = (33,2) pixel coords; the arm of interest in orange."""
    import cv2
    img = np.ascontiguousarray(img.copy())
    th = max(2, int(round(min(img.shape[:2]) / 160)))
    hot = {ARM[arm]["sh"], ARM[arm]["el"], ARM[arm]["wr"]} if arm in ARM else set()
    for i, j in SKELETON:
        p, q = P[i], P[j]
        if np.all(np.isfinite(p)) and np.all(np.isfinite(q)):
            cv2.line(img, (int(p[0]), int(p[1])), (int(q[0]), int(q[1])),
                     arm_color if (i in hot and j in hot) else color, th, cv2.LINE_AA)
    for i in sorted(set(sum(SKELETON, ()))):
        if np.all(np.isfinite(P[i])):
            cv2.circle(img, (int(P[i][0]), int(P[i][1])), th + 1, arm_color if i in hot else color, -1, cv2.LINE_AA)
    return img
