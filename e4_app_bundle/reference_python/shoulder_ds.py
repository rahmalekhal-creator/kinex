"""shoulder_ds (v4, final notebook): from one pose + silhouette file to per-rep samples, in several versions.

Used for training, evaluation, the demo and (later) the app, so preprocessing is identical everywhere:
    import shoulder_ds as sds
    out = sds.analyze_video(sl.load_npz(path), "e2", side="left", seg_cfg=dict(min_rep_s=0.6),
                            n_geo=3, rr_levels=(0.55, 0.7, 0.85), key="e2_good_p05_left_15")
    out["X"]    (G, R, n, C, T) float32: G pose versions (0 = as recorded, 1.. = consistent geometric
                augmentations), R range versions (0 = full range, 1.. = top of the rep cut), n reps, C channels, T frames
    out["F"]    (G, R, n, F) per-rep features of the same versions
    out["rows"] one dict per rep (also partial / unusable ones)

v3 (Step 2c): shrug channels, shoulder-angle elbow measures, fixed body-part groups, MultiROCKET pooling.
v4 (final):
  - SILHOUETTE (person mask from MediaPipe, measured by pose_worker v2): the gap between the upper arm and the side of
    the body (0 = touching, whatever the body shape) for e3, and the shoulder outline / its distance to the ear for
    shrugs. Silhouette numbers come from the original recording (geometric versions reuse them).
  - GATED SHRUG channels (e1/e2): shoulder hike, ear gap, neck ratio... relative to the rep start and FROZEN once the
    arm passes 100 deg, so the normal shoulder rise at the top of a full-range rep is not read as a shrug.
  - PHASE features: the way up/out and the way down/back separately (a mistake made only on one side of the rep),
    e.g. the elbow straight at the start but bent at the top.
"""
import zlib

import numpy as np

import shoulder_lib as sl

# ----------------------------------------------------------------------------- channels
POINT_NAMES = ["nose", "ear_a", "ear_o", "sh_a", "sh_o", "el_a", "el_o", "wr_a", "wr_o", "hip_a", "hip_o"]
COORD_NAMES = [f"{p}_{ax}" for p in POINT_NAMES for ax in "xy"]
ANGLE_COMMON = ["elev_a", "elev_o", "abd_trunk_a", "elev_est_a", "elev_est_o", "elev3d_a", "elbow2d_a", "elbow2d_o",
                "elbow3d_a", "elbow3d_o", "wr_h_a", "wr_h_o", "ua_ratio_a", "lean_to_arm", "hike", "ear_sh"]
ANGLE_EXTRA = {"e1": ["stick_tilt", "asym", "lift"], "e2": [], "e3": ["rot", "el_out"]}
DEPTH_NAMES = ["wr_dz_a", "el_dz_a", "wr_dz_o", "fa_ratio_a", "rot3d_a"]
BASE_POINTS = ["nose", "ear_a", "ear_o", "sh_a", "sh_o", "hip_a", "hip_o"]
BASE_ANGLES = ["hike", "ear_sh", "lean_to_arm", "elbow2d_a", "elev_a"]
BASE_EXTRA = {"e1": ["stick_tilt"], "e2": [], "e3": ["el_out"]}
# new in v3
SHLD_NAMES = ["hike_d0", "ear_sh_d0", "neck_ratio", "neck_ratio_d0", "hike3d", "hike3d_d0"]
GAP_NAMES = ["ua_abd", "ua_abd3d", "ua_abd_d0", "ua_abd3d_d0", "el_out_d0"]
BASE_NEW = {"e1": ["neck_ratio", "hike3d"], "e2": ["neck_ratio", "hike3d"], "e3": ["ua_abd", "ua_abd3d"]}
SHLD_EX, GAP_EX = {"e1", "e2"}, {"e3"}
SIL_ARM_NAMES = ["sil_gap_mean", "sil_gap_min", "sil_gap85", "sil_contact"]                # e3: upper arm vs body
SIL_SH_NAMES = ["sil_neck_a", "sil_neck_ratio", "sil_shtop_a", "sil_neck_a_d0", "sil_shtop_a_d0"]  # e1/e2: shoulder outline
GATED_NAMES = ["hike_g", "ear_sh_g", "neck_ratio_g", "hike3d_g", "sil_neck_g"]           # e1/e2: frozen above GATE_DEG
GATE_DEG = 100.0
GATE_KEY = {"e1": "elev_est_a", "e2": "elev_a"}
CONTACT_GAP = 0.02                     # gap (shoulder widths) below which the arm counts as touching the body
DEG = {"elev_a", "elev_o", "abd_trunk_a", "elev_est_a", "elev_est_o", "elev3d_a", "elbow2d_a", "elbow2d_o",
       "elbow3d_a", "elbow3d_o", "lean_to_arm", "stick_tilt", "asym", "rot3d_a", "ua_abd", "ua_abd3d"}  # stored /90
ELEV_KEY = {"e1": "elev_mean", "e2": "elev_a", "e3": "elev_a"}      # arm elevation used for rest angles
GROUP_ORDER = ["coords", "angles", "depth", "base_pts", "base_ang", "shld", "gap", "base_new", "sil", "gated", "dur"]
OTHER_ARM_SIG = {"elev_o", "elev_est_o", "elbow2d_o", "elbow3d_o", "wr_h_o", "wr_dz_o", "ua_ratio_o", "abd_trunk_o",
                 "elev3d_o", "stick_tilt", "asym", "lift"}
SHOULDER_SIG = {"hike", "ear_sh", "neck_ratio", "hike3d", "sil_neck_a", "sil_neck_ratio", "sil_shtop_a", "sil_neck"}


def channel_groups(ex):
    return {"coords": list(COORD_NAMES),
            "angles": ANGLE_COMMON + ANGLE_EXTRA[ex],
            "depth": list(DEPTH_NAMES),
            "base_pts": [f"{p}_{ax}_rel" for p in BASE_POINTS for ax in "xy"],
            "base_ang": [f"{k}_rel" for k in BASE_ANGLES + BASE_EXTRA[ex]],
            "shld": list(SHLD_NAMES) if ex in SHLD_EX else [],
            "gap": list(GAP_NAMES) if ex in GAP_EX else [],
            "base_new": [f"{k}_rel" for k in BASE_NEW[ex]],
            "sil": list(SIL_ARM_NAMES) if ex in GAP_EX else list(SIL_SH_NAMES),
            "gated": list(GATED_NAMES) if ex in SHLD_EX else [],
            "dur": ["log_duration"]}


