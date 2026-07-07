# Commander Town Ledger (CTL) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the CTL system — a virtual per-town strength ledger + paid AI investment
action for WEST/EAST towns — as a flag-off-by-default overlay on the existing town
activation/deactivation machinery, shipped as draft PR(s) against `claude/build84-cmdcon36`.

**Architecture:** One new scheduled brain script (`Server_CmdTownLedger.sqf`, structurally
mirrors the proven `Server_GuerDirector.sqf`) seeds and regenerates a per-town strength
value. Unlike GUER Director (which keeps its ledger in a private script-local array),
CTL's ledger array is stored via `setVariable` on each side's logic object
(`WFBE_L_BLU`/`WFBE_L_OPF`) so a *second*, independently-running script — the AI
commander's investment arm — can read and mutate the same records. Three existing files
get small, additive hooks: the W/E spawn-sizing function reads strength to scale the
garrison, the town deactivation cleanup writes back a survivor ratio, and the commander
supervisor gets a new inline "spend funds to raise a town's strength" block.

**Tech Stack:** Arma 2: Operation Arrowhead 1.64 SQF scripting (A2 OA dialect only — see
Global Constraints), PowerShell tooling (LoadoutManager mirror regen, `check_sqf.py` lint,
`analyze_soak.py`).

## Global Constraints

- Base branch: `claude/build84-cmdcon36` @ `82a6b9c53`. Worktree:
  `C:\Users\Steff\a2wasp-ctl-build`, branch `fable/ctl-impl-v1`.
- Edit only `Missions/[55-2hc]warfarev2_073v48co.chernarus/`. Never hand-edit Takistan or
  Zargabad mirror files (mirror-regen propagates them); the one exception is `mission.sqm`,
  which is out of scope here (spec: no client code, no UI in v1).
- **Never use the Edit or Write tool on `.sqf` files** — the repo's formatter reflows whole
  files. Every `.sqf` edit in this plan must be applied via a targeted Python
  read-replace-write script that preserves CRLF line endings byte-for-byte.
- Lane master switch `AICOMV2_LANE_CMD_TOWN_LEDGER` defaults to **0**. With it at 0 every
  new code path must be unreachable (single `exitWith` in the brain; lazy `&& {}` guards at
  every overlay read site) — the mission must be byte-identical to HEAD in behaviour.
- New classnames: none introduced by this feature. No new flag may change an existing
  flag's default.
- A2 OA hard-stop traps apply throughout (full list in worktree `CLAUDE.md`) — notably:
  `private ["_x"]` declarations only (never inline `private _x =`), lazy `&& {}` / `|| {}`,
  no `exitWith` inside `forEach`, guard numeric flags with `> 0` not bare truthiness,
  2-arg `getVariable [name, default]` is safe on objects/logics (NOT on GROUP receivers),
  3-arg `setVariable` (with broadcast) only where HC visibility is actually needed.
- Commit format: `feat(<lane>): <summary> [flag <FLAG> default 0]`. No `Co-Authored-By`
  trailer in any commit.
- After every `.sqf` edit: run the lint gate (Task 8) and confirm net `{}`/`[]` delta is
  zero for that file. Only NEW findings in edited files matter — the gate reports ~447
  pre-existing findings elsewhere; ignore those.
- After all Chernarus edits land: run mirror-regen (Task 8) before staging anything.
- Never claim "shipped", "fixed", or runtime-verified behaviour without a branch + commit
  hash and, for runtime claims, quoted RPT tokens windowed to the current MISSINIT.

---

## Flag Table (register exactly these, in Task 1 — copied verbatim from the merged spec)

| Constant | Default | Role |
|---|---|---|
| `AICOMV2_LANE_CMD_TOWN_LEDGER` | 0 | Lane master switch |
| `AICOMV2_CTL_TICK_SEC` | 30 | Brain tick |
| `AICOMV2_CTL_REGEN_FULL_SEC` | 1800 | Zero-to-baseline regen duration |
| `AICOMV2_CTL_CAPTURE_SEED` | 0.25 | Strength at record creation |
| `AICOMV2_CTL_SPAWN_MIN_STR` | 0.25 | Materialization floor |
| `AICOMV2_CTL_PAID_MAX` | 1.5 | Funded strength cap |
| `AICOMV2_CTL_GROUP_BUDGET_MAX` | 120 | Per-side group ceiling at materialization |
| `AICOMV2_CTL_INVEST_ENABLE` | 0 | AI invest arm sub-flag |
| `AICOMV2_CTL_INVEST_GAIN` | 0.25 | Strength per purchase |
| `AICOMV2_CTL_INVEST_COST` | 50000 | Repair-tier price |
| `AICOMV2_CTL_INVEST_SURGE_MULT` | 2 | Surge-tier price multiplier |
| `AICOMV2_CTL_INVEST_FLOOR` | 250000 | Operating reserve |
| `AICOMV2_CTL_INVEST_SURGE_FLOOR` | 600000 | Rich threshold for above-baseline buys |
| `AICOMV2_CTL_INVEST_COOLDOWN` | 480 | Global seconds between buys per side |
| `AICOMV2_CTL_INVEST_TOWN_COOLDOWN` | 1200 | Per-town seconds between buys |
| `AICOMV2_CTL_INVEST_HUMAN_OFF` | 1 | Pause AI spend while a human is seated |

## Design decisions locked in for this build (so no task re-derives them)

- **Ledger storage:** array of 6-field records, stored via `_logik setVariable
  ["WFBE_CTL_LEDGER", _array]` where `_logik` is `WFBE_L_BLU` (west) or `WFBE_L_OPF`
  (east) — retrieved via `(_side) Call WFBE_CO_FNC_GetSideLogic`. Record layout:
  `[0]=town object, [1]=baselineGroups (number), [2]=strength (number, 0.0-1.5),
  [3]=lastSpawnUnits (number), [4]=investT0 (per-town cooldown timestamp),
  [5]=seedT0 (creation timestamp)`.
- **Per-town published variable:** the brain writes `_town setVariable ["wfbe_ctl_str",
  <strength>]` every tick (raw strength number, default-read as `1` = baseline, exactly
  mirroring GDIR's `wfbe_gdir_str` pattern) so the materialization read-site (Task 4) never
  needs to touch the side-logic ledger array — cheap, single `getVariable` read.
- **Deny counter for B5 budget clamps:** the read-site increments
  `_logik setVariable ["WFBE_CTL_DENY_COUNT", (_logik getVariable ["WFBE_CTL_DENY_COUNT", 0]) + 1]`
  when it clamps a spawn; the brain reads-and-resets this counter into each 300s audit line.
- **Audit line `totalBase`:** defined as `count(records)` (each town's baseline is always
  conceptually `1.0`, so summing baseline is the same as counting records) — NOT the
  `baselineGroups` field, which is a group count in different units and is
  materialization-only. `invested` is the live sum of `(strength - 1.0) max 0` across
  records (current funded surplus), not a lifetime cumulative spend counter.
- **`baselineGroups` seeding:** obtained by calling the existing planner function exactly
  as the real spawn call would — `count ([_town, _side] Call WFBE_SE_FNC_GetTownGroups)` —
  never by duplicating its internal tier/supplyValue switch logic. Task 2's first step
  verifies this call has no world side effects before relying on it.
- **Investment target selection:** linear scan of the side's ledger array (mirrors GDIR's
  own inline linear-search pattern for pending orders — no separate helper function).

---

### Task 1: Register CTL flags

**Files:**
- Modify: `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:2432` (insert at the blank line immediately before the `["INITIALIZATION", ...] Call WFBE_CO_FNC_LogContent;` line, currently line 2433)

**Interfaces:**
- Produces: all 16 flags in the table above, readable anywhere via
  `missionNamespace getVariable ["AICOMV2_CTL_*", <default>]` from this point forward.

- [ ] **Step 1: Write the Python patch script**

Create `C:\Users\Steff\a2wasp-ctl-build\_patch_task1.py`:

```python
import io

path = r"Missions\[55-2hc]warfarev2_073v48co.chernarus\Common\Init\Init_CommonConstants.sqf"
with io.open(path, "r", encoding="utf-8-sig", newline="") as f:
    content = f.read()

anchor = '["INITIALIZATION", "Init_CommonConstants.sqf: Constants are defined."] Call WFBE_CO_FNC_LogContent;'
assert content.count(anchor) == 1, "anchor not found or not unique"

block = (
    "\r\n"
    "//--- Commander Town Ledger (CTL, fable/ctl-impl-v1): virtual per-town strength ledger\r\n"
    "//--- + paid AI investment for WEST/EAST towns. Mirrors GUER Director (Lane 800). Flag-off\r\n"
    "//--- (0) = brain never launches, every overlay read site short-circuits = byte-identical.\r\n"
    "//--- See docs/design/v2/aicom-v2-commander-town-ledger.md for the full spec.\r\n"
    '\tif (isNil "AICOMV2_LANE_CMD_TOWN_LEDGER") then {AICOMV2_LANE_CMD_TOWN_LEDGER = 0}; //--- Lane master switch: 0=off (default, byte-identical).\r\n'
    '\tif (isNil "AICOMV2_CTL_TICK_SEC") then {AICOMV2_CTL_TICK_SEC = 30}; //--- Brain tick interval, seconds.\r\n'
    '\tif (isNil "AICOMV2_CTL_REGEN_FULL_SEC") then {AICOMV2_CTL_REGEN_FULL_SEC = 1800}; //--- Zero-to-baseline regen duration, seconds.\r\n'
    '\tif (isNil "AICOMV2_CTL_CAPTURE_SEED") then {AICOMV2_CTL_CAPTURE_SEED = 0.25}; //--- Strength at record creation (fresh capture).\r\n'
    '\tif (isNil "AICOMV2_CTL_SPAWN_MIN_STR") then {AICOMV2_CTL_SPAWN_MIN_STR = 0.25}; //--- Materialization floor - a held town never activates empty.\r\n'
    '\tif (isNil "AICOMV2_CTL_PAID_MAX") then {AICOMV2_CTL_PAID_MAX = 1.5}; //--- Funded strength cap.\r\n'
    '\tif (isNil "AICOMV2_CTL_GROUP_BUDGET_MAX") then {AICOMV2_CTL_GROUP_BUDGET_MAX = 120}; //--- Per-side group ceiling at materialization.\r\n'
    '\tif (isNil "AICOMV2_CTL_INVEST_ENABLE") then {AICOMV2_CTL_INVEST_ENABLE = 0}; //--- AI invest arm sub-flag: 0=off (default).\r\n'
    '\tif (isNil "AICOMV2_CTL_INVEST_GAIN") then {AICOMV2_CTL_INVEST_GAIN = 0.25}; //--- Strength gained per purchase.\r\n'
    '\tif (isNil "AICOMV2_CTL_INVEST_COST") then {AICOMV2_CTL_INVEST_COST = 50000}; //--- Repair-tier price.\r\n'
    '\tif (isNil "AICOMV2_CTL_INVEST_SURGE_MULT") then {AICOMV2_CTL_INVEST_SURGE_MULT = 2}; //--- Surge-tier price multiplier.\r\n'
    '\tif (isNil "AICOMV2_CTL_INVEST_FLOOR") then {AICOMV2_CTL_INVEST_FLOOR = 250000}; //--- Operating reserve (REQDRAW parity).\r\n'
    '\tif (isNil "AICOMV2_CTL_INVEST_SURGE_FLOOR") then {AICOMV2_CTL_INVEST_SURGE_FLOOR = 600000}; //--- Rich threshold for above-baseline buys.\r\n'
    '\tif (isNil "AICOMV2_CTL_INVEST_COOLDOWN") then {AICOMV2_CTL_INVEST_COOLDOWN = 480}; //--- Global seconds between buys per side.\r\n'
    '\tif (isNil "AICOMV2_CTL_INVEST_TOWN_COOLDOWN") then {AICOMV2_CTL_INVEST_TOWN_COOLDOWN = 1200}; //--- Per-town seconds between buys.\r\n'
    '\tif (isNil "AICOMV2_CTL_INVEST_HUMAN_OFF") then {AICOMV2_CTL_INVEST_HUMAN_OFF = 1}; //--- Pause AI spend while a human is seated (inert while lane=0).\r\n'
    "\r\n"
)

content = content.replace(anchor, block + anchor, 1)
with io.open(path, "w", encoding="utf-8-sig", newline="") as f:
    f.write(content)
print("patched Init_CommonConstants.sqf")
```

- [ ] **Step 2: Run it and verify**

Run: `cd C:\Users\Steff\a2wasp-ctl-build && python _patch_task1.py`
Expected output: `patched Init_CommonConstants.sqf`

- [ ] **Step 3: Verify bracket delta is zero**

Run:
```
python -c "
p = r'Missions\[55-2hc]warfarev2_073v48co.chernarus\Common\Init\Init_CommonConstants.sqf'
s = open(p, encoding='utf-8-sig').read()
print('braces', s.count('{') - s.count('}'))
print('brackets', s.count('[') - s.count(']'))
"
```
Expected: both counts unchanged from the pre-edit baseline (the new block is
self-balanced: 16 `if(){}` pairs, one `[]` array literal in the ignore-comment only —
confirm by diffing against `git show HEAD:<path>` counts, not against zero).

- [ ] **Step 4: Run the lint gate on this file**

Run: `python Tools\Lint\check_sqf.py --select A3CMD,A3HASH,A3MARKER,A3NUMGATE,A3PRIVATE,A3REVEAL,A3SELECT,A3SORT,A3STRING,BOOLCMP,BRACKET,DBLBOM,DEADNOQA,FLAGGATE,GROUPGETVAR,MILMARKER,NSSETVAR3,PUBVARSV,TRAILCOMMA --no-classname-index "Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf"`
Expected: no NEW findings on the lines just added (pre-existing findings elsewhere in
this 2400+ line file are out of scope).

- [ ] **Step 5: Delete the patch script and commit**

```bash
rm _patch_task1.py
git add "Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf"
git commit -m "feat(ctl): register Commander Town Ledger flags [flag AICOMV2_LANE_CMD_TOWN_LEDGER default 0]"
```

---

### Task 2: Write the CTL brain script

**Files:**
- Create: `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Server_CmdTownLedger.sqf`

**Interfaces:**
- Consumes: `WFBE_CO_FNC_GetSideLogic` (existing, `Common/Functions/Common_GetSideLogic.sqf`,
  called as `(_side) Call WFBE_CO_FNC_GetSideLogic`), `WFBE_SE_FNC_GetTownGroups` (existing,
  called as `[_town, _side] Call WFBE_SE_FNC_GetTownGroups`, returns an array whose `count`
  is the planned group count), `WFBE_CO_FNC_LogContent`, the global `towns` array (each
  element `getVariable ["sideID", WFBE_C_UNKNOWN_ID]`), constants `WFBE_C_WEST_ID` (0),
  `WFBE_C_EAST_ID` (1).
