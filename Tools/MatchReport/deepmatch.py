"""
DeepMatch — the full-detail analysis behind the in-depth match report.

Where `matchdata.MatchData` is shaped for a 48-second vertical video (it keeps the few
numbers a scene can show and throws the rest away), `DeepMatch` keeps everything the
telemetry carries and derives the tables a post-match read-through wants: a merged
event timeline, per-town ownership history, per-side territory-seconds, kill tempo,
weapon and distance distributions, the complete 15-field operator table, head-to-head
pairs, and an honest coverage audit.

Two design rules:

  * **stdlib only.** `matchdata.finalize()` pulls in numpy for the control-map grid, so
    the whole video path needs numpy + Pillow. This report is a text/HTML artifact that
    should run on the box that already has the RPT, so it imports nothing but the
    standard library (plus the pure, dependency-free helpers in `matchdata`).
  * **never invent a number.** Anything not in the log is reported as absent. Event
    times that had to be interpolated are tracked and surfaced in the coverage audit
    rather than being presented as measured.
"""
from collections import Counter, OrderedDict

from matchdata import (
    MatchData, SIDE_FROM_PSTAT, SIDE_NAME, TOWN_COORDS, WORLD_SIZE,
    _clean, _dequote, _pretty_weapon, _support_event, _time_token,
    is_excluded_name, side_from_id, side_from_str,
)
from matchfacts import parse_match_family

WASPSTAT_PREFIX = "WASPSTAT|v1|"
WASPSTAT_EXTENDED_RECORDS = ("CAMP", "BUILDINGKILL")

#--- Fixed faction order for every table and chart in the report. Never rank-ordered:
#--- a filter or a zero-score faction must not repaint or reorder the others.
FACTION_ORDER = ("west", "east", "guer")
FACTION_LABEL = {"west": "BLUFOR", "east": "OPFOR", "guer": "GUER", "neu": "CIV / CONTESTED"}

#--- WASPSTAT KILL category enum (docs/WASPSTAT-FORMAT.md). Fixed display order.
KILL_CATEGORIES = ("INF", "VEH", "AIR", "STATIC", "STRUCT", "HQ")
CATEGORY_LABEL = {"INF": "Infantry", "VEH": "Ground vehicle", "AIR": "Aircraft",
                  "STATIC": "Static weapon", "STRUCT": "Structure", "HQ": "Headquarters"}

#--- PLAYERSTATS d0..d14, in wire order. Drives the full operator table.
STAT_FIELDS = (
    ("Inf kills", "d0"), ("Veh kills", "d1"), ("Air kills", "d2"), ("Static kills", "d3"),
    ("Factory kills", "d4"), ("HQ kills", "d5"), ("Deaths", "d6"), ("PvP kills", "d7"),
    ("Supply runs", "d8"), ("Supply value", "d9"), ("Town caps", "d10"), ("Camp caps", "d11"),
    ("Built", "d12"), ("Defences", "d13"), ("Playtime", "d14"),
)

#--- Engagement-range buckets, in metres. Upper bound is exclusive; None = open-ended.
DISTANCE_BUCKETS = (
    ("0–50 m", 0, 50), ("50–150 m", 50, 150), ("150–300 m", 150, 300),
    ("300–600 m", 300, 600), ("600–1000 m", 600, 1000), ("1000 m+", 1000, None),
)


def fmt_clock(sec):
    """Match clock as H:MM:SS / MM:SS — the timeline's left gutter."""
    sec = int(max(0, sec))
    h, rem = divmod(sec, 3600)
    m, s = divmod(rem, 60)
    return "%d:%02d:%02d" % (h, m, s) if h else "%02d:%02d" % (m, s)


def pct(n, total):
    return (100.0 * n / total) if total else 0.0


def _is_playerstats_token(token):
    """A PLAYERSTATS head has a UID and all 15 deltas plus the side field."""
    if ":" not in token:
        return False
    uid, fields = token.split(":", 1)
    return bool(uid) and len(fields.split(",")) >= 16


