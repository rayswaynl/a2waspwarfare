"""
build_sample() -> a realistic placeholder MatchData for the offline demo.

Hand-built in the same shapes the real WASPSTAT parser produces, so the renderer
cannot tell sample data from live data. Deterministic (fixed RNG seed).
"""
import numpy as np
from collections import Counter
from matchdata import MatchData, coords_for, TOWN_COORDS

def build_sample():
    rng = np.random.default_rng(11)
    m = MatchData()
    m.map_name, m.world_size, m.duration, m.winner = "CHERNARUS", 15360, 2600, "west"

    # plot ALL Chernarus towns (boot-harvested set incl. airfields/Khe Sanh), not just the
    # ones that flip below — uncaptured towns render neutral via finalize().
    m.towns, m.world_size = coords_for("chernarus", list(TOWN_COORDS["chernarus"].keys()))

    init = {}
    for t in ["Komarovo","Kamenka","Pavlovo","Zelenogorsk"]: init[t] = "west"
    for t in ["Berezino","Krasnostav","Dubrovka","Solnichniy"]: init[t] = "east"
    m.init_owners = init

    m.caps = [(180,"Pustoshka","west"),(240,"Elektrozavodsk","east"),(360,"Vybor","west"),
        (455,"Msta","east"),(540,"Mogilevka","west"),(610,"Polana","east"),(720,"Chernogorsk","west"),
        (815,"Gvozdno","east"),(905,"Vyshnoye","west"),(1010,"Grishino","east"),(1140,"Stary Sobor","west"),
        (1230,"Msta","west"),(1325,"Novy Sobor","west"),(1450,"Polana","west"),(1560,"Elektrozavodsk","west"),
        (1700,"Grishino","west"),(1840,"Gvozdno","west"),(1980,"Solnichniy","west"),(2120,"Berezino","west"),
        (2300,"Dubrovka","west"),(2480,"Krasnostav","west")]

    NAMES_W = ["Ghost","Viper","Hawk-7","Reaper","Maverick","Tonka","Sledge","Doc","Crash","Wolfe"]
    NAMES_E = ["Boris","Krait","Volk","Spetz","Tsar","Grom","Pavel","Iron","Yuri","Zveno"]
    def mk(name, side, tier):
        inf=int(rng.integers(8,40)*tier); veh=int(rng.integers(0,9)*tier); air=int(rng.integers(0,3)*tier)
        sta=int(rng.integers(0,4)*tier); deaths=int(rng.integers(3,16)); pvp=int(rng.integers(0,inf//2+1))
        caps=int(rng.integers(0,6)*tier); supply=int(rng.integers(0,5)); supval=supply*int(rng.integers(800,2200))
        built=int(rng.integers(0,7)); defs=int(rng.integers(0,9)); play=int(rng.integers(1600,m.duration))
        return {"name":name,"side":side,"d":[inf,veh,air,sta,0,0,deaths,pvp,supply,supval,caps,0,built,defs,play]}
    for i,n in enumerate(NAMES_W): m.players.append(mk(n,"west",1.6 if i<3 else 1.0))
    for i,n in enumerate(NAMES_E): m.players.append(mk(n,"east",1.5 if i<3 else 1.0))

    # kills -> aggregates (WASPSTAT KILL shape: weapon/category/distance)
    WPOOL={"west":[("M16A2","INF"),("M4 Aimpoint","INF"),("M249 SAW","INF"),("M240","INF"),("M107 .50","INF"),
                   ("M1A1 Abrams","VEH"),("HMMWV M2","VEH"),("AH-1Z","AIR"),("UH-1Y","AIR"),("Mk19 GMG","STATIC")],
           "east":[("AK-74","INF"),("RPK-74","INF"),("PKM","INF"),("SVD Dragunov","INF"),("RPG-7V","VEH"),
                   ("T-72","VEH"),("BMP-2","VEH"),("Mi-24 Hind","AIR"),("KORD HMG","STATIC"),("Igla","AIR")]}
    def dist(cat, wp):
        if any(s in wp for s in ("SVD",".50","M107")): return int(rng.integers(380,1450))
        lo,hi={"INF":(25,330),"VEH":(40,820),"AIR":(120,1500),"STATIC":(90,650)}[cat]; return int(rng.integers(lo,hi))
    kills=[]
    for p in m.players:
        pk=p["d"][0]+p["d"][1]+p["d"][2]+p["d"][3]; pool=WPOOL[p["side"]]
        for _ in range(pk):
            wp,cat=pool[int(rng.integers(0,len(pool)))]
            kills.append((int(rng.integers(20,m.duration)), p["name"], p["side"], wp, cat, dist(cat,wp)))
    m.total_kills = 1147
    while len(kills) < m.total_kills:
        s="west" if rng.random()<0.5 else "east"; pool=WPOOL[s]; wp,cat=pool[int(rng.integers(0,len(pool)))]
        kills.append((int(rng.integers(20,m.duration)), None, s, wp, cat, dist(cat,wp)))
    kills.sort(key=lambda k: k[0])
    m.kills = kills
    return m.finalize()
