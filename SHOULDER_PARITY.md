# Shoulder pipeline: parity with the Python reference

The app's shoulder pipeline (`lib/features/exercise_ai/`) is a Dart port of `shoulder_app_bundle/reference_python`
(`analyze_video(..., n_geo=0, rr_levels=())`, `reference_predict.head_inputs / verdict`,
`pose_worker.sil_features`). The ONNX models run through ONNX Runtime's C API (`core/ort_ffi.dart`), with the same
code on the PC (tests) and on the phone.

## How to run the tests

```powershell
# once: the Python reference (only needed to regenerate fixtures) and the ONNX Runtime library for the PC tests
python -m venv D:\kinex-tools\pyref; D:\kinex-tools\pyref\Scripts\pip install -r shoulder_app_bundle\requirements.txt
# onnxruntime-win-x64-1.31.0.zip from https://github.com/microsoft/onnxruntime/releases, unzipped to D:\kinex-tools

$env:ORT_LIB = "D:\kinex-tools\onnxruntime-win-x64-1.31.0\lib\onnxruntime.dll"
flutter test test/shoulder/
```

`ORT_LIB` is required: without it the probability checks fail instead of being skipped.
`tool/shoulder_ref/make_fixtures.py` regenerates `test/shoulder/fixtures/` from the Python reference.
`build/shoulder_parity.json` gets the per-file differences after each run.

| Test file | What it checks |
|---|---|
| `golden_pipeline_test.dart` | the 8 golden recordings, stage by stage, both models (multi-task and separate) |
| `live_cases_test.dart` | 24 cuts of the golden recordings, the way the live app sees them: the buffer ending 0.5 s after a rep, and the recording starting in the rest before a rep |
| `np_port_test.dart` | numpy / scipy primitives (`find_peaks` with plateaus, `savgol_filter` edges, `nanpercentile`, `interp`, round half to even) |
| `sil_features_test.dart` | `sil_features` on the 15 masks of `golden/sil_tests.json`; float16 rounding |

## Results (2026-10-09, ONNX Runtime 1.31.0 on Windows x64)

Every test passes (63/63). Max |Δ| per golden file and stage. Tolerances: rep indices ±1 frame;
channels/features 1e-3 (relative 1e-3 for large values); probabilities 1e-3; labels and messages identical.

| golden file | arm | baseline | reps (max Δ frames) | count signal | frame channels | x | f | probs | labels | messages | separate probs | separate labels |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| e1_elb_p12_right_9 | ok | ok | 9/9 (0) | 8.5e-08 | 3.9e-07 | 3.8e-07 | 1.7e-05 | 1.2e-07 | 7/7 | 7/7 | 1.8e-07 | 7/7 |
| e1_good_p14_left_9 | ok | ok | 9/9 (0) | 1.5e-07 | 2.9e-06 | 2.8e-06 | 4.6e-05 | 2.4e-07 | 9/9 | 9/9 | 2.4e-07 | 9/9 |
| e1_rngdown_p25_left_10 | ok | ok | 10/10 (0) | 3.7e-07 | 2.5e-06 | 2.4e-06 | 5.7e-05 | 1.5e-06 | 9/9 | 9/9 | 7.2e-07 | 9/9 |
| e2_elb_p30_right_10 | ok | ok | 10/10 (0) | 1.9e-05 | 1.4e-06 | 1.3e-06 | 3.2e-05 | 1.2e-07 | 10/10 | 10/10 | 3.6e-07 | 10/10 |
| e2_good_p01_left_9 | ok | ok | 9/9 (0) | 1.8e-05 | 8.5e-07 | 8.3e-07 | 3.1e-05 | 5.4e-07 | 9/9 | 9/9 | 3.0e-07 | 9/9 |
| e2_rngdown_p25_left_10 | ok | ok | 10/10 (0) | 1.6e-05 | 1.5e-06 | 1.5e-06 | 4.6e-05 | 1.2e-07 | 9/9 | 9/9 | 1.8e-07 | 9/9 |
| e3_good_p30_left_10 | ok | ok | 10/10 (0) | 5.3e-07 | 8.2e-06 | 8.2e-06 | 6.9e-05 | 5.8e-08 | 8/8 | 8/8 | 5.9e-08 | 8/8 |
| e3_wrong_p13_right_10 | ok | ok | 10/10 (0) | 2.5e-07 | 2.5e-06 | 2.5e-06 | 9.9e-05 | 3.0e-08 | 9/9 | 9/9 | 7.5e-09 | 9/9 |

- **Absolute `f` and count-signal differences:** the largest ones are on large-valued signals and features
  (degrees, slopes × 90); relative differences are ≤ 1e-6.
