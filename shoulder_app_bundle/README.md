# Shoulder exercises — multi-task network: app bundle

One small network judges every repetition (rep) of three shoulder exercises filmed from the front with a phone.
It has one output head per exercise; the app runs only the head of the exercise the patient is doing.

| exercise | name | classes (head output order: see `models/mt_final.json` → `heads[ex].classes`) |
|---|---|---|
| e1 | active-assisted forward elevation with a stick (both arms) | good, elb, rngdown, imb |
| e2 | arm abduction (one arm) | good, elb, rngdown, shld, lean |
| e3 | arm rotation, elbow at the side (one arm) | good, wrong |

## Files
- `models/mt_e1.onnx`, `mt_e2.onnx`, `mt_e3.onnx` — one file per exercise (≈1.3 MB each, ≈1 ms per rep on a phone CPU).
  Inputs: `x` float32 (reps, C, 64) and `f` float32 (reps, F); output `probs` (reps, K). The normalisation, the
  velocity channels and missing features (NaN) are handled **inside** the file: pass raw values.
- `models/sep_e1.onnx`, `sep_e2.onnx`, `sep_e3.onnx` + `models/separate.json` — the **separate** model: the final
  notebook's own network of each exercise (best single network, its saved seeds averaged), with exactly the same
  interface. `separate.json` has the same `heads[ex]` keys as `mt_final.json`, so the app switches model by
  switching the config file + ONNX file; the pipeline is the same. An exercise missing from `separate.json` has no
  separate network (the final notebook chose a classical model only).
  (The final notebook's full ensembles cannot run on a phone: they mix Random Forest, gradient boosting and ROCKET
  Python objects with random test-time augmentation.)
- `models/sep_e*.pt` and `reference_python/final_nets.py` — the same separate networks for PyTorch (Python reference only).
- `models/mt_final.pt` — the same network for PyTorch (only for the Python reference; the app does not need it).
- `models/mt_final.json` — per head: `input_selection` (which stored channels go into `x`, in order), `stored_channels`
  (names of all stored channels), `features` (names of the columns of `f`, in order), `classes`, `needs_silhouette`;
  and `analyze_video` (all preprocessing settings).
- `reference_python/` — the exact Python code used for training: `shoulder_lib.py` (resampling, angles, rep
  segmentation), `shoulder_ds.py` (`analyze_video`: rep windows, channels, features), `pose_worker.py`
  (`sil_features`: silhouette numbers from the person mask), `shoulder_mt.py` (network + `MTPredictor`),
  `reference_predict.py` (whole chain on one recording, with ONNX Runtime).
- `golden/<ex>__<video>.json` — real recordings with everything the Python pipeline computes for them.
- `golden/sil_tests.json` — person masks with the expected silhouette numbers.
- `app_spec.json` — MediaPipe settings, pipeline settings, feedback messages, confidence threshold.

## The pipeline (what the app must reproduce)
**Per camera frame**
1. MediaPipe Tasks **PoseLandmarker**, model `pose_landmarker_full.task`, 1 person, confidences 0.5/0.5/0.5,
   ~30 fps. Keep for every frame: the timestamp (ms), the 33 normalized landmarks (x, y, z, visibility, presence),
   the 33 world landmarks (x, y, z in metres), the frame width and height. A frame without a person = all NaN.
   (Not ML Kit / MoveNet / another model: the network was trained on these landmarks.)
2. Only if the head needs the silhouette (`needs_silhouette`, see `app_spec.json`): turn on the segmentation mask
   and compute `sil_features(mask, landmarks)` → 2×9 numbers per frame (port of `pose_worker.sil_features`, ~50 lines).
3. Camera images must be upright and **not mirrored** (un-mirror the selfie preview before MediaPipe), otherwise
   left and right swap.

**Per rep** (Python reference: `shoulder_ds.analyze_video(d, ex, side, single_arm, ...)` with `n_geo=0`, `rr_levels=()`)
1. `sl.resample`: uniform 30 Hz grid from the first to the last detected frame; linear interpolation; gaps longer
   than 0.5 s stay NaN. Pixel coordinates = normalized × (width, height).
2. `sds.choose_arm`: e2/e3 the moving arm (the patient's chosen side when it is not clear); e1 = the side given
   (the injured arm).
3. `sl.compute_signals`: angles and distances per frame (side-relative).
4. `sl.segment_reps` on the count signal (`e1: lift`, `e2: elev_a`, `e3: rot`): peaks with a prominence
   ≥ 0.35 × (p95 − p5) of the recording, start/end where the signal is within 10 % of the rep amplitude from its
   valleys. Partial reps (cut by the start/end) are counted but not scored.
5. `sds.baseline_frames`: the "first break" = the last 1.5 s before the first rep (the patient standing still).
   The app should ask for a short "get ready, stand still" moment before the first rep.
6. For every usable rep: the window = rep start − 0.5 s … rep end + 0.5 s (never past the neighbouring valleys),
   resampled to 64 frames (`to_T`). Channels: `_frame_matrix` + `_sample_channels` (coordinates in torso units,
   angles, depth, first-break-relative values, `_d0` = relative to the rest before the rep, gated shrug channels
   `_g` frozen once the arm passes 100°), and as last stored channel log(duration in s). Features:
   `features_v4` on the same window.
7. `x = X[:, input_selection]`, `f` = the features named in `heads[ex].features` → ONNX → `probs`.
8. Verdict: class = argmax; confidence < 0.5 → "unsure" message; else the class message (`app_spec.json`).

**Live use.** Keep all frames of the session in a buffer. When a rep has finished (its end + 0.5 s margin is in
the buffer and the signal is back at rest, or the next rep has started), run steps 1–8 on the buffer and score the
reps that were not scored yet. This reproduces the training pipeline exactly. For an instant counter on screen,
`sl.online_count` (causal) can be shown while waiting; the scored reps come from `segment_reps`.

## Checking the port (do this before trusting the app)
Each golden file has `input` (exactly what the app would record), `expected` (multi-task model) and
`expected_separate` (separate model: `samples` with `probs`, `label`, `message`, plus `x`/`f` only when its inputs
differ from the multi-task ones). `expected` has:
`arm`, `baseline`, `reps` (frame indices on the 30 Hz grid), `count_signal_smoothed`, `frame_channels`
(per-frame values of the head's channels before windowing), and for every scored rep `x`, `f`, `probs`,
`label`, `confidence`, `message`. Suggested tolerances: rep indices ±1 frame, channels/features |Δ| < 1e-3
(relative 1e-3 for large values), probabilities |Δ| < 1e-3, same label.
To check an app recording: export it as JSON in the same format as `input` and run
`python reference_python/reference_predict.py --pose rec.json --exercise e2 --side left --model multitask --out ref.json`
(or `--model separate`).
