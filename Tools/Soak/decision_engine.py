#!/usr/bin/env python3
"""Convergence controller for the WASP autopilot. Stdlib only.

Turns ab_stats verdicts into the next move so an experiment terminates instead of piling replicates
forever. Two decision entry points:

  ab_decision(arm_a, arm_b, ...)  -> A/B: replicate each arm to MIN_N, then keep replicating only
                                     while the test is UNDERPOWERED (2*combined-SEM >= MDE), capped
                                     at N_MAX. A powered NO_DIFF is a real "they tie", not "not enough
                                     data yet". BETTER/WORSE ends it.

  sweep_decision(points, ...)     -> knee sweep: ensure each grid point has MIN_N replicates, find the
                                     steepest adjacent drop (the knee bracket), and either CONVERGE (the
                                     bracket is at grid resolution) or BISECT its midpoint -- never pile
                                     more replicates onto an already-powered point just to "be sure".

Actions: NEED_MORE_REPLICATES | BISECT | CONVERGED | STOP.

Usage:  python decision_engine.py --self-test
"""
import argparse
import math
import statistics
import sys

import ab_stats

MIN_N = 5
N_MAX = 12


def _clean(v):
    return ab_stats._clean(v)


def ab_decision(arm_a, arm_b, metric, mde, regime_a=None, regime_b=None, min_n=MIN_N, n_max=N_MAX):
    """Decide the next move for a two-arm A/B."""
    a, b = _clean(arm_a), _clean(arm_b)
    if regime_a is not None and regime_b is not None and regime_a != regime_b:
        return {"action": "STOP", "reason": "regime-mismatch",
                "verdict": "REFUSE_REGIME_MISMATCH", "needArm": None,
                "note": "arms are different regimes; refuse to compare."}

    # 1) floor: both arms must reach min_n
    if len(a) < min_n:
        return {"action": "NEED_MORE_REPLICATES", "needArm": "A", "have": len(a), "target": min_n,
                "reason": "below-min-n", "note": "arm A needs %d more" % (min_n - len(a))}
    if len(b) < min_n:
        return {"action": "NEED_MORE_REPLICATES", "needArm": "B", "have": len(b), "target": min_n,
                "reason": "below-min-n", "note": "arm B needs %d more" % (min_n - len(b))}

    r = ab_stats.compare(a, b, metric, mde=mde, regime_a=regime_a, regime_b=regime_b, min_n=min_n)

    if r["verdict"] in ("BETTER", "WORSE"):
        return {"action": "CONVERGED", "verdict": r["verdict"], "ab": r,
                "reason": "significant+practical", "note": r["note"]}

    # NO_DIFF (or count NO_DIFF): powered?  For the parametric path, "powered" means the combined
    # 2*SEM is already smaller than the MDE we care about -> we *would* have seen a real effect.
    powered = True
    if r["kind"] == "parametric" and r.get("sem_a") is not None and mde:
        combined = 2.0 * math.sqrt(r["sem_a"] ** 2 + r["sem_b"] ** 2)
        powered = combined < mde
    if powered:
        return {"action": "STOP", "verdict": "NO_DIFF", "ab": r,
                "reason": "powered-no-diff", "note": "no practical difference at the target MDE."}
    if max(len(a), len(b)) >= n_max:
        return {"action": "STOP", "verdict": "INCONCLUSIVE", "ab": r,
                "reason": "n-max-underpowered",
                "note": "hit N_MAX=%d still underpowered; report as inconclusive, do not claim NO_DIFF." % n_max}
    arm = "A" if len(a) <= len(b) else "B"
    return {"action": "NEED_MORE_REPLICATES", "needArm": arm, "have": min(len(a), len(b)),
            "target": min(n_max, max(len(a), len(b)) + 1), "reason": "underpowered",
            "note": "2*SEM still >= MDE; add a replicate to the smaller arm."}


