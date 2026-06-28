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
SIDE_NAME = {"west": "BLUFOR", "east": "OPFOR", "guer": "GUER", "neu": "NEUTRAL"}

def side_from_id(v):
    try: return SIDE_FROM_ID.get(int(v), "neu")
    except (TypeError, ValueError): return "neu"

def side_from_str(s):
    return SIDE_FROM_STR.get(str(s).strip().upper(), "neu")

def _pretty_weapon(w):
    """Tidy a weapon/unit class token from WASPSTAT KILL into a readable label."""
    if not w: return "—"
    w = w.split("=")[-1].strip()
    for pre in ("RU_","CDF_","GUE_","INS_","Ins_","US_","USMC_","GER_","RUS_"):
        if w.startswith(pre): w = w[len(pre):]; break
    return w.replace("_"," ").strip() or "—"

# ---- town coordinates (metres, map origin SW, y = north) -----------------
# These are STATIC per map. The values below are hand-approximated for Chernarus;
# they make the control map recognisable but are not survey-accurate. Production
# fix (tiny, mission-side): log each town's real getPos once at boot and load it
# here, which also yields Takistan for free. Towns with no entry are auto-placed
# on a ring by _autoplace() so an unknown/new map still renders.
WORLD_SIZE = {"chernarus": 15360, "takistan": 12800, "default": 15360}

