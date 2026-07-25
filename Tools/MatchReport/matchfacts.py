"""
MatchFacts — parser for the `MATCH|v1|` telemetry family.

The `MATCH|v1|` family is a *parallel, independent* prefix to `WASPSTAT|v1|`: it does
not share the `WFBE_WASPSTAT_SEQ` counter and it is gated separately on
`WFBE_C_MATCH_TELEMETRY`. See `docs/WASPSTAT-FORMAT.md` ("MATCH family").

The video pipeline (`matchdata.parse_waspstat`) ignores this family entirely, so the
match-identity line (`START`), the authoritative match-facts summary (`END`) and the
narrative beats (`MILESTONE`) were previously unreadable by any report. This module is
the missing boundary, and it is deliberately **stdlib-only** so the in-depth report can
run on a bare server box with no numpy/Pillow install.

Wire shapes (verified against the emitters, 2026-07-25):

    MATCH|v1|START|world=..|build=..|towns=..|missionSlots=..|aiEnabled=..|delegation=..
                   |statlog=..|guer=..|naval=..|oilfield=..
    MATCH|v1|END|winner=..|durationSec=..|world=..|townsW=..|townsE=..|townsG=..
                 |casW=..|casE=..|vehLostW=..|vehLostE=..|players=..|totalTowns=..
    MATCH|v1|MILESTONE|FIRST_TOWN|side=..|town=..|tMin=..
    MATCH|v1|MILESTONE|HQ_DESTROYED|side=..|tMin=..
    MATCH|v1|MILESTONE|OILFIELD_CAP|owner=..|tMin=..
    MATCH|v1|MILESTONE|CARRIER_CAP|carrier=..|newSideID=..|tMin=..

Every value arrives from `str`/`diag_log`, so numbers are strings, booleans may be
`true`/`false` or `1`/`0`, and the whole line carries a `"..."` wrapper. Parsing is
lenient by design: an unknown milestone subtype or an added key is retained verbatim
rather than dropped, so a mission-side field addition never silently disappears from
the report.
"""
from matchdata import _clean, _dequote, side_from_id, side_from_str

MATCH_PREFIX = "MATCH|v1|"

#--- Milestone subtypes we render with a purpose-built sentence. Anything else still
#--- lands in the timeline via its raw key=value pairs.
KNOWN_MILESTONES = ("FIRST_TOWN", "HQ_DESTROYED", "OILFIELD_CAP", "CARRIER_CAP")

#--- START/END fields that are logically numeric. Kept as an explicit list rather than
#--- "try int() on everything" so a build tag like "build89" is never coerced.
_NUMERIC_KEYS = {
    "towns", "missionSlots", "durationSec", "townsW", "townsE", "townsG",
    "casW", "casE", "vehLostW", "vehLostE", "players", "totalTowns",
    "tMin", "newSideID",
}
#--- Fields the mission writes with `str` on a value that may be a Boolean or a 0/1 number.
_FLAG_KEYS = {"aiEnabled", "statlog", "guer", "naval", "oilfield", "delegation"}


def _as_int(v, default=0):
    try:
        return int(float(_clean(v)))
    except (TypeError, ValueError):
        return default


def _as_flag(v):
    """Normalise an SQF-stringified flag to an int, tolerating true/false and 1/0."""
    s = _clean(v).lower()
    if s in ("true", "yes"):
        return 1
    if s in ("false", "no", ""):
        return 0
    return _as_int(s, 0)


def _kv(parts):
    """Parse `key=value` tokens into a dict, coercing the known numeric/flag keys."""
    out = {}
    for tok in parts:
        if "=" not in tok:
            continue
        k, _, v = tok.partition("=")
        k = _clean(k)
        v = _clean(v)
        if k in _NUMERIC_KEYS:
            out[k] = _as_int(v)
        elif k in _FLAG_KEYS:
            out[k] = _as_flag(v)
        else:
            out[k] = v
    return out


