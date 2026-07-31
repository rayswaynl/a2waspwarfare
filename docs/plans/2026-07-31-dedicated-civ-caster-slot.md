# Dedicated CIV Caster Slot Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add one dedicated, flag-gated CIV caster slot to each maintained terrain that bypasses combat enrollment and enters the existing UID-allowlisted spectator path.

**Architecture:** Identify the slot with a unit-local setVariable stamp in mission.sqm, which is available in Arma 2 OA 1.64 without A3-only role metadata. An early Init_Client.sqf branch parks that body at the shared fixed GuerTempRespawnMarker, clears the join blackout, bypasses all enrollment/deadspawn/lobby-lock code, and polls the existing spectator UID allowlist every 60 seconds. A single common real-player predicate excludes both HC bodies and the stamped caster; Common_RealPlayers/Near and direct human-count/proximity consumers use that predicate.

**Tech Stack:** Arma 2: Operation Arrowhead 1.64 SQF, mission.sqm, Python structural tests, PowerShell LoadoutManager mirror generation.

---

### Task 1: Establish red test and source contract

**Files:**
- Create: Tools/Lint/test_caster_slot.py
- Create: docs/plans/2026-07-31-dedicated-civ-caster-slot.md

**Steps:**

1. Test the three mission trees for a CIV Functionary1 caster group after both HC groups, exact description/init stamp, no forceHeadlessClient, and contiguous Groups.items/ItemNN numbering.
2. Test the default-off flag, early client branch, shared predicate registration, and no forbidden disableSerialization/hintSilent in the new caster branch.
3. Run python -m pytest Tools/Lint/test_caster_slot.py -q and confirm it fails because the slot, flag, branch, and predicate do not yet exist.

### Task 2: Implement client branch and shared exclusion

**Files:**
- Modify: Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Init/Init_Client.sqf
- Modify: Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf
- Modify: Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_Common.sqf
- Create: Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_IsRealPlayer.sqf
- Modify: Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_RealPlayers.sqf
- Modify: Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_RealPlayersNear.sqf

**Steps:**

1. Add WFBE_C_SPECTATOR_CASTER_SLOT = 0 as an appended default registration with explicit flag-off behavior documentation.
2. Register the A2-safe shared predicate before its consumers. Exclude stamped caster bodies, known HC names, and registered HC groups while preserving caller-owned alive/side filters.
3. Add the earliest safe caster branch after the null-player guard. With the flag armed, clear the black fade, set allowDamage false and setCaptive true, park at GuerTempRespawnMarker, compile only the existing spectator path needed by this early exit, and auto-call it for allowlisted UIDs. Non-allowlisted bodies receive a cutText reservation message and recheck every 60 seconds.
4. Keep all existing non-caster flow text and ordering unchanged outside the gated branch.

### Task 3: Cover human-count, credit, spectator-target, and proximity consumers

**Files:**
- Modify the Chernarus source counterparts of the existing HC-name/direct human consumers, including Common_CreditSidePlayers.sqf, Server/Stats/StatsFlush.sqf, Server/Server_AicomSupplySquad.sqf, Server/Server_USVFlotilla.sqf, Server/Init/Init_NavalHVT.sqf, Server/Init/Init_Server.sqf, kill-credit checks, and spectator target builders.

**Steps:**

1. Route aggregate player lists and proximity vetoes through WFBE_CO_FNC_RealPlayers/WFBE_CO_FNC_RealPlayersNear so the parked CIV caster cannot count as a combatant or nearby human.
2. Route remaining direct HC-name human checks through WFBE_CO_FNC_IsRealPlayer, leaving HC registration-identification code unchanged.
3. Re-scan all WFBE_C_HC_NAMES, Common_RealPlayers*, playable-unit counts, side-credit, and WASPSCALE player-count sites for missed human consumers.

### Task 4: Add and validate terrain slots

**Files:**
- Modify: Missions/[55-2hc]warfarev2_073v48co.chernarus/mission.sqm
- Modify: Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/mission.sqm
- Modify: Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/mission.sqm

**Steps:**

1. Add exactly one CIV Functionary1 playable group after the two HC groups, with the caster description, local init stamp, and no forceHeadlessClient.
2. Re-close each Groups.items count and group ItemNN sequence.
3. Run the brace-walk validator for each terrain.

### Task 5: Mirror and verify

**Steps:**

1. Run dotnet run -c RELEASE from Tools/LoadoutManager after the source SQF edit.
2. Restore only any generated TK/ZG version.sqf.template drift and verify TK/ZG constants.
3. Run focused pytest, the mandated SQF lint gate, delimiter/prose/layer scans, source/mirror parity, and flag-off structural identity checks.
4. Review the final diff and commit exactly feat(spectator): dedicated CIV caster slot [flag WFBE_C_SPECTATOR_CASTER_SLOT default 0] without an attribution trailer.
