import re
P = r"Missions/[55-2hc]warfarev2_073v48co.chernarus/mission.sqm"
txt = open(P, encoding="utf-8", errors="replace").read()

# Role-balanced keep-counts per (side, vehicle) -> 14/side (Eng4/Med3/Sol3/Sup2/Sniper2).
KEEP = {
    ("WEST","USMC_Soldier_TL"):4, ("WEST","FR_Corpsman"):3, ("WEST","FR_Miles"):3,
    ("WEST","FR_TL"):2, ("WEST","USMC_SoldierS_Sniper"):2,
    ("EAST","Ins_Soldier_CO"):4, ("EAST","RUS_Soldier_Medic"):3, ("EAST","RUS_Soldier1"):3,
    ("EAST","RUS_Soldier_TL"):2, ("EAST","RU_Soldier_Sniper"):2,
}
seen = {}
deslotted = {"WEST":0, "EAST":0}

def proc(m):
    name, body = m.group(1), m.group(2)
    whole = m.group(0)
    if 'player="PLAY CDG"' not in body:
        return whole
    sm = re.search(r'side="(WEST|EAST|RESISTANCE|CIV)"', body)
    vm = re.search(r'vehicle="([^"]+)"', body)
    if not sm or not vm:
        return whole
    side, veh = sm.group(1), vm.group(1)
    if side not in ("WEST","EAST"):
        return whole          # never touch GUER/CIV(HC) slots
    if 'forceHeadlessClient' in body:
        return whole
    k = (side, veh)
    seen[k] = seen.get(k, 0) + 1
    keep = KEEP.get(k, 99)
    if seen[k] <= keep:
        return whole          # keep this slot
    # DE-SLOT: drop the player= line + self-delete the unit; group Item stays (no renumber/sync change).
    deslotted[side] += 1
    new = re.sub(r'[ \t]*player="PLAY CDG";\r?\n', '', whole)
    # NOTE: init values can contain ESCAPED quotes (""task"",""medic"") — match those too, else the
    # append lands mid-string and produces a malformed init (the 2026-06-16 medic-deslot bug). See JOURNAL.
    new = re.sub(r'init="((?:[^"]|"")*)"', lambda mm: 'init="' + mm.group(1) + '; deleteVehicle this"', new, count=1)
    return new

out = re.sub(r'\bclass (Item\d+)\s*\{(.*?)\n\t\t\};', proc, txt, flags=re.S)
open(P, "w", encoding="utf-8", errors="replace").write(out)

print("de-slotted:", deslotted)
print("WEST kept by class:", {v:c for (s,v),c in seen.items() if s=="WEST"})
print("EAST kept by class:", {v:c for (s,v),c in seen.items() if s=="EAST"})
print("remaining PLAY CDG:", out.count('player="PLAY CDG"'))
print("braces", out.count("{"), out.count("}"), "| items=134 still:", "items=134;" in out)
