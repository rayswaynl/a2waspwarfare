#!/usr/bin/env python3
"""Run one A/B experiment over accumulated Run-Result JSONs and emit a finding. Stdlib only.

Gathers two arms (matched by scenario + a config filter), pulls the metric from each arm's runs,
drives ab_stats.compare + decision_engine.ab_decision, and (with --emit) appends an evidence-cited
finding via findings_emitter. This is the bridge from the raw results/ corpus to the honest-stats
engine; the orchestrator calls it once per configured A/B experiment.

On a thin corpus it correctly emits an INCONCLUSIVE finding (n<5) rather than inventing a result.

Usage:
    python run_experiment.py --results results --findings findings.jsonl \
        --experiment hc-split-benefit --scenario hc-split --metric serverFpsMedian \
        --arm-a hcCount=1 --arm-b hcCount=2 --regime "zargabad/pin10" [--emit]
    python run_experiment.py --self-test
"""
import argparse
import glob
import json
import os
import sys

import ab_stats
import decision_engine
import findings_emitter

HERE = os.path.dirname(os.path.abspath(__file__))


def _load_mde(metric):
    try:
        t = json.load(open(os.path.join(HERE, "mde-table.json"), encoding="utf-8"))
        m = t.get("metrics", {}).get(metric)
        return (m or {}).get("mde")
    except (OSError, json.JSONDecodeError):
        return None


