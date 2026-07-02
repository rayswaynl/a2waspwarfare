#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
analyze_soak.py -- WASP soak-KPI analyzer (cmdcon41 fix-package grader)

Reads a server RPT (required) and an optional HC RPT (team-driver logs live
there; the capture pattern is `CAPTURED [`). Emits a compact scorecard grading
the soak against the cmdcon41 fix-package KPIs, with PASS/WATCH/FAIL verdicts.

stdlib only, Python 3.6+.

Usage:
    python analyze_soak.py <server.rpt> [hc.rpt]
    python analyze_soak.py <server.rpt> --hc <hc.rpt>
    python analyze_soak.py <server.rpt> --json          # machine-readable dump
    python analyze_soak.py <server.rpt> --no-color

Log-format cheat-sheet (all pipe-delimited, one per RPT line, quoted):
    AICOMSTAT|v2|EVENT|<SIDE>|<tick>|<TYPE>|k=v|k=v...
        ASSAULT_DISPATCH  team= town= dist= reissue=
        ASSAULT_ARRIVED   team= town= dist= elapsed=
        ASSAULT_STRANDED  team= town= dist= elapsed= moved= stuck=
        UNSTUCK_STRIKE    team= tier=
        TEAM_FOUNDED      via= template= class= cost=
        TARGET_ABANDON    team= town= reason= onGoto= cooldown=
        (cmdcon41 new) TARGET_ESCALATE / RALLY_ORDER / RALLY_ARRIVED /
        BREAKOFF / TOPUP_REQ / TOPUP_DONE / TEAM_RECYCLE / RECYCLE_FLAG /
        ORBITER_STUCK / ECON_SINK / CAPTURE_TRACE / STAGE ...
    AICOMSTAT|v1|POSTURE|<SIDE>|<tick>|<STANCE>|myTowns=|enTowns=|myStr=|...
    AICOMSTAT|v1|FRONT|<SIDE>|<tick>|held=|enemyHeld=|contested=|primary=|onFront=
    AICOMSTAT|v1|SPEARHEAD_REPICK|<SIDE>|<tick>|stalled=|approach=|newPrimary=|...
    AICOMSTAT|v1|MHQRELOC|<SIDE>|<tick>|<DEPLOYED|ABORT>|<reason>|...
    WASPSTAT|v1|<seq>|KILL|||<killerSide>|<victimSide>|<vclass>|<dist>|<type>|hw=|vc=|t=<sec>
    WASPSTAT|v1|<seq>|CAPTURE|<Town>|<newOwner>|<oldOwner>|t=<sec>
    WASPSTAT|v1|<seq>|ROUNDEND|<winner>|<clockSec>|<map>
    WASPSCALE|v2|<tick>|tier=|players=|AI_W=|AI_E=|AI_GUER=|AI_TOT=|groups=|fps=|map=|build=|hc_fps=

IMPORTANT (per project memory):
  * AICOM TEAMS run on the HC -> driver / CAPTURED logs go to the HC RPT
    (ArmA2OA.RPT), NOT the server RPT. Pass the HC RPT to get dogpile/capture
    driver telemetry. Only the LAST MISSINIT block of the HC RPT is scoped
    (the HC RPT is not archived on deploy, so it accumulates old matches).
  * AICOM tick (the integer after the SIDE in v1/v2 lines) == 1 minute of
    wall-clock. tick/60 == hours. Used for per-hour churn rates.
  * The archived reference full-match RPT is wasp-westwin-20260701.rpt; running
    this tool against it must reproduce: 583 dispatches, 40 arrivals (6.9%),
    13 zombie teams, 32 W<->E kills, 43/43 MHQ aborts.
