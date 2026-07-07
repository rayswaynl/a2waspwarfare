#!/usr/bin/env python3
"""Emit evidence-cited experiment findings to an append-only findings.jsonl. Stdlib only.

A finding is the autopilot's durable output: a verdict (from ab_stats/decision_engine) plus the full
evidence chain that produced it -- both arms' rowIds, n, mean/stdev, the test used, the MDE, and the
decision. It is deliberately auditable: every claim cites the ledger rows it rests on, so a finding
can never be "trust me". The recommender reads findings (never raw metrics) and the A/B chart draws
from them.

Never fabricates: INCONCLUSIVE / REFUSE verdicts are recorded as first-class findings, not hidden.

Usage:
    import findings_emitter as fe
    fe.emit(findings_path, experiment="hc-split@pin10", metric="serverFpsMedian",
            regime="zargabad/2hc/pin10", ab=ab_result, decision=dec,
            arm_a={"label": "1hc", "rowIds": [...]}, arm_b={"label": "2hc", "rowIds": [...]},
            created_at="2026-07-07T21:00:00Z")
    python findings_emitter.py --self-test
"""
import argparse
import json
import os
import sys

SCHEMA = "a2wasp-finding-v1"
HEADER = "# a2wasp-findings-v1 jsonl; skip lines beginning with '#'"


def _utc_now():
    # datetime is fine here (not a workflow script). Kept isolated so callers can inject a stamp.
    from datetime import datetime, timezone
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def iter_findings(path):
    if not path or not os.path.exists(path):
        return
    with open(path, "r", encoding="utf-8-sig") as fh:
        for line in fh:
            s = line.strip()
            if not s or s.startswith("#"):
                continue
            try:
                yield json.loads(s)
            except json.JSONDecodeError:
                continue


def _next_seq(path, day):
    mx = 0
    for f in iter_findings(path):
        fid = f.get("findingId", "")
        if fid.startswith(day + "-"):
            try:
                mx = max(mx, int(fid.split("-")[-1]))
            except ValueError:
                pass
    return mx + 1


def build_finding(experiment, metric, regime, ab, decision, arm_a, arm_b,
                  created_at=None, finding_id=None, recommendation=None):
    """Assemble a finding dict from an ab_stats result + a decision + arm provenance."""
    ab = ab or {}
    created_at = created_at or _utc_now()
    verdict = (decision or {}).get("verdict") or ab.get("verdict") or "INCONCLUSIVE"
    ev = {
        "armA": {
            "label": (arm_a or {}).get("label"), "n": ab.get("n_a"),
            "mean": ab.get("mean_a"), "stdev": ab.get("stdev_a"),
            "rowIds": (arm_a or {}).get("rowIds", []),
        },
        "armB": {
            "label": (arm_b or {}).get("label"), "n": ab.get("n_b"),
            "mean": ab.get("mean_b"), "stdev": ab.get("stdev_b"),
            "rowIds": (arm_b or {}).get("rowIds", []),
        },
        "delta": ab.get("delta"), "pctDelta": ab.get("pctDelta"),
        "test": "nonparametric-p10p90" if ab.get("kind") == "count" else "welch-t",
        "welch_t": ab.get("welch_t"), "t_crit": ab.get("t_crit"), "df": ab.get("df"),
        "cohens_d": ab.get("cohens_d"), "mde": ab.get("mde"),
        "significant": ab.get("significant"), "practicallySignificant": ab.get("practicallySignificant"),
        "direction": ab.get("direction"),
    }
    return {
        "schema": SCHEMA,
        "findingId": finding_id,   # filled by emit() when appending
        "createdAtUtc": created_at,
        "experiment": experiment,
        "metric": metric,
        "regime": regime,
        "verdict": verdict,
        "evidence": ev,
        "decision": {"action": (decision or {}).get("action"), "reason": (decision or {}).get("reason"),
                     "note": (decision or {}).get("note") or ab.get("note")},
        "recommendation": recommendation,   # set by the recommender later; null here
    }


