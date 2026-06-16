# GUER "Insurgents" Playable Faction — Build Journal

**Goal:** implement `claude-bridge/GUER-BUILD-SPEC.md` (locked, Ray Q&A 2026-06-15) — a 4-slot harass-only
3rd playable faction (RESISTANCE/GUER), gated behind `WFBE_C_GUER_PLAYERSIDE` (default 0=OFF).
**Branch:** `feat/guer-insurgents-faction` off `origin/claude/b36-chernarus` (B36 comeback patrols = lifeline).
**Worktree:** `C:/Users/Steff/a2wasp-guer`. **Mission root:** `Missions/[55-2hc]warfarev2_073v48co.chernarus/`.
**Brain item:** `guer-insurgents-playable-faction` (claimed by claude-main; codex-gaming lane, dormant).

## Locked decisions (Steff 2026-06-15)
1. FULL spec in one pass (incl. telemetry board).
2. Ka-137 = Recon + ARMED AT/AA (cap 2). UPDATED 2026-06-15: build the armed variants now — research armed
   classnames, wire via the EASA system, prefer MANUAL FIRE by the pilot (player-controlled, not AI auto-engage).
   (Was "defer armed"; Steff reversed it.)
3. FULL WEST/EAST slot cut 27→14 each (ratio Eng4/Med3/Sol3/Sup2/Sniper2); same mission.sqm pass.
4. FULL GUER telemetry board (harass K/D + towns-denied) now.

## Step-0 verification (spec vs real tree) — DONE, spec holds
- `WFBE_ISTHREEWAY = false` @ Init_Common.sqf:292 ✓ (spec exact)
- `WFBE_C_GUER_ID = 2` @ Init_CommonConstants.sqf:32 ✓
- `WFBE_C_GUER_COLOR="ColorBlue"` @ L607 AND L613 (spec said 620/626 — DELTA; two set-sites, handle real lines)
- gate const goes in the `with missionNamespace do {` block @ Init_CommonConstants:73 ✓
- mission.sqm: items=129 ✓; LocationLogicOwnerWest @3852, East @3871; GuerTempRespawnMarker @4962 ✓
- ALL classnames exist: GUE_Soldier_Sab/Sniper/Medic; Offroad_DSHKM_Gue, Pickup_PK_GUE, Offroad_SPG9_Gue,
  BRDM2_Gue, T55_TK_GUE_EP1, T72_Gue, Ka137 ✓

## Build checklist
- [x] Step 1: gate const (Init_CommonConstants:76) + Parameters.hpp param (587) — commit 205e8e9c6
- [x] Step 2: gated WFBE_ISTHREEWAY (Init_Common:292) — commit bb4a6c454
- [ ] Step 3: mission.sqm — OwnerGuer logic (id 308) + 4 RESISTANCE slots (id 309-312) + W/E 27→14 cut + items/sync bookkeeping
- [ ] Step 4: NEW Server/Server_GuerStipend.sqf (150/min, +10/min per town below start, cap 3x)
- [ ] Step 5: NEW Common/Config/Core_Root/Root_GUE_PlayerOverlay.sqf (buy-pool repoint + per-role gear + time-tier vehicles)
- [ ] Step 5b: server WFBE_GUER_VEHICLE_TIER broadcast loop (Flag C robust delivery) — fold into stipend loop or own loop
- [ ] Step 6: Init_Server GUER team-registration + editor-slot-tag extension + stipend exec
- [ ] Step 7: Skill_Init GUER classes → Engineers/Spotters/Medics (gated)
- [ ] Step 8: resistance marker-color branch (Init_CommonConstants) + confirm zero GUER side econ
- [ ] Step 9: Root_GUE.sqf loads the overlay (player block, gated)
- [ ] Telemetry: per-player harass K/D + towns-denied accumulator; broadcast; diag_log for :8080 dashboard; Top-PvP
- [ ] Verify: bracket balance + A2-illegal grep on every changed file; gate-OFF regression check; spec §9 static walk
- [ ] Ship: commit; HOLD push for Steff consent. In-engine 4-slot playtest = Steff (no auto game launch).

