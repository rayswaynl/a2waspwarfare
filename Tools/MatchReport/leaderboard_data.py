"""
LeaderboardData — real server-leaderboard data from the live Postgres (ingame_stats).

Unlike a match, this is the cumulative server hall-of-fame: every operator's lifetime
kills (by category), PvP, town captures and score. Used by render.render_leaderboard().
This is the real data we actually store (the per-match event stream is not stored).
"""
import os
from collections import Counter

SIDE_FROM_PSTAT = {1: "west", 2: "east", 3: "guer", 0: "neu"}

def _db_url(env_path=r"C:\Users\Game\miksuus-warfare\web\.env.local"):
    url = os.environ.get("DATABASE_URL")
    if url: return url
    try:
        for ln in open(env_path, encoding="utf-8"):
            if ln.startswith("DATABASE_URL=") and "postgres" in ln:
                return ln.split("=", 1)[1].strip().strip('"')
    except OSError:
        pass
    return None

class LeaderboardData:
    def __init__(self):
        self.map_name = "SERVER"
        self.players = []          # [{name, side, kills, inf, veh, air, sta, pvp, caps, score}]
        self.total_kills = 0
        self.catcount = Counter()
        self.mvp = None
        self.n_players = 0

def load_leaderboard(url=None, min_score=1):
    """Pull ingame_stats from the live DB into a LeaderboardData."""
    import psycopg2
    url = url or _db_url()
    if not url: raise RuntimeError("No DATABASE_URL (set env or web/.env.local).")
    c = psycopg2.connect(url); cur = c.cursor()
    cur.execute("""select display_name, side, kills_infantry, kills_vehicle, kills_air,
                          kills_static, pvp_kills, captures_town, total_score
                   from ingame_stats order by total_score desc""")
    rows = cur.fetchall(); c.close()

    d = LeaderboardData()
    for i, r in enumerate(rows):
        name, side, inf, veh, air, sta, pvp, caps, score = r
        kills = (inf or 0) + (veh or 0) + (air or 0) + (sta or 0)
        if (score or 0) < min_score and kills == 0:   # drop empty rows
            continue
        d.players.append({
            "name": (name or f"Operator {i+1}"), "side": SIDE_FROM_PSTAT.get(side or 0, "neu"),
            "kills": kills, "inf": inf or 0, "veh": veh or 0, "air": air or 0, "sta": sta or 0,
            "pvp": pvp or 0, "caps": caps or 0, "score": score or 0,
        })
    d.players.sort(key=lambda p: -p["score"])
    d.n_players = len(d.players)
    for p in d.players:
        d.total_kills += p["kills"]
        d.catcount["INF"] += p["inf"]; d.catcount["VEH"] += p["veh"]
        d.catcount["AIR"] += p["air"]; d.catcount["STATIC"] += p["sta"]
    d.mvp = d.players[0] if d.players else None
    return d
