#!/usr/bin/env python3
"""Extract MediaPipe Pose landmarks AND silhouette measurements from ONE video into a compressed .npz
(pose_worker v2 = Step-1 worker v1 + body silhouette).

Runs as its own process, so a crash or hang inside MediaPipe never kills the notebook kernel.
Output, written atomically (a file that exists is always complete):
  lm        (T,33,5) float32  x, y (fraction of width/height), z, visibility, presence  (NaN = nobody found)
  world     (T,33,3) float32  metres, hip-centred (MediaPipe world landmarks)
  t_ms      (T,)     float64  time of each analysed frame in the video
  frame_idx (T,)     int32    index of that frame in the video
  n_poses   (T,)     int8     people detected in that frame
  sil       (T,2,K)  float16  silhouette measurements per frame for the LEFT (0) and RIGHT (1) arm, in shoulder
                              widths (see SIL_NAMES); NaN when there is no mask or no person
  thumbs    (N,h,w)  uint8    small copies of the person mask (0-255) every --thumb-every frames, for visual checks
  thumb_idx (N,)     int32    index (into the analysed frames) of each thumbnail
  meta      JSON string: fps, frame size, extractor settings, versions, detection rate, timing, SIL_NAMES

The silhouette is the person mask MediaPipe computes together with the pose. Only a few numbers per frame are
kept (no images of the person except the tiny mask thumbnails):
  gapNN    background between the upper arm and the side of the body, measured across the body at NN % of
           the way from the shoulder to the elbow (0 = arm touching the body/clothes, in shoulder widths)
  shtopKK  height of the shoulder outline above the shoulder line, KK % of the way from the neck to the
           shoulder joint (the trapezius / top of the shoulder; rises in a shrug)
  neckKK   distance from that shoulder outline up to the ear (shrinks in a shrug)
  mask_ok  1 if the mask covers the middle of the torso (the mask is usable)
Exit codes: 0 ok | 2 unreadable video | 3 error while processing | 4 MediaPipe import/setup error
"""
import argparse, json, os, sys, time, traceback
from datetime import datetime, timezone

WORKER_VERSION = 2
GAP_FRACS = (0.40, 0.55, 0.70, 0.85)
TOP_FRACS = (0.65, 0.80)
SIL_NAMES = ([f"gap{int(f * 100)}" for f in GAP_FRACS] + [f"shtop{int(k * 100)}" for k in TOP_FRACS]
             + [f"neck{int(k * 100)}" for k in TOP_FRACS] + ["mask_ok"])
ARMS = ((11, 13, 7), (12, 14, 8))            # (shoulder, elbow, ear) of the person's LEFT and RIGHT side


def lm_array(landmarks, cols):
    import numpy as np
    out = np.full((33, cols), np.nan, np.float32)
    for i, l in enumerate(list(landmarks)[:33]):
        vals = (l.x, l.y, l.z, getattr(l, "visibility", None), getattr(l, "presence", None))[:cols]
        out[i] = [np.nan if v is None else float(v) for v in vals]
    return out


def mask_array(m):
    """MediaPipe mask (mp.Image or array) -> 2-D float32 array in [0, 1], or None."""
    import numpy as np
    if m is None:
        return None
    a = m.numpy_view() if hasattr(m, "numpy_view") else m
    a = np.asarray(a, np.float32)
    if a.ndim == 3:
        a = a[..., 0]
    return a if a.ndim == 2 and a.size else None


def _march(mask, p, d, length):
    """Mask values (bool) along p + t*d, t = 0..length pixels (nearest pixel; outside the image = background)."""
    import numpy as np
    H, W = mask.shape
    t = np.arange(0, int(max(1, length)) + 1, dtype=np.float32)
    x = np.rint(p[0] + t * d[0]).astype(np.int64)
    y = np.rint(p[1] + t * d[1]).astype(np.int64)
    inside = (x >= 0) & (x < W) & (y >= 0) & (y < H)
    v = np.zeros(len(t), bool)
    v[inside] = mask[y[inside], x[inside]] > 0.5
    return v