## Ka-137 EASA plan (researched 2026-06-15)
EASA = loadout-swap (EASA_Init.sqf: parallel _easaVehi/_easaDefault/_easaLoadout arrays; row =
[price,label,[weapons[],mags[]]]; line ~667 auto-tags AA; line ~668 exports). Manual fire CONFIRMED
(addWeapon to vehicle, Ka-137 has no gunner turret → pilot fires). Use **Ka137_MG_PMC** (armed, pilot-flyable).
Register before EASA_Init.sqf:667, gated on WFBE_C_GUER_PLAYERSIDE. Loadouts:
- [MR] Recon: stock MG (Ka137_MG / 100Rnd_762x54_PKT — UNCONFIRMED classname, verify in-engine via diag_log weapons)
- [AG]: AT9Launcher/4Rnd_AT9_Mi24P + 57mmLauncher/64Rnd_57mm  (both CONFIRMED in existing EASA rows)
- [AA]: Igla_twice / 2Rnd_Igla x2  (CONFIRMED)
CAVEATS for the Hetzner dry-run (after 8AM): (1) confirm stock MG mag classname; (2) Ka-137 is a recon
airframe — missiles may fire from origin w/o pylon proxy; fallback = 57mm rockets only. cap 2 alive (buy-menu).

## Hetzner testing (Steff 2026-06-15)
After the FULL build: dry runs + test + improve on the Hetzner box (78.46.107.142) — but ONLY AFTER 8 AM.
Do NOT deploy/test there before 8 AM.

## Constraints
A2 OA SQF only (NO inline `private _x=`, params, pushBack, isEqualType, allMapMarkers, select{}, remoteExec).
Do NOT touch: B36 comeback patrols, AI-GUER faction config, WASP-NEXT. Takistan = regen later, no hand-edit.

## BUILD COMPLETE (2026-06-15 overnight) — all steps done, A2-safe, gated, ready for 8AM Hetzner test
Commits on feat/guer-insurgents-faction (off b36): step1 gate+param, step2 ISTHREEWAY, step3a sqm additions,
steps4-5 stipend+overlay, steps6-9 team-reg/skill/colors/overlay-load, Ka-137 EASA, telemetry (side=3 + towns-denied),
step3b W/E 27->14 cut. 13 files +346/-59. Verified: 0 A2-illegal constructs; all braces balanced; mission.sqm
items=134, 1215/1215; WEST14/EAST14/GUER4/HC2 slots.

### KNOWN ITEMS for the 8AM Hetzner dry-run (test + improve, after 8AM only):
1. Ka-137: confirm stock-MG classname (diag_log weapons on a spawned Ka137_MG_PMC); confirm missile fire
   geometry (AT9/Igla) on the recon airframe — fallback to 57mm rockets only if they fire from origin.
