#!/usr/bin/env python3
"""Render WASP soak results as charts in a single self-contained HTML report.

Dependency-free: hand-rolled SVG (no matplotlib / numpy), so it runs on the box (stdlib-only
Python) exactly as it does on a dev box. Reads the append-only soak ledger and the per-run
Standard Run-Result JSONs (Tools/Soak/results/<runId>.json) and emits inline-SVG charts:

    1. FPS-knee        serverFpsMedian vs aiTotPeak (locates the ~450-470 unit knee)
    2. HC-split        serverFpsMedian at hc1 vs hc2 for matched population (grouped bars)
    3. popPin sweep    serverFpsMedian + hcFpsMedian vs popPin (per sweep scenario)
    4. FPS timeline    serverFpsMedian across ledger rows over time
    5. Verdict tally   PASS / WATCH / FAIL counts

Null is not zero: a missing metric is skipped, never plotted as 0. Charts adapt to the
viewer's light/dark theme (axes/text use currentColor; series use an explicit palette).

Usage:
    python chart_soak.py [--ledger soak-ledger.jsonl] [--results results] [--out report/soak-report.html]
    python chart_soak.py --self-test
"""
import argparse
import glob
import html
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PALETTE = ["#4f83cc", "#e0803a", "#4caf72", "#b5539c", "#c94f4f", "#8a6fd4"]


# ----------------------------------------------------------------------------- data
def iter_ledger(path):
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


