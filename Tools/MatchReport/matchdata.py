"""
MatchData — the single input boundary for the post-match report renderer.

Everything the renderer (render.py) draws is read off a MatchData instance, so
there is exactly one place that data enters the system. Two producers exist:

  * sample_match.build_sample()  -> a realistic placeholder match (offline demo)
  * parse_waspstat(lines, ...)   -> a real match parsed from WASPSTAT telemetry

Both return a finalized MatchData. See docs reference: a2waspwarfare
docs/WASPSTAT-FORMAT.md (PLAYERSTATS d0..d14, KILL, CAPTURE, ROUNDEND).
"""
from collections import Counter

# ---- side handling -------------------------------------------------------
# CAPTURE uses numeric side IDs; KILL/ROUNDEND use string side names. Normalise
# everything to the short keys the renderer uses.
SIDE_FROM_ID  = {0: "west", 1: "east", 2: "guer", 4: "neu"}
SIDE_FROM_STR = {"WEST": "west", "EAST": "east", "RESISTANCE": "guer", "CIV": "neu"}
# PLAYERSTATS trailing side field: 1=WEST, 2=EAST, 0=other.
SIDE_FROM_PSTAT = {1: "west", 2: "east", 0: "guer"}

def side_from_id(v):
    try: return SIDE_FROM_ID.get(int(v), "neu")
    except (TypeError, ValueError): return "neu"

def side_from_str(s):
    return SIDE_FROM_STR.get(str(s).strip().upper(), "neu")

# ---- town coordinates (metres, map origin SW, y = north) -----------------
# These are STATIC per map. The values below are hand-approximated for Chernarus;
# they make the control map recognisable but are not survey-accurate. Production
# fix (tiny, mission-side): log each town's real getPos once at boot and load it
# here, which also yields Takistan for free. Towns with no entry are auto-placed
# on a ring by _autoplace() so an unknown/new map still renders.
WORLD_SIZE = {"chernarus": 15360, "takistan": 12800, "default": 15360}

TOWN_COORDS = {
 "chernarus": {  # real engine coords, harvested via the #116 town logger (cmdcon6 boot, worldName=chernarus)
  "Petrovka":(4984,12593),"Solnichniy":(13406,6178),"Pulkovo":(4995,5595),"Stary Sobor":(6222,7822),
  "Kabanino":(5424,8616),"Dubrovka":(10492,9831),"Olsha":(13386,12856),"Khe Sanh Charlie":(14700,2000),
  "Chernogorsk":(6833,2439),"Kamyshovo":(11960,3523),"Lopatino":(2787,9832),"Gvozdno":(8640,11946),
  "Khelm":(12376,10878),"Zelenogorsk":(2591,5437),"Bor":(3334,3921),"Pavlovo":(1754,3925),
  "Pusta":(9110,3809),"Tulga":(12785,4473),"Shakhovka":(9735,6517),"Guglovo":(8414,6738),
  "Vyshnoye":(6532,6151),"Kamenka":(1827,2261),"Khe Sanh Bravo":(10000,700),"NEAF":(11850,12690),
  "Nizhnoye":(12958,8095),"Myshkino":(1916,7439),"Vybor":(3724,8988),"Grishino":(6076,10378),
  "Polana":(10702,7983),"Khe Sanh Alpha":(14700,9400),"Balota":(4540,2285),"NWAF":(4470,10615),
  "Rogovo":(4733,6767),"Krasnostav":(10984,12372),"Berezino":(12125,9145),"Gorka":(9629,8866),
  "Prigorodki":(8118,3306),"Elektrozavodsk":(10280,1970),"Staroye":(10062,5439),"Msta":(11395,5510),
  "Mogilevka":(7477,5203),"Novy Sobor":(7140,7758),"Komarovo":(3512,2485),"Nadezhdino":(5925,4727),
  "Dolina":(11269,6593),"Pustoshka":(3112,7947),
 },
 "takistan": {},   # TODO: fill from the boot-time town-position logger.
}

def coords_for(map_name, town_names):
    """Return {town: (x,y)} for the given map, auto-placing any unknown towns."""
    mp = TOWN_COORDS.get(map_name.lower(), {})
    size = WORLD_SIZE.get(map_name.lower(), WORLD_SIZE["default"])
    out, missing = {}, []
    for t in town_names:
        if t in mp: out[t] = mp[t]
        else: missing.append(t)
    out.update(_autoplace(missing, size, len(out)))
    return out, size

