#!/usr/bin/env python3
"""Reference pipeline of the shoulder multi-task network: MediaPipe landmarks of ONE recording -> reps -> model
inputs -> class probabilities -> feedback. This is the code the phone app must reproduce.

    python reference_predict.py --pose session.json --exercise e2 --side left [--model separate] [--out result.json]

--pose: a recording, either the worker's .npz (training format) or a .json with
        {"t_ms": [T], "lm": [T][33][5], "world": [T][33][3], "sil": [T][2][9] or null, "width": W, "height": H}
        lm = MediaPipe normalized landmarks (x, y in 0..1, z, visibility, presence); world = world landmarks (m);
        sil = silhouette measures per frame (pose_worker.sil_features), only needed by heads that use the silhouette;
        frames without a person: lm/world rows of null (NaN).
The result has the same layout as the "expected" part of the golden files, so an app recording can be checked
against this script number by number.
Needs: numpy, scipy, onnxruntime (pip install numpy scipy onnxruntime).
"""
import argparse
import json
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import shoulder_ds as sds  # noqa: E402
import shoulder_lib as sl  # noqa: E402

SINGLE_ARM = {"e1": False, "e2": True, "e3": True}


def load_pose(path):
    """Recording (.npz or .json) -> the dict analyze_video expects."""
    path = Path(path)
    if path.suffix == ".npz":
        return sl.load_npz(path)
    j = json.loads(path.read_text())
    arr = lambda v, shape_tail: np.array([[[np.nan if x is None else x for x in row] for row in fr] if fr is not None
                                          else np.full(shape_tail, np.nan) for fr in v], np.float32)
    d = dict(t_ms=np.asarray(j["t_ms"], np.float64), lm=arr(j["lm"], (33, 5)), world=arr(j["world"], (33, 3)),
             meta=dict(width=j["width"], height=j["height"], sil_names=j.get("sil_names") or None))
    if j.get("sil") is not None:
        d["sil"] = arr(j["sil"], (2, 9))
    if d["meta"]["sil_names"] is None:
        d["meta"].pop("sil_names")
    return d


MODEL_FILES = {"multitask": "mt_final.json", "separate": "separate.json"}


class Model:
    """One of the two models of the bundle, run with its ONNX files (what the app runs):
    "multitask" = one network shared by the 3 exercises (models/mt_final.json, mt_e*.onnx);
    "separate"  = the final notebook's own network of each exercise (models/separate.json, sep_e*.onnx).
    Without an ONNX file, the PyTorch weights are used instead (needs torch)."""
    def __init__(self, bundle, which="multitask"):
        self.bundle, self.which = Path(bundle), which
        self.cfg = json.loads((self.bundle / "models" / MODEL_FILES[which]).read_text())
        self.sess, self.torch_heads = {}, {}
        try:
            import onnxruntime as ort
        except ImportError:
            ort = None
        for ex, h in self.cfg["heads"].items():
            p = self.bundle / "models" / h["onnx_file"]
            if p.exists() and ort is not None:
                self.sess[ex] = ort.InferenceSession(str(p), providers=["CPUExecutionProvider"])

    def _torch(self, ex, x, f):
        import torch
        if ex not in self.torch_heads:
            if self.which == "multitask":
                import shoulder_mt as smt
                self.torch_heads.update(smt.MTPredictor(self.bundle / "models", "cpu").heads)
            else:
                import final_nets as fn
                ck = fn.load_checkpoint(self.bundle / "models" / self.cfg["heads"][ex]["weights_file"])
                self.torch_heads[ex] = [fn.SepHead(ck).eval()]
        with torch.no_grad():
            return np.mean([h(torch.from_numpy(x), torch.from_numpy(f)).float().numpy() for h in self.torch_heads[ex]], 0)

    def __call__(self, ex, x, f):
        x, f = x.astype(np.float32), f.astype(np.float32)
        if ex not in self.sess:
            return self._torch(ex, x, f)
        s = self.sess[ex]
        feed = {"x": x}
        if "f" in [i.name for i in s.get_inputs()]:
            feed["f"] = f
        return s.run(None, feed)[0]


def head_inputs(out, ex, head):
    """x (n, C_sel, T): the stored channels the head uses, raw (normalisation is inside the ONNX file);
    f (n, F): the head's per-rep features by name, raw, NaN where missing."""
    X = np.asarray(out["X"][0, 0], np.float32)[:, head["input_selection"]]
    F0, names = np.asarray(out["F"][0, 0], np.float32), out["feature_names"]
    f = np.full((len(F0), len(head["features"])), np.nan, np.float32)
    for j, n in enumerate(head["features"]):
        if n in names:
            f[:, j] = F0[:, names.index(n)]
    return X, f