def sweep_decision(points, metric, mde, min_n=MIN_N, n_max=N_MAX, min_step=1):
    """points = [{"x": <number>, "values": [<metric ...>]}]. Decide the next sweep move."""
    pts = sorted((p for p in points if p.get("x") is not None), key=lambda p: p["x"])
    if len(pts) < 2:
        return {"action": "NEED_MORE_REPLICATES", "target": None, "reason": "need-2-points",
                "note": "a knee sweep needs at least two grid points."}

    # 1) every point must reach min_n (unless already at n_max)
    for p in pts:
        n = len(_clean(p["values"]))
        if n < min_n and n < n_max:
            return {"action": "NEED_MORE_REPLICATES", "target": p["x"], "have": n,
                    "reason": "point-below-min-n", "note": "x=%s needs %d more replicate(s)" % (p["x"], min_n - n)}

    means = [(p["x"], statistics.fmean(_clean(p["values"]))) for p in pts if _clean(p["values"])]
    # 2) steepest adjacent drop = the knee bracket
    worst_i, worst_drop = None, 0.0
    for i in range(len(means) - 1):
        drop = means[i][1] - means[i + 1][1]
        if drop > worst_drop:
            worst_drop, worst_i = drop, i
    if worst_i is None or (mde and worst_drop < mde):
        return {"action": "CONVERGED", "knee": None, "reason": "no-knee",
                "note": "no adjacent drop exceeds the MDE across the sampled range."}

    xlo, xhi = means[worst_i][0], means[worst_i + 1][0]
    if (xhi - xlo) <= min_step:
        return {"action": "CONVERGED", "knee": [xlo, xhi], "reason": "bracketed",
                "note": "knee bracketed to grid resolution between %s and %s." % (xlo, xhi)}
    mid = round((xlo + xhi) / 2.0)
    if mid <= xlo or mid >= xhi:
        return {"action": "CONVERGED", "knee": [xlo, xhi], "reason": "bracketed",
                "note": "midpoint collapses to an existing grid point; knee is between %s and %s." % (xlo, xhi)}
    return {"action": "BISECT", "target": mid, "knee": [xlo, xhi], "reason": "refine-knee",
            "note": "sample x=%s to halve the knee bracket [%s, %s]." % (mid, xlo, xhi)}


def _self_test():
    checks = []

    def chk(name, cond):
        checks.append((name, bool(cond)))

    # A/B: below min_n on B
    d = ab_decision([42, 41, 43, 42, 42], [32, 33], "serverFpsMedian", 2.0, "x", "x")
    chk("A/B needs more on arm B", d["action"] == "NEED_MORE_REPLICATES" and d["needArm"] == "B")

    # A/B: clear win -> CONVERGED
    d2 = ab_decision([32, 33, 31, 32, 33, 32], [41, 42, 40, 41, 42, 41], "serverFpsMedian", 2.0, "x", "x")
    chk("A/B clear win CONVERGED BETTER", d2["action"] == "CONVERGED" and d2["verdict"] == "BETTER")

    # A/B: tight tie, powered -> STOP NO_DIFF
    d3 = ab_decision([42.0, 42.1, 41.9, 42.0, 42.1, 42.0], [42.1, 42.0, 42.2, 42.0, 42.1, 42.0],
                     "serverFpsMedian", 2.0, "x", "x")
    chk("A/B powered tie STOP NO_DIFF", d3["action"] == "STOP" and d3["verdict"] == "NO_DIFF")

    # A/B: noisy tie, underpowered, under n_max -> NEED_MORE
    d4 = ab_decision([40, 44, 39, 45, 41], [41, 45, 38, 46, 42], "serverFpsMedian", 1.0, "x", "x")
    chk("A/B underpowered needs more", d4["action"] == "NEED_MORE_REPLICATES" and d4["reason"] == "underpowered")

    # A/B: regime mismatch -> STOP
    d5 = ab_decision([42, 41, 43, 42, 42], [32, 31, 33, 32, 32], "serverFpsMedian", 2.0, "z", "c")
    chk("A/B mismatch STOP", d5["action"] == "STOP" and d5["reason"] == "regime-mismatch")

    # sweep: a point lacks replicates
    s = sweep_decision([{"x": 3, "values": [47, 46, 47]}, {"x": 6, "values": [44, 45, 44, 45, 44]}],
                       "serverFpsMedian", 3.0)
    chk("sweep needs replicates at x=3", s["action"] == "NEED_MORE_REPLICATES" and s["target"] == 3)

    # sweep: coarse knee between 6 and 14 -> BISECT ~10
    full = [{"x": 3, "values": [48] * 5}, {"x": 6, "values": [46] * 5},
            {"x": 14, "values": [26] * 5}]
    s2 = sweep_decision(full, "serverFpsMedian", 3.0)
    chk("sweep BISECT the coarse knee", s2["action"] == "BISECT" and 6 < s2["target"] < 14)

    # sweep: knee bracketed at grid resolution -> CONVERGED
    s3 = sweep_decision([{"x": 9, "values": [40] * 5}, {"x": 10, "values": [30] * 5}],
                        "serverFpsMedian", 3.0)
    chk("sweep CONVERGED bracketed", s3["action"] == "CONVERGED" and s3["reason"] == "bracketed")

    # sweep: no knee (flat) -> CONVERGED no-knee
    s4 = sweep_decision([{"x": 3, "values": [45] * 5}, {"x": 6, "values": [45] * 5},
                         {"x": 10, "values": [44] * 5}], "serverFpsMedian", 3.0)
    chk("sweep CONVERGED no-knee", s4["action"] == "CONVERGED" and s4["reason"] == "no-knee")

    ok = True
    for name, passed in checks:
        print("  %s %s" % ("ok  " if passed else "FAIL", name))
        ok = ok and passed
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