def channel_names(ex):
    g = channel_groups(ex)
    return [c for name in GROUP_ORDER for c in g[name]]


def _base_name(name):
    n = name[2:] if name.startswith("d_") else name
    for suf in ("_rel", "_d0", "_g"):
        if n.endswith(suf):
            n = n[: -len(suf)]
    return n


def scale_of(name):
    return 90.0 if _base_name(name) in DEG else 1.0


def part_of(name):
    """Body part of an input channel (body-part attention network, occlusion test, other-arm options).
    Velocity channels are 'd_<name>'; '_rel' (first break) and '_d0' (rep start) versions belong to their source."""
    n = _base_name(name)
    if n == "log_duration":
        return "time"
    if n in ("hip_a_x", "hip_a_y", "hip_o_x", "hip_o_y", "lean_to_arm"):
        return "trunk"
    if n.startswith(("nose_", "ear_a_", "ear_o_", "sh_a_", "sh_o_")) or n in SHOULDER_SIG:
        return "shoulder_head"
    if n.startswith(("el_o_", "wr_o_")) or n in OTHER_ARM_SIG:
        return "other_arm"
    return "arm"


# ----------------------------------------------------------------------------- per-rep feature bookkeeping
NEW_FEATURE_PREFIXES = ("neck_ratio", "neckr_", "hike3d", "ua_abd", "el_out_d0", "hike_d0", "ear_sh_d0")
SHLD_FEATURE_PREFIXES = ("neck_ratio", "neckr_", "hike3d", "hike_d0", "ear_sh_d0")
TIME_FEATURES = {"duration_s", "up_s", "down_s", "up_ratio", "amp", "valid_frac"}
OTHER_FEATURES = {"other_elev_max", "elev_oth_peak", "elev3d_oth_max", "asym_peak", "stick_tilt_peak",
                  "stick_tilt_mean", "stick_tilt_absmax", "stick_tilt_relpeak", "stick_tilt_relmax", "lift_peak",
                  "lift_bottom"}


def is_new_feature(name):
    """New compared with Step 2b (used for Step-2b reference sets)."""
    return name.startswith(NEW_FEATURE_PREFIXES) or feature_group(name) in ("sil", "phase", "shg")


def feature_group(name):
    """'sil' (silhouette), 'phase' (way up / way down), 'shg' (gated shrug), 'shld' (2c shrug features),
    'gap_el' (elbow vs shoulder-hip line), 'gap_ua' (upper-arm angle at the shoulder) or None."""
    if "sil" in name:
        return "sil"
    if name.startswith("ph_"):
        return "phase"
    if name.startswith("shg_"):
        return "shg"
    if name.startswith(SHLD_FEATURE_PREFIXES):
        return "shld"
    if name.startswith("el_out"):
        return "gap_el"
    if name.startswith("ua_abd"):
        return "gap_ua"
    return None


def feature_relative(name):
    """True if the feature is relative to the person's own posture (rep start or first break)."""
    return name.endswith(("_delta", "_d0max", "_d0min", "_relpeak", "_relmax"))


def part_of_feature(name):
    n = name[3:].split("_", 2)[-1] if name.startswith("ph_") else name
    if name in TIME_FEATURES:
        return "time"
    if n.startswith(("lean",)):
        return "trunk"
    if n.startswith(("hike", "ear_sh", "earsh", "neck", "neckr", "sil_neck", "sil_shtop", "silneck")) or name.startswith("shg_"):
        return "shoulder_head"
    if name in OTHER_FEATURES or n in ("elbow3d_o", "stick_tilt"):
        return "other_arm"
    return "arm"


# ----------------------------------------------------------------------------- small helpers
def _nanmin(x):
    x = np.asarray(x, float)
    return float(np.nanmin(x)) if np.isfinite(x).any() else float("nan")


def _nanmax(x):
    x = np.asarray(x, float)
    return float(np.nanmax(x)) if np.isfinite(x).any() else float("nan")


def _nanmean(x):
    x = np.asarray(x, float)
    return float(np.nanmean(x)) if np.isfinite(x).any() else float("nan")


def _fill_cols(M):
    """Column-wise linear interpolation over NaNs (edges held); all-NaN columns become 0."""
    M = np.array(M, dtype=np.float64, copy=True)
    for j in range(M.shape[1]):
        f = sl.fill_nan(M[:, j])
        M[:, j] = 0.0 if f is None else f
    return M


def to_T(A, T):
    """Linear resampling of the rows of A (L, C) to T rows."""
    L = len(A)
    if L == 1:
        return np.repeat(A, T, axis=0)
    xs = np.linspace(0, L - 1, T)
    i0 = np.floor(xs).astype(int)
    i1 = np.minimum(i0 + 1, L - 1)
    f = (xs - i0)[:, None]
    return A[i0] * (1 - f) + A[i1] * f


def apply_map(A, ia, ib, w):
    w = w[:, None] if A.ndim == 2 else w
    return A[ia] * (1 - w) + A[ib] * w


def point_ids(arm):
    a, o = sl.ARM[arm], sl.ARM[sl.OTHER[arm]]
    return [sl.NOSE, a["ear"], o["ear"], a["sh"], o["sh"], a["el"], o["el"], a["wr"], o["wr"], a["hip"], o["hip"]]


def canonical_coords(r, arm, smooth_s=0.25):
    """(T, 22): hip-centred, torso-length units, y up, mirrored so the arm of interest is on +x (as Step 2a)."""
    P = r["P"].astype(np.float64)
    hip_mid = 0.5 * (P[:, sl.L_HIP] + P[:, sl.R_HIP])
    TL = sl.torso_len(P)
    Q = (P - hip_mid[:, None, :]) / (TL if np.isfinite(TL) and TL > 0 else 1.0)
    Q[..., 1] *= -1.0
    s = np.nanmedian(Q[:, sl.ARM[arm]["sh"], 0]) if np.isfinite(Q[:, sl.ARM[arm]["sh"], 0]).any() else 1.0
    Q[..., 0] *= (1.0 if s >= 0 else -1.0)
    C = Q[:, point_ids(arm), :].reshape(len(Q), -1)
    if smooth_s:
        C = np.stack([sl.smooth_nan(C[:, j], r["fs"], smooth_s) for j in range(C.shape[1])], 1)
    return C


