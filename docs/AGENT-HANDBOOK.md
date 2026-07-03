# AGENT-HANDBOOK — WASP Warfare deep reference
<!-- GUIDE-REV: GR-2026-07-03a -->

This file is the deep companion to `AGENTS.md` / `CLAUDE.md`. Read those first; come here
for the full how-to on tooling, traps, coordination, and deploy policy.

---

## LoadoutManager — full flow

The tool lives in `Tools/LoadoutManager/`. It reads loadout data from `Tools/LoadoutManager/Data/`
and writes generated SQF files into all three terrain missions.

**Standard run (after every SQF edit):**

```powershell
cd Tools\LoadoutManager
dotnet run -c RELEASE
```

Build configurations:
- `RELEASE` — production; use this for all PR work.
- `SERVER_DEBUG` — adds logging; use only when diagnosing a live-server issue.
- `DEBUG` — developer mode; not for deployment.
- `AIRWAR_RELEASE` / `AIRWAR_DEBUG` / `AIRWAR_SERVER_DEBUG` — Air War module builds.

**Dry-run (no file writes):**

```powershell
dotnet run -c RELEASE -- --check
```

Checks TK mirror drift and reports differences without writing. Safe to run repeatedly.

**Skipping the 7z pack:**

Set `A2WASP_SKIP_ZIP=1` before running if you want to suppress the `_MISSIONS.7z` creation
step entirely. The mirror always completes regardless; the pack step is optional.

**7-Zip discovery order:**
1. `7za` environment variable (path to executable)
2. `C:\Program Files\7-Zip\7za.exe` or `7z.exe`
3. `C:\Program Files (x86)\7-Zip\7za.exe`
4. `7za` / `7z` on PATH

If none is found, LoadoutManager logs a line and skips packing. The mirror still completes.

**What LoadoutManager generates:**

LoadoutManager writes `Common/Init/Init_CommonBalanceInit.sqf` and
`Client/Module/EASA/EASA_Init.sqf` (and related files) into all three terrain folders.
It does NOT mirror `mission.sqm`. TK and ZG `mission.sqm` changes are separate manual tasks.

**version.sqf.template restore procedure:**

LoadoutManager sometimes touches `version.sqf.template` as a side effect of terrain config
processing. Always restore both TK and ZG templates to the branch HEAD before staging:

```powershell
git checkout origin/claude/build84-cmdcon36 -- `
  "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/version.sqf.template" `
  "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/version.sqf.template"
```

Verify the restored values. CH template values are NOT valid for TK or ZG:

| Field | CH | TK | ZG |
|---|---|---|---|
| `WF_MAXPLAYERS` | 34 (naval) | 61 | 61 |
| `STARTING_DISTANCE` | 7500 | 7500 | 5000 |
| `IS_CHERNARUS_MAP_DEPENDENT` | defined | NOT defined | NOT defined |
| `IS_NAVAL_MAP` | defined | NOT defined | NOT defined |

---

## Zargabad-specific constants and scripts

Zargabad (`Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/`) is a small dense urban
map (~8 towns, 8192m world size). CH defaults are scaled for Chernarus (40+ towns, 15360m)
and are unreachable on ZG, so ZG carries a worldName-gated pre-set block.

**ZG AICOM tuning block** (in `Common/Init/Init_CommonConstants.sqf`, guarded with
`if (worldName == "Zargabad") then { ... }`):

```sqf
WFBE_C_AICOM_HQSTRIKE_MIN_TOWNS = 5     // CH default: 12
WFBE_C_AICOM_ENGAGE_MIN_TOWNS   = 4     // CH default: varies
WFBE_C_AICOM_LANE_OFFSET        = 60    // matches TK value
WFBE_C_AICOM_ASSAULT_REACH_FOOT = 1800  // matches TK value; the worldName guard at ~1229
                                         // sets 1800 for TK but 2500 for ZG — this pre-set
                                         // runs first and wins on ZG
WFBE_C_BASE_EGRESS_MAP_BOUNDS   = 1     // use Init_Boundaries ZG size (8192) not legacy 15360
```

These run BEFORE the `isNil`-guarded CH/TK defaults below them, so ZG values win.
CH and TK are byte-identical (the `worldName` guard skips the entire block on those maps).

**ZG lobby-param notes:**

`STARTING_DISTANCE` in `version.sqf.template` is 5000 for ZG (vs 7500 for CH/TK). This
reflects ZG's map size. Do not propagate the CH value during template restores.

**mission.sqm:** ZG `mission.sqm` is maintained separately and is not touched by LoadoutManager.
Slot-count changes require manual edits to all three `mission.sqm` files.

---

## SQF trap taxonomy — full reference

Each trap below gives the rule and the WHY in one line.

### A3-only commands (A2 OA 1.64 does not have these)

