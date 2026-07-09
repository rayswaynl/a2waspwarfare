#!/usr/bin/env python3
"""Replicate-aware A/B comparison for WASP soak metrics. Stdlib only.

The honest-statistics core of the autopilot. Given two arms (each a list of a metric's values
across matched-regime replicate runs), decide whether arm B beat/lost/tied arm A -- or whether we
simply do not have the evidence yet. Two hard rules keep it from lying:

  * n < MIN_N per arm  -> INCONCLUSIVE (never a "finding" on a thin corpus; the sandbox starts empty).
  * regime mismatch    -> REFUSE (an A/B across different terrain/HC/pin/duration measures the regime,
                          not the change -- the #1 false-finding hazard).

A real difference must clear BOTH gates: statistical (Welch t vs an embedded two-tailed t-table,
so it works with no scipy and small n) AND practical (|delta| >= the metric's minimum detectable
effect). FPS-like metrics use the parametric path; heavy-tailed count metrics (captures, arrival,
zombies) route through a nonparametric p10..p90-separation path where a t-test on a few events is invalid.

Usage:
    import ab_stats
    r = ab_stats.compare(arm_a, arm_b, metric="serverFpsMedian", mde=2.0,
                         regime_a="zargabad/2hc/pin10", regime_b="zargabad/2hc/pin10")
    python ab_stats.py --self-test
"""
import argparse
import math
import statistics
import sys

MIN_N = 5  # replicates per arm before any verdict other than INCONCLUSIVE

# Metric direction: is a HIGHER value better? aiTotPeak is neutral (context, not goal).
METRIC_DIRECTION = {
    "serverFpsMedian": "up", "serverFpsMin": "up", "hcFpsMedian": "up", "hc2FpsMedian": "up",
    "arrivalPct": "up", "captures": "up", "maxTownsWest": "up", "maxTownsEast": "up",
    "aiTotPeak": "neutral", "guerPeak": "neutral",
}
# Count-like metrics get the nonparametric path.
COUNT_METRICS = {"captures", "arrivalPct", "maxTownsWest", "maxTownsEast", "guerPeak"}

# Two-tailed t critical values at alpha=0.05, by degrees of freedom. Missing df -> nearest lower
# tabulated df (conservative: a higher crit makes "significant" harder, suppressing false positives).
_T05 = {1: 12.706, 2: 4.303, 3: 3.182, 4: 2.776, 5: 2.571, 6: 2.447, 7: 2.365, 8: 2.306,
        9: 2.262, 10: 2.228, 11: 2.201, 12: 2.179, 13: 2.160, 14: 2.145, 15: 2.131,
        16: 2.120, 18: 2.101, 20: 2.086, 25: 2.060, 30: 2.042, 40: 2.021, 60: 2.000,
        120: 1.980, 100000: 1.960}


def _t_crit(df):
    if df is None or df < 1:
        return _T05[1]
    keys = sorted(_T05)
    pick = keys[0]
    for k in keys:
        if k <= df:
            pick = k
        else:
            break
    return _T05[pick]


def _clean(values):
    out = []
    for v in values or []:
        if v is None:
            continue
        if isinstance(v, bool):
            continue
        if isinstance(v, (int, float)) and not math.isnan(v):
            out.append(float(v))
    return out


def _pct(a, b):
    return None if (a is None or a == 0) else round((b - a) / abs(a) * 100.0, 2)


def _percentile(sorted_vals, q):
    if not sorted_vals:
        return None
    if len(sorted_vals) == 1:
        return sorted_vals[0]
    pos = q * (len(sorted_vals) - 1)
    lo = int(math.floor(pos))
    hi = int(math.ceil(pos))
    if lo == hi:
        return sorted_vals[lo]
    frac = pos - lo
    return sorted_vals[lo] * (1 - frac) + sorted_vals[hi] * frac


