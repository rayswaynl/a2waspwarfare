# JOURNAL — a2waspwarfare-experital

## 2026-06-12 — Artillery Radar + Reserve buildable structures (WDDM integration)

Two new commander-buildable structures, mirroring the CBR/Bank pattern (cfc1fb93):

- **ArtilleryRadar** — `USMC_/RU_WarfareBArtilleryRadar` (CO) / `US_/TK_..._EP1` (OA).
  Cost 2400, MediumSite, dis 21, dir 90. Gate `WFBE_C_STRUCTURES_ARTILLERYRADAR = 1`.
- **Reserve** — `Land_Mil_Barracks_i` (CO) / `Land_Mil_Barracks_i_EP1` (OA — intact model
  inferred safe from the `Land_Mil_Barracks_i_ruins_EP1` WFBE_C_STRUCTURES_RUINS precedent).
  Cost 2000, MediumSite, dis 30 (walls reach ±24 m). Gate `WFBE_C_STRUCTURES_RESERVE = 1`.

Both use **MediumSite** → the standard phased construction animation path
(LocationLogicStart / WFBE_B_Completion), same as the factories — NOT preplaced.
Auto-walls fire from Construction_MediumSite (exclusion list untouched), pulling the
CHOSEN WDDM designs added to Init_Defenses.sqf:

- `WFBE_NEURODEF_ARTILLERYRADAR_WALLS` — "walled boom-gate checkpoint": HESCO 5x ring,
  3 m front gap, cones + danger sign; boom gate `Land_BarGate2` on A2/CO, jersey-block
  chicane fallback on OA standalone (BarGate is A2 content).
- `WFBE_NEURODEF_RESERVE_WALLS` — "floodlit walled yard": HESCO 10x yard, corner
  watchtowers (`Land_Fort_Watchtower[_EP1]` per content set), `Land_Ind_IlluminantTower`
  over the bays (confirmed both content sets via Core_CIV/Core_TKCIV).

Plumbing: RequestStructure allowed-list +2, marker labels ("AR"/"RES"),
Client_FNC_Special build-started cases, stringtable `RB_Artillery_Radar`/`RB_Reserve`,
shorthand vars `<side>ARTRAD`/`<side>RES`. Per-design intent: the Artillery Radar takes
fortifications only (walls, no gun defenses) — its template contains zero crewed weapons.

LoadoutManager run synced Takistan (7za pack step fails — documented-ignorable). NOTE:
the generator clobbers owner hand-edits in `EASA_Init.sqf` (re-adds stripped defaults,
54ad0732) and `Sounds\description.ext` (volumes 1→7) on the CHERNARUS side — those four
generated-file changes were reverted before commit; Takistan committed state already
matches generator output. Needs an in-engine build test of both structures.

---

## Task 28 — Port Patrols v2 at upgrade index 23 (2026-06-10)

WFBE_UP_PATROLS = 23 (CBR = 22 stays). All faction arrays grow to 24 entries.

PR #25 dependency check: server_side_patrols.sqf only needs WFBE_HEADLESSCLIENTS_ID
and HandleSpecial/RequestSpecial — both already present in experital pre-#25. No PR #25
symbols needed.

Old system retired: Init_Towns random flagging + server_town_ai spawn gate removed.
server_patrols.sqf / Server_GetTownPatrol.sqf left as dead code (same as master).

Group A (21 entries→24): RU, USMC, CDF, INS, OA_TKGUE, OA_US — add UNITCOST+CBR+Patrols padding
Group B (22 entries→24): OA_TKA — add CBR+Patrols padding
Group C (23 entries→24): CO_GUE, GUE, CO_RU, CO_US — add Patrols only

---

## 2026-06-10 — Investigation: BuyUnits dropdown forEach over `[objNull]` (GUI_Menu_BuyUnits.sqf)

**Question:** Did commit `c8071eeb` (airfield capture / Task 12) introduce a regression where the
factory-dropdown `forEach _sorted` at ~line 282 iterates `[objNull]` when no depot/airport is in range?

**Verdict: pre-existing since the original WFBE import — NO new regression.**

Evidence:
- `git log -L 250,290` on the file: the `_sorted = [[...] Call WFBE_CL_FNC_GetClosestDepot];`
  wrapping is unchanged context in `c8071eeb`; the commit only ADDED `_closest = _sorted select 0;`.
- Initial import `96809ac3` already has the identical wrap + the same `forEach _sorted`, and the
  Depot/Airport branches never set `_closest` (file-top init `_closest = objNull;`, line 8).
- `_sorted` was never carried over from the `default` factory branch — every switch branch always
  assigned it, including in the original code.
- `Client_GetClosestDepot.sqf` / `Client_GetClosestAirport.sqf` always return objNull-or-entity
  (init `_closest = objNull`, returned as last expression) — never nil, so the wrap is always a
  1-element array and `select 0` is safe.
- With `_x = objNull`: `Common_GetClosestEntity.sqf` returns objNull harmlessly (`distance` vs a
  null object = 1e10, never `< 100000`), then `objNull getVariable 'name'` → nil → the `_txt`
  concatenation on line 280 errors → broken/missing dropdown entry + RPT "Undefined variable"
  spam. Same behavior before and after `c8071eeb`.
- `c8071eeb` actually FIXED a real carry-over bug: before it, on Depot/Airport tabs `_closest`
  kept its stale value (objNull init, last factory from the `default` branch, or the dropdown
  handler at line 191), so the queue display at line 290 could read the wrong object's "queu".
  Downstream is objNull-tolerant (`isNil '_queu'` guard, `getVariable` on objNull → nil).

### Discovered Issues (off-scope, optional hardening)
- Cosmetic, since 2010: opening the Depot/Airport tab with none in purchase range puts one broken
  entry / RPT error in the 12018 dropdown. Cheap fix if ever wanted:
  `if !(isNull (_sorted select 0)) then { ...forEach _sorted... }` around the lbClear/forEach
  block (or `lbAdd [12018, localize 'STR_...none-in-range']` in the else).
