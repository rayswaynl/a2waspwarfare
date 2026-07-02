"""
MatchData — the single input boundary for the post-match report renderer.

Everything the renderer (render.py) draws is read off a MatchData instance, so
there is exactly one place that data enters the system. Two producers exist:

  * sample_match.build_sample()  -> a realistic placeholder match (offline demo)
  * parse_waspstat(lines, ...)   -> a real match parsed from WASPSTAT telemetry

Both return a finalized MatchData. See docs reference: a2waspwarfare
docs/WASPSTAT-FORMAT.md (PLAYERSTATS d0..d14, KILL, CAPTURE, ROUNDEND).
"""
import re
from collections import Counter

# ---- side handling -------------------------------------------------------
# CAPTURE uses numeric side IDs; KILL/ROUNDEND use string side names. Normalise
# everything to the short keys the renderer uses.
SIDE_FROM_ID  = {0: "west", 1: "east", 2: "guer", 4: "neu"}
SIDE_FROM_STR = {"WEST": "west", "EAST": "east", "RESISTANCE": "guer", "GUER": "guer", "CIV": "neu"}
# PLAYERSTATS trailing side field: 1=WEST, 2=EAST, 0=other.
SIDE_FROM_PSTAT = {1: "west", 2: "east", 0: "guer"}
SIDE_NAME = {"west": "BLUFOR", "east": "OPFOR", "guer": "GUER", "neu": "NEUTRAL"}

def side_from_id(v):
    try: return SIDE_FROM_ID.get(int(v), "neu")
    except (TypeError, ValueError): return "neu"

def side_from_str(s):
    return SIDE_FROM_STR.get(_clean(s).upper(), "neu")

# ---- raw-line hygiene ----------------------------------------------------
# The emitter writes each WASPSTAT record through diag_log, which wraps the whole
# line in double quotes: '"WASPSTAT|v1|...|chernarus"'. Left unstripped, the last
# field carries a trailing '"' (map became 'chernarus"'), and embedded ~"name"
# tokens carry their own quotes. _dequote peels the outer diag_log wrapper;
# _clean strips stray quotes/whitespace off any single field or token.
def _dequote(raw):
    """Strip the diag_log '"..."' wrapper (and trailing CR) from a raw RPT line."""
    s = raw.rstrip("\r\n")
    st = s.lstrip()
    if st.startswith('"') and st.rstrip().endswith('"'):
        st = st.strip()
        return st[1:-1]
    return s

def _clean(s):
    """Trim whitespace and surrounding double quotes from a token/field."""
    return str(s).strip().strip('"').strip()

# ---- headless-client / AI-controller exclusion ---------------------------
# HCs and AI commanders appear in PLAYERSTATS (they carry a UID + a stat row) but
# they are NOT operators — they must never surface as MVP, in a top-list, or in a
# kill table. Two shapes seen live: legacy "HC"/"HEADLESS"/"SERVER" tokens, and the
# AI commander display names "HC-AI-Control-1" / "AI-Control-2". Match generously.
_HC_EXACT = {"HC","HC1","HC2","HC3","HC4","HEADLESS","HEADLESSCLIENT","SERVER"}
def is_excluded_name(nm):
    """True if nm is a headless client / AI controller (exclude from all human lists)."""
    if not nm: return True
    u = _clean(nm).upper()
    if u in _HC_EXACT: return True
    if u.startswith("HC-") or u.startswith("HC "): return True
    if "AI-CONTROL" in u or "AI-COMMANDER" in u or "AICOM" in u: return True
    return False

def _pretty_weapon(w):
    """Tidy a weapon/unit class token from WASPSTAT KILL into a readable label."""
    if not w: return "—"
    w = w.split("=")[-1].strip()
    for pre in ("RU_","CDF_","GUE_","INS_","Ins_","US_","USMC_","GER_","RUS_"):
        if w.startswith(pre): w = w[len(pre):]; break
    return w.replace("_"," ").strip() or "—"

def _time_token(toks):
    """Extract a real match-time from a 't=<sec>' token if the emitter logged one (else None)."""
    for p in toks:
        if p.startswith("t="):
            try: return int(p[2:])
            except ValueError: return None
    return None

