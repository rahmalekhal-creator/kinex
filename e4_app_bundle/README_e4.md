# Exercise 4 (hip): standing hip abduction — adding it to the app

The app already judges three **shoulder** exercises with `shoulder_app_bundle/` (e1–e3). This bundle adds a fourth
exercise, a **hip** exercise, with the same conventions: one ONNX file, one JSON config with the same keys, the same
MediaPipe model, the same rep segmentation and rep window. What is new is the leg geometry (`leg_ds.py`).

| id | body region | name | side asked | classes (output order: `models/e4_head.json` → `heads.e4.classes`) |
|---|---|---|---|---|
| e1 | Shoulder | stick elevation (both arms) | injured arm | good, elb, rngdown, imb |
| e2 | Shoulder | arm abduction | working arm | good, elb, rngdown, shld, lean |
| e3 | Shoulder | arm rotation, elbow at the side | working arm | good, wrong |
| **e4** | **Hip** | **standing hip abduction (chair support)** | **lifted leg** | **good, knee, leanin, leanout** |

e4 classes: **good**; **knee** = the knee of the lifted leg bends; **leanin** = the trunk tilts toward the lifted leg;
**leanout** = the trunk tilts away from it (toward the chair). A small lift is **not** a mistake class: the range is
checked by the **range rule** against a target angle the physiotherapist sets per patient (below), so a patient in an
early stage who lifts the leg a little with a good form is told "good form, lift a bit higher", not "wrong".

## Files
- `models/mt_e4.onnx` — the e4 network (≈1.3 MB; same size as `mt_e1–e3`, ≈1 ms per rep: `app_spec_e4.json` → `model.check.onnx_ms_per_rep_this_cpu`). Inputs `x` float32 (reps, 63, 64) and `f` float32
  (reps, 64); output `probs` (reps, 4). Normalisation, velocity channels and missing measures (NaN) are handled
  **inside** the file: pass raw values. Same interface as `mt_e1/e2/e3.onnx`. Its encoder is the shoulder network's
  encoder, frozen (see `app_spec_e4.json` → `model.check`); the file is self-contained.
- `models/e4_head.json` — `heads.e4`: `input_selection` (which stored channels go into `x`, in order),
  `stored_channels` (names of all stored channels), `features` (names of the columns of `f`, in order), `classes`,
  `needs_silhouette` (false); `analyze_video` (preprocessing settings); `range_rule`. Same keys as `mt_final.json` → `heads[ex]`.
- `models/e4_head.pt` + `reference_python/shoulder_mt.py` — the same network for PyTorch (Python reference only).
- `reference_python/leg_ds.py` — **the code to port**: leg signals, channels and per-rep measures.
  `shoulder_lib.py` / `shoulder_ds.py` — shared with e1–e3 (already ported for the shoulder exercises).
- `reference_python/reference_predict_e4.py` — the whole e4 chain on one recording (ONNX Runtime).
- `golden/e4__<video>.json` — real recordings with everything the Python pipeline computes for them.
- `app_spec_e4.json` — MediaPipe and camera settings, pipeline settings, feedback messages, range rule.
- `exercise_catalog.json` — the four exercises with body region (Shoulder / Hip), names, side question, patient
  instructions, model files: to seed the database and group the exercises in the physiotherapist's screens.

## The e4 pipeline (what the app must reproduce)
**Per camera frame** — exactly as e1–e3: MediaPipe Tasks **PoseLandmarker** (`pose_landmarker_full.task`, 1 person,
confidences 0.5/0.5/0.5, ~30 fps); keep the timestamp (ms), the 33 normalized landmarks (x, y, z, visibility, presence),
the 33 world landmarks, the frame width/height. **No segmentation mask** for e4. Image upright and **not mirrored**.
**Camera:** from the front, **the whole body including both feet** (the ankles are the main points; e1–e3 only need
the knees up), the chair beside the standing leg.

**Per recording / rep** (Python reference: `leg_ds.analyze_video(d, side=<lifted leg>, n_geo=0, rr_levels=())`)
1. `sl.resample` — 30 Hz grid, gaps > 0.5 s stay NaN (shared with e1–e3).
2. `lds.choose_leg` — the lifted leg = the ankle that moves most sideways; if the other leg clearly moves more than the
   chosen side, it is used and `side_conflict` is reported (show `messages.side_conflict`).
3. `lds.compute_signals` — per-frame leg signals (new): leg and thigh angle away from the trunk's own axis
   (`abd_leg_a` = **count signal**), knee angles 2-D/3-D (both legs), sideways trunk lean toward the lifted leg,
   pelvis and shoulder tilt, ankle height and sideways position, feet distance, head and trunk shift, depth of knee
   and ankle (world landmarks), 3-D abduction and lean. Everything is **mirrored so that the lifted leg is always on
   the same side**.
4. `sl.segment_reps` on `abd_leg_a` with `app_spec_e4.json` → `pipeline.seg` (prominence 0.35, rep 0.6–20 s) — shared.
5. `sds.baseline_frames` — the first break (last 1.5 s before the first rep, standing still) — shared.
6. For every usable rep: window = rep start − 0.5 s … rep end + 0.5 s (`sds.rep_window`, shared), resampled to 64
   frames (`sds.to_T`, shared). Channels: `lds._frame_matrix` (new): `lds.canonical_coords` (13 body points in torso
   units), the angles, the depth signals, the 5 base points and 7 base angles **relative to the first break**, then
   log(duration in s) as the last stored channel. Measures: `lds.rep_features` (new, 64 measures) on the same window.
7. `x = X[:, input_selection]`, `f` = the measures named in `heads.e4.features` → `mt_e4.onnx` → `probs`.
8. Verdict: class = argmax; confidence < 0.5 → "unsure"; not good → the class message (`{leg}` = left/right);
   good → **range check**.

**Range check (good-form reps only).** `peak_deg` = per-rep measure `g4_abd_leg_peak` (leg angle at the top, degrees;
also column `features.index("g4_abd_leg_peak")` of `f`). Target, in this order: the physiotherapist's target angle for
the patient → else `relative_fraction` (≈0.75) × the patient's usual lift (median `peak_deg` of their good reps, e.g. of
their first session) → else `fixed_threshold_deg` (≈27°). `peak_deg < target` → status `below_target`, message
`range_low`. Only on good-form reps: a sideways lean changes the leg angle (it is measured against the trunk).

**Live use.** As e1–e3: keep all frames of the session; when a rep has finished (its end + 0.5 s in the buffer and the
leg back down, or the next rep started), run steps 1–8 on the buffer and score the reps not scored yet.

## Checking the port (before trusting the app)
Each golden file has `input` (exactly what the app records) and `expected`: `leg`, `side_conflict`, `baseline`, `reps`
(30 Hz frame indices), `count_signal_smoothed`, `frame_channels` (per-frame values of the head's channels before
windowing, angles in stored units = degrees / 90), and per scored rep `x`, `f`, `probs`, `label`, `confidence`,
`peak_deg`, `status`, `message`, with the default range target (`range_target`). Tolerances: rep indices ±1 frame,
channels/measures |Δ| < 1e-3 (relative 1e-3 for large values), probabilities |Δ| < 1e-3, same label and status.
The golden `shallow` recording must give mostly `good` form with `below_target` reps.
To check an app recording: export it as JSON in the format of `input` and run
`python reference_python/reference_predict_e4.py --pose rec.json --side left [--target-deg 35] --out ref.json`.