"""

import sys
import os
import re
import json
import statistics
from collections import defaultdict, Counter, OrderedDict

# ---------------------------------------------------------------------------
# Baselines (pre-fix numbers from the archived reference match; the deltas we
# want cmdcon41 to move). Keep these here so the scorecard prints against them.
# ---------------------------------------------------------------------------
BASE_ARRIVAL_PCT   = 6.9      # 40 / 583 arrivals in the reference match
BASE_ZOMBIES       = 13       # teams with >=N dispatches and 0 arrivals
BASE_WE_KILLS      = 32       # army-vs-army kills (W<->E incl W->W, E->E)
BASE_WE_SHARE_PCT  = 0.8      # 32 / 3813 total kills
BASE_CHURN_W       = 102      # FRONT primary changes, WEST, over ~7h
BASE_CHURN_E       = 122      # FRONT primary changes, EAST, over ~7h
BASE_MHQ_ABORTS    = 43       # MHQRELOC aborts (43/43 = 100% abort in ref)
BASE_HOURS         = 7.0      # reference match length, for per-hour rates

# Zombie definition: a team is a "zombie" if it was dispatched at least this
# many times and never once arrived. N=3 reproduces the documented baseline of
# 13 zombies on the archived reference match (N=2 -> 15, N=1 -> 20).
ZOMBIE_MIN_DISPATCH = 3

# Verdict thresholds (fix-package KPIs).
TH_ARRIVAL_PASS  = 20.0   # arrival% >20 -> PASS
TH_ARRIVAL_GREAT = 30.0   # arrival% >30 -> GREAT
TH_ZOMBIE_PASS   = 2      # zombies 0..2 -> PASS
TH_WE_SHARE_PASS = 5.0    # W<->E share of kills >5% -> PASS
# churn "halved" pass is computed relative to baseline per side.

# cmdcon41 NEW event types to surface (count + last-3 samples each).
NEW_EVENT_TYPES = [
    "TARGET_ESCALATE",
    "RALLY_ORDER",
    "RALLY_ARRIVED",
    "BREAKOFF",
    "TOPUP_REQ",
    "TOPUP_DONE",
    "TEAM_RECYCLE",
    "RECYCLE_FLAG",
    "ORBITER_STUCK",
    "ECON_SINK",
    "CAPTURE_TRACE",
    "STAGE",
]

# ---------------------------------------------------------------------------
# Terminal color helpers (respect --no-color and non-tty)
# ---------------------------------------------------------------------------
class C:
    RESET = "\033[0m"; BOLD = "\033[1m"; DIM = "\033[2m"
    RED = "\033[31m"; GRN = "\033[32m"; YEL = "\033[33m"
    BLU = "\033[34m"; CYN = "\033[36m"; MAG = "\033[35m"

    enabled = True

    @classmethod
    def disable(cls):
        cls.enabled = False
        for k in ("RESET", "BOLD", "DIM", "RED", "GRN", "YEL", "BLU", "CYN", "MAG"):
            setattr(cls, k, "")


def _c(s, color):
    return "%s%s%s" % (color, s, C.RESET) if C.enabled else str(s)


# ---------------------------------------------------------------------------
# Parsing primitives
# ---------------------------------------------------------------------------
KV_RE = re.compile(r"([A-Za-z_][A-Za-z0-9_]*)=([^|\"\r\n]*)")


def parse_kvs(fields):
    """Parse trailing key=value fields (as a joined string or a list) into a dict.

    Values are kept as strings; callers coerce. Trailing quotes/CR stripped.
    """
    if isinstance(fields, (list, tuple)):
        fields = "|".join(fields)
    out = {}
    for m in KV_RE.finditer(fields):
        out[m.group(1)] = m.group(2).strip()
    return out


def _to_int(s, default=None):
    try:
        return int(str(s).strip())
    except (ValueError, TypeError):
        try:
            return int(float(s))
        except (ValueError, TypeError):
            return default


def _to_float(s, default=None):
    try:
        return float(str(s).strip())
    except (ValueError, TypeError):
        return default


def read_lines(path):
    """Read an RPT tolerantly (latin-1 never raises; A2 logs are ASCII-ish)."""
    with open(path, "r", encoding="latin-1", errors="replace") as fh:
        return fh.readlines()


STAT_MARKERS = ("WASPSTAT|", "AICOMSTAT|", "WASPSCALE|")


def _has_stats(lines):
    for ln in lines:
        for m in STAT_MARKERS:
            if m in ln:
                return True
    return False


def scope_last_missinit(lines, require_stats=True):
    """Return only the lines at/after the LAST *meaningful* MISSINIT marker.

    A match ends with a post-deploy server/HC reboot that emits a fresh
    MISSINIT but no gameplay stats (the archived reference RPT has exactly this
    -- a dead boot near EOF). Naively taking the very last MISSINIT would scope
    to that empty tail and drop the whole match.

    So when require_stats is True we pick the last MISSINIT that is FOLLOWED by
    at least one WASPSTAT/AICOMSTAT/WASPSCALE line. This:
      * scopes the archived reference to its real match (ignoring the dead boot),
      * scopes a genuine multi-match server/HC RPT to its final *played* match,
      * is a no-op for a single-match soak RPT.

    Returns (scoped_lines, scoped_bool).
    """
    idxs = [i for i, ln in enumerate(lines) if "MISSINIT" in ln]
    if not idxs:
        return lines, False
    if not require_stats:
        return lines[idxs[-1]:], True
    # walk MISSINIT markers from last to first; take the first whose tail has stats
    for k in range(len(idxs) - 1, -1, -1):
        start = idxs[k]
        end = idxs[k + 1] if k + 1 < len(idxs) else len(lines)
        # stats can appear anywhere from this MISSINIT to EOF; but to avoid
        # bleeding a *previous* match's stats into an empty final boot, first
        # check the segment up to the next MISSINIT, then fall back to EOF.
        if _has_stats(lines[start:end]) or (k == len(idxs) - 1 and _has_stats(lines[start:])):
            return lines[start:], True
    # no MISSINIT had stats after it; fall back to the last marker
    return lines[idxs[-1]:], True


def strip_line(ln):
    """Strip A2 log framing to expose the payload. Lines look like:

        [123,45.6,0,"PAYLOAD"]
    or  "PAYLOAD"
    We only care that our pipe-delimited token appears; return the raw line and
    let callers match substrings. Trailing whitespace/quotes trimmed.
    """
    return ln.rstrip("\r\n")


# ---------------------------------------------------------------------------
# Line matchers -- we scan substrings rather than anchoring, because A2 wraps
# payloads in [tick,elapsed,0,"..."] framing and the exact wrapper varies.
# ---------------------------------------------------------------------------
RE_V2_EVENT = re.compile(
    r"AICOMSTAT\|v2\|EVENT\|([A-Z]+)\|(\d+)\|([A-Z_][A-Z0-9_]*)\|?(.*)$"
)
RE_POSTURE = re.compile(
    r"AICOMSTAT\|v1\|POSTURE\|([A-Z]+)\|(\d+)\|([A-Z_]+)\|(.*)$"
)
RE_FRONT = re.compile(
    r"AICOMSTAT\|v1\|FRONT\|([A-Z]+)\|(\d+)\|(.*)$"
)
RE_REPICK = re.compile(
    r"AICOMSTAT\|v1\|SPEARHEAD_REPICK\|([A-Z]+)\|(\d+)\|(.*)$"
)
RE_MHQ = re.compile(
    r"AICOMSTAT\|v1\|MHQRELOC\|([A-Z]+)\|(\d+)\|([A-Za-z_-]+)\|?(.*)$"
)
RE_KILL = re.compile(
    r"WASPSTAT\|v1\|(\d+)\|KILL\|\|\|([A-Z]+)\|([A-Z]+)\|([^|]*)\|([^|]*)\|([^|]*)\|(.*)$"
)
RE_CAPTURE = re.compile(
    r"WASPSTAT\|v1\|(\d+)\|CAPTURE\|([^|]+)\|(\d+)\|(\d+)\|t=(\d+)"
)
RE_ROUNDEND = re.compile(
    r"WASPSTAT\|v1\|(\d+)\|ROUNDEND\|([A-Z]+)\|(\d+)\|([^|\"\r\n]+)"
)
RE_SCALE = re.compile(
    r"WASPSCALE\|v2\|(\d+)\|(.*)$"
)
RE_BASE_ASSAULT = re.compile(r"BASE-ASSAULT")
RE_CAPTURED = re.compile(r"CAPTURED \[")


# ---------------------------------------------------------------------------
# Main data container
# ---------------------------------------------------------------------------
class Soak(object):
    def __init__(self):
        # v2 events: type -> list of (side, tick, kv-dict, raw)
        self.events = defaultdict(list)
        # dispatches / arrivals keyed by team name
        self.dispatch = defaultdict(list)   # team -> list of dict(tick,town,dist,reissue)
        self.arrive = defaultdict(list)     # team -> list of dict(tick,town,dist,elapsed)
        self.dispatch_count = 0
        self.arrive_count = 0
        self.reissue_count = 0
        # kills
        self.kill_matrix = Counter()        # (killer, victim) -> n
        self.kill_total = 0
        # posture towns timeline: side -> list of (tick, myTowns)
        self.towns = defaultdict(list)
        # FRONT primary sequence: side -> list of (tick, primary)
        self.front = defaultdict(list)
        # repicks
        self.repick = defaultdict(int)
        # target abandon
        self.abandon = defaultdict(int)
        self.abandon_reasons = Counter()
        # MHQ
        self.mhq = defaultdict(lambda: Counter())   # side -> Counter(DEPLOYED/ABORT)
        self.mhq_abort_reasons = Counter()
        self.mhq_total = 0
        # captures (server-side WASPSTAT)
        self.captures = []                  # list of dict(town,new,old,t)
        self.capture_by_town = Counter()
        # perf
        self.scale = []                     # list of dict
        # roundend
        self.roundend = None
        # HC side
        self.hc_captured = []               # raw CAPTURED [ lines
        self.hc_capture_by_town = Counter()
        self.hc_scoped = False
        self.hc_present = False
        # base-assault phase
        self.base_assault_lines = []
        # duration
        self.max_tick = 0
        self.match_secs = None

    # -- ingestion -------------------------------------------------------
    def _note_tick(self, tick):
        if tick > self.max_tick:
            self.max_tick = tick

    def ingest_server(self, lines):
        for raw in lines:
            ln = strip_line(raw)

            m = RE_V2_EVENT.search(ln)
            if m:
                side, tick, etype, rest = m.group(1), _to_int(m.group(2), 0), m.group(3), m.group(4)
                kv = parse_kvs(rest)
                self._note_tick(tick)
                self.events[etype].append((side, tick, kv, ln))
                if etype == "ASSAULT_DISPATCH":
                    self.dispatch_count += 1
                    team = kv.get("team", "?")
                    reissue = kv.get("reissue", "false").lower() == "true"
                    if reissue:
                        self.reissue_count += 1
                    self.dispatch[team].append({
                        "tick": tick, "town": kv.get("town", "?"),
                        "dist": _to_float(kv.get("dist"), None),
                        "reissue": reissue, "side": side,
                    })
                elif etype == "ASSAULT_ARRIVED":
                    self.arrive_count += 1
                    team = kv.get("team", "?")
                    self.arrive[team].append({
                        "tick": tick, "town": kv.get("town", "?"),
                        "dist": _to_float(kv.get("dist"), None),
                        "elapsed": _to_float(kv.get("elapsed"), None),
                        "side": side,
                    })
                elif etype == "TARGET_ABANDON":
                    self.abandon[side] += 1
                    self.abandon_reasons[kv.get("reason", "unspecified")] += 1
                continue

            m = RE_POSTURE.search(ln)
            if m:
                side, tick = m.group(1), _to_int(m.group(2), 0)
                kv = parse_kvs(m.group(4))
                self._note_tick(tick)
                self.towns[side].append((tick, _to_int(kv.get("myTowns"), 0)))
                continue

            m = RE_FRONT.search(ln)
            if m:
                side, tick = m.group(1), _to_int(m.group(2), 0)
                kv = parse_kvs(m.group(3))
                self._note_tick(tick)
                self.front[side].append((tick, kv.get("primary", "?")))
                continue

            m = RE_REPICK.search(ln)
            if m:
                side = m.group(1)
                self.repick[side] += 1
                continue

            m = RE_MHQ.search(ln)
            if m:
                side, tick, verb, rest = m.group(1), _to_int(m.group(2), 0), m.group(3), m.group(4)
                self._note_tick(tick)
                self.mhq_total += 1
                verb_u = verb.upper()
                # normalize: anything that isn't ABORT counts as DEPLOYED-ish
                key = "ABORT" if verb_u == "ABORT" else verb_u
                self.mhq[side][key] += 1
                if verb_u == "ABORT":
                    # first token of rest is the reason
                    reason = rest.split("|")[0].strip() if rest else "unspecified"
                    if not reason:
                        reason = "unspecified"
                    self.mhq_abort_reasons[reason] += 1
                continue

            m = RE_KILL.search(ln)
            if m:
                killer, victim = m.group(2), m.group(3)
                self.kill_total += 1
                self.kill_matrix[(killer, victim)] += 1
                continue

            m = RE_CAPTURE.search(ln)
            if m:
                town = m.group(2)
                self.captures.append({
                    "town": town, "new": _to_int(m.group(3)),
                    "old": _to_int(m.group(4)), "t": _to_int(m.group(5)),
                })
                self.capture_by_town[town] += 1
                continue

            m = RE_ROUNDEND.search(ln)
            if m:
                self.roundend = {
                    "winner": m.group(2),
                    "secs": _to_int(m.group(3)),
                    "map": m.group(4).strip().strip('"'),
                }
                self.match_secs = self.roundend["secs"]
                continue

            m = RE_SCALE.search(ln)
            if m:
                tick = _to_int(m.group(1), 0)
                kv = parse_kvs(m.group(2))
                self._note_tick(tick)
                self.scale.append({
                    "tick": tick,
                    "players": _to_int(kv.get("players"), 0),
                    "AI_W": _to_int(kv.get("AI_W"), 0),
                    "AI_E": _to_int(kv.get("AI_E"), 0),
                    "AI_GUER": _to_int(kv.get("AI_GUER"), 0),
                    "AI_TOT": _to_int(kv.get("AI_TOT"), 0),
                    "groups": _to_int(kv.get("groups"), 0),
                    "fps": _to_float(kv.get("fps"), None),
                    "hc_fps": _to_float(kv.get("hc_fps"), None),
                    "build": kv.get("build", "?"),
                    "map": kv.get("map", "?"),
                })
                continue

            if RE_BASE_ASSAULT.search(ln):
                self.base_assault_lines.append(ln.strip())
                continue

    def ingest_hc(self, lines):
        self.hc_present = True
        scoped, ok = scope_last_missinit(lines)
        self.hc_scoped = ok
        for raw in scoped:
            ln = strip_line(raw)
            if RE_CAPTURED.search(ln):
                self.hc_captured.append(ln.strip())
                # try to pull a town-ish token for dogpile counting.
                # HC CAPTURED lines look like: ... CAPTURED [<town>] by <team> ...
                mt = re.search(r"CAPTURED \[([^\]]+)\]", ln)
                if mt:
                    self.hc_capture_by_town[mt.group(1)] += 1

    # -- derived metrics -------------------------------------------------
    def hours(self):
        """Best estimate of match length in hours.

        Prefer ROUNDEND clock seconds; else AICOM max tick (== minutes).
        """
        if self.match_secs:
            return self.match_secs / 3600.0
        if self.max_tick:
            return self.max_tick / 60.0
        return BASE_HOURS

    def arrival_pct(self):
        if self.dispatch_count == 0:
            return 0.0
        return 100.0 * self.arrive_count / self.dispatch_count

    def arrival_by_bucket(self):
        """dist-bucketed dispatch/arrival counts.

        Buckets by DISPATCH distance: <500, 500-2000, 2000+.
        A team 'arrived' for a dispatch if it has any ASSAULT_ARRIVED after that
        dispatch's tick. We approximate at the team+bucket level: for each
        dispatch we mark arrived if the team has an arrival at tick >= dispatch
        tick (first unused arrival). This gives a per-dispatch arrival rate.
        """
        buckets = OrderedDict([
            ("<500", {"d": 0, "a": 0}),
            ("500-2000", {"d": 0, "a": 0}),
            ("2000+", {"d": 0, "a": 0}),
        ])

        def bucket_of(dist):
            if dist is None:
                return "500-2000"
            if dist < 500:
                return "<500"
            if dist < 2000:
                return "500-2000"
            return "2000+"

        # Build per-team sorted arrival ticks (consumable).
        arr_ticks = {t: sorted(a["tick"] for a in lst)
                     for t, lst in self.arrive.items()}
        used = defaultdict(int)  # team -> index into arr_ticks consumed

        for team, dlist in self.dispatch.items():
            for d in sorted(dlist, key=lambda x: x["tick"]):
                b = bucket_of(d["dist"])
                buckets[b]["d"] += 1
                ticks = arr_ticks.get(team, [])
                idx = used[team]
                # find first unused arrival at tick >= dispatch tick
                while idx < len(ticks) and ticks[idx] < d["tick"]:
                    idx += 1
                if idx < len(ticks):
                    buckets[b]["a"] += 1
                    used[team] = idx + 1
                else:
                    used[team] = idx
        return buckets

    def median_dispatch_to_arrival_min(self):
        """Median minutes from a team's dispatch to its next arrival.

        Pairs each arrival to the most recent prior dispatch of the same team.
        Ticks are minutes, so the delta is already minutes.
        """
        deltas = []
        for team, alist in self.arrive.items():
            dlist = sorted(d["tick"] for d in self.dispatch.get(team, []))
            for a in alist:
                # most recent dispatch tick <= arrival tick
                prior = [dt for dt in dlist if dt <= a["tick"]]
                if prior:
                    deltas.append(a["tick"] - prior[-1])
                elif a.get("elapsed") is not None:
                    # fall back to elapsed= seconds -> minutes
                    deltas.append(a["elapsed"] / 60.0)
        if not deltas:
            return None
        return statistics.median(deltas)

    def zombies(self, min_dispatch=None):
        """Teams with >=min_dispatch dispatches and 0 arrivals."""
        n = ZOMBIE_MIN_DISPATCH if min_dispatch is None else min_dispatch
        z = []
        for team, dlist in self.dispatch.items():
            if len(dlist) >= n and len(self.arrive.get(team, [])) == 0:
                z.append((team, len(dlist)))
        z.sort(key=lambda x: (-x[1], x[0]))
        return z

    def we_kills(self):
        """Army-vs-army kills (both killer & victim in {WEST,EAST})."""
        n = 0
        for (k, v), c in self.kill_matrix.items():
            if k in ("WEST", "EAST") and v in ("WEST", "EAST"):
                n += c
        return n

    def we_share_pct(self):
        if self.kill_total == 0:
            return 0.0
        return 100.0 * self.we_kills() / self.kill_total

    def front_changes(self, side):
        """Count of consecutive-distinct primary changes for a side."""
        seq = [p for (_, p) in sorted(self.front.get(side, []), key=lambda x: x[0])]
        changes = 0
        prev = None
        for p in seq:
            if prev is not None and p != prev:
                changes += 1
            prev = p
        return changes

    def max_simultaneous_towns(self, side):
        vals = [v for (_, v) in self.towns.get(side, [])]
        return max(vals) if vals else 0

    def perf_summary(self):
        fps = [s["fps"] for s in self.scale if s["fps"] is not None]
        hcfps = [s["hc_fps"] for s in self.scale if s["hc_fps"] is not None]
        ai = [s["AI_TOT"] for s in self.scale if s["AI_TOT"] is not None]
        guer = [s["AI_GUER"] for s in self.scale if s["AI_GUER"] is not None]

        def mm(xs):
            if not xs:
                return (None, None, None)
            return (min(xs), statistics.median(xs), max(xs))

        return {
            "fps": mm(fps),
            "hc_fps": mm(hcfps),
            "ai_tot": mm(ai),
            "guer": mm(guer),
            "samples": len(self.scale),
        }


# ---------------------------------------------------------------------------
# Verdict helpers
# ---------------------------------------------------------------------------
def verdict_arrival(pct):
    if pct > TH_ARRIVAL_GREAT:
        return ("PASS", C.GRN, "great (>%.0f%%)" % TH_ARRIVAL_GREAT)
    if pct > TH_ARRIVAL_PASS:
        return ("PASS", C.GRN, ">%.0f%%" % TH_ARRIVAL_PASS)
    if pct >= TH_ARRIVAL_PASS * 0.5:
        return ("WATCH", C.YEL, "below %.0f%%" % TH_ARRIVAL_PASS)
    return ("FAIL", C.RED, "well below %.0f%%" % TH_ARRIVAL_PASS)


def verdict_zombies(n):
    if n <= TH_ZOMBIE_PASS:
        return ("PASS", C.GRN, "<=%d" % TH_ZOMBIE_PASS)
    if n <= max(TH_ZOMBIE_PASS * 2, 5):
        return ("WATCH", C.YEL, ">%d" % TH_ZOMBIE_PASS)
    return ("FAIL", C.RED, "many")


def verdict_we_share(pct):
    if pct > TH_WE_SHARE_PASS:
        return ("PASS", C.GRN, ">%.0f%%" % TH_WE_SHARE_PASS)
    if pct >= TH_WE_SHARE_PASS * 0.5:
        return ("WATCH", C.YEL, "below %.0f%%" % TH_WE_SHARE_PASS)
    return ("FAIL", C.RED, "armies not fighting")


def verdict_churn(cur_per_h, base_per_h):
    """Churn 'halved' relative to baseline per-hour -> PASS."""
    if base_per_h <= 0:
        return ("WATCH", C.YEL, "no baseline")
    ratio = cur_per_h / base_per_h
    if ratio <= 0.5:
        return ("PASS", C.GRN, "halved (%.0f%%)" % (ratio * 100))
    if ratio <= 0.8:
        return ("WATCH", C.YEL, "%.0f%% of baseline" % (ratio * 100))
    return ("FAIL", C.RED, "%.0f%% of baseline" % (ratio * 100))


def _delta_str(cur, base, unit="", better="up"):
    d = cur - base
    sign = "+" if d >= 0 else ""
    good = (d >= 0) if better == "up" else (d <= 0)
    col = C.GRN if good else C.RED
    return _c("%s%.1f%s" % (sign, d, unit), col)


# ---------------------------------------------------------------------------
# Report rendering
# ---------------------------------------------------------------------------
def hdr(title):
    bar = "=" * 74
    return "\n%s\n%s\n%s" % (_c(bar, C.DIM), _c(" " + title, C.BOLD + C.CYN), _c(bar, C.DIM))


def sub(title):
    return _c("-- " + title, C.BOLD)


def render(soak, args):
    out = []
    ap = out.append

    hours = soak.hours()
    build = "?"
    mapname = "?"
    if soak.scale:
        build = soak.scale[-1]["build"]
        mapname = soak.scale[-1]["map"]

    ap(hdr("WASP SOAK SCORECARD"))
    ap("  server RPT : %s" % args.server)
    ap("  hc RPT     : %s%s" % (
        args.hc if args.hc else _c("(none - HC-only telemetry unavailable)", C.YEL),
        (_c("  [scoped to last MISSINIT]", C.DIM) if (args.hc and soak.hc_scoped) else "")))
    ap("  build      : %s   map: %s" % (_c(build, C.BOLD), mapname))
    ap("  duration   : %.2f h  (%s)" % (
        hours,
        ("ROUNDEND clock" if soak.match_secs else "AICOM tick est")))
    if soak.roundend:
        ap("  ROUNDEND   : winner=%s  clock=%ds  map=%s" % (
            _c(soak.roundend["winner"], C.BOLD), soak.roundend["secs"], soak.roundend["map"]))

    verdicts = []  # (label, status, color)

    # 1. ARRIVAL --------------------------------------------------------
    ap(hdr("1. ARRIVAL  (assault teams reaching their town)"))
    pct = soak.arrival_pct()
    vs, vc, vnote = verdict_arrival(pct)
    verdicts.append(("ARRIVAL", vs, vc))
    ap("  dispatches : %d" % soak.dispatch_count)
    ap("  arrivals   : %d" % soak.arrive_count)
    ap("  arrival %%  : %s   (baseline %.1f%% -> delta %s)  [%s]" % (
        _c("%.1f%%" % pct, C.BOLD),
        BASE_ARRIVAL_PCT,
        _delta_str(pct, BASE_ARRIVAL_PCT, "pp", "up"),
        _c(vs, vc)))
    med = soak.median_dispatch_to_arrival_min()
    ap("  median dispatch->arrival: %s" % (
        _c("%.1f min" % med, C.BOLD) if med is not None else _c("n/a", C.DIM)))
    ap("  " + sub("by dispatch-distance bucket"))
    for b, d in soak.arrival_by_bucket().items():
        bp = (100.0 * d["a"] / d["d"]) if d["d"] else 0.0
        ap("     %-10s  %4d disp  %4d arr  %s" % (
            b, d["d"], d["a"], _c("%.1f%%" % bp, C.BOLD)))

    # 2. ZOMBIES --------------------------------------------------------
    ap(hdr("2. ZOMBIES  (>=%d dispatches, 0 arrivals)" % args.zombie_min))
    z = soak.zombies(args.zombie_min)
    vs, vc, vnote = verdict_zombies(len(z))
    verdicts.append(("ZOMBIES", vs, vc))
    ap("  zombie teams: %s   (baseline %d -> delta %s)  [%s]" % (
        _c(str(len(z)), C.BOLD), BASE_ZOMBIES,
        _delta_str(len(z), BASE_ZOMBIES, "", "down"), _c(vs, vc)))
    if z:
        ap("  " + sub("worst 5"))
        for team, n in z[:5]:
            ap("     %-14s  %d dispatches, 0 arrivals" % (team, n))

    # 3. ARMY-VS-ARMY ---------------------------------------------------
    ap(hdr("3. ARMY-VS-ARMY  (killer x victim)"))
    sides = ["WEST", "EAST", "GUER"]
    ap("  " + sub("kill matrix (rows=killer, cols=victim)"))
    ap("     %-8s %8s %8s %8s" % ("", "WEST", "EAST", "GUER"))
    for k in sides:
        row = "     %-8s" % k
        for v in sides:
            row += " %8d" % soak.kill_matrix.get((k, v), 0)
        ap(row)
    we = soak.we_kills()
    share = soak.we_share_pct()
    vs, vc, vnote = verdict_we_share(share)
    verdicts.append(("W<->E SHARE", vs, vc))
    ap("  total kills : %d" % soak.kill_total)
    ap("  W<->E kills : %s   (baseline %d)" % (_c(str(we), C.BOLD), BASE_WE_KILLS))
    ap("  W<->E share : %s   (baseline %.1f%% -> delta %s)  [%s]" % (
        _c("%.2f%%" % share, C.BOLD), BASE_WE_SHARE_PCT,
        _delta_str(share, BASE_WE_SHARE_PCT, "pp", "up"), _c(vs, vc)))

    # 4. CHURN ----------------------------------------------------------
    ap(hdr("4. CHURN  (front instability)"))
    cw = soak.front_changes("WEST")
    ce = soak.front_changes("EAST")
    cw_h = cw / hours if hours else 0.0
    ce_h = ce / hours if hours else 0.0
    bw_h = BASE_CHURN_W / BASE_HOURS
    be_h = BASE_CHURN_E / BASE_HOURS
    vw = verdict_churn(cw_h, bw_h)
    ve = verdict_churn(ce_h, be_h)
    # combined churn verdict = worse of the two
    order = {"PASS": 0, "WATCH": 1, "FAIL": 2}
    churn_status = vw if order[vw[0]] >= order[ve[0]] else ve
    verdicts.append(("CHURN", churn_status[0], churn_status[1]))
    ap("  FRONT primary changes / hour:")
    ap("     WEST : %s  (%d total)   baseline %.1f/h  [%s %s]" % (
        _c("%.1f/h" % cw_h, C.BOLD), cw, bw_h, _c(vw[0], vw[1]), vw[2]))
    ap("     EAST : %s  (%d total)   baseline %.1f/h  [%s %s]" % (
        _c("%.1f/h" % ce_h, C.BOLD), ce, be_h, _c(ve[0], ve[1]), ve[2]))
    ap("  TARGET_ABANDON : W=%d E=%d  (total %d)" % (
        soak.abandon.get("WEST", 0), soak.abandon.get("EAST", 0),
        sum(soak.abandon.values())))
    if soak.abandon_reasons:
        top = ", ".join("%s=%d" % (r, n) for r, n in soak.abandon_reasons.most_common(4))
        ap("     abandon reasons: %s" % top)
    ap("  SPEARHEAD_REPICK : W=%d E=%d  (total %d)" % (
        soak.repick.get("WEST", 0), soak.repick.get("EAST", 0),
        sum(soak.repick.values())))
    reissue_share = (100.0 * soak.reissue_count / soak.dispatch_count) if soak.dispatch_count else 0.0
    ap("  reissue share : %s  (%d / %d dispatches)" % (
        _c("%.1f%%" % reissue_share, C.BOLD), soak.reissue_count, soak.dispatch_count))

    # 5. NEW cmdcon41 EVENTS -------------------------------------------
    ap(hdr("5. NEW cmdcon41 EVENTS  (count + last 3 samples)"))
    any_new = False
    for et in NEW_EVENT_TYPES:
        evs = soak.events.get(et, [])
        if not evs:
            ap("  %-16s : %s" % (et, _c("0", C.DIM)))
            continue
        any_new = True
        ap("  %-16s : %s" % (et, _c(str(len(evs)), C.BOLD + C.GRN)))
        for (side, tick, kv, raw) in evs[-3:]:
            payload = "|".join("%s=%s" % (k, v) for k, v in kv.items())
            ap("       [t%-4d %s] %s" % (tick, side, payload[:90]))
    # CAPTURE_TRACE gate/wait ratio
    ct = soak.events.get("CAPTURE_TRACE", [])
    if ct:
        gate = sum(1 for (_, _, kv, raw) in ct
                   if "ARRIVAL_GATE" in raw or kv.get("phase") == "ARRIVAL_GATE"
                   or kv.get("gate") == "true")
        wait = sum(1 for (_, _, kv, raw) in ct
                   if "ARRIVAL_WAIT" in raw or kv.get("phase") == "ARRIVAL_WAIT"
                   or kv.get("wait") == "true")
        ratio = ("%.2f" % (gate / wait)) if wait else ("inf" if gate else "0")
        ap("  CAPTURE_TRACE gate/wait: GATE=%d WAIT=%d ratio=%s" % (gate, wait, ratio))
    # BASE-ASSAULT fire phase
    ap("  BASE-ASSAULT lines : %s" % (
        _c(str(len(soak.base_assault_lines)), C.BOLD + C.GRN) if soak.base_assault_lines
        else _c("0", C.DIM)))
    for bl in soak.base_assault_lines[-3:]:
        ap("       %s" % bl[:100])
    # MHQRELOC deployed vs abort
    ap("  " + sub("MHQRELOC deployed vs abort"))
    total_dep = sum(cnt.get("DEPLOYED", 0) for cnt in soak.mhq.values())
    total_abt = sum(cnt.get("ABORT", 0) for cnt in soak.mhq.values())
    ap("     DEPLOYED=%d  ABORT=%d  (baseline aborts %d)" % (
        total_dep, total_abt, BASE_MHQ_ABORTS))
    for side in ("WEST", "EAST"):
        if soak.mhq.get(side):
            parts = ", ".join("%s=%d" % (k, v) for k, v in soak.mhq[side].items())
            ap("       %s: %s" % (side, parts))
    if soak.mhq_abort_reasons:
        for r, n in soak.mhq_abort_reasons.most_common(5):
            ap("       abort reason: %-32s %d" % (r, n))
    if not any_new and not soak.base_assault_lines:
        ap("  %s" % _c("(no cmdcon41 events present -- pre-fix RPT or events not wired)", C.YEL))

    # 6. HOLD / SEE-SAW -------------------------------------------------
    ap(hdr("6. HOLD / SEE-SAW  (town control)"))
    mw = soak.max_simultaneous_towns("WEST")
    me = soak.max_simultaneous_towns("EAST")
    ap("  max simultaneous towns held:  WEST=%s  EAST=%s" % (
        _c(str(mw), C.BOLD), _c(str(me), C.BOLD)))
    ap("  total captures (WASPSTAT): %d" % len(soak.captures))
    if soak.capture_by_town:
        ap("  " + sub("captures per town (top 8 -- see-saw / dogpile)"))
        for town, n in soak.capture_by_town.most_common(8):
            flag = _c("  <- dogpile", C.YEL) if n >= 4 else ""
            ap("     %-16s %d%s" % (town, n, flag))
    if soak.hc_present:
        ap("  " + sub("HC CAPTURED driver lines (scoped last MISSINIT)"))
        ap("     CAPTURED [ lines: %d" % len(soak.hc_captured))
        if soak.hc_capture_by_town:
            for town, n in soak.hc_capture_by_town.most_common(8):
                flag = _c("  <- dogpile", C.YEL) if n >= 4 else ""
                ap("     %-16s %d%s" % (town, n, flag))
    else:
        ap("  %s" % _c("(no HC RPT -> capture-driver / dogpile detail unavailable)", C.DIM))

    # 7. PERF -----------------------------------------------------------
    ap(hdr("7. PERF  (WASPSCALE fps vs AI load)"))
    p = soak.perf_summary()

    def fmt_mm(mm, unit=""):
        if mm[0] is None:
            return _c("n/a", C.DIM)
        return "min %s / med %s / max %s" % (
            _c("%g%s" % (mm[0], unit), C.BOLD), "%g%s" % (mm[1], unit), "%g%s" % (mm[2], unit))

    ap("  samples    : %d" % p["samples"])
    ap("  server fps : %s" % fmt_mm(p["fps"]))
    ap("  HC fps     : %s" % fmt_mm(p["hc_fps"]))
    ap("  AI_TOT     : %s" % fmt_mm(p["ai_tot"]))
    ap("  GUER AI    : %s" % fmt_mm(p["guer"]))
    # fps-at-peak-AI: find sample with max AI_TOT
    if soak.scale:
        peak = max(soak.scale, key=lambda s: s["AI_TOT"] or 0)
        ap("  at peak AI_TOT=%d : fps=%s hc_fps=%s (t%d)" % (
            peak["AI_TOT"],
            _c(str(peak["fps"]), C.BOLD), str(peak["hc_fps"]), peak["tick"]))

    # VERDICT block ----------------------------------------------------
    ap(hdr("VERDICT"))
    worst = "PASS"
    for label, status, color in verdicts:
        ap("  %-14s : %s" % (label, _c(status, color)))
        if order.get(status, 0) > order.get(worst, 0):
            worst = status
    overall_col = {"PASS": C.GRN, "WATCH": C.YEL, "FAIL": C.RED}[worst]
    ap("  %s" % _c("-" * 30, C.DIM))
    ap("  %-14s : %s" % ("OVERALL", _c(worst, C.BOLD + overall_col)))
    ap("")

    return "\n".join(out)


def render_json(soak, args):
    p = soak.perf_summary()
    data = {
        "server_rpt": args.server,
        "hc_rpt": args.hc,
        "hours": soak.hours(),
        "roundend": soak.roundend,
        "arrival": {
            "dispatches": soak.dispatch_count,
            "arrivals": soak.arrive_count,
            "arrival_pct": soak.arrival_pct(),
            "baseline_pct": BASE_ARRIVAL_PCT,
            "median_dispatch_to_arrival_min": soak.median_dispatch_to_arrival_min(),
            "by_bucket": {b: d for b, d in soak.arrival_by_bucket().items()},
        },
        "zombies": {
            "min_dispatch": args.zombie_min,
            "count": len(soak.zombies(args.zombie_min)),
            "baseline": BASE_ZOMBIES,
            "worst5": soak.zombies(args.zombie_min)[:5],
        },
        "army_vs_army": {
            "matrix": {"%s->%s" % k: v for k, v in soak.kill_matrix.items()},
            "total_kills": soak.kill_total,
            "we_kills": soak.we_kills(),
            "we_share_pct": soak.we_share_pct(),
            "baseline_we_kills": BASE_WE_KILLS,
            "baseline_we_share_pct": BASE_WE_SHARE_PCT,
        },
        "churn": {
            "front_changes": {"WEST": soak.front_changes("WEST"),
                              "EAST": soak.front_changes("EAST")},
            "target_abandon": dict(soak.abandon),
            "abandon_reasons": dict(soak.abandon_reasons),
            "spearhead_repick": dict(soak.repick),
            "reissue_count": soak.reissue_count,
        },
        "new_events": {et: len(soak.events.get(et, [])) for et in NEW_EVENT_TYPES},
        "base_assault_lines": len(soak.base_assault_lines),
        "mhq": {
            "deployed": sum(c.get("DEPLOYED", 0) for c in soak.mhq.values()),
            "abort": sum(c.get("ABORT", 0) for c in soak.mhq.values()),
            "abort_reasons": dict(soak.mhq_abort_reasons),
            "baseline_aborts": BASE_MHQ_ABORTS,
        },
        "hold": {
            "max_towns": {"WEST": soak.max_simultaneous_towns("WEST"),
                          "EAST": soak.max_simultaneous_towns("EAST")},
            "captures": len(soak.captures),
            "capture_by_town": dict(soak.capture_by_town),
            "hc_captured": len(soak.hc_captured),
            "hc_capture_by_town": dict(soak.hc_capture_by_town),
        },
        "perf": {
            "fps": p["fps"], "hc_fps": p["hc_fps"],
            "ai_tot": p["ai_tot"], "guer": p["guer"], "samples": p["samples"],
        },
    }
    return json.dumps(data, indent=2)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
class Args(object):
    server = None
    hc = None
    json = False
    no_color = False
    zombie_min = ZOMBIE_MIN_DISPATCH


def parse_args(argv):
    a = Args()
    pos = []
    i = 0
    while i < len(argv):
        tok = argv[i]
        if tok == "--hc":
            i += 1
            a.hc = argv[i] if i < len(argv) else None
        elif tok == "--json":
            a.json = True
        elif tok in ("--no-color", "--nocolor"):
            a.no_color = True
        elif tok == "--zombie-min":
            i += 1
            a.zombie_min = _to_int(argv[i], ZOMBIE_MIN_DISPATCH) if i < len(argv) else ZOMBIE_MIN_DISPATCH
        elif tok in ("-h", "--help"):
            print(__doc__)
            sys.exit(0)
        elif tok.startswith("-"):
            sys.stderr.write("unknown option: %s\n" % tok)
            sys.exit(2)
        else:
            pos.append(tok)
        i += 1
    if not pos:
        sys.stderr.write(
            "usage: analyze_soak.py <server.rpt> [hc.rpt] [--hc HC] "
            "[--zombie-min N] [--json] [--no-color]\n")
        sys.exit(2)
    a.server = pos[0]
    if len(pos) > 1 and not a.hc:
        a.hc = pos[1]
    return a


def main(argv):
    args = parse_args(argv)

    if args.no_color or not sys.stdout.isatty():
        C.disable()

    if not os.path.isfile(args.server):
        sys.stderr.write("server RPT not found: %s\n" % args.server)
        sys.exit(1)

    soak = Soak()
    srv_lines = read_lines(args.server)
    # Scope server RPT to last MISSINIT too (harmless if single match; correct
    # if the server RPT accumulated multiple matches).
    scoped_srv, ok = scope_last_missinit(srv_lines)
    soak.ingest_server(scoped_srv)

    if args.hc:
        if not os.path.isfile(args.hc):
            sys.stderr.write("WARNING: HC RPT not found, skipping: %s\n" % args.hc)
            args.hc = None
        else:
            soak.ingest_hc(read_lines(args.hc))

    if args.json:
        print(render_json(soak, args))
    else:
        print(render(soak, args))


if __name__ == "__main__":
    main(sys.argv[1:])