class DeepMatch(object):
    """Every derived table the in-depth report renders. Build via `parse_deep`."""

    def __init__(self):
        self.facts = None            # MatchFacts (MATCH|v1| family)
        self.map_name = ""
        self.world_size = WORLD_SIZE["default"]
        self.duration = 0
        self.winner = "neu"
        self.towns = []              # every known town on this terrain
        self.init_owners = {}
        self.caps = []               # {t, town, old, new, exact}
        self.kills = []              # {t, killer, victim, kside, vside, weapon, cat, dist, exact}
        self.support_events = []
        self.auxiliary_times = []    # measured t= values on coverage-only WASPSTAT records
        self.players = []
        self.excluded_players = []   # HC / AI-controller rows, kept only for the audit
        self.pvp_pairs = Counter()
        self.seqs = []
        self.record_counts = Counter()
        self.unresolved_uids = 0
        self.in_progress = False

    # ---- ownership ------------------------------------------------------
    def owners_at(self, ts):
        """Town -> owning side at match time `ts` (seconds)."""
        o = dict(self.init_owners)
        for c in self.caps:
            if c["t"] <= ts and c["town"] in o:
                o[c["town"]] = c["new"]
        return o

    def final_town_counts(self):
        """Towns held per side at the bell.

        `MATCH|v1|END` wins when present: the mission counts with `GetTownsHeld`, which sees
        towns a side owned from spawn and never had to capture, while a CAPTURE-derived count
        only knows about towns that changed hands. Falls back to the derived count otherwise.
        """
        if self.facts and self.facts.end:
            counts = self.facts.final_towns()
            if any(counts.values()):
                return counts
        derived = Counter(self.final_owners.values())
        return dict((s, derived.get(s, 0)) for s in FACTION_ORDER)

    def finalize(self):
        f = self.facts
        #--- END is authoritative for winner/duration; ROUNDEND agrees when both exist, but END
        #--- is recomputed mission-side independently of WFBE_C_STATLOG, so it wins on conflict.
        if f and f.end:
            self.winner = f.winner or self.winner
            self.duration = f.duration or self.duration
        self.duration = max(1, int(self.duration))

        for t in self.towns:
            self.init_owners.setdefault(t, "neu")
        self.caps.sort(key=lambda c: c["t"])

        self._derive_territory()
        self._derive_momentum()
        self._derive_combat()
        self._derive_operators()
        self._derive_timeline()
        self._derive_coverage()
        return self

    # ---- territory ------------------------------------------------------
    def _derive_territory(self):
        """Per-town flip history + per-side town-seconds (the real 'who held the map')."""
        owner = dict(self.init_owners)
        since = dict((t, 0) for t in owner)
        held = dict((t, Counter()) for t in owner)
        flips = Counter()
        first_flip, last_flip = {}, {}

        for c in self.caps:
            town = c["town"]
            if town not in owner:
                #--- a capture for a town the static table doesn't know (new terrain / renamed
                #--- logic). Admit it at the capture time rather than dropping the event.
                owner[town] = "neu"
                since[town] = c["t"]
                held[town] = Counter()
            held[town][owner[town]] += max(0, c["t"] - since[town])
            owner[town] = c["new"]
            since[town] = c["t"]
            flips[town] += 1
            first_flip.setdefault(town, c["t"])
            last_flip[town] = c["t"]

        for town in owner:
            held[town][owner[town]] += max(0, self.duration - since[town])

        self.final_owners = owner
        self.town_rows = []
        for town in sorted(owner):
            h = held[town]
            self.town_rows.append({
                "town": town,
                "final": owner[town],
                "flips": flips.get(town, 0),
                "first": first_flip.get(town),
                "last": last_flip.get(town),
                "held": h,
                "dominant": max(h.items(), key=lambda kv: kv[1])[0] if h else "neu",
            })

        #--- territory-seconds per side: the area-under-the-curve measure of map control,
        #--- which a final town count alone hides (a side can lead for an hour and lose 18–2).
        #--- Two denominators, because they answer different questions: the terrain table holds
        #--- every town logic, but a match only activates WFBE_C_TOWNS_ACTIVE_MAX of them, so a
        #--- whole-map share is mostly "neutral" and says nothing about who won the ground.
        self.town_seconds = Counter()
        self.active_seconds = Counter()
        self.active_towns = 0
        for row in self.town_rows:
            ever_owned = any(s != "neu" and secs > 0 for s, secs in row["held"].items())
            if ever_owned:
                self.active_towns += 1
            for side, secs in row["held"].items():
                self.town_seconds[side] += secs
                if ever_owned:
                    self.active_seconds[side] += secs
        self.town_seconds_total = sum(self.town_seconds.values())
        self.active_seconds_total = sum(self.active_seconds.values())
        self.idle_towns = len(self.town_rows) - self.active_towns

        self.contested = sorted(
            [r for r in self.town_rows if r["flips"] > 0],
            key=lambda r: (-r["flips"], r["town"]))

        #--- capture streaks: consecutive captures by one side, the shape of a push.
        self.streaks = []
        for c in self.caps:
            if self.streaks and self.streaks[-1]["side"] == c["new"]:
                s = self.streaks[-1]
                s["n"] += 1
                s["end"] = c["t"]
                s["towns"].append(c["town"])
            else:
                self.streaks.append({"side": c["new"], "n": 1, "start": c["t"],
                                     "end": c["t"], "towns": [c["town"]]})
        self.best_streak = max(self.streaks, key=lambda s: s["n"]) if self.streaks else None

        self.caps_by_side = Counter(c["new"] for c in self.caps)

    # ---- momentum -------------------------------------------------------
    def _derive_momentum(self):
        """Towns held per side, sampled across the match — the momentum line chart."""
        step = max(20, self.duration // 96)
        self.ser_x = list(range(0, self.duration + 1, step))
        if self.ser_x[-1] != self.duration:
            self.ser_x.append(self.duration)
        snaps = [self.owners_at(t) for t in self.ser_x]
        self.series = OrderedDict(
            (side, [sum(1 for v in o.values() if v == side) for o in snaps])
            for side in FACTION_ORDER)
        self.series["neu"] = [sum(1 for v in o.values() if v == "neu") for o in snaps]

        #--- lead changes / largest deficit, computed on the WEST–EAST town differential.
        diff = [w - e for w, e in zip(self.series["west"], self.series["east"])]
        self.lead_changes = sum(1 for a, b in zip(diff, diff[1:])
                                if a and b and (a > 0) != (b > 0))
        wsign = 1 if self.winner == "west" else (-1 if self.winner == "east" else 0)
        self.max_deficit = int(-min(d * wsign for d in diff)) if (wsign and diff) else 0

    # ---- combat ---------------------------------------------------------
    def _derive_combat(self):
        self.total_kills = len(self.kills)
        self.kills_by_side = Counter(k["kside"] for k in self.kills)
        self.deaths_by_side = Counter(k["vside"] for k in self.kills if k["vside"] != "neu")
        self.kills_by_cat = Counter(k["cat"] for k in self.kills)
        self.weapons = Counter(k["weapon"] for k in self.kills)

        #--- distances: -1 means the engine could not compute one; excluded from the
        #--- histogram rather than binned as a 0 m kill.
        measured = [k for k in self.kills if k["dist"] >= 0]
        self.dist_measured = len(measured)
        self.dist_rows = []
        for label, lo, hi in DISTANCE_BUCKETS:
            n = sum(1 for k in measured if k["dist"] >= lo and (hi is None or k["dist"] < hi))
            self.dist_rows.append({"label": label, "n": n, "pct": pct(n, len(measured))})
        self.median_dist = 0
        if measured:
            ds = sorted(k["dist"] for k in measured)
            self.median_dist = ds[len(ds) // 2]
        self.longest = max(measured, key=lambda k: k["dist"]) if measured else None

        #--- kill tempo: fixed-count bins so the chart's x-axis is always the match length.
        #--- Bin edges are proportional, not `duration // bins`: integer-truncated widths leave a
        #--- remainder at the tail that the min() clamp dumps into the last bin, inventing a
        #--- final-minute spike that never happened.
        bins = 32
        width = self.duration / float(bins)
        self.tempo_x = [int(i * width) for i in range(bins)]
        self.tempo = OrderedDict((s, [0] * bins) for s in FACTION_ORDER)
        for k in self.kills:
            idx = min(bins - 1, int(k["t"] * bins // self.duration))
            if k["kside"] in self.tempo:
                self.tempo[k["kside"]][idx] += 1
        self.tempo_width = int(round(width))
        self.peak_bin = max(range(bins),
                            key=lambda i: sum(self.tempo[s][i] for s in FACTION_ORDER))

        self.pvp_kills = sum(1 for k in self.kills if k["killer"] and k["victim"])
        self.support_counts = Counter(e["kind"] for e in self.support_events)

    # ---- operators ------------------------------------------------------
    def _derive_operators(self):
        """The full 15-field table, HC/AI rows removed (they carry UIDs but aren't operators)."""
        for p in self.players:
            d = p["d"]
            p["kills"] = d[0] + d[1] + d[2] + d[3]
            p["score"] = MatchData.score(d, p["kills"])
            p["kd"] = p["kills"] / max(1, d[6])
        self.players.sort(key=lambda p: -p["score"])
        self.mvp = self.players[0] if self.players else None
        self.ai_only = not self.players

        self.by_side = OrderedDict((s, [p for p in self.players if p["side"] == s])
                                   for s in FACTION_ORDER)
        self.side_totals = OrderedDict()
        for side in FACTION_ORDER:
            roster = self.by_side[side]
            tot = [0] * 15
            for p in roster:
                for i in range(15):
                    tot[i] += p["d"][i]
            self.side_totals[side] = {"n": len(roster), "d": tot,
                                      "kills": tot[0] + tot[1] + tot[2] + tot[3]}

        #--- superlatives: one tag per operator, best-first, so five different names light up.
        self.awards = OrderedDict()
        if self.longest and self.longest["killer"]:
            self.awards[self.longest["killer"]] = ("THE SNIPER", "%d m kill" % self.longest["dist"])
        for tag, idx, unit in (("THE BUTCHER", 0, "infantry kills"),
                               ("ARMOR HUNTER", 1, "vehicle kills"),
                               ("ACE OF THE SKIES", 2, "air kills"),
                               ("TIP OF THE SPEAR", 10, "town captures"),
                               ("QUARTERMASTER", 8, "supply runs"),
                               ("COMBAT ENGINEER", 12, "structures built")):
            if not self.players:
                break
            cand = max(self.players, key=lambda p: p["d"][idx])
            if cand["d"][idx] > 0 and cand["name"] not in self.awards:
                self.awards[cand["name"]] = (tag, "%d %s" % (cand["d"][idx], unit))
        for p in self.players:
            p["award"] = self.awards.get(p["name"])

        kdp = [p for p in self.players if p["kills"] >= 3]
        self.kd_leader = max(kdp, key=lambda p: p["kd"]) if kdp else None

        #--- head-to-head: fold the directed PvP counter into undirected pairs.
        pairs, seen = [], set()
        for (a, b), n in self.pvp_pairs.items():
            key = tuple(sorted((a, b)))
            if key in seen:
                continue
            seen.add(key)
            ab = self.pvp_pairs.get((a, b), 0)
            ba = self.pvp_pairs.get((b, a), 0)
            hi, lo = (a, b) if ab >= ba else (b, a)
            pairs.append({"a": hi, "b": lo, "af": max(ab, ba), "bf": min(ab, ba),
                          "tot": ab + ba})
        pairs.sort(key=lambda r: (-r["tot"], r["a"]))
        self.duels = pairs
        self.rivalry = pairs[0] if pairs else None
        self.nemesis = None
        if self.mvp:
            cands = [(k[0], v) for k, v in self.pvp_pairs.items()
                     if k[1] == self.mvp["name"] and v > 0]
            if cands:
                who, n = max(cands, key=lambda x: x[1])
                self.nemesis = {"who": who, "n": n}

    # ---- timeline -------------------------------------------------------
    def _derive_timeline(self):
        """One merged, chronological narrative from all three telemetry families."""
        ev = []
        f = self.facts

        def add(t, kind, side, text, exact=True, detail=""):
            ev.append({"t": int(max(0, t)), "kind": kind, "side": side,
                       "text": text, "exact": exact, "detail": detail})

        if f and f.start:
            add(0, "START", "neu", "Match start — %s" % (f.start.get("world", self.map_name) or "unknown"),
                detail="build %s · %s town slots · %s player slots" % (
                    f.start.get("build", "?"), f.start.get("towns", "?"),
                    f.start.get("missionSlots", "?")))

        for m in (f.milestones if f else []):
            #--- MILESTONE times are minute-resolution (tMin); mark them as such so the
            #--- timeline never implies second-accuracy the emitter did not provide.
            add(m["t"], "MILESTONE", f.milestone_side(m), f.describe(m),
                exact=False, detail="minute resolution (tMin=%d)" % m["tmin"])

        for c in self.caps:
            verb = "captured" if c["old"] == "neu" else "taken from %s" % FACTION_LABEL.get(c["old"], "?")
            add(c["t"], "CAPTURE", c["new"],
                "%s %s by %s" % (c["town"], verb, FACTION_LABEL.get(c["new"], "?")),
                exact=c["exact"])

        for e in self.support_events:
            add(e["t"], "SUPPORT", "neu", e["label"], exact=e.get("exact", False))

        if f and f.end:
            add(self.duration, "END", self.winner,
                "%s wins" % FACTION_LABEL.get(self.winner, self.winner.upper()),
                detail="%s · final towns BLUFOR %d, OPFOR %d, GUER %d · %d players connected" % (
                    MatchData.fmt_duration(self.duration),
                    f.end.get("townsW", 0), f.end.get("townsE", 0), f.end.get("townsG", 0),
                    f.end.get("players", 0)))
        elif self.in_progress:
            add(self.duration, "LIVE", "neu", "Match still running — log ends here",
                detail="latest observed event; no result recorded yet")
        elif self.caps or self.kills:
            add(self.duration, "END", self.winner,
                "%s wins" % FACTION_LABEL.get(self.winner, self.winner.upper()),
                detail="no MATCH|v1|END line — winner taken from WASPSTAT ROUNDEND")

        ev.sort(key=lambda e: (e["t"], 0 if e["kind"] == "START" else
                               (9 if e["kind"] == "END" else 5)))
        self.timeline = ev

        #--- how the win landed, read off final ownership rather than asserted.
        held = self.final_town_counts()
        wt = held.get(self.winner, 0)
        rivals = [(s, n) for s, n in held.items() if s not in (self.winner, "neu") and n > 0]
        if self.in_progress:
            leader = max(held.items(), key=lambda kv: kv[1], default=("neu", 0))
            self.win_how = ("IN PROGRESS",
                            ("%s leads on towns %d–%d as of %s"
                             % (FACTION_LABEL.get(leader[0], "?"), leader[1],
                                max([n for s, n in held.items() if s != leader[0]] or [0]),
                                fmt_clock(self.duration)))
                            if leader[1] else "no side holds a town yet")
        elif wt > 0 and not rivals:
            self.win_how = ("SUPREMACY", "%d towns held — every rival wiped off the map" % wt)
        elif wt > 0:
            runner = max(rivals, key=lambda kv: kv[1])
            self.win_how = ("TERRITORY", "%d–%d on towns at the bell" % (wt, runner[1]))
        else:
            self.win_how = ("OBJECTIVE", "decided on base/objective, not the town count")

    # ---- coverage audit -------------------------------------------------
    def _derive_coverage(self):
        """What the log actually contained — so a thin report is never mistaken for a thin match."""
        gaps = 0
        if self.seqs:
            s = sorted(set(self.seqs))
            gaps = (s[-1] - s[0] + 1) - len(s)

        cap_exact = sum(1 for c in self.caps if c["exact"])
        kill_exact = sum(1 for k in self.kills if k["exact"])
        f = self.facts
        self.coverage = {
            "records": dict(self.record_counts),
            "match_family": dict(f.line_counts) if f else {},
            "seq_min": min(self.seqs) if self.seqs else None,
            "seq_max": max(self.seqs) if self.seqs else None,
            "seq_gaps": gaps,
            "cap_exact": cap_exact, "cap_total": len(self.caps),
            "kill_exact": kill_exact, "kill_total": len(self.kills),
            "dist_measured": self.dist_measured, "dist_total": len(self.kills),
            "unresolved_uids": self.unresolved_uids,
            "excluded_rows": len(self.excluded_players),
            "in_progress": self.in_progress,
            "has_start": bool(f and f.start),
            "has_end": bool(f and f.end),
            "towns_known": bool(TOWN_COORDS.get(self.map_name.lower())),
        }

        warns = []
        if self.in_progress:
            warns.append("Match still in progress: no ROUNDEND and no MATCH|v1|END in this log. "
                         "The clock runs to the latest observed event (%s), there is no winner, "
                         "and every total below is a snapshot that will keep moving."
                         % fmt_clock(self.duration))
        if not self.coverage["has_start"]:
            warns.append("No MATCH|v1|START line — match configuration (build, town/slot counts, "
                         "feature flags) is unknown. Check WFBE_C_MATCH_TELEMETRY and that the "
                         "log window starts before mission init.")
        if not self.coverage["has_end"] and not self.in_progress:
            warns.append("No MATCH|v1|END line — casualties, vehicles lost and the connected-player "
                         "count are unavailable, and the result is inferred from WASPSTAT ROUNDEND.")
        if self.caps and cap_exact < len(self.caps):
            warns.append("%d of %d captures carried no t= timestamp; their times are interpolated "
                         "evenly across the match and are ordering-accurate only."
                         % (len(self.caps) - cap_exact, len(self.caps)))
        if self.kills and kill_exact < len(self.kills):
            warns.append("%d of %d kills carried no t= timestamp; the tempo chart shows sequence "
                         "shape, not measured timing." % (len(self.kills) - kill_exact, len(self.kills)))
        if gaps:
            warns.append("%d gap(s) in the WASPSTAT sequence. Gaps are expected across a crash or a "
                         "trimmed log window and do not by themselves mean dropped records." % gaps)
        if self.unresolved_uids:
            warns.append("%d operator UID(s) had no display name and render as Op-XXXX. Supply a "
                         "UID<TAB>name file with --names to label them." % self.unresolved_uids)
        extended = sum(self.record_counts.get(rtype, 0) for rtype in WASPSTAT_EXTENDED_RECORDS)
        if extended:
            warns.append("%d CAMP/BUILDINGKILL record(s) are recognized but not included in event "
                         "tables; their counts remain visible in Telemetry coverage." % extended)
        unknown = self.record_counts.get("UNKNOWN", 0)
        if unknown:
            warns.append("%d WASPSTAT record(s) had an unrecognized type and were excluded from "
                         "the report." % unknown)
        if not self.coverage["towns_known"]:
            warns.append("No static town table for '%s'; only towns that changed hands appear, and "
                         "territory-seconds exclude towns that never flipped." % self.map_name)
        if self.ai_only:
            warns.append("No human operators in PLAYERSTATS — operator tables are empty and this "
                         "reads as an AI-only or unattended round.")
        self.warnings = warns


def parse_deep(lines, names=None):
    """Build a DeepMatch from raw RPT lines (WASPSTAT + MATCH families, one pass)."""
    names = names or {}
    lines = list(lines)
    dm = DeepMatch()
    dm.facts = parse_match_family(lines)

    caps_raw, kills_raw, support_raw, pstats = [], [], [], {}
    winner, duration, map_name = "neu", 0, ""

    for line_no, raw in enumerate(lines):
        raw = _dequote(raw)
        sup = _support_event(raw)
        if sup:
            support_raw.append((line_no, sup))
        i = raw.find(WASPSTAT_PREFIX)
        if i < 0:
            continue
        parts = raw[i:].strip().split("|")
        try:
            seq = int(parts[2])
        except (IndexError, ValueError):
            continue
        dm.seqs.append(seq)
        rtype = parts[3] if len(parts) > 3 else ""

        if rtype == "ROUNDEND":
            dm.record_counts["ROUNDEND"] += 1
            winner = side_from_str(parts[4] if len(parts) > 4 else "")
            try:
                duration = int(_clean(parts[5]))
            except (IndexError, ValueError):
                duration = 0
            map_name = _clean(parts[6]).lower() if len(parts) > 6 else ""
        elif rtype == "CAPTURE":
            dm.record_counts["CAPTURE"] += 1
            t = _time_token(parts[7:])
            caps_raw.append((seq, _clean(parts[4]), side_from_id(parts[5]),
                             side_from_id(parts[6]), t))
        elif rtype == "KILL":
            dm.record_counts["KILL"] += 1
            kuid = _clean(parts[4]) if len(parts) > 4 else ""
            vuid = _clean(parts[5]) if len(parts) > 5 else ""
            kside = side_from_str(parts[6]) if len(parts) > 6 else "neu"
            vside = side_from_str(parts[7]) if len(parts) > 7 else "neu"
            weap = parts[8] if len(parts) > 8 else "—"
            for p in parts[8:]:
                #--- hw= carries the real hand weapon; parts[8] is only the killer's vehicle class.
                if p.startswith("hw=") and len(p) > 3:
                    weap = p[3:]
                    break
            try:
                dist = int(parts[9])
            except (IndexError, ValueError):
                dist = -1
            cat = _clean(parts[10]) if len(parts) > 10 else "INF"
            kills_raw.append((seq, kuid, vuid, kside, vside, _pretty_weapon(weap),
                              cat, dist, _time_token(parts[8:])))
        elif rtype in WASPSTAT_EXTENDED_RECORDS:
            dm.record_counts[rtype] += 1
            if rtype == "CAMP":
                t = _time_token(parts[7:])
                if t is not None:
                    dm.auxiliary_times.append(t)
        elif _is_playerstats_token(rtype):
            dm.record_counts["PLAYERSTATS"] += 1
            for tok in parts[3:]:
                if ":" not in tok:
                    continue
                uid, fields = tok.split(":", 1)
                vals = fields.split(",")
                if len(vals) < 16:
                    continue
                side_raw, _, nm = vals[15].partition("~")
                nm = _clean(nm)
                try:
                    d = [int(x) for x in vals[:15]]
                    side = SIDE_FROM_PSTAT.get(int(_clean(side_raw)), "guer")
                except ValueError:
                    continue
                acc = pstats.setdefault(_clean(uid), {"d": [0] * 15, "side": side, "name": ""})
                acc["side"] = side
                if nm:
                    acc["name"] = nm
                for j in range(15):
                    acc["d"][j] += d[j]
        else:
            dm.record_counts["UNKNOWN"] += 1

    #--- identity: END wins, then ROUNDEND, then START.
    f = dm.facts
    dm.map_name = (f.world or map_name or "unknown").upper()
    dm.winner = winner
    dm.duration = duration
    if f and f.end:
        dm.duration = f.end.get("durationSec", 0) or duration
        dm.winner = f.winner or winner

    #--- A live match has no ROUNDEND and no MATCH|v1|END, because neither is written until the
    #--- victory FSM fires. Without a fallback the clock collapses to 1 s and every time-based
    #--- surface (momentum sampling, tempo bins, territory-seconds) degenerates. Fall back to the
    #--- latest event the log actually observed, and mark the report as in-progress so nothing
    #--- downstream presents a running match as a finished one.
    dm.in_progress = not (dm.record_counts.get("ROUNDEND") or (f and f.end))
    if dm.in_progress:
        observed = [t for t in
                    [r[4] for r in caps_raw] + [r[8] for r in kills_raw]
                    + [s["t"] for (_ln, s) in support_raw]
                    + dm.auxiliary_times
                    + [m["t"] for m in (f.milestones if f else [])]
                    if t is not None]
        dm.duration = max(observed) if observed else 0
        dm.winner = "neu"
    dm.duration = max(1, dm.duration)
    dm.world_size = WORLD_SIZE.get(dm.map_name.lower(), WORLD_SIZE["default"])

    #--- town set: the full static table for the terrain, plus anything that flipped.
    caps_raw.sort(key=lambda r: r[0])
    kills_raw.sort(key=lambda r: r[0])
    captured = []
    for (_s, town, _o, _n, _t) in caps_raw:
        if town not in captured:
            captured.append(town)
    dm.towns = list(TOWN_COORDS.get(dm.map_name.lower(), {}).keys()) or list(captured)
    for town in captured:
        if town not in dm.towns:
            dm.towns.append(town)

    init = dict((t, "neu") for t in dm.towns)
    seen = set()
    for (_s, town, old, _n, _t) in caps_raw:
        if town not in seen:
            init[town] = old
            seen.add(town)
    dm.init_owners = init

    def t_for(stored, idx, total):
        """Real emitted time when present, else an even spread that preserves order only."""
        if stored is not None:
            return stored
        return int((idx + 1) / (total + 1) * dm.duration)

    dm.caps = [{"t": t_for(ct, i, len(caps_raw)), "town": town, "old": old, "new": new,
                "exact": ct is not None}
               for i, (_s, town, old, new, ct) in enumerate(caps_raw)]

    allnames = dict(names)
    for uid, acc in pstats.items():
        if acc.get("name"):
            allnames[uid] = acc["name"]

    def disp(uid):
        if not uid:
            return None
        if uid in allnames:
            return allnames[uid]
        dm.unresolved_uids += 1
        return "Op-" + uid[-4:] if len(uid) >= 4 else uid

    resolved = {}

    def disp_cached(uid):
        if not uid:
            return None
        if uid not in resolved:
            resolved[uid] = disp(uid)
        return resolved[uid]

    dm.kills = [{"t": t_for(kt, i, len(kills_raw)), "killer": disp_cached(ku),
                 "victim": disp_cached(vu), "kside": ks, "vside": vs, "weapon": wp,
                 "cat": cat, "dist": dist, "exact": kt is not None}
                for i, (_s, ku, vu, ks, vs, wp, cat, dist, kt) in enumerate(kills_raw)]

    for k in dm.kills:
        if k["killer"] and k["victim"] and k["killer"] != k["victim"]:
            dm.pvp_pairs[(k["killer"], k["victim"])] += 1

    support_raw.sort(key=lambda r: (r[1]["t"] if r[1]["t"] is not None else dm.duration + r[0], r[0]))
    dm.support_events = [{"t": t_for(s["t"], i, len(support_raw)), "kind": s["kind"],
                          "label": s["label"], "exact": s["t"] is not None}
                         for i, (_ln, s) in enumerate(support_raw)]

    for uid, acc in pstats.items():
        nm = disp_cached(uid) or uid
        row = {"name": nm, "side": acc["side"], "d": acc["d"], "uid": uid}
        if is_excluded_name(nm):
            dm.excluded_players.append(row)
        else:
            dm.players.append(row)

    return dm.finalize()
