# AICOM Experital — Fix Notes from the 8-Hour Test-Server Match

**Provenance:** Analysis of the live ~8 h AI-vs-AI match on the Hetzner test box (`78.46.107.142`), mission
`[55-2hc]warfarev2_073v48co.chernarus`, build *"WASP Experital TEST"* (= branch `deploy/2026-06-12-aicom-experital`).
Generated 2026-06-16 by Claude (operator session). Source quoted below was **pulled from the running box**
(its on-disk twin `[61-2hc]…takistan`, AICOM server functions are world-agnostic and matched the error line numbers).

> ⚠️ **Before applying:** the box may be slightly ahead of the repo. Re-confirm each line range against
> `deploy/2026-06-12-aicom-experital` before patching. All paths below are mission-relative
> (`Missions/[55-2hc]warfarev2_073v48co.chernarus/...`). Patches are written A2-OA-1.64-legal
> (no inline `private _x=`, no `isNull` on Side, no `allMapMarkers`/`setSpeaker`).

---

## Match context (why these matter)

- Ran AI-vs-AI ~7 h (1 human, `Zwanon`, for the first ~53 min only). **No winner after 8 h.** WEST 5 towns / EAST 3 / GUER 35 of 43.
- **Server health was fine** (srvFps 22–47, HC delegation 65–82 % remote, group caps far below 144, no crash/leak). The problems are **game logic + balance**, not performance.
- **Deaths:** GUER town garrisons did the most killing (701 kills). The single deadliest unit was **`T72_Gue` (145 kills)**, then `BMP2_Gue` (72), `GUE_Soldier_AT` (~90), `Ural_ZU23_Gue` (~65). WEST lost the most (cas 376 / 33 veh) vs EAST (258 / 35). The AI commanders fielded **on-foot infantry squads + self-driving motorized/armor teams (no troop-truck-dismount system)**; their teams die walking into entrenched GUER armor garrisons, and motorized teams that lose their vehicle get stranded on foot. See `## Death & composition summary` at the bottom.

---

## Fix priority

| # | ID | Severity (post-verify) | Verified by operator? |
|---|---|---|---|
| 1 | `fix-hqstrike-stuck` | **High** (gameplay-breaking endgame loop) | symptom ✓, root cause ✓, full patch needs review |
| 2 | `fix-wildcard-vehicle` | **High→Medium** (2 wildcards 100% dead) | ✓ fully verified |
| 3 | `fix-mopup-squad` | **Medium** (feature 100% dead, 9/9 captures) | current code ✓, lookup key needs final confirm |
| 4 | `fix-isnull-side` | **Low** (A3-ism; fired once, 1 lost heli refund) | ✓ verified |
| 5 | `fix-supply-novehicle` | **Cosmetic** (log spam, ~820+ lines) | ✓ verified |
| — | secondary balance/telemetry notes | low/design | see `## Secondary notes` |

---

## FIX 1 — `fix-hqstrike-stuck`  (HIGH)

**Symptom (from the match):** WEST entered `HQ_STRIKE` at t=129 and never left it (`strikeOn=true` t=129→465, 336 min, 6 launch events). Strike teams (`B 1-3-L`, `B 1-3-M`, `B 1-4-F`) sat at `dist≈4629 moved=0 stuck=true` and were re-dispatched to the same EAST-HQ coordinate every ~8 min. WEST had the strength lead (99 vs 70) but could never convert it.

**Root cause (3 interlocking modes):**
1. **`wfbe_exec_sig` dedup eats every re-dispatch.** `AI_Commander_Execute.sqf` keys on `_sig = [mode, round(x), round(y)]`. The HQ position never changes, so after the first waypoint, `if (str _sig != str _prevSig)` is always false → no new waypoint is ever issued to an already-moving (stuck) team.
2. **Strike teams are invisible to the stuck-reroute path.** They run in `"move"` mode → `AI_Commander_AssignTowns.sqf` sets `_explicitMode=true` and skips the re-route block, so `wfbe_aicom_stuckstrikes` never increments for them.
3. **No epoch-level give-up.** The only cancel is the war-state ratio (`_myTowns>=_enemyTowns*1.2 && _myStr>=_enStr`), which seesaws on a single bad strength tick → rapid launch/recall churn, never a clean abort.