def depth_signals(r, arm, out_sign, smooth_s=0.25):
    """Depth information from the MediaPipe world landmarks (metres, hip-centred, z < 0 = toward the camera):
    wr_dz_a / el_dz_a  wrist / elbow in front of (-) or behind (+) the shoulder, in arm lengths
    wr_dz_o            same for the other wrist
    fa_ratio_a         projected forearm length / its 95th percentile (shortens when the forearm points at the camera)
    rot3d_a            forearm direction in the horizontal plane (deg): 0 = straight forward, + = outward."""
    W, P = r["world"].astype(np.float64), r["P"].astype(np.float64)
    a, o = sl.ARM[arm], sl.ARM[sl.OTHER[arm]]

    def arm_len(j):
        u = np.nanmedian(np.linalg.norm(W[:, j["el"]] - W[:, j["sh"]], axis=-1)) if np.isfinite(W[:, j["el"]]).any() else np.nan
        f = np.nanmedian(np.linalg.norm(W[:, j["wr"]] - W[:, j["el"]], axis=-1)) if np.isfinite(W[:, j["wr"]]).any() else np.nan
        L = u + f
        return L if np.isfinite(L) and L > 1e-6 else 1.0

    La, Lo = arm_len(a), arm_len(o)
    fa = np.linalg.norm(P[:, a["wr"]] - P[:, a["el"]], axis=-1)
    fa95 = np.nanpercentile(fa, 95) if np.isfinite(fa).any() else np.nan
    lat = out_sign * (W[:, a["wr"], 0] - W[:, a["el"], 0])
    fwd = -(W[:, a["wr"], 2] - W[:, a["el"], 2])
    d = {"wr_dz_a": (W[:, a["wr"], 2] - W[:, a["sh"], 2]) / La,
         "el_dz_a": (W[:, a["el"], 2] - W[:, a["sh"], 2]) / La,
         "wr_dz_o": (W[:, o["wr"], 2] - W[:, o["sh"], 2]) / Lo,
         "fa_ratio_a": fa / fa95 if np.isfinite(fa95) and fa95 > 0 else fa * np.nan,
         "rot3d_a": np.degrees(np.arctan2(lat, fwd))}
    if smooth_s:
        d = {k: sl.smooth_nan(v, r["fs"], smooth_s) for k, v in d.items()}
    return d


def _unit(v):
    n = np.linalg.norm(v, axis=-1, keepdims=True)
    return v / np.where(n > 1e-9, n, np.nan)


def extra_signals(r, arm, out_sign, smooth_s=0.25):
    """New per-frame signals (v3).
    neck_ratio  ear-to-shoulder distance of the working side / the same distance of the other side (2D). ~1 at rest
                for everybody; drops when the working shoulder shrugs toward the ear.
    hike3d      working shoulder above the other one along the trunk axis, from the 3D world landmarks, in
                shoulder widths (less sensitive to camera roll and body rotation than the 2D hike)
    ua_abd      angle of the upper arm at the shoulder against the body's own vertical axis (2D image, deg):
                0 = upper arm hanging along the body axis, + = elbow away from the body
    ua_abd3d    same angle in the trunk's frontal plane from the 3D world landmarks (camera-yaw independent)"""
    P, W = r["P"].astype(np.float64), r["world"].astype(np.float64)
    a, o = sl.ARM[arm], sl.ARM[sl.OTHER[arm]]
    SW = np.nanmedian(np.linalg.norm(P[:, sl.L_SH] - P[:, sl.R_SH], axis=-1))
    SW = SW if np.isfinite(SW) and SW > 1e-9 else 1.0
    neck_a = np.linalg.norm(P[:, a["ear"]] - P[:, a["sh"]], axis=-1) / SW
    neck_o = np.linalg.norm(P[:, o["ear"]] - P[:, o["sh"]], axis=-1) / SW
    out = {"neck_ratio": neck_a / np.where(neck_o > 1e-6, neck_o, np.nan)}
    # 2D: body axis (hips -> shoulders) and the outward lateral axis of the working arm
    up = _unit(0.5 * (P[:, sl.L_SH] + P[:, sl.R_SH]) - 0.5 * (P[:, sl.L_HIP] + P[:, sl.R_HIP]))
    lat = out_sign * np.stack([-up[:, 1], up[:, 0]], 1)
    ua = P[:, a["el"]] - P[:, a["sh"]]
    out["ua_abd"] = np.degrees(np.arctan2((ua * lat).sum(1), -(ua * up).sum(1)))
    # 3D world landmarks: trunk axis, outward axis in the frontal plane, upper arm
    shw_a, shw_o = W[:, a["sh"]], W[:, o["sh"]]
    upw = _unit(0.5 * (shw_a + shw_o) - 0.5 * (W[:, sl.L_HIP] + W[:, sl.R_HIP]))
    across = shw_a - shw_o
    outw = _unit(across - (across * upw).sum(1, keepdims=True) * upw)
    uaw = W[:, a["el"]] - shw_a
    out["ua_abd3d"] = np.degrees(np.arctan2((uaw * outw).sum(1), -(uaw * upw).sum(1)))
    SWw = np.nanmedian(np.linalg.norm(across, axis=-1))
    out["hike3d"] = (across * upw).sum(1) / (SWw if np.isfinite(SWw) and SWw > 1e-9 else 1.0)
    if smooth_s:
        out = {k: sl.smooth_nan(v, r["fs"], smooth_s) for k, v in out.items()}
    return out


# ----------------------------------------------------------------------------- silhouette (pose_worker v2)
SIL_RAW = ["gap40", "gap55", "gap70", "gap85", "shtop65", "shtop80", "neck65", "neck80", "mask_ok"]


def has_silhouette(d):
    return "sil" in d and np.asarray(d["sil"]).ndim == 3 and len(d["sil"]) > 0