def emit(findings_path, experiment, metric, regime, ab, decision, arm_a, arm_b,
         created_at=None, recommendation=None):
    """Append one finding; generate its findingId (YYYYMMDD-NNNN). Returns the finding dict."""
    created_at = created_at or _utc_now()
    day = created_at[:10].replace("-", "")
    fid = "%s-%04d" % (day, _next_seq(findings_path, day))
    f = build_finding(experiment, metric, regime, ab, decision, arm_a, arm_b,
                      created_at=created_at, finding_id=fid, recommendation=recommendation)
    d = os.path.dirname(os.path.abspath(findings_path))
    if d and not os.path.isdir(d):
        os.makedirs(d)
    new = not os.path.exists(findings_path)
    with open(findings_path, "a", encoding="utf-8", newline="\n") as fh:
        if new:
            fh.write(HEADER + "\n")
        fh.write(json.dumps(f, ensure_ascii=False) + "\n")
    return f


def _self_test():
    import tempfile
    checks = []

    def chk(n, c):
        checks.append((n, bool(c)))

    d = tempfile.mkdtemp(prefix="wasp-find-test-")
    fp = os.path.join(d, "findings.jsonl")
    ab = {"verdict": "WORSE", "n_a": 6, "n_b": 6, "mean_a": 42.0, "mean_b": 32.0, "stdev_a": 0.9,
          "stdev_b": 0.9, "delta": -10.0, "pctDelta": -23.8, "kind": "parametric", "welch_t": -19.2,
          "t_crit": 2.228, "df": 10.0, "cohens_d": -11.1, "mde": 2.0, "significant": True,
          "practicallySignificant": True, "direction": "worse", "note": "clear"}
    dec = {"action": "CONVERGED", "verdict": "WORSE", "reason": "significant+practical", "note": "clear"}
    f1 = emit(fp, "hc-split@pin10", "serverFpsMedian", "zargabad/2hc/pin10", ab, dec,
              {"label": "1hc", "rowIds": ["20260707-0001", "20260707-0003"]},
              {"label": "2hc", "rowIds": ["20260707-0002", "20260707-0004"]},
              created_at="2026-07-07T21:00:00Z")
    chk("findingId dated seq", f1["findingId"] == "20260707-0001")
    chk("verdict recorded", f1["verdict"] == "WORSE")
    chk("evidence cites rowIds", f1["evidence"]["armA"]["rowIds"] == ["20260707-0001", "20260707-0003"])
    chk("test = welch", f1["evidence"]["test"] == "welch-t")
    chk("recommendation null until recommender", f1["recommendation"] is None)

    f2 = emit(fp, "a-life@pin4", "captures", "chernarus/1hc/pin4",
              {"verdict": "INCONCLUSIVE", "n_a": 3, "n_b": 4, "kind": "count", "delta": None},
              {"action": "NEED_MORE_REPLICATES", "reason": "below-min-n", "note": "thin"},
              {"label": "off", "rowIds": ["20260707-0005"]}, {"label": "on", "rowIds": []},
              created_at="2026-07-07T21:05:00Z")
    chk("second findingId increments", f2["findingId"] == "20260707-0002")
    chk("INCONCLUSIVE recorded not hidden", f2["verdict"] == "INCONCLUSIVE")

    rows = list(iter_findings(fp))
    chk("two findings on file", len(rows) == 2)
    chk("header comment present", open(fp, encoding="utf-8").readline().startswith("#"))
    chk("all rows carry schema", all(r.get("schema") == SCHEMA for r in rows))

    import shutil
    shutil.rmtree(d, ignore_errors=True)
    ok = True
    for n, p in checks:
        print("  %s %s" % ("ok  " if p else "FAIL", n))
        ok = ok and p
    return ok


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    if args.self_test:
        ok = _self_test()
        print("PASSED" if ok else "FAILED")
        return 0 if ok else 1
    ap.print_help()
    return 0


if __name__ == "__main__":
    sys.exit(main())