**Files:** `Server/AI/Commander/AI_Commander_Strategy.sqf` (~175–228), `Server/FSM/AI_Commander_AssignTowns.sqf` (~94–106).

**Fix A — Strategy.sqf:** add a force-cancel BEFORE the ratio check + a re-launch lockout, and clear `wfbe_exec_sig` on every (re)designation so the waypoint actually re-issues. Core additions:

```sqf
// On fresh launch, stamp the epoch and clear per-team arrival flags:
_logik setVariable ["wfbe_aicom_strike_since", time];
{ if (!isNull _x) then {_x setVariable ["wfbe_aicom_strike_arrived", false]} } forEach _teams;

// FORCE-CANCEL guard, evaluated BEFORE the hysteresis ratio check (so a timed-out strike
// is not re-armed the same tick). _wasStrike := false on cancel; record reason for the log.
if (_wasStrike) then {
    _strikeAge = time - (_logik getVariable ["wfbe_aicom_strike_since", time]);
    _strikeNoProgress = true;
    { if (!isNull _x && {_x getVariable ["wfbe_aicom_strike", false]} && {_x getVariable ["wfbe_aicom_strike_arrived", false]}) then {_strikeNoProgress = false} } forEach _teams;
    if (_strikeNoProgress && {_strikeAge > ((missionNamespace getVariable ["WFBE_C_AICOM_STRIKE_MAX_MINS", 25]) * 60)}) then {
        _wasStrike = false; _strikeCancelReason = format ["age timeout (%1 min, no ARRIVED)", round (_strikeAge/60)];
    };
    // (also: all-strikers-stuck -> stuckstrikes>=2 on every alive strike team -> cancel)
};

// suppress re-launch during lockout:
if (time < (_logik getVariable ["wfbe_aicom_strike_lockout_until", 0])) exitWith {};

// on (re)designating a strike team, FORCE the exec sig to re-issue the waypoint:
_best setVariable ["wfbe_aicom_strike", true];
_best setVariable ["wfbe_aicom_stuckstrikes", 0];
[_best, "move"] Call SetTeamMoveMode;
[_best, getPos _enemyHQ] Call SetTeamMovePos;
_best setVariable ["wfbe_exec_sig", []];   // <-- the key line: defeats the dedup

// on cancel: set lockout + clear flags + clear exec_sig on each team
_logik setVariable ["wfbe_aicom_strike_lockout_until", time + ((missionNamespace getVariable ["WFBE_C_AICOM_STRIKE_LOCKOUT_MINS", 15]) * 60)];
```

**Fix B — AssignTowns.sqf** (inside the `ASSAULT_STRANDED` branch): a strike-flagged team that is genuinely stuck (`moved<200`, not in COMBAT) gets `wfbe_aicom_stuckstrikes++`; at `>=2` it is yanked from the strike pool (`wfbe_aicom_strike=false`, mode→`"towns"`, clear `wfbe_exec_sig`) and, if HC-resident, flagged `wfbe_aicom_disband=true` to recycle.

**Fix C — AssignTowns.sqf** (`ASSAULT_ARRIVED` branch): mark progress so the age-guard works:
```sqf
if (_team getVariable ["wfbe_aicom_strike", false]) then { _team setVariable ["wfbe_aicom_strike_arrived", true]; };
```

**New config (Init_Server.sqf, plain numbers):**
```sqf
WFBE_C_AICOM_STRIKE_MAX_MINS     = 25;  // force-cancel if no ARRIVED after N min
WFBE_C_AICOM_STRIKE_LOCKOUT_MINS = 15;  // suppress re-launch N min after a force-cancel
```

**Test:** run AI-vs-AI with `WFBE_C_AICOM_STRIKE_MAX_MINS=3`; expect `HQ_STRIKE|launched` → `STRIKE_STUCK|strikestrike=1/2` → `HQ_STRIKE|force_cancel` within ~3 min, and **no** re-launch for the lockout window. For the exec_sig fix: Execute.sqf "executing move order" count for a strike team should be >1 (was exactly 1).

---

## FIX 2 — `fix-wildcard-vehicle`  (HIGH → Medium)  ✅ fully verified

**Symptom:** wildcards **W13 (gunship strike)** and **W17 (supply convoy)** silently do nothing all match (6× `Undefined variable in expression: common_createvehicle`, yet AICOM logs `result=applied`).

