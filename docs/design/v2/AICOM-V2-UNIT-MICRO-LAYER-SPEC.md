> **⚠ VERIFICATION CORRECTIONS (Fable claims-audit, 2026-07-06) — read before executing work orders:**
> 1. **PR-WO-1 (#548) reframed:** `wfbe_aicom_econ_surge` is NOT missing — `AI_Commander.sqf:623` already sets it. #548 adds an independent FundsSink-cadence trigger (additive value, not a correctness fix). 
> 2. **EXT-1 (pacing):** the spec's claims about `WFBE_C_AICOM_MARCH_YELLOW` coverage were inaccurate — re-verify the current march-discipline implementation before building transit-posture work.
> 3. **EXT-4:** `land "GET OUT"` claims must be re-verified against RunCommanderTeam — the audit found the "NOT YET IMPLEMENTED" claim unsafe.
> Minor: verify `ATV_US_EP1 isKindOf Motorcycle` in-config and the `Core_CO_US.sqf:143` citation before executing WO-5. Full audit in the verification transcript.

# AICOM V2 Unit Micro-Layer — Spec &amp; Work Orders

Guide-rev: GR-2026-07-03a. Research date: 2026-07-06. Worktree: `C:\Users\Steff\a2wasp-fable-push`. Read-only; zero edits made.

---

## 1. How to read this document

Each topic section opens with **Current-state evidence** (file:line citations from the actual code), then a **Design proposal** written as a bounded work order. Work orders that touch only `Common_RunCommanderTeam.sqf` or `Common_AICOMServiceTick.sqf` are labelled **PRE-CUTOVER SAFE** — they live in the Common driver layer, which survives the one-shot cutover unchanged. Work orders that touch `AI_Commander_*.sqf` commander files are **FOLD-INTO-V2 CUTOVER** items. The 8 open PR fold-ins are a separate section. Non-goals are stated last.

---

## 2. Current-state evidence — topic by topic

### 2.1 Driver states: mount/dismount, stuck ladder, driver-replacement, smoke

`Common_RunCommanderTeam.sqf` is the master driver file. All evidence below is from the Chernarus copy at that path.

**Mount-up (ground):** Lines 730-838 implement a "GROUND MOUNT-UP" feature. Before the order loop, the driver iterates `_grndVehs`, builds `_ridePool` of drivable ground vehicles with free cargo seats (`canMove _x` + `emptyPositions "cargo" > 0`, line 787), then assigns on-foot infantry via `assignAsCargo` + `orderGetIn true` (lines 791+). A GUER-avoid path-check (lines 748-783) skips the seat-fill if a hostile town lies within a danger band of the drive line — infantry march on foot instead.

**Air insertion (own-heli):** Lines 287-729 implement a full heli air-insert block. The team's own transport heli (`transportSoldier > 0`, line 310) is identified. Foot pax load via `assignAsCargo` + `[_x] orderGetIn true` (lines 489-495). Overflow walks. The hot-LZ paradrop decision (lines 507-565) scans the LZ for enemy presence or non-owned town ownership and, when hot, forces a paradrop by setting `_lzPos` to an offset point and `_flat = []` so the existing eject branch fires. The heli uses `doMove _lz` + `flyInHeight 60` (lines 605-606) for run-in.

**Arrival smoke (assault onset):** Lines 1490-1527. When the team latches arrival on a towns-target order, `createVehicle [_asCls, _asP0, [], 0, "NONE"]` (x2) places two faction-coloured smoke shells 45–60 m ahead of the leader toward `_dest`. Rate-limited via `wfbe_aicom_smoke_last` group variable (lines 1502-1524). Faction colours: WEST `SmokeShell`, EAST `SmokeShellRed`, GUER/default `SmokeShellGreen` (lines 1507-1511).

**Break-off smoke:** Lines 2057-2095. When the team drops below `WFBE_C_AICOM_BREAKOFF_MIN` live units (default 3) with enemy nearby, two covering smoke shells are placed in a ~15 m arc around the leader oriented toward the nearest enemy, then `wfbe_aicom_wantrally = true` is broadcast (line 2056). Same rate-limit + same group-var stamp as assault smoke.

**Dead-driver swap (RECOVERY V2):** Lines 1004-1017. Inside the stuck-recovery Spawn (which fires on a fresh stuck re-issue, not per-tick), `cmdcon41-w3e` implements: if the lead hull is alive + `canMove` but its driver is dead/null, iterate `crew _uVeh` and call `_swapPick moveInDriver _uVeh` (line 1014) on the first live non-player crewman. This runs HC-locally where the group and hulls are local.

**Stuck ladder (tiers 1-3):** Lines 939-1100 (approx). Tier read from `_order select 3` (line 950). Tier 1: `_uVeh setVelocity [0,0,0]` + reverse-velocity pulse along `-vectorDir` + wfbe_aicom_lanejit sign flip (lane-flip re-path, from LANE-FLIP in cmdcon41-w3e). Tier 2: fresh road route (re-snap from current pos). Tier 3 (>= 3): road-snap teleport of the lead hull onto the nearest clear non-water road node, only when no player is within 300 m. Water guard: `surfaceIsWater` on hull/leader forces tier-3 immediately (lines 1000-1002). Every tier ends with the road route below — always holds a move.

**Self-repair (vehicle):** Lines 840-875. Gate `WFBE_C_AICOM_VEHICLE_SELFREPAIR` (default 1). For each alive local `LandVehicle` where `!(canMove _x)` and crew is alive: if no enemy within `WFBE_C_AICOM_SELFREPAIR_SAFE_DIST` (250 m) and leader not in COMBAT, stamp `wfbe_aicom_repair_at = time`. After `WFBE_C_AICOM_SELFREPAIR_DELAY` (30 s), call `_srVeh setDamage 0`. Enemy appearance cancels the stamp (line 869). This is `setDamage 0`, i.e. full hull restore, not a partial fix.

### 2.2 Service tick: rearm/repair triggers

`Common_AICOMServiceTick.sqf` (207 lines total).

**Trigger conditions (IDLE branch, line 101+):** Not pulled from a firefight (`behaviour _ldr != "COMBAT"`, line 109), enemy count within `WFBE_C_AICOM_SVC_TRIGGER_DIST` (300 m) = 0 (line 108). The ALLTEAMS extension (cmdcon41-w2, line 120-141) also admits foot teams when alive count < 0.5 × TEAM_SIZE OR any member is wounded past `_dmgT`. Needs-service check (line 143-157): any member `getDammage > _dmgT` (0.5), OR a combat vehicle's `GetAmmoFraction < _ammoT` (0.35).

**What triggers service:** damage OR low ammo on a combat vehicle. There is NO front-stabilization gate, NO "only after town loss" logic. It triggers opportunistically whenever the thresholds are met and the team is safe.

**Repair on arrival (line 74):** `{if (alive _x) then {_x setDamage 0}} forEach (units _team)` — full heal of every group member. Vehicles: `_x setDamage 0; _x setVehicleAmmo 1` (full rearm), plus `setFuel 1` for air. Artillery gets a tier-fraction rearm via `WFBE_C_AICOM_ARTY_AMMO_FRAC` (line 85-87).

**These commands are confirmed A2 OA compatible** — `setDamage`, `setVehicleAmmo`, `setFuel`, `getDammage` (double-m is correct A2 spelling; CLAUDE.md confirms this), `nearEntities`, `behaviour` are all used throughout the codebase.

### 2.3 Transport: how infantry teams get vehicles today

**At founding (AI_Commander_Teams.sqf):**

INF-TRANSPORT wire (Build83, lines 913-997): when `WFBE_C_AICOM_INF_TRANSPORT = 1` and the picked template is pure infantry (no ground vehicle hull) and the nearest uncaptured town is beyond `WFBE_C_AICOM_ASSAULT_REACH_FOOT` (3500 m) of the HQ, one faction troop-truck is prepended to a copy of the template. Classname from `WFBE_%1REDEPLOYTRUCKS` (MTVR for WEST, Kamaz for EAST; GUER falls back to V3S variants). Common_CreateTeam then spawns and crews the truck, giving AssignTowns a `REACH_MOUNTED` (9000 m) team.

**Combined groups:** There is no dedicated pickup/combined-group logic in the codebase. Teams are founded as self-contained units. The INF-TRANSPORT wire is the only existing mechanism that attaches a transport to an infantry team. There is no code that merges separate infantry + transport groups after founding.

### 2.4 Composition: D4 target-aware, ATV/bike pool status

**D4 (AI_Commander_Teams.sqf lines 805-877, gate `WFBE_C_AICOM_TARGET_AWARE_COMP` default 0):**  
After the forced-arty override, D4 reads `wfbe_aicom_garrison` group's `wfbe_aicom_alloc_target` or iterates teams for a fallback. Garrison-heavy towns (`camps >= WFBE_C_AICOM_COMP_GARRISON_HEAVY`, default 3): boost templates containing Tank/Wheeled_APC/Tracked_APC by `_d4AtmgMult` (3.0). Open villages (`supplyValue <= WFBE_C_AICOM_COMP_OPEN_SV`, default 50): boost bClass-1 (mech/motorized) templates by `_d4MechMult` (2.5). Currently off by default.

**ATVs/bikes in the buy pool:** The USMC squad file (Squad_USMC.sqf, lines 303-316) registers one template called "Motorized - CROWS ATV Scout Section" containing `ATV_US_EP1` (x2) with `_aiTeamUpgrades = [[0,2,0,0]]` (light factory). The static-weapon strip in Teams.sqf (lines 409-423) does NOT strip ATVs — they would survive to the bucket. The ATV classname appears in player buy-unit configs too (`Core_US.sqf:90`, `Core_CO_US.sqf:143`). However, the AI founding filters strip templates by factory tier, upgrade mask, and the storedType/bucket system. An ATV template classified as bClass 1 (light) would compete against IFV/APC templates in the same bucket — the effectiveness-weighted draw (line 746) weights by BI `CfgVehicles cost`, and ATVs have a very low cost score, so they would almost never be picked in a competitive field. They are in the pool but effectively self-filtered out by the cost-weighted draw.

### 2.5 Softest-lane / post-town-loss targeting

**V1 (AI_Commander_AssignTowns.sqf, not read in full but inferred from Allocate context):** AssignTowns reads `wfbe_aicom_alloc_target` per team and dispatches. Without the V2 allocator, targeting is the legacy strategy worker.

**V2 allocator (AI_Commander_Allocate.sqf, full read):**

Expansion-first gate (lines 38-96): until `_myTowns >= WFBE_C_AICOM_ENGAGE_MIN_TOWNS` (10), the fist pool is restricted to soft neutral towns only (GUER-free neutrals preferred, then GUER-inclusive neutrals, then enemy if contested-engage fires). The `WFBE_C_AICOM_ENGAGE_CONTESTED` bug-fix (line 52) prevents perpetual neutral-chasing when the enemy is at parity or ahead.

CONCENTRATE gate (lines 241-244): until `_myTowns < WFBE_C_AICOM_CONCENTRATE_TOWNS` (4), `_expandN = 0; _harassN = 0` — full strength on one fist.

After a town loss: if the loss drops `_myTowns` back below `_engageMin`, the expansion-first gate re-engages and the fist shifts to neutral towns. If above `_engageMin`, the scored fist re-ranks with `_repickPen` (BUG-2 anti-dogpile, line 151) preventing dogpile on the recently-lost town. There is NO explicit "softest-lane push after losing a key town" logic — that behaviour would emerge from the scored fist picking the next highest-scoring capturable town, biased away from the recently-attacked one by the repick penalty and toward the nearest front.

---

## 3. Engine feasibility — dismount-repair-remount on A2 OA 1.64

### What is confirmed scriptable from existing codebase usage

- `setDamage 0` / `getDammage`: used extensively in ServiceTick (lines 74, 78, 136) and elsewhere. Fully restores vehicle health, including mobility. **Does NOT fix specific wheel hit-points independently; it restores the vehicle's total damage to zero.**
- `canMove`: used as the immobilisation check in Common_RunCommanderTeam lines 787, 841, 852. Returns false when the vehicle cannot move (engine destroyed, all wheels destroyed, flipped). Confirmed A2 OA.
- `setVehicleAmmo`: used in ServiceTick line 88-89.
- `setFuel`: used in ServiceTick line 90.
- `moveInDriver`: used in the dead-driver swap (line 1014). Confirmed A2 OA.
- `setVelocity`: used in tier-1 unstuck (the reverse pulse code block after line 1019).
- `createVehicle`: used for smoke shells throughout (lines 1522, 1523, 2090, 2091).

### What is NOT confirmed — wheel-damage specifics

**getHit / setHit on named selections** (e.g. `_veh getHit "HitLFWheel"`): **NOT found anywhere in this codebase**. This file uses `getDammage` (the vehicle's total damage scalar) and `canMove`. The A2 OA 1.64 scripting reference lists `getHit`/`setHit` for named selections, but they are not used in this mission. Whether wheel-damage is tracked independently in A2 OA 1.64 is **UNKNOWN from this codebase alone** — the game may expose `getHit "HitLFWheel"` but this mission has never needed to query it.

**Dismount-to-repair-action flow:** The existing self-repair (`WFBE_C_AICOM_VEHICLE_SELFREPAIR`) uses `setDamage 0` directly without any "unit dismounts, walks to vehicle, performs action" sequence. A true dismount-repair-remount flow — where AI dismounts, triggers the `action ["Repair", _veh]` command (which requires a repair truck in A2 OA), repairs individual components, then remounts — is **NOT implemented and NOT confirmed feasible** for scripted AI without a repair truck present. In A2 OA, the `action "Repair"` command requires an AI to be near a repair truck; there is no self-repair action for individual wheel hits. `setDamage 0` bypasses this entirely and is the practical approach.

**Conclusion on dismount-repair-remount:** Scriptable in the sense that you can: (1) unassign a unit from the vehicle, (2) call `vehicle doMove repairTruck` (if one exists) or simply wait a delay, (3) call `setDamage 0` on the hull, (4) call `_unit moveInDriver _veh` or `orderGetIn true`. But the "unit dismounts, physically walks to and repairs the wheel, remounts" fantasy is not achievable without a repair truck in vanilla A2 OA. The existing `setDamage 0` approach is correct and sufficient. Mark the "individual wheel repair without repair truck" scenario **UNKNOWN / likely not achievable in vanilla**.

---

## 4. Design proposals — work orders

Each work order specifies: objective, owner intent served, files, approach, flag, risks, sequencing.

---

### WO-1: Heavy+light combined groups at founding (transport choreography)

**Status:** PRE-CUTOVER SAFE (Common driver layer)  
**Owner intent:** "heavy/light infantry pickups and combined groups"  
**Current gap:** The INF-TRANSPORT wire (Teams.sqf Build83) attaches one unarmed troop-truck to a pure-infantry founding when the front is far. There is no mechanism for a combined mech group (IFV carries dismounts, IFV is the punch) at founding from a single template. The existing WFBE_DISMOUNT_BIAS (1.6×) already boosts dismount-carrying templates in the effectiveness-weighted draw (Teams.sqf line 748).

**Proposal:** No new founding code needed for the basic case — the bucket/effectiveness-weighted draw already prefers mech templates. The gap is in the mount-up choreography: when a team founds with both an IFV/APC and infantry, the GROUND MOUNT-UP at RunCommanderTeam lines 747-838 seats the infantry into the vehicle. This is already live. The improvement needed is the dismount-point decision at objective arrival.

**Work order (pre-cutover, Common_RunCommanderTeam.sqf):** Implement a dismount-point resolver in the arrival branch (around line 1436 where `_arrived = true` fires). When the team has a `_grndVeh` with passengers and the arrival is a towns-target, calculate a dismount point at `WFBE_C_AICOM_DISMOUNT_STANDOFF` (default 150 m) behind the target using garrison R-score data (existing `wfbe_town_type` tiering). Issue `_u unassignVehicle _veh; [_u] orderGetIn false; _u doMove _dismountPt` for each cargo unit, then `doMove _dismountPt` for the vehicle separately. The infantry advance on foot into the capture ring while the vehicle provides fire support from standoff. TTL: re-mount if the order changes before arrival.

**Flag:** `WFBE_C_AICOM_DISMOUNT_ASSAULT` default 0  
**Risk:** Dismount timing is event-driven (one call at arrival latch), no per-frame scan. Main risk: the vehicle drives forward past dismount point before infantry arrive at the capture ring — mitigated by `doMove` on the vehicle separately at the standoff point.  
**Sequencing:** Buildable now, pre-cutover.

---

### WO-2: Driver-killed → swap → smoke → continue (PRESERVE existing)

**Status:** ALREADY IMPLEMENTED — DO NOT DUPLICATE  
**Evidence:** `Common_RunCommanderTeam.sqf` lines 1004-1017 (dead-driver swap via `moveInDriver`) and lines 1490-1527 (assault smoke at arrival latch). The smoke fires faction-coloured shells at the arrival gate on a towns-target order. The driver swap fires inside the stuck-recovery Spawn when the lead hull is alive + canMove but has no live driver.

**What is missing from the owner's vision:** The smoke fires at *arrival*, not specifically when the driver dies mid-transit. The dead-driver swap fires on the stuck-recovery path (when the hull is physically stuck), not proactively when the driver is killed while driving.

**Work order (pre-cutover, Common_RunCommanderTeam.sqf):** Add a per-20s-tick check in the order loop: if the lead hull has `(isNull (driver _veh)) || {!alive (driver _veh)}` AND `canMove _veh` AND a live crewman exists, immediately: (1) `_swapPick moveInDriver _veh`, (2) pop one covering smoke shell near the hull (faction colour, rate-limited by existing `wfbe_aicom_smoke_last` stamp). This makes the swap proactive (mid-transit) rather than only reactive (stuck-recovery). The existing stuck-recovery path keeps its own dead-driver swap as belt-and-braces.

**Flag:** `WFBE_C_AICOM_PROACTIVE_DRIVER_SWAP` default 1 (it is a preservation/improvement of existing behaviour, not a new feature risk)  
**Risk:** `moveInDriver` is confirmed A2 OA safe (already used at line 1014). Low risk.  
**Sequencing:** Pre-cutover.

---

### WO-3: Tires-shot-out / stuck handling (existing ladder + improvements)

**Status:** Substantial existing ladder, one gap to close.

**Current state:** The stuck ladder (tiers 1-3) in RunCommanderTeam handles velocity-wedge, lane-flip re-path, and road-snap teleport. The self-repair (`WFBE_C_AICOM_VEHICLE_SELFREPAIR`) handles `!canMove` via `setDamage 0` after a 30 s safe window. The water guard forces tier-3 on water-surface hulls (lines 1000-1002).

**Gap:** `setDamage 0` restores the hull fully but there is no differentiation between "tires shot out" (partial mobility loss) and "engine destroyed" (total mobility loss). Both result in `!canMove = true` and are handled identically — which is correct and sufficient.

**Work order (pre-cutover, Common_RunCommanderTeam.sqf):** The existing self-repair is adequate for V2. One improvement: reduce `WFBE_C_AICOM_SELFREPAIR_DELAY` default from 30 s to 20 s for mounted teams (a wheel hit that immobilises a team for 30+ s in transit is too punishing). Gate on `WFBE_C_AICOM_SELFREPAIR_FAST_MOUNTED` default 1.  
**No new dismount-repair-remount cycle is proposed** (see engine feasibility section 3 — not achievable in vanilla without a repair truck; `setDamage 0` is the correct approach).

**Flag:** `WFBE_C_AICOM_SELFREPAIR_FAST_MOUNTED` default 1 (reduces delay when a drivable vehicle is present)  
**Sequencing:** Pre-cutover.

---

### WO-4: Rearm/repair driven by damage/ammo state, not front stabilization

**Status:** ALREADY CORRECT — the existing ServiceTick triggers on `getDammage > 0.5` OR vehicle ammo fraction `< 0.35`, with no front-stabilization gate. This matches the owner intent exactly. The B49 RELAX (line 103-109) already removed the old SAFE_DIST start-gate in favour of TRIGGER_DIST (300 m), so a disengaged team can service without the front being stable.

**Work order:** None needed. Document as confirmed correct.

---

### WO-5: Balanced composition — most meaningful unlocked vehicles, no ATVs/bikes

**Status:** ATVs are technically in the USMC template pool (Squad_USMC.sqf lines 303-316: "Motorized - CROWS ATV Scout Section" with two `ATV_US_EP1`). They would almost never be picked because the effectiveness-weighted draw weights by BI `cost` — ATVs have a low cost score and compete against IFVs and APCs in the same light bucket.

**Work order (fold-into-V2 cutover, AI_Commander_Teams.sqf):** Explicitly strip templates containing ATV/Motorcycle hull classnames from `_eligible` in the same pattern as the existing static-weapon strip (lines 409-423). Check `_x isKindOf "Motorcycle"` (A2 OA class hierarchy: ATV_US_EP1 inherits from `Motorcycle`) for every unit classname in the template. If any member isKindOf "Motorcycle", exclude the template from `_eligible`. GUARDRAIL: if stripping would empty the set, keep the original (same pattern as line 422). This is deterministic — the owner ruling "no ATVs/bikes" is explicit.

**Flag:** `WFBE_C_AICOM_NO_BIKES` default 1 (stripping is the desired state; 0 reverts to current behaviour where ATVs are merely unlikely, not prohibited).  
**Risk:** Only one template (USMC ATV scout) is affected. The GUARDRAIL prevents starvation.  
**Sequencing:** Fold into cutover (touches Teams.sqf, a commander file).

---

### WO-6: When losing — fewer-but-better units, softest-lane push (no auto-recapture)

**Status:** The Allocate softest-lane logic is partially present: the expansion-first gate shifts to neutral towns when `_myTowns < _engageMin`, and the repick penalty discourages dogpiling. There is no explicit "after a town loss, push the softest available lane" logic.

**Work order (fold-into-V2 cutover, AI_Commander_Allocate.sqf):**

*Fewer-but-better on losses:* When `_myTowns` drops (detectable by comparing snapshot `WFBE_SNAP_MYTOWNS` to a previous tick's cached value), temporarily boost `WFBE_C_AICOM_EFF_BIAS_EXP` for this side's pick cycle by +0.3 (capped at 1.0) so the effectiveness-weighted draw leans harder on the strongest available template. Self-correcting: next tick the exponent returns to baseline. This is economic attrition — spend more on quality per team rather than quantity.

*Softest-lane push:* After a loss, the fist scorer already deprioritises recently-attacked towns via `_repickPen`. To reinforce this: when `_myTowns` just dropped (detectable as above), temporarily add a `_softBonus` to neutral/GUER-only capturable towns in the scored list (additive to their score), weighting them above contested enemy towns for 2–3 strategy ticks. The owner's intent "softest lane" = least-defended next target, not the obvious counter-attack on the lost town.

*No auto-recapture:* The repick penalty already covers this. No additional code needed.

**Flag:** `WFBE_C_AICOM_LOSS_SOFTLANE` default 1  
**Risk:** Loss detection needs a cached previous-tick town count on the side logic (one `getVariable` + `setVariable` per strategy tick). Low risk.  
**Sequencing:** Fold into cutover.

---

## 5. Four approved extensions (MICRO-LAYER.md §45-64) specced against driver code

These are defined in `docs/design/v2/MICRO-LAYER.md` (read in full). All build on the driver layer and are **PRE-CUTOVER SAFE** unless they touch commander files.

---

### EXT-1: Road-march pacing (MICRO-LAYER.md line 46-51)

**Design:** At the order-accept branch in RunCommanderTeam (around line 928-936 where `_arrived = false` is reset and the new route is laid), immediately before the road route spawn, issue: `_team setBehaviour "CARELESS"; _team setSpeedMode "FULL"; _team setFormation "COLUMN"`. This is the transit posture.

**Flip-to-COMBAT trigger (hard requirement from MICRO-LAYER.md):** The flip must fire on arrival OR contact OR timeout. Use the existing `_arrived` latch (line 1442) to flip back: `_team setCombatMode "RED"; _team setBehaviour "AWARE"; _team setSpeedMode "FULL"` at arrival gate. For contact en-route: the 20-second order-loop cadence can check `behaviour (leader _team) == "COMBAT"` — if true, the engine has already detected a threat and flipped the leader; in that case assert `_team setBehaviour "AWARE"` immediately. Timeout: if the team has not arrived within `WFBE_C_AICOM_MARCH_TIMEOUT` (default 600 s), flip to AWARE regardless.

**Note:** `WFBE_C_AICOM_MARCH_YELLOW` is mentioned in a comment at line 1447 ("Transit may have run YELLOW") — this suggests the concept is already partially considered. Look for an existing flag before adding a new one.

**Flag:** `WFBE_C_AICOM_ROAD_MARCH_PACE` default 1  
**Zargabad note:** Dense path mesh — stagger simultaneous doMoves over 2 driver ticks (MICRO-LAYER.md line 38: "Stagger simultaneous doMoves over 2 driver ticks on Zargabad").  
**Files:** `Common_RunCommanderTeam.sqf` only.  
**Sequencing:** Pre-cutover.

---

### EXT-2: Fire discipline (MICRO-LAYER.md lines 52-57)

**Design:** Three distinct levers, each a one-shot call at the appropriate state transition:

1. **Transit hold-fire:** At mount-up completion (after `_riders` are seated, around RunCommanderTeam line 825+), call `_team enableAttack false`. Re-enable at the arrival latch (line 1448, after the existing `_team setCombatMode "RED"`). This prevents the transport from stopping to fight every patrol.

2. **Hold-fire posture (GREEN):** For harass-lane teams (identifiable by `_grp getVariable "wfbe_aicom_alloc_target"` matching the harass target), set `_team setCombatMode "GREEN"` at founding or order-accept — they infiltrate to the rear rather than stopping to fight. Re-enable to RED at arrival. This is a commander-side assignment, so it touches Allocate.sqf (fold-into-cutover) for the harass team flag, but the actual setCombatMode call goes in RunCommanderTeam (pre-cutover).

3. **No-flee regulars:** `_team allowFleeing 0` is ALREADY called at line 81 of RunCommanderTeam at founding. This is confirmed already in place.

**Flag:** `WFBE_C_AICOM_FIRE_DISCIPLINE` default 1 (covers both enableAttack and GREEN posture for harass)  
**Risk:** `enableAttack false` on an armour team could prevent it from engaging at the objective if re-enable is missed. The arrival-latch re-enable must be unconditional. Add a belt-and-braces re-enable on any order change (seq bump) in addition to arrival.  
**Files:** `Common_RunCommanderTeam.sqf` (enableAttack, allowFleeing); `AI_Commander_Allocate.sqf` (harass-team GREEN flag, fold-into-cutover).  
**Sequencing:** enableAttack/allowFleeing pre-cutover; harass-GREEN fold-into-cutover.

---

### EXT-3: Economy of force (MICRO-LAYER.md lines 58-62)

**Design:** Three sub-features:

1. **Field-merge of two mauled teams (`joinSilent`):** When two teams from the same side have both dropped below `WFBE_C_AICOM_MERGE_THRESHOLD` alive (e.g. 3) and are within `WFBE_C_AICOM_MERGE_RANGE` (default 200 m) of each other, merge the smaller into the larger with `joinSilent`. This reduces group count, the #1 server-FPS lever. The merge must run on the HC where both groups are local. Requires a HC-side scan — implement as an additional block in the 20-s RunCommanderTeam order loop, or as a tiny HC-local Spawn that monitors the team pair. The 50% salvage refund (MICRO-LAYER.md line 59) is a commander-side fund credit via `ChangeAICommanderFunds` — fold-into-cutover.

2. **selectLeader promotion:** After a join or when the leader is dead, call `selectLeader` on the merged/surviving group to ensure the best-skilled member leads. In A2 OA `selectLeader` is valid. Check: the founding code at line 81 does not explicitly set a leader; A2 engine promotes group leader automatically. `selectLeader` is a confirmed A2 OA command (not in the banned list). Add a post-merge `selectLeader` call.

3. **Instant depot refit:** `setVehicleAmmo 1` and `setFuel 1` are already used in ServiceTick. The "depot refit" scenario for economy of force is already covered by ServiceTick — no additional code needed here.

**Flag:** `WFBE_C_AICOM_ECON_FORCE` default 0 (new feature, default off)  
**Risk:** `joinSilent` changes group membership permanently — if both groups have wfbe_* variables stamped on them, the smaller group's stamps are lost. Map relevant stamps (wfbe_teammode, wfbe_aicom_alloc_target) onto the surviving group before join.  
**Files:** `Common_RunCommanderTeam.sqf` (merge scan + joinSilent + selectLeader); `AI_Commander_Allocate.sqf` (salvage refund signal — fold-into-cutover); `AI_Commander_Teams.sqf` (team list cleanup after merge — fold-into-cutover).  
**Sequencing:** HC-side merge can be pre-cutover; salvage refund and team-list cleanup fold-into-cutover.

---

### EXT-4: Air insertion modes — learner picks, driver executes (MICRO-LAYER.md lines 63-64)

**Design:** The three execution modes are already partially implemented in RunCommanderTeam:
- `land "LAND"` (full landing): the existing `_lzPos` flat-empty path (lines 503-504), which calls `doMove _lz` and lets the heli touch down.
- Para-eject (`eject`): the existing hot-LZ paradrop path (lines 507-565), which forces a paradrop by passing `_flat = []` so the eject branch fires.
- Low hover drop (`land "GET OUT"`): NOT YET IMPLEMENTED. Currently the only alternatives are full-landing vs eject.

**`flyInHeight` for transit vs run-in:** Already implemented: `_h flyInHeight (60 max WFBE_C_AICOM_HELI_RUNINFLOOR)` (line 606). Transit altitude tunable via `WFBE_C_AICOM_HELI_APPROACH_LIMITED` (line 603-604).

**`setUnloadInCombat`:** NOT YET in RunCommanderTeam. This would prevent cargo AI from bailing under fire mid-transit.

**Work order (pre-cutover, Common_RunCommanderTeam.sqf):**
1. Add `setUnloadInCombat _airVeh` call immediately after the pax are loaded (after line 496 `orderGetIn true` calls). Set to a high threshold so AI does not bail mid-flight.
2. Implement the low-hover-drop branch: after the heli reaches within 60 m of the LZ at low altitude, call `_h land "GET OUT"` instead of the full landing sequence. This is the third insertion mode.
3. The "learner" (which mode to use) is a decision in the hot-LZ block (currently binary: flat-LZ = land, no-flat-LZ or hot = eject). Extend to three branches: safe + flat = land; safe + no-flat = hover-drop; hot = eject. Parameters: `WFBE_C_AICOM_AIR_INSERT_MODE_SAFE` (0=land, 1=hover, 2=eject, default 0).

**Flag:** `WFBE_C_AICOM_AIR_INSERT_V2` default 0 (new hover-drop mode off by default; eject path unchanged)  
**Risk:** `land "GET OUT"` in A2 OA: confirmed command name. Whether it halts at a reliable hover height needs an in-game test — mark as **UNKNOWN / needs live verification** before shipping.  
**Sequencing:** Pre-cutover.

---

## 6. The 8 PR fold-in work orders

These are open PRs that must be reviewed, stacked or merged into the V2 cutover build. Evidence from `gh pr view` calls.

---

### PR-WO-1: PR #548 — Lane 227: Arm FundsSink econ surge

**PR summary:** Adds the missing `wfbe_aicom_econ_surge` broadcast in `AI_Commander_FundsSink.sqf` beside the existing `wfbe_aicom_reinforce_rich` latch. 3 additions, 0 deletions. Inside the existing `WFBE_C_AICOM_FUNDS_SINK_ENABLE` default-off path.

**Work order:** Merge as-is. It is a correctness fix — the econ-surge broadcast that Teams.sqf and RunCommanderTeam's rich-gear block already read (`wfbe_aicom_econ_surge`, used at RunCommanderTeam line 426 for the gear-tier surge) was never set. Without this PR the econ-sink surge is inert. **Fold-into-cutover** (touches AI_Commander_FundsSink.sqf, a commander file).

**Risk:** None. The change is inside a default-off flag path. Lint clean per PR body.

---

### PR-WO-2: PR #561 — Lane 342: Guard slung AICOM vehicles from retreat cull

**PR summary:** Detects live team vehicles marked `wfbe_aicom_slung` before the Produce retreat-thrash merge/cull branch. Defers stranded merge/cull while the air leg still owns the attached hull. Mirrors Chernarus/TK/ZG.

**Work order:** Merge as-is. The slung-vehicle guard prevents a valid air-transport hull from being culled as "stranded" while it is still actively carrying the team. **Fold-into-cutover** (touches AI_Commander_Produce.sqf). Sequencing: must land before or with the air-insert V2 work (EXT-4) since retained transports (WFBE_C_AICOM_AIR_RETAIN) interact with the slung state.

**Risk:** Low. Correctness fix for the retain-transport feature (WO-EXT-4 depends on this being clean).

---

### PR-WO-3: PR #564 — Lane 266: Gate AI research gap entries

**PR summary:** Adds default-off `WFBE_C_AICOM_RESEARCH_GAP_FIX`. When armed, inserts `UnitCost L1/L2` and `AmmoCoin L1` into the CO US/RU AI research order immediately after `AIRAAM`. Mirrors TK/ZG.

**Work order:** Ship as-is, but review the research order interaction against V2 doctrine. In V2, the AI research program determines what units the AI can buy. Inserting UnitCost/AmmoCoin earlier means the AI gains economy-tier upgrades sooner, freeing funds for more or better-quality teams. This is compatible with the composition work (WO-5, WO-6). **Fold-into-cutover** (touches AI research config / AI_Commander equivalent). Keep default 0 until V2 soaked.

**Risk:** Research-order changes affect the entire upgrade-dependency chain. Keep default off; owner should enable during parity soak (step 3).

---

### PR-WO-4: PR #570 — Lane 267: Expose AICOM balance toggles

**PR summary:** Adds lobby parameters for `WFBE_C_AICOM_FUNDS_SINK_ENABLE` and `WFBE_C_ENDGAME_FORCE_ENABLE` (both default 0, No/Yes). Mirrors TK/ZG Parameters.hpp.

**Work order:** Merge as-is. These are lobby-accessible toggles for features already implemented. No SQF changes. **Fold-into-cutover** (touches Parameters.hpp — trivial mirror, no logic).

**Risk:** None. Parameters.hpp additions are additive.

---

### PR-WO-5: PR #571 — Lane 365: Log AICOM tuning constants at boot

**PR summary:** One boot-time `AICOMSTAT|v2|CONSTANTS|<side>|0|...` line in `AI_Commander.sqf` logging 12 tuning values: strategy interval, concentration, spearhead town cap, HQ-strike town gate, lane offset, team target, funds-per-extra fallback, lone-team strength gates, top-up cooldown, air cap, produce batch.

**Work order:** Merge as-is. This is telemetry-only — zero behaviour change. Essential for parity soak (step 3) because it allows Score-AicomRounds.ps1 to correlate soak outcomes against the exact constants in play. **Fold-into-cutover** (touches AI_Commander.sqf). Must land before or at the cutover build so the soak-farm has the telemetry line from day one.

**Risk:** None. Additive log line.

---

### PR-WO-6: PR #639 — Lane 373: Clear stale PC-scale retirement flags

**PR summary:** Tags PC-scale retirement requests with `wfbe_aicom_disband_pcscale`. Cancels only those tagged automatic retirements once `founded + pending <= target`. Human console disbands (`wfbe_aicom_disband_cmd`) and low-tier culls remain unaffected. Stacked on #609.

**Work order:** Merge after #609. This is a correctness fix — stale retirement flags caused founded teams to self-delete even after the PC count dropped back to a level that warranted keeping them, wasting founding budget. **Fold-into-cutover** (touches RunCommanderTeam's disband executor and the server-side flag issuer). The pre-cutover safety is debatable: the HC-side executor in RunCommanderTeam is the Common driver layer, but the server-side flag issuer is a commander file. Treat as cutover.

**Risk:** Low. The cancellation path is additive; existing retirements can still be honoured by the cmd tag.

---

### PR-WO-7: PR #640 — Lane 229: Share produce size-max read

**PR summary:** Reads `WFBE_C_AICOM_TEAM_SIZE_MAX` once before the AI_Commander_Produce.sqf team loop and reuses the value for both the stranded-merge ceiling and refill target ceiling. Removes a duplicate read/private.

**Work order:** Merge as-is. Pure refactor — zero behaviour change, eliminates a double-getVariable in the hot produce loop. **Fold-into-cutover** (touches AI_Commander_Produce.sqf). Stacked on #600; resolve #600 first.

**Risk:** None. The value read is the same constant; dedup cannot change behaviour.

---

### PR-WO-8: PR #642 — Lane 347: Use copilot seat for air inserts

**PR summary:** When foot passengers overflow the normal cargo count, the air-insert code now looks for one empty config-marked copilot turret. Normal cargo seats still use `assignAsCargo` + `orderGetIn`; copilot uses the turret path. Stacked on #601.

**Work order:** Merge after #601. This directly improves the air-insert choreography (EXT-4) by fitting one more infantry unit into the transport. **Fold-into-cutover or pre-cutover depending on which file is touched** — if only Common_RunCommanderTeam.sqf, it is pre-cutover safe; if it also touches Teams.sqf, it is a cutover fold. Verify from the PR diff. Sequencing: land before or with EXT-4 air-insert work.

**Risk:** The copilot turret path requires the config to correctly mark the copilot position. Needs live test with each faction's transport to verify the seat is usable.

---

## 7. Non-goals (binding)

The following are explicitly OUT OF SCOPE for this lane, per owner rulings:

- **No deception systems.** No feints, no fake retreats, no deception missions. The FEINT block in Allocate.sqf (lines 482-561, gate `WFBE_C_AICOM_FEINT_ENABLE` default 0) already exists but is off. Do not enable, extend, or reference it in any V2 micro-layer work.
- **No ATVs/bikes in AICOM composition.** The CROWS ATV Scout Section template (Squad_USMC.sqf lines 303-316) must be stripped from AICOM founding via WO-5 when `WFBE_C_AICOM_NO_BIKES = 1` (default 1).
- **No front-stabilization rearm gate.** ServiceTick already correctly triggers on damage/ammo thresholds only. Do not add a "wait until the front is quiet" gate.
- **No per-frame loops.** All micro-layer work must be event-driven or on the 20-s driver cadence. Zero per-frame scans.
- **No targeting micro in COMBAT mode.** Do not issue `doTarget`/`doFire` for infantry (the heli cannon-nudge at lines 197-278 is the sole approved exception, for gunner muzzle selection only).
- **No defensive tasking for maneuver teams.** Maneuver teams are offense-only. Garrisons are the defense layer.
- **No new groups or unit spawns from the micro layer.** The field-merge (EXT-3) reduces group count; it does not create new groups.
- **No fuel logic.** Fuel is effectively infinite (WFBE_C_AICOM_VEHICLE_AUTOFUEL, referenced at RunCommanderTeam line 877). TP-8 owns fuel. Do not touch fuel constants in this work.

---

## 8. Summary table

| ID | Topic | Status | Layer | Timing |
|---|---|---|---|---|
| WO-1 | Combined-group dismount assault | New | Common driver | Pre-cutover |
| WO-2 | Proactive driver-swap + mid-transit smoke | Improvement | Common driver | Pre-cutover |
| WO-3 | Faster self-repair for mounted teams | Tweak | Common driver | Pre-cutover |
| WO-4 | Rearm/repair triggers (confirm correct) | No change needed | Common driver | — |
| WO-5 | No ATVs/bikes in composition | New strip rule | Commander | Fold-into-cutover |
| WO-6 | Softest-lane push + fewer-but-better | New | Commander | Fold-into-cutover |
| EXT-1 | Road-march pacing (CARELESS transit) | New | Common driver | Pre-cutover |
| EXT-2 | Fire discipline (enableAttack, GREEN) | New | Both | Pre/Cutover split |
| EXT-3 | Economy of force (joinSilent, selectLeader) | New | Both | Pre/Cutover split |
| EXT-4 | Air insertion modes (hover-drop, setUnloadInCombat) | New | Common driver | Pre-cutover |
| PR-WO-1 | PR #548 FundsSink broadcast | Merge as-is | Commander | Fold-into-cutover |
| PR-WO-2 | PR #561 Slung-vehicle guard | Merge as-is | Commander | Fold-into-cutover |
| PR-WO-3 | PR #564 Research gap entries | Merge, keep dark | Commander | Fold-into-cutover |
| PR-WO-4 | PR #570 Balance lobby params | Merge as-is | Params only | Fold-into-cutover |
| PR-WO-5 | PR #571 Boot constants telemetry | Merge ASAP | Commander | Fold-into-cutover |
| PR-WO-6 | PR #639 Stale retirement flags | Merge after #609 | Both | Fold-into-cutover |
| PR-WO-7 | PR #640 Produce size-max read | Merge after #600 | Commander | Fold-into-cutover |
| PR-WO-8 | PR #642 Copilot seat air inserts | Merge after #601 | Common driver | Pre-cutover |

---

## 9. Open UNKNOWNs requiring in-game verification

1. **`land "GET OUT"` hover-drop altitude in A2 OA 1.64** — command exists in documentation but the exact hover altitude and reliability need live testing before EXT-4 hover-drop branch ships.
2. **Individual wheel-hit detection (`getHit "HitLFWheel"`)** — the command may exist in A2 OA 1.64 but is not used anywhere in this codebase. If per-wheel damage matters for a future feature, verify in engine. For current WO-3, `canMove + setDamage 0` is sufficient and confirmed working.
3. **Copilot-seat reliability per faction (PR #642)** — the config-marked copilot turret availability varies by airframe. Each faction transport needs a live test.
4. **`setUnloadInCombat` in A2 OA 1.64** — command listed in MICRO-LAYER.md as A2-OA-verified but not found in the current codebase. Confirm the command name and signature before using in EXT-4.
