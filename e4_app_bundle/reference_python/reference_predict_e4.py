#!/usr/bin/env python3
"""Reference pipeline of exercise 4 (standing hip abduction, chair support): MediaPipe landmarks of ONE recording ->
reps -> model inputs -> class probabilities -> feedback, and the range check. This is the code the app must reproduce.

    python reference_predict_e4.py --pose session.json --side left [--target-deg 35 | --own-lift-deg 48] [--out result.json]

--pose: a recording, either the training .npz or a .json with
        {"t_ms": [T], "lm": [T][33][5], "world": [T][33][3], "width": W, "height": H}
        lm = MediaPipe normalized landmarks (x, y in 0..1, z, visibility, presence); world = world landmarks (m);
        frames without a person: rows of null. (No silhouette / segmentation mask is needed for e4.)
--side: the LIFTED leg (the leg that moves; the patient stands on the other one, holding the chair).
--target-deg: the physiotherapist's target angle for this patient (leg angle away from the body at the top of a rep).
--own-lift-deg: without a target: the patient's usual lift (median leg angle at the top of their good reps, e.g. from
        their first session); the target is then app_spec range.relative_fraction x this. Without both: the fixed
        default angle of app_spec (range.fixed_threshold_deg).
The result has the same layout as the "expected" part of the golden files.
Needs: numpy, scipy, onnxruntime.
"""
import argparse
import json
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import leg_ds as lds  # noqa: E402
import shoulder_lib as sl  # noqa: E402

EX = "e4"
PEAK_FEATURE = "g4_abd_leg_peak"          # leg angle away from the body at the top of the rep (degrees)


def load_pose(path):
    """Recording (.npz or .json) -> the dict analyze_video expects."""
    path = Path(path)
    if path.suffix == ".npz":
        return sl.load_npz(path)
    j = json.loads(path.read_text())
    arr = lambda v, shape_tail: np.array([[[np.nan if x is None else x for x in row] for row in fr] if fr is not None
                                          else np.full(shape_tail, np.nan) for fr in v], np.float32)
    return dict(t_ms=np.asarray(j["t_ms"], np.float64), lm=arr(j["lm"], (33, 5)), world=arr(j["world"], (33, 3)),
                meta=dict(width=j["width"], height=j["height"]))


class Model:
    """The e4 network, run with its ONNX file (what the app runs); without the file, with PyTorch (needs torch)."""
    def __init__(self, bundle):
        self.bundle = Path(bundle)
        self.cfg = json.loads((self.bundle / "models" / "e4_head.json").read_text())
        self.head = self.cfg["heads"][EX]
        self.sess, self.torch_head = None, None
        p = self.bundle / "models" / self.head["onnx_file"]
        try:
            import onnxruntime as ort
            if p.exists():
                self.sess = ort.InferenceSession(str(p), providers=["CPUExecutionProvider"])
        except ImportError:
            pass

    def __call__(self, x, f):
        x, f = x.astype(np.float32), f.astype(np.float32)
        if self.sess is not None:
            feed = {"x": x}
            if "f" in [i.name for i in self.sess.get_inputs()]:
                feed["f"] = f
            return self.sess.run(None, feed)[0]
        import torch
        import shoulder_mt as smt
        if self.torch_head is None:
            try:
                ck = torch.load(self.bundle / "models" / self.cfg["weights_file"], map_location="cpu", weights_only=False)
            except TypeError:
                ck = torch.load(self.bundle / "models" / self.cfg["weights_file"], map_location="cpu")
            self.torch_head = smt.ExportHead(smt.build_net(ck, "cpu")[0], 0, ck["stats"][EX]).eval()
        with torch.no_grad():
            return self.torch_head(torch.from_numpy(x), torch.from_numpy(f)).float().numpy()


def head_inputs(out, head):
    """x (n, C_sel, T): the stored channels the head uses, raw (normalisation is inside the ONNX file);
    f (n, F): the head's per-rep measures by name, raw, NaN where missing."""
    X = np.asarray(out["X"][0, 0], np.float32)[:, head["input_selection"]]
    F0, names = np.asarray(out["F"][0, 0], np.float32), out["feature_names"]
    f = np.full((len(F0), len(head["features"])), np.nan, np.float32)
    for j, n in enumerate(head["features"]):
        if n in names:
            f[:, j] = F0[:, names.index(n)]
    return X, f


def range_target(spec, target_deg=None, own_lift_deg=None):
    """(target angle, where it comes from): the physio's target, else a share of the patient's own usual lift, else the
    fixed default angle."""
    rr = spec["range"]
    if target_deg is not None:
        return float(target_deg), "physiotherapist's target"
    if own_lift_deg is not None:
        return float(rr["relative_fraction"] * own_lift_deg), f"{rr['relative_fraction']:.0%} of the patient's usual lift"
    return float(rr["fixed_threshold_deg"]), "default angle"


def verdict(spec, label, confidence, side, peak_deg, target):
    """status (good / below_target / mistake / unsure), message. The range is judged only when the form is good:
    a sideways lean changes the leg angle (it is measured against the trunk), so range and form are not mixed."""
    fb = spec["feedback"]
    leg = {"left": "left", "right": "right"}.get(side, "")
    if confidence < fb["min_confidence"]:
        return "unsure", fb["messages"]["unsure"]
    if label != "good":
        return "mistake", fb["messages"][EX][label].format(leg=leg)
    if target is not None and peak_deg is not None and np.isfinite(peak_deg) and peak_deg < target[0]:
        return "below_target", fb["messages"]["range_low"].format(target=target[0], reached=peak_deg)
    return "good", fb["messages"][EX]["good"]