def resample_sil(d, r, max_gap_s=0.5):
    """(n, 2, K) silhouette measurements on the uniform grid of r (side 0 = person's left, 1 = right) and their
    names, or (None, names) without silhouette. Values further than max_gap_s from a measured frame stay NaN."""
    names = list((d.get("meta") or {}).get("sil_names") or SIL_RAW)
    if not has_silhouette(d):
        return None, names
    t = np.asarray(d["t_ms"], np.float64) / 1000.0
    S = np.asarray(d["sil"], np.float32)
    g = r["t"]
    out = np.full((len(g), S.shape[1], S.shape[2]), np.nan, np.float32)
    for s in range(S.shape[1]):
        for k in range(S.shape[2]):
            x = S[:, s, k]
            m = np.isfinite(x) & np.isfinite(t)
            if m.sum() < 2:
                continue
            tv, xv = t[m], x[m]
            y = np.interp(g, tv, xv)
            j = np.clip(np.searchsorted(tv, g), 1, len(tv) - 1)
            dist = np.minimum(np.abs(g - tv[j - 1]), np.abs(tv[j] - g))
            y[dist > max_gap_s] = np.nan
            out[:, s, k] = y
    out[~r["valid"]] = np.nan
    return out, names


def sil_signals(d, r, arm, smooth_s=0.25):
    """Per-frame silhouette signals of the arm of interest (a) and the other side (o), in shoulder widths:
    sil_gap_mean / sil_gap_min / sil_gap85  background between the upper arm and the body (0 = touching)
    sil_contact     share of the 4 upper-arm points touching the body
    sil_neck_a/o    shoulder outline -> ear distance (shrinks in a shrug); sil_neck_ratio = a / o
    sil_shtop_a     height of the shoulder outline above the shoulder line
    sil_ok          the mask covers the torso"""
    S, names = resample_sil(d, r)
    n = len(r["t"])
    nan = np.full(n, np.nan)
    keys = ["sil_gap_mean", "sil_gap_min", "sil_gap85", "sil_contact", "sil_neck_a", "sil_neck_o", "sil_neck_ratio",
            "sil_shtop_a", "sil_ok"]
    if S is None:
        return {k: nan.copy() for k in keys}
    col = {nm: i for i, nm in enumerate(names)}
    ia, io = (0, 1) if arm == "left" else (1, 0)
    pick = lambda side, pre: np.stack([S[:, side, col[c]] for c in names if c.startswith(pre)], 1)
    G = pick(ia, "gap")
    neck = lambda side: np.nanmean(pick(side, "neck"), 1)
    out = {"sil_gap_mean": np.nanmean(G, 1), "sil_gap_min": np.nanmin(G, 1), "sil_gap85": G[:, -1],
           "sil_contact": np.nanmean(np.where(np.isfinite(G), (G <= CONTACT_GAP).astype(float), np.nan), 1),
           "sil_neck_a": neck(ia), "sil_neck_o": neck(io), "sil_shtop_a": np.nanmean(pick(ia, "shtop"), 1),
           "sil_ok": S[:, ia, col["mask_ok"]] if "mask_ok" in col else nan.copy()}
    no = out["sil_neck_o"]
    out["sil_neck_ratio"] = out["sil_neck_a"] / np.where(np.abs(no) > 1e-3, no, np.nan)
    if smooth_s:
        out = {k: (v if k in ("sil_contact", "sil_ok") else sl.smooth_nan(v, r["fs"], smooth_s)) for k, v in out.items()}
    return out


# ----------------------------------------------------------------------------- first break (label-free calibration)
def baseline_frames(reps, s, n, fs, base_s=1.5, gap_s=0.15, min_s=0.4):
    """Frames used as the person's own reference posture.
    'first_break': the last base_s seconds before the first rep (the person standing still before starting -
    in the app: a short 'get ready' moment). Fallback 'lowest_point': 0.5 s around the lowest point of the count
    signal (used when the video starts in the middle of a rep)."""
    if reps and not reps[0]["partial"]:
        end = reps[0]["i_start"] - int(round(gap_s * fs))
        start = max(0, end - int(round(base_s * fs)))
        if end - start >= int(round(min_s * fs)):
            return start, end, "first_break"
    if s is None or not np.isfinite(s).any():
        return 0, min(n, int(fs)), "video_start"
    k, h = int(np.nanargmin(s)), int(round(0.25 * fs))
    return max(0, k - h), min(n, k + h + 1), "lowest_point"


# ----------------------------------------------------------------------------- geometric augmentation
def geo_version(r, rng, roll_deg=5.0, sx_range=0.08, yaw_deg=15.0, jitter=0.004):
    """A plausible 'other camera / other body' version of the whole video: camera roll, horizontal scaling
    (body proportions + camera yaw), the same yaw applied to the 3D world landmarks, and small landmark jitter.
    Angles are then recomputed from the transformed skeleton, so all channels stay consistent."""
    P = r["P"].astype(np.float64).copy()
    W = r["world"].astype(np.float64).copy()
    hip = 0.5 * (P[:, sl.L_HIP] + P[:, sl.R_HIP])
    c = np.nanmedian(hip, axis=0) if np.isfinite(hip).any() else np.zeros(2)
    TL = sl.torso_len(P)
    TL = TL if np.isfinite(TL) and TL > 0 else 1.0
    roll = np.radians(rng.uniform(-roll_deg, roll_deg))
    yaw = np.radians(rng.uniform(-yaw_deg, yaw_deg))
    sx = rng.uniform(1 - sx_range, 1 + sx_range) * np.cos(yaw)
    Q = P - c
    Q[..., 0] *= sx
    cs, sn = np.cos(roll), np.sin(roll)
    Q = np.stack([Q[..., 0] * cs - Q[..., 1] * sn, Q[..., 0] * sn + Q[..., 1] * cs], -1)
    Q += rng.normal(0, jitter * TL, Q.shape)
    x, z = W[..., 0].copy(), W[..., 2].copy()
    W[..., 0], W[..., 2] = x * np.cos(yaw) + z * np.sin(yaw), -x * np.sin(yaw) + z * np.cos(yaw)
    out = dict(r)
    out["P"], out["world"] = (Q + c).astype(np.float32), W.astype(np.float32)
    return out, dict(roll=float(np.degrees(roll)), yaw=float(np.degrees(yaw)), sx=float(sx))


def version_rng(key, g, seed=0):
    return np.random.default_rng(zlib.crc32(f"{key}|{g}|{seed}".encode()))


# ----------------------------------------------------------------------------- windows and reduced range
def rep_window(rep, n, fs, margin_s=0.5):
    """Rep onset..end plus up to margin_s of rest on each side, never past the neighbouring valleys (as Step 2a)."""
    m = int(round(margin_s * fs))
    w0, w1 = rep["i_start"] - m, rep["i_end"] + m
    if rep.get("i_valley_l", -1) >= 0:
        w0 = max(w0, rep["i_valley_l"])
    if rep.get("i_valley_r", -1) >= 0:
        w1 = min(w1, rep["i_valley_r"])
    return max(0, w0), min(n - 1, w1)