def sil_features(mask, lm):
    """(2, len(SIL_NAMES)) silhouette measurements for the left and right arm (shoulder widths), NaN if impossible."""
    import numpy as np
    out = np.full((2, len(SIL_NAMES)), np.nan, np.float32)
    if mask is None or lm is None or not np.isfinite(lm[[11, 12, 13, 14, 23, 24], :2]).all():
        return out
    H, W = mask.shape
    P = lm[:, :2].astype(np.float64) * np.array([W, H], np.float64)
    sh_mid, hip_mid = 0.5 * (P[11] + P[12]), 0.5 * (P[23] + P[24])
    up = sh_mid - hip_mid
    n = np.linalg.norm(up)
    SW = np.linalg.norm(P[11] - P[12])
    if n < 1e-6 or SW < 4:
        return out
    up = up / n
    lat = np.array([-up[1], up[0]])
    c = 0.5 * (sh_mid + hip_mid)
    ok = float(_march(mask, c, up, 0)[0])
    for s, (i_sh, i_el, i_ear) in enumerate(ARMS):
        S, E = P[i_sh], P[i_el]
        inward = lat if np.dot(sh_mid - S, lat) > 0 else -lat
        L = 0.9 * SW
        vals = []
        for f in GAP_FRACS:                       # background between the upper arm and the body
            v = _march(mask, S + f * (E - S), inward, L)
            bg = np.flatnonzero(~v)
            if not len(bg):
                vals.append(0.0)                  # never leaves the person: arm against the body (or clothes)
                continue
            i0 = int(bg[0])
            back = np.flatnonzero(v[i0:])
            vals.append((int(back[0]) if len(back) else len(v) - i0) / SW)
        tops, necks = [], []
        for k in TOP_FRACS:                       # shoulder outline above the shoulder line
            p0 = sh_mid + k * (S - sh_mid)
            v = _march(mask, p0, up, 0.6 * SW)
            bg = np.flatnonzero(~v)
            if not len(bg):                       # hair / raised arm: no outline found
                tops.append(np.nan)
                necks.append(np.nan)
                continue
            h = float(bg[0])
            tops.append(h / SW)
            ear = P[i_ear]
            necks.append(float(np.dot(ear - (p0 + h * up), up)) / SW if np.isfinite(ear).all() else np.nan)
        out[s] = vals + tops + necks + [ok]
    return out


def make_backend(mp, args):
    import numpy as np
    nan_w = np.full((33, 3), np.nan, np.float32)
    if args.backend == "tasks":
        try:
            BaseOptions, vision = mp.tasks.BaseOptions, mp.tasks.vision
        except AttributeError:
            from mediapipe.tasks.python import BaseOptions, vision
        opts = vision.PoseLandmarkerOptions(
            base_options=BaseOptions(model_asset_path=args.model),
            running_mode=vision.RunningMode.VIDEO, num_poses=args.num_poses,
            min_pose_detection_confidence=args.det_conf, min_pose_presence_confidence=args.pres_conf,
            min_tracking_confidence=args.track_conf, output_segmentation_masks=bool(args.seg))
        landmarker = vision.PoseLandmarker.create_from_options(opts)

        def infer(rgb, ts_ms):
            res = landmarker.detect_for_video(mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb), ts_ms)
            pls, wls = list(res.pose_landmarks or []), list(res.pose_world_landmarks or [])
            masks = list(getattr(res, "segmentation_masks", None) or [])
            return [(lm_array(pl, 5), lm_array(wls[i], 3) if i < len(wls) else nan_w,
                     masks[i] if i < len(masks) else None) for i, pl in enumerate(pls)]
        return infer, landmarker.close

    pose = mp.solutions.pose.Pose(static_image_mode=False, model_complexity=args.legacy_complexity,
                                  smooth_landmarks=True, enable_segmentation=bool(args.seg),
                                  min_detection_confidence=args.det_conf, min_tracking_confidence=args.track_conf)

    def infer(rgb, ts_ms):
        res = pose.process(rgb)
        if res.pose_landmarks is None:
            return []
        w = lm_array(res.pose_world_landmarks.landmark, 3) if res.pose_world_landmarks is not None else nan_w
        return [(lm_array(res.pose_landmarks.landmark, 5), w, getattr(res, "segmentation_mask", None))]
    return infer, pose.close


