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

## Working state
Steps 1-2 DONE + committed (both bracket-balanced). NEXT = Step 3, the mission.sqm surgery (highest risk):
add LocationLogicOwnerGuer (id 308, text WFBE_L_GUE, near OwnerWest@3852/East@3871) + 4 RESISTANCE player
slots (GUE_Soldier_Sab x2 / Sniper / Medic, id 309-312, synced to 308); cut WEST 27->14 + EAST 27->14
(keep Eng4/Med3/Sol3/Sup2/Sniper2 ratio); bump items=129 accordingly; repair OwnerWest/East
synchronizations[] after the cut. Approach: read the W/E player-slot group blocks + the two owner-logic
sync lists FIRST, map every id, then make the edits surgically (no reformat — flat numbered .sqm).
Then steps 4-9 + telemetry. HOLD push for Steff. Playtest = Steff (no auto game launch).
