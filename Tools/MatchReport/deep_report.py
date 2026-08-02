"""
In-depth post-match report — HTML (and Markdown) renderer + CLI.

    python deep_report.py --rpt arma2oaserver.RPT -o report.html
    grep -E "WASPSTAT\\|v1\\||MATCH\\|v1\\|" server.rpt | python deep_report.py --rpt - -o report.html
    python deep_report.py --sample -o report.html      # deterministic demo, no data needed
    python deep_report.py --rpt match.log --format md  # plain-text/Markdown to stdout

This is the read-through companion to the 48-second vertical video (`render_report.py`):
same telemetry, opposite goal. The video shows eight numbers to a scrolling audience;
this shows every number the log carries, to someone asking what actually happened —
including the `MATCH|v1|` family (match config, casualties, vehicles lost, narrative
milestones) that the video pipeline never reads.

Dependency-free on purpose: stdlib only, one self-contained HTML file out, no CDN, no
build step. It runs on the box that already has the RPT.

Charts are generated as inline SVG against a palette validated for colour-vision
deficiency and contrast in both light and dark mode (see PALETTE below); every chart
ships a table-view twin so no value is reachable by colour or hover alone.
"""
import argparse
import html
import json
import sys
from collections import Counter

from matchdata import MatchData
from deepmatch import (
    CATEGORY_LABEL, FACTION_LABEL, FACTION_ORDER, KILL_CATEGORIES, STAT_FIELDS,
    DeepMatch, fmt_clock, parse_deep, pct,
)

# --------------------------------------------------------------------------
# Palette
# --------------------------------------------------------------------------
# Faction hues are brand data (Miksuu's Warfare tokens: west blue, east rust, guer
# olive). The raw token values fail a categorical-palette audit — west/guer/neutral sit
# below the chroma floor and guer↔east collapse to ΔE 5.2 under deuteranopia — so each
# hue was stepped within its own family until all checks pass. Verified with the
# dataviz validator on both surfaces:
#
#   dark  #5b9ad0,#b8452f,#8d9e2e on #14171b -> lightness/chroma/CVD/normal/contrast PASS
#                                               (worst adjacent ΔE 11.5 deutan)
#   light #2a7fbe,#a83a22,#93a531 on #f4f1e8 -> all checks PASS
#
# CIV / CONTESTED is deliberately NOT a faction hue: it is a neutral status, so it uses
# recessive grey chrome and never competes with a faction for attention.
PALETTE = {
    "dark":  {"surface": "#14171b", "panel": "#1c2026", "ink": "#e7e3d6", "muted": "#9a9a8c",
              "line": "#2c323a", "accent": "#d9763c",
              "west": "#5b9ad0", "east": "#b8452f", "guer": "#8d9e2e", "neu": "#6f7680"},
    "light": {"surface": "#f4f1e8", "panel": "#ffffff", "ink": "#1d2024", "muted": "#5b6069",
              "line": "#ded9cc", "accent": "#b45a22",
              "west": "#2a7fbe", "east": "#a83a22", "guer": "#93a531", "neu": "#7c828b"},
}

E = html.escape


def _e(v):
    return E(str(v), quote=True)


def _n(v):
    """Thousands-separated integer for table cells and tiles."""
    try:
        return "{:,}".format(int(v))
    except (TypeError, ValueError):
        return str(v)


# --------------------------------------------------------------------------
# SVG primitives
# --------------------------------------------------------------------------
# Shared mark spec: 2px strokes, hairline recessive grid, >=8px markers, 4px rounded
# data-ends anchored to the baseline, 2px surface gaps between adjacent/stacked fills.
def _rounded_end_bar(x, y, w, h, r=4):
    """Horizontal bar: square at the baseline (x), rounded at the data end."""
    r = max(0, min(r, w, h / 2.0))
    if w <= 0:
        return ""
    return ("M%.2f %.2f H%.2f a%.2f %.2f 0 0 1 %.2f %.2f V%.2f a%.2f %.2f 0 0 1 %.2f %.2f H%.2f Z"
            % (x, y, x + w - r, r, r, r, r, y + h - r, r, r, -r, r, x))


