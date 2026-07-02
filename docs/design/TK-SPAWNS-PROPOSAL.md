# Proposal: Takistan start-spawn audit + 11 new spawns (Ray review via sector-planner)

Companion to `NEW-SPAWNS-PROPOSAL.md` (Chernarus). **Takistan is an independent spawn set** — the
LoadoutManager CH->TK mirror copies code but **skips `mission.sqm`**, so none of the Chernarus spawn
edits reach Takistan. This doc is TK-only, extracted from the TK mission's own data. Read-only analysis;
**do not edit `mission.sqm`** — Ray picks first, then a mission.sqm round-trip applies the chosen blocks.

Review in https://miksuu.com/tools/sector-planner (raw mission.sqm world-metres; spawn layer view-only).
Terrain slope is **not readable from sqm** → the elevation column below is the placed logic's ASL height,
and every NEW pick must be **eyeballed in the planner** and nudged onto flat, road-adjacent valley ground
before committing.

---

## 1. System parity + the pairing rule (this is the load-bearing part)

**Parameter defaults — confirmed identical to Chernarus:**

| Flag | TK `Rsc/Parameters.hpp` | TK `Common/Init/Init_CommonConstants.sqf` |
|---|---|---|
| `WFBE_C_BASE_STARTING_MODE` | default **2** (Random) — line 141 | `= 2` — line 957 |
| `WFBE_C_BASE_RANDOM_PURE` | default **1** (Original/pure) — line 147 | `= 1` — line 958 |

**The pairing rule — the constant is `startingDistance`, NOT a hardcoded 7500 in the picker.**
Chain: `Server/Init/Init_Server.sqf:308` sets `_minDist = startingDistance`;
`initJIPCompatible.sqf:22` sets `startingDistance = STARTING_DISTANCE`;
`version.sqf:10` (the LIVE built file, not just the template) defines `#define STARTING_DISTANCE 7500`.
So **TK pair rule = 7500 m**, the same absolute value as Chernarus — but Takistan is **~12800 m** wide
(confirmed from data: max town/logic coord y = 12779, x = 12681; nominal 12800×12800) versus Chernarus
15360 m. **It is NOT map-scaled.** A fixed 7500 on a 12.8 km map is proportionally much tighter
(0.59 × map width vs 0.49 × on Chernarus).

**Under the live default `RANDOM_PURE == 1`, the 7500 spacing is the ONLY constraint.**
`Init_Server.sqf` skips the B62 airfield filter (L244), the B62/B66 rotation-exclusion (L285), and the
B66 egress pool measure/relax (L374) whenever `RANDOM_PURE==1`, and the draw-loop egress clause
auto-passes (L468 / L474: `... || {RANDOM_PURE==1 || {_x call _egressOK}}`). Net: the WEST/EAST draw
accepts **any** pair of `LocationLogicStart` logics that are **≥ 7500 m apart**. No edge guard, no airfield
guard, no road/egress check. (Those filters only exist for the non-default `RANDOM_PURE==0` hardened path.)

> Note: the `_egressOK` edge guard hardcodes `_ws = 15360` (Chernarus) — dead under the live pure path,
> but if Ray ever flips `RANDOM_PURE=0` on Takistan that edge margin would be computed against the wrong
> world size. Flagged as a latent TK-portability bug in `Init_Server.sqf:342`; out of scope for this doc.

**Pair-count math (why east-half coverage is mathematically critical):**
- Current 14 logics form **28** valid ≥7500 m WEST/EAST pairs.
- A start at the **map centre can never pair** — e.g. existing **id230 (3715, 5636)** is closest to the
  middle and forms **0** valid pairs (it can literally never be selected). Any pick within ~7500 m of the
  whole rest of the field is wasted.
- Because 7500 ≈ 0.59 × map width, a viable pair almost always needs **one start in the far east/SE and one
  in the far west/SW** (or N↔S corner). The east edge is the thinnest-covered band, so **adding far-east
  starts multiplies pair variety far more than central ones** — the far-east picks below each add 6–8 new
  pairs, the central ones only 0–3.

---

## 2. Town anchors (extracted from the TK mission, not memory)

