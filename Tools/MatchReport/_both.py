import os, numpy as np
from matchdata import MatchData, coords_for, TOWN_COORDS
from render import render, climax_frame
from render_report import add_sound
from sample_match import build_sample

def build_alt():
    rng=np.random.default_rng(29); m=MatchData()
    m.map_name,m.world_size,m.duration,m.winner="CHERNARUS",15360,2210,"east"
    m.towns,m.world_size=coords_for("chernarus",list(TOWN_COORDS["chernarus"].keys()))
    init={}
    for t in ["Kamenka","Komarovo","Balota","Pavlovo","Myshkino"]: init[t]="west"
    for t in ["Berezino","Krasnostav","Dubrovka","Solnichniy","Olsha","Nizhnoye"]: init[t]="east"
    m.init_owners=init
    m.caps=[(160,"Chernogorsk","east"),(250,"Elektrozavodsk","east"),(360,"Zelenogorsk","west"),
            (470,"Mogilevka","east"),(600,"Stary Sobor","east"),(720,"Vybor","west"),
            (860,"Novy Sobor","east"),(1010,"Pustoshka","east"),(1180,"Grishino","east"),
            (1330,"Vyshnoye","east"),(1500,"Kabanino","east"),(1680,"NWAF","east"),
            (1890,"Rogovo","east"),(2090,"Lopatino","east")]
    NW=["Ghost","Hawk","Reaper","Doc","Crash"]; NE=["Volk","Krait","Tsar","Grom","Boris","Yuri","Pavel"]
    def mk(name,side,tier):
        inf=int(rng.integers(8,40)*tier);veh=int(rng.integers(0,9)*tier);air=int(rng.integers(0,3)*tier)
        sta=int(rng.integers(0,4)*tier);deaths=int(rng.integers(3,16));pvp=int(rng.integers(0,inf//2+1))
        caps=int(rng.integers(0,6)*tier);supply=int(rng.integers(0,5));supval=supply*int(rng.integers(800,2200))
        built=int(rng.integers(0,7));defs=int(rng.integers(0,9));play=int(rng.integers(1400,m.duration))
        return {"name":name,"side":side,"d":[inf,veh,air,sta,0,0,deaths,pvp,supply,supval,caps,0,built,defs,play]}
    for i,n in enumerate(NW): m.players.append(mk(n,"west",1.2 if i<2 else 1.0))
    for i,n in enumerate(NE): m.players.append(mk(n,"east",1.85 if i<3 else 1.1))
    WP={"west":[("M16A2","INF"),("M249 SAW","INF"),("M107 .50","INF"),("M1A1 Abrams","VEH"),("AH-1Z","AIR"),("Mk19 GMG","STATIC")],
        "east":[("AK-74","INF"),("PKM","INF"),("SVD Dragunov","INF"),("RPG-7V","VEH"),("T-72","VEH"),("Mi-24 Hind","AIR")]}
    def dist(cat,wp):
        if any(s in wp for s in ("SVD",".50","M107")): return int(rng.integers(380,1450))
        lo,hi={"INF":(25,330),"VEH":(40,820),"AIR":(120,1500),"STATIC":(90,650)}[cat]; return int(rng.integers(lo,hi))
    kills=[]
    for p in m.players:
        pk=p["d"][0]+p["d"][1]+p["d"][2]+p["d"][3]; pool=WP[p["side"]]
        for _ in range(pk):
            wp,cat=pool[int(rng.integers(0,len(pool)))]; kills.append((int(rng.integers(20,m.duration)),p["name"],p["side"],wp,cat,dist(cat,wp)))
    m.total_kills=986
    while len(kills)<m.total_kills:
        s="east" if rng.random()<0.55 else "west"; pool=WP[s]; wp,cat=pool[int(rng.integers(0,len(pool)))]
        kills.append((int(rng.integers(20,m.duration)),None,s,wp,cat,dist(cat,wp)))
    kills.sort(key=lambda k:k[0]); m.kills=kills
    return m.finalize()

sb=r"C:\Users\Game\AppData\Local\Temp\claude\C--\cbd8c07e-5184-4e09-aaae-8c5e6a2e7c64\scratchpad"
for name,m in [("blufor",build_sample()),("opfor",build_alt())]:
    out=os.path.join(sb, "report_"+name+"_music.mp4")
    n=render(m,out); add_sound(out,n,climax_frame(),seed=m.seed,winner=m.winner)
    print(name+": winner="+m.winner+" mvp="+m.mvp['name']+" seed="+str(m.seed)+" size="+str(os.path.getsize(out)))
