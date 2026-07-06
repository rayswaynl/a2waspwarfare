# WASP Warfare — Agent Guide
<!-- GUIDE-REV: GR-2026-07-03a — PR bodies MUST cite this rev -->

This is an Arma 2: Operation Arrowhead 1.64 (EOL) Warfare fork. Three maintained terrains:
Chernarus (source), Takistan (mirror), Zargabad (mirror). All work is delivered as draft PRs
to `origin/claude/build84-cmdcon36`; agents never deploy to the live server. SQF scripting
reference: https://community.bistudio.com/wiki/Category:Arma_2:_Operation_Arrowhead:_Scripting_Commands
Ignore all Arma 3 documentation. Deep reference: `docs/AGENT-HANDBOOK.md`.

---

## Source rule and three-terrain mirror

Edit only `Missions/[55-2hc]warfarev2_073v48co.chernarus/`. Never edit TK or ZG files directly
except for `mission.sqm` (LoadoutManager does not mirror it).

After every SQF edit, propagate to both mirrors:

```powershell
cd Tools\LoadoutManager
dotnet run -c RELEASE
```

If `dotnet run` fails: stop and tell the user to install the .NET SDK. 7-Zip is auto-detected
from the `7za` env var, `C:\Program Files\7-Zip`, or PATH; if none is found it logs a line and
skips the optional `_MISSIONS.7z` pack step only — the mirror still completes.
Set `A2WASP_SKIP_ZIP=1` to suppress packing explicitly.

After the run, restore any `version.sqf.template` that drifted on TK or ZG to its pre-run
merge-base state before staging:

```powershell
git checkout origin/claude/build84-cmdcon36 -- \
  "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/version.sqf.template" \
  "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/version.sqf.template"
```

Verify the TK and ZG templates contain their correct per-map values (not CH values):
- TK: `WF_MAXPLAYERS 61`, `STARTING_DISTANCE 7500`, no `IS_CHERNARUS_MAP_DEPENDENT`, no `IS_NAVAL_MAP`
- ZG: `WF_MAXPLAYERS 61`, `STARTING_DISTANCE 5000`, no `IS_CHERNARUS_MAP_DEPENDENT`, no `IS_NAVAL_MAP`

Dry-run (no write): `dotnet run -c RELEASE -- --check` (reports TK drift without writing files).

---

## SQF editing on Windows

The Edit/Write tools trigger a reformatter that reflows entire files. All SQF edits must use
targeted Python scripts (read file, apply replacement, write back) that preserve CRLF line endings.
Never use the Edit or Write tool on `.sqf` files.

---

## A2 OA hard-stop traps

Never use — these are A3-only or wrong-spelling and will silently corrupt or crash on A2 OA 1.64:

- `isEqualType`, `isEqualTo`, `params`, `pushBack`, `findIf`, `apply`
- `selectRandom` (command form), `forceFollowRoad`, `worldSize`, `getPosVisual`
- `remoteExec`, `distance2D`, `setGroupOwner`, `groupOwner`, `joinGroup`
- Array-form `reveal`, A3 `find` on strings, substring `select [a, b]`, sort-by-code
- `inline private _x =` — use `private ["_x"]`
- `==` / `!=` with Boolean operands — use `if (_flag)` / `if (!_flag)`
- `missionNamespace setVariable` with a third (public) argument — NSSETVAR3 trap; A2/OA runtime error
- `getVariable [name, default]` on a GROUP receiver — use `WFBE_CO_FNC_GroupGetBool` or 1-arg + `isNil`
- Capture outer `_x` before any inner `forEach`; inner loop permanently rebinds it
- Never use `exitWith` inside `forEach` to skip one iteration — use `if` nesting instead
- Never use `publicVariableServer` from the server — call the server callback directly
- Guard numeric-threshold flags with `> 0`, not bare `if (number)`
- Never use `isKindOf` on weapon or magazine classnames — it walks `CfgVehicles`
- "Has launcher" = non-empty `secondaryWeapon _unit`, not `primaryWeapon`
- Never reset `MenuAction` before the second click in a two-click confirm flow
- Every new classname must appear in the mission tree or the PR must include config proof

Valid A2 OA syntax that linters incorrectly flag as errors (do not remove):
`getDammage`/`setDammage` (double-m is correct), `;;`, `&& {code}`, `|| {code}`, `isNil {block}`.
SQF command names are case-insensitive; casing-only diffs are false positives.

---

## Flag policy

- Feature additions: flag-gate with `missionNamespace getVariable ["WFBE_C_FLAG", 0]`, default 0.
  With the flag at 0 the mission must be byte-identical to HEAD.
