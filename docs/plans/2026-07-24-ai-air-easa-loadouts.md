# AI Air EASA Loadouts Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Establish whether AICOM air can safely receive EASA payloads, and stage a default-off implementation only after an OA 1.64 locality and weapon-employment proof.

**Architecture:** The EASA catalog is client-compiled, but founded AICOM teams already use a separate server/HC-local, explicit equipment table. That table currently equips researched Su-34/Su-25 teams with FAB-capable kits. Refills and AICOM2 response flights bypass it. Any extension must use the established local direct-kit pattern (or a carefully extracted common equivalent), never the player/carrier `EASA_Equip` call; selection remains an explicit per-airframe allowlist.

**Tech Stack:** Arma 2 OA 1.64 SQF, existing EASA catalog, AICOM purchase/order scripts, LoadoutManager mirrors, HC RPT evidence.

---

## Audit verdict (2026-07-24)

### What AICOM air receives today

- Founded AICOM teams already receive a server/HC-local EASA-derived kit after their hulls are created. `Common/Functions/Common_RunCommanderTeam.sqf:342-420` gates it on `WFBE_C_AICOM_EASA_AI` and an actually researched EASA upgrade, then uses an exact stock/remove + kit/add table only on local, alive air hulls. `Common/Init/Init_CommonConstants.sqf:1170` currently sets that existing feature's default to **1**, not 0. It deliberately does not set `WFBE_EASA_Setup`, because the player rearm index contract is incompatible with this independent table.
- The founded table already gives `Su34` and `Su25_TK_EP1` FAB-250 kits (`Common_RunCommanderTeam.sqf:377-380`). Therefore the correct current answer is: qualifying founded AICOM jets can be configured with FAB weapons after EASA research, but this audit has no RPT proof that OA AI releases them.
- Normal AICOM refills reach `Server/Functions/Server_BuyUnit.sqf`: it creates the hull on the server/HC purchase path (lines 261-275), selects a pilot for any `Air` class (261-265), and applies the normal balance, countermeasure, and AA-removal policies (354-381). It does not run the founded-team EASA table or call `EASA_Equip`.
- AICOM2 response flights are a third path: `Server/AI/Commander/AI_Commander_AirResp.sqf:199-238` chooses an allowlisted attack class, creates/crews it, patrols it, and sets COMBAT/RED. It does not apply either EASA mechanism. Its optional attack-heli gunner is independently default-off (221-228), so helicopter weapon employment must be tested with the actual seat configuration.
- The only random EASA assignment is player carrier purchasing in `Client/Functions/Client_BuildUnit.sqf:710-747`; its own comment identifies `EASA_Equip` as client-side/local (718). The naval CAP exception stamps `wfbe_naval_easa_pending`, then every client-side `Common/Init/Init_Unit.sqf:368-379` observes and applies it. This is a synchronization pattern for that special flow, not a server/HC equipment API.
- EASA itself is compiled in `Client/Init/Init_Client.sqf:1382`. `Client/Module/EASA/EASA_Equip.sqf:8-37` finds an exact vehicle classname, removes its previous/default weapons and magazines, adds the selected payload, and broadcasts `WFBE_EASA_Setup`. It contains two turret-only exceptions (26-34). It is not registered on the server/HC path.
- Existing rearm scripts will reapply an already-set EASA index (`Common_RearmVehicle.sqf:65-69`, OA variant:64-68), but do not choose an initial AI preset.

### FAB and helicopter catalog facts

- `Mi24_P` is in the EASA catalog. Its default contains `HeliBombLauncher` with `2Rnd_FAB_250`; its two FAB-bearing selectable rows use `AirBombLauncher` with `4Rnd_FAB_250` and `2Rnd_FAB_250` (`Client/Module/EASA/EASA_Init.sqf:639-647`). The founded AICOM table currently replaces that Mi-24P FAB stock loadout with Ataka + Igla (no FAB) at `Common_RunCommanderTeam.sqf:370-371`. That confirms a helicopter FAB catalog exists, not that AICOM helicopters presently retain or release it.
- Fixed-wing catalog rows include MK-82 and GBU-12 combinations (for example `EASA_Init.sqf:494-569`). The catalog is indexed by exact class, so a valid index only proves the row matches that hull, not that it is appropriate for every AICOM mission or faction doctrine.

### What the code proves about employment—and what it does not

- AICOM orders attacking helicopter gunners to select a cannon muzzle, target, and `doFire` a revealed target in `Common/Functions/Common_RunCommanderTeam.sqf:197-245`. Fixed-wing teams receive fly height, combat posture, and orbit/attack movement around the objective (1370-1398 and 1803-1813). The general team combat path also uses `doTarget`/`doFire` (1984-1986).
- This demonstrates that AICOM exposes targets and issues firing orders. It does **not** prove OA 1.64 will select/release the FAB or bomb muzzle from an altered payload. BI’s weapon configuration reference says AI ammo/mode choice depends on range, ammo costs, target/threat, lock availability, and other configuration inputs; an EASA row alone is insufficient evidence. The official command documentation also warns that some forced-fire behavior is version/locality-sensitive.
- Therefore this audit makes no claim that AI currently drops FABs, nor that simply adding `AirBombLauncher` will make it do so. The required RPT/game evidence is below.