| Trap | Why |
|---|---|
| `isEqualType` | A3-only; no A2 equivalent |
| `isEqualTo` | A3-only; use `==` for scalars/strings |
| `params` | A3-only; parse with `_x = _this select N` |
| `pushBack` | A3-only; use `_arr = _arr + [elem]` |
| `findIf` | A3-only; use a `forEach` with a flag |
| `apply` | A3-only; use `forEach` + accumulate |
| `selectRandom` (command form) | A3-only; use `_arr select (floor (random (count _arr)))` |
| `forceFollowRoad` | A3-only |
| `worldSize` | A3-only; use `Init_Boundaries` values |
| `getPosVisual` | A3-only; use `getPosATL` or `getPos` |
| Array-form `reveal` | A3-only; `group reveal target` only |
| `find` on strings | A3-only; use `count` trick or `in` |
| `select [a, b]` substring | A3-only |
| Sort-by-code | A3-only |

### Inline private (A3 syntax)

`inline private _x =` is A3-only. Use `private ["_x"]` at the top of the scope, then assign.

### Boolean comparison

Never use `==` or `!=` with Boolean operands. `true == true` compiles but has undefined
behaviour in A2 OA. Use `if (_flag)` and `if (!_flag)`.

### NSSETVAR3 trap

`missionNamespace setVariable ["NAME", value, true]` — the third (public) argument causes an
A2/OA runtime error. Use `missionNamespace setVariable ["NAME", value]` and separately call
`publicVariable "NAME"` if broadcasting is needed.

### Group getVariable

`_grp getVariable ["name", default]` with a default value does not work on GROUP receivers
in A2 OA. Use `WFBE_CO_FNC_GroupGetBool` for boolean group vars, or the 1-arg form +
`isNil` guard.

### forEach _x rebinding

Outer `_x` is permanently rebound by any inner `forEach`. Save it first:

```sqf
// CORRECT
{
  private ["_outer"];
  _outer = _x;
  { doSomething [_outer, _x] } forEach _innerList;
} forEach _outerList;
```

### exitWith inside forEach

`exitWith` in `forEach` exits the entire scope, not just the current iteration. Use `if`
nesting to skip an iteration.

### publicVariableServer from server

Never call `publicVariableServer` from server-side code. The server is the namespace;
call the server callback function directly.

### Numeric flags

`if (WFBE_C_SOME_FLAG)` when the flag is a number (0/1) evaluates 0 as true in A2 OA
because any number is truthy except... it is in fact false for 0. Safe to use with
`> 0` guard for clarity and lint compliance: `if (WFBE_C_SOME_FLAG > 0)`.

### isKindOf on weapons/magazines

`isKindOf` walks `CfgVehicles`, not `CfgWeapons` or `CfgMagazines`. Never use it to check
weapon or magazine classnames; it will always return false or walk the wrong tree.

### Has launcher

"Has launcher" = `secondaryWeapon _unit != ""`, not `primaryWeapon`. The primary slot is
for rifles.

### MenuAction reset in two-click confirm

Do not reset `MenuAction` to the default before the second click in a two-click confirm flow.
The first click sets state; resetting between clicks breaks the flow.

### getDammage / setDammage spelling

`getDammage` and `setDammage` (double-m) are the correct A2 OA spellings. `getDamage` is A3.
Do not rename them.

### Valid A2 OA syntax that looks wrong

These are valid and must not be changed:

- `;;` — empty statement, parses fine
- `&& {code}` / `|| {code}` — A2 OA short-circuits lazy-eval code blocks
- `isNil {code block}` — code-block form is valid in A2 OA
- SQF command names are case-insensitive; `getVariable`, `GETVARIABLE`, `GetVariable` are all
  the same. Casing-only command diffs are false positives.

---

## RPT smoke and testing guidance

### HC RPT vs server RPT

AICOM team events (expansion, assault, strike, lane allocation) go to the HC RPT
(`ArmA2OA.RPT`), not `arma2oaserver.RPT`. When reading AICOM logs, scope to the current
`MISSINIT` boundary — earlier log content belongs to a previous session.

The server RPT carries spawn, town-capture, player-purchase, and supply events.

### Live watch

```powershell
powershell -ExecutionPolicy Bypass -File Tools\PrTestHarness\Rpt\Watch-WaspLiveRpt.ps1 -Once
```

During a Steff playtest, report inline ticks in chat rather than setting up recurring automation
unless Steff explicitly asks for it.

### Post-run analysis

```powershell
powershell -ExecutionPolicy Bypass -File Tools\PrTestHarness\Rpt\Analyze-WaspStressRpt.ps1 -CurrentRun -LiveSummary
```

Key tokens to search for in RPT:
`QUEUE_PROOF`, `QUEUE_STEP`, `QUEUE_END`, `QUEUE_NOT_TRIGGERED`, `AI_BEHAVIOR`,
`AI_DELEGATION_AUDIT`, `GPS_UI_AUDIT`, `CLIENT_GPS_STATE`, `BUGHUNT_AUDIT`,
`FACTORY_AUDIT`, `SERVICE_SUPPLY_AUDIT`, `WDDM_ARTILLERY_AUDIT`, `PERF_BURST`, `PERF #`.