- **Cut recordings:** all 24 cuts match too (arm, baseline, reps, `x` of the first scored rep, every `f`,
  probabilities, labels, messages). Three of them use the "first_break" baseline, which the full golden files never
  reach.
- **`sil_features`:** max |Δ| = 5e-10 over the 15 masks.

## Known differences and findings

1. **`compute_signals` is float32 in numpy.** `sl.resample` stores the pixels as float32, so `side_evidence` and
   `compute_signals` do float32 arithmetic (Python floats such as `TL` or `Lu` are cast to float32 first). It
   matters: `elev_est = degrees(arccos(dy / Lu))` near arm-down lands on float32 steps (1.0 vs 0.99999994 ≈ 0.02°),
   which showed up as a 0.022° feature difference in a cut recording. The port reproduces numpy's float32
   operations there (`_sub`, `_div`, `_norm2f`, `_deg32` in `shoulder_lib.dart`). `_ang` and all of `shoulder_ds`
   are float64, as in numpy.
2. **`find_peaks` with exactly equal peak heights.** scipy orders peaks for the `distance` rule with
   `np.argsort` (an unstable sort whose order for ties depends on numpy's sort kernel, e.g. the SIMD one). The port
   uses a stable order. Real (smoothed, float) count signals never have two distinct peaks of exactly the same height
   within `distance`; plateaus are handled exactly like scipy (tested).
3. **float32 math functions.** numpy's float32 `arctan2` / `arccos` / `arcsin` may use SIMD versions (≤ a few
   float32 ulps). The port uses the correctly rounded value; the effect is ~1e-7 relative.
4. **Silhouette values are stored as float16 in training** (`pose_worker` writes `sil` as float16). The app rounds
   its silhouette numbers to float16 (`f16`) before they enter the pipeline, so they match what the network was
   trained on.
5. **Live scoring uses the buffer at that moment.** The pipeline uses whole-recording statistics (p5/p95 of the
   count signal, the median prominence, torso length, upper-arm and forearm length percentiles, smoothing edges,
   the "lowest_point" baseline). A rep scored live can therefore differ slightly from the same rep in a run on the
   whole set. `live_cases_test` shows the port equals the reference on the same cut, so the debug export stores the
   buffer length used for each live score, and the reference reproduces it.
6. **Frame size.** In training `width`/`height` are the original video size, while MediaPipe saw a resized frame;
   only the aspect ratio matters for the landmarks. The app uses the analysed (upright) frame size for both.
7. **Not used:** `range_top`, `top_tolerance_deg`, `therapist_target_deg` (all null) and the heads' `rest_threshold`
   are not used by `reference_predict.verdict`, so the app does not use them either.

## Live scoring replay

`live_replay_test.dart` feeds each golden recording to `ShoulderModule.score` the way the live screen does:
a pass every 15 new frames on the buffer so far, then a final pass. It compares the live verdicts with the
offline run on the whole recording:

| golden file | offline scored | live scored | same label | max prob Δ (live vs offline) |
|---|---|---|---|---|
| e1_elb_p12_right_9 | 7 | 8 | 7/7 | 0.005 |
| e1_good_p14_left_9 | 9 | 9 | 9/9 | 0.007 |
| e1_rngdown_p25_left_10 | 9 | 9 | 9/9 | 0.264 |
| e2_elb_p30_right_10 | 10 | 10 | 10/10 | 0.003 |
| e2_good_p01_left_9 | 9 | 9 | 9/9 | 0.008 |
| e2_rngdown_p25_left_10 | 9 | 9 | 9/9 | 0.007 |
| e3_good_p30_left_10 | 8 | 8 | 8/8 | 0.003 |
| e3_wrong_p13_right_10 | 9 | 9 | 9/9 | 0.001 |

- **Every rep once:** every rep the offline run scores gets exactly one live verdict, and none is scored twice.
- **Labels:** the label is the same for all 70.
- **Probabilities:** they differ because of the whole-recording statistics (known difference 5). On
  e1_rngdown, one rep differs by 0.26 (still the same label).
- **One extra live score:** in e1_elb, the first rep is cut by the start of the full recording (partial, not
  scored offline), but on the shorter buffer the segmentation found it complete, so it was scored live.

## Timing

- **On the PC** (debug JIT, in the tests): the pipeline takes 65–390 ms per whole recording (9–10 reps). ONNX takes
  ~13 ms for all the reps of a recording; the first session load takes ~150 ms.
- **On the phone:** not measured yet (Phase 4).

### Live delay: what was changed and how to measure it

The live scoring re-analyses the whole current segment, as the reference does (known difference 5). Its cost
therefore grows with the length of the set. The skeleton itself comes straight from MediaPipe and never waits for the
scoring, but on a slow phone the scoring competes with MediaPipe for the CPU.