def _base(metric, a, b, regime_a, regime_b):
    mean_a = statistics.fmean(a) if a else None
    mean_b = statistics.fmean(b) if b else None
    delta = None if (mean_a is None or mean_b is None) else round(mean_b - mean_a, 4)
    return {
        "metric": metric, "regimeMatch": (regime_a == regime_b),
        "regimeA": regime_a, "regimeB": regime_b,
        "n_a": len(a), "n_b": len(b),
        "mean_a": None if mean_a is None else round(mean_a, 4),
        "mean_b": None if mean_b is None else round(mean_b, 4),
        "median_a": round(statistics.median(a), 4) if a else None,
        "median_b": round(statistics.median(b), 4) if b else None,
        "stdev_a": round(statistics.stdev(a), 4) if len(a) > 1 else None,
        "stdev_b": round(statistics.stdev(b), 4) if len(b) > 1 else None,
        "delta": delta, "pctDelta": None if delta is None else _pct(mean_a, mean_b),
        "sem_a": None, "sem_b": None, "cohens_d": None, "welch_t": None, "df": None,
        "t_crit": None, "significant": None, "mde": None, "practicallySignificant": None,
        "kind": None, "direction": "flat", "verdict": None, "note": "",
    }


def _direction(metric, delta):
    if delta is None or abs(delta) < 1e-12:
        return "flat"
    goal = METRIC_DIRECTION.get(metric, "up")
    if goal == "neutral":
        return "up" if delta > 0 else "down"
    improved = (delta > 0) if goal == "up" else (delta < 0)
    return "better" if improved else "worse"


def compare(arm_a, arm_b, metric, mde=None, regime_a=None, regime_b=None, min_n=MIN_N):
    """Compare two replicate arms of one metric. Returns a verdict dict; never raises on data."""
    a, b = _clean(arm_a), _clean(arm_b)
    r = _base(metric, a, b, regime_a, regime_b)
    r["kind"] = "count" if metric in COUNT_METRICS else "parametric"

    if regime_a is not None and regime_b is not None and regime_a != regime_b:
        r["verdict"] = "REFUSE_REGIME_MISMATCH"
        r["note"] = "arms are different regimes; an A/B here measures the regime, not the change."
        return r
    if len(a) < min_n or len(b) < min_n:
        r["verdict"] = "INCONCLUSIVE"
        r["note"] = "need >= %d replicates per arm (have %d/%d)." % (min_n, len(a), len(b))
        return r

    r["direction"] = _direction(metric, r["delta"])
    r["mde"] = mde

    if r["kind"] == "count":
        # Nonparametric: require the better arm's p10..p90 box to clear the other by >= MDE.
        sa, sb = sorted(a), sorted(b)
        a_lo, a_hi = _percentile(sa, 0.10), _percentile(sa, 0.90)
        b_lo, b_hi = _percentile(sb, 0.10), _percentile(sb, 0.90)
        gap = None
        if b_lo > a_hi:      # B clearly above A
            gap = b_lo - a_hi
        elif a_lo > b_hi:    # A clearly above B
            gap = -(a_lo - b_hi)
        separated = gap is not None
        practical = (mde is None) or (separated and abs(gap) >= mde)
        r["significant"] = separated
        r["practicallySignificant"] = practical
        if separated and practical:
            r["verdict"] = "BETTER" if r["direction"] == "better" else "WORSE"
        else:
            r["verdict"] = "NO_DIFF"
        r["note"] = "nonparametric p10..p90 (count metric); gap=%s" % (None if gap is None else round(gap, 3))
        return r

    # Parametric (Welch): needs spread on both arms.
    if r["stdev_a"] is None or r["stdev_b"] is None:
        r["verdict"] = "INCONCLUSIVE"
        r["note"] = "zero-variance arm; cannot run Welch t."
        return r
    sem_a = r["stdev_a"] / math.sqrt(len(a))
    sem_b = r["stdev_b"] / math.sqrt(len(b))
    r["sem_a"], r["sem_b"] = round(sem_a, 4), round(sem_b, 4)
    denom = math.sqrt(sem_a ** 2 + sem_b ** 2)
    if denom == 0:
        r["verdict"] = "INCONCLUSIVE"
        r["note"] = "zero pooled standard error."
        return r
    t = (r["mean_b"] - r["mean_a"]) / denom
    num = (sem_a ** 2 + sem_b ** 2) ** 2
    den = (sem_a ** 4) / (len(a) - 1) + (sem_b ** 4) / (len(b) - 1)
    df = num / den if den > 0 else (len(a) + len(b) - 2)
    tc = _t_crit(df)
    pooled = math.sqrt(((len(a) - 1) * r["stdev_a"] ** 2 + (len(b) - 1) * r["stdev_b"] ** 2) / (len(a) + len(b) - 2))
    r["welch_t"] = round(t, 4)
    r["df"] = round(df, 2)
    r["t_crit"] = tc
    r["cohens_d"] = round((r["mean_b"] - r["mean_a"]) / pooled, 4) if pooled > 0 else None
    r["significant"] = abs(t) > tc
    r["practicallySignificant"] = (mde is None) or (abs(r["delta"]) >= mde)
    if r["significant"] and r["practicallySignificant"]:
        r["verdict"] = "BETTER" if r["direction"] == "better" else "WORSE"
    else:
        r["verdict"] = "NO_DIFF"
    bits = ["|t|=%.2f vs t_crit=%.2f" % (abs(t), tc)]
    if mde is not None:
        bits.append("|delta|=%.2f vs MDE=%.2f" % (abs(r["delta"]), mde))
    r["note"] = "; ".join(bits)
    return r