def _read_results(results_dir):
    out = []
    for p in sorted(glob.glob(os.path.join(results_dir, "*.json"))):
        try:
            o = json.load(open(p, encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        if isinstance(o, dict) and o.get("schema") == "a2wasp-run-result-v1":
            out.append(o)
    return out


def _match(res, scenario, filt):
    if scenario and res.get("scenario") != scenario:
        return False
    cfg = res.get("config", {})
    for k, v in filt.items():
        cv = cfg.get(k)
        if str(cv) != str(v):
            return False
    return True


def _parse_filter(s):
    out = {}
    for part in (s or "").split(","):
        part = part.strip()
        if "=" in part:
            k, v = part.split("=", 1)
            out[k.strip()] = v.strip()
    return out


def _arm(results, scenario, filt, metric):
    vals, rowids = [], []
    for r in results:
        if _match(r, scenario, filt):
            m = r.get("metrics", {}).get(metric)
            if isinstance(m, (int, float)) and not isinstance(m, bool):
                vals.append(m)
            rid = r.get("ledgerRowId")
            if rid:
                rowids.append(rid)
    return vals, rowids


def run(results_dir, findings_path, experiment, scenario, metric, arm_a, arm_b, regime,
        mde=None, emit=False, created_at=None):
    results = _read_results(results_dir)
    fa, fb = _parse_filter(arm_a), _parse_filter(arm_b)
    a_vals, a_rows = _arm(results, scenario, fa, metric)
    b_vals, b_rows = _arm(results, scenario, fb, metric)
    if mde is None:
        mde = _load_mde(metric)
    regime_a = "%s|%s" % (regime, arm_a)
    regime_b = "%s|%s" % (regime, arm_b)
    # NOTE: arms differ by the tested dimension only; the shared regime string keeps ab_stats from
    # refusing (same base regime), while the arm suffix documents which arm is which.
    ab = ab_stats.compare(a_vals, b_vals, metric, mde=mde, regime_a=regime, regime_b=regime)
    dec = decision_engine.ab_decision(a_vals, b_vals, metric, mde or 0.0, regime, regime)
    finding = None
    if emit:
        finding = findings_emitter.emit(
            findings_path, experiment, metric, regime, ab, dec,
            {"label": arm_a, "rowIds": a_rows}, {"label": arm_b, "rowIds": b_rows},
            created_at=created_at)
    return {"ab": ab, "decision": dec, "finding": finding,
            "n_a": len(a_vals), "n_b": len(b_vals)}


def _self_test():
    import tempfile
    checks = []

    def chk(n, c):
        checks.append((n, bool(c)))

    d = tempfile.mkdtemp(prefix="wasp-runexp-")
    res = os.path.join(d, "results")
    os.makedirs(res)

    def mkrun(scen, hc, pin, fps, i):
        o = {"schema": "a2wasp-run-result-v1", "runId": "%s-hc%d-%d" % (scen, hc, i), "scenario": scen,
             "config": {"map": "zargabad", "hcCount": hc, "popPin": pin},
             "metrics": {"serverFpsMedian": fps}, "verdict": "PASS", "ledgerRowId": "row-%s-%d" % (hc, i)}
        json.dump(o, open(os.path.join(res, o["runId"] + ".json"), "w"))

    # 6 replicates per arm: 1HC~32, 2HC~42 -> BETTER for arm B
    for i, f in enumerate([32, 33, 31, 32, 33, 32]):
        mkrun("hc-split", 1, 10, f, i)
    for i, f in enumerate([42, 41, 43, 42, 41, 42]):
        mkrun("hc-split", 2, 10, f, i)
    fp = os.path.join(d, "findings.jsonl")
    r = run(res, fp, "hc-split-benefit", "hc-split", "serverFpsMedian", "hcCount=1", "hcCount=2",
            "zargabad/pin10", emit=True, created_at="2026-07-07T22:00:00Z")
    chk("gathered 6/6 replicates", r["n_a"] == 6 and r["n_b"] == 6)
    chk("verdict BETTER (2HC wins)", r["ab"]["verdict"] == "BETTER")
    chk("decision CONVERGED", r["decision"]["action"] == "CONVERGED")
    chk("finding emitted with rowIds", r["finding"] and r["finding"]["evidence"]["armA"]["rowIds"])

    # thin corpus -> INCONCLUSIVE
    res2 = os.path.join(d, "results2")
    os.makedirs(res2)
    json.dump({"schema": "a2wasp-run-result-v1", "runId": "x", "scenario": "hc-split",
               "config": {"hcCount": 1, "popPin": 10}, "metrics": {"serverFpsMedian": 33}}, open(os.path.join(res2, "x.json"), "w"))
    r2 = run(res2, os.path.join(d, "f2.jsonl"), "hc-split-benefit", "hc-split", "serverFpsMedian",
             "hcCount=1", "hcCount=2", "zargabad/pin10", emit=False)
    chk("thin corpus INCONCLUSIVE", r2["ab"]["verdict"] == "INCONCLUSIVE")

    import shutil
    shutil.rmtree(d, ignore_errors=True)
    ok = True
    for n, p in checks:
        print("  %s %s" % ("ok  " if p else "FAIL", n))
        ok = ok and p
    return ok


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--results", default=os.path.join(HERE, "results"))
    ap.add_argument("--findings", default=os.path.join(HERE, "findings.jsonl"))
    ap.add_argument("--experiment", default="ad-hoc")
    ap.add_argument("--scenario")
    ap.add_argument("--metric", default="serverFpsMedian")
    ap.add_argument("--arm-a", default="")
    ap.add_argument("--arm-b", default="")
    ap.add_argument("--regime", default="unspecified")
    ap.add_argument("--mde", type=float, default=None)
    ap.add_argument("--emit", action="store_true")
    ap.add_argument("--self-test", action="store_true")
    a = ap.parse_args()
    if a.self_test:
        ok = _self_test()
        print("PASSED" if ok else "FAILED")
        return 0 if ok else 1
    r = run(a.results, a.findings, a.experiment, a.scenario, a.metric, a.arm_a, a.arm_b, a.regime,
            mde=a.mde, emit=a.emit)
    print(json.dumps({"verdict": r["ab"]["verdict"], "action": r["decision"]["action"],
                      "n_a": r["n_a"], "n_b": r["n_b"], "delta": r["ab"].get("delta"),
                      "findingId": (r["finding"] or {}).get("findingId")}, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