2. Ka-137 EASA reconfig needs a SERVICE POINT (base-less GUER has none) -> decide: GUER strongholds act as
   EASA points, OR buy the Ka-137 pre-armed. (It's buyable + pilot-MG-armed out of the box already.)
3. W/E cut is the SAFE de-slot (not full group-removal) + is ALWAYS-ON (not gated) -> W/E have 14 slots even
   with GUER off. If full group-removal (cleaner) is wanted, run after load-test (script: _guer-build/sqm_cut.py).
4. Per-role spawn gear (WFBE_GUER_DefaultGear_*) is SET; confirm the respawn system applies the right one by role.
5. Stronghold-only buy-location gate (buy only at fully-held GUER towns) — not yet enforced; verify/refine.
6. cap-2-alive Ka-137 + towns-denied dashboard rendering (box-side parser must learn side=3 + |td=).
7. Box-side dashboard parser update (side=3 GUER cohort + td= field) — separate, box-side.

## HARDENING PASS (post-build adversarial review, 2026-06-16) — 25 candidates -> 9 confirmed; 4 FIXED + committed (0920d8197, pushed)
FIXED now (commit 0920d8197):
- CRITICAL: Root_GUE_PlayerOverlay gear keys `DefaultGear_Engineer/Sniper/Medic` -> `DefaultGearEngineer/Spot/Medic`
  (must match Client_OnRespawnHandler Format keys; old keys -> nil -> `count nil` crash -> NAKED respawn every death).
- HIGH: Init_Server:591 GUER team `wfbe_side` stored string "GUER" -> `resistance` side value (+broadcast); fixes GetSideID -> -1.
- HIGH: mission.sqm 6 medic de-slot inits had `deleteVehicle this` spliced INSIDE `setVariable[]` (cut-script regex
  bug — `[^"]*` stopped at the escaped `""`); rewritten as sequential statements. sqm_cut.py regex fixed too.
- MEDIUM: server_playerstat_loop `|td=` now appended only when WFBE_C_GUER_PLAYERSIDE>0 (vanilla keeps 10-field
  format); docstring documents side=3 + conditional td field.

### DISCOVERED ISSUES — deferred (note for the 8AM session / post-test):
- MEDIUM (mission.sqm GUER slots 312-315 not gate-suppressed when gate OFF): a player joining a GUER slot with the
  gate OFF spawns as an armed GUE soldier with no economy. NOT fixed via .sqm init because `WFBE_C_GUER_PLAYERSIDE`
  may not be readable when slot-init fields fire -> could wrongly delete the GUER slots even with gate ON (would break
  today's gate-ON test). PROPER FIX = server-side delete-on-OFF block in Init_Server (param-timing-safe). Gate-ON
  test is unaffected. Verify param-read timing first.
- LOW (Init_CommonConstants marker-color block runs on dedicated server where player==objNull -> wrong else-branch):
  pre-existing display-only block; wrap `if (!isServer)`. Cosmetic/server-debug only.
- LOW + OUT-OF-LANE (PRE-EXISTING, NOT my file): Server/Config/Config_GUE.sqf:63-79 — the 4th AI reserve team
  template uses PMC_* classnames (DLC-gated; nil price) instead of GUE_*. This is the AI-GUER config which the build
  charter says DO NOT TOUCH. Flag to Steff as a pre-existing repo bug; do not fix here.
- REJECTED/DOWNGRADED: 12 rejected + 4 downgraded by adversarial verify (A2 false-positives etc.).

## TAKISTAN PORT (answer to Steff's question, 2026-06-16) — investigated, NOT started (Takistan = regen-later)
- On Takistan the resistance side is **TKGUE** (Takistani Guerrillas, `TK_GUE_*_EP1`), NOT PMC. Mechanism: Takistan's
  version.sqf has IS_CHERNARUS_MAP_DEPENDENT commented out -> `WFBE_C_UNITS_FACTION_GUER = 2` -> index 2 of
  ['GUE','PMC','TKGUE'] -> Root_TKGUE.sqf. PMC (index 1) is a dead/reserve config — no code path selects it.
- LoadoutManager (Tools/LoadoutManager) = wholesale recursive COPY Chernarus->Takistan, then overwrites 4 generated
  files (EASA_Init.sqf, Common_BalanceInit.sqf, Common_ReturnAircraftNameFromItsType.sqf, version.sqf) + patches
  Init_Server SET_MAP 1->2. It NEVER touches mission.sqm (FileManager skip) or Parameters.hpp.
- So to ship GUER on Takistan: (1) Ka-137 EASA block will be ERASED on every LM run (EASA_Init is regenerated) ->
  add Ka137_MG_PMC to the C# vehicle registry OR post-gen append; (2) faction routing — Takistan loads Root_TKGUE not
  Root_GUE, so Root_GUE_PlayerOverlay is never reached -> either add Root_TKGUE_PlayerOverlay OR reroute GUER index;
  (3) hand-add LocationLogicOwnerGuer + 4 RESISTANCE slots to Takistan mission.sqm (Takistan positions, ideally
  TK_GUE_*_EP1 classnames); (4) run LoadoutManager; (5) verify Ka-137 survived; (6) Takistan smoke. Also check
  WFBE_C_MODULE_BIS_PMC default on Takistan (Ka137_MG_PMC is PMC-DLC-gated there).

## Working state
Steps 1-2 DONE + committed (both bracket-balanced). NEXT = Step 3, the mission.sqm surgery (highest risk):
add LocationLogicOwnerGuer (id 308, text WFBE_L_GUE, near OwnerWest@3852/East@3871) + 4 RESISTANCE player
slots (GUE_Soldier_Sab x2 / Sniper / Medic, id 309-312, synced to 308); cut WEST 27->14 + EAST 27->14
(keep Eng4/Med3/Sol3/Sup2/Sniper2 ratio); bump items=129 accordingly; repair OwnerWest/East
synchronizations[] after the cut. Approach: read the W/E player-slot group blocks + the two owner-logic
sync lists FIRST, map every id, then make the edits surgically (no reformat — flat numbered .sqm).
Then steps 4-9 + telemetry. HOLD push for Steff. Playtest = Steff (no auto game launch).