def _autoplace(names, size, offset):
    import math
    res = {}; n = max(1, len(names) + offset)
    for i, t in enumerate(names):
        a = 2 * math.pi * (i + offset) / n
        res[t] = (size*0.5 + size*0.33*math.cos(a), size*0.5 + size*0.33*math.sin(a))
    return res


class MatchData:
    def __init__(self):
        self.map_name = "CHERNARUS"
        self.world_size = 15360
        self.duration = 0
        self.winner = "west"
        self.towns = {}            # name -> (x,y)
        self.init_owners = {}      # name -> side
        self.caps = []             # (t_sec, town, new_side)  ordered
        self.players = []          # {name, side, d[15], kills, score, kd, fav}
        self.kills = []            # (t_sec, name_or_None, side, weapon, cat, dist)
        self.total_kills = 0

    # town ownership at match time ts (seconds)
    def owners_at(self, ts):
        o = dict(self.init_owners)
        for (t, town, s) in self.caps:
            if t <= ts and town in o: o[town] = s
        return o

    @staticmethod
    def score(d, kills):
        # composite match score (kills, pvp, captures, vehicles/air, supply, builds)
        return kills*10 + d[7]*8 + d[10]*40 + d[1]*6 + d[2]*15 + d[9]//100 + d[12]*5

    def finalize(self):
        # per-player derived
        for p in self.players:
            d = p["d"]
            p["kills"] = d[0]+d[1]+d[2]+d[3]
            p["score"] = self.score(d, p["kills"])
            p["kd"]    = p["kills"] / max(1, d[6])
        self.players.sort(key=lambda p: -p["score"])
        self.mvp = self.players[0] if self.players else None

        # kill aggregates
        self.catcount  = Counter(k[4] for k in self.kills)
        self.weapcount = Counter(k[3] for k in self.kills)
        self.topweap   = self.weapcount.most_common(1)[0] if self.weapcount else ("—", 0)
        self.longest   = max(self.kills, key=lambda k: k[5]) if self.kills else (0, None, "west", "—", "INF", 0)
        if not self.total_kills:
            self.total_kills = len(self.kills)
        self.pvp_total = sum(p["d"][7] for p in self.players)
        self.cap_total = len(self.caps)
        if self.mvp:
            c = Counter(k[3] for k in self.kills if k[1] == self.mvp["name"])
            self.mvp["fav"] = c.most_common(1)[0][0] if c else "—"

        # decisive capture = first cap after which the winner reaches its peak town count
        self.decisive = self.caps[-1] if self.caps else (self.duration, "—", self.winner)
        best = -1
        for (t, town, s) in self.caps:
            w = sum(v == self.winner for v in self.owners_at(t).values())
            if w > best:
                best = w; self.decisive = (t, town, s)

        # momentum series (towns held over time)
        step = max(20, self.duration // 64)
        xs = list(range(0, self.duration + 1, step))
        self.ser_x = xs
        self.ser_w = [sum(v == "west" for v in self.owners_at(t).values()) for t in xs]
        self.ser_e = [sum(v == "east" for v in self.owners_at(t).values()) for t in xs]

        # control-map grid (nearest-town index per cell) — precomputed once
        import numpy as np
        self.tnames = list(self.towns)
        tpos = [self.towns[t] for t in self.tnames]
        GC = 44; self.grid_n = GC
        near = np.zeros((GC, GC), int); S = self.world_size
        for r in range(GC):
            for c in range(GC):
                gx = (c+0.5)/GC*S; gy = (1-(r+0.5)/GC)*S
                near[r, c] = int(np.argmin([(gx-px)**2+(gy-py)**2 for px, py in tpos])) if tpos else 0
        self.nearest = near
        return self


# ============================ WASPSTAT parser ============================
def parse_waspstat(lines, names=None, line_times=None):
    """
    Build a MatchData from raw WASPSTAT telemetry lines (see WASPSTAT-FORMAT.md).

    lines      : iterable of strings, each containing a "WASPSTAT|v1|..." record.
    names      : optional {uid: display_name} (PLAYERSTATS carries UID, not name —
                 in production names join from the players table). Falls back to
                 "Op-<last4>".
    line_times : optional {seq: t_seconds}. WASPSTAT CAPTURE/KILL lines do NOT
                 carry a match-time today, so if this is not supplied we spread
                 events evenly across [0, duration] by sequence order. See README
                 "Known gap: event timestamps".
    """
    names = names or {}
    caps_raw, kills_raw, pstats = [], [], {}
    winner, duration, map_name = "west", 0, "chernarus"
    # Real per-event match-time (seconds), keyed by seq, parsed from the "t=" token
    # the server now appends to CAPTURE/KILL WASPSTAT lines. Merged onto any caller
    # -supplied line_times below so the timeline is true, not evenly spread.
    event_times = {}

    def _t_token(toks):
        for tok in toks:
            if tok.startswith("t="):
                try: return int(tok[2:])
                except ValueError: return None
        return None

    for raw in lines:
        i = raw.find("WASPSTAT|v1|")
        if i < 0: continue
        parts = raw[i:].strip().split("|")
        # parts: WASPSTAT, v1, seq, <type-or-pstat>, ...
        try: seq = int(parts[2])
        except (IndexError, ValueError): continue
        rtype = parts[3] if len(parts) > 3 else ""

        if rtype == "ROUNDEND":
            winner = side_from_str(parts[4]); duration = int(parts[5]); map_name = parts[6].lower()
        elif rtype == "CAPTURE":
            caps_raw.append((seq, parts[4], side_from_id(parts[5]), side_from_id(parts[6])))
            _tt = _t_token(parts[7:])
            if _tt is not None: event_times[seq] = _tt
        elif rtype == "KILL":
            killer_uid, victim_uid = parts[4], parts[5]
            kside = side_from_str(parts[6]); weap = parts[8]; dist = int(parts[9]); cat = parts[10]
            nm = names.get(killer_uid) if killer_uid else None
            kills_raw.append((seq, nm, kside, weap, cat, dist, killer_uid))
            _tt = _t_token(parts[11:])
            if _tt is not None: event_times[seq] = _tt
        else:
            # PLAYERSTATS: tokens "uid:d0,...,d14,side" joined by '|' from parts[3:]
            for tok in parts[3:]:
                if ":" not in tok: continue
                uid, fields = tok.split(":", 1)
                vals = fields.split(",")
                if len(vals) < 16: continue
                d = [int(x) for x in vals[:15]]; side = SIDE_FROM_PSTAT.get(int(vals[15]), "guer")
                acc = pstats.setdefault(uid, {"d": [0]*15, "side": side})
                acc["side"] = side
                for j in range(15): acc["d"][j] += d[j]

    m = MatchData()
    m.winner = winner; m.duration = duration or 1; m.map_name = map_name.upper()

    # towns + coords
    town_names = []
    for (_, town, _o, _n) in caps_raw:
        if town not in town_names: town_names.append(town)
    m.towns, m.world_size = coords_for(map_name, town_names)

    # initial owners: oldSide of a town's first capture; else neutral
    init = {t: "neu" for t in town_names}
    seen = set()
    for (_, town, old, _n) in caps_raw:
        if town not in seen: init[town] = old; seen.add(town)
    m.init_owners = init

    # assign times to seq-ordered events (ingest times if provided, else spread)
    caps_raw.sort(key=lambda r: r[0]); kills_raw.sort(key=lambda r: r[0])
    def t_for(seq, idx, total):
        # Prefer the real match-time the server logged ("t=" token), then any
        # caller-supplied line_times, and only as a last resort spread evenly.
        if seq in event_times: return event_times[seq]
        if line_times and seq in line_times: return line_times[seq]
        return int((idx + 1) / (total + 1) * m.duration)
    m.caps  = [(t_for(s, i, len(caps_raw)),  town, new) for i, (s, town, _o, new) in enumerate(caps_raw)]
    m.kills = [(t_for(s, i, len(kills_raw)), nm, ks, wp, cat, dist)
               for i, (s, nm, ks, wp, cat, dist, _u) in enumerate(kills_raw)]

    # players
    for uid, acc in pstats.items():
        nm = names.get(uid) or ("Op-" + uid[-4:] if len(uid) >= 4 else uid)
        m.players.append({"name": nm, "side": acc["side"], "d": acc["d"]})

    return m.finalize()