**Root cause (verified):** both call bare `Call Common_CreateVehicle` — a variable **never assigned anywhere** in the mission. The real compiled global is **`WFBE_CO_FNC_CreateVehicle`** (used correctly at `Common_CreateTeam.sqf:115`). Confirmed `Common/Functions/Common_CreateVehicle.sqf` signature:
`[type, position, side, direction, locked, bounty=true, global=true, special="FORM"]` — it even auto-converts a SIDE arg to an ID. The existing call args map 1:1.

**File:** `Server/Functions/AI_Commander_Wildcard.sqf:827` (W13) and `:937` (W17).

```sqf
// line 827  (W13 gunship):  Common_CreateVehicle -> WFBE_CO_FNC_CreateVehicle
_w13Heli  = [_w13Class,      _w13SpawnPos, _side, random 360, true,  true] Call WFBE_CO_FNC_CreateVehicle;
// line 937  (W17 convoy):
_w17Truck = [_w17TruckClass, _w17SpawnPos, _side, random 360, false, true] Call WFBE_CO_FNC_CreateVehicle;
```

Add a loud nil-guard once near the top of the wildcard worker so a future rename fails visibly instead of silently:
```sqf
if (isNil "WFBE_CO_FNC_CreateVehicle") exitWith {
    ["ERROR","AI_Commander_Wildcard.sqf: WFBE_CO_FNC_CreateVehicle is nil — W13/W17 cannot fire."] Call WFBE_CO_FNC_AICOMLog;
};
```

**Polish (optional):** the W13 gunship spawns airborne; `Common_CreateVehicle.sqf:34` does `setVelocity [0,0,-1]` unless `special=="FLY"`. Consider passing `"FLY"` as arg 8 for W13 so it doesn't briefly ground-settle before `flyInHeight` takes over. **Note:** W14 (Iron Dome) intentionally uses bare `createVehicle []` — leave it.

**Test:** trigger W13/W17; RPT shows no `Undefined variable` near Common_CreateVehicle and the gunship/convoy actually appears.

---

## FIX 3 — `fix-mopup-squad`  (MEDIUM)  — current code ✅, lookup key needs final confirm

**Symptom:** the post-capture "mop-up squad" feature fails on **every** town capture (9/9). Existing `claude-gaming 2026-06-14` guard at `Common_CreateTeam.sqf:100` only *suppresses* the error (`roster token [Squad_3] … not a CfgVehicles class … skipped`) — the squad never spawns.

**Root cause (verified):** `server_town.sqf:326` builds `_tplName = format ["Squad_%1", _upgLvl]` and passes that **key string** straight to `WFBE_CO_FNC_CreateTeam` (`:333`). CreateTeam iterates `["Squad_3"]` as if it were a unit class → guard skips it. The key must first be resolved to its unit-class array (`Groups_USMC.sqf`/`Groups_RU.sqf` build `_k=["Squad_0".."Squad_3",…]` with parallel `_l` arrays; e.g. WEST `Squad_3 = ["USMC_Soldier_SL","USMC_Soldier_AR","USMC_Soldier_SL","USMC_Soldier_AT","USMC_Soldier_AR","USMC_Soldier_Medic"]`).

**File:** `Server/FSM/server_town.sqf:324-333`.

```sqf
// resolve the template KEY -> unit-class array before CreateTeam, with a walk-down fallback:
Private ["_mopupSideText","_tplKey","_tplList"];
_upgLvl        = ((_side) Call WFBE_CO_FNC_GetSideUpgrades) select WFBE_UP_BARRACKS;
_tplKey        = format ["Squad_%1", _upgLvl];
_mopupSideText = str _side;                                   // "WEST" / "EAST"
_tplList = missionNamespace getVariable [format ["WFBE_%1_GROUPS_%2", _mopupSideText, _tplKey], []];
if (count _tplList == 0) then { _tplList = missionNamespace getVariable [format ["WFBE_%1_GROUPS_Squad_0", _mopupSideText], []]; };
if (count _tplList == 0) exitWith {
    ["WARNING", format ["server_town.sqf: mop-up squad aborted for %1 (%2) - no unit list for %3.", _loc getVariable ["name","?"], _side, _tplKey]] Call WFBE_CO_FNC_LogContent;
};
_spawnPos  = [getPos _loc, 50, 200] call WFBE_CO_FNC_GetRandomPosition;
_spawnPos  = [_spawnPos, 50] call WFBE_CO_FNC_GetEmptyPosition;
_squadTeam = [_side, "town-ai"] Call WFBE_CO_FNC_CreateGroup;
_retVal    = [_tplList, _spawnPos, _side, true, _squadTeam, true, 90] call WFBE_CO_FNC_CreateTeam;   // <-- _tplList not _tplName
```