31 real towns + 2 airfield anchors, all defined inline in `mission.sqm` via
`[this,"<name>",...] execVM "Common\Init\Init_Town.sqf"` (the mission reads them at runtime as
`LocationLogicDepot` entities — `Common/Init/Init_Towns.sqf:6`). Positions used for every anchor below:

Chak Chak (4389,748) · Huzrutimam (6078,1082) · Landay (2073,304) · Loy Manara (8532,2467) ·
Sultansafee (6484,2081) · Jaza (9232,1832) · Chardarakht (10277,2332) · Hazar Bagh (11926,2642) ·
Chaman (513,2806) · Shukurkalay (1481,3513) · Sakhee (3673,4348) · Jilavur (2535,5047) ·
Khushab (1609,5682) · Mulladoost (2090,7687) · Kakaru (5314,4780) · Anar (6135,5671) ·
Feeruz Abad (5203,6070) · Timurkalay (8994,5337) · Falar (5958,7361) · Garmarud (9101,6756) ·
Garmsar (10881,6405) · Imarat (8208,7770) · Gospandi (3667,8540) · Ravanay (11484,8302) ·
Karachinar (12296,10398) · Nur (1784,11933) · Zavarak (9813,11495) · Bastam (5871,9000) ·
Nagara (3140,9964) · Rasman (6309,11122) · Shamali (4081,11720).

---

## 3. Runway rectangles to avoid