def pick_pose(poses, prev):
    """Several people: keep the one closest to last frame's person, otherwise the biggest torso."""
    import numpy as np
    if len(poses) == 1:
        return 0
    try:
        centers, sizes = [], []
        for lm, _, _ in poses:
            sh, hp = lm[[11, 12], :2].mean(0), lm[[23, 24], :2].mean(0)
            centers.append((sh + hp) / 2)
            sizes.append(np.linalg.norm(sh - hp))
        if prev is not None:
            return int(np.nanargmin([np.linalg.norm(c - prev) for c in centers]))
        return int(np.nanargmax(sizes))
    except ValueError:
        return 0


def main():
    ap = argparse.ArgumentParser(description="MediaPipe pose + silhouette extraction for one video")
    ap.add_argument("--video", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--model", default="")
    ap.add_argument("--backend", default="tasks", choices=["tasks", "legacy"])
    ap.add_argument("--legacy-complexity", type=int, default=1)
    ap.add_argument("--target-fps", type=float, default=30.0)
    ap.add_argument("--max-side", type=int, default=1280)
    ap.add_argument("--num-poses", type=int, default=1)
    ap.add_argument("--det-conf", type=float, default=0.5)
    ap.add_argument("--pres-conf", type=float, default=0.5)
    ap.add_argument("--track-conf", type=float, default=0.5)
    ap.add_argument("--seg", type=int, default=1, help="1 = also compute the silhouette measurements")
    ap.add_argument("--thumb-every", type=int, default=30, help="keep a small mask every N analysed frames")
    ap.add_argument("--thumb-h", type=int, default=96)
    ap.add_argument("--max-thumbs", type=int, default=120)
    ap.add_argument("--max-frames", type=int, default=0, help="stop after N analysed frames (benchmark)")
    args = ap.parse_args()
    t0 = time.time()

    import numpy as np
    import cv2
    cv2.setNumThreads(1)
    try:
        import mediapipe as mp
        infer, close = make_backend(mp, args)
    except Exception as e:
        print(json.dumps(dict(status="setup_error", error=f"{type(e).__name__}: {e}")), flush=True)
        return 4

    cap = cv2.VideoCapture(args.video)
    if not cap.isOpened():
        close()
        print(json.dumps(dict(status="unreadable", error="OpenCV cannot open the file")), flush=True)
        return 2
    src_fps = cap.get(cv2.CAP_PROP_FPS) or 0.0
    fps_valid = 1.0 < src_fps < 1000.0
    fps = src_fps if fps_valid else 30.0
    step = max(1, int(round(fps / args.target_fps))) if args.target_fps > 0 else 1
    n_meta = int(cap.get(cv2.CAP_PROP_FRAME_COUNT) or 0)
    nan_lm = np.full((33, 5), np.nan, np.float32)
    nan_w = np.full((33, 3), np.nan, np.float32)
    nan_s = np.full((2, len(SIL_NAMES)), np.nan, np.float32)
    LM, WL, SIL, T_IDX, T_POS, FI, NP, TH, TH_I = [], [], [], [], [], [], [], [], []
    W = H = None
    idx, last_ts, prev = -1, -1, None
    n_mask, t_sil = 0, 0.0
    t_loop = time.time()
    try:
        while True:
            if not cap.grab():
                break
            idx += 1
            if idx % step:
                continue
            ok, frame = cap.retrieve()
            if not ok or frame is None:
                continue
            if W is None:
                H, W = frame.shape[:2]
            if args.max_side and max(frame.shape[:2]) > args.max_side:
                sc = args.max_side / max(frame.shape[:2])
                frame = cv2.resize(frame, (int(round(frame.shape[1] * sc)), int(round(frame.shape[0] * sc))),
                                   interpolation=cv2.INTER_AREA)
            rgb = np.ascontiguousarray(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))
            t_idx = idx * 1000.0 / fps
            ts = max(last_ts + 1, int(round(t_idx)))      # VIDEO mode needs strictly increasing timestamps
            last_ts = ts
            poses = infer(rgb, ts)
            mask = None
            if poses:
                lm, wl, m = poses[pick_pose(poses, prev)]
                prev = (lm[[11, 12], :2].mean(0) + lm[[23, 24], :2].mean(0)) / 2
                if args.seg:
                    ts0 = time.time()
                    mask = mask_array(m)
                    s = sil_features(mask, lm)
                    t_sil += time.time() - ts0
                    n_mask += mask is not None
                else:
                    s = nan_s
            else:
                lm, wl, s = nan_lm, nan_w, nan_s
            k = len(FI)
            if args.seg and args.thumb_every and k % args.thumb_every == 0 and len(TH) < args.max_thumbs:
                th_w = max(8, int(round(args.thumb_h * rgb.shape[1] / rgb.shape[0])))
                TH.append(cv2.resize((mask * 255).astype(np.uint8), (th_w, args.thumb_h), interpolation=cv2.INTER_AREA)
                          if mask is not None else np.zeros((args.thumb_h, th_w), np.uint8))
                TH_I.append(k)
            LM.append(lm); WL.append(wl); SIL.append(s); T_IDX.append(t_idx)
            T_POS.append(cap.get(cv2.CAP_PROP_POS_MSEC)); FI.append(idx); NP.append(len(poses))
            if args.max_frames and len(FI) >= args.max_frames:
                break
    except Exception as e:
        cap.release(); close()
        print(json.dumps(dict(status="error", error=f"{type(e).__name__}: {e}",
                              trace=traceback.format_exc()[-1500:])), flush=True)
        return 3
    cap.release(); close()
    loop_s = time.time() - t_loop
    if not FI:
        print(json.dumps(dict(status="unreadable", error="no frame could be decoded")), flush=True)
        return 2

    t_idx = np.asarray(T_IDX, np.float64)
    t_pos = np.asarray(T_POS, np.float64)
    span_idx, span_pos = t_idx[-1] - t_idx[0], t_pos[-1] - t_pos[0]
    use_pos = bool(len(t_pos) > 2 and np.all(np.isfinite(t_pos)) and np.all(np.diff(t_pos) > 0)
                   and span_idx > 0 and abs(span_pos - span_idx) <= 0.25 * span_idx)
    t_ms = (t_pos - t_pos[0] + t_idx[0]) if use_pos else t_idx      # container timestamps handle variable-fps phones
    lm = np.stack(LM).astype(np.float32)
    wl = np.stack(WL).astype(np.float32)
    sil = np.stack(SIL).astype(np.float16)
    det = np.isfinite(lm[:, 0, 0])
    th = np.stack(TH) if TH else np.zeros((0, args.thumb_h, 8), np.uint8)
    meta = dict(worker_version=WORKER_VERSION, video=os.path.basename(args.video), backend=args.backend,
                src_bytes=os.path.getsize(args.video),
                model=(os.path.basename(args.model) if args.backend == "tasks" else f"legacy_c{args.legacy_complexity}"),
                mediapipe_version=getattr(mp, "__version__", "unknown"), target_fps=args.target_fps,
                max_side=args.max_side, num_poses=args.num_poses, det_conf=args.det_conf, pres_conf=args.pres_conf,
                track_conf=args.track_conf, src_fps=src_fps, fps_valid=fps_valid, step=step, eff_fps=fps / step,
                width=W, height=H, n_frames_meta=n_meta, n_frames_decoded=idx + 1, n_frames_analysed=len(FI),
                detect_rate=float(det.mean()), time_source="container_pts" if use_pos else "index_fps",
                seg=bool(args.seg), sil_names=SIL_NAMES, gap_fracs=list(GAP_FRACS), top_fracs=list(TOP_FRACS),
                mask_rate=float(n_mask / max(1, det.sum())), sil_ms_per_frame=round(1000.0 * t_sil / max(1, len(FI)), 2),
                seconds=round(time.time() - t0, 2), ms_per_frame=round(1000.0 * loop_s / len(FI), 2),
                truncated=bool(args.max_frames and len(FI) >= args.max_frames),
                created=datetime.now(timezone.utc).isoformat(timespec="seconds"))
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    tmp = args.out + ".part"
    with open(tmp, "wb") as f:
        np.savez_compressed(f, lm=lm, world=wl, t_ms=t_ms, frame_idx=np.asarray(FI, np.int32),
                            n_poses=np.asarray(NP, np.int8), sil=sil, thumbs=th,
                            thumb_idx=np.asarray(TH_I, np.int32), meta=np.array(json.dumps(meta)))
    os.replace(tmp, args.out)
    print(json.dumps(dict(status="ok", frames=len(FI), detect_rate=round(meta["detect_rate"], 4),
                          mask_rate=round(meta["mask_rate"], 4), seconds=meta["seconds"],
                          ms_per_frame=meta["ms_per_frame"])), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
