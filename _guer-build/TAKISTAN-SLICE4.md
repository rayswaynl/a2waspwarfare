# TAKISTAN SLICE 4 — TKGUE Routing / Generator-path Code

Branch: `claude/guer-merge`  
Base commit: `740241972` (slice 2)  
Status: **WORKING TREE CHANGES ONLY — not committed**

---

## STEP-0 Finding: LoadoutManager Regen Is WHOLESALE

**The regen does a full mirrored copy of Chernarus → Takistan.**

Key evidence from `Tools/LoadoutManager/FileManagement/FileManager.cs`:

- `UpdateFilesForTakistan()` calls `FileManager.CopyFilesFromSourceToDestination(chernarusDir, takistanDir, VANILLA)`
- That method calls `DeleteExtraFiles()` + `DeleteExtraDirectories()` — any file in TK that has **no counterpart in CH** is **deleted**.
- The generated `EASA_Init.sqf` is overwritten wholesale by `WriteToFile(..., @"\Client\Module\EASA\EASA_Init.sqf")` in `WriteSpecificFilesToTheTerrains`.

**Files skipped by `ShouldSkipFile`** (preserved across regen): `mission.sqm`, `version.sqf`, `GUI_Menu_Help.sqf`, `texHeaders.bin`, `StartVeh.sqf`, `loadScreen.jpg` (non-modded). These survive. Everything else is overwritten or deleted.

**Confirmed:** `Common/Config/Core_Root/Root_GUE_PlayerOverlay.sqf` exists in CH but NOT in TK currently. On regen, CH's copy propagates to TK. A hypothetical `Root_TKGUE_PlayerOverlay.sqf` (TK-only) would be **deleted by `DeleteExtraFiles`**.

**File strategy chosen: dual-map branching inside CH source `Root_GUE_PlayerOverlay.sqf`** using `#ifdef IS_CHERNARUS_MAP_DEPENDENT` (defined in `version.sqf` for Chernarus; commented-out for Takistan per `BaseTerrain.GenerateAndWriteVersionSqf()`). This single file serves both maps — regen propagates it from CH → TK, and the preprocessor picks the right classname branch at mission load time.

---

## Files Created / Edited

### 1. `Missions/[55-2hc]…chernarus/Common/Config/Core_Root/Root_GUE_PlayerOverlay.sqf` — EDITED (CH source)

**What it does:** The single shared overlay for both maps. Guards on `WFBE_C_GUER_PLAYERSIDE > 0`, `local player`, `side == resistance`. Sets per-role gear (`WFBE_GUER_DefaultGearEngineer/Spot/Medic`). Runs a `[] spawn` loop rebuilding `WFBE_GUERDEPOTUNITS` on tier changes.