Two `LocationLogicAirport` anchors + their town-mode airfields (the mission's actual airfield logics):

| Airfield | LocationLogicAirport | Init_Town anchor | Avoid within |
|---|---|---|---|
| **Rasman AF (main Takistan airbase, N-centre)** | id78 @ (5690, 11181) | "Rasman AF" (5690, 11260) | ~1.5 km + the NE-SW strip |
| **Loy Manara AF (SW/S-centre strip)** | id66 @ (8191, 1803) | "Loy Manara AF" (8191, 1880) | ~1.5 km |

No third strip exists in the mission data. (Under the live pure path the 1500 m airfield filter is off,
so avoid these by hand.) None of the 11 proposals below sit inside either rectangle.

---

## 4. Audit of the existing 14 `LocationLogicStart`

Verdict key: **KEEP** / **REMOVE-CANDIDATE**. "elev" = placed-logic ASL height (Takistan valley floors run
~25–360 m per the town data; >430 m = hillside/ridge). "pairs" = how many of the other 13 it can pair with.
"edge" = distance to nearest map border.

| id | x, y | elev | pairs | edge | airDist | Verdict | Reason |
|---|---|---|---|---|---|---|---|
| 29 | 7292, 10550 | 84 | 5 | 2250 | 1722 | **KEEP** | NE plateau near Rasman/Zavarak, valley-height |
| 31 | 5551, 12268 | 69 | 6 | 532 | 1096 | **KEEP*** | `wfbe_default east`/"south"; N-edge (532 m) + 1096 m from Rasman AF. Low ground, high pair value — keep, but *nudge S off the map edge / away from the runway if planner shows it hugging either |
| 32 | 4180, 2063 | 435 | 5 | 2063 | clear | **KEEP** | S sector near Chak Chak; 435 m is elevated but inland & well-paired |
| 33 | 7874, 3261 | 358 | 3 | 3261 | 1492 | **KEEP*** | Near Loy Manara; 1492 m from Loy Manara AF (borderline) — eyeball it clears the strip |
| 34 | 170, 7330 | **494** | 6 | **170** | clear | **REMOVE-CANDIDATE** | Hard WEST edge (170 m) on high ground (494 m) — one of the two flagged. `wfbe_default resistance`, but GUER is base-less and NEVER placed in the loop (`_setGuer=false`, B59), so the resistance var is inert for placement → safe to drop. Its west-band coverage is replaced by T8/T11 |
| 64 | 4671, 9203 | 151 | 1 | 3597 | clear | **KEEP** | N-central valley (Gospandi/Nagara); low pair count but only central-N start |
| 65 | 8465, 8603 | 202 | 4 | 4197 | clear | **KEEP** | E-central near Imarat, valley-height, anchors the east |
| 228 | 4747, 3136 | **544** | 3 | 3136 | clear | **REMOVE-CANDIDATE** | **Highest of all (544 m)** — genuine ridge/peak start. Sakhee is already covered by valley-height neighbours; drop the peak |
| 229 | 7531, 4960 | 351 | 2 | 4960 | clear | **KEEP** | Dead-mid-east (Timurkalay); low pairs but scarce east-mid coverage |
| 230 | 3715, 5636 | 171 | **0** | 3715 | clear | **REMOVE-CANDIDATE** | **Dead-centre: forms ZERO valid ≥7500 m pairs → can never be selected.** Pure deadweight (not edge/ridge — remove for uselessness) |
| 231 | 648, 4569 | 418 | 5 | **648** | clear | **REMOVE-CANDIDATE** | WEST edge (648 m) on high ground (418 m) — the second flagged one. West-band coverage replaced by T8 |
| 232 | 7287, 761 | 288 | 8 | 761 | 1380 | **KEEP*** | `wfbe_default west`/"north"; **most-paired start (8)**. S-edge (761 m) + 1380 m from Loy Manara AF — keep for pair value, but *nudge N off the edge/strip if the planner shows overlap |
| 247 | 9250, 10019 | 166 | 5 | 2781 | clear | **KEEP** | NE near Zavarak, valley-height |
| 248 | 4761, 10413 | 104 | 3 | 2387 | 1206 | **KEEP*** | N near Shamali; 1206 m from Rasman AF — eyeball it clears the strip |

**Summary:** 4 REMOVE-CANDIDATES — **id34** & **id231** (west-edge, high ground — the two flagged in the
brief), **id228** (ridge/peak, 544 m), **id230** (dead-centre, 0 pairs / unselectable). Removing these 4
leaves 10 KEEP starts (14 pairs among them). The `*` KEEPs are edge/runway-borderline and worth an eyeball
nudge but are functionally fine and carry high pair value.

---

## 5. Proposed NEW spawns (11)

Anchored to the most-uncovered towns (ranked by distance to nearest existing start: Hazar Bagh 4.1 km,
Nur 3.3 km, Garmsar 3.3 km, Karachinar 3.1 km, Ravanay 2.8 km, Landay 2.7 km, Chardarakht 2.6 km …). Each
clears both runway rectangles and sits ≤ ~0.45 km from its anchor town (road-connectivity proxy).
"newPairs" = valid ≥7500 m pairs this pick forms **with the existing set** (the marginal coverage it buys).

| # | id | Coords (x, y) | Nearest town | newPairs | Fills |
|---|---|---|---|---|---|
| T1 | id260 | **11500, 2750** | Hazar Bagh ~439m | 8 | Far-SE desert — the single biggest hole (4.1 km) |
| T2 | id261 | **10300, 2450** | Chardarakht ~121m | 7 | SE plateau, Jaza↔Chardarakht seam |
| T3 | id262 | **10850, 6250** | Garmsar ~158m | 4 | East-central hole (3.3 km) |
| T4 | id263 | **11350, 8300** | Ravanay ~134m | 6 | East-coast band (2.8 km) |
| T5 | id264 | **12050, 10250** | Karachinar ~287m | 7 | Far-NE corner (3.1 km) |
| T6 | id265 | **1900, 11650** | Nur ~305m | 6 | Far-NW corner (3.3 km) |
| T7 | id266 | **2150, 520** | Landay ~229m | 6 | SW corner, south-edge west start (2.7 km) |
| T8 | id267 | **900, 2950** | Chaman ~413m | 5 | Inland-west SW — off-edge replacement for id231 |
| T9 | id268 | **9150, 6650** | Garmarud ~116m | 2 | East-central valley (Timurkalay↔Garmarud) |
| T11 | id269 | **2350, 7550** | Mulladoost ~294m | 1 | West-central band — off-edge replacement for id34 |
| T12 | id270 | **8850, 5250** | Timurkalay ~168m | 3 | East-mid, strengthens the scarce east-mid pairs |

**Priority if fewer than 11 wanted:** **T1 → T5 → T2 → T4 → T6 → T7 → T8 → T3 → T12 → T9 → T11**
(east/SE + corners first — they buy the most pairs and fill the true holes; T9/T11 are coverage-only fillers).

**Edge caveats to eyeball in the planner:** T7 (2150, 520) sits ~520 m off the S edge and T6/T8/T5 are
near corners — all clear of runways and anchored to real towns, but nudge onto the town's road/valley
floor so none ends up on a slope or hugging the border. T9 and T11 add little pair value; keep them only
if Ray wants denser east-central / west-central coverage.

**Net effect:** keep-10 (14 pairs) **+ 11 new = 21 starts → 79 valid ≥7500 m pairs** (from 28 today).
The far-east/corner additions are what break the current east-half thinness.

---

## 6. Ready-to-paste `mission.sqm` blocks

Cloned from a real TK start block (`class Item49` / id230 structure). `position[]={x, ELEV, y}` — the
**middle** value is ASL elevation; the engine snaps LocationLogic to terrain, so an approximate elev is
fine (values below are the anchor town's ground height as a starting guess). Use the **unused ids 260–270**
(free ranges in the sqm: 206–226, 233–246, 249, 255–999). **Bump the parent `class Groups` counter**
`items=91;` at `mission.sqm:45` to `items=102` (91 + 11), and append these as `class Item91` … `class Item101`.

```cpp
// append under class Groups (mission.sqm), and set the parent items=91 -> items=102
class Item91 { side="LOGIC"; class Vehicles { items=1; class Item0 {
    position[]={11500,300,2750}; id=260; side="LOGIC"; vehicle="LocationLogicStart"; leader=1; skill=0.60000002; }; }; };
class Item92 { side="LOGIC"; class Vehicles { items=1; class Item0 {
    position[]={10300,330,2450}; id=261; side="LOGIC"; vehicle="LocationLogicStart"; leader=1; skill=0.60000002; }; }; };
class Item93 { side="LOGIC"; class Vehicles { items=1; class Item0 {
    position[]={10850,290,6250}; id=262; side="LOGIC"; vehicle="LocationLogicStart"; leader=1; skill=0.60000002; }; }; };
class Item94 { side="LOGIC"; class Vehicles { items=1; class Item0 {
    position[]={11350,270,8300}; id=263; side="LOGIC"; vehicle="LocationLogicStart"; leader=1; skill=0.60000002; }; }; };
class Item95 { side="LOGIC"; class Vehicles { items=1; class Item0 {
    position[]={12050,150,10250}; id=264; side="LOGIC"; vehicle="LocationLogicStart"; leader=1; skill=0.60000002; }; }; };
class Item96 { side="LOGIC"; class Vehicles { items=1; class Item0 {
    position[]={1900,146,11650}; id=265; side="LOGIC"; vehicle="LocationLogicStart"; leader=1; skill=0.60000002; }; }; };
class Item97 { side="LOGIC"; class Vehicles { items=1; class Item0 {
    position[]={2150,360,520}; id=266; side="LOGIC"; vehicle="LocationLogicStart"; leader=1; skill=0.60000002; }; }; };
class Item98 { side="LOGIC"; class Vehicles { items=1; class Item0 {
    position[]={900,248,2950}; id=267; side="LOGIC"; vehicle="LocationLogicStart"; leader=1; skill=0.60000002; }; }; };
class Item99 { side="LOGIC"; class Vehicles { items=1; class Item0 {
    position[]={9150,203,6650}; id=268; side="LOGIC"; vehicle="LocationLogicStart"; leader=1; skill=0.60000002; }; }; };
class Item100 { side="LOGIC"; class Vehicles { items=1; class Item0 {
    position[]={2350,268,7550}; id=269; side="LOGIC"; vehicle="LocationLogicStart"; leader=1; skill=0.60000002; }; }; };
class Item101 { side="LOGIC"; class Vehicles { items=1; class Item0 {
    position[]={8850,261,5250}; id=270; side="LOGIC"; vehicle="LocationLogicStart"; leader=1; skill=0.60000002; }; }; };
```

**Removals (Ray's call):** to drop a REMOVE-CANDIDATE, delete its wrapping `class Item{N}` block and
decrement the same `items=` counter. id34 is `wfbe_default resistance` (inert for placement) and id232/id31
are the WEST/EAST `wfbe_default` markers — **do not delete id31/id232**; they are KEEPs and are the
last-resort force-fall anchors.

> Coords are **Takistan-world metres** — do not hand-port to/from Chernarus. LoadoutManager skips
> mission.sqm on the mirror, so these must be applied to the TK mission directly.