def run_reference(d, ex, side, cfg, predict, spec=None, key="", dump_inputs=True, frame_debug=True):
    """The whole chain for one recording. predict(ex, x, f) -> (n, K) probabilities."""
    av, head = cfg["analyze_video"], cfg["heads"].get(ex)
    out = sds.analyze_video(d, ex, side=side, single_arm=SINGLE_ARM[ex], fs=av["FS"], max_gap_s=av["MAX_GAP_S"],
                            seg_cfg=av["SEG"][ex], T=av["T_LEN"], margin_s=av["MARGIN_S"], min_valid=av["MIN_VALID"],
                            n_geo=0, geo_cfg=av["GEO_CFG"], rr_levels=(), base_cfg=av["BASE_CFG"], key=key)
    if out is None:
        return dict(error="no person detected")
    b0, b1, bsrc = out["baseline"]
    res = dict(exercise=ex, side=side, arm=out["arm"], side_conflict=bool(out["side_conflict"]),
               n_frames_30hz=int(len(out["r"]["t"])), t0_s=float(out["r"]["t"][0]),
               baseline=dict(start=int(b0), end=int(b1), source=bsrc),
               count_signal=sl.COUNT_SIGNAL[ex],
               reps=[{k: (v if not isinstance(v, (np.floating, float)) else float(v))
                      for k, v in row.items() if k in ("rep", "partial", "usable", "i_start", "i_peak", "i_end",
                                                       "t_start", "t_peak", "t_end", "rest_max")} for row in out["rows"]],
               samples=[])
    if frame_debug and head is not None:
        res["count_signal_smoothed"] = out["s"]
        M, names, _, _ = sds._frame_matrix(out["r"], out["sig"], out["scal"], ex, out["arm"], b0, b1, sl.COUNT_SIGNAL[ex],
                                           out["silsig"])
        wanted = [n for n in (head["stored_channels"][i] for i in head["input_selection"]) if n in names]
        res["frame_channels"] = dict(names=wanted, values=M[:, [names.index(n) for n in wanted]])
    if out["X"] is None or not len(out["use"]) or ex not in cfg["heads"]:
        return res
    x, f = head_inputs(out, ex, head)
    P = predict(ex, x, f)
    classes = head["classes"]
    for j, i in enumerate(out["use"]):
        s = dict(rep=out["rows"][i]["rep"], probs=P[j], label=classes[int(np.argmax(P[j]))], confidence=float(np.max(P[j])))
        if spec is not None:
            s["status"], s["message"] = verdict(spec, ex, s["label"], s["confidence"], side)
        if dump_inputs:
            s["x"], s["f"] = x[j], f[j]
        res["samples"].append(s)
    return res


def verdict(spec, ex, label, confidence, side):
    fb = spec["feedback"]
    if confidence < fb["min_confidence"]:
        return "unsure", fb["messages"]["unsure"]
    arm = {"left": "left", "right": "right"}.get(side, "")
    return ("good" if label == "good" else "mistake"), fb["messages"][ex][label].format(arm=arm)


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
    ap.add_argument("--exercise", required=True, choices=["e1", "e2", "e3"])
    ap.add_argument("--side", choices=["left", "right"], default=None,
                    help="e2/e3: working arm; e1: injured arm (the app asks the patient)")
    ap.add_argument("--model", choices=["multitask", "separate"], default="multitask",
                    help="multitask: one network for the 3 exercises; separate: the final notebook's network of the exercise")
    ap.add_argument("--bundle", default=str(HERE.parent), help="folder with models/ and app_spec.json")
    ap.add_argument("--out", default=None)
    ap.add_argument("--no-inputs", action="store_true", help="do not write the model inputs x/f of every rep")
    a = ap.parse_args()
    heads = Model(a.bundle, a.model)
    spec_p = Path(a.bundle) / "app_spec.json"
    spec = json.loads(spec_p.read_text()) if spec_p.exists() else None
    res = run_reference(load_pose(a.pose), a.exercise, a.side, heads.cfg, heads, spec, key=Path(a.pose).stem,
                        dump_inputs=not a.no_inputs)
    for s in res.get("samples", []):
        print(f"rep {s['rep']:>3}: {s['label']:<8} {s['confidence']:.2f}  {s.get('message', '')}")
    print(f"{len(res.get('reps', []))} reps found, {len(res.get('samples', []))} scored | arm {res.get('arm')} | "
          f"baseline {res.get('baseline')}")
    if a.out:
        Path(a.out).write_text(json.dumps(to_json(res)))
        print("written", a.out)


if __name__ == "__main__":
    main()