- Correctness fixes (crashes, nil dereferences, idempotency guards): ship directly, no flag required.
- Append new flag registrations to `Common/Init/Init_CommonConstants.sqf` only; never change existing defaults.
- `WFBE_C_SIM_GATING` is owner-rejected; never wire it.

---

## Before every PR

1. Run the lint gate:
   ```
   python Tools\Lint\check_sqf.py --select A3CMD,A3MARKER,A3NUMGATE,A3REVEAL,A3SELECT,A3SORT,A3STRING,GROUPGETVAR,BRACKET,NSSETVAR3 --no-classname-index
   ```
2. Verify net bracket delta is zero per edited file (count `{` and `}`, count `[` and `]`).
3. Confirm flag-off leaves the mission byte-identical to HEAD.
4. Confirm mirrors ran and TK/ZG templates are restored.
5. No `Co-Authored-By` trailer in any commit.

---

## PR mechanics

- Draft PRs only: `gh pr create --draft --base claude/build84-cmdcon36`
- Branch naming: `codex/<lane>-<topic>` or `fable/<topic>`; never target `master`
- Commit format: `feat(<lane>): <summary> [flag <FLAG> default 0]`
- PR body required fields: feature description, flag name + default, why flag-off is inert,
  test plan, mirrors confirmed, GUIDE-REV `GR-2026-07-03a`
- Never stage line-ending-churn files, `_MISSIONS.7z`, or a `nul` file artifact

---

## Claim protocol

Before starting any task:
1. Check `agent-status.json` for in-progress claims on the target files. This is a
   fleet-coordinator runtime artifact and may be absent in the repo — if not present,
   fall back to the wiki Agent-Worklog page
   (`https://github.com/rayswaynl/a2waspwarfare/wiki/Agent-Worklog`) and open-PR check.
2. Check open PRs for in-flight branches touching the same files.
3. Check the Block J avoid-list in the fleet prompt for forbidden file sets.
4. If a target file is touched by an in-flight PR, base on that PR's HEAD and declare
   "stacked on #NNN" in the PR body.
5. One active claim at a time per lane.

See `CODEX-FLEET-PROMPT.md` for the full lane board and lane assignment rules.
`CODEX-FLEET-PROMPT.md` is a fleet-coordinator runtime artifact and may be absent
from the repo; if not present, check the wiki Agent-Worklog and open PRs directly.

---

## Where to look

- AICOM team logs: HC RPT (`ArmA2OA.RPT`), not `arma2oaserver.RPT`; scope reads to the
  current `MISSINIT` boundary.
- Soak KPIs: `Tools/Soak/README.md`
- Fleet lanes: `CODEX-FLEET-PROMPT.md`
- Deep tooling reference (LoadoutManager full flow, template restore, RPT smoke, stacked-PR walkthrough,
  full trap taxonomy, match-report bugs, ZG constants): `docs/AGENT-HANDBOOK.md`
- Wiki Agent-Guide: https://github.com/rayswaynl/a2waspwarfare/wiki/AI-Assistant-Developer-Guide

---

## Owner constraints

- Never deploy to the live server; PRs are the only output.
- Never touch: HC architecture, player enrollment/JIP flow, deploy/box scripts.
- GUER volume is the point; no caps or nerfs to GUER output.
- Do not re-propose: TPWCAS, AI supply trucks, satchel AI, EMP/WP/DECOY SCUD munitions,
  doctrine personalities, antistack touch, ACR content.
- Shelved PRs (https://github.com/rayswaynl/a2waspwarfare/wiki/Shelved-PR-*) are closed
  proposals; do not re-open or duplicate. Check the shelved-PR register before proposing
  any audit-flagged fix.
- Convention pointers:
  - Global hotkeys: `Client/Init/Init_Client.sqf` via `findDisplay 46` `KeyDown` handlers.
    Unrelated features go in separate `Common/Functions/Common_*.sqf` files.
    Gear filler hotkeys: `Client/Init/Init_Keybind.sqf`.
  - Unit purchases: `Client/GUI/GUI_Menu_BuyUnits.sqf` → `Client/Functions/Client_BuildUnit.sqf` (player);
    `Server/Functions/Server_BuyUnit.sqf` (AI team).
  - Debug lines: `WFBE_CO_FNC_LogContent` output is gated by the `WF_LOG_CONTENT` define
    (set in `version.sqf`), NOT by `WF_Debug`. On the HC, LogContent is ALWAYS active
    regardless of the define (`initJIPCompatible.sqf:72` forces it on for every HC).
    Use one always-on `INFORMATION`/`WARNING` line for the feature state transition or
    failure to confirm in RPT; gate verbose value dumps behind `WF_LOG_CONTENT`.
