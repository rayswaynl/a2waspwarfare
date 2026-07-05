"""
build_sample(profile) -> a realistic placeholder MatchData for the offline demo.

Three match profiles (0 stomp / 1 comeback / 2 see-saw marathon), built in the same
shapes the real WASPSTAT parser produces, so the renderer cannot tell sample data
from live data. Deterministic per profile (fixed RNG seeds). Kill totals, hardware
losses and pacing are tuned to look like actual WASP rounds, not a stat explosion.
"""
import numpy as np
from collections import Counter
from matchdata import MatchData, coords_for, TOWN_COORDS

PROFILES = [
    # short evening round, BLUFOR never trails
    {"rng": 11, "winner": "west", "duration": 3120,  "kills": 430,  "arc": "steady",
     "mvp_side": "west"},
    # long night round, OPFOR digs out of a hole
    {"rng": 23, "winner": "east", "duration": 6060,  "kills": 780,  "arc": "comeback",
     "mvp_side": "east"},
    # weekend marathon, lead changes all night
    {"rng": 37, "winner": "west", "duration": 8220,  "kills": 1030, "arc": "seesaw",
     "mvp_side": "west"},
]

NAMES_W = ["Ghost","Viper","Hawk-7","Reaper","Maverick","Tonka","Sledge","Doc","Crash","Wolfe"]
NAMES_E = ["Boris","Krait","Volk","Spetz","Tsar","Grom","Pavel","Iron","Yuri","Zveno"]

# central towns that actually change hands in a typical round
FLIP_TOWNS = ["Pustoshka","Elektrozavodsk","Vybor","Msta","Mogilevka","Polana","Chernogorsk",
              "Gvozdno","Vyshnoye","Grishino","Stary Sobor","Novy Sobor","Staroye","Shakhovka",
              "Guglovo","Rogovo","Pulkovo","Kabanino","Dolina","Solnichniy"]

# weapon pools per category (weapon label, side) — cat chosen by weight first, so the
# infantry/vehicle/air split looks like a real round (~3/4 infantry fighting).
CAT_W = [("INF", 0.74), ("VEH", 0.14), ("AIR", 0.07), ("STATIC", 0.05)]
WPOOL = {
 "west": {"INF": ["M16A2","M4 Aimpoint","M249 SAW","M240","M107 .50"],
          "VEH": ["M1A1 Abrams","M2A2 Bradley","HMMWV M2","LAV-25"],
          "AIR": ["AH-1Z","A-10","UH-1Y"], "STATIC": ["Mk19 GMG","M2 static"]},
 "east": {"INF": ["AK-74","RPK-74","PKM","SVD Dragunov"],
          "VEH": ["T-72","BMP-2","RPG-7V","BTR-90"],
          "AIR": ["Mi-24 Hind","Ka-52","Igla"], "STATIC": ["KORD HMG","ZU-23"]},
}

# victim motor pools for the hardware tally (class, weight) — what each side realistically
# loses; weights favour the workhorses, marquee air assets stay in believable single digits.
VPOOL = {
 "east": [("T72_RU",8),("T90",2),("BMP3",4),("BMP2",5),("BTR90",4),("Mi24_V",4),
          ("Mi17_rockets_RU",3),("Su34",1),("Su25_RU",2),("Ka52",1),("ZSU_23_4",2),
          ("GRAD_RU",1),("Ural_supply",5),("UAZ_MG",4),("GAZ_Vodnik_HMG",2)],
 "west": [("M1A1",6),("M2A2_Bradley",5),("LAV25",3),("AAV",2),("HMMWV_M2",6),
          ("AH1Z",3),("UH1Y",3),("UH60M_EP1",2),("MV22",1),("A10",2),("F35B",1),
          ("MLRS",1),("MTVR_supply",4),("AH6J_EP1",1)],
}