def run_reference(d, side, cfg, predict, spec=None, key="", dump_inputs=True, frame_debug=True, target_deg=None,
                  own_lift_deg=None):
    """The whole chain for one recording. predict(x, f) -> (n, K) probabilities."""
    av, head = cfg["analyze_video"], cfg["heads"][EX]
    out = lds.analyze_video(d, side=side, fs=av["FS"], max_gap_s=av["MAX_GAP_S"], seg_cfg=av["SEG"], T=av["T_LEN"],
                            margin_s=av["MARGIN_S"], min_valid=av["MIN_VALID"], n_geo=0, base_cfg=av["BASE_CFG"], key=key,
                            rr_levels=())
    if out is None:
        return dict(error="no person detected")
    b0, b1, bsrc = out["baseline"]
    res = dict(exercise=EX, side=side, leg=out["leg"], side_conflict=bool(out["side_conflict"]),
               n_frames_30hz=int(len(out["r"]["t"])), t0_s=float(out["r"]["t"][0]),
               baseline=dict(start=int(b0), end=int(b1), source=bsrc), count_signal=lds.COUNT_SIGNAL,
               reps=[{k: (v if not isinstance(v, (np.floating, float)) else float(v))
                      for k, v in row.items() if k in ("rep", "partial", "usable", "i_start", "i_peak", "i_end", "t_start",
                                                       "t_peak", "t_end", "peak_abd", "amp")} for row in out["rows"]],
               samples=[])
    target = range_target(spec, target_deg, own_lift_deg) if spec is not None else None
    if target is not None:
        res["range_target"] = dict(deg=target[0], source=target[1])
    if frame_debug:
        res["count_signal_smoothed"] = out["s"]
        M, _, _ = lds._frame_matrix(out["r"], out["sig"], out["leg"], b0, b1)
        names = list(head["stored_channels"])[:M.shape[1]]          # M = every stored channel except log_duration (last)
        wanted = [n for n in (head["stored_channels"][i] for i in head["input_selection"]) if n in names]
        res["frame_channels"] = dict(names=wanted, values=M[:, [names.index(n) for n in wanted]],
                                     note="per-frame values on the 30 Hz grid, before windowing; angles in stored units (deg / 90)")
    if out["X"] is None or not len(out["use"]):
        return res
    x, f = head_inputs(out, head)
    P = predict(x, f)
    classes = head["classes"]
    names = out["feature_names"]
    peaks = np.asarray(out["F"][0, 0], np.float32)[:, names.index(PEAK_FEATURE)] if PEAK_FEATURE in names else np.full(len(P), np.nan)
    for j, i in enumerate(out["use"]):
        s = dict(rep=out["rows"][i]["rep"], probs=P[j], label=classes[int(np.argmax(P[j]))], confidence=float(np.max(P[j])),
                 peak_deg=float(peaks[j]))
        if spec is not None:
            s["status"], s["message"] = verdict(spec, s["label"], s["confidence"], side, s["peak_deg"], target)
        if dump_inputs:
            s["x"], s["f"] = x[j], f[j]
        res["samples"].append(s)
    good = [s["peak_deg"] for s in res["samples"] if s["label"] == "good" and np.isfinite(s["peak_deg"])]
    res["summary"] = dict(scored=len(res["samples"]), by_label={c: sum(s["label"] == c for s in res["samples"]) for c in classes},
                          median_peak_deg_good_reps=float(np.median(good)) if good else None)
    return res


def to_json(o):
    """NaN -> null, float32 values with 9 significant digits (round-trips float32 exactly)."""
    if isinstance(o, dict):
        return {k: to_json(v) for k, v in o.items()}
    if isinstance(o, (list, tuple)):
        return [to_json(v) for v in o]
    if isinstance(o, np.ndarray):
        if o.dtype.kind == "f":
            a = o.astype(np.float64)
            return [to_json(v) for v in a.tolist()] if a.ndim > 1 else [None if v != v else float(f"{v:.9g}") for v in a.tolist()]
        return o.tolist()
    if isinstance(o, (np.floating, float)):
        return None if o != o else float(f"{float(o):.9g}")
    if isinstance(o, np.integer):
        return int(o)
    if isinstance(o, np.bool_):
        return bool(o)
    return o


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--pose", required=True)
    ap.add_argument("--side", choices=["left", "right"], default=None, help="the LIFTED leg")
    ap.add_argument("--target-deg", type=float, default=None, help="the physiotherapist's target angle for this patient")
    ap.add_argument("--own-lift-deg", type=float, default=None, help="the patient's usual lift (median of good reps)")
    ap.add_argument("--bundle", default=str(HERE.parent), help="folder with models/ and app_spec_e4.json")
    ap.add_argument("--out", default=None)
    ap.add_argument("--no-inputs", action="store_true", help="do not write the model inputs x/f of every rep")
    a = ap.parse_args()
    model = Model(a.bundle)
    spec_p = Path(a.bundle) / "app_spec_e4.json"
    spec = json.loads(spec_p.read_text()) if spec_p.exists() else None
    res = run_reference(load_pose(a.pose), a.side, model.cfg, model, spec, key=Path(a.pose).stem,
                        dump_inputs=not a.no_inputs, target_deg=a.target_deg, own_lift_deg=a.own_lift_deg)
    for s in res.get("samples", []):
        print(f"rep {s['rep']:>3}: {s['label']:<8} {s['confidence']:.2f}  peak {s['peak_deg']:5.1f} deg  {s.get('message', '')}")
    print(f"{len(res.get('reps', []))} reps found, {len(res.get('samples', []))} scored | lifted leg {res.get('leg')} "
          f"(side conflict: {res.get('side_conflict')}) | range target {res.get('range_target')}")
    if a.out:
        Path(a.out).write_text(json.dumps(to_json(res)))
        print("written", a.out)


if __name__ == "__main__":
    main()