TOWN_COORDS = {
 # Accurate Chernarus map positions (metres, 0..15360, y=north). Used until the boot
 # logger (WFBE_C_LOG_TOWN_COORDS) harvests the mission's exact getPos set.
 # EXACT Chernarus positions, boot-harvested from the live mission's town logics via the
 # WFBE_C_LOG_TOWN_COORDS logger (TOWNPOS|v1|... RPT lines, 46 towns incl. airfields/Khe Sanh).
 "chernarus": {
  "Balota":(4540,2285),"Berezino":(12125,9145),"Bor":(3334,3921),"Chernogorsk":(6833,2439),
  "Dolina":(11269,6593),"Dubrovka":(10492,9831),"Elektrozavodsk":(10280,1970),"Gorka":(9629,8866),
  "Grishino":(6076,10378),"Guglovo":(8414,6738),"Gvozdno":(8640,11946),"Kabanino":(5424,8616),
  "Kamenka":(1827,2261),"Kamyshovo":(11960,3523),"Khe Sanh Alpha":(14700,9400),"Khe Sanh Bravo":(10000,700),
  "Khe Sanh Charlie":(14700,2000),"Khelm":(12376,10878),"Komarovo":(3512,2485),"Krasnostav":(10984,12372),
  "Lopatino":(2787,9832),"Mogilevka":(7477,5203),"Msta":(11395,5510),"Myshkino":(1916,7439),
  "NEAF":(11850,12690),"NWAF":(4470,10615),"Nadezhdino":(5925,4727),"Nizhnoye":(12958,8095),
  "Novy Sobor":(7140,7758),"Olsha":(13386,12856),"Pavlovo":(1754,3925),"Petrovka":(4984,12593),
  "Polana":(10702,7983),"Prigorodki":(8118,3306),"Pulkovo":(4995,5595),"Pusta":(9110,3809),
  "Pustoshka":(3112,7947),"Rogovo":(4733,6767),"Shakhovka":(9735,6517),"Solnichniy":(13406,6178),
  "Staroye":(10062,5439),"Stary Sobor":(6222,7822),"Tulga":(12785,4473),"Vybor":(3724,8988),
  "Vyshnoye":(6532,6151),"Zelenogorsk":(2591,5437),
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
        self.seed = 0              # deterministic per-match variety seed (set in finalize)
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
        # every town on the map gets an owner entry (uncaptured -> neutral) so the control
        # map renders the FULL town set (all logics incl. airfields), not just towns that flipped.
        for t in self.towns: self.init_owners.setdefault(t, "neu")
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

        # --- engagement derivations (fleet plan): cold-open hero stat, player superlatives, comeback arc ---
        # superlatives: give up to 5 DIFFERENT players a punchy tag from their dominant stat -> "that's me".
        self.awards = {}
        lk_name = self.longest[1]
        if lk_name and self.longest[5] > 0: self.awards[lk_name] = "THE SNIPER"   # owns the longest kill
        for tag, fn in [("THE BUTCHER", lambda p: p["d"][0]),        # most infantry kills
                        ("ARMOR HUNTER", lambda p: p["d"][1]),       # most vehicle kills
                        ("ACE OF THE SKIES", lambda p: p["d"][2]),   # most air kills
                        ("TIP OF THE SPEAR", lambda p: p["d"][10])]: # most town captures
            if not self.players: break
            cand = max(self.players, key=fn)
            if fn(cand) > 0 and cand["name"] not in self.awards:
                self.awards[cand["name"]] = tag
        for p in self.players: p["award"] = self.awards.get(p["name"])
        kdp = [p for p in self.players if p["kills"] >= 3]
        self.kd_leader = max(kdp, key=lambda p: p["kd"]) if kdp else None

        # cold-open HERO stat: the most extreme REAL number (longest shot > top fragger > total kills).
        top = self.players[0] if self.players else None
        if self.longest[5] >= 600 and lk_name:
            self.hero = {"label": "LONGEST SHOT", "num": int(self.longest[5]), "suffix": "M", "who": lk_name}
        elif top and top["kills"] >= 25:
            self.hero = {"label": "TOP FRAGGER", "num": int(top["kills"]), "suffix": " KILLS", "who": top["name"]}
        else:
            self.hero = {"label": "TOTAL KILLS", "num": int(self.total_kills), "suffix": "", "who": None}

        # comeback / lead-change arc from the momentum series (kills the old hardcoded, sometimes-lying subtitle).
        wsign = 1 if self.winner == "west" else (-1 if self.winner == "east" else 0)
        diff = [w - e for w, e in zip(self.ser_w, self.ser_e)]
        fw, fe = (self.ser_w[-1], self.ser_e[-1]) if diff else (0, 0)
        self.comeback = {"line": f"{SIDE_NAME.get(self.winner, self.winner.upper())} TOOK THE FIELD"}
        if wsign and diff:
            worst = min(d * wsign for d in diff)                    # most negative = furthest the winner was behind
            changes = sum(1 for a, b in zip(diff, diff[1:]) if (a > 0) != (b > 0) and a and b)
            if worst <= -3:   self.comeback = {"badge": "COMEBACK", "line": f"DOWN {abs(worst)} TOWNS — WON {max(fw,fe)}–{min(fw,fe)}"}
            elif changes >= 3: self.comeback = {"badge": "SEE-SAW", "line": f"{changes} LEAD CHANGES — WON {max(fw,fe)}–{min(fw,fe)}"}
            else:              self.comeback = {"line": f"WON {max(fw,fe)}–{min(fw,fe)} — NEVER TRAILED"}

        # deterministic per-match variety seed — drives backdrop/silhouette/music/hook
        # rotation so a feed of many reports never looks or sounds identical.
        import hashlib
        _key = f"{self.map_name}|{self.winner}|{self.duration}|{self.total_kills}|{self.mvp['name'] if self.mvp else ''}"
        self.seed = int(hashlib.sha1(_key.encode()).hexdigest()[:8], 16)
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
        elif rtype == "KILL":
            # KILL|killerUID|victimUID|killerSide|victimSide|killerClass|dist|cat|hw=<weapon>|vc=<victimClass>
            killer_uid = parts[4] if len(parts) > 4 else ""
            kside = side_from_str(parts[6]) if len(parts) > 6 else "neu"
            cat = parts[10] if len(parts) > 10 else "INF"
            try: dist = int(parts[9])
            except (IndexError, ValueError): dist = 0
            weap = parts[8] if len(parts) > 8 else "—"        # killer class; prefer real hand weapon
            for p in parts[8:]:
                if p.startswith("hw=") and len(p) > 3: weap = p[3:]; break
            kills_raw.append((seq, None, kside, _pretty_weapon(weap), cat, dist, killer_uid))
        else:
            # PLAYERSTATS: tokens "uid:d0,...,d14,side~name" joined by '|' from parts[3:].
            # the trailing "~name" is the live display name (added by the leaderboard emitter).
            for tok in parts[3:]:
                if ":" not in tok: continue
                uid, fields = tok.split(":", 1)
                vals = fields.split(",")
                if len(vals) < 16: continue
                side_raw, _, nm = vals[15].partition("~")
                try: d = [int(x) for x in vals[:15]]; side = SIDE_FROM_PSTAT.get(int(side_raw), "guer")
                except ValueError: continue
                acc = pstats.setdefault(uid, {"d": [0]*15, "side": side, "name": ""})
                acc["side"] = side
                if nm: acc["name"] = nm
                for j in range(15): acc["d"][j] += d[j]

    m = MatchData()
    m.winner = winner; m.duration = duration or 1; m.map_name = map_name.upper()

    # towns + coords — plot the FULL map (every known town logic), not only captured towns,
    # so airfields and quiet towns still appear. Falls back to captured names on an unknown map.
    town_names = []
    for (_, town, _o, _n) in caps_raw:
        if town not in town_names: town_names.append(town)
    all_names = list(TOWN_COORDS.get(map_name.lower(), {}).keys()) or town_names
    for town in town_names:
        if town not in all_names: all_names.append(town)
    m.towns, m.world_size = coords_for(map_name, all_names)

    # initial owners: oldSide of a town's first capture; else neutral
    init = {t: "neu" for t in town_names}
    seen = set()
    for (_, town, old, _n) in caps_raw:
        if town not in seen: init[town] = old; seen.add(town)
    m.init_owners = init

    # assign times to seq-ordered events (ingest times if provided, else spread)
    caps_raw.sort(key=lambda r: r[0]); kills_raw.sort(key=lambda r: r[0])
    def t_for(seq, idx, total):
        if line_times and seq in line_times: return line_times[seq]
        return int((idx + 1) / (total + 1) * m.duration)
    m.caps  = [(t_for(s, i, len(caps_raw)),  town, new) for i, (s, town, _o, new) in enumerate(caps_raw)]
    # resolve display names: WASPSTAT now embeds them (~name); fall back to a passed map, then Op-XXXX.
    allnames = dict(names)
    for uid, acc in pstats.items():
        if acc.get("name"): allnames[uid] = acc["name"]
    def _disp(uid): return allnames.get(uid) or ("Op-" + uid[-4:] if len(uid) >= 4 else uid)

    m.kills = [(t_for(s, i, len(kills_raw)), (_disp(u) if u else None), ks, wp, cat, dist)
               for i, (s, _nm, ks, wp, cat, dist, u) in enumerate(kills_raw)]

    # players (skip headless-client connections — they carry UIDs + stats but aren't operators)
    _HC = {"HC","HC1","HC2","HC3","HC4","HEADLESS","HEADLESSCLIENT","SERVER"}
    for uid, acc in pstats.items():
        nm = _disp(uid)
        if nm.strip().upper() in _HC: continue
        m.players.append({"name": nm, "side": acc["side"], "d": acc["d"]})

    return m.finalize()
