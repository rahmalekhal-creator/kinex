#!/usr/bin/env python3
"""Extra test fixtures for the Dart port, computed with the bundle's Python reference (source of truth).

    python tool/shoulder_ref/make_fixtures.py

np_cases.json     numpy / scipy primitives on random and edge-case signals (find_peaks with plateaus and ties,
                  savgol_filter edges, percentiles, interp, rounding).
extra_cases.json  the golden recordings cut the way the live app sees them: the buffer ending 0.5 s after a rep
                  (live scoring) and the recording starting in the rest before a rep (a 'first_break' baseline).
                  Expected = reference_predict.run_reference (arm, baseline, reps, probs, labels, f, x of the
                  first scored rep).
"""
import json
import sys
from pathlib import Path

import numpy as np
from scipy.signal import find_peaks, savgol_filter

ROOT = Path(__file__).resolve().parents[2]
BUNDLE = ROOT / "shoulder_app_bundle"
sys.path.insert(0, str(BUNDLE / "reference_python"))
import reference_predict as rp  # noqa: E402
import shoulder_lib as sl  # noqa: E402

OUT = ROOT / "test" / "shoulder" / "fixtures"


def j(o):
    return rp.to_json(o)


def np_cases():
    rng = np.random.default_rng(0)
    cases = []
    for k in range(12):
        n = int(rng.integers(40, 400))
        x = np.cumsum(rng.normal(0, 1, n))
        if k % 3 == 0:                                    # plateaus and exact ties
            x = np.round(x)
            x = x + 1e-3 * np.cumsum(np.r_[0, np.diff(x) != 0])   # plateaus stay, distinct peaks differ (no height ties)
        if k % 4 == 1:
            x[rng.integers(0, n, 5)] = np.nan
        xf = sl.fill_nan(x)
        prom = float(0.2 * (np.nanmax(x) - np.nanmin(x)))
        dist = float(rng.choice([1, 3, 7.5, 14]))
        pk, pr = find_peaks(xf, prominence=prom, distance=dist)
        win = int(rng.choice([5, 9, 13]))
        q = [5.0, 50.0, 95.0, 37.5]
        xp = np.sort(rng.uniform(0, 10, 15))
        xq = rng.uniform(-1, 11, 30)
        cases.append(dict(x=x, filled=xf, prominence=prom, distance=dist, peaks=pk, prominences=pr["prominences"],
                          window=win, savgol=savgol_filter(xf, win, 2), smooth=sl.smooth_nan(x, 30.0, 0.25),
                          q=q, nanpercentile=[float(np.nanpercentile(x, v)) for v in q],
                          nanmedian=float(np.nanmedian(x)), xp=xp, fp=np.sin(xp), xq=xq, interp=np.interp(xq, xp, np.sin(xp))))
    halves = [0.5, 1.5, 2.5, -0.5, -1.5, 4.5, 4.499999999999999, 0.15 * 30, 0.25 * 30, 7.5, 12.5]
    plateau = dict(x=[0, 1, 1, 1, 0, 2, 2, 0, 1, 3, 3, 3, 3, 0, 3, 0], prominence=0.5, distance=1.0)
    pk, pr = find_peaks(np.asarray(plateau["x"], float), prominence=0.5)
    plateau.update(peaks=pk, prominences=pr["prominences"])
    f16 = np.concatenate([rng.normal(0, 1, 200), rng.uniform(0, 3, 200), [0.0, 1e-5, 3e-8, 65504.0, 0.333251953125, 2.0 ** -14]])
    f16 = f16.astype(np.float32).astype(np.float64)
    return dict(cases=cases, rounding=dict(x=halves, round=[round(v) for v in halves]), plateau=plateau,
                f16=dict(x=f16, f16=f16.astype(np.float32).astype(np.float16).astype(np.float64)))


def run(d, ex, side, cfg, model, spec):
    return rp.run_reference(d, ex, side, cfg, model, spec, frame_debug=False)


def cut(inp, t0_ms=None, t1_ms=None):
    t = np.asarray(inp["t_ms"], float)
    keep = np.ones(len(t), bool)
    if t0_ms is not None:
        keep &= t >= t0_ms
    if t1_ms is not None:
        keep &= t <= t1_ms
    idx = np.flatnonzero(keep)
    out = dict(inp)
    for k in ("t_ms", "lm", "world"):
        out[k] = [inp[k][i] for i in idx]
    if inp.get("sil") is not None:
        out["sil"] = [inp["sil"][i] for i in idx]
    return out


def extra_cases():
    model = rp.Model(BUNDLE, "multitask")
    spec = json.loads((BUNDLE / "app_spec.json").read_text())
    cases = []
    for p in sorted((BUNDLE / "golden").glob("e*__*.json")):
        g = json.loads(p.read_text())
        ex, side, inp = g["exercise"], g["side"], g["input"]
        exp = g["expected"]
        t0 = float(exp["t0_s"]) * 1000.0
        reps = [r for r in exp["reps"] if r["usable"]]
        variants = []
        # live buffer: ends 0.5 s after the end of the 2nd and of the middle usable rep
        for r in (reps[1], reps[len(reps) // 2]):
            variants.append((f"live_after_rep{r['rep']}", None, t0 + (r["i_end"] / 30.0 + 0.5) * 1000.0))
        # first break: start ~1.2 s before the rest that precedes the 3rd usable rep
        r = reps[2]
        variants.append(("start_before_rep%d" % r["rep"], t0 + (r["i_start"] / 30.0 - 2.0) * 1000.0, None))
        for name, a, b in variants:
            a = None if a is None else float(round(a))        # whole ms: the test cuts with exactly these bounds
            b = None if b is None else float(round(b))
            sub = cut(inp, a, b)
            d = _to_d(sub)
            res = run(d, ex, side, model.cfg, model, spec)
            cases.append(dict(source=p.name, name=name, exercise=ex, side=side, t_from_ms=a, t_to_ms=b,
                              expected=dict(arm=res["arm"], baseline=res["baseline"],
                                            reps=[{k: r2[k] for k in ("i_start", "i_peak", "i_end", "partial", "usable")}
                                                  for r2 in res["reps"]],
                                            samples=[dict(rep=s["rep"], probs=s["probs"], label=s["label"],
                                                          message=s["message"], f=s["f"],
                                                          x=s["x"] if i == 0 else None)
                                                     for i, s in enumerate(res["samples"])])))
            print(p.name, name, res["baseline"], len(res["reps"]), "reps", len(res["samples"]), "scored")
    return cases


def _to_d(j_):
    """reference_predict.load_pose for an in-memory dict."""
    arr = lambda v, tail: np.array([[[np.nan if x is None else x for x in row] for row in fr] if fr is not None
                                    else np.full(tail, np.nan) for fr in v], np.float32)
    d = dict(t_ms=np.asarray(j_["t_ms"], np.float64), lm=arr(j_["lm"], (33, 5)), world=arr(j_["world"], (33, 3)),
             meta=dict(width=j_["width"], height=j_["height"]))
    if j_.get("sil_names"):
        d["meta"]["sil_names"] = j_["sil_names"]
    if j_.get("sil") is not None:
        d["sil"] = arr(j_["sil"], (2, 9))
    return d


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "np_cases.json").write_text(json.dumps(j(np_cases())))
    (OUT / "extra_cases.json").write_text(json.dumps(j(extra_cases())))
    print("written", OUT)
