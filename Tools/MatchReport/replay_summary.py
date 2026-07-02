"""Replay summary derivations for WASP post-match reports.

This module intentionally works from finalized MatchData only. It does not read
raw PLAYERSTATS rows, so headless clients and AI controller names never become a
stat surface here.
"""
from collections import Counter


SIDES = ("west", "east", "guer")


def _fmt_time(sec):
    sec = int(max(0, sec))
    hh, rem = divmod(sec, 3600)
    mm, ss = divmod(rem, 60)
    if hh:
        return f"{hh}:{mm:02d}:{ss:02d}"
    return f"{mm:02d}:{ss:02d}"


def kill_timeline(m, bins=48):
    """Return fixed-width kill bins by side for a replay strip."""
    duration = max(1, int(getattr(m, "duration", 1) or 1))
    bins = max(1, int(bins))
    span = float(duration) / bins
    rows = []
    for idx in range(bins):
        start = int(idx * span)
        end = int((idx + 1) * span)
        rows.append({
            "start": start,
            "end": end,
            "label": _fmt_time(start),
            "west": 0,
            "east": 0,
            "guer": 0,
            "other": 0,
        })
    for t, _name, side, _weapon, _cat, _dist in getattr(m, "kills", []):
        idx = min(bins - 1, max(0, int(float(max(0, t)) / duration * bins)))
        key = side if side in SIDES else "other"
        rows[idx][key] += 1
    return rows


def support_markers(m):
    """Return SCUD/TEL markers positioned for the same replay timeline."""
    duration = max(1, int(getattr(m, "duration", 1) or 1))
    out = []
    for ev in getattr(m, "support_events", []) or []:
        t = int(max(0, min(duration, ev.get("t", 0))))
        out.append({
            "t": t,
            "label": ev.get("label", "support event"),
            "kind": ev.get("kind", "SUPPORT"),
            "at": _fmt_time(t),
            "pct": round(t / float(duration), 4),
        })
    return out


def town_control_area(m):
    """Integrate towns-held over time for each side.

    The values are town-seconds. pct is share of all side-held town time, excluding
    neutral time so the chart answers "who controlled active territory most?".
    """
    duration = max(1, int(getattr(m, "duration", 1) or 1))
    events = sorted((int(t), town, side) for t, town, side in getattr(m, "caps", []))
    marks = sorted(set([0, duration] + [max(0, min(duration, t)) for t, _town, _side in events]))
    area = Counter()
    for a, b in zip(marks, marks[1:]):
        if b <= a:
            continue
        owners = m.owners_at(a)
        dt = b - a
        for side in SIDES:
            area[side] += sum(v == side for v in owners.values()) * dt
    total = float(sum(area.values())) or 1.0
    return {
        side: {
            "town_seconds": int(area[side]),
            "pct": round(area[side] / total, 4),
        }
        for side in SIDES
    }


def capture_streaks(m, min_len=3):
    """Return consecutive same-side capture streaks for callout cards."""
    streaks = []
    cur_side, cur = None, []
    for cap in sorted(getattr(m, "caps", []), key=lambda c: c[0]):
        side = cap[2]
        if side == cur_side:
            cur.append(cap)
        else:
            if len(cur) >= min_len:
                streaks.append(_streak_row(cur_side, cur))
            cur_side, cur = side, [cap]
    if len(cur) >= min_len:
        streaks.append(_streak_row(cur_side, cur))
    streaks.sort(key=lambda row: (-row["count"], row["start"]))
    return streaks


def _streak_row(side, caps):
    return {
        "side": side,
        "count": len(caps),
        "start": int(caps[0][0]),
        "end": int(caps[-1][0]),
        "label": f"{side.upper()} captured {len(caps)} straight",
        "towns": [town for _t, town, _side in caps],
    }


def build_replay_summary(m):
    """Build the JSON-serialisable replay sidecar."""
    return {
        "map": getattr(m, "map_name", ""),
        "duration": int(getattr(m, "duration", 0) or 0),
        "winner": getattr(m, "winner", ""),
        "killTimeline": kill_timeline(m),
        "supportMarkers": support_markers(m),
        "townControlArea": town_control_area(m),
        "captureStreaks": capture_streaks(m),
    }