## Recommended implementation: two gated stages

### Stage A: prove the engine contract before changing gameplay

**Files:**

- Create: `Tools/Lint/test_aicom_easa_air_contract.py`
- Create: a local/offline OA 1.64 mission-test script under the established test harness, with an HC-local and server-local case
- Read: `Common/Functions/Common_RunCommanderTeam.sqf`, `Server/Functions/Server_BuyUnit.sqf`, `Client/Module/EASA/EASA_Equip.sqf`

**Step 1: Write the failing static contract test.**

Assert the current contract separately for founded teams, refills, and AIRRESP: (a) the existing founded-team flag and EASA research gate remain unchanged, (b) no server/HC code calls the client-only `EASA_Equip`, (c) an eventual default-zero AIRRESP/heli extension has an explicit `Mi24_P` FAB allowlist, and (d) every new assignment emits an always-on structured RPT marker plus an observed `Fired` receipt.

**Step 2: Run it and verify it fails because the implementation is absent.**

Run: `python Tools/Lint/test_aicom_easa_air_contract.py`

Expected: failure describing the missing response/heli extension allowlist and RPT contract. The pre-existing founded-team contract should pass unchanged.

**Step 3: Run the OA test matrix before code is authorized.**

For each case, spawn an AI-owned founded `Su34`/`Su25_TK_EP1` with the existing kit, then an AI-owned `Mi24_P` with stock and each FAB candidate; repeat the intended AIRRESP path separately. Execute once server-local and once HC-local, issue the existing AICOM-style `reveal` / `doTarget` / `doFire` order against a ground target, and capture a single `MISSINIT`-bounded HC RPT window.

Required evidence per row: vehicle locality, selected weapon/muzzle, magazine count before/after, `Fired` event weapon and ammo, target coordinates, and no script error. A row that never emits a bomb `Fired` event is excluded from Stage B—not repaired by forced-fire commands.

### Stage B: implement only proven, curated rows

**Files:**

- Modify: `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf`
- Modify: `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_RunCommanderTeam.sqf` only if Stage A shows the existing founded-kit table needs a proven Mi-24 FAB row
- Modify: `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_AirResp.sqf` for a new AIRRESP-only extension
- Test: `Tools/Lint/test_aicom_easa_air_contract.py`

**Step 1: Keep the feature inert by default.**

Append a new `WFBE_C_AICOM_EASA_AIRRESP = 0` only. Do not alter the pre-existing founded-team flag (currently 1) or the player/carrier EASA code path without an owner decision.

**Step 2: Write the minimal locality-safe executor.**

The extension must run where the vehicle is local, remove/add only the explicitly tested weapon/magazine pair for an exact airframe, and emit one structured assignment marker. Follow the founded-team table's intentional rule: do not set `WFBE_EASA_Setup` for AI. It must use the correctly proved turret path when required. Do not call `EASA_Equip` from the server or HC merely because it is available on player clients.

**Step 3: Select only validated doctrine rows.**

Use a per-class table, initially no more than the FAB-bearing `Mi24_P` row(s) and any fixed-wing row that passed Stage A. The current founded Su-34/Su-25 FAB entries are the baseline cases, not a reason to broaden selection. Selection can be deterministic by doctrine/side; random selection is allowed only among the already-proven entries for that exact classname. Do not use an unconstrained `floor random count _easaLoadouts` draw.

**Step 4: Run the contract test and OA matrix again.**

Run the static test, then the same server-local and HC-local RPT matrix. Verify the flag-off byte path is unchanged, every selected row produces the expected `Fired` evidence, and no unvalidated row is selected.

**Step 5: Mirror and preflight only after Stage B is green.**

Run `A2WASP_SKIP_ZIP=1 dotnet run -c RELEASE` in `Tools/LoadoutManager`, restore the two terrain templates if they drift, run the mandatory SQF lint gate, delimiter checks, and `dotnet run -c RELEASE -- --check`. Submit a draft PR with the RPT evidence attached; never deploy from the lane.

## Rejected shortcuts

- Calling `EASA_Equip` in `Server_BuyUnit.sqf` or an HC script: it is client-compiled and relies on client-side catalog state.
- Broadcasting a pending index to every client and letting each client mutate a normal AICOM hull: it does not establish a single authoritative equipment owner.
- Enabling every catalog row or assuming a FAB row is safe because it exists: catalog membership and ammunition count are not AI employment proof.
- Adding forced-fire behavior to compensate for a failed FAB trial: it would be new combat logic outside this owner ask and needs separate evidence/design.

## Current delivery decision

This documentation-only draft records the audit and the safe enablement boundary. No mission SQF, mirror, or runtime behavior is changed; a gameplay PR remains gated on the Stage A RPT matrix.