class MatchFacts(object):
    """Everything the `MATCH|v1|` family carries about one match.

    All attributes are always present. `start`/`end` are `None` when the match ran with
    `WFBE_C_MATCH_TELEMETRY = 0`, when the log window was cut before the boot line, or
    when the server died before the victory FSM ran — the in-depth report reports that
    absence rather than inventing values.
    """

    def __init__(self):
        self.start = None          # dict | None
        self.end = None            # dict | None
        self.milestones = []       # list[dict] with keys: kind, tmin, t, fields
        self.line_counts = {"START": 0, "END": 0, "MILESTONE": 0, "UNKNOWN": 0}

    # ---- convenience accessors (never raise on a missing family) ----
    @property
    def world(self):
        for src in (self.end, self.start):
            if src and src.get("world"):
                return _clean(src["world"]).lower()
        return ""

    @property
    def build(self):
        return (self.start or {}).get("build", "")

    @property
    def winner(self):
        if self.end and self.end.get("winner"):
            return side_from_str(self.end["winner"])
        return None

    @property
    def duration(self):
        return (self.end or {}).get("durationSec", 0)

    def final_towns(self):
        """{side: towns held at ROUNDEND} from END, or {} when END is absent."""
        if not self.end:
            return {}
        return {"west": self.end.get("townsW", 0),
                "east": self.end.get("townsE", 0),
                "guer": self.end.get("townsG", 0)}

    def casualties(self):
        """{side: casualties} — the mission only tracks WEST/EAST counters."""
        if not self.end:
            return {}
        return {"west": self.end.get("casW", 0), "east": self.end.get("casE", 0)}

    def vehicles_lost(self):
        if not self.end:
            return {}
        return {"west": self.end.get("vehLostW", 0), "east": self.end.get("vehLostE", 0)}

    def milestones_of(self, kind):
        return [m for m in self.milestones if m["kind"] == kind]

    def describe(self, m):
        """A one-line human sentence for a milestone, used by the timeline."""
        f = m["fields"]
        kind = m["kind"]
        if kind == "FIRST_TOWN":
            return "%s took its first town — %s" % (
                side_from_str(f.get("side", "")).upper(), f.get("town", "unknown"))
        if kind == "HQ_DESTROYED":
            return "%s HQ destroyed" % side_from_str(f.get("side", "")).upper()
        if kind == "OILFIELD_CAP":
            return "Oilfield taken by %s" % side_from_str(f.get("owner", "")).upper()
        if kind == "CARRIER_CAP":
            return "Carrier %s taken by %s" % (
                f.get("carrier", "unknown"),
                side_from_id(f.get("newSideID", 4)).upper())
        # unknown subtype: surface it verbatim so new mission telemetry is never silent
        rest = " ".join("%s=%s" % (k, v) for k, v in f.items() if k != "tMin")
        return ("%s %s" % (kind, rest)).strip()

    def milestone_side(self, m):
        """Faction a milestone belongs to, for timeline colouring ('neu' if none)."""
        f = m["fields"]
        if m["kind"] == "HQ_DESTROYED":
            return "neu"   # the *victim's* side — never paint it as that side's win
        for key in ("side", "owner"):
            if key in f:
                return side_from_str(f[key])
        if "newSideID" in f:
            return side_from_id(f["newSideID"])
        return "neu"


def parse_match_family(lines):
    """Build a MatchFacts from any iterable of raw RPT lines.

    Non-MATCH lines are ignored, so the same RPT stream can be handed to this and to the
    WASPSTAT parser without pre-filtering.
    """
    facts = MatchFacts()
    for raw in lines:
        raw = _dequote(raw)
        i = raw.find(MATCH_PREFIX)
        if i < 0:
            continue
        parts = raw[i:].strip().split("|")
        subtype = _clean(parts[2]) if len(parts) > 2 else ""

        if subtype == "START":
            facts.line_counts["START"] += 1
            facts.start = _kv(parts[3:])
        elif subtype == "END":
            facts.line_counts["END"] += 1
            facts.end = _kv(parts[3:])
        elif subtype == "MILESTONE":
            facts.line_counts["MILESTONE"] += 1
            kind = _clean(parts[3]) if len(parts) > 3 else ""
            fields = _kv(parts[4:])
            tmin = fields.get("tMin", 0)
            facts.milestones.append(
                {"kind": kind, "tmin": tmin, "t": tmin * 60, "fields": fields})
        else:
            facts.line_counts["UNKNOWN"] += 1

    #--- tMin is minute-resolution, so many beats collide on one value; a stable sort keeps
    #--- emission order inside a minute instead of shuffling the narrative.
    facts.milestones.sort(key=lambda m: m["tmin"])
    return facts