### Pre-test final check

```powershell
pwsh Tools\PrTestHarness\Run-WaspFinalCheck.ps1
```

Runs the static smoke gate + whole-mission bug-hunt. Does not replace in-engine testing.

---

## Stacked-PR walkthrough

A stacked PR is required when your target file is already touched by an open (draft) PR.

1. Identify the in-flight PR number (`gh pr list --state open --base claude/build84-cmdcon36`).
2. Find its branch HEAD: `gh pr view <N> --json headRefName,headRefOid`.
3. Create your branch from that HEAD, not from `origin/claude/build84-cmdcon36`:
   ```
   git checkout -b codex/<lane>-<topic> <headRefOid>
   ```
4. Do your work and commit normally.
5. Open your draft PR with `--base` set to the in-flight PR's branch:
   ```
   gh pr create --draft --base <in-flight-branch> --title "..."
   ```
6. In the PR body state: "Stacked on #NNN — rebases cleanly on that PR's HEAD."
7. When the upstream PR merges, rebase your branch onto `claude/build84-cmdcon36` and
   change the base: `gh pr edit <your-N> --base claude/build84-cmdcon36`.

---

## Review checklist

Before requesting review or marking a PR ready:

- [ ] Lint gate passed: `check_sqf.py --select A3CMD,A3MARKER,A3REVEAL,A3SELECT,A3SORT,A3STRING,GROUPGETVAR,BRACKET,NSSETVAR3 --no-classname-index`
- [ ] Net bracket delta is zero per edited file
- [ ] All new classnames present in mission tree or config proof attached
- [ ] Flag-off leaves mission byte-identical to HEAD (diff the generated output)
- [ ] `dotnet run -c RELEASE` completed without error
- [ ] TK and ZG `version.sqf.template` restored to merge-base values
- [ ] TK and ZG templates verified: correct MAXPLAYERS, STARTING_DISTANCE, defines
- [ ] No A3-only commands in the diff
- [ ] No NSSETVAR3 in the diff
- [ ] No `inline private _x =` in the diff
- [ ] No `Co-Authored-By` trailer in any commit
- [ ] PR body cites GUIDE-REV `GR-2026-07-03a`
- [ ] PR body contains: flag name, default, why flag-off is inert, test plan
- [ ] Shelved-PR register checked for duplicate proposals

---

## Match-report known bugs

Location: `Tools/MatchReport/`

1. **Trailing-quote map parse failure.** The RPT map-name parser fails when the map string
   has a trailing quote inside the `WASPSTAT` line. Workaround: post-process the slice with
   `replay_summary.py` and check the map field before rendering.

2. **`WaspMatchEndRotate` dual-PBO abort.** When two PBO files exist for the same build
   (e.g., from a mid-session switch), `produce-match-report.ps1` may pick the wrong one
   and abort. Fix: ensure only one PBO is present in `MPMissions` for the active build.

3. **Scheduled task not installed.** `PRODUCTION.md` describes a `WaspMatchReport` scheduled
   task; as of GR-2026-07-03a it has not been registered on the Game PC. Reports must be
   triggered manually with `pwsh -File produce-match-report.ps1 -RptFile <log>`.

**Town coordinates:** `WFBE_C_LOG_TOWN_COORDS` is currently set to 1 in the live build.
This causes coordinate-harvest lines to be emitted every match. Reset to 0 in
`Common/Init/Init_CommonConstants.sqf` after harvesting coordinates into
`Tools/MatchReport/matchdata.py::TOWN_COORDS`. Leaving it at 1 is log noise, not a crash.

---

## Box and deploy policy

All code changes ship as draft PRs. The owner folds PRs to the live server manually.

- Never SSH to `livehost` or any Hetzner box to deploy, restart, or copy mission files.
- Never register or modify scheduled tasks on the Game PC.
- Never touch `server-config/` with the intent to deploy; it is reference-only.
  The `server-config/README.md` covers the Hetzner vs Game PC relationship and operator runbook.
  Server credentials and IPs are in `server-config/README.md`, not here.
- The `Tools/Ops/Set-MissionTemplate.ps1` helper is an operator tool; do not call it from agent code.

If you need to verify live server state for debugging, ask the owner to run the relevant
`Tools/Ops/` or `Tools/PrTestHarness/Ops/` helper and share the output.

---

## Shelved-PR register

Before proposing any fix for an audit-flagged issue, check `wiki/Shelved-PR-*.md`.
Shelved PRs are proposals the owner explicitly rejected or deferred. Re-opening them or
duplicating their content wastes a review slot and will be closed without merge.

Current shelved topics include proposals for: TPWCAS integration, AI supply trucks,
satchel AI, EMP/WP/DECOY SCUD munitions, doctrine personalities, antistack adjustments,
ACR content additions. Do not re-propose any item on the owner-rejected list in `AGENTS.md`.