def _self_test():
    checks = []

    def chk(name, cond):
        checks.append((name, bool(cond)))

    # 1) clear FPS regression: B (32) worse than A (42), tight, n=6, MDE 2
    a = [42, 43, 41, 42, 42, 41]
    b = [32, 33, 31, 32, 33, 32]
    r = compare(a, b, "serverFpsMedian", mde=2.0, regime_a="z/2hc/p10", regime_b="z/2hc/p10")
    chk("clear regression -> WORSE", r["verdict"] == "WORSE")
    chk("clear regression significant", r["significant"] is True)
    chk("clear regression practical", r["practicallySignificant"] is True)
    chk("direction worse", r["direction"] == "worse")

    # 2) tiny difference below MDE -> NO_DIFF
    a2 = [42.0, 42.3, 41.8, 42.1, 42.2, 41.9]
    b2 = [42.4, 42.6, 42.2, 42.5, 42.3, 42.5]
    r2 = compare(a2, b2, "serverFpsMedian", mde=2.0, regime_a="x", regime_b="x")
    chk("sub-MDE -> NO_DIFF", r2["verdict"] == "NO_DIFF")
    chk("sub-MDE not practical", r2["practicallySignificant"] is False)

    # 3) thin corpus -> INCONCLUSIVE
    r3 = compare([42, 41, 43], [30, 31, 32], "serverFpsMedian", mde=2.0)
    chk("n<5 -> INCONCLUSIVE", r3["verdict"] == "INCONCLUSIVE")

    # 4) regime mismatch -> REFUSE
    r4 = compare(a, b, "serverFpsMedian", mde=2.0, regime_a="z/2hc/p10", regime_b="c/1hc/p6")
    chk("regime mismatch -> REFUSE", r4["verdict"] == "REFUSE_REGIME_MISMATCH")

    # 5) genuine FPS improvement -> BETTER
    r5 = compare([32, 33, 31, 32, 33, 32], [41, 42, 40, 41, 42, 41], "serverFpsMedian",
                 mde=2.0, regime_a="x", regime_b="x")
    chk("real gain -> BETTER", r5["verdict"] == "BETTER")
    chk("real gain direction better", r5["direction"] == "better")

    # 6) count metric nonparametric: clear capture separation
    r6 = compare([0, 1, 0, 1, 0, 1], [5, 6, 5, 7, 6, 5], "captures", mde=2.0, regime_a="x", regime_b="x")
    chk("count separation -> BETTER", r6["verdict"] == "BETTER")
    chk("count uses nonparametric path", r6["kind"] == "count")

    # 7) count metric overlapping -> NO_DIFF
    r7 = compare([2, 3, 2, 3, 2, 3], [2, 3, 3, 2, 3, 2], "captures", mde=2.0, regime_a="x", regime_b="x")
    chk("count overlap -> NO_DIFF", r7["verdict"] == "NO_DIFF")

    # 8) nulls stripped, not zeroed
    r8 = compare([42, None, 41, 42, 43, 41, 42], [32, 33, None, 32, 33, 32], "serverFpsMedian",
                 mde=2.0, regime_a="x", regime_b="x")
    chk("nulls stripped (n_a=6,n_b=5)", r8["n_a"] == 6 and r8["n_b"] == 5)
    chk("nulls still WORSE", r8["verdict"] == "WORSE")

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