def _caps_for(rng, arc, winner, duration):
    """Scripted capture timeline shaped by the match arc; towns can re-flip."""
    loser = "east" if winner == "west" else "west"
    n = min(int(len(FLIP_TOWNS) * 1.8), 14 + duration // 400)
    towns = list(FLIP_TOWNS); rng.shuffle(towns)
    cur = {}                                                    # tracked owner of flipped towns
    caps = []
    for i in range(n):
        f = (i + 1) / (n + 1)                                   # 0..1 through the match
        if arc == "steady":     p_win = 0.85
        elif arc == "comeback": p_win = 0.12 if f < 0.55 else 0.92
        else:                   p_win = 0.12 if ((i // 3) % 2 and f < 0.80) else 0.88
        if i >= n - 3: p_win = 1.0                              # the winner closes the match out
        side = winner if rng.random() < p_win else loser
        other = loser if side == winner else winner
        # capturing an ENEMY town swings the lead — prefer it (that's what a push looks like)
        enemy = [t for t in towns if cur.get(t) == other]
        fresh = [t for t in towns if t not in cur]
        if enemy and (not fresh or rng.random() < 0.75):
            town = enemy[int(rng.integers(0, len(enemy)))]
        elif fresh:
            town = fresh[int(rng.integers(0, len(fresh)))]
        else:
            town = towns[int(rng.integers(0, len(towns)))]
        cur[town] = side
        t = int(f * duration + rng.integers(-90, 90))
        caps.append((max(60, min(duration - 60, t)), town, side))
    caps.sort(key=lambda c: c[0])
    return caps


def build_sample(profile=0):
    p = PROFILES[profile % len(PROFILES)]
    rng = np.random.default_rng(p["rng"])
    m = MatchData()
    m.map_name, m.world_size = "CHERNARUS", 15360
    m.duration, m.winner = p["duration"], p["winner"]
    m.towns, m.world_size = coords_for("chernarus", list(TOWN_COORDS["chernarus"].keys()))

    init = {}
    for t in ["Komarovo","Kamenka","Pavlovo","Zelenogorsk"]: init[t] = "west"
    for t in ["Berezino","Krasnostav","Dubrovka","Nizhnoye"]: init[t] = "east"
    m.init_owners = init
    m.caps = _caps_for(rng, p["arc"], p["winner"], p["duration"])

    # players — MVP tier on the winning (or profile-chosen) side, realistic k/d spreads
    def mk(name, side, tier):
        inf = int(rng.integers(4, 22) * tier); veh = int(rng.integers(0, 5) * tier)
        air = int(rng.integers(0, 3) * (tier if side == p["mvp_side"] else 1))
        sta = int(rng.integers(0, 3)); deaths = int(rng.integers(2, 13))
        pvp = int(rng.integers(0, max(2, inf // 3))); caps = int(rng.integers(0, 5) * tier)
        supply = int(rng.integers(0, 5)); supval = supply * int(rng.integers(800, 2200))
        built = int(rng.integers(0, 7)); defs = int(rng.integers(0, 9))
        play = int(rng.integers(int(m.duration * 0.55), m.duration))
        return {"name": name, "side": side,
                "d": [inf, veh, air, sta, 0, 0, deaths, pvp, supply, supval, caps, 0, built, defs, play]}
    off = profile * 3                                   # rotate rosters so the MVP differs per clip
    for i, n in enumerate(NAMES_W[off:] + NAMES_W[:off]):
        m.players.append(mk(n, "west", (1.7 if i < 3 else 1.0) * (1.15 if p["mvp_side"] == "west" else 0.9)))
    for i, n in enumerate(NAMES_E[off:] + NAMES_E[:off]):
        m.players.append(mk(n, "east", (1.7 if i < 3 else 1.0) * (1.15 if p["mvp_side"] == "east" else 0.9)))

    # kill stream: category by weight, weapon from the side pool, distances by class
    def draw_kill(t, name, side):
        r = rng.random(); acc = 0.0; cat = "INF"
        for c, w in CAT_W:
            acc += w
            if r < acc: cat = c; break
        wp = WPOOL[side][cat][int(rng.integers(0, len(WPOOL[side][cat])))]
        if any(s in wp for s in ("SVD", ".50", "M107")): dist = int(rng.integers(380, 1450))
        else:
            lo, hi = {"INF": (25, 330), "VEH": (40, 820), "AIR": (120, 1500), "STATIC": (90, 650)}[cat]
            dist = int(rng.integers(lo, hi))
        return (t, name, side, wp, cat, dist)

    kills = []
    for pl in m.players:
        pk = pl["d"][0] + pl["d"][1] + pl["d"][2] + pl["d"][3]
        for _ in range(pk):
            kills.append(draw_kill(int(rng.integers(20, m.duration)), pl["name"], pl["side"]))
    m.total_kills = p["kills"]
    while len(kills) < m.total_kills:
        s = "west" if rng.random() < 0.5 else "east"
        kills.append(draw_kill(int(rng.integers(20, m.duration)), None, s))
    kills.sort(key=lambda k: k[0])
    m.kills = kills[:m.total_kills]

    # hardware-loss tally (real matches: KILL vc= victim class) — victim from the
    # OPPOSITE side's motor pool
    for k in m.kills:
        if k[4] not in ("VEH", "AIR"): continue
        vside = "east" if k[2] == "west" else "west"
        pool = VPOOL[vside]; tot = sum(w for _, w in pool); r = int(rng.integers(0, tot))
        for cls, w in pool:
            if r < w: m.vloss_raw.append((cls, vside)); break
            r -= w

    # player-vs-player grudges: pair top fraggers across sides
    ws = sorted((pl for pl in m.players if pl["side"] == "west"), key=lambda q: -q["d"][7])
    es = sorted((pl for pl in m.players if pl["side"] == "east"), key=lambda q: -q["d"][7])
    m.pvp_pairs = Counter()
    for a, b in zip(ws[:3], es[:3]):
        x, y = int(rng.integers(2, 7)), int(rng.integers(1, 5))
        m.pvp_pairs[(a["name"], b["name"])] += x; m.pvp_pairs[(b["name"], a["name"])] += y
    return m.finalize()