> 🔎 **CONFIRM BEFORE APPLY:** the exact namespace key. Evidence it's `WFBE_<SIDE>_GROUPS_<key>` with `SIDE="WEST"/"EAST"`: (a) `Common_CreateTeam.sqf:95` comment literally references *"the suffixed `WFBE_<side>_GROUPS_*` lookup keys"*; (b) `Groups_USMC.sqf:9` sets `_side="WEST"`. **But** `Config_Groups.sqf` (the loader that does the `setVariable`) was not pulled — verify the precise key/casing there. The verified-registered template var is `WFBE_<side>AITEAMTEMPLATES` (array, indexed), which is a *different* structure.
>
> **Option B (zero-lookup, dead-simple fallback)** if the key proves fiddly: have the mop-up pass a hardcoded small infantry array per side (e.g. side rifleman ×4) instead of resolving `Squad_N`. Less faithful to barracks tier, but guaranteed to spawn.

**Test:** after a capture, RPT shows the old "not a CfgVehicles class" WARNING gone and a real squad spawning; spectate the captured town at T+60 s.

---

## FIX 4 — `fix-isnull-side`  (LOW)  ✅ verified

**Symptom:** one-shot `Error isnull: Type Side, expected Object,Group,…` at t≈325; the `aicom-heli-refunded` branch aborts → one off-map heli refund lost. Classic A3-only-construct-in-A2 (same family as the `allMapMarkers`/`setSpeaker` burns).

**File:** `Server/Functions/Server_HandleSpecial.sqf:339`.

```sqf
// _rSide = (_rSideID) Call WFBE_CO_FNC_GetSideFromID;   // returns a SIDE
// before:
if (!isNull _rSide && {_rCost > 0}) then {
// after (A2-safe):
if (!isNil "_rSide" && {_rSide != sideUnknown} && {_rCost > 0}) then {
```
`isNull` rejects Side in A2OA. `isNil "_rSide"` + `sideUnknown` is the correct guard. (The other GetSideFromID sites at :219/:252 correctly chain through `GetSideLogic` to an Object first — not applicable here since `ChangeAICommanderFunds` takes a Side directly.)

---

## FIX 5 — `fix-supply-novehicle`  (COSMETIC)  ✅ verified

**Symptom:** ~820+ `Current commander of team: … Error: No vehicle.` `[WFBE (INFORMATION)]` lines (one per supply tick) — pure log spam under `AI_COMMANDER_LOCK=1` (no human in a commander vehicle). Economy is unaffected.

**File:** `Server/Functions/Server_ChangeSideSupply.sqf:17` and `:41` (both handlers).