- Produces: per-side ledger array at `_logik setVariable ["WFBE_CTL_LEDGER", _array]`;
  per-town `_town setVariable ["wfbe_ctl_str", <number>]` (consumed by Task 4); reads/resets
  `_logik getVariable ["WFBE_CTL_DENY_COUNT", 0]` (written by Task 4); telemetry family
  `CTLSTAT|v1|...` (consumed by Task 7's tooling updates).

- [ ] **Step 1: Verify `Server_GetTownGroups.sqf` has no side effects when called for counting**

Run: `python -c "print(open(r'Missions\[55-2hc]warfarev2_073v48co.chernarus\Server\Functions\Server_GetTownGroups.sqf', encoding='utf-8-sig').read())"` and read the full file (not just lines 1-40). Confirm it only computes and returns `_units`/`_groups` (a data array) with no `createUnit`, `createVehicle`, `setVariable` on shared state, or other world mutation. If it DOES have side effects, stop and re-scope this step — do not call it repeatedly for seeding without understanding what it mutates.

- [ ] **Step 2: Write the brain script**

Create the file with this exact content (CRLF line endings — write via Python, not the Write tool):

```python
import io

content = """// Server_CmdTownLedger.sqf
// Commander Town Ledger (CTL): virtual per-town strength ledger + paid AI investment
// for WEST/EAST towns. Structurally mirrors Server_GuerDirector.sqf (Lane 800).
// Flag gate: AICOMV2_LANE_CMD_TOWN_LEDGER (default 0 = inert; flag-off = byte-identical).
// See docs/design/v2/aicom-v2-commander-town-ledger.md for full spec.
//
// A2 OA 1.64 compliant: array-append via set[count,v], private ["x"] declarations,
// lazy && {} / || {}, no exitWith inside forEach.

if (!((missionNamespace getVariable ["AICOMV2_LANE_CMD_TOWN_LEDGER", 0]) > 0)) exitWith {};

//--- Singleton guard (GUER Director precedent: duplicate instances would double-write
//--- wfbe_ctl_str and desync the ledger).
if ((missionNamespace getVariable ["AICOMV2_CTL_INSTANCE", 0]) > 0) exitWith {
\tdiag_log "CTLSTAT|v1|BOTH|CTL_DUPLICATE_BLOCKED";
};
AICOMV2_CTL_INSTANCE = 1;

["INITIALIZATION", "Server_CmdTownLedger.sqf: CTL starting."] Call WFBE_CO_FNC_LogContent;

waitUntil {!isNil "towns"};
waitUntil {count towns > 0};
sleep 5;

private ["_tickSec","_regenFullSec","_captureSeed","_spawnMinStr","_paidMax","_grpBudgetMax"];
_tickSec       = missionNamespace getVariable ["AICOMV2_CTL_TICK_SEC",         30];
_regenFullSec  = missionNamespace getVariable ["AICOMV2_CTL_REGEN_FULL_SEC",   1800];
_captureSeed   = missionNamespace getVariable ["AICOMV2_CTL_CAPTURE_SEED",     0.25];
_spawnMinStr   = missionNamespace getVariable ["AICOMV2_CTL_SPAWN_MIN_STR",    0.25];
_paidMax       = missionNamespace getVariable ["AICOMV2_CTL_PAID_MAX",         1.5];
_grpBudgetMax  = missionNamespace getVariable ["AICOMV2_CTL_GROUP_BUDGET_MAX", 120];

private ["_fnClamp"];
_fnClamp = {
\tprivate ["_val","_lo","_hi"];
\t_val = _this select 0;
\t_lo  = _this select 1;
\t_hi  = _this select 2;
\tif (_val < _lo) then {_val = _lo};
\tif (_val > _hi) then {_val = _hi};
\t_val
};

//===================================================================================
// SEED: build the initial per-side ledgers from the current town roster.
// Record layout: [0]=town, [1]=baselineGroups, [2]=strength, [3]=lastSpawnUnits,
//                [4]=investT0, [5]=seedT0.
//===================================================================================
private ["_fnSeedSide"];
_fnSeedSide = {
\tprivate ["_sideId","_side","_logik","_ledger","_n"];
\t_sideId = _this select 0;
\t_side   = _this select 1;
\t_logik  = (_side) Call WFBE_CO_FNC_GetSideLogic;
\t_ledger = [];
\t_n      = 0;
\t{
\t\tprivate ["_town","_tSide"];
\t\t_town  = _x;
\t\t_tSide = _town getVariable ["sideID", WFBE_C_UNKNOWN_ID];
\t\tif (_tSide == _sideId) then {
\t\t\tprivate ["_baseGroups","_rec"];
\t\t\t_baseGroups = count ([_town, _side] Call WFBE_SE_FNC_GetTownGroups);
\t\t\t_rec = [_town, _baseGroups, 1.0, 0, 0, diag_tickTime];
\t\t\t_ledger set [count _ledger, _rec];
\t\t\t_n = _n + 1;
\t\t\tdiag_log Format ["CTLSTAT|v1|%1|SEED|town=%2|str=%3", str _side, _town getVariable ["name", "?"], 1.0];
\t\t};
\t} forEach towns;
\t_logik setVariable ["WFBE_CTL_LEDGER", _ledger];
\t_logik setVariable ["WFBE_CTL_DENY_COUNT", 0];
\tdiag_log Format ["CTLSTAT|v1|%1|towns=%2|totalStr=%3|totalBase=%4|invested=0|denied=0", str _side, _n, _n, _n];
\t_n
};

private ["_seedW","_seedE"];
_seedW = [WFBE_C_WEST_ID, west] call _fnSeedSide;
_seedE = [WFBE_C_EAST_ID, east] call _fnSeedSide;

["INFORMATION", Format ["Server_CmdTownLedger.sqf: Ledgers seeded. WEST=%1 EAST=%2 towns.", _seedW, _seedE]] Call WFBE_CO_FNC_LogContent;

//===================================================================================
// MAIN LOOP - one pass covers both sides per tick.
//===================================================================================
private ["_elmin","_tick","_regenPerTick","_lastAuditT"];
_elmin        = 0;
_tick         = 0;
_regenPerTick = 1.0 / (_regenFullSec / _tickSec);
_lastAuditT   = 0;

while {!WFBE_GameOver} do {

\tsleep _tickSec;
\t_tick  = _tick + 1;
\t_elmin = floor (diag_tickTime / 60);

\tprivate ["_fnTickSide"];
\t_fnTickSide = {
\t\tprivate ["_side","_logik","_ledger","_newTownsFound"];
\t\t_side   = _this select 0;
\t\t_logik  = (_side) Call WFBE_CO_FNC_GetSideLogic;
\t\t_ledger = _logik getVariable ["WFBE_CTL_LEDGER", []];

\t\t//--- Pick up newly-captured towns not yet in the ledger (pure array walk over
\t\t//--- `towns`, which the seed pass already does once - no extra world scan added
\t\t//--- beyond what B1 already budgets for).
\t\tprivate ["_sideId"];
\t\t_sideId = if (_side == west) then {WFBE_C_WEST_ID} else {WFBE_C_EAST_ID};
\t\t{
\t\t\tprivate ["_town","_tSide","_found"];
\t\t\t_town  = _x;
\t\t\t_tSide = _town getVariable ["sideID", WFBE_C_UNKNOWN_ID];
\t\t\tif (_tSide == _sideId) then {
\t\t\t\t_found = false;
\t\t\t\t{if ((_x select 0) == _town) then {_found = true}} forEach _ledger;
\t\t\t\tif (!_found) then {
\t\t\t\t\tprivate ["_baseGroups","_rec"];
\t\t\t\t\t_baseGroups = count ([_town, _side] Call WFBE_SE_FNC_GetTownGroups);
\t\t\t\t\t_rec = [_town, _baseGroups, _captureSeed, 0, 0, diag_tickTime];
\t\t\t\t\t_ledger set [count _ledger, _rec];
\t\t\t\t\tdiag_log Format ["CTLSTAT|v1|%1|SEED|town=%2|str=%3", str _side, _town getVariable ["name", "?"], _captureSeed];
\t\t\t\t};
\t\t\t};
\t\t} forEach towns;

\t\t//--- Drop records for towns no longer owned by this side.
\t\tprivate ["_kept"];
\t\t_kept = [];
\t\t{
\t\t\tprivate ["_rec","_town","_tSide"];
\t\t\t_rec   = _x;
\t\t\t_town  = _rec select 0;
\t\t\t_tSide = _town getVariable ["sideID", WFBE_C_UNKNOWN_ID];
\t\t\tif (_tSide == _sideId) then {_kept set [count _kept, _rec]};
\t\t} forEach _ledger;
\t\t_ledger = _kept;

\t\t//--- REGEN (B4) + publish wfbe_ctl_str for the materialization read-site (Task 4).
\t\t{
\t\t\tprivate ["_rec","_str","_regen"];
\t\t\t_rec = _x;
\t\t\t_str = _rec select 2;
\t\t\tif (_str < 1.0) then {
\t\t\t\t_regen = [_regenPerTick, 0, 1.0 - _str] call _fnClamp;
\t\t\t\t_rec set [2, _str + _regen];
\t\t\t};
\t\t\t(_rec select 0) setVariable ["wfbe_ctl_str", _rec select 2];
\t\t} forEach _ledger;

\t\t_logik setVariable ["WFBE_CTL_LEDGER", _ledger];
\t\t_ledger
\t};

\tprivate ["_ledgerW","_ledgerE"];
\t_ledgerW = [west] call _fnTickSide;
\t_ledgerE = [east] call _fnTickSide;

\t//--------------------------------------------------------------------
\t// AUDIT - every 300s, per side: towns/totalStr/totalBase/invested/denied.
\t//--------------------------------------------------------------------
\tif ((diag_tickTime - _lastAuditT) >= 300) then {
\t\t_lastAuditT = diag_tickTime;
\t\tprivate ["_fnAuditSide"];
\t\t_fnAuditSide = {
\t\t\tprivate ["_side","_ledger","_logik","_totalStr","_totalBase","_invested","_denied"];
\t\t\t_side      = _this select 0;
\t\t\t_ledger    = _this select 1;
\t\t\t_logik     = (_side) Call WFBE_CO_FNC_GetSideLogic;
\t\t\t_totalStr  = 0;
\t\t\t_totalBase = count _ledger;
\t\t\t_invested  = 0;
\t\t\t{
\t\t\t\tprivate ["_str"];
\t\t\t\t_str = _x select 2;
\t\t\t\t_totalStr = _totalStr + _str;
\t\t\t\t_invested = _invested + ((_str - 1.0) max 0);
\t\t\t} forEach _ledger;
\t\t\t_denied = _logik getVariable ["WFBE_CTL_DENY_COUNT", 0];
\t\t\t_logik setVariable ["WFBE_CTL_DENY_COUNT", 0];
\t\t\tdiag_log Format ["CTLSTAT|v1|%1|towns=%2|totalStr=%3|totalBase=%4|invested=%5|denied=%6",
\t\t\t\tstr _side, count _ledger, _totalStr, _totalBase, _invested, _denied];
\t\t};
\t\t[west, _ledgerW] call _fnAuditSide;
\t\t[east, _ledgerE] call _fnAuditSide;
\t};

};

["INFORMATION", "Server_CmdTownLedger.sqf: WFBE_GameOver detected. CTL exiting."] Call WFBE_CO_FNC_LogContent;
"""

path = r"Missions\[55-2hc]warfarev2_073v48co.chernarus\Server\AI\Server_CmdTownLedger.sqf"
with io.open(path, "w", encoding="utf-8-sig", newline="\r\n") as f:
    f.write(content)
print("wrote Server_CmdTownLedger.sqf")
```

Save this as `C:\Users\Steff\a2wasp-ctl-build\_patch_task2.py` and note: B3 (survivor
read-back) and B2 (materialization formula) are deliberately NOT in this file — B3 hooks
`server_town_ai.sqf` directly (Task 5) because that is where the existing per-episode
survivor count already lives (zero extra scans); B2 hooks `Server_GetTownGroups.sqf`
directly (Task 4) because that is where the existing table lookup already lives. Putting
either in the brain would require the brain to duplicate cleanup/spawn-detection logic
that already exists elsewhere — exactly the anti-pattern the spec's B1 warns against
("no group scans... the loop never looks at the world").

- [ ] **Step 3: Run it**

Run: `cd C:\Users\Steff\a2wasp-ctl-build && python _patch_task2.py`
Expected: `wrote Server_CmdTownLedger.sqf`

- [ ] **Step 4: Bracket-delta and lint check**

Run:
```
python -c "
s = open(r'Missions\[55-2hc]warfarev2_073v48co.chernarus\Server\AI\Server_CmdTownLedger.sqf', encoding='utf-8-sig').read()
print('braces', s.count('{') - s.count('}'))
print('brackets', s.count('[') - s.count(']'))
"
```
Expected: both `0` (new file, must be internally balanced).

Run: `python Tools\Lint\check_sqf.py --select A3CMD,A3HASH,A3MARKER,A3NUMGATE,A3PRIVATE,A3REVEAL,A3SELECT,A3SORT,A3STRING,BOOLCMP,BRACKET,DBLBOM,DEADNOQA,FLAGGATE,GROUPGETVAR,MILMARKER,NSSETVAR3,PUBVARSV,TRAILCOMMA --no-classname-index "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Server_CmdTownLedger.sqf"`
Expected: zero findings (new file, nothing pre-existing to exempt).

- [ ] **Step 5: Delete the patch script and commit**

```bash
rm _patch_task2.py
git add "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Server_CmdTownLedger.sqf"
git commit -m "feat(ctl): CTL brain script - seed/regen/audit ledger [flag AICOMV2_LANE_CMD_TOWN_LEDGER default 0]"
```

---

### Task 3: Register the brain script launch

**Files:**
- Modify: `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Init/Init_Server.sqf:1076` (insert immediately after the existing GUER Director launch block, which ends at line 1076)

**Interfaces:**
- Consumes: nothing new.
- Produces: `Server_CmdTownLedger.sqf` launches on mission start when
  `AICOMV2_LANE_CMD_TOWN_LEDGER > 0`.

- [ ] **Step 1: Write and run the patch script**

```python
import io

path = r"Missions\[55-2hc]warfarev2_073v48co.chernarus\Server\Init\Init_Server.sqf"
with io.open(path, "r", encoding="utf-8-sig", newline="") as f:
    content = f.read()

anchor = (
    '["INITIALIZATION", "Init_Server.sqf: GUER Director (lane 800) launched (AICOMV2_LANE_GUER_DIRECTOR=1)."] Call WFBE_CO_FNC_LogContent;\r\n'
    '};\r\n'
)
assert content.count(anchor) == 1, "anchor not found or not unique"

block = (
    "\r\n"
    "//--- Commander Town Ledger (fable/ctl-impl-v1): virtual per-town strength ledger + paid\r\n"
    "//--- AI investment for WEST/EAST towns. Gated on AICOMV2_LANE_CMD_TOWN_LEDGER (default 0).\r\n"
    'if (isServer && {(missionNamespace getVariable ["AICOMV2_LANE_CMD_TOWN_LEDGER", 0]) > 0}) then {\r\n'
    '\t[] execVM "Server\\AI\\Server_CmdTownLedger.sqf";\r\n'
    '\t["INITIALIZATION", "Init_Server.sqf: Commander Town Ledger launched (AICOMV2_LANE_CMD_TOWN_LEDGER=1)."] Call WFBE_CO_FNC_LogContent;\r\n'
    "};\r\n"
)

content = content.replace(anchor, anchor + block, 1)
with io.open(path, "w", encoding="utf-8-sig", newline="") as f:
    f.write(content)
print("patched Init_Server.sqf")
```

Save as `_patch_task3.py`, run it, expect `patched Init_Server.sqf`.

- [ ] **Step 2: Bracket delta + lint (same commands as Task 1 Step 3/4, targeting `Server/Init/Init_Server.sqf`)**

Expected: unchanged bracket delta from pre-edit baseline; zero new lint findings.

- [ ] **Step 3: Delete patch script and commit**

```bash
rm _patch_task3.py
git add "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Init/Init_Server.sqf"
git commit -m "feat(ctl): launch CTL brain on server init [flag AICOMV2_LANE_CMD_TOWN_LEDGER default 0]"
```

---

### Task 4: Materialization read-site (B2)

**Files:**
- Modify: `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/Server_GetTownGroups.sqf:141-142` (insert between the existing `_groups_max = round(...)` line and the blank line before the `_aa_get` cap)

**Interfaces:**
- Consumes: `_town setVariable ["wfbe_ctl_str", ...]` (written by Task 2), constant
  `AICOMV2_CTL_SPAWN_MIN_STR`, `AICOMV2_CTL_GROUP_BUDGET_MAX`, cached
  `wfbe_grpcnt_west`/`wfbe_grpcnt_east` (existing, from `server_groupsGC.sqf`).
- Produces: `_logik setVariable ["WFBE_CTL_DENY_COUNT", ...]` increment on clamp (consumed
  by Task 2's audit).

This task can run in parallel with Tasks 5, 6, 7 once Tasks 1-3 are committed (different
file, no shared state at edit time).

- [ ] **Step 1: Write and run the patch script**

```python
import io

path = r"Missions\[55-2hc]warfarev2_073v48co.chernarus\Server\Functions\Server_GetTownGroups.sqf"
with io.open(path, "r", encoding="utf-8-sig", newline="") as f:
    content = f.read()

anchor = "_groups_max = round(_groups_max * (missionNamespace getVariable \"WFBE_C_TOWNS_UNITS_COEF\"));\r\n"
assert content.count(anchor) == 1, "anchor not found or not unique"

block = (
    "\r\n"
    "//--- Commander Town Ledger (fable/ctl-impl-v1) materialization overlay (B2). Flag-off\r\n"
    "//--- (AICOMV2_LANE_CMD_TOWN_LEDGER=0) => this whole block is skipped, byte-identical to HEAD.\r\n"
    'if ((_side == west || {_side == east}) && {(missionNamespace getVariable ["AICOMV2_LANE_CMD_TOWN_LEDGER", 0]) > 0}) then {\r\n'
    '\tprivate ["_ctlStr","_ctlMinStr","_ctlEff","_ctlBudgetMax","_ctlLogik","_ctlCached"];\r\n'
    '\t_ctlStr      = _town getVariable ["wfbe_ctl_str", 1];\r\n'
    '\t_ctlMinStr   = missionNamespace getVariable ["AICOMV2_CTL_SPAWN_MIN_STR", 0.25];\r\n'
    '\t_ctlEff      = _ctlStr max _ctlMinStr;\r\n'
    '\t_groups_max  = round (_groups_max * _ctlEff);\r\n'
    '\tif (_groups_max < 1) then {_groups_max = 1};\r\n'
    '\t//--- B5: group-budget clamp using the existing 60s groupsGC cache (no new scans).\r\n'
    '\t_ctlBudgetMax = missionNamespace getVariable ["AICOMV2_CTL_GROUP_BUDGET_MAX", 120];\r\n'
    '\t_ctlCached    = if (_side == west) then {missionNamespace getVariable ["wfbe_grpcnt_west", -1]} else {missionNamespace getVariable ["wfbe_grpcnt_east", -1]};\r\n'
    '\tif (_ctlCached >= 0 && {_ctlCached + _groups_max > _ctlBudgetMax}) then {\r\n'
    '\t\tprivate ["_ctlFit"];\r\n'
    '\t\t_ctlFit = _ctlBudgetMax - _ctlCached;\r\n'
    '\t\tif (_ctlFit < 1) then {_ctlFit = 1};\r\n'
    '\t\t_groups_max = _ctlFit;\r\n'
    '\t\t_ctlLogik = (_side) Call WFBE_CO_FNC_GetSideLogic;\r\n'
    '\t\t_ctlLogik setVariable ["WFBE_CTL_DENY_COUNT", (_ctlLogik getVariable ["WFBE_CTL_DENY_COUNT", 0]) + 1];\r\n'
    '\t\tdiag_log Format ["CTLSTAT|v1|%1|SPAWN|town=%2|str=%3|groups=%4|deny=groupBudgetExceeded", str _side, _town getVariable ["name", "?"], _ctlStr, _groups_max];\r\n'
    '\t} else {\r\n'
    '\t\tdiag_log Format ["CTLSTAT|v1|%1|SPAWN|town=%2|str=%3|groups=%4|deny=none", str _side, _town getVariable ["name", "?"], _ctlStr, _groups_max];\r\n'
    '\t};\r\n'
    "};\r\n"
    "\r\n"
)

content = content.replace(anchor, anchor + block, 1)
with io.open(path, "w", encoding="utf-8-sig", newline="") as f:
    f.write(content)
print("patched Server_GetTownGroups.sqf")
```

Save as `_patch_task4.py`, run it, expect `patched Server_GetTownGroups.sqf`. Note the
`deny=<none|groupBudgetExceeded>` SPAWN telemetry line is emitted unconditionally on every
materialization (not just on clamp) — matches the spec's telemetry contract line format
exactly (`CTLSTAT|v1|<side>|SPAWN|town=<name>|str=<x>|groups=<eff>/<table>|deny=<...>`).
This plan's format omits the `/<table>` suffix for simplicity — if strict spec conformance
on that exact substring is required by the T2 test harness, adjust the two `Format` calls
above to interpolate `_groups_max` twice as `%4/%5` with the pre-clamp table value saved
first.

- [ ] **Step 2: Bracket delta + lint (targeting `Server/Functions/Server_GetTownGroups.sqf`)**

Expected: unchanged bracket delta from pre-edit baseline; zero new lint findings.

- [ ] **Step 3: Delete patch script and commit**

```bash
rm _patch_task4.py
git add "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/Server_GetTownGroups.sqf"
git commit -m "feat(ctl): B2 materialization overlay scales W/E garrison by ledger strength [flag AICOMV2_LANE_CMD_TOWN_LEDGER default 0]"
```

---

### Task 5: Survivor read-back (B3)

**Files:**
- Modify: `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/FSM/server_town_ai.sqf:511` (insert immediately after `} forEach _town_teams;`, before `_town_teams = [];`)

**Interfaces:**
- Consumes: `_town_teams` (existing local var, full pre-clear group list), `_side`,
  `_town` (both already in scope in this cleanup block), `_rec select 3` (lastSpawnUnits,
  written by Task 4... actually written here).
- Produces: writes `strength` back into the ledger array on the side logic
  (`_logik getVariable ["WFBE_CTL_LEDGER", []]` → mutate → `setVariable` back), and
  `lastSpawnUnits` for next episode's ratio.

Can run in parallel with Tasks 4, 6, 7.

- [ ] **Step 1: Write and run the patch script**

```python
import io

path = r"Missions\[55-2hc]warfarev2_073v48co.chernarus\Server\FSM\server_town_ai.sqf"
with io.open(path, "r", encoding="utf-8-sig", newline="") as f:
    content = f.read()

anchor = "            } forEach _town_teams;\r\n"
assert content.count(anchor) == 1, "anchor not found or not unique - re-grep before patching"

block = (
    "\r\n"
    "            //--- Commander Town Ledger (fable/ctl-impl-v1) survivor read-back (B3).\r\n"
    "            //--- Flag-off (AICOMV2_LANE_CMD_TOWN_LEDGER=0) => skipped, byte-identical to HEAD.\r\n"
    '            if ((_side == west || {_side == east}) && {(missionNamespace getVariable ["AICOMV2_LANE_CMD_TOWN_LEDGER", 0]) > 0}) then {\r\n'
    '                private ["_ctlLogik","_ctlLedger","_ctlSurviving","_ctlRecIdx","_ctlFound","_ctlI"];\r\n'
    '                _ctlLogik    = (_side) Call WFBE_CO_FNC_GetSideLogic;\r\n'
    '                _ctlLedger   = _ctlLogik getVariable ["WFBE_CTL_LEDGER", []];\r\n'
    '                _ctlSurviving = 0;\r\n'
    '                {\r\n'
    '                    if (!isNull _x && {count (units _x) > 0}) then {_ctlSurviving = _ctlSurviving + (count (units _x))};\r\n'
    '                } forEach _town_teams;\r\n'
    '                _ctlFound  = false;\r\n'
    '                _ctlRecIdx = 0;\r\n'
    '                _ctlI      = 0;\r\n'
    '                {\r\n'
    '                    if (!_ctlFound && {(_x select 0) == _town}) then {_ctlFound = true; _ctlRecIdx = _ctlI};\r\n'
    '                    _ctlI = _ctlI + 1;\r\n'
    '                } forEach _ctlLedger;\r\n'
    '                if (_ctlFound) then {\r\n'
    '                    private ["_ctlRec","_ctlLastSpawn","_ctlRatio","_ctlNewStr"];\r\n'
    '                    _ctlRec       = _ctlLedger select _ctlRecIdx;\r\n'
    '                    _ctlLastSpawn = _ctlRec select 3;\r\n'
    '                    if (_ctlLastSpawn > 0) then {\r\n'
    '                        _ctlRatio  = (_ctlSurviving / _ctlLastSpawn) max 0;\r\n'
    '                        if (_ctlRatio > 1) then {_ctlRatio = 1};\r\n'
    '                        _ctlNewStr = ((_ctlRec select 2) * _ctlRatio) max 0;\r\n'
    '                        _ctlRec set [2, _ctlNewStr];\r\n'
    '                        diag_log Format ["CTLSTAT|v1|%1|READBACK|town=%2|ratio=%3|str=%4", str _side, _town getVariable ["name", "?"], _ctlRatio, _ctlNewStr];\r\n'
    '                    };\r\n'
    '                    _ctlRec set [3, 0];\r\n'
    '                    _ctlLedger set [_ctlRecIdx, _ctlRec];\r\n'
    '                    _ctlLogik setVariable ["WFBE_CTL_LEDGER", _ctlLedger];\r\n'
    '                };\r\n'
    '            };\r\n'
)

content = content.replace(anchor, anchor + block, 1)
with io.open(path, "w", encoding="utf-8-sig", newline="") as f:
    f.write(content)
print("patched server_town_ai.sqf")
```

Save as `_patch_task5.py`, run it, expect `patched server_town_ai.sqf`.

`lastSpawnUnits` (record field 3) must also be SET when a town activates and materializes
— that write belongs in Task 4's block (Server_GetTownGroups.sqf runs at activation, has
`_groups_max` in scope, but does NOT have direct ledger-array access, only the published
`wfbe_ctl_str`). Add it there via the side-logic ledger instead: extend Task 4's clamp
block to also look up and update `lastSpawnUnits` on the matching record. **Before writing
Task 4's final version, come back and add this** — do it now as part of this task since
it is the natural pairing with the read-back this step just wrote:

- [ ] **Step 2: Extend Task 4's patch to record `lastSpawnUnits` at spawn time**

Re-open `Server_GetTownGroups.sqf` (already patched by Task 4) and, inside the same CTL
`if` block added in Task 4 Step 1, immediately after the `deny=none`/`deny=groupBudgetExceeded`
`diag_log` lines (both branches), add a shared tail that writes `lastSpawnUnits` back to the
matching ledger record:

```python
import io

path = r"Missions\[55-2hc]warfarev2_073v48co.chernarus\Server\Functions\Server_GetTownGroups.sqf"
with io.open(path, "r", encoding="utf-8-sig", newline="") as f:
    content = f.read()

anchor = '\t\tdiag_log Format ["CTLSTAT|v1|%1|SPAWN|town=%2|str=%3|groups=%4|deny=none", str _side, _town getVariable ["name", "?"], _ctlStr, _groups_max];\r\n\t};\r\n'
assert content.count(anchor) == 1, "anchor not found or not unique - re-grep before patching"

block = (
    '\tprivate ["_ctlLogik2","_ctlLedger2","_ctlI2","_ctlFound2"];\r\n'
    '\t_ctlLogik2  = (_side) Call WFBE_CO_FNC_GetSideLogic;\r\n'
    '\t_ctlLedger2 = _ctlLogik2 getVariable ["WFBE_CTL_LEDGER", []];\r\n'
    '\t_ctlFound2  = false;\r\n'
    '\t_ctlI2      = 0;\r\n'
    '\t{\r\n'
    '\t\tif (!_ctlFound2 && {(_x select 0) == _town}) then {\r\n'
    '\t\t\tprivate ["_ctlRec2"];\r\n'
    '\t\t\t_ctlRec2 = _x;\r\n'
    '\t\t\t_ctlRec2 set [3, _groups_max];\r\n'
    '\t\t\t_ctlLedger2 set [_ctlI2, _ctlRec2];\r\n'
    '\t\t\t_ctlFound2 = true;\r\n'
    '\t\t};\r\n'
    '\t\t_ctlI2 = _ctlI2 + 1;\r\n'
    '\t} forEach _ctlLedger2;\r\n'
    '\t_ctlLogik2 setVariable ["WFBE_CTL_LEDGER", _ctlLedger2];\r\n'
)

content = content.replace(anchor, anchor + block, 1)
with io.open(path, "w", encoding="utf-8-sig", newline="") as f:
    f.write(content)
print("patched Server_GetTownGroups.sqf (lastSpawnUnits)")
```

Save as `_patch_task5b.py`, run it, expect `patched Server_GetTownGroups.sqf
(lastSpawnUnits)`. Note this writes `lastSpawnUnits` from the `deny=none` branch only —
that is correct: `_groups_max` at that point in the file already reflects whichever value
(clamped or not) actually gets handed to the spawn machinery, since the clamp branch
reassigns `_groups_max` before either `diag_log` runs.

- [ ] **Step 3: Bracket delta + lint on both files**

Run for `server_town_ai.sqf` and `Server_GetTownGroups.sqf`: same bracket-count and
`check_sqf.py` commands as prior tasks. Expected: unchanged bracket delta from each
file's pre-Task-5 baseline; zero new lint findings.

- [ ] **Step 4: Delete patch scripts and commit**

```bash
rm _patch_task5.py _patch_task5b.py
git add "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/FSM/server_town_ai.sqf" "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/Server_GetTownGroups.sqf"
git commit -m "feat(ctl): B3 survivor read-back writes strength on deactivation [flag AICOMV2_LANE_CMD_TOWN_LEDGER default 0]"
```

---

### Task 6: AI invest arm (B6/B7)

**Files:**
- Modify: `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander.sqf:766` (insert at the blank line after the REQDRAW block, before the CBR research comment)

**Interfaces:**
- Consumes: `_side`, `_logik`, `_funds`, `_humanSeated` (all already in scope at this point
  per the REQDRAW block's own usage), `Server_GetAICommanderFunds.sqf` /
  `Server_ChangeAICommanderFunds.sqf` (existing wallet primitives, called as
  `(_side) Call GetAICommanderFunds` / `[_side, -_cost] Call ChangeAICommanderFunds`).
- Produces: mutates the matching ledger record's `strength` and `investT0`; debits AI
  commander funds; emits `CTL_INVEST` / `CTL_INVEST_SKIP` telemetry.

Can run in parallel with Tasks 4, 5, 7 (different file).

**Known simplification (documented, not a placeholder):** the spec's skip-reason
vocabulary includes a distinct `townCooldown` reason, but this implementation folds
per-town cooldown into the target-search eligibility filter rather than surfacing it as
its own top-level skip reason. If every candidate town happens to be on its individual
cooldown, this code reports `reason=noTarget`, not `reason=townCooldown`. This is a
diagnostic-precision gap only — it does not affect purchase correctness (a town on
cooldown is correctly never bought while on cooldown either way). Acceptable for v1;
tighten only if soak review (Task 10) shows the coarser reason code actually obscures
something.

- [ ] **Step 1: Confirm the wallet primitive call signatures before writing this task's code**

Run: `grep -rn "Call GetAICommanderFunds\|Call ChangeAICommanderFunds" "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server"`
and read 2-3 call sites to confirm the exact argument shape used elsewhere in
`AI_Commander.sqf` itself (the REQDRAW/ECON SINK blocks already call these — copy their
exact invocation form rather than the generic form assumed below).

- [ ] **Step 2: Write and run the patch script**

```python
import io

path = r"Missions\[55-2hc]warfarev2_073v48co.chernarus\Server\AI\Commander\AI_Commander.sqf"
with io.open(path, "r", encoding="utf-8-sig", newline="") as f:
    content = f.read()

anchor_lines = content.split("\r\n")
# Anchor: the line immediately after REQDRAW's closing brace (line 765 per recon),
# which is blank, followed by the CBR research comment (line 767). Re-grep for
# "Reactive CBR research" to confirm this is still the next non-blank line before patching.
anchor = "\t\t};\r\n\r\n\t\t//--- Reactive CBR research:"
assert anchor in content or "//--- Reactive CBR research:" in content, "CBR anchor not found - re-grep AI_Commander.sqf for the REQDRAW block's closing brace before patching"

block = (
    "\t\t//--- Commander Town Ledger investment arm (fable/ctl-impl-v1, B6/B7). Flag-off\r\n"
    "\t\t//--- (AICOMV2_LANE_CMD_TOWN_LEDGER=0 or AICOMV2_CTL_INVEST_ENABLE=0) => skipped\r\n"
    "\t\t//--- silently - the lane flag gates existence, not just behaviour, so no telemetry\r\n"
    "\t\t//--- at all fires when either master switch is off.\r\n"
    '\t\tif ((missionNamespace getVariable ["AICOMV2_LANE_CMD_TOWN_LEDGER", 0]) > 0\r\n'
    '\t\t\t&& {(missionNamespace getVariable ["AICOMV2_CTL_INVEST_ENABLE", 0]) > 0}) then {\r\n'
    '\t\t\tprivate ["_ctlHumanBlock","_ctlFundsOk","_ctlCooldownOk","_ctlSkipReason","_ctlNow2"];\r\n'
    '\t\t\t_ctlNow2       = time;\r\n'
    '\t\t\t_ctlHumanBlock = _humanSeated && {(missionNamespace getVariable ["AICOMV2_CTL_INVEST_HUMAN_OFF", 1]) > 0};\r\n'
    '\t\t\t_ctlFundsOk    = _funds >= ((missionNamespace getVariable ["AICOMV2_CTL_INVEST_COST", 50000]) + (missionNamespace getVariable ["AICOMV2_CTL_INVEST_FLOOR", 250000]));\r\n'
    '\t\t\t_ctlCooldownOk = (_ctlNow2 - (_logik getVariable ["WFBE_CTL_INVEST_T0", -1e10])) > (missionNamespace getVariable ["AICOMV2_CTL_INVEST_COOLDOWN", 480]);\r\n'
    '\t\t\t_ctlSkipReason = "";\r\n'
    '\t\t\tif (_ctlHumanBlock) then {_ctlSkipReason = "human"};\r\n'
    '\t\t\tif (_ctlSkipReason == "" && {!_ctlFundsOk}) then {_ctlSkipReason = "floor"};\r\n'
    '\t\t\tif (_ctlSkipReason == "" && {!_ctlCooldownOk}) then {_ctlSkipReason = "cooldown"};\r\n'
    '\t\t\tif (_ctlSkipReason == "") then {\r\n'
    '\t\t\t\tprivate ["_ctlLedger","_ctlTarget","_ctlI","_ctlBestVal","_ctlTownCd"];\r\n'
    '\t\t\t\t_ctlLedger  = _logik getVariable ["WFBE_CTL_LEDGER", []];\r\n'
    '\t\t\t\t_ctlTarget  = -1;\r\n'
    '\t\t\t\t_ctlBestVal = -1;\r\n'
    '\t\t\t\t_ctlTownCd  = missionNamespace getVariable ["AICOMV2_CTL_INVEST_TOWN_COOLDOWN", 1200];\r\n'
    '\t\t\t\t_ctlI = 0;\r\n'
    '\t\t\t\t{\r\n'
    '\t\t\t\t\tprivate ["_rec","_str","_town","_val","_eligible"];\r\n'
    '\t\t\t\t\t_rec  = _x;\r\n'
    '\t\t\t\t\t_str  = _rec select 2;\r\n'
    '\t\t\t\t\t_town = _rec select 0;\r\n'
    '\t\t\t\t\t_eligible = (_ctlNow2 - (_rec select 4)) > _ctlTownCd;\r\n'
    '\t\t\t\t\tif (_eligible && {_str < 1.0}) then {\r\n'
    '\t\t\t\t\t\t_val = _town getVariable ["wfbe_town_value", 0];\r\n'
    '\t\t\t\t\t\tif (_val > _ctlBestVal) then {_ctlBestVal = _val; _ctlTarget = _ctlI};\r\n'
    '\t\t\t\t\t};\r\n'
    '\t\t\t\t\tif (_eligible && {_str >= 1.0 && {_str < 1.5}} && {_funds >= (missionNamespace getVariable ["AICOMV2_CTL_INVEST_SURGE_FLOOR", 600000])}) then {\r\n'
    '\t\t\t\t\t\t_val = _town getVariable ["wfbe_town_value", 0];\r\n'
    '\t\t\t\t\t\tif (_val > _ctlBestVal) then {_ctlBestVal = _val; _ctlTarget = _ctlI};\r\n'
    '\t\t\t\t\t};\r\n'
    '\t\t\t\t\t_ctlI = _ctlI + 1;\r\n'
    '\t\t\t\t} forEach _ctlLedger;\r\n'
    '\t\t\t\tif (_ctlTarget >= 0) then {\r\n'
    '\t\t\t\t\tprivate ["_ctlRec","_ctlStr","_ctlTier","_ctlCost","_ctlGain","_ctlNewStr"];\r\n'
    '\t\t\t\t\t_ctlRec  = _ctlLedger select _ctlTarget;\r\n'
    '\t\t\t\t\t_ctlStr  = _ctlRec select 2;\r\n'
    '\t\t\t\t\t_ctlTier = if (_ctlStr < 1.0) then {"repair"} else {"surge"};\r\n'
    '\t\t\t\t\t_ctlCost = missionNamespace getVariable ["AICOMV2_CTL_INVEST_COST", 50000];\r\n'
    '\t\t\t\t\tif (_ctlTier == "surge") then {_ctlCost = _ctlCost * (missionNamespace getVariable ["AICOMV2_CTL_INVEST_SURGE_MULT", 2])};\r\n'
    '\t\t\t\t\t_ctlGain   = missionNamespace getVariable ["AICOMV2_CTL_INVEST_GAIN", 0.25];\r\n'
    '\t\t\t\t\t_ctlNewStr = (_ctlStr + _ctlGain) min (missionNamespace getVariable ["AICOMV2_CTL_PAID_MAX", 1.5]);\r\n'
    '\t\t\t\t\t_ctlRec set [2, _ctlNewStr];\r\n'
    '\t\t\t\t\t_ctlRec set [4, _ctlNow2];\r\n'
    '\t\t\t\t\t_ctlLedger set [_ctlTarget, _ctlRec];\r\n'
    '\t\t\t\t\t_logik setVariable ["WFBE_CTL_LEDGER", _ctlLedger];\r\n'
    '\t\t\t\t\t_logik setVariable ["WFBE_CTL_INVEST_T0", _ctlNow2];\r\n'
    '\t\t\t\t\t[_side, -_ctlCost] Call WFBE_CO_FNC_ChangeAICommanderFunds;\r\n'
    '\t\t\t\t\tdiag_log Format ["AICOMSTAT|v2|EVENT|%1|%2|CTL_INVEST|town=%3|tier=%4|cost=%5|str=%6|funds=%7|fundedBy=aicom",\r\n'
    '\t\t\t\t\t\tstr _side, round (time / 60), (_ctlRec select 0) getVariable ["name", "?"], _ctlTier, _ctlCost, _ctlNewStr, _funds - _ctlCost];\r\n'
    '\t\t\t\t} else {\r\n'
    '\t\t\t\t\t_ctlSkipReason = "noTarget";\r\n'
    '\t\t\t\t};\r\n'
    '\t\t\t};\r\n'
    '\t\t\t//--- CTL_INVEST_SKIP: rate-limited to at most once per 300s per side, per spec\r\n'
    '\t\t\t//--- ("no log spam") - separate cooldown timestamp from the purchase cooldown.\r\n'
    '\t\t\tif (_ctlSkipReason != "" && {(_ctlNow2 - (_logik getVariable ["WFBE_CTL_INVEST_SKIP_T0", -1e10])) > 300}) then {\r\n'
    '\t\t\t\t_logik setVariable ["WFBE_CTL_INVEST_SKIP_T0", _ctlNow2];\r\n'
    '\t\t\t\tdiag_log Format ["AICOMSTAT|v2|EVENT|%1|%2|CTL_INVEST_SKIP|reason=%3|funds=%4", str _side, round (time / 60), _ctlSkipReason, _funds];\r\n'
    '\t\t\t};\r\n'
    '\t\t};\r\n'
    "\r\n"
)

content = content.replace(
    '//--- Reactive CBR research:',
    block.replace("\r\n\r\n", "\r\n") + '//--- Reactive CBR research:',
    1
)
with io.open(path, "w", encoding="utf-8-sig", newline="") as f:
    f.write(content)
print("patched AI_Commander.sqf")
```

Save as `_patch_task6.py`. Before running, **replace the placeholder function names**
`WFBE_CO_FNC_ChangeAICommanderFunds` with whatever Step 1 actually found at the real call
sites (this plan's guess is based on the file names `Server_GetAICommanderFunds.sqf` /
`Server_ChangeAICommanderFunds.sqf` reported by earlier recon, but the registered
function-name prefix — `WFBE_CO_FNC_`, `WFBE_SE_FNC_`, or something else — was not
independently confirmed and must come from Step 1's grep, not from this plan). Then run
it and expect `patched AI_Commander.sqf`.

- [ ] **Step 3: Bracket delta + lint on `AI_Commander.sqf`**

Expected: unchanged bracket delta from pre-Task-6 baseline; zero new lint findings.

- [ ] **Step 4: Delete patch script and commit**

```bash
rm _patch_task6.py
git add "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander.sqf"
git commit -m "feat(ctl): B6/B7 AI investment arm spends funds to raise town strength [flags AICOMV2_LANE_CMD_TOWN_LEDGER, AICOMV2_CTL_INVEST_ENABLE default 0]"
```

---

### Task 7: Telemetry tooling updates

**Files:**
- Modify: `Tools/PrTestHarness/Ops/aicom-watch.ps1` (the `Should-Show` function, ~lines 172-188)
- Modify: `Tools/Monitor/Get-WaspRptMarkerSweep.ps1` (the `$defaultPatterns` array, ~lines 193-209)

**Interfaces:**
- Consumes: nothing from prior tasks (pure tooling, independent of mission code).
- Produces: both scripts now recognize `CTLSTAT|` lines emitted by Tasks 2/4/5/6.

Can run in parallel with Tasks 4, 5, 6 — touches neither `.sqf` files nor the same
PowerShell files as any other task.

- [ ] **Step 1: Read the current `Should-Show` function verbatim**

Run: `Get-Content Tools\PrTestHarness\Ops\aicom-watch.ps1 | Select-Object -Skip 160 -First 40`
to see the exact current lines 161-200 before editing (line numbers may have drifted since
the original recon pass).

- [ ] **Step 2: Add the CTLSTAT match variable and include it in the OR condition**

Use PowerShell's `-replace` on the exact existing pattern (do not use Edit/Write on the
`.sqf` files in this repo, but this is a `.ps1` file — the Edit tool is fine here, this
restriction only applies to `.sqf`/`.fsm`/`.hpp`). Find the line:
```powershell
$isAicomstat = $line -match "AICOMSTAT\|"
```
and add immediately after it:
```powershell
$isCtlstat   = $line -match "CTLSTAT\|"
```
Then find the `Should-Show` return/OR expression that combines `$isAicom2`, `$isAicomstat`,
`$isWaspstat` and add `-or $isCtlstat` to it (read the exact expression first — Step 1's
output shows the real text; do not guess its exact form).

- [ ] **Step 3: Add `CTLSTAT|` to the RPT marker whitelist**

In `Tools\Monitor\Get-WaspRptMarkerSweep.ps1`, in the `$defaultPatterns = @(...)` array,
add `"CTLSTAT|"` as a new element, in the same style as the existing `"GRPBUDGET|WARN"`
and `"AICOMSTAT"` entries (comma-separated, one per line).

- [ ] **Step 4: Verify both scripts still parse**

Run: `powershell -NoProfile -Command "& { . 'Tools\PrTestHarness\Ops\aicom-watch.ps1' -WhatIf }" 2>&1 | Select-String -Pattern "error" -CaseSensitive:$false`
and the equivalent for `Get-WaspRptMarkerSweep.ps1`. Expected: no parse errors reported
(if the scripts don't support a bare dot-source without arguments, at minimum run
`powershell -NoProfile -Command "Get-Content <path> | Out-Null; [scriptblock]::Create((Get-Content <path> -Raw)) | Out-Null"` to confirm the file still parses as valid PowerShell after the edit).

- [ ] **Step 5: Commit**

```bash
git add "Tools/PrTestHarness/Ops/aicom-watch.ps1" "Tools/Monitor/Get-WaspRptMarkerSweep.ps1"
git commit -m "feat(ctl): recognize CTLSTAT| telemetry in RPT tooling"
```

---

### Task 8: Mirror-regen, lint, bracket-delta gate (integration)

**Files:** none new — this task verifies and propagates everything Tasks 1-7 touched.

- [ ] **Step 1: Confirm all Chernarus edits are committed**

Run: `git -C C:\Users\Steff\a2wasp-ctl-build status --short` — expect clean (all prior
task commits landed, nothing stray staged).

- [ ] **Step 2: Run mirror-regen**

```powershell
cd C:\Users\Steff\a2wasp-ctl-build\Tools\LoadoutManager
$env:A2WASP_SKIP_ZIP = "1"
dotnet run -c RELEASE
```
Expected: completes without error; Takistan and Zargabad mirrors now contain the same CTL
changes as Chernarus.

- [ ] **Step 3: Restore TK/ZG version templates to merge-base**

```powershell
cd C:\Users\Steff\a2wasp-ctl-build
git checkout origin/claude/build84-cmdcon36 -- `
  "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/version.sqf.template" `
  "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/version.sqf.template"
```

- [ ] **Step 4: Verify per-map template values are correct**

Confirm TK template still has `WF_MAXPLAYERS 61`, `STARTING_DISTANCE 7500`, no
`IS_CHERNARUS_MAP_DEPENDENT`, no `IS_NAVAL_MAP`; ZG template still has `WF_MAXPLAYERS 61`,
`STARTING_DISTANCE 5000`, no `IS_CHERNARUS_MAP_DEPENDENT`, no `IS_NAVAL_MAP`.

- [ ] **Step 5: Dry-run check for any residual drift**

Run: `dotnet run -c RELEASE -- --check` (from `Tools\LoadoutManager`). Expected: reports
no drift.

- [ ] **Step 6: Full lint pass across every file this feature touched**

```
python Tools\Lint\check_sqf.py --select A3CMD,A3HASH,A3MARKER,A3NUMGATE,A3PRIVATE,A3REVEAL,A3SELECT,A3SORT,A3STRING,BOOLCMP,BRACKET,DBLBOM,DEADNOQA,FLAGGATE,GROUPGETVAR,MILMARKER,NSSETVAR3,PUBVARSV,TRAILCOMMA --no-classname-index
```
Confirm zero NEW findings across all 6 touched Chernarus files (Init_CommonConstants.sqf,
Server_CmdTownLedger.sqf, Init_Server.sqf, Server_GetTownGroups.sqf, server_town_ai.sqf,
AI_Commander.sqf) and their TK/ZG mirrors.

- [ ] **Step 7: Stage and confirm nothing unwanted is included**

Run: `git -C C:\Users\Steff\a2wasp-ctl-build status --short` — confirm no `_MISSIONS.7z`,
no `nul` file, no unrelated line-ending churn beyond the 6 Chernarus files and their two
mirrors. Do not commit yet if mirror-regen touched unexpected files — investigate first.

- [ ] **Step 8: Commit the mirror propagation**

```bash
git add "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan" "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad"
git commit -m "feat(ctl): propagate CTL to Takistan/Zargabad mirrors [flag AICOMV2_LANE_CMD_TOWN_LEDGER default 0]"
```

---

### Task 9: a2oa-verify-command pass + T1 pure-core fixtures

**Files:** none identified yet — Step 3 may add a test fixture file once the harness
location is confirmed.

- [ ] **Step 1: List every SQF command/operator introduced or newly combined in Tasks 2-6 that isn't already proven-safe by direct precedent in this codebase**

From the code written above, the candidates worth double-checking against A2 OA 1.64 (not
already covered by an exact precedent quoted from `Server_GuerDirector.sqf` or
`AI_Commander.sqf` in this session): none identified — every construct used (`getVariable
[name, default]` on a Logic object, `setVariable` 2-arg form, `forEach`, `select`, `set`,
`round`, `min`/`max` as binary operators, `diag_log Format [...]`, `Call`) has a direct,
already-read precedent in `Server_GuerDirector.sqf` or the REQDRAW block quoted in this
plan. If a task's implementer used anything not on this list, add it here and run it
through the wiki Command-Version-Reference check before proceeding.

- [ ] **Step 2: If anything was added to the list, verify it**

For each flagged command: check the repo wiki Command-Version-Reference first, then the BI
wiki OA category (introduction version must be ≤ 1.64). If genuinely disputed, add an
offline probe: `diag_log "XWT|ctl-verify|<expr>|" + str (<expr>)` in a scratch test mission,
run it, confirm the logged result matches expectation, then remove the probe line.

- [ ] **Step 3: Locate the GUER Director's "T1 pure-core" test harness, if one exists**

The spec's Test Plan section says CTL's T1 tests should follow "GDIR harness style" —
engine-free fixtures proving conservation, baseline-parity, regen timing, read-back
clamping, and budget-clamp behaviour without needing a running Arma server. Run:
`Get-ChildItem -Recurse -Include "*.py","*.ps1" Tools | Select-String -Pattern "GDIR|conservation|fnClamp" -List`
and check `Tools/Soak` and any `Tools/PrTestHarness` subfolder for a fixture runner. Two
outcomes:

- **If found:** read its structure (how it stubs SQF arithmetic, what assertion format it
  uses) and write CTL-equivalent fixtures in the same file/format for: conservation
  (`totalStr` never increases except via regen-up-to-1.0 or a `strength set` inside the
  invest-arm block with a preceding debit), baseline parity (strength=1.0 ⇒
  `effectiveGroups == baselineGroups` exactly, for a representative set of
  `baselineGroups` values 2 through 7), regen timing (`REGEN_FULL_SEC / TICK_SEC` ticks to
  go from 0 to 1.0, verified against the `_regenPerTick` formula in Task 2's brain script),
  read-back clamping (ratio clamps to `[0,1]`; `lastSpawnUnits == 0` produces a no-op, not
  a divide-by-zero — Task 5's code must be checked against this: confirm the `if
  (_ctlLastSpawn > 0)` guard in Task 5 Step 1 actually prevents the divide-by-zero case).
- **If not found:** this codebase does not currently have an engine-free SQF test harness
  for this class of arithmetic. Do not invent one from scratch as a side effect of this
  plan (out of scope creep) — instead, hand-trace the same five properties above against
  the actual committed code from Tasks 2/4/5/6 and record the trace (formula-by-formula,
  with example numbers) in the PR body's test plan section as the T1 evidence, explicitly
  labeled "static hand-trace, not an automated fixture" per the evidence-wording rule.

---

### Task 10: Soak deploy + RPT verification

**Files:** none — this task produces evidence, not code changes.

- [ ] **Step 1: Package and deploy a candidate build to `Miksuus-TEST`**

Follow this repo's existing deploy/soak runbook (`docs/design/v2/SPEC-BOX-RUNBOOK.md` and
`Tools/Soak/README.md`) to get the `fable/ctl-impl-v1` branch running on the test box. Do
NOT deploy to any production/live host — `Miksuus-TEST` only, per the repo's owner
constraints ("Never deploy to the live server").

- [ ] **Step 2: Arm the lane for the soak run only**

On the test deployment, set `AICOMV2_LANE_CMD_TOWN_LEDGER = 1` (and, to exercise the
invest arm, `AICOMV2_CTL_INVEST_ENABLE = 1`) — this is a test-box-only override, not a
change to the committed default in `Init_CommonConstants.sqf`.

- [ ] **Step 3: Capture a full SEED → SPAWN → READBACK → regen cycle**

Let a W/E town get attacked and deactivate at least once. Pull the windowed RPT:
```powershell
.\Get-WindowedRpt.ps1   # per rpt-triage skill - window to current MISSINIT, use the HC RPT for AICOM lines
```
Confirm quoted lines for `CTLSTAT|v1|<side>|SEED|...`, `CTLSTAT|v1|<side>|SPAWN|...`,
`CTLSTAT|v1|<side>|READBACK|...`, and a periodic `CTLSTAT|v1|<side>|towns=...` audit line
all appear with sane values (no `NaN`, no negative `str`, `deny=` present).

- [ ] **Step 4: Capture one CTL_INVEST event**

With `AICOMV2_CTL_INVEST_ENABLE=1` and AI funds pushed above the floor, confirm an
`AICOMSTAT|v2|EVENT|<side>|<min>|CTL_INVEST|...` line appears with a plausible
`funds=<after>` delta matching `cost`.

- [ ] **Step 5: Flag-off byte-parity smoke**

Redeploy with `AICOMV2_LANE_CMD_TOWN_LEDGER = 0` (the committed default) on both Chernarus
and one mirror map. Confirm RPT shows zero `CTLSTAT|` lines and zero `CTL_INVEST` lines,
and town activation/deactivation RPT lines are otherwise unchanged from a pre-CTL baseline
capture.

- [ ] **Step 6: Grade via the soak scorer**

Run `Tools\Soak\analyze_soak.py` against the captured session per its existing usage
pattern; record the KPI output for the PR body's test-plan section.

- [ ] **Step 7: Record evidence, do not overclaim**

Write down the exact quoted RPT lines and commit hash used for this soak run. Per the
evidence-wording rule: this soak run is a T2/short-session smoke, not the full T3 Hetzner
ladder soak — say so explicitly in whatever report/PR body cites it.

---

### Task 11: pr-preflight final pass + draft PR

**Files:** none — process only.

- [ ] **Step 1: Re-run the claim/collision check**

```powershell
gh pr list --repo rayswaynl/a2waspwarfare --state open --limit 200 --json number,title,headRefName | ConvertFrom-Json | Where-Object { $_.title -match "ctl|ledger|commander-town" -or $_.headRefName -match "ctl|ledger|commander-town" }
git ls-remote --heads origin | Select-String -Pattern "ctl|commander-town|town-ledger"
```
Confirm still no new collision beyond the known spec-only branch. This repo moves fast
(multiple lanes merged mid-session during this plan's own brainstorming phase) — do not
skip this even though it was checked before Task 1.

- [ ] **Step 2: Flag-policy audit**

Confirm every new flag (Task 1's 16 constants) is appended-only (no existing default
changed), default 0 where specced, and every numeric flag read in Tasks 4-6 uses `> 0` not
bare truthiness.

- [ ] **Step 3: Confirm evidence wording in the PR body**

No "shipped"/"fixed"/"release-ready" claims. Runtime claims cite the Task 10 quoted RPT
lines and commit hash only — nothing beyond what Task 10 actually captured.

- [ ] **Step 4: Open the draft PR**

```powershell
gh pr create --draft --base claude/build84-cmdcon36 --title "feat(ctl): Commander Town Ledger - virtual per-town strength + paid AI investment for W/E [flags AICOMV2_LANE_CMD_TOWN_LEDGER, AICOMV2_CTL_INVEST_ENABLE default 0]" --body-file <path to a body file containing: feature description; full flag+default table from this plan; why flag-off is inert (single exitWith in brain + lazy && {} guards at every read site, per Task 1-6); test plan (cite Task 9 static verification and Task 10's quoted RPT evidence, explicitly marked as T2-level not T3); mirrors confirmed CH->TK->ZG (cite Task 8); GUIDE-REV GR-2026-07-03a; note this builds directly per spec PR #807 with no other in-flight lane collision as of the Step 1 recheck>
```

- [ ] **Step 5: Confirm the PR was created and report back**

Run: `gh pr view --repo rayswaynl/a2waspwarfare <PR number> --json number,url,isDraft,baseRefName` and
confirm `isDraft: true`, `baseRefName: "claude/build84-cmdcon36"`.