def window_map(rep, n, fs, margin_s, s=None, level=None, hold_frac=0.3):
    """Frame map of one sample. level=None: the plain window. level=f: the same rep with a REDUCED RANGE - the
    part of the movement above f x (peak - rest) is cut out and replaced by a short hold that blends the last
    frame before the cut into the first frame after it. Every frame is a real recorded posture, so the mistake
    (bent elbow, shrug, lean, elbow off the body...) stays in the data while only the range shrinks.
    Returns (ia, ib, w, (start, peak, end), duration_frames): value_k = (1-w_k) * A[ia_k] + w_k * A[ib_k]."""
    w0, w1 = rep_window(rep, n, fs, margin_s)
    i0, ip, i1 = rep["i_start"], rep["i_peak"], rep["i_end"]
    if level is None or s is None:
        ia = np.arange(w0, w1 + 1)
        return ia, ia, np.zeros(len(ia)), (i0 - w0, ip - w0, i1 - w0), i1 - i0
    base = min(s[i0], s[i1])
    L = base + level * (s[ip] - base)
    up = np.arange(i0, ip + 1)
    k = np.flatnonzero(s[up] >= L)
    t_up = int(up[k[0]]) if len(k) else ip
    dn = np.arange(ip, i1 + 1)
    k = np.flatnonzero(s[dn] >= L)
    t_dn = int(dn[k[-1]]) if len(k) else ip
    h = max(3, int(round(hold_frac * (t_dn - t_up))))
    seg1, seg3 = np.arange(w0, t_up + 1), np.arange(t_dn, w1 + 1)
    ia = np.concatenate([seg1, np.full(h, t_up), seg3])
    ib = np.concatenate([seg1, np.full(h, t_dn), seg3])
    w = np.concatenate([np.zeros(len(seg1)), np.linspace(0, 1, h + 2)[1:-1], np.zeros(len(seg3))])
    start, peak, end = i0 - w0, len(seg1) + h // 2, len(seg1) + h + (i1 - t_dn)
    return ia, ib, w, (start, peak, end), end - start


# ----------------------------------------------------------------------------- per-rep features
def angle_matched(sig, rep, ex, levels=(60, 90)):
    """Shoulder hike / ear-shoulder gap when the arm PASSES 60 deg and 90 deg on the way up (vs the rep start), and
    the slope of hike against arm elevation (as Step 2a). v3 adds neck_ratio and hike3d at the same angles."""
    keys = {"hike": "hike", "earsh": "ear_sh"}
    if "neck_ratio" in sig:
        keys.update(neckr="neck_ratio", hike3d="hike3d")
    if "sil_neck_a" in sig:
        keys.update(silneck="sil_neck_a")
    out = {f"{k}_at{L}": np.nan for k in keys for L in levels}
    out["hike_slope"] = np.nan
    if ex not in ("e1", "e2"):
        return out
    e = np.asarray(sig["elev_a"] if ex == "e2" else sig["elev_est_a"], float)
    i0, ip = rep["i_start"], rep["i_peak"]
    up = e[i0:ip + 1]
    for L in levels:
        k = np.flatnonzero(up >= L)
        if len(k) and k[0] > 0:
            j = i0 + int(k[0])
            f = (L - e[j - 1]) / (e[j] - e[j - 1]) if e[j] != e[j - 1] else 1.0
            for short, src in keys.items():
                h = np.asarray(sig[src], float)
                out[f"{short}_at{L}"] = h[j - 1] + f * (h[j] - h[j - 1]) - h[i0]
    h = np.asarray(sig["hike"], float)
    hs = h[i0:ip + 1]
    m = np.isfinite(up) & np.isfinite(hs)
    if m.sum() >= 5 and np.ptp(up[m]) > 20:
        out["hike_slope"] = float(np.polyfit(up[m], hs[m], 1)[0] * 90.0)
    return out


def rest_angles(elev, start, end):
    """Lowest arm elevation in the rest just before (start) and just after (end) the rep, inside the window."""
    rb = _nanmin(elev[: start + 1])
    ra = _nanmin(elev[end:]) if end < len(elev) else _nanmin(elev[-1:])
    return rb, ra


def features_v3(sm, ex, marks, fs):
    """Per-rep features computed on one (possibly augmented / reduced-range) sample window.
    sm: dict of per-frame signals on the window; marks = (start, peak, end) inside the window."""
    st, pk, en = marks
    rep = dict(i_start=st, i_peak=pk, i_end=en, i_valley_l=-1, i_valley_r=-1,
               amp=float(sm["_count"][pk] - min(sm["_count"][st], sm["_count"][en])))
    f = sl.rep_features(sm, ex, rep, fs)
    f.update(angle_matched(sm, rep, ex))
    rb, ra = rest_angles(sm[ELEV_KEY[ex]], st, en)
    f.update(rest_before=rb, rest_after=ra, rest_max=np.nanmax([rb, ra]) if np.isfinite([rb, ra]).any() else np.nan)
    seg = slice(st, en + 1)
    f.update(wr_dz_peak=float(sm["wr_dz_a"][pk]), el_dz_mean=_nanmean(sm["el_dz_a"][seg]),
             fa_ratio_min=_nanmin(sm["fa_ratio_a"][seg]), rot3d_peak=float(sm["rot3d_a"][pk]))
    for k in BASE_ANGLES + BASE_EXTRA[ex] + BASE_NEW[ex]:
        v = sm[f"{k}_rel"]
        f[f"{k}_relpeak"] = float(v[pk])
        f[f"{k}_relmax"] = _nanmax(np.abs(v[seg]))

    def d0(k):
        v = np.asarray(sm[k], float)
        return v - _nanmean(v[:max(2, st)])

    if ex in SHLD_EX:
        nr, h3 = np.asarray(sm["neck_ratio"], float), np.asarray(sm["hike3d"], float)
        f.update(neck_ratio_min=_nanmin(nr[seg]), neck_ratio_delta=float(nr[pk] - nr[st]),
                 neck_ratio_d0min=_nanmin(d0("neck_ratio")[seg]), hike3d_delta=float(h3[pk] - h3[st]),
                 hike3d_d0max=_nanmax(d0("hike3d")[seg]), hike_d0max=_nanmax(d0("hike")[seg]),
                 ear_sh_d0min=_nanmin(d0("ear_sh")[seg]))
    if ex in GAP_EX:
        for k in ("ua_abd", "ua_abd3d"):
            v = np.asarray(sm[k], float)
            f.update({f"{k}_max": _nanmax(v[seg]), f"{k}_mean": _nanmean(v[seg]), f"{k}_delta": float(v[pk] - v[st]),
                      f"{k}_d0max": _nanmax(d0(k)[seg])})
        f["el_out_d0max"] = _nanmax(d0("el_out")[seg])
    for k in [k for k in f if k.endswith("_bottom") or k.endswith("_rom")]:
        f.pop(k)                                          # need neighbouring valleys: replaced by rest_* above
    return f


