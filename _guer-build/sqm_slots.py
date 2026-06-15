import re, sys
P = r"Missions/[55-2hc]warfarev2_073v48co.chernarus/mission.sqm"
txt = open(P, encoding="utf-8", errors="replace").read()

# Iterate every group "class ItemN { ... }" in the Groups container; a player slot is a group whose
# inner unit has player="PLAY CDG". Extract side + vehicle + description + id + the group Item number.
slots = []
for gm in re.finditer(r'\bclass (Item\d+)\s*\{(.*?)\n\t\t\};', txt, re.S):  # 2-tab group close
    name, body = gm.group(1), gm.group(2)
    if 'player="PLAY CDG"' not in body:
        continue
    side = (re.search(r'side="(WEST|EAST|RESISTANCE|CIV)"', body) or [None, "?"])[1]
    veh  = (re.search(r'vehicle="([^"]+)"', body) or [None, "?"])[1]
    gid  = (re.search(r'id=(\d+)', body) or [None, "?"])[1]
    desc = (re.search(r'description="([^"]*)"', body) or [None, ""])[1]
    fhc  = 'forceHeadlessClient' in body
    slots.append((side, name, gid, veh, desc, fhc))

from collections import Counter
for s in ["WEST", "EAST", "RESISTANCE", "CIV"]:
    ss = [u for u in slots if u[0] == s]
    print(f"=== {s}: {len(ss)} player-slot groups ===")
    vc = Counter(u[3] for u in ss if not u[5])
    for veh, n in vc.most_common():
        print(f"   {n:>2}x {veh}")
    hc = [u for u in ss if u[5]]
    if hc:
        print(f"   [{len(hc)} forceHeadlessClient]")
print(f"TOTAL player-slot groups: {len(slots)}")
