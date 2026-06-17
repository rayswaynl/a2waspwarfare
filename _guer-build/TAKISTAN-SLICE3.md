# GUER Takistan Port — Slice 3 Report (mission.sqm surgery)

**Branch:** `claude/guer-merge`  
**Worktree:** `C:/Users/Steff/a2wasp-guermerge`  
**File edited:** `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/mission.sqm`  
**Status:** DONE (working-tree only — no commit, no push, awaiting orchestrator review)

---

## Edits made

### 1. Groups top-level `items=` count

| Before | After |
|--------|-------|
| `items=118;` | `items=123;` |

+5 to account for: 1 GUER owner-logic group + 4 GUER player-slot groups.

### 2. GUER owner-logic item (`class Item118`)

- **Group:** `class Item118`, `side="LOGIC"`
- **Vehicle:** `LocationLogicOwnerResistance` (correct class — NOT `LocationLogicOwnerGuer` which is invalid)
- **id:** `254`
- **text:** `"WFBE_L_GUE"`
- **Position:** `{12505.479, 208.02589, 12528.001}` — anchored exactly at `GuerTempRespawnMarker` (already present at mission.sqm Markers block)
- **synchronizations:** `{255, 256, 257, 258}` (the 4 GUER player slots below)

### 3. GUER player slots (`class Item119–122`)

All 4 slots: `side="GUER"`, `player="PLAY CDG"`, `rank="CORPORAL"`, `skill=0.60000002`, `synchronizations[]={254}`.

| Group | id | Classname | Position | Description |
|-------|----|-----------|----------|-------------|
| Item119 | 255 | `TK_GUE_Soldier_EP1` | `{12503.479, 208.02589, 12528.001}` | Insurgent Engineer |
| Item120 | 256 | `TK_GUE_Soldier_EP1` | `{12507.479, 208.02589, 12528.001}` | Insurgent Engineer |
| Item121 | 257 | `TK_GUE_Soldier_Sniper_EP1` | `{12503.479, 208.02589, 12532.001}` | Insurgent Sniper |
| Item122 | 258 | `TK_GUE_Bonesetter_EP1` | `{12507.479, 208.02589, 12532.001}` | Insurgent Medic |

**Init fields:**
- Engineer x2: `init="removeAllWeapons this";`
- Sniper: `init="removeAllWeapons this";`
- Medic: `init="removeAllWeapons this; this setVariable [""task"",""medic""];";`

Medic init uses the **fixed sequential form** (matching the CH hardening-pass fix from commit `0920d8197`) — `setVariable` is NOT inside `deleteVehicle this` and `deleteVehicle this` is NOT present at all (these are live playable slots, not de-slotted overflow units).

### 4. W/E de-slot cut — DEFERRED

The CH "27→14" W/E cut was **NOT applied to TK**. Reason: TK's W/E slot layout differs materially from Chernarus:

| | Chernarus | Takistan |
|-|-----------|----------|
| Slots per side | 27 W + 27 E | 30 W + 30 E |
| WEST classnames | `FR_TL`, `FR_Corpsman`, `FR_Miles`, `USMC_SoldierS_Sniper`, `USMC_Soldier_TL` | `US_Delta_Force_EP1`, `US_Delta_Force_TL_EP1`, `US_Soldier_Officer_EP1`, `US_Soldier_Medic_EP1`, `US_Soldier_Sniper_EP1`, `GER_Soldier_*`, `BAF_Soldier_Medic_DDPM` |
| EAST classnames | `Ins_Soldier_CO`, `RUS_Soldier_Medic`, `RUS_Soldier1`, `RUS_Soldier_TL`, `RU_Soldier_Sniper` | `TK_Soldier_Officer_EP1`, `TK_Soldier_Medic_EP1`, `TK_Soldier_Sniper_EP1`, `TK_Special_Forces_EP1`, `TK_Special_Forces_TL_EP1`, `TK_CIV_Takistani03_EP1`, `RUS_Commander` |

`sqm_cut.py` is hardcoded to CH classnames and would produce 0 de-slots on TK. Per slice instructions, the safe approach is to apply only the GUER-additive part and report the cut as needing manual attention.

**TK W/E cut needs:** A separate `sqm_cut_tk.py` with the correct KEEP dict for TK classnames + slot counts (or manual decision on target counts). **Steff must decide role-balance target for TK before the cut is run.** Current TK state = 30 W + 30 E + 4 GUER = 64 total playable slots.

---

## Verification results

### Brace balance
```
{ = 1032    } = 1032    delta = 0
```
PASS.

### items= consistency
```
Groups top-level items=123
Actual class ItemN count at depth 2: 123  (Item0 through Item122)
```
PASS — exact match.

### synchronizations[] consistency
- Owner-logic id=254: syncs to `{255,256,257,258}` (4 GUER slots)
- Each GUER slot: syncs back to `{254}` (owner logic)
- No orphaned sync references (no new ids referenced by existing items, no existing sync lists touched)

### A2-illegal scan (new init strings only)
Checked for: `private _`, `params `, `pushBack`, `isEqualType`, `allMapMarkers`, `select{`, `remoteExec`
Result: **CLEAN**

### id uniqueness
- Pre-existing highest id: 253 (id=253, LocationLogicCamp in Item117)
- New ids: 254, 255, 256, 257, 258 — all fresh, no collision

### PLAY CDG slot count
- Before: 62 (30 WEST + 30 EAST + 2 HC CIV)
- After: 66 (30 WEST + 30 EAST + 2 HC CIV + 4 GUER)

---

## Design decisions made

1. **Owner-logic position:** Placed at the exact `GuerTempRespawnMarker` coordinates `{12505.479, 208.02589, 12528.001}`. This is in the central-east area of Takistan (approx. Loy Manara area), which is the intended GUER spawn anchor already placed by the prior infrastructure.

2. **Player slot offsets:** Slots offset ±2 in X and ±4 in Z from the owner-logic center (mirroring the CH ±2/±4 grid pattern), keeping the spawn cluster compact.

3. **Classnames used:** `TK_GUE_Soldier_EP1` (x2 saboteur), `TK_GUE_Soldier_Sniper_EP1`, `TK_GUE_Bonesetter_EP1` — all confirmed present in `Common/Config/Core/Core_TKGUE.sqf` (locked contract from slice spec).

4. **W/E cut deferred:** Not attempted. TK has 30 slots per side with different classnames than CH's `sqm_cut.py` can handle. The cut is a separate task requiring a TK-specific KEEP dict.

---

## Open questions / items Steff must confirm before in-engine smoke

1. **W/E cut for TK:** Do you want a 30→14 cut, 30→20 cut, or no cut? What role-balance target? Once decided, a `sqm_cut_tk.py` variant can be written and run safely.

2. **GuerTempRespawnMarker position check:** The owner-logic and spawn slots are anchored at `{12505, 208, 12528}`. Please verify this is a walkable ground position in-engine (no clipping into terrain). The marker was pre-placed by earlier infrastructure but may need a small Z adjustment if terrain height differs.

3. **Slot descriptions:** Used "Insurgent Engineer" (x2) matching CH description. If TK wants different role labels (e.g. "Rifleman" for the generic `TK_GUE_Soldier_EP1`), update descriptions before commit.

4. **GUER slot gate-OFF suppress:** Same deferred issue as CH (noted in JOURNAL.md hardening section): GUER slots are always present in .sqm; server-side Init_Server delete-on-OFF block should gate them when `WFBE_C_GUER_PLAYERSIDE=0`. Confirm the TK Init_Server port (slice 1) handles this correctly for TK.