**New dual-map branching** (inside the spawn loop's tier-rebuild block):
```
#ifdef IS_CHERNARUS_MAP_DEPENDENT
    // Chernarus roster: GUE_Soldier_Sab/Medic/MG/AT/AA/Sniper + Offroad_DSHKM_Gue/V3S_Gue + Ka137_MG_PMC
    // tier>=1: BRDM2_Gue, T34_TK_GUE_EP1
    // tier>=2: T55_TK_GUE_EP1, BTR40_TK_GUE_EP1
    // tier>=3: T72_Gue, BMP2_Gue
#else
    // Takistan roster: TK_GUE_Soldier_EP1/Bonesetter/MG/AT/AA/Sniper + Offroad_DSHKM_TK_GUE_EP1/Pickup_PK_TK_GUE_EP1/V3S_TK_GUE_EP1 + Ka137_MG_PMC
    // tier>=1: BRDM2_TK_GUE_EP1, T34_TK_GUE_EP1
    // tier>=2: T55_TK_GUE_EP1, BTR40_MG_TK_GUE_EP1
    // tier>=3: Ural_ZU23_TK_GUE_EP1  (no T72/BMP2 GUE on TK)
#endif
```
Gear arrays unchanged (AKS-74 family common to both GUER factions).

**Regen-safe:** lives in CH, copied to TK automatically. Survives.

---

### 2. `Missions/[55-2hc]…chernarus/Common/Config/Core_Root/Root_TKGUE.sqf` — EDITED (CH source)

**What it does:** Adds the player overlay call inside the `if (local player) then {...}` block:
```sqf
if ((missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0) then {
    Call Compile preprocessFileLineNumbers "Common\Config\Core_Root\Root_GUE_PlayerOverlay.sqf";
};
```
This is placed after the Loadout_TKGUE / Loadout_PMC calls. Since CH's `Root_TKGUE.sqf` is identical to TK's (diff confirmed empty before this edit), editing CH is sufficient for regen-safety. CH's `Root_TKGUE.sqf` will be copied to TK on regen.

**Regen-safe:** CH is the source; edit lives in the CH copy. TK copy also edited for current working tree consistency.

---

### 3. `Missions_Vanilla/[61-2hc]…takistan/Common/Config/Core_Root/Root_TKGUE.sqf` — EDITED (TK copy, in-sync with CH)

Same as #2 — applied to TK copy for immediate working-tree correctness. Will be overwritten by CH on regen (which now carries the same edit). No divergence.

---

### 4. `Missions_Vanilla/[61-2hc]…takistan/Common/Config/Core/Core_TKGUE.sqf` — EDITED

**What it does:** Adds `Ka137_MG_PMC` to the warlord buy roster, gated on `WFBE_C_GUER_PLAYERSIDE > 0`:
```sqf
if ((missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0) then {
    _c = _c + ['Ka137_MG_PMC'];
    _i = _i + [['','',6000,40,-2,0,3,0,'Takistani Guerilla',[]]];
};
```

**Duplicate-element note:** `Core_PMC.sqf` (loaded at Init_Common.sqf line 254) unconditionally registers `Ka137_MG_PMC` when `WFBE_C_MODULE_BIS_PMC > 0` (which is the default on TK). Core_TKGUE loads at line 259. When both PMC and GUER playerside are enabled, Core_TKGUE will hit the "Duplicated Element found" diag_log guard — this is a **harmless warning** (the loop skips the second registration), and the vehicle is available in the buy menu via the first (PMC) registration. If PMC is disabled (`WFBE_C_MODULE_BIS_PMC == 0`), Core_TKGUE's gated block provides the only registration. Both paths are functional.

**Reconcile check:** All contract-roster vehicles (Offroad_DSHKM_TK_GUE_EP1, Pickup_PK_TK_GUE_EP1, V3S_TK_GUE_EP1, BRDM2_TK_GUE_EP1, T34_TK_GUE_EP1, T55_TK_GUE_EP1, BTR40_MG_TK_GUE_EP1, Ural_ZU23_TK_GUE_EP1, UH1H_TK_GUE_EP1) already present in Core_TKGUE before this slice — not re-added. Only Ka137_MG_PMC was missing.

---

### 5. `Missions_Vanilla/[61-2hc]…takistan/Client/Module/Skill/Skill_Init.sqf` — EDITED

**What it does:** Replaces the verbatim CH Chernarus classnames in the GUER gate block with the contract TK classnames:
```sqf
// BEFORE (Chernarus classnames, inert on TK):
WFBE_SK_V_Engineers = WFBE_SK_V_Engineers + ["GUE_Soldier_Sab"];
WFBE_SK_V_Spotters  = WFBE_SK_V_Spotters  + ["GUE_Soldier_Sniper"];
WFBE_SK_V_Medics    = WFBE_SK_V_Medics    + ["GUE_Soldier_Medic"];

// AFTER (TK contract classnames):
WFBE_SK_V_Engineers = WFBE_SK_V_Engineers + ["TK_GUE_Soldier_EP1"];
WFBE_SK_V_Spotters  = WFBE_SK_V_Spotters  + ["TK_GUE_Soldier_Sniper_EP1"];
WFBE_SK_V_Medics    = WFBE_SK_V_Medics    + ["TK_GUE_Bonesetter_EP1"];
```
Gate `WFBE_C_GUER_PLAYERSIDE > 0` preserved. No other changes.

**Note:** Skill_Init.sqf is in `ShouldSkipFile`? No — it is NOT in the skip list. Regen will overwrite it from CH. The CH copy still has the old `GUE_Soldier_*` classnames. **Action needed post-regen:** The orchestrator must also apply this classname fix to the CH `Skill_Init.sqf` so regen propagates the TK fix. Alternatively, add a post-regen patch. See Open Questions below.

---

### 6. LoadoutManager C# Changes (Ka-137 EASA regen-safety)

**Problem:** `WriteToFile(..., EASA_Init.sqf)` overwrites the file wholesale. Any hand-edit to the Ka-137 GUER EASA block is lost on regen.

**Solution:** Marker-pair injection pattern (same as `Common_ModifyAirVehicle.sqf`):
- `Tools/LoadoutManager/SqfFileGenerators/SqfFileGenerator.cs` — `GenerateEndOfTheEasaFile()` now emits `//LoadoutManagerGuerEasaInsert` + `//LoadoutManagerGuerEasaInsert_END` marker lines **before** the `for '_i'` loop. These survive into the generated EASA_Init.sqf.
- `Tools/LoadoutManager/FileManagement/FileManager.cs` — new static `GenerateGuerEasaKa137Block()` method returns the SQF block (the gated `if (WFBE_C_GUER_PLAYERSIDE > 0) then {...}` block with all 3 EASA loadouts).
- `Tools/LoadoutManager/Data/Terrains/BaseTerrain.cs` — `WriteSpecificFilesToTheTerrains()` now calls `FileManager.InsertGeneratedCodeInToAFile(FileManager.GenerateGuerEasaKa137Block(), easaInitPath, "//LoadoutManagerGuerEasaInsert", "//LoadoutManagerGuerEasaInsert_END")` immediately after `WriteToFile(EASA_Init.sqf)`, for VANILLA and MAIN terrain mod status only.

**Post-regen flow:** Regen writes EASA_Init (markers included) → immediately injects Ka-137 block between them → file is complete with the GUER block. Fully automatic on every regen run.

**EASA_Init.sqf (both CH and TK working tree copies):** Updated in working tree to match the marker+content form that regen will produce. CH: hand-edit replaced with marker-wrapped block. TK: Ka-137 block added with marker pair.

---

## Verification Results

| File | Brace/Bracket balance | A2-illegal scan | Gate-OFF |
|------|----------------------|-----------------|---------|
| Root_GUE_PlayerOverlay.sqf (CH) | PASS (14/14 { }, 28/28 [ ], both #ifdef branches individually 3/3 { } 4/4 [ ]) | PASS | exitWith {} on line 22 (GUER_PLAYERSIDE≤0 = no-op) |
| Root_TKGUE.sqf CH | PASS | PASS | overlay call inside `if GUER_PLAYERSIDE>0` |
| Root_TKGUE.sqf TK | PASS | PASS | same |
| Core_TKGUE.sqf | PASS | PASS | Ka137 block inside `if GUER_PLAYERSIDE>0` |
| Skill_Init.sqf TK | PASS | PASS | classname block inside `if GUER_PLAYERSIDE>0` |

**#ifdef branch balance (Root_GUE_PlayerOverlay.sqf):**
- CH branch: 3 `{` / 3 `}`, 4 `[` / 4 `]`
- TK branch: 3 `{` / 3 `}`, 4 `[` / 4 `]`

**C# conceptual verification:**
- `GenerateGuerEasaKa137Block()` uses verbatim string with `""` double-quote escaping for SQF strings inside C# `@""` literal — correct.
- `InsertGeneratedCodeInToAFile` already handles marker-replacement (proven on `Common_ModifyAirVehicle.sqf`). Pattern is identical.
- `GenerateEndOfTheEasaFile()` now emits `\n//LoadoutManagerGuerEasaInsert\n//LoadoutManagerGuerEasaInsert_END\n` — both markers on their own lines, which `IndexOf` will find. Correct.
- Injection conditioned on `terrainModStatus == VANILLA || MAIN` — modded terrains (currently commented out in `GenerateCommonBalanceInitAndTheEasaFileForEachTerrain`) are excluded.

---

## Open Questions for Steff

### HIGH — needs smoke confirmation

1. **Ka-137 MG classnames:** `Ka137_MG` (weapon) and `100Rnd_762x54_PKT` (magazine) in the `[MR] Recon` EASA loadout are **UNCONFIRMED**. Check RPT on first regen+smoke. If wrong, update `GenerateGuerEasaKa137Block()` in FileManager.cs with correct classnames.

2. **Ataka ([AG]) missile geometry from Ka-137 recon airframe:** The Ka-137 is a recon drone, not a gunship. Whether `AT9Launcher` / `4Rnd_AT9_Mi24P` (Ataka ATGM) can achieve lock and fire from this airframe is **unconfirmed**. If AG loadout fails (no lock, no fire), fall back to 57mm rockets only: `[2000,'[AG] Strike - S-5 (64)',[['57mmLauncher'],['64Rnd_57mm']]]`.

3. **Igla ([AA]) lock from Ka-137:** Same caveat as AG — drone airframe may not support `airLock` missile targeting. If AA loadout fails, remove it or replace with a backup.

4. **Skill_Init.sqf regen risk:** TK `Skill_Init.sqf` is NOT in `ShouldSkipFile` — regen will overwrite it from CH's copy which still has `GUE_Soldier_Sab/Sniper/Medic`. **The orchestrator needs to also apply the TK classname fix to the CH `Skill_Init.sqf` so the fix propagates on regen.** Options: (a) edit CH Skill_Init with a `#ifdef IS_CHERNARUS_MAP_DEPENDENT` branch (same pattern as overlay), OR (b) add Skill_Init to `ShouldSkipFile` for Takistan, OR (c) apply a post-regen patch in `BaseTerrain.cs`. Option (a) is cleanest. This is **out of scope for slice 4** but must be resolved before the first regen in production.

5. **LoadoutManager C# compilation:** The C# has not been compiled/run. The pattern matches the existing `Common_ModifyAirVehicle.sqf` injection. Steff should run `dotnet build` on LoadoutManager and do a dry regen into a test directory before committing. The `GenerateGuerEasaKa137Block` verbatim string uses `[[ 'Ka137_MG'],[ '100Rnd_762x54_PKT']]` — the double-space before the classnames (from the `@"` multiline literal) should be harmless in SQF but can be cleaned up if aesthetics matter.

6. **Ka-137 DLC gate on Chernarus:** On Chernarus `WFBE_C_MODULE_BIS_PMC` is also available (`Root_GUE.sqf` calls `Loadout_PMC.sqf` when PMC > 0). The CH overlay pool already includes `Ka137_MG_PMC` — no PMC gate on the pool entry (it just appears in the pool regardless of PMC module state). If non-PMC CH servers exist, `Ka137_MG_PMC` will appear in the buy menu but fail to spawn (class not found). Consider adding a PMC gate to the CH pool entry in `Root_GUE_PlayerOverlay.sqf` too.

### LOW

7. **Duplicate `Ka137_MG_PMC` diag_log:** When both PMC and GUER playerside are on (default TK config), `Core_PMC.sqf` registers Ka137_MG_PMC first, and Core_TKGUE's conditional block will emit a diag_log "Duplicated Element found" warning. Functionally harmless, but visible in RPT. If it causes concern, the Core_TKGUE entry can be removed (relying solely on Core_PMC); the trade-off is Ka-137 becomes unavailable when PMC is disabled.

8. **Root_GUE.sqf CH client block — overlay already wired:** The CH `Root_GUE.sqf` already calls `Root_GUE_PlayerOverlay.sqf` inside `if (WFBE_C_GUER_PLAYERSIDE > 0)`. No change needed there.

---

## What Regen + Smoke Must Confirm

1. Regen runs cleanly (no C# compile errors, no missing markers).
2. TK EASA_Init after regen contains the Ka-137 block between the markers.
3. GUER players on TK see `Takistani Guerilla` depot with correct TK_GUE_* vehicles.
4. Ka-137 appears in buy menu only when tier ≥ 0 (always), PMC enabled, GUER playerside on.
5. EASA service point on TK shows Ka-137 with [MR]/[AG]/[AA] loadout choices when GUER playerside on.
6. RPT is clean on Skill check — `TK_GUE_Soldier_EP1` resolves to Engineer skill, `TK_GUE_Soldier_Sniper_EP1` to Spotter, `TK_GUE_Bonesetter_EP1` to Medic.
7. WFBE_C_GUER_PLAYERSIDE=0 (default) → no GUER depot pool changes, no skill registrations, no EASA Ka-137 entry, no overlay call executed. Takistan is a pure 2-side match.