PHASE_SIGNALS = {   # (signal, statistic) measured separately on the way up/out and on the way down/back
    "e1": [("elbow3d_a", "min"), ("elbow3d_o", "min"), ("elbow2d_a", "min"), ("stick_tilt", "absmax"), ("hike", "max")],
    "e2": [("elbow2d_a", "min"), ("elbow3d_a", "min"), ("lean_to_arm", "absmax"), ("hike", "max"), ("ear_sh", "min")],
    "e3": [("el_out", "max"), ("ua_abd", "max"), ("ua_abd3d", "max"), ("sil_gap_mean", "max"), ("sil_gap85", "max"),
           ("sil_contact", "min"), ("elev_a", "max")],
}
BEND_SIGNALS = {"e1": ["elbow3d_a", "elbow2d_a"], "e2": ["elbow2d_a", "elbow3d_a"], "e3": []}


def features_v4(sm, ex, marks, fs):
    """v3 features + PHASE features (ph_*: the way up/out and down/back separately; ph_top_bend_*: elbow angle at
    the start minus at the top, i.e. straight at the start but bent at the top) + GATED SHRUG features (shg_*: rise
    of the shoulder relative to the rep start while the arm is still below GATE_DEG) + SILHOUETTE features (sil*)."""
    f = features_v3(sm, ex, marks, fs)
    st, pk, en = marks
    seg = slice(st, en + 1)
    sig = lambda k: np.asarray(sm[k], float)
    for k, how in PHASE_SIGNALS[ex]:
        if k not in sm:
            continue
        v = sig(k)
        for ph, part in (("up", v[st:pk + 1]), ("dn", v[pk:en + 1])):
            if how == "min":
                f[f"ph_{ph}_min_{k}"] = _nanmin(part)
            elif how == "max":
                f[f"ph_{ph}_max_{k}"] = _nanmax(part)
            else:
                f[f"ph_{ph}_absmax_{k}"] = _nanmax(np.abs(part - v[st]))
        if how == "max":
            f[f"ph_all_asym_{k}"] = f[f"ph_dn_max_{k}"] - f[f"ph_up_max_{k}"]
    for k in BEND_SIGNALS[ex]:
        v = sig(k)
        f[f"ph_top_bend_{k}"] = float(v[st] - v[pk])
        f[f"ph_up_bendmax_{k}"] = float(v[st] - _nanmin(v[st:pk + 1]))
    if ex in SHLD_EX:
        e = sig(GATE_KEY[ex])[seg]
        low = np.isfinite(e) & (e <= GATE_DEG)
        def d0(k):
            v = sig(k)
            return (v - _nanmean(v[:max(2, st)]))[seg]
        for k, short, fn in (("hike", "hike", _nanmax), ("hike3d", "hike3d", _nanmax), ("neck_ratio", "neckr", _nanmin),
                             ("ear_sh", "earsh", _nanmin), ("sil_neck_a", "silneck", _nanmin)):
            if k in sm:
                f[f"shg_{short}_{'max' if fn is _nanmax else 'min'}"] = fn(d0(k)[low]) if low.any() else np.nan
        h = d0("hike")
        if low.sum() >= 5 and np.ptp(e[low]) > 15:
            f["shg_hike_slope"] = float(np.polyfit(e[low], h[low], 1)[0] * 90.0)
        else:
            f["shg_hike_slope"] = np.nan
        if "sil_neck_a" in sm:
            v = sig("sil_neck_a")
            f.update(sil_neck_a_d0min=_nanmin((v - _nanmean(v[:max(2, st)]))[seg]),
                     sil_shtop_a_d0max=_nanmax((sig("sil_shtop_a") - _nanmean(sig("sil_shtop_a")[:max(2, st)]))[seg]),
                     sil_neck_ratio_min=_nanmin(sig("sil_neck_ratio")[seg]))
    if ex in GAP_EX and "sil_gap_mean" in sm:
        f.update(sil_gap_mean_max=_nanmax(sig("sil_gap_mean")[seg]), sil_gap_mean_mean=_nanmean(sig("sil_gap_mean")[seg]),
                 sil_gap_min_mean=_nanmean(sig("sil_gap_min")[seg]), sil_gap85_max=_nanmax(sig("sil_gap85")[seg]),
                 sil_contact_mean=_nanmean(sig("sil_contact")[seg]), sil_contact_min=_nanmin(sig("sil_contact")[seg]))
    if "sil_ok" in sm:
        f["sil_ok_mean"] = _nanmean(sig("sil_ok")[seg])
    return f


# ----------------------------------------------------------------------------- arm choice (as Step 2a)
def choose_arm(r, ex, side=None, single_arm=True):
    ev = sl.side_evidence(r)
    ml, mr = ev["motion_left"], ev["motion_right"]
    if single_arm:
        moving = "left" if ml >= mr else "right"
        clear = max(ml, mr) / max(min(ml, mr), 1e-6) >= 1.5
        arm = moving if (clear or side is None) else side
        return arm, bool(side is not None and clear and moving != side)
    if side is not None:
        return side, False
    el, er = ev["elev95_left"], ev["elev95_right"]
    return ("left" if (el == el and er == er and el <= er) else "right"), False