_SUPPORT_TIME_RE = re.compile(r"(?:^|[|,\s])t=(\d+)(?:$|[|,\s])", re.IGNORECASE)
_TEL_RE = re.compile(r"\bTEL\b|ICBMTEL", re.IGNORECASE)

def _support_event(raw):
    """Return a compact SCUD/TEL support-event marker parsed from a raw RPT line."""
    up = raw.upper()
    has_scud = "SCUD" in up
    has_tel = bool(_TEL_RE.search(up))
    if not (has_scud or has_tel):
        return None
    if any(token in up for token in ("TELEMETRY", "SATELLITE")) and not has_scud:
        return None

    if has_scud and has_tel: kind = "SCUD/TEL"
    elif has_scud: kind = "SCUD"
    else: kind = "TEL"

    action = "event"
    for needle, label in (("LAUNCH", "launch"), ("FIRED", "fired"), ("STRIKE", "strike"),
                          ("DESTROY", "destroyed"), ("KILLED", "destroyed"),
                          ("SPAWN", "spawned"), ("READY", "ready"), ("CANCEL", "cancelled")):
        if needle in up:
            action = label
            break
    mt = _SUPPORT_TIME_RE.search(raw)
    return {"t": int(mt.group(1)) if mt else None, "kind": kind, "label": f"{kind} {action}"}

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
 # EXACT Takistan positions (metres, 0..12800, y=north), harvested read-only from the mission's
 # town logics (vehicle="LocationLogicDepot") in Missions_Vanilla/[61-2hc]...takistan/mission.sqm.
 # Keyed by the marker `text=` name — the same token WASPSTAT CAPTURE lines emit — so captured
 # towns join by name and the full static set (incl. the two airfields) renders on the control map.
 "takistan": {
  "Anar":(5361,4533),"Bastam":(9809,11193),"ChakChak":(1862,1842),"Chaman":(11647,2547),
  "Chardarakht":(9129,1997),"Falar":(8762,5185),"FeeruzAbad":(6138,5368),"Garmarud":(5933,7123),
  "Garmsar":(8954,6896),"Gospandi":(8385,7607),"HazarBagh":(10526,2357),"Huzrutimam":(4201,529),
  "Imarat":(10690,6319),"Jaza":(6739,1967),"Jilavur":(3548,4167),"Kakaru":(1945,7510),
  "Karachinar":(11564,8575),"Khushab":(2740,5190),"Landay":(5857,961),"Loy Manara AF":(4177,11451),
  "LoyManara":(2227,479),"Mulladoost":(1443,5492),"Nagara":(5605,8923),"Nur":(12245,10663),
  "Rasman":(2853,9929),"Rasman AF":(8191,1960),"Ravanay":(3476,8356),"Sakhee":(1277,3354),
  "Shamali":(6115,10951),"Shukurkalay":(732,2949),"Sultansafee":(8355,2229),"Timurkalay":(4983,6052),
  "Zavarak":(1960,11749),
 },
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
        self.support_events = []   # {t, kind, label} SCUD/TEL support-event markers
        self.total_kills = 0
        self.ai_only = False       # no human operators -> AI-only match (no phantom MVP)

    @staticmethod
    def fmt_duration(sec):
        """Human match length: '6h56m', '48m', '2h00m'. Never the raw 416:08 minutes bug."""
        sec = int(max(0, sec)); h, rem = divmod(sec, 3600); mm, _ = divmod(rem, 60)
        if h: return f"{h}h{mm:02d}m"
        if mm: return f"{mm}m{sec%60:02d}s" if sec < 600 else f"{mm}m"
        return f"{sec}s"

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
        # per-player derived. Drop HC / AI-controller phantoms AND zero-activity ghosts
        # (a player with no kills, no caps, no deaths, no score contributes nothing and must
        # never be featured as MVP). This is the fix for MVP="HC-AI-Control-1".
        clean = []
        for p in self.players:
            d = p["d"]
            p["kills"] = d[0]+d[1]+d[2]+d[3]
            p["score"] = self.score(d, p["kills"])
            p["kd"]    = p["kills"] / max(1, d[6])
            if is_excluded_name(p["name"]): continue
            if p["kills"] == 0 and p["d"][10] == 0 and p["d"][6] == 0 and p["score"] == 0:
                continue                                            # 0-activity phantom
            clean.append(p)
        self.players = clean
        self.players.sort(key=lambda p: -p["score"])
        self.mvp = self.players[0] if self.players else None
        self.ai_only = not self.players                            # no human operators survived

        # kill aggregates (kills carry the KILLER side; None name = AI/anonymous)
        self.catcount  = Counter(k[4] for k in self.kills)
        self.weapcount = Counter(k[3] for k in self.kills)
        self.topweap   = self.weapcount.most_common(1)[0] if self.weapcount else ("—", 0)
        self.longest   = max(self.kills, key=lambda k: k[5]) if self.kills else (0, None, "west", "—", "INF", 0)
        if not self.total_kills:
            self.total_kills = len(self.kills)
        # HONEST kill accounting: total_kills counts ALL forces (incl. AI-vs-AI). Also expose a
        # per-side split so GUER (which can top the kill charts yet win nothing) is never invisible.
        self.kills_by_side = Counter(k[2] for k in self.kills)     # {"west":n,"east":n,"guer":n,...}
        self.pvp_total = sum(p["d"][7] for p in self.players)
        self.cap_total = len(self.caps)
        if self.mvp:
            c = Counter(k[3] for k in self.kills if k[1] == self.mvp["name"])
            self.mvp["fav"] = c.most_common(1)[0][0] if c else "—"
        self.support_events = sorted(getattr(self, "support_events", []), key=lambda e: e.get("t", 0))
        self.support_total = len(self.support_events)
        self.support_counts = Counter(e.get("kind", "SUPPORT") for e in self.support_events)

        # decisive capture = first cap after which the winner reaches its peak town count
        self.decisive = self.caps[-1] if self.caps else (self.duration, "—", self.winner)
        best = -1
        for (t, town, s) in self.caps:
            w = sum(v == self.winner for v in self.owners_at(t).values())
            if w > best:
                best = w; self.decisive = (t, town, s)

        # momentum series (towns held over time) — now tracks all THREE factions incl. GUER,
        # which is a real capturing side in this mission and was previously dropped from the chart.
        step = max(20, self.duration // 64)
        xs = list(range(0, self.duration + 1, step))
        self.ser_x = xs
        _own = [self.owners_at(t) for t in xs]
        self.ser_w = [sum(v == "west" for v in o.values()) for o in _own]
        self.ser_e = [sum(v == "east" for v in o.values()) for o in _own]
        self.ser_g = [sum(v == "guer" for v in o.values()) for o in _own]
        # did GUER ever hold enough ground to be worth drawing? (drives render toggle)
        self.guer_active = any(g > 0 for g in self.ser_g) or self.kills_by_side.get("guer", 0) > 0

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

        # hardware destroyed (vehicles + aircraft, from KILL category) — concrete kill-porn.
        self.hw_veh = self.catcount.get("VEH", 0); self.hw_air = self.catcount.get("AIR", 0)
        self.hq_kills = self.catcount.get("HQ", 0)

        # --- WINNER: how did they win? supremacy (last side standing on the town map) vs a raw
        # town-count edge vs base destruction. We only have CAPTURE + ROUNDEND, so infer from the
        # final ownership: if the loser holds 0 towns at ROUNDEND it reads as SUPREMACY/base-wipe;
        # otherwise it was decided on the town count. ---
        fo = self.owners_at(self.duration)
        held = Counter(fo.values())
        wt = held.get(self.winner, 0)
        others = sum(v for k, v in held.items() if k not in (self.winner, "neu"))
        if others == 0 and wt > 0:
            self.win_how = {"mode": "SUPREMACY", "text": f"held {wt} towns — enemy wiped off the map"}
        elif wt > 0:
            runner = max(((k, v) for k, v in held.items() if k not in (self.winner, "neu")),
                         key=lambda kv: kv[1], default=(None, 0))
            self.win_how = {"mode": "TERRITORY", "text": f"{wt}–{runner[1]} on towns at the bell"}
        else:
            self.win_how = {"mode": "OBJECTIVE", "text": "won on objective / base"}

        # --- AI-ONLY match fallback: no human MVP, so feature the fiercest fighting side and the
        # fiercest single flashpoint instead of an empty/phantom card. ---
        self.top_side = None; self.fiercest = None
        if self.kills:
            ks = self.kills_by_side
            engaged = [(s, n) for s, n in ks.items() if s in ("west", "east", "guer") and n > 0]
            if engaged:
                s, n = max(engaged, key=lambda x: x[1])
                self.top_side = {"side": s, "kills": n}
            # fiercest battle = the town whose (re)capture had the most kills in the ±win window
            if self.caps and self.kills:
                win = max(60, self.duration // 40); best = None
                for (t, town, s) in self.caps:
                    n = sum(1 for k in self.kills if abs(k[0] - t) <= win)
                    if best is None or n > best[0]: best = (n, town, t, s)
                if best: self.fiercest = {"town": best[1], "kills": best[0], "t": best[2], "side": best[3]}
        # rivalry (top head-to-head) + nemesis (who killed the MVP most) from player-vs-player kills.
        self.rivalry = None; self.nemesis = None
        pp = getattr(self, "pvp_pairs", None)
        if pp:
            seen = set(); best = None
            for (a, b) in list(pp):
                key = tuple(sorted((a, b)))
                if key in seen: continue
                seen.add(key)
                ab = pp.get((a, b), 0); ba = pp.get((b, a), 0); tot = ab + ba
                if tot > 0 and (best is None or tot > best["tot"]):
                    best = ({"a": a, "b": b, "af": ab, "bf": ba, "tot": tot} if ab >= ba
                            else {"a": b, "b": a, "af": ba, "bf": ab, "tot": tot})
            self.rivalry = best
            if self.mvp:
                cands = [(k[0], v) for k, v in pp.items() if k[1] == self.mvp["name"] and v > 0]
                if cands:
                    who, nn = max(cands, key=lambda x: x[1]); self.nemesis = {"who": who, "n": nn}

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
    caps_raw, kills_raw, support_raw, pstats = [], [], [], {}
    winner, duration, map_name = "west", 0, "chernarus"

    for line_no, raw in enumerate(lines):
        # Peel the diag_log '"..."' wrapper FIRST so the final field (map name) and any embedded
        # name tokens don't carry stray quotes. Without this, map parsed as 'chernarus"'.
        raw = _dequote(raw)
        support = _support_event(raw)
        if support:
            support_raw.append((line_no, support["t"], support["kind"], support["label"]))
        i = raw.find("WASPSTAT|v1|")
        if i < 0: continue
        parts = raw[i:].strip().split("|")
        # parts: WASPSTAT, v1, seq, <type-or-pstat>, ...
        try: seq = int(parts[2])
        except (IndexError, ValueError): continue
        rtype = parts[3] if len(parts) > 3 else ""

        if rtype == "ROUNDEND":
            winner = side_from_str(parts[4])
            try: duration = int(_clean(parts[5]))
            except (IndexError, ValueError): duration = 0
            map_name = _clean(parts[6]).lower()
        elif rtype == "CAPTURE":
            caps_raw.append((seq, _clean(parts[4]), side_from_id(parts[5]), side_from_id(parts[6]), _time_token(parts[7:])))
        elif rtype == "KILL":
            # KILL|killerUID|victimUID|killerSide|victimSide|killerClass|dist|cat|hw=<weapon>|vc=<victimClass>[|t=<sec>]
            killer_uid = parts[4] if len(parts) > 4 else ""
            victim_uid = parts[5] if len(parts) > 5 else ""
            kside = side_from_str(parts[6]) if len(parts) > 6 else "neu"
            cat = parts[10] if len(parts) > 10 else "INF"
            try: dist = int(parts[9])
            except (IndexError, ValueError): dist = 0
            weap = parts[8] if len(parts) > 8 else "—"        # killer class; prefer real hand weapon
            for p in parts[8:]:
                if p.startswith("hw=") and len(p) > 3: weap = p[3:]; break
            kills_raw.append((seq, None, kside, _pretty_weapon(weap), cat, dist, killer_uid, victim_uid, _time_token(parts[8:])))
        else:
            # PLAYERSTATS: tokens "uid:d0,...,d14,side~name" joined by '|' from parts[3:].
            # the trailing "~name" is the live display name (added by the leaderboard emitter).
            for tok in parts[3:]:
                if ":" not in tok: continue
                uid, fields = tok.split(":", 1)
                vals = fields.split(",")
                if len(vals) < 16: continue
                side_raw, _, nm = vals[15].partition("~")
                nm = _clean(nm)                                   # strip quotes off the ~"name" token
                try: d = [int(x) for x in vals[:15]]; side = SIDE_FROM_PSTAT.get(int(_clean(side_raw)), "guer")
                except ValueError: continue
                acc = pstats.setdefault(_clean(uid), {"d": [0]*15, "side": side, "name": ""})
                acc["side"] = side
                if nm: acc["name"] = nm
                for j in range(15): acc["d"][j] += d[j]

    m = MatchData()
    m.winner = winner; m.duration = duration or 1; m.map_name = map_name.upper()

    # towns + coords — plot the FULL map (every known town logic), not only captured towns,
    # so airfields and quiet towns still appear. Falls back to captured names on an unknown map.
    town_names = []
    for (_, town, _o, _n, _ct) in caps_raw:
        if town not in town_names: town_names.append(town)
    all_names = list(TOWN_COORDS.get(map_name.lower(), {}).keys()) or town_names
    for town in town_names:
        if town not in all_names: all_names.append(town)
    m.towns, m.world_size = coords_for(map_name, all_names)

    # initial owners: oldSide of a town's first capture; else neutral
    init = {t: "neu" for t in town_names}
    seen = set()
    for (_, town, old, _n, _ct) in caps_raw:
        if town not in seen: init[town] = old; seen.add(town)
    m.init_owners = init

    # assign times to seq-ordered events (ingest times if provided, else spread)
    caps_raw.sort(key=lambda r: r[0]); kills_raw.sort(key=lambda r: r[0])
    def t_for(stored, seq, idx, total):
        # prefer the REAL emitted time (t= token), then a passed line_times map, else even spread.
        if stored is not None: return stored
        if line_times and seq in line_times: return line_times[seq]
        return int((idx + 1) / (total + 1) * m.duration)
    m.caps  = [(t_for(ct, s, i, len(caps_raw)), town, new) for i, (s, town, _o, new, ct) in enumerate(caps_raw)]
    support_raw.sort(key=lambda r: (r[1] if r[1] is not None else m.duration + r[0], r[0]))
    m.support_events = [{"t": t_for(st, line_no, i, len(support_raw)), "kind": kind, "label": label}
                        for i, (line_no, st, kind, label) in enumerate(support_raw)]
    # resolve display names: WASPSTAT now embeds them (~name); fall back to a passed map, then Op-XXXX.
    allnames = dict(names)
    for uid, acc in pstats.items():
        if acc.get("name"): allnames[uid] = acc["name"]
    def _disp(uid): return allnames.get(uid) or ("Op-" + uid[-4:] if len(uid) >= 4 else uid)

    m.kills = [(t_for(kt, s, i, len(kills_raw)), (_disp(u) if u else None), ks, wp, cat, dist)
               for i, (s, _nm, ks, wp, cat, dist, u, vu, kt) in enumerate(kills_raw)]

    # rivalries / nemesis foundation: count player-vs-player kills (both UIDs present, distinct).
    pvp = Counter()
    for (s, _nm, ks, wp, cat, dist, u, vu, kt) in kills_raw:
        if u and vu and u != vu: pvp[(_disp(u), _disp(vu))] += 1
    m.pvp_pairs = pvp

    # players (skip headless clients / AI controllers — they carry UIDs + stats but aren't
    # operators). finalize() also drops any that slip through + 0-activity ghosts.
    for uid, acc in pstats.items():
        nm = _disp(uid)
        if is_excluded_name(nm): continue
        m.players.append({"name": nm, "side": acc["side"], "d": acc["d"]})

    return m.finalize()