def svg_line(chart_id, xs, series, y_label, x_label, colors, labels, unit=""):
    """Multi-series line chart. Legend + direct endpoint labels + crosshair tooltip."""
    Wv, Hv = 720, 262
    L, R, T, B = 40, 104, 14, 42
    pw, ph = Wv - L - R, Hv - T - B
    xmax = max(xs) or 1
    ymax = max([max(v) for v in series.values() if v] + [1])
    #--- round the y-axis up to a friendly tick so the top gridline is a real number
    step = 1 if ymax <= 5 else (2 if ymax <= 12 else (5 if ymax <= 30 else 10))
    ytop = ((ymax + step - 1) // step) * step

    def px(x):
        return L + (x / xmax) * pw

    def py(y):
        return T + ph - (y / ytop) * ph

    out = ['<svg class="chart" id="%s" viewBox="0 0 %d %d" role="img" '
           'aria-label="%s over time" data-chart="line" data-xs=\'%s\' data-series=\'%s\' '
           'data-labels=\'%s\' data-unit="%s">'
           % (chart_id, Wv, Hv, _e(y_label), json.dumps(xs),
              json.dumps({k: v for k, v in series.items()}),
              json.dumps(labels), _e(unit))]

    #--- grid: solid hairlines one shade off the surface, never dashed
    ticks = list(range(0, ytop + 1, step)) if step else [0, ytop]
    for t in ticks:
        out.append('<line class="grid" x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f"/>'
                   % (L, py(t), L + pw, py(t)))
        out.append('<text class="tick" x="%.1f" y="%.1f" text-anchor="end">%d</text>'
                   % (L - 6, py(t) + 3.5, t))
    for frac in (0, 0.25, 0.5, 0.75, 1.0):
        tx = xmax * frac
        out.append('<text class="tick" x="%.1f" y="%.1f" text-anchor="middle">%s</text>'
                   % (px(tx), Hv - 10, fmt_clock(tx)))
    out.append('<text class="axis" x="%.1f" y="%.1f" text-anchor="middle">%s</text>'
               % (L + pw / 2, Hv - 0.5, _e(x_label)))

    out.append('<g class="crosshair" id="%s-cross" style="display:none">'
               '<line y1="%.1f" y2="%.1f"/></g>' % (chart_id, T, T + ph))

    for key, vals in series.items():
        if not vals or not any(vals):
            continue
        pts = " ".join("%.2f,%.2f" % (px(x), py(v)) for x, v in zip(xs, vals))
        out.append('<polyline class="series" points="%s" stroke="var(--c-%s)"/>' % (pts, key))
        #--- direct endpoint label: identity without forcing a legend round-trip
        ex, ey = px(xs[-1]), py(vals[-1])
        out.append('<circle class="endcap" cx="%.2f" cy="%.2f" r="4.5" fill="var(--c-%s)"/>'
                   % (ex, ey, key))
        out.append('<text class="endlabel" x="%.2f" y="%.2f" fill="var(--c-%s)">%s %d</text>'
                   % (ex + 9, ey + 4, key, _e(labels.get(key, key)), vals[-1]))

    out.append('<rect class="hit" x="%.1f" y="%.1f" width="%.1f" height="%.1f"/>'
               % (L, T, pw, ph))
    out.append('</svg>')
    return "\n".join(out)


def svg_hbar(chart_id, rows, color_key="accent", value_fmt=None):
    """Horizontal bars, one series -> one colour. rows: [{label, n, note?}]."""
    if not rows:
        return '<p class="empty">No data.</p>'
    value_fmt = value_fmt or (lambda r: _n(r["n"]))
    Wv = 720
    rh, gap = 26, 6                      # 6px pitch gap >= the 2px surface-gap minimum
    Hv = len(rows) * (rh + gap) + 6
    L, R = 150, 78
    pw = Wv - L - R
    mx = max([r["n"] for r in rows] + [1])
    out = ['<svg class="chart" id="%s" viewBox="0 0 %d %d" role="img" aria-label="%s" '
           'data-chart="bar">' % (chart_id, Wv, Hv, _e(chart_id.replace("-", " ")))]
    for i, r in enumerate(rows):
        y = i * (rh + gap) + 3
        w = (r["n"] / mx) * pw
        out.append('<text class="rowlabel" x="%.1f" y="%.1f" text-anchor="end">%s</text>'
                   % (L - 10, y + rh / 2 + 4, _e(r["label"])))
        key = r.get("color", color_key)
        if w > 0:
            out.append('<path class="mark" tabindex="0" role="img" d="%s" fill="var(--c-%s)" '
                       'data-tip="%s — %s%s"/>'
                       % (_rounded_end_bar(L, y, w, rh), key, _e(r["label"]),
                          _e(value_fmt(r)), _e(r.get("note", ""))))
        else:
            out.append('<line class="zero" x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f"/>'
                       % (L, y + rh / 2, L + 3, y + rh / 2))
        out.append('<text class="rowval" x="%.1f" y="%.1f">%s</text>'
                   % (L + max(w, 3) + 10, y + rh / 2 + 4, _e(value_fmt(r))))
    out.append('</svg>')
    return "\n".join(out)


def svg_stack(chart_id, parts, total):
    """One part-to-whole bar with 2px surface gaps between segments."""
    if not total:
        return '<p class="empty">No data.</p>'
    Wv, Hv = 720, 46
    GAP = 2.0
    live = [p for p in parts if p["n"] > 0]
    if not live:
        return '<p class="empty">No data.</p>'
    avail = Wv - GAP * (len(live) - 1)
    out = ['<svg class="chart" id="%s" viewBox="0 0 %d %d" role="img" aria-label="share of '
           'territory-seconds" data-chart="bar">' % (chart_id, Wv, Hv)]
    x = 0.0
    for p in live:
        w = (p["n"] / total) * avail
        out.append('<rect class="mark" tabindex="0" role="img" x="%.2f" y="6" width="%.2f" '
                   'height="26" rx="3" fill="var(--c-%s)" data-tip="%s — %.1f%% (%s)"/>'
                   % (x, w, p["key"], _e(p["label"]), pct(p["n"], total), _e(p["note"])))
        if w > 62:
            out.append('<text class="seglabel" x="%.2f" y="%.1f" text-anchor="middle">%.0f%%</text>'
                       % (x + w / 2, 24, pct(p["n"], total)))
        x += w + GAP
    out.append('</svg>')
    return "\n".join(out)


def legend(keys, labels):
    items = "".join('<span class="lg"><i style="background:var(--c-%s)"></i>%s</span>'
                    % (k, _e(labels.get(k, k))) for k in keys)
    return '<div class="legend">%s</div>' % items


def table(headers, rows, cls="", caption=None):
    head = "".join("<th>%s</th>" % _e(h) for h in headers)
    body = "".join("<tr>%s</tr>" % "".join("<td>%s</td>" % c for c in r) for r in rows)
    cap = "<caption>%s</caption>" % _e(caption) if caption else ""
    return ('<div class="tw"><table class="%s">%s<thead><tr>%s</tr></thead><tbody>%s</tbody>'
            "</table></div>" % (cls, cap, head, body))


def table_view(summary, headers, rows):
    """A chart's WCAG-clean twin: every plotted value, reachable without colour or hover."""
    return ("<details class='tv'><summary>%s</summary>%s</details>"
            % (_e(summary), table(headers, rows)))


def chip(label, value, tone=""):
    return ('<div class="tile %s"><div class="tl">%s</div><div class="tv2">%s</div></div>'
            % (tone, _e(label), value))


# --------------------------------------------------------------------------
# Sections
# --------------------------------------------------------------------------
def sec(title, body, note=None, sid=None):
    n = '<p class="note">%s</p>' % note if note else ""
    anchor = ' id="%s"' % sid if sid else ""
    return '<section%s><h2>%s</h2>%s%s</section>' % (anchor, _e(title), n, body)


def side_label(s):
    return FACTION_LABEL.get(s, str(s).upper())


def _result(dm):
    f = dm.facts
    mode, how = dm.win_how
    tiles = [
        chip("Status", "In progress") if dm.in_progress else
        chip("Winner", '<span style="color:var(--c-%s)">%s</span>'
             % (dm.winner, _e(side_label(dm.winner)))),
        chip("Elapsed" if dm.in_progress else "Duration", MatchData.fmt_duration(dm.duration)),
        chip("Total kills", _n(dm.total_kills)),
        chip("Town captures", _n(len(dm.caps))),
    ]
    if f and f.end:
        tiles.append(chip("Players connected", _n(f.end.get("players", 0))))
        tiles.append(chip("Towns on map", _n(f.end.get("totalTowns", len(dm.towns)))))
    #--- a running match has no winner; showing one (or a neutral "CIV / CONTESTED wins")
    #--- would be the single most misleading thing this page could say.
    headline = "MATCH IN PROGRESS" if dm.in_progress else side_label(dm.winner)
    hero = ('<div class="hero"><div class="herolab">%s</div>'
            '<div class="heronum" style="color:var(--c-%s)">%s</div>'
            '<div class="herosub">%s</div></div>'
            % (_e(mode), dm.winner, _e(headline), _e(how)))

    arc = []
    if dm.max_deficit >= 3:
        arc.append("Comeback: the winner trailed by as many as %d towns." % dm.max_deficit)
    if dm.lead_changes >= 3:
        arc.append("See-saw: %d lead changes on the BLUFOR–OPFOR town differential." % dm.lead_changes)
    if dm.best_streak and dm.best_streak["n"] >= 3:
        b = dm.best_streak
        arc.append("Longest push: %s took %d towns unanswered between %s and %s."
                   % (side_label(b["side"]), b["n"], fmt_clock(b["start"]), fmt_clock(b["end"])))
    arcs = '<ul class="bullets">%s</ul>' % "".join("<li>%s</li>" % _e(a) for a in arc) if arc else ""

    return hero + '<div class="tiles">%s</div>' % "".join(tiles) + arcs


def _ledger(dm):
    """Per-faction ledger. Every faction gets a row even at zero — never dropped for being quiet."""
    f = dm.facts
    cas, veh = (f.casualties(), f.vehicles_lost()) if f else ({}, {})
    ft = dm.final_town_counts()
    rows = []
    for s in FACTION_ORDER:
        tot = dm.side_totals.get(s, {"n": 0, "d": [0] * 15, "kills": 0})
        rows.append([
            '<span class="sw" style="background:var(--c-%s)"></span>%s' % (s, _e(side_label(s))),
            _n(ft.get(s, 0)),
            _n(dm.caps_by_side.get(s, 0)),
            "%.1f%%" % pct(dm.active_seconds.get(s, 0), dm.active_seconds_total),
            _n(dm.kills_by_side.get(s, 0)),
            _n(dm.deaths_by_side.get(s, 0)),
            _n(cas[s]) if s in cas else "<span class='na'>n/a</span>",
            _n(veh[s]) if s in veh else "<span class='na'>n/a</span>",
            _n(tot["n"]),
            _n(tot["kills"]),
        ])
    rows.append([
        '<span class="sw neu"></span>%s' % _e(FACTION_LABEL["neu"]),
        _n(sum(1 for v in dm.final_owners.values() if v == "neu")), "—",
        "%.1f%%" % pct(dm.active_seconds.get("neu", 0), dm.active_seconds_total),
        "—", "—", "—", "—", "—", "—",
    ])
    notes = []
    if f and f.end:
        notes.append("Towns at end, casualties and vehicle losses come from MATCH|v1|END. The "
                     "mission counts towns with GetTownsHeld, which also sees towns a side held "
                     "from spawn without ever capturing them, so it can exceed the count derived "
                     "from CAPTURE records alone.")
        notes.append("Casualty and vehicle-loss counters exist mission-side for BLUFOR and OPFOR "
                     "only, so GUER shows n/a rather than a zero that would read as "
                     "'took no losses'.")
    else:
        notes.append("MATCH|v1|END is absent from this log, so casualties and vehicle losses are "
                     "unavailable and towns at end are derived from CAPTURE records only.")
    notes.append("Territory share is town-seconds across the %d towns that were held by someone "
                 "at some point. %d town(s) in the terrain table never changed hands and are "
                 "excluded, so the share reflects the contested map rather than being diluted by "
                 "inactive town logics." % (dm.active_towns, dm.idle_towns))
    return (table(
        ["Faction", "Towns at end", "Captures", "Territory share", "Kills", "Deaths",
         "Casualties", "Vehicles lost", "Operators", "Operator kills"], rows, cls="ledger")
        + "".join('<p class="note">%s</p>' % _e(n) for n in notes))


def _momentum(dm):
    labels = dict((s, side_label(s)) for s in FACTION_ORDER)
    chart = svg_line("chart-momentum", dm.ser_x,
                     dict((s, dm.series[s]) for s in FACTION_ORDER),
                     "towns held", "match clock", PALETTE, labels, unit=" towns")
    rows = [[fmt_clock(x)] + [_n(dm.series[s][i]) for s in FACTION_ORDER] + [_n(dm.series["neu"][i])]
            for i, x in enumerate(dm.ser_x)]
    tv = table_view("Table view — towns held at each sample",
                    ["Clock"] + [side_label(s) for s in FACTION_ORDER] + ["Neutral"], rows)
    caveat = ""
    ft = dm.final_town_counts()
    derived = dict((s, dm.series[s][-1]) for s in FACTION_ORDER)
    if any(ft.get(s, 0) != derived[s] for s in FACTION_ORDER):
        caveat = ('<p class="note">%s</p>'
                  % _e("This curve is built from CAPTURE records, so it only counts towns that "
                       "changed hands: it ends at %s against the %s that MATCH|v1|END reports. "
                       "The gap is towns a side held from spawn and never had to take."
                       % ("–".join(str(derived[s]) for s in FACTION_ORDER),
                          "–".join(str(ft.get(s, 0)) for s in FACTION_ORDER))))
    return legend(FACTION_ORDER, labels) + chart + tv + caveat


def _territory(dm):
    keys = list(FACTION_ORDER) + ["neu"]
    parts = [{"key": s, "label": side_label(s) if s in FACTION_ORDER else FACTION_LABEL["neu"],
              "n": dm.active_seconds.get(s, 0),
              "note": "%.1f town-hours" % (dm.active_seconds.get(s, 0) / 3600.0)}
             for s in keys]
    share = svg_stack("chart-share", parts, dm.active_seconds_total)
    share_tv = table_view(
        "Table view — territory-seconds",
        ["Faction", "Town-seconds (contested towns)", "Share", "Town-seconds (whole terrain)"],
        [[_e(p["label"]), _n(p["n"]), "%.1f%%" % pct(p["n"], dm.active_seconds_total),
          _n(dm.town_seconds.get(p["key"], 0))] for p in parts])

    def town_row(r):
        return [
            _e(r["town"]),
            '<span class="sw" style="background:var(--c-%s)"></span>%s'
            % (r["final"], _e(side_label(r["final"]))),
            _n(r["flips"]),
            fmt_clock(r["first"]) if r["first"] is not None else "—",
            fmt_clock(r["last"]) if r["last"] is not None else "—",
            _e(side_label(r["dominant"])),
        ]

    THEAD = ["Town", "Owner at end", "Flips", "First flip", "Last flip", "Held longest by"]
    fought = [r for r in dm.town_rows if r["flips"] > 0]
    quiet = [r for r in dm.town_rows if r["flips"] == 0]
    towns = table(THEAD, [town_row(r) for r in
                          sorted(fought, key=lambda r: (-r["flips"], r["town"]))], cls="towns")
    if quiet:
        towns += ("<details class='tv'><summary>%s</summary>%s</details>"
                  % (_e("%d town(s) that never changed hands" % len(quiet)),
                     table(THEAD, [town_row(r) for r in quiet], cls="towns")))

    streaks = ""
    if dm.streaks:
        srows = [[_e(side_label(s["side"])), _n(s["n"]), fmt_clock(s["start"]), fmt_clock(s["end"]),
                  _e(", ".join(s["towns"][:6]) + (" …" if len(s["towns"]) > 6 else ""))]
                 for s in sorted(dm.streaks, key=lambda s: -s["n"])[:10]]
        streaks = ("<h3>Capture streaks</h3>"
                   + table(["Faction", "Towns", "From", "To", "Sequence"], srows))

    return ("<h3>Share of contested territory</h3>"
            + legend(keys, dict(list((s, side_label(s)) for s in FACTION_ORDER)
                                + [("neu", FACTION_LABEL["neu"])]))
            + share + share_tv
            + '<p class="note">%s</p>'
            % _e("Town-seconds held, across the %d towns that changed hands at least once. "
                 "The neutral slice is time those towns spent unowned between captures."
                 % dm.active_towns)
            + "<h3>Towns that changed hands</h3>" + towns + streaks)


def _combat(dm):
    labels = dict((s, side_label(s)) for s in FACTION_ORDER)
    tempo = svg_line("chart-tempo", dm.tempo_x, dm.tempo, "kills per bin", "match clock",
                     PALETTE, labels, unit=" kills")
    tempo_tv = table_view(
        "Table view — kills per %s bin" % MatchData.fmt_duration(dm.tempo_width),
        ["Clock"] + [side_label(s) for s in FACTION_ORDER],
        [[fmt_clock(x)] + [_n(dm.tempo[s][i]) for s in FACTION_ORDER]
         for i, x in enumerate(dm.tempo_x)])

    cat_rows = [{"label": CATEGORY_LABEL.get(c, c), "n": dm.kills_by_cat.get(c, 0)}
                for c in KILL_CATEGORIES]
    extra = [c for c in dm.kills_by_cat if c not in KILL_CATEGORIES]
    for c in sorted(extra):
        cat_rows.append({"label": "%s (unrecognised)" % c, "n": dm.kills_by_cat[c], "note": ""})
    cats = svg_hbar("chart-cats", cat_rows,
                    value_fmt=lambda r: "%s (%.0f%%)" % (_n(r["n"]), pct(r["n"], dm.total_kills)))
    cats_tv = table_view("Table view — kills by target class",
                         ["Target class", "Kills", "Share"],
                         [[_e(r["label"]), _n(r["n"]), "%.1f%%" % pct(r["n"], dm.total_kills)]
                          for r in cat_rows])

    dists = svg_hbar("chart-dists", [{"label": r["label"], "n": r["n"]} for r in dm.dist_rows],
                     value_fmt=lambda r: _n(r["n"]))
    dists_tv = table_view("Table view — engagement range",
                          ["Range", "Kills", "Share of measured"],
                          [[_e(r["label"]), _n(r["n"]), "%.1f%%" % r["pct"]] for r in dm.dist_rows])

    wrows = [[_e(w), _n(n), "%.1f%%" % pct(n, dm.total_kills)]
             for w, n in dm.weapons.most_common(20)]
    weapons = table(["Weapon / platform", "Kills", "Share"], wrows)

    tiles = [chip("Kills", _n(dm.total_kills)),
             chip("PvP kills", _n(dm.pvp_kills)),
             chip("Median range", "%s m" % _n(dm.median_dist))]
    if dm.longest:
        who = dm.longest["killer"] or "an AI unit"
        tiles.append(chip("Longest kill", "%s m" % _n(dm.longest["dist"])))
        tiles.append(chip("Longest kill by", _e(who)))
    if dm.support_events:
        tiles.append(chip("SCUD / TEL events", _n(len(dm.support_events))))

    peak_t = dm.tempo_x[dm.peak_bin]
    peak_n = sum(dm.tempo[s][dm.peak_bin] for s in FACTION_ORDER)
    note = ("Heaviest fighting in the %s window from %s (%d kills)."
            % (MatchData.fmt_duration(dm.tempo_width), fmt_clock(peak_t), peak_n))

    #--- Only caveat the histogram when something was actually dropped; a blanket
    #--- "N of N were measured" line reads as a warning where there is nothing wrong.
    unmeasured = dm.total_kills - dm.dist_measured
    dist_note = ("Every kill carried a measured distance."
                 if not unmeasured else
                 "%d of %d kills logged distance -1 (the engine could not compute one) and are "
                 "excluded from this histogram rather than binned as 0 m."
                 % (unmeasured, dm.total_kills))

    return ('<div class="tiles">%s</div>' % "".join(tiles)
            + "<h3>Kill tempo</h3>" + legend(FACTION_ORDER, labels) + tempo + tempo_tv
            + '<p class="note">%s</p>' % _e(note)
            + "<h3>Kills by target class</h3>" + cats + cats_tv
            + "<h3>Engagement range</h3>" + dists + dists_tv
            + '<p class="note">%s</p>' % _e(dist_note)
            + "<h3>Top weapons and platforms</h3>" + weapons)


def _operators(dm):
    if not dm.players:
        return ('<p class="empty">No human operators appeared in PLAYERSTATS. This reads as an '
                'AI-only or unattended round; headless-client and AI-commander rows are excluded '
                'from every stat surface by design.</p>')
    headers = ["#", "Operator", "Faction", "Score", "Kills", "K/D"] + [f[0] for f in STAT_FIELDS]
    rows = []
    for i, p in enumerate(dm.players, 1):
        award = ('<span class="award">%s</span>' % _e(p["award"][0])) if p.get("award") else ""
        d = p["d"]
        cells = [_n(x) for x in d[:14]] + [MatchData.fmt_duration(d[14])]
        rows.append([str(i), "%s%s" % (_e(p["name"]), award),
                     '<span class="sw" style="background:var(--c-%s)"></span>%s'
                     % (p["side"], _e(side_label(p["side"]))),
                     _n(p["score"]), _n(p["kills"]), "%.2f" % p["kd"]] + cells)
    tbl = table(headers, rows, cls="ops")

    aw = ""
    if dm.awards:
        aw = ("<h3>Superlatives</h3>"
              + table(["Award", "Operator", "Why"],
                      [[_e(tag), _e(name), _e(why)] for name, (tag, why) in dm.awards.items()]))
    kd = ""
    if dm.kd_leader:
        kd = ('<p class="note">%s</p>'
              % _e("Best K/D among operators with 3+ kills: %s (%.2f)."
                   % (dm.kd_leader["name"], dm.kd_leader["kd"])))
    mvp = ""
    if dm.mvp:
        m = dm.mvp
        mvp = ('<div class="hero small"><div class="herolab">MATCH MVP</div>'
               '<div class="heronum" style="color:var(--c-%s)">%s</div>'
               '<div class="herosub">%s · %d kills · %d captures · score %s</div></div>'
               % (m["side"], _e(m["name"]), _e(side_label(m["side"])), m["kills"],
                  m["d"][10], _n(m["score"])))
    note = ('<p class="note">%s</p>'
            % _e("Score is the shared composite used across the report pipeline: "
                 "kills×10 + PvP×8 + town captures×40 + vehicle kills×6 + air kills×15 + "
                 "supply value/100 + structures×5. Playtime is the summed PLAYERSTATS d14 "
                 "flush chunks, not wall-clock session length."))
    return mvp + aw + kd + "<h3>Full operator table</h3>" + tbl + note


def _duels(dm):
    if not dm.duels:
        return ('<p class="empty">No player-versus-player kills in this log. PvP attribution needs '
                'both a killer and a victim UID on the KILL record, so AI-heavy rounds show none.</p>')
    rows = [[_e(d["a"]), _e(d["b"]), _n(d["af"]), _n(d["bf"]), _n(d["tot"])]
            for d in dm.duels[:25]]
    out = table(["Operator", "Opponent", "Kills for", "Kills against", "Total exchanges"], rows)
    extra = ""
    if dm.nemesis and dm.mvp:
        extra = ('<p class="note">%s</p>'
                 % _e("MVP %s was killed most often by %s (%d times)."
                      % (dm.mvp["name"], dm.nemesis["who"], dm.nemesis["n"])))
    return out + extra


def _timeline(dm):
    if not dm.timeline:
        return '<p class="empty">No timeline events were recoverable from this log.</p>'
    items = []
    for e in dm.timeline:
        approx = "" if e["exact"] else '<span class="approx" title="interpolated or minute-resolution time">~</span>'
        det = '<span class="tdetail">%s</span>' % _e(e["detail"]) if e["detail"] else ""
        items.append('<li class="ev %s"><span class="tclock">%s%s</span>'
                     '<span class="tkind" style="border-color:var(--c-%s)">%s</span>'
                     '<span class="ttext">%s</span>%s</li>'
                     % (e["kind"].lower(), approx, fmt_clock(e["t"]), e["side"],
                        _e(e["kind"]), _e(e["text"]), det))
    return ('<ol class="timeline">%s</ol>'
            '<p class="note">A leading ~ marks a time the emitter did not measure to the second: '
            'MILESTONE beats are minute-resolution, and captures or kills without a t= token are '
            'spread evenly across the match, preserving order but not timing.</p>'
            % "".join(items))


def _coverage(dm):
    c = dm.coverage
    rows = [
        ["WASPSTAT PLAYERSTATS lines", _n(c["records"].get("PLAYERSTATS", 0))],
        ["WASPSTAT KILL lines", _n(c["records"].get("KILL", 0))],
        ["WASPSTAT CAPTURE lines", _n(c["records"].get("CAPTURE", 0))],
        ["WASPSTAT ROUNDEND lines", _n(c["records"].get("ROUNDEND", 0))],
        ["Other WASPSTAT records (CAMP / BUILDINGKILL / unknown)", "%s / %s / %s" % (
            _n(c["records"].get("CAMP", 0)), _n(c["records"].get("BUILDINGKILL", 0)),
            _n(c["records"].get("UNKNOWN", 0)))],
        ["MATCH START / END / MILESTONE", "%s / %s / %s" % (
            _n(c["match_family"].get("START", 0)), _n(c["match_family"].get("END", 0)),
            _n(c["match_family"].get("MILESTONE", 0)))],
        ["WASPSTAT seq range", "%s – %s" % (c["seq_min"], c["seq_max"])
            if c["seq_min"] is not None else "n/a"],
        ["Sequence gaps", _n(c["seq_gaps"])],
        ["Captures with measured time", "%s of %s" % (_n(c["cap_exact"]), _n(c["cap_total"]))],
        ["Kills with measured time", "%s of %s" % (_n(c["kill_exact"]), _n(c["kill_total"]))],
        ["Kills with measured distance", "%s of %s" % (_n(c["dist_measured"]), _n(c["dist_total"]))],
        ["Operator UIDs without a name", _n(c["unresolved_uids"])],
        ["Headless / AI rows excluded", _n(c["excluded_rows"])],
        ["Static town table for terrain", "yes" if c["towns_known"] else "no"],
    ]
    warn = ""
    if dm.warnings:
        warn = ('<ul class="warn">%s</ul>'
                % "".join("<li>%s</li>" % _e(w) for w in dm.warnings))
    return (warn + table(["Signal", "Value"], rows, cls="cov")
            + '<p class="note">%s</p>'
            % _e("Headless clients and AI-commander controllers carry UIDs and stat rows but are "
                 "not operators; they are removed before any MVP, leaderboard or duel table is "
                 "built, and counted here only so the exclusion is visible."))


CSS = """
:root{color-scheme:light dark}
*{box-sizing:border-box}
body{margin:0;padding:0 20px 72px;font:15px/1.55 "Inter",-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;
background:var(--surface);color:var(--ink);-webkit-font-smoothing:antialiased}
.wrap{max-width:960px;margin:0 auto}
h1{font-size:clamp(26px,5vw,40px);line-height:1.1;margin:6px 0 4px;letter-spacing:-.02em}
h2{font-size:19px;margin:0 0 4px;letter-spacing:.01em}
h3{font-size:14px;text-transform:uppercase;letter-spacing:.09em;color:var(--muted);margin:26px 0 8px;font-weight:600}
header{padding:34px 0 18px;border-bottom:1px solid var(--line)}
.eyebrow{font-size:11px;letter-spacing:.22em;text-transform:uppercase;color:var(--accent);font-weight:600}
.subtitle{color:var(--muted);margin:6px 0 0}
.chips{display:flex;flex-wrap:wrap;gap:8px;margin-top:14px}
.chip{border:1px solid var(--line);border-radius:999px;padding:3px 11px;font-size:12px;color:var(--muted)}
section{padding:26px 0;border-bottom:1px solid var(--line)}
.note{color:var(--muted);font-size:13px;margin:8px 0 0;max-width:76ch}
.empty{color:var(--muted);font-style:italic}
.bullets{color:var(--muted);font-size:14px;margin:12px 0 0;padding-left:18px}
.tiles{display:grid;grid-template-columns:repeat(auto-fit,minmax(136px,1fr));gap:10px;margin:16px 0 0}
.tile{background:var(--panel);border:1px solid var(--line);border-radius:10px;padding:12px 14px}
.tl{font-size:11px;letter-spacing:.1em;text-transform:uppercase;color:var(--muted)}
.tv2{font-size:23px;margin-top:3px;font-variant-numeric:proportional-nums}
.hero{background:var(--panel);border:1px solid var(--line);border-radius:12px;padding:22px 24px}
.hero.small{padding:16px 18px}
.herolab{font-size:11px;letter-spacing:.2em;text-transform:uppercase;color:var(--muted)}
.heronum{font-size:clamp(30px,6vw,46px);line-height:1.05;margin:4px 0 2px;letter-spacing:-.02em;font-variant-numeric:proportional-nums}
.hero.small .heronum{font-size:clamp(22px,4vw,30px)}
.herosub{color:var(--muted);font-size:14px}
.legend{display:flex;flex-wrap:wrap;gap:16px;margin:4px 0 10px;font-size:12px;color:var(--muted)}
.lg{display:inline-flex;align-items:center;gap:7px}
.lg i{width:11px;height:11px;border-radius:3px;display:inline-block}
.chart{width:100%;height:auto;display:block;overflow:visible}
.chart .grid{stroke:var(--line);stroke-width:1}
.chart .tick{fill:var(--muted);font-size:10px;font-variant-numeric:tabular-nums}
.chart .axis{fill:var(--muted);font-size:10px;letter-spacing:.08em;text-transform:uppercase}
.chart .series{fill:none;stroke-width:2;stroke-linejoin:round;stroke-linecap:round}
.chart .endcap{stroke:var(--surface);stroke-width:2}
.chart .endlabel{font-size:11px;font-weight:600}
.chart .rowlabel{fill:var(--ink);font-size:12px}
.chart .rowval{fill:var(--muted);font-size:12px;font-variant-numeric:tabular-nums}
.chart .seglabel{fill:#fff;font-size:11px;font-weight:600;font-variant-numeric:tabular-nums}
.chart .zero{stroke:var(--muted);stroke-width:2;stroke-linecap:round}
.chart .hit{fill:transparent}
.chart .crosshair line{stroke:var(--muted);stroke-width:1}
.chart .mark{cursor:default}
.chart .mark:focus{outline:2px solid var(--accent);outline-offset:2px}
.tw{overflow-x:auto;margin-top:8px;-webkit-overflow-scrolling:touch}
table{border-collapse:collapse;width:100%;font-size:13px;min-width:min(100%,520px)}
caption{text-align:left;color:var(--muted);font-size:12px;padding-bottom:6px}
th{text-align:left;font-weight:600;color:var(--muted);font-size:11px;letter-spacing:.08em;
text-transform:uppercase;padding:7px 10px;border-bottom:1px solid var(--line);white-space:nowrap}
td{padding:7px 10px;border-bottom:1px solid var(--line);font-variant-numeric:tabular-nums;white-space:nowrap}
td:first-child,th:first-child{padding-left:0}
tbody tr:hover td{background:var(--panel)}
.ops td:nth-child(2){white-space:nowrap}
.towns td:first-child{white-space:normal}
.sw{width:10px;height:10px;border-radius:3px;display:inline-block;margin-right:7px;vertical-align:-1px}
.sw.neu{background:var(--c-neu)}
.na{color:var(--muted);font-style:italic}
.award{display:inline-block;margin-left:8px;font-size:10px;letter-spacing:.08em;color:var(--accent);
border:1px solid var(--accent);border-radius:999px;padding:1px 7px;vertical-align:1px;white-space:nowrap}
.tv{margin-top:10px}
.tv summary{cursor:pointer;color:var(--muted);font-size:12px;padding:5px 0}
.tv summary:hover{color:var(--ink)}
.timeline{list-style:none;margin:6px 0 0;padding:0}
.ev{display:grid;grid-template-columns:74px 92px 1fr;gap:12px;align-items:baseline;padding:7px 0;
border-bottom:1px solid var(--line);font-size:14px}
.tclock{color:var(--muted);font-size:12px;font-variant-numeric:tabular-nums}
.approx{color:var(--accent);margin-right:2px}
.tkind{font-size:10px;letter-spacing:.09em;color:var(--muted);border-left:3px solid;padding-left:7px}
.tdetail{grid-column:3;color:var(--muted);font-size:12px}
.ev.end,.ev.start{background:var(--panel)}
.warn{margin:0 0 14px;padding:0;list-style:none}
.warn li{border-left:3px solid var(--accent);padding:7px 0 7px 12px;margin-bottom:7px;
color:var(--muted);font-size:13px;background:var(--panel)}
#tip{position:fixed;pointer-events:none;opacity:0;transition:opacity .1s;background:var(--panel);
color:var(--ink);border:1px solid var(--line);border-radius:7px;padding:6px 10px;font-size:12px;
box-shadow:0 6px 24px rgba(0,0,0,.28);z-index:9;max-width:280px}
footer{color:var(--muted);font-size:12px;padding:22px 0}
@media (max-width:640px){.ev{grid-template-columns:64px 1fr}.tkind{display:none}.tdetail{grid-column:2}}
@media print{.tv[open] summary{display:none}#tip{display:none}}
"""


def _theme_css():
    def block(sel, p):
        return ("%s{--surface:%s;--panel:%s;--ink:%s;--muted:%s;--line:%s;--accent:%s;"
                "--c-west:%s;--c-east:%s;--c-guer:%s;--c-neu:%s;--c-accent:%s}"
                % (sel, p["surface"], p["panel"], p["ink"], p["muted"], p["line"], p["accent"],
                   p["west"], p["east"], p["guer"], p["neu"], p["accent"]))
    return (block(":root", PALETTE["light"])
            + "@media (prefers-color-scheme:dark){" + block(":root", PALETTE["dark"]) + "}"
            + block(':root[data-theme="dark"]', PALETTE["dark"])
            + block(':root[data-theme="light"]', PALETTE["light"]))


JS = """
(function(){
 var tip=document.getElementById('tip');
 function show(t,x,y){tip.textContent=t;tip.style.opacity=1;
  var r=tip.getBoundingClientRect();
  tip.style.left=Math.min(x+14,innerWidth-r.width-8)+'px';
  tip.style.top=Math.max(8,y-r.height-12)+'px';}
 function hide(){tip.style.opacity=0;}
 // bars & segments: hover AND keyboard focus reach the same value
 document.querySelectorAll('.mark[data-tip]').forEach(function(el){
  var t=el.getAttribute('data-tip');
  el.addEventListener('mouseenter',function(e){show(t,e.clientX,e.clientY);});
  el.addEventListener('mousemove',function(e){show(t,e.clientX,e.clientY);});
  el.addEventListener('mouseleave',hide);
  el.addEventListener('focus',function(){var b=el.getBoundingClientRect();show(t,b.right,b.top);});
  el.addEventListener('blur',hide);
 });
 // line charts: crosshair + all-series readout at the nearest sample
 document.querySelectorAll('svg[data-chart="line"]').forEach(function(svg){
  var xs=JSON.parse(svg.getAttribute('data-xs'));
  var series=JSON.parse(svg.getAttribute('data-series'));
  var labels=JSON.parse(svg.getAttribute('data-labels'));
  var unit=svg.getAttribute('data-unit')||'';
  var hit=svg.querySelector('.hit'), cross=svg.querySelector('.crosshair');
  if(!hit||!xs.length)return;
  var L=+hit.getAttribute('x'), PW=+hit.getAttribute('width');
  var xmax=xs[xs.length-1]||1;
  function clock(s){s=Math.max(0,Math.round(s));var h=Math.floor(s/3600),m=Math.floor(s%3600/60),
   q=s%60;var p=function(n){return(n<10?'0':'')+n;};return h?h+':'+p(m)+':'+p(q):p(m)+':'+p(q);}
  hit.addEventListener('mousemove',function(e){
   var b=svg.getBoundingClientRect();
   var vx=(e.clientX-b.left)/b.width*svg.viewBox.baseVal.width;
   var frac=Math.max(0,Math.min(1,(vx-L)/PW));
   var i=Math.round(frac*(xs.length-1));
   var txt=clock(xs[i]);
   for(var k in series){var v=series[k][i];
    txt+='  ·  '+labels[k]+' '+v+(v===1?unit.replace(/s$/,''):unit);}
   cross.style.display='';
   cross.querySelector('line').setAttribute('x1',L+frac*PW);
   cross.querySelector('line').setAttribute('x2',L+frac*PW);
   show(txt,e.clientX,e.clientY);
  });
  hit.addEventListener('mouseleave',function(){cross.style.display='none';hide();});
 });
})();
"""


def render_html(dm, title=None):
    f = dm.facts
    chips = []
    if f and f.start:
        s = f.start
        chips.append("build %s" % s.get("build", "?"))
        chips.append("%s town slots" % s.get("towns", "?"))
        chips.append("%s player slots" % s.get("missionSlots", "?"))
        chips.append("AI commander %s" % ("on" if s.get("aiEnabled") else "off"))
        chips.append("delegation %s" % s.get("delegation", "?"))
        chips.append("playable GUER %s" % ("on" if s.get("guer") else "off"))
        if s.get("naval"):
            chips.append("naval HVT on")
        if s.get("oilfield"):
            chips.append("oilfield on")
    chips.append("%d of %d towns contested" % (dm.active_towns, len(dm.towns)))
    chiphtml = "".join('<span class="chip">%s</span>' % _e(c) for c in chips)

    head = ('<header><div class="wrap"><div class="eyebrow">WASP Warfare · in-depth match report</div>'
            '<h1>%s</h1><p class="subtitle">%s · %s · %s</p><div class="chips">%s</div></div></header>'
            % (_e(dm.map_name.title()),
               _e("in progress" if dm.in_progress else "%s victory" % side_label(dm.winner)),
               _e(MatchData.fmt_duration(dm.duration)),
               _e("%s kills · %s captures" % (_n(dm.total_kills), _n(len(dm.caps)))),
               chiphtml))

    body = "".join([
        sec("Result", _result(dm), sid="result"),
        sec("Faction ledger", _ledger(dm),
            note="Every faction appears even at zero. Territory share is town-seconds held "
                 "across the match, which a final town count alone hides.", sid="ledger"),
        sec("Momentum", _momentum(dm),
            note="Towns held by each faction, sampled across the match clock.", sid="momentum"),
        sec("Territory", _territory(dm), sid="territory"),
        sec("Combat", _combat(dm), sid="combat"),
        sec("Operators", _operators(dm), sid="operators"),
        sec("Head-to-head", _duels(dm),
            note="Player-versus-player exchanges, from KILL records carrying both a killer and a "
                 "victim UID.", sid="duels"),
        sec("Match timeline", _timeline(dm), sid="timeline"),
        sec("Telemetry coverage", _coverage(dm),
            note="What the log contained, so a thin report is never mistaken for a thin match.",
            sid="coverage"),
    ])

    foot = ('<footer><div class="wrap">Generated by Tools/MatchReport/deep_report.py from '
            'WASPSTAT|v1| and MATCH|v1| telemetry. No values are estimated: anything the log did '
            'not carry is reported as absent in Telemetry coverage.</div></footer>')

    return ("<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\">"
            "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">"
            "<title>%s</title><style>%s%s</style></head><body>"
            "<div id=\"tip\" role=\"status\" aria-live=\"polite\"></div>"
            "%s<div class=\"wrap\">%s</div>%s<script>%s</script></body></html>"
            % (_e(title or ("WASP match report — %s" % dm.map_name.title())),
               _theme_css(), CSS, head, body, foot, JS))


# --------------------------------------------------------------------------
# Markdown
# --------------------------------------------------------------------------
def _md_table(headers, rows):
    out = ["| " + " | ".join(headers) + " |",
           "|" + "|".join("---" for _ in headers) + "|"]
    for r in rows:
        out.append("| " + " | ".join(str(c) for c in r) + " |")
    return "\n".join(out)


def render_md(dm):
    f = dm.facts
    L = []
    L.append("# WASP in-depth match report — %s" % dm.map_name.title())
    L.append("")
    L.append("**%s** · %s · %s kills · %s captures"
             % ("MATCH IN PROGRESS" if dm.in_progress else "%s victory" % side_label(dm.winner),
                MatchData.fmt_duration(dm.duration), _n(dm.total_kills), _n(len(dm.caps))))
    mode, how = dm.win_how
    L.append("")
    L.append("%s — %s" % (mode, how))
    if f and f.start:
        L.append("")
        L.append("Config: " + ", ".join("%s=%s" % (k, v) for k, v in f.start.items()))

    L += ["", "## Faction ledger", ""]
    ft = dm.final_town_counts()
    cas = f.casualties() if f else {}
    veh = f.vehicles_lost() if f else {}
    rows = []
    for s in FACTION_ORDER:
        tot = dm.side_totals.get(s, {"n": 0, "kills": 0})
        rows.append([side_label(s),
                     ft.get(s, 0),
                     dm.caps_by_side.get(s, 0),
                     "%.1f%%" % pct(dm.active_seconds.get(s, 0), dm.active_seconds_total),
                     dm.kills_by_side.get(s, 0), dm.deaths_by_side.get(s, 0),
                     cas.get(s, "n/a"), veh.get(s, "n/a"), tot["n"], tot["kills"]])
    L.append(_md_table(["Faction", "Towns", "Captures", "Territory", "Kills", "Deaths",
                        "Casualties", "Veh lost", "Operators", "Op kills"], rows))

    L += ["", "## Combat", ""]
    L.append(_md_table(["Target class", "Kills", "Share"],
                       [[CATEGORY_LABEL.get(c, c), dm.kills_by_cat.get(c, 0),
                         "%.1f%%" % pct(dm.kills_by_cat.get(c, 0), dm.total_kills)]
                        for c in KILL_CATEGORIES]))
    L += ["", "Top weapons:", ""]
    L.append(_md_table(["Weapon", "Kills"], [[w, n] for w, n in dm.weapons.most_common(10)]))
    if dm.longest:
        L += ["", "Longest kill: %s m by %s (%s)."
              % (_n(dm.longest["dist"]), dm.longest["killer"] or "an AI unit",
                 dm.longest["weapon"])]

    L += ["", "## Operators", ""]
    if dm.players:
        L.append(_md_table(["#", "Operator", "Faction", "Score", "Kills", "Deaths", "K/D", "Caps"],
                           [[i, p["name"], side_label(p["side"]), p["score"], p["kills"],
                             p["d"][6], "%.2f" % p["kd"], p["d"][10]]
                            for i, p in enumerate(dm.players, 1)]))
    else:
        L.append("_No human operators in PLAYERSTATS._")

    L += ["", "## Timeline", ""]
    for e in dm.timeline:
        L.append("- `%s%s` **%s** — %s%s"
                 % ("" if e["exact"] else "~", fmt_clock(e["t"]), e["kind"], e["text"],
                    (" (%s)" % e["detail"]) if e["detail"] else ""))

    L += ["", "## Telemetry coverage", ""]
    for w in dm.warnings:
        L.append("- ⚠ %s" % w)
    if not dm.warnings:
        L.append("- No coverage gaps: every record type was present and timestamped.")
    c = dm.coverage
    L += ["", _md_table(["Signal", "Value"], [
        ["Records", ", ".join("%s=%s" % (k, v) for k, v in sorted(c["records"].items())) or "none"],
        ["MATCH family", ", ".join("%s=%s" % (k, v) for k, v in sorted(c["match_family"].items()))],
        ["Sequence gaps", c["seq_gaps"]],
        ["Captures timestamped", "%s/%s" % (c["cap_exact"], c["cap_total"])],
        ["Kills timestamped", "%s/%s" % (c["kill_exact"], c["kill_total"])],
        ["HC/AI rows excluded", c["excluded_rows"]],
    ])]
    return "\n".join(L) + "\n"


# --------------------------------------------------------------------------
# Sample log (deterministic, exercises the real parse path)
# --------------------------------------------------------------------------
def sample_lines():
    """A synthetic but wire-accurate RPT slice, so --sample proves the parser, not a stub."""
    import random
    rng = random.Random(20260725)
    seq = [0]

    def nxt():
        seq[0] += 1
        return seq[0]

    out = ['"MATCH|v1|START|world=chernarus|build=build89-cmdcon44|towns=20|missionSlots=55'
           '|aiEnabled=1|delegation=2|statlog=1|guer=1|naval=0|oilfield=0"']

    uids = ["7656119801234%04d" % i for i in range(12)]
    names = ["Ghost", "Viper", "Hawk-7", "Reaper", "Maverick", "Tonka",
             "Boris", "Krait", "Volk", "Spetz", "Tsar", "Grom"]
    sides = [1] * 6 + [2] * 6
    side_str = ["WEST"] * 6 + ["EAST"] * 6
    duration = 4820

    caps = [(305, "Pustoshka", 4, 0), (412, "Elektrozavodsk", 4, 1), (688, "Vybor", 4, 0),
            (901, "Msta", 4, 1), (1102, "Mogilevka", 4, 0), (1330, "Polana", 4, 1),
            (1547, "Chernogorsk", 4, 0), (1802, "Gvozdno", 4, 2), (2050, "Vyshnoye", 4, 0),
            (2298, "Grishino", 1, 0), (2544, "Stary Sobor", 4, 0), (2790, "Msta", 1, 0),
            (3010, "Novy Sobor", 4, 0), (3266, "Polana", 1, 0), (3512, "Berezino", 4, 0),
            (3740, "Gvozdno", 2, 0), (3988, "Solnichniy", 4, 0), (4210, "Dubrovka", 4, 0),
            (4455, "Krasnostav", 4, 0)]

    WPOOL = {"WEST": [("M16A2", "INF"), ("M4A1_Aim", "INF"), ("M249", "INF"), ("M107", "INF"),
                      ("M1A1", "VEH"), ("AH1Z", "AIR"), ("MK19", "STATIC")],
             "EAST": [("AK_74", "INF"), ("PKM", "INF"), ("SVD", "INF"), ("RPG7V", "VEH"),
                      ("T72", "VEH"), ("Mi24_D", "AIR"), ("KORD", "STATIC")],
             "RESISTANCE": [("AKS_74_U", "INF"), ("Saiga12K", "INF"), ("BRDM2", "VEH")]}
    events = []
    for t, town, old, new in caps:
        events.append((t, "CAPTURE|%s|%d|%d|t=%d" % (town, old, new, t)))
    for _ in range(1180):
        t = rng.randint(30, duration)
        ks = rng.choices(["WEST", "EAST", "RESISTANCE"], weights=[46, 41, 13])[0]
        vs = rng.choice([s for s in ("WEST", "EAST", "RESISTANCE") if s != ks])
        wp, cat = rng.choice(WPOOL[ks])
        dist = {"INF": (25, 420), "VEH": (60, 900), "AIR": (150, 1600),
                "STATIC": (90, 700)}[cat]
        d = rng.randint(*dist)
        if wp in ("M107", "SVD"):
            d = rng.randint(400, 1480)
        ku = rng.choice(uids[:6] if ks == "WEST" else uids[6:]) if rng.random() < 0.42 else ""
        vu = rng.choice(uids[6:] if ks == "WEST" else uids[:6]) if (ku and rng.random() < 0.35) else ""
        events.append((t, "KILL|%s|%s|%s|%s|%s|%d|%s|hw=%s|t=%d"
                       % (ku, vu, ks, vs, wp, d, cat, wp, t)))
    events.sort(key=lambda e: e[0])
    for _t, payload in events:
        out.append('"WASPSTAT|v1|%d|%s"' % (nxt(), payload))

    #--- PLAYERSTATS flush: one line, all dirty players, deltas already summed for the demo.
    toks = []
    for i, uid in enumerate(uids):
        tier = 1.7 if i in (0, 1, 6, 7) else 1.0
        d = [int(rng.randint(9, 44) * tier), int(rng.randint(0, 9) * tier),
             int(rng.randint(0, 3) * tier), int(rng.randint(0, 4) * tier), 0, 0,
             rng.randint(3, 17), rng.randint(0, 11), rng.randint(0, 5), 0,
             int(rng.randint(0, 5) * tier), rng.randint(0, 2), rng.randint(0, 7),
             rng.randint(0, 9), rng.randint(2400, duration)]
        d[9] = d[8] * rng.randint(800, 2200)
        toks.append("%s:%s,%d~%s" % (uid, ",".join(str(x) for x in d), sides[i], names[i]))
    #--- a headless-client row, to prove the exclusion path is live on real data
    toks.append("%s:%s,0~HC-AI-Control-1" % ("76561190000000001", ",".join(["0"] * 14 + ["4820"])))
    out.append('"WASPSTAT|v1|%d|%s"' % (nxt(), "|".join(toks)))

    out.append('"WASPSTAT|v1|%d|ROUNDEND|WEST|%d|chernarus"' % (nxt(), duration))
    out.append('"MATCH|v1|MILESTONE|FIRST_TOWN|side=WEST|town=Pustoshka|tMin=5"')
    out.append('"MATCH|v1|MILESTONE|FIRST_TOWN|side=EAST|town=Elektrozavodsk|tMin=6"')
    out.append('"MATCH|v1|MILESTONE|FIRST_TOWN|side=RESISTANCE|town=Gvozdno|tMin=30"')
    out.append('" SCUD launch detected t=2410"')
    out.append('"ICBMTEL destroyed t=3120"')
    out.append('"MATCH|v1|MILESTONE|HQ_DESTROYED|side=EAST|tMin=78"')
    out.append('"MATCH|v1|END|winner=WEST|durationSec=%d|world=chernarus|townsW=17|townsE=0'
               '|townsG=1|casW=228|casE=397|vehLostW=19|vehLostE=41|players=12|totalTowns=20"'
               % duration)
    return out


def load_names(path):
    """UID<TAB>name mapping, one per line. Blank lines and #comments ignored."""
    out = {}
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.rstrip("\r\n")
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            parts = line.split("\t") if "\t" in line else line.split(None, 1)
            if len(parts) >= 2:
                out[parts[0].strip()] = parts[1].strip()
    return out


def main(argv=None):
    ap = argparse.ArgumentParser(
        description="In-depth post-match report from WASPSTAT|v1| + MATCH|v1| telemetry.")
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("--rpt", metavar="PATH",
                     help="RPT / log file containing the telemetry lines ('-' for stdin).")
    src.add_argument("--sample", action="store_true",
                     help="Render a deterministic demo match (no data needed).")
    ap.add_argument("-o", "--out", metavar="PATH",
                    help="Output file. Defaults to stdout.")
    ap.add_argument("--format", choices=("html", "md"), default="html",
                    help="Output format (default: html).")
    ap.add_argument("--names", metavar="PATH",
                    help="UID<TAB>name file to label operators (otherwise Op-XXXX).")
    ap.add_argument("--title", help="Override the HTML <title>.")
    args = ap.parse_args(argv)

    if args.sample:
        lines = sample_lines()
    elif args.rpt == "-":
        lines = sys.stdin.read().splitlines()
    else:
        with open(args.rpt, "r", encoding="utf-8", errors="replace") as fh:
            lines = fh.read().splitlines()

    names = load_names(args.names) if args.names else None
    dm = parse_deep(lines, names=names)

    text = render_html(dm, title=args.title) if args.format == "html" else render_md(dm)
    if args.out:
        with open(args.out, "w", encoding="utf-8") as fh:
            fh.write(text)
        sys.stderr.write(
            "wrote %s (%s, %s, %d kills, %d captures, %d operators, %d coverage warnings)\n"
            % (args.out, dm.map_name, MatchData.fmt_duration(dm.duration), dm.total_kills,
               len(dm.caps), len(dm.players), len(dm.warnings)))
    else:
        sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
