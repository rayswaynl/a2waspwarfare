# Proposal: 5 new Chernarus start spawns (Ray review via sector-planner)

Ray (2026-07-02): default start placement flips to **random-PURE**; he asked for up to 5 NEW spawn
suggestions, reviewable in https://miksuu.com/tools/sector-planner (tool speaks raw mission.sqm
world-metres; spawn layer is view-only → add via the mission.sqm round-trip / paste blocks below).

Today: 19 `LocationLogicStart` points → 48 valid ≥7.5km WEST/EAST pairs. Gaps: deep south band,
SW corner, SE coast. Each pick below clears the NWAF/NEAF/Balota runway rectangles and sits within
~0.5-1.7km of a town (road-connectivity proxy). Terrain slope not readable from sqm → **eyeball each
in the planner before committing** (nudge onto flat, road-adjacent ground).

| # | Region | Coords (x,y) | Nearest town | Fills | New ≥7.5km partners |
|---|---|---|---|---|---|
| S1 | Petrovka South plain (deep S) | **4900, 12100** | Petrovka ~500m | biggest hole: deep-south band | 11 |
| S2 | South-central deep (Gvozdno↔Petrovka seam) | **6600, 13200** | Petrovka ~1.7km | emptiest region; true south-edge starts | 11 |
| S3 | SW corner (Komarovo/Kamenka) | **2900, 2350** | Komarovo ~630m | empty coastal SW | 10 |
| S4 | SE coast (Nizhnoye/Solnichniy) | **13100, 7500** | Nizhnoye ~610m | east-coast seam | 8 |
| S5 | Far-SE (Gvozdno/Krasnostav) | **9700, 12400** | Gvozdno ~1.15km | far-SE cells | 9 |

Priority if fewer than 5: **S1 → S3 → S5 → S4 → S2** (S2 overlaps S1's region; keep both only if Ray
wants two south variants).

Ready-to-paste `mission.sqm` blocks (copy of the id=301 structure; `position[]={x, ELEV, y}` — engine
snaps logics to terrain; use unused ids e.g. 310-314 and bump the parent `items=` counter):
see the full blocks in the recon output (agent a090d6e75e701ef40) — template:
```cpp
class ItemTODO { side="LOGIC"; class Vehicles { items=1; class Item0 {
    position[]={4900,150,12100}; id=310; side="LOGIC"; vehicle="LocationLogicStart"; leader=1; skill=0.60000002; }; }; };
```
(S1 4900/12100 · S2 6600/13200 · S3 2900/2350 · S4 13100/7500 · S5 9700/12400)

NOTE: Chernarus-world coords — do NOT hand-port to Takistan (LoadoutManager skips mission.sqm on the
mirror; TK needs its own set later).