1. **Debug build:** the phone ran a debug (JIT) build, which is several times slower. `tool/phone.ps1` now installs a
   release build.
2. **Whole screen rebuilt per frame:** the screen, including the camera view, was rebuilt on every frame. Now only
   the skeleton repaints on its own; the screen rebuilds only when something it shows changes.
3. **One isolate per pass:** a new background isolate was spawned for every scoring pass (every 0.5 s). Now one
   worker isolate lives for the whole set (`_ScoringWorker` in `shoulder_module.dart`).
4. **Fixed pass rate:** passes ran every 0.5 s whatever their cost. Now the next pass waits at least twice as long as
   the last one took, with a minimum of 0.5 s. That keeps the scoring under about a third of a core, so MediaPipe keeps
   its frame rate as the set gets longer. A verdict can then come a little later on a slow phone, but it is the same
   verdict.
5. **Release builds:** R8 shrinking is off (MediaPipe uses JNI) and the Gradle memory cap is 3 GB.

6. **Every camera frame converted, even when MediaPipe was busy** (2026-10-13): each frame was converted to a
   bitmap, rotated and handed to MediaPipe, which drops it when still busy with the previous one. That conversion
   used the CPU that MediaPipe needs. Now a frame is skipped *before* any conversion while a detection is running
   (`inFlight` in `KinexPosePlugin.kt`), so only the newest frame is ever processed and nothing queues. The
   overlay counts the skipped frames ("dropped/s").
7. **Person mask copied value by value** (e2 only): one bulk copy now.
8. **GPU delegate, as an option** (Developer settings → *Run pose detection on the GPU*, off by default): MediaPipe
   on the phone's GPU, falling back to the CPU if the phone cannot. It stays optional because the landmarks are not
   bit-identical to the CPU ones the scoring was validated with; use it to compare on a given phone.

The scoring itself is unchanged (all parity tests still pass), and nothing was removed: the latest-frame rule only
drops frames that MediaPipe would have dropped anyway, after paying for their conversion.

The timing overlay (Developer settings → Show timing overlay) shows, every 2 s:

| Field | Meaning |
|---|---|
| fps (cpu/gpu, N dropped/s) | results per second, the delegate in use, frames skipped because MediaPipe was busy |
| camera->result ms | age of a result: camera timestamp to MediaPipe's answer (the skeleton's delay) |
| MediaPipe ms | the detection itself |
| mask ms | packing the person mask (e2) |
| Dart ms/frame | the Dart time per frame |
| pass ms / every N fr | the scoring pass time and its interval |
| backlog | how far the frames reaching Dart lag behind the camera clock |
| buffer | the buffer size |

`tool/phone.ps1 -Logs` prints the same line (`[kinex perf]`) to the PC.

How to read the numbers:

| What you see | What it means |
|---|---|
| backlog growing | frames pile up on the Dart side |
| high camera->result with a high MediaPipe ms | the detection is the limit: try the GPU option |
| high camera->result with a low MediaPipe ms | conversion / waiting: should now be gone (frames are skipped instead) |
| pass ms growing with the buffer | the scoring cost (bounded: a set ends at 10 good or 15 reps) |

Where the delay of a *verdict* comes from, even on a fast phone: the reference pipeline judges a rep once it is over
and the arm has rested for 0.5 s (known difference 5), then the next scoring pass runs. That part is by design.

### Measuring before / after on a phone

```powershell
adb shell pm grant com.example.reeducation android.permission.CAMERA   # once, after installing
flutter drive --profile --driver=test_driver/integration_test.dart --target=integration_test/live_perf_test.dart -d <device>
```

No one needs to stand in front of the camera. It runs the camera and MediaPipe for 12 s (after 3 s of warm-up) in four
configurations: the old behaviour (every frame submitted, CPU), the latest-frame rule on the CPU, the same with the
person mask (e2), and on the GPU. It then times the scoring pass on synthetic sets of 10–90 s. The results go to
`build/live_perf.json` (mean / p50 / p90 / max per measure).

**Phone results: not measured yet.** No phone was reachable on 2026-10-13, so the improvement of items 6–8 is not
verified on a device. Run the command above and compare the first two configurations.

PC reference (Windows, debug JIT, synthetic left-arm abduction, 5 runs each), scoring pass round trip:

| Set length | Reps found | Median | Min – max |
|---|---|---|---|
| 10 s | 3 | 52 ms | 23 – 159 ms |
| 30 s | 8 | 67 ms | 43 – 82 ms |
| 60 s | 15 | 93 ms | 80 – 131 ms |
| 90 s | 23 | 146 ms | 119 – 170 ms |