# ----------------------------------------------------------------------------- one video -> all samples
def _frame_matrix(r, sig, scal, ex, arm, b0, b1, count_key, silsig):
    """Per-frame matrix of every stored channel that does not depend on the sample (all but '_d0', gated and
    the duration), its column names, and the per-frame signal dict used for the features, for one version."""
    allsig = dict(sig)
    allsig.update(depth_signals(r, arm, scal["out_sign"]))
    allsig.update(extra_signals(r, arm, scal["out_sign"]))
    allsig.update(silsig)
    g = channel_groups(ex)
    C = canonical_coords(r, arm)
    plain = g["angles"] + g["depth"] + [n for n in g["shld"] + g["gap"] + g["sil"] if not n.endswith("_d0")]
    A = np.stack([np.asarray(allsig[k], float) / scale_of(k) for k in plain], 1)
    pid = {p: i for i, p in enumerate(POINT_NAMES)}
    cols = [2 * pid[p] + j for p in BASE_POINTS for j in (0, 1)]
    Cb = C[:, cols]
    bC = np.nanmedian(Cb[b0:b1], axis=0) if np.isfinite(Cb[b0:b1]).any() else np.nanmedian(Cb, axis=0)
    base_keys = BASE_ANGLES + BASE_EXTRA[ex] + BASE_NEW[ex]
    Ab = np.stack([np.asarray(allsig[k], float) for k in base_keys], 1)
    bA = np.nanmedian(Ab[b0:b1], axis=0) if np.isfinite(Ab[b0:b1]).any() else np.nanmedian(Ab, axis=0)
    bA = np.where(np.isfinite(bA), bA, 0.0)
    bC = np.where(np.isfinite(bC), bC, 0.0)
    rel = (Ab - bA) / np.array([scale_of(k) for k in base_keys])
    M = _fill_cols(np.concatenate([C, A, Cb - bC, rel], 1))
    names = list(COORD_NAMES) + plain + g["base_pts"] + [f"{k}_rel" for k in base_keys]
    sd = dict(allsig)
    for j, k in enumerate(base_keys):
        sd[f"{k}_rel"] = Ab[:, j] - bA[j]
    sd["_count"] = sig[count_key]
    keys = list(sd)
    raw = np.stack([np.asarray(sd[k], float) for k in keys], 1)
    S = _fill_cols(raw)
    S[:, ~np.isfinite(raw).any(0)] = np.nan          # a signal missing in the whole video (e.g. no silhouette) stays missing
    return M, names, S, keys


def _sample_channels(Mw, names, ex, start):
    """Stored channels of one sample window (L, C-1) in channel_names(ex) order: adds the '_d0' channels
    (value minus its mean over the rest frames before the rep starts) and the gated '_g' channels (the same
    relative value, frozen while the arm is above GATE_DEG)."""
    col = {n: j for j, n in enumerate(names)}
    k0 = max(2, int(start))
    gate = col.get(GATE_KEY.get(ex))
    hold = None
    if gate is not None:
        low = Mw[:, gate] * scale_of(GATE_KEY[ex]) <= GATE_DEG
        hold = np.maximum.accumulate(np.where(low, np.arange(len(Mw)), 0))
    out = []
    for n in channel_names(ex)[:-1]:
        if n in col:
            out.append(Mw[:, col[n]])
        elif n.endswith("_g"):                                  # gated shrug channel
            v = Mw[:, col["sil_neck_a" if n == "sil_neck_g" else n[:-2]]]
            v = v - v[:k0].mean()
            out.append(v[hold] if hold is not None else v)
        else:                                                   # '_d0' channel
            v = Mw[:, col[n[:-3]]]
            out.append(v - v[:k0].mean())
    return np.stack(out, 1)


def analyze_video(d, ex, side=None, single_arm=True, fs=30.0, max_gap_s=0.5, seg_cfg=None, T=64, margin_s=0.5,
                  min_valid=0.8, n_geo=0, geo_cfg=None, rr_levels=(), base_cfg=None, key="", seed=0):
    r = sl.resample(d, fs, max_gap_s)
    if r is None:
        return None
    arm, conflict = choose_arm(r, ex, side, single_arm)
    sig, scal = sl.compute_signals(r, ex, arm)
    count_key = sl.COUNT_SIGNAL[ex]
    reps, s = sl.segment_reps(sig[count_key], fs, **(seg_cfg or {}))
    n = len(r["t"])
    b0, b1, bsrc = baseline_frames(reps, s, n, fs, **(base_cfg or {}))
    ek = ELEV_KEY[ex]
    rows = []
    for k, rp in enumerate(reps):
        f = sl.rep_features(sig, ex, rp, fs, valid=r["valid"])
        f.update(angle_matched(sig, rp, ex))
        w0, w1 = rep_window(rp, n, fs, margin_s)
        rb, ra = rest_angles(np.asarray(sig[ek], float)[w0:w1 + 1], rp["i_start"] - w0, rp["i_end"] - w0)
        usable = bool((not rp["partial"]) and f.get("valid_frac", 1.0) >= min_valid and w1 - w0 >= 3)
        rows.append(dict(rep=k + 1, partial=rp["partial"], usable=usable, i_start=rp["i_start"], i_peak=rp["i_peak"],
                         i_end=rp["i_end"], t_start=float(r["t"][rp["i_start"]]), t_peak=float(r["t"][rp["i_peak"]]),
                         t_end=float(r["t"][rp["i_end"]]), rest_before=rb, rest_after=ra,
                         rest_max=np.nanmax([rb, ra]) if np.isfinite([rb, ra]).any() else np.nan, **f))
    use = [i for i, row in enumerate(rows) if row["usable"]]
    silsig = sil_signals(d, r, arm)
    sil_key = "sil_gap_mean" if ex in GAP_EX else "sil_neck_a"
    sil_rate = float(np.isfinite(silsig[sil_key]).mean()) if len(silsig[sil_key]) else 0.0
    versions, geo_params = [(r, sig, scal)], []
    for g in range(1, n_geo + 1):
        rg, prm = geo_version(r, version_rng(key, g, seed), **(geo_cfg or {}))
        sg, scg = sl.compute_signals(rg, ex, arm)
        versions.append((rg, sg, scg))
        geo_params.append(prm)
    levels = [None] + list(rr_levels)
    s_full = sl.fill_nan(s) if s is not None else None
    X, F, fnames = None, None, None
    for g, (rv, sv, scv) in enumerate(versions):
        M, names, S, keys = _frame_matrix(rv, sv, scv, ex, arm, b0, b1, count_key, silsig)
        for ri, lev in enumerate(levels):
            for j, i in enumerate(use):
                ia, ib, w, marks, dur = window_map(reps[i], n, fs, margin_s, s_full, lev)
                xs = to_T(_sample_channels(apply_map(M, ia, ib, w), names, ex, marks[0]), T)
                fd = features_v4(dict(zip(keys, apply_map(S, ia, ib, w).T)), ex, marks, fs)
                if X is None:
                    fnames = list(fd)
                    X = np.zeros((len(versions), len(levels), len(use), xs.shape[1] + 1, T), np.float32)
                    F = np.full((len(versions), len(levels), len(use), len(fnames)), np.nan, np.float32)
                X[g, ri, j, :-1] = xs.T
                X[g, ri, j, -1] = np.log(max(dur / fs, 0.1))
                F[g, ri, j] = [fd.get(k, np.nan) for k in fnames]
    return dict(r=r, sig=sig, scal=scal, arm=arm, side_conflict=conflict, reps=reps, s=s, rows=rows, use=use,
                X=X, F=F, feature_names=fnames, baseline=(b0, b1, bsrc), geo_params=geo_params, silsig=silsig,
                sil_rate=sil_rate)


