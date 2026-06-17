# GUER Takistan Port — Slice 2/4 (gate + config + client)

**Brain task:** `guer-merge-takistan-port-s2` (claimed by claude-main 2026-06-17).
**Branch:** `claude/guer-merge` (worktree `C:/Users/Steff/a2wasp-guermerge`).
**Scope:** MECHANICAL mirror of GUER gate+config+client hunks Chernarus→Takistan. NOT mission.sqm (slice 3).
Gate `WFBE_C_GUER_PLAYERSIDE` default OFF; every block must be a gate-OFF no-op. Branch-only, no deploy.

## Ground truth
- Player-GUER commit block = **33 commits**, base `8a395f889` (B39, pre-GUER) → tip `e1f5ab335` (slice 1).
- Full GUER surface on Chernarus = **25 files**.
- Slice 1 (e1f5ab335) already mirrored **5 server files** to Takistan:
  server_town.sqf, Init/Init_Server.sqf, PVFunctions/RequestOnUnitKilled.sqf, Server_GuerStipend.sqf, Stats/StatsFlush.sqf.
- `mission.sqm` = OUT (slice 3).
- Remaining = **19 files** → triage below.

## Maps
- CH source: `Missions/[55-2hc]warfarev2_073v48co.chernarus/`
- TK target: `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/`

## TK routing facts (from _guer-build/JOURNAL.md)
- Takistan resistance routes to **Root_TKGUE.sqf** (faction index 2 = TKGUE), NOT Root_GUE.sqf.
- LoadoutManager REGENERATES: EASA_Init.sqf, Common_BalanceInit.sqf, Common_ReturnAircraftNameFromItsType.sqf, version.sqf — hand-edits erased.

## Slice-2 triage — FINALIZED (discovery workflow w9jayuzrm: 19 specs + completeness critic)

### PORT (15) — mechanical, gate-OFF no-op, faithful Chernarus mirror
1. Rsc/Parameters.hpp — gate lobby param (default 0=OFF)
2. Common/Init/Init_Common.sqf — WFBE_ISTHREEWAY gated on WFBE_C_GUER_PLAYERSIDE
3. Common/Init/Init_CommonConstants.sqf — gate const declaration + GUER colour override (PRESERVE TK FACTION_GUER=2 + supply-heli TK branch)
4. Common/Functions/Common_GetSideSupply.sqf — non-blocking resistance (anti-"Receiving mission" hang)
5. Common/Functions/Common_GetSideUpgrades.sqf — nil-guard zero array for resistance
6. Common/Config/Core_Units/Units_CO_GUE.sqf — GUER airport air pool (shared file, loaded by Root_GUE + Root_TKGUE)
7. Client/Functions/Client_GetClosestAirport.sqf — DELTA edit (file is multi-line; NOT wholesale)
8. Client/Functions/Client_OnRespawnHandler.sqf — resistance random-friendly-town respawn
9. Client/GUI/GUI_Menu.sqf — grey out commander/base/upgrade/economy/vote for resistance
10. Client/GUI/GUI_Menu_BuyUnits.sqf — 5 base-less buy guards (Depot pool)
11. Client/Init/Init_Client.sqf — 5 resistance guard hunks (GuerTempRespawnMarker confirmed TK sqm:4206)
12. Client/Module/Skill/Skill_Init.sqf — GUER skill classes (verbatim GUE_Soldier_*; TODO: reconcile to TK_GUE_* in slice 3 when slots defined → inert-but-harmless on TK)
13. Client/PVFunctions/CampCaptured.sqf — GUER_ID receives camp-capture markers
14. Client/PVFunctions/TownCaptured.sqf — GUER_ID receives town-capture markers
15. Server/FSM/server_playerstat_loop.sqf — telemetry side=3 + |td= (slice-1 server leftover, folded in)

### DEFER → slice 4 (4)
- Client/Module/EASA/EASA_Init.sqf — LoadoutManager REGENERATES it (hand-edit erased); Ka-137 belongs to slice 4
- Common/Config/Core/Core_GUE.sqf — Warlord roster must land in Core_TKGUE (TK index 2), else wrong namespace + duplicate-element diag
- Common/Config/Core_Root/Root_GUE.sqf — call-site is a DEAD write on TK (Root_TKGUE is the live resistance root)
- Common/Config/Core_Root/Root_GUE_PlayerOverlay.sqf — needs Root_TKGUE_PlayerOverlay variant (TK_GUE_* classnames) wired into Root_TKGUE

### Known parity caveats (exist on Chernarus too — NOT slice-2 regressions; faithful mirror)
- WFBE_GUERAIRPORTUNITS is read but never written anywhere (Chernarus gap) → GUER airfield buy list empty both maps until slice 4.
- Init_Client JIP Killed-EH block after the HQ-deploy guard runs for GUER clients → RPT noise on both maps when gate ON.
- GUER buy menu inert on TK until slice 4 (overlay deferred) — expected for a 4-slice plan.

## Verification (all green)
- Brace/paren/bracket parity TK==CH on all 15 ported files (Init_CommonConstants delta fully explained by
  the pre-existing, non-GUER `WFBE_C_VEHICLE_MARKINGS` Miksuu line that CH has and TK doesn't — out of scope).
- 3 wholesale-rewritten files (Client_GetClosestAirport, Common_GetSideSupply, Common_GetSideUpgrades) byte-identical to CH.
- A2-illegal scan clean (no inline `private _x=`, params, pushBack, isEqualType, allMapMarkers, remoteExec, createVehicleCrew).
- Complex-file diffs (Init_Client 5 guards, GUI_Menu, GUI_Menu_BuyUnits, Init_CommonConstants) reproduce the
  reviewed Chernarus GUER hunks line-for-line.
- Scope: exactly 15 files changed, all under the Takistan tree; 0 Chernarus files, 0 DEFER files touched.
- GuerTempRespawnMarker confirmed present in TK mission.sqm:4206 (Init_Client respawn fallback is safe).

## Working state — DONE
Slice 2 applied + verified + committed on claude/guer-merge (branch-only). PUSH HELD for Steff.
Next: slice 3 = Takistan mission.sqm (WFBE_L_GUE owner logic + 4 GUER slots, TK positions/classnames).
Then slice 4 = Root_TKGUE_PlayerOverlay (TK_GUE_* roster) + Core_TKGUE Warlord roster + EASA Ka-137 via LoadoutManager + smoke.
Slice-3 follow-up: reconcile Skill_Init GUER classnames GUE_Soldier_* -> TK_GUE_* once TK slots are defined.