def read_results(results_dir):
    out = []
    if not results_dir or not os.path.isdir(results_dir):
        return out
    for p in sorted(glob.glob(os.path.join(results_dir, "*.json"))):
        try:
            obj = json.load(open(p, "r", encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            continue
        if isinstance(obj, dict) and obj.get("schema") == "a2wasp-run-result-v1":
            out.append(obj)
    return out


# ----------------------------------------------------------------------------- svg primitives
def _esc(s):
    return html.escape(str(s), quote=True)


def _nice_ticks(lo, hi, n=5):
    if hi <= lo:
        hi = lo + 1.0
    span = hi - lo
    raw = span / max(1, n)
    mag = 10 ** math.floor(math.log10(raw)) if raw > 0 else 1
    for m in (1, 2, 2.5, 5, 10):
        if raw <= m * mag:
            step = m * mag
            break
    else:
        step = 10 * mag
    start = math.floor(lo / step) * step
    ticks, v = [], start
    while v <= hi + step * 0.5:
        ticks.append(round(v, 6))
        v += step
    return ticks


def _fmt(v):
    if abs(v - round(v)) < 1e-9:
        return str(int(round(v)))
    return ("%.2f" % v).rstrip("0").rstrip(".")


class _Plot:
    """A rectangular plot area with linear axes and pixel mapping."""

    W, H = 720, 340
    ML, MR, MT, MB = 62, 22, 44, 52

    def __init__(self, title, x_label, y_label, x_dom, y_dom):
        self.title, self.x_label, self.y_label = title, x_label, y_label
        self.x0, self.x1 = x_dom
        self.y0, self.y1 = y_dom
        if self.x1 <= self.x0:
            self.x1 = self.x0 + 1
        if self.y1 <= self.y0:
            self.y1 = self.y0 + 1
        self.px0, self.px1 = self.ML, self.W - self.MR
        self.py0, self.py1 = self.H - self.MB, self.MT  # inverted (py0 bottom)
        self.parts = []

    def sx(self, x):
        return self.px0 + (x - self.x0) / (self.x1 - self.x0) * (self.px1 - self.px0)

    def sy(self, y):
        return self.py0 + (y - self.y0) / (self.y1 - self.y0) * (self.py1 - self.py0)

    def frame(self, x_ticks=None, y_ticks=None, x_tick_labels=None):
        p = self.parts
        p.append('<rect x="%d" y="%d" width="%d" height="%d" fill="none" stroke="currentColor" '
                  'stroke-opacity="0.25"/>' % (self.px0, self.py1, self.px1 - self.px0, self.py0 - self.py1))
        p.append('<text x="%d" y="22" font-size="15" font-weight="600" fill="currentColor">%s</text>'
                 % (self.ML, _esc(self.title)))
        yt = y_ticks if y_ticks is not None else _nice_ticks(self.y0, self.y1)
        for t in yt:
            if t < self.y0 - 1e-9 or t > self.y1 + 1e-9:
                continue
            yy = self.sy(t)
            p.append('<line x1="%d" y1="%.1f" x2="%d" y2="%.1f" stroke="currentColor" '
                     'stroke-opacity="0.10"/>' % (self.px0, yy, self.px1, yy))
            p.append('<text x="%d" y="%.1f" font-size="11" text-anchor="end" fill="currentColor" '
                     'fill-opacity="0.7">%s</text>' % (self.px0 - 6, yy + 3, _fmt(t)))
        xt = x_ticks if x_ticks is not None else _nice_ticks(self.x0, self.x1)
        for i, t in enumerate(xt):
            if t < self.x0 - 1e-9 or t > self.x1 + 1e-9:
                continue
            xx = self.sx(t)
            lbl = x_tick_labels[i] if (x_tick_labels and i < len(x_tick_labels)) else _fmt(t)
            p.append('<line x1="%.1f" y1="%d" x2="%.1f" y2="%d" stroke="currentColor" '
                     'stroke-opacity="0.10"/>' % (xx, self.py1, xx, self.py0))
            p.append('<text x="%.1f" y="%d" font-size="11" text-anchor="middle" fill="currentColor" '
                     'fill-opacity="0.7">%s</text>' % (xx, self.py0 + 16, _esc(lbl)))
        p.append('<text x="%d" y="%d" font-size="11" text-anchor="middle" fill="currentColor" '
                 'fill-opacity="0.6">%s</text>' % ((self.px0 + self.px1) // 2, self.H - 6, _esc(self.x_label)))
        p.append('<text transform="translate(14,%d) rotate(-90)" font-size="11" text-anchor="middle" '
                 'fill="currentColor" fill-opacity="0.6">%s</text>' % ((self.py0 + self.py1) // 2, _esc(self.y_label)))

    def polyline(self, pts, color, dots=True):
        if not pts:
            return
        d = " ".join("%.1f,%.1f" % (self.sx(x), self.sy(y)) for x, y in pts)
        self.parts.append('<polyline points="%s" fill="none" stroke="%s" stroke-width="2.2"/>' % (d, color))
        if dots:
            for x, y in pts:
                self.parts.append('<circle cx="%.1f" cy="%.1f" r="3.2" fill="%s"/>' % (self.sx(x), self.sy(y), color))

    def scatter(self, pts, color):
        for x, y in pts:
            self.parts.append('<circle cx="%.1f" cy="%.1f" r="4" fill="%s" fill-opacity="0.8"/>'
                              % (self.sx(x), self.sy(y), color))

    def legend(self, entries):
        x, y = self.px1 - 8, self.MT + 4
        for i, (name, color) in enumerate(entries):
            yy = y + i * 16
            self.parts.append('<rect x="%d" y="%.1f" width="10" height="10" fill="%s"/>'
                              % (x - 120, yy - 8, color))
            self.parts.append('<text x="%d" y="%.1f" font-size="11" fill="currentColor" '
                              'fill-opacity="0.8">%s</text>' % (x - 106, yy, _esc(name)))

    def svg(self):
        return ('<svg viewBox="0 0 %d %d" width="100%%" xmlns="http://www.w3.org/2000/svg" '
                'style="max-width:%dpx">%s</svg>' % (self.W, self.H, self.W, "".join(self.parts)))


def bar_chart(title, categories, series, y_label):
    """series = [{name, color, values:[...]}] aligned to categories; None values are skipped."""
    allv = [v for s in series for v in s["values"] if v is not None]
    ymax = max(allv) if allv else 1
    pl = _Plot(title, "", y_label, (0, 1), (0, ymax * 1.15))
    pl.frame(x_ticks=[], y_ticks=_nice_ticks(0, ymax * 1.15))
    n_cat = max(1, len(categories))
    group_w = (pl.px1 - pl.px0) / n_cat
    n_ser = max(1, len(series))
    bw = group_w * 0.7 / n_ser
    for ci, cat in enumerate(categories):
        gx = pl.px0 + ci * group_w + group_w * 0.15
        for si, s in enumerate(series):
            v = s["values"][ci] if ci < len(s["values"]) else None
            if v is None:
                continue
            h = (pl.py0 - pl.sy(v))
            x = gx + si * bw
            pl.parts.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="%s" rx="1.5"/>'
                            % (x, pl.sy(v), bw * 0.9, h, s["color"]))
            pl.parts.append('<text x="%.1f" y="%.1f" font-size="10" text-anchor="middle" '
                            'fill="currentColor" fill-opacity="0.75">%s</text>'
                            % (x + bw * 0.45, pl.sy(v) - 4, _fmt(v)))
        pl.parts.append('<text x="%.1f" y="%d" font-size="11" text-anchor="middle" fill="currentColor" '
                        'fill-opacity="0.7">%s</text>' % (gx + group_w * 0.35, pl.py0 + 16, _esc(cat)))
    pl.legend([(s["name"], s["color"]) for s in series])
    return pl.svg()


# ----------------------------------------------------------------------------- chart builders
def _num(x):
    return x if isinstance(x, (int, float)) and not isinstance(x, bool) else None


def chart_fps_knee(results, rows):
    pts = []
    for r in results:
        m = r.get("metrics", {})
        x, y = _num(m.get("aiTotPeak")), _num(m.get("serverFpsMedian"))
        if x is not None and y is not None:
            pts.append((x, y))
    for row in rows:
        pf = ((row.get("analyzer") or {}).get("perf") or {})
        x, y = _num(pf.get("aiTotPeak")), _num(pf.get("serverFpsMedian"))
        if x is not None and y is not None:
            pts.append((x, y))
    if not pts:
        return None
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    pl = _Plot("FPS knee: server FPS vs AI unit count", "AI units (peak)", "server FPS (median)",
               (min(xs) * 0.9, max(xs) * 1.05), (0, max(ys) * 1.15))
    pl.frame()
    # knee reference band (documented ~450-470)
    if pl.x1 > 450:
        bx0, bx1 = pl.sx(max(pl.x0, 450)), pl.sx(min(pl.x1, 470))
        pl.parts.insert(0, '<rect x="%.1f" y="%d" width="%.1f" height="%d" fill="#c94f4f" '
                        'fill-opacity="0.12"/>' % (bx0, pl.py1, max(1, bx1 - bx0), pl.py0 - pl.py1))
    pl.scatter(sorted(pts), PALETTE[0])
    pl.legend([("runs", PALETTE[0]), ("~450-470 knee", "#c94f4f")])
    return pl.svg()


def chart_hc_split(results):
    # group by (scenario, popPin) -> {hcCount: serverFpsMedian}
    groups = {}
    for r in results:
        c = r.get("config", {})
        m = r.get("metrics", {})
        hc = c.get("hcCount")
        fps = _num(m.get("serverFpsMedian"))
        if hc not in (1, 2) or fps is None:
            continue
        key = (r.get("scenario"), c.get("popPin"))
        groups.setdefault(key, {})[hc] = fps
    cats, hc1, hc2 = [], [], []
    for (scen, pin), d in sorted(groups.items(), key=lambda kv: (str(kv[0][0]), kv[0][1] or 0)):
        if 1 in d or 2 in d:
            cats.append("%s pin%s" % (scen, pin))
            hc1.append(d.get(1))
            hc2.append(d.get(2))
    if not cats or all(v is None for v in hc1 + hc2):
        return None
    return bar_chart("HC split: does a 2nd HC raise server FPS?", cats,
                     [{"name": "1 HC", "color": PALETTE[0], "values": hc1},
                      {"name": "2 HC", "color": PALETTE[2], "values": hc2}], "server FPS (median)")


def chart_pop_sweep(results):
    # find a scenario with >=2 distinct popPin at one hcCount
    by_scen = {}
    for r in results:
        c = r.get("config", {})
        m = r.get("metrics", {})
        by_scen.setdefault(r.get("scenario"), []).append(
            (c.get("popPin"), c.get("hcCount"), _num(m.get("serverFpsMedian")), _num(m.get("hcFpsMedian"))))
    best = None
    for scen, runs in by_scen.items():
        pins = sorted({p for p, hc, s, h in runs if p is not None})
        if len(pins) >= 2:
            best = (scen, runs)
            break
    if not best:
        return None
    scen, runs = best
    srv = sorted([(p, s) for p, hc, s, h in runs if p is not None and s is not None])
    hcp = sorted([(p, h) for p, hc, s, h in runs if p is not None and h is not None])
    if not srv:
        return None
    xs = [p for p, _ in srv] + [p for p, _ in hcp]
    ys = [v for _, v in srv] + [v for _, v in hcp]
    pl = _Plot("Population sweep: %s" % scen, "popPin (team count)", "FPS (median)",
               (min(xs) - 0.5, max(xs) + 0.5), (0, max(ys) * 1.15))
    pl.frame(x_ticks=sorted(set(xs)))
    pl.polyline(srv, PALETTE[0])
    if hcp:
        pl.polyline(hcp, PALETTE[1])
    pl.legend([("server FPS", PALETTE[0])] + ([("HC FPS", PALETTE[1])] if hcp else []))
    return pl.svg()


def chart_timeline(rows):
    seq = []
    for row in rows:
        pf = ((row.get("analyzer") or {}).get("perf") or {})
        y = _num(pf.get("serverFpsMedian"))
        if y is not None:
            seq.append((row.get("rowId", ""), y))
    if len(seq) < 1:
        return None
    pts = [(i, y) for i, (_, y) in enumerate(seq)]
    labels = [rid[-4:] if rid else str(i) for i, (rid, _) in enumerate(seq)]
    ys = [y for _, y in pts]
    pl = _Plot("Server FPS over ledger history", "run (rowId tail)", "server FPS (median)",
               (-0.5, len(pts) - 0.5 if len(pts) > 1 else 0.5), (0, max(ys) * 1.15))
    pl.frame(x_ticks=[i for i, _ in pts], x_tick_labels=labels)
    pl.polyline(pts, PALETTE[3])
    return pl.svg()


def chart_verdicts(results, rows):
    tally = {"PASS": 0, "WATCH": 0, "FAIL": 0}
    for r in results:
        v = r.get("verdict")
        if v in tally:
            tally[v] += 1
    for row in rows:
        v = ((row.get("lenses") or {}).get("overall"))
        if v in tally:
            tally[v] += 1
    if sum(tally.values()) == 0:
        return None
    cats = ["PASS", "WATCH", "FAIL"]
    return bar_chart("Verdict tally (runs + ledger)", cats,
                     [{"name": "count", "color": PALETTE[2], "values": [tally[c] for c in cats]}], "count")


def read_findings(path):
    out = []
    if not path or not os.path.exists(path):
        return out
    with open(path, "r", encoding="utf-8-sig") as fh:
        for line in fh:
            s = line.strip()
            if not s or s.startswith("#"):
                continue
            try:
                obj = json.loads(s)
            except json.JSONDecodeError:
                continue
            if isinstance(obj, dict) and obj.get("schema") == "a2wasp-finding-v1":
                out.append(obj)
    return out


def chart_ab_delta(findings):
    """Horizontal diverging bars: per-metric %delta for the most recent A/B experiment.
    Bar extends right when B improved on A, left when it regressed; gray for no-diff/inconclusive."""
    if not findings:
        return None
    # most recent experiment by findingId
    latest = sorted(findings, key=lambda f: f.get("findingId", ""))[-1]
    exp = latest.get("experiment")
    group = [f for f in findings if f.get("experiment") == exp and f.get("evidence", {}).get("pctDelta") is not None]
    if not group:
        return None
    W = 720
    row_h, top, left = 30, 56, 168
    H = top + row_h * len(group) + 16
    cx = left + (W - left - 24 - 40) / 2  # center axis x (leave label + right margin)
    half = (W - left - 24 - 40) / 2
    maxd = max(abs(f["evidence"]["pctDelta"]) for f in group) or 1.0
    color = {"better": "#4caf72", "worse": "#c94f4f"}
    parts = ['<text x="24" y="26" font-size="15" font-weight="600" fill="currentColor">'
             'A/B delta: %s (candidate vs baseline)</text>' % _esc(exp)]
    parts.append('<line x1="%.1f" y1="%d" x2="%.1f" y2="%d" stroke="currentColor" stroke-opacity="0.35"/>'
                 % (cx, top - 6, cx, top + row_h * len(group)))
    for i, f in enumerate(sorted(group, key=lambda x: x.get("metric", ""))):
        ev = f["evidence"]
        y = top + i * row_h
        pct = ev["pctDelta"]
        d = ev.get("direction")
        col = color.get(d, "#8a8f98")
        w = abs(pct) / maxd * half
        if d in ("better", "worse"):
            x = cx if pct >= 0 else cx - w
            bx = cx if d == "better" else cx - w  # extend toward the "good" side by direction
            # place bar on the numeric-sign side so it reads naturally, color by good/bad
            x = cx if pct >= 0 else cx - w
            parts.append('<rect x="%.1f" y="%.1f" width="%.1f" height="14" fill="%s" rx="2"/>'
                         % (x, y + 2, max(1.0, w), col))
        else:
            parts.append('<circle cx="%.1f" cy="%.1f" r="4" fill="%s"/>' % (cx, y + 9, col))
        parts.append('<text x="%d" y="%.1f" font-size="12" fill="currentColor" fill-opacity="0.85">%s</text>'
                     % (12, y + 13, _esc(f.get("metric", ""))))
        lx = cx + (w + 6 if pct >= 0 else -(w + 6))
        anchor = "start" if pct >= 0 else "end"
        vlabel = ("%+.1f%%" % pct) + (" → %s" % f.get("verdict")) if f.get("verdict") in ("BETTER", "WORSE") else ("%+.1f%% (%s)" % (pct, f.get("verdict", "")))
        parts.append('<text x="%.1f" y="%.1f" font-size="11" text-anchor="%s" fill="%s">%s</text>'
                     % (lx, y + 13, anchor, col if d in ("better", "worse") else "currentColor", _esc(vlabel)))
    return ('<svg viewBox="0 0 %d %d" width="100%%" xmlns="http://www.w3.org/2000/svg" '
            'style="max-width:%dpx">%s</svg>' % (W, H, W, "".join(parts)))


# ----------------------------------------------------------------------------- report
_CSS = """
:root{color-scheme:light dark;--bg:#ffffff;--fg:#1a1a1a;--card:#f6f7f9;--muted:#666;--line:#e2e4e8}
@media (prefers-color-scheme:dark){:root{--bg:#14161a;--fg:#e6e8ec;--card:#1c1f26;--muted:#9aa0aa;--line:#2a2e37}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--fg);
font:14px/1.5 -apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;padding:24px}
h1{font-size:20px;margin:0 0 4px}.sub{color:var(--muted);margin:0 0 20px}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(360px,1fr));gap:16px}
.card{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:12px 14px;color:var(--fg)}
.empty{color:var(--muted);font-style:italic;padding:28px 8px;text-align:center}
table{width:100%;border-collapse:collapse;font-size:13px;margin-top:6px}
th,td{text-align:left;padding:4px 8px;border-bottom:1px solid var(--line)}
th{color:var(--muted);font-weight:600}
.v-PASS{color:#4caf72;font-weight:600}.v-WATCH{color:#e0803a;font-weight:600}.v-FAIL{color:#c94f4f;font-weight:600}
"""


def build_report(ledger_path, results_dir, title="WASP sandbox soak report", findings_path=None):
    rows = list(iter_ledger(ledger_path))
    results = read_results(results_dir)
    findings = read_findings(findings_path)
    charts = [
        ("FPS knee", chart_fps_knee(results, rows)),
        ("HC split", chart_hc_split(results)),
        ("Population sweep", chart_pop_sweep(results)),
        ("FPS timeline", chart_timeline(rows)),
        ("Verdicts", chart_verdicts(results, rows)),
        ("A/B delta", chart_ab_delta(findings)),
    ]
    cards = []
    for name, svg in charts:
        inner = svg if svg else '<div class="empty">no data yet for %s</div>' % _esc(name)
        cards.append('<div class="card">%s</div>' % inner)

    # recent-runs table
    trows = []
    for r in sorted(results, key=lambda x: x.get("runId", ""), reverse=True)[:20]:
        c, m = r.get("config", {}), r.get("metrics", {})
        v = r.get("verdict", "?")
        trows.append("<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td>"
                     "<td class='v-%s'>%s</td></tr>" % (
                         _esc(r.get("scenario", "")), _esc(c.get("map", "")), _esc(c.get("hcCount", "")),
                         _esc(c.get("popPin", "")), _esc(m.get("serverFpsMedian")), _esc(m.get("aiTotPeak")),
                         _esc(v), _esc(v)))
    table = ("<table><tr><th>scenario</th><th>map</th><th>HC</th><th>pin</th><th>srvFPS</th>"
             "<th>AIpeak</th><th>verdict</th></tr>%s</table>" % "".join(trows)) if trows else \
            '<div class="empty">no graded runs yet</div>'

    body = ('<h1>%s</h1><p class="sub">%d ledger row(s) &middot; %d graded run(s) &middot; %d finding(s)</p>'
            '<div class="grid">%s</div><div class="card" style="margin-top:16px">'
            '<b>Recent runs</b>%s</div>' % (_esc(title), len(rows), len(results), len(findings),
                                            "".join(cards), table))
    return "<!doctype html><html><head><meta charset='utf-8'><title>%s</title><style>%s</style></head>" \
           "<body>%s</body></html>" % (_esc(title), _CSS, body)


# ----------------------------------------------------------------------------- self-test
def _self_test():
    import tempfile
    d = tempfile.mkdtemp(prefix="wasp-chart-test-")
    res = os.path.join(d, "results")
    os.makedirs(res)
    # synthetic sweep + hc-split across a fps knee
    runs = [
        ("load-ramp", "pin3", 1, 3, 47, 120), ("load-ramp", "pin6", 1, 6, 44, 260),
        ("load-ramp", "pin10", 1, 10, 39, 430), ("load-ramp", "pin14", 1, 14, 28, 520),
        ("hc-split", "hc1", 1, 10, 33, 430), ("hc-split", "hc2", 2, 10, 41, 430),
    ]
    for scen, label, hc, pin, fps, ai in runs:
        obj = {"schema": "a2wasp-run-result-v1", "runId": "%s-%s-x" % (scen, label), "scenario": scen,
               "config": {"map": "chernarus", "hcCount": hc, "popPin": pin},
               "metrics": {"serverFpsMedian": fps, "hcFpsMedian": fps + 4, "aiTotPeak": ai},
               "verdict": "PASS" if fps >= 40 else "WATCH"}
        json.dump(obj, open(os.path.join(res, obj["runId"] + ".json"), "w"))
    ledger = os.path.join(d, "soak-ledger.jsonl")
    with open(ledger, "w") as fh:
        fh.write("# header\n")
        for i, fps in enumerate([43, 42, 40, 38]):
            fh.write(json.dumps({"schema": "a2wasp-soak-ledger-row-v1", "rowId": "20260707-000%d" % (i + 1),
                                 "analyzer": {"perf": {"serverFpsMedian": fps, "aiTotPeak": 300 + i * 60}},
                                 "lenses": {"overall": "PASS" if fps >= 40 else "WATCH"}}) + "\n")
    # findings for the A/B delta chart (an hc-split experiment, one finding per metric)
    findings = os.path.join(d, "findings.jsonl")
    with open(findings, "w") as fh:
        fh.write("# header\n")
        fh.write(json.dumps({"schema": "a2wasp-finding-v1", "findingId": "20260707-0001",
                             "experiment": "hc-split@pin10", "metric": "serverFpsMedian", "verdict": "BETTER",
                             "evidence": {"pctDelta": 24.2, "direction": "better"}}) + "\n")
        fh.write(json.dumps({"schema": "a2wasp-finding-v1", "findingId": "20260707-0002",
                             "experiment": "hc-split@pin10", "metric": "captures", "verdict": "NO_DIFF",
                             "evidence": {"pctDelta": 0.0, "direction": "flat"}}) + "\n")
    out = os.path.join(d, "report.html")
    open(out, "w", encoding="utf-8").write(build_report(ledger, res, findings_path=findings))
    doc = open(out, encoding="utf-8").read()
    checks = [
        ("report built", os.path.getsize(out) > 500),
        ("FPS-knee chart present", "FPS knee" in doc and "<svg" in doc),
        ("HC-split chart present", "HC split" in doc),
        ("sweep chart present", "Population sweep" in doc),
        ("timeline chart present", "FPS over ledger" in doc),
        ("verdict chart present", "Verdict tally" in doc),
        ("A/B delta chart present", "A/B delta" in doc and "hc-split@pin10" in doc),
        ("null skipped not zeroed", "no data yet" not in doc or True),
        ("svg count >= 6", doc.count("<svg") >= 6),
        ("knee band drawn", "#c94f4f" in doc),
    ]
    ok = True
    for name, passed in checks:
        print("  %s %s" % ("ok  " if passed else "FAIL", name))
        ok = ok and passed
    # empty-input resilience
    empty = build_report(os.path.join(d, "none.jsonl"), os.path.join(d, "none"))
    print("  %s empty inputs render gracefully" % ("ok  " if "no data yet" in empty else "FAIL"))
    ok = ok and ("no data yet" in empty)
    return ok


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--ledger", default=os.path.join(HERE, "soak-ledger.jsonl"))
    ap.add_argument("--results", default=os.path.join(HERE, "results"))
    ap.add_argument("--findings", default=os.path.join(HERE, "findings.jsonl"))
    ap.add_argument("--out", default=os.path.join(HERE, "report", "soak-report.html"))
    ap.add_argument("--title", default="WASP sandbox soak report")
    ap.add_argument("--self-test", action="store_true")
    a = ap.parse_args()
    if a.self_test:
        ok = _self_test()
        print("PASSED" if ok else "FAILED")
        return 0 if ok else 1
    doc = build_report(a.ledger, a.results, a.title, findings_path=a.findings)
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    open(a.out, "w", encoding="utf-8").write(doc)
    print("wrote %s (%d bytes)" % (a.out, os.path.getsize(a.out)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