analyze_video_v2 = analyze_video          # name used by the Step-2b demo code


# ----------------------------------------------------------------------------- ROCKET-style random convolution features
class RandomConvFeatures:
    """Multivariate ROCKET-style transform: random kernels (length 9, random weights, dilation, bias, channel
    subset). Pooled features per kernel: 'ppv' share of positive values, 'max', 'mpv' mean of positive values,
    'mipv' mean index of the positive values, 'lspv' longest stretch of positive values (the last three as in
    MultiROCKET). Uses PyTorch (GPU) when available, NumPy otherwise; same kernels either way."""

    def __init__(self, C, T, kernels_per_dilation=1000, dilations=(1, 2, 3, 5, 7), klen=9, seed=0,
                 pools=("ppv", "max")):
        rng = np.random.default_rng(seed)
        self.klen, self.layers, self.pools, self.T = klen, [], tuple(pools), T
        for d in dilations:
            if (klen - 1) * d + 1 > T:
                continue
            K = kernels_per_dilation
            W = rng.normal(0, 1, (C, klen, K)).astype(np.float32)
            n_ch = np.clip((2 ** rng.uniform(0, np.log2(min(C, 9) + 1), K)).astype(int), 1, C)
            mask = np.zeros((C, K), np.float32)
            for k in range(K):
                mask[rng.choice(C, n_ch[k], replace=False), k] = 1.0
            W = (W - W.mean(1, keepdims=True)) * mask[:, None, :]
            self.layers.append((d, W.reshape(C * klen, K), rng.uniform(-1, 1, K).astype(np.float32)))
        self.n_features = len(self.pools) * sum(W.shape[1] for _, W, _ in self.layers)

    def _pool(self, Z, out, col, K):
        """Z: (B, T, K) NumPy."""
        T = Z.shape[1]
        pos = Z > 0
        for p in self.pools:
            if p == "ppv":
                v = pos.mean(1)
            elif p == "max":
                v = Z.max(1)
            elif p == "mpv":
                v = np.clip(Z, 0, None).sum(1) / np.maximum(pos.sum(1), 1)
            elif p == "mipv":
                cnt = pos.sum(1)
                v = np.where(cnt > 0, (pos * np.arange(T)[None, :, None]).sum(1) / np.maximum(cnt, 1) / max(T - 1, 1), -1.0)
            else:                                              # lspv
                run = np.zeros((Z.shape[0], K), np.float32)
                best = np.zeros_like(run)
                for t in range(T):
                    run = (run + 1) * pos[:, t]
                    best = np.maximum(best, run)
                v = best / T
            out[:, col:col + K] = v
            col += K
        return col

    def transform(self, X, batch=256, device=None):
        try:
            import torch
            if device is None:
                device = "cuda" if torch.cuda.is_available() else None
        except ImportError:
            torch = None
        if torch is not None and device is not None:
            return self._transform_torch(X, torch, device, batch)
        N, C, T = X.shape
        out, col = np.empty((N, self.n_features), np.float32), 0
        for d, W, b in self.layers:
            pad = (self.klen - 1) * d // 2
            Xp = np.pad(X.astype(np.float32), ((0, 0), (0, 0), (pad, pad)))
            idx = np.arange(T)[:, None] + d * np.arange(self.klen)[None, :]
            K = W.shape[1]
            for s in range(0, N, batch):
                P = Xp[s:s + batch][:, :, idx].transpose(0, 2, 1, 3).reshape(-1, T, C * self.klen)
                self._pool(P @ W + b, out[s:s + batch], col, K)
            col += len(self.pools) * K
        return out

    def _transform_torch(self, X, torch, device, batch):
        N, C, T = X.shape
        out, col = np.empty((N, self.n_features), np.float32), 0
        with torch.no_grad():
            tidx = torch.arange(T, device=device).float()
            for d, W, b in self.layers:
                K = W.shape[1]
                w = torch.from_numpy(np.ascontiguousarray(W.reshape(C, self.klen, K).transpose(2, 0, 1))).to(device)
                bb = torch.from_numpy(b).to(device)
                pad = (self.klen - 1) * d // 2
                for s in range(0, N, batch):
                    xb = torch.from_numpy(np.ascontiguousarray(X[s:s + batch], dtype=np.float32)).to(device)
                    Z = torch.nn.functional.conv1d(xb, w, bb, padding=pad, dilation=d)      # (B, K, T)
                    pos = (Z > 0).float()
                    c = col
                    for p in self.pools:
                        if p == "ppv":
                            v = pos.mean(-1)
                        elif p == "max":
                            v = Z.amax(-1)
                        elif p == "mpv":
                            v = Z.clamp(min=0).sum(-1) / pos.sum(-1).clamp(min=1)
                        elif p == "mipv":
                            cnt = pos.sum(-1)
                            v = torch.where(cnt > 0, (pos * tidx).sum(-1) / cnt.clamp(min=1) / max(T - 1, 1),
                                            torch.full_like(cnt, -1.0))
                        else:                                  # lspv
                            run = torch.zeros_like(pos[..., 0])
                            best = torch.zeros_like(run)
                            for t in range(T):
                                run = (run + 1) * pos[..., t]
                                best = torch.where(run > best, run, best)
                            v = best / T
                        out[s:s + batch, c:c + K] = v.cpu().numpy()
                        c += K
                col += len(self.pools) * K
        return out