```sqf
// replace the inline `name leader ((_side) call WFBE_CO_FNC_GetCommanderTeam)` arg with a guarded value:
_cmdTeamSup   = (_side) call WFBE_CO_FNC_GetCommanderTeam;
_cmdLeaderSup = if (!isNull _cmdTeamSup) then {leader _cmdTeamSup} else {objNull};
_cmdNameSup   = if (!isNull _cmdLeaderSup) then {name _cmdLeaderSup} else {"(AI Commander)"};
// ...format [... "%5." ..., _cmdNameSup] ...
```
(Declare `_cmdTeamSup,_cmdLeaderSup,_cmdNameSup` in each handler's `Private[]`.)

---

## Secondary notes (lower priority / design)

1. **Iron Dome (W14) spawned only at t=446** — base weight `_wW14=7` isn't escalated for the losing side. In `AI_Commander_Wildcard.sqf` add `_wW14` to the `_losing` escalation block (~413–420) so it draws at `_wW14*_eMult`. Also verify `WFBE_%1DEFENSES_AAPOD` is initialised before the first wildcard interval (a nil class silently zeros W14 all match).

2. **Post-capture defense race** (`server_town.sqf:251-256`,`295-319`) — capturing side clears GUER statics then waits **60 s** before the mop-up squad. That window is undefended → GUER retook **Vybor 16 s** after WEST captured it. Reduce the delay to ~5–10 s when enemies were detected at capture, or demand-spawn defenders immediately on capture-with-enemies-present.

3. **W3 bonus-patrol wasted draws** (`AI_Commander_Wildcard.sqf:228`,`~533-554`) — the eligibility flag passes even when all current-tier patrol templates are committed; the draw then lands and skips (8/60 draws = 13 % wasted). Add `_active < _w3Max` to the eligibility flag, or downgrade the tier (HEAVY→MEDIUM→LIGHT) before giving up.

4. **`UPRISING_DONE` has no `UPRISING_START`** (`AI_Commander_Wildcard.sqf:~736`) — add `diag_log "AICOMSTAT|v2|EVENT|…|UPRISING_START|target=…"` right after the GUER uprising group is confirmed, to make the lifecycle measurable.

5. **Balance: EAST losing-spiral + no supply sink.**
   - EAST sat at **1 town for ~350 min** (t=71→421). A side holding ≤1 town for >N min should get a real boost (team-spawn or supply stipend), and a losing side should target the *nearest recoverable* town rather than by supply value (see `AI_Commander_AssignTowns.sqf` scoring / `WFBE_C_AICOM_DISTANCE_DIVISOR`).
   - WEST hit the **50 000 supply cap at t≈374** and wasted income for the rest of the match — there is **no supply sink**. Add an optional per-town supply maintenance drain (e.g. `WFBE_C_ECONOMY_SUPPLY_MAINTENANCE_PER_TOWN`, default 0 for back-compat) so a big empire bleeds supply and the cap becomes a real ceiling, rewarding tighter holdings.
   - Overall capture rate ≈ **1 town / 56 min** → an 8 h round can't produce a winner. Consider a time/points victory, or make a town-advantaged side able to overwhelm GUER garrisons faster.

---

## Death & composition summary (context for the above)

**Who died most (WASPSTAT kill ledger, 1,476 events):** GUER 779 (615 inf + 164 veh) · WEST 405 (375 inf + 30 veh) · EAST 292 (258 inf + 34 veh).
**Top killers:** `T72_Gue` 145 · `BMP2_Gue` 72 · `GUE_Soldier_AT` ~90 · `Ural_ZU23_Gue` ~65 — i.e. **GUER town-garrison armor** is the dominant threat. WEST died more than EAST (it attacked more, made=63 with far higher casualties).
**Kill logging:** `WASPSTAT|…|KILL|…` carries killer class + hw category + victim class (the usable ledger). `RequestOnUnitKilled.sqf` lines carry only side+group IDs (no weapon). `[Performance Audit]` lines are noise.

**Dismount hypothesis — PARTIALLY supported, but reframed:** the vehicle→infantry death chain is real (e.g. `T72_Gue` kills a WEST MTVR then 8 dismounted infantry in consecutive entries; an AAV brewed up then 5 USMC die). **But** there is **no troop-truck-dismount system** in the AICOM:
- `class=infantry` templates march **on foot** (3.5 km reach) — these are the big infantry losses, mown down by entrenched GUER `T72/BMP2` already in town.
- `class=light` templates **are** the vehicles (WEST: HMMWV family; EAST: UAZ→GAZ Vodnik→BRDM-2→BTR-90), crew baked in; when the vehicle dies the survivors become foot-reach and often strand.
- `class=heavy` = tracked IFV/MBT (Bradley/Abrams; BMP/T-72/T-90). `air` = UH1Y (WEST) / Mi-24V (EAST) pairs.

**What the commanders built (TEAM_FOUNDED):** WEST 56 teams (32 inf / 18 light / 4 air / 2 heavy); EAST 32 (20 / 8 / 3 / 1). Both LF doctrine. WEST's most-built: `Squad_1` USMC rifle (×5), `Motorized_0` HMMWV pair (×5), `Armored_4` M1A2 TUSK (×4). EAST's: `Squad_3` RU rifle (×5), `Squad_1` (×4), `Motorized_4` BRDM+BTR-90 (×3). Full template→unit rosters are in the operator analysis (`AI_Commander_Teams.sqf` selection; `Common/Config/Groups/Groups_{USMC,RU}.sqf` rosters).
