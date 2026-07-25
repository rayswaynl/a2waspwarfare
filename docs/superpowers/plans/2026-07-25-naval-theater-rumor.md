# Naval Theatre Rumor Announces Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add default-off, rate-limited player announcements for the existing USV activation gate and per-carrier CAP arming gate.

**Architecture:** Keep all existing server gate evaluation and latches unchanged. Add one interval constant and one last-announced timestamp per gate owner, and broadcast through the established `DashboardAnnounce` PVF only on false-to-true transitions when the new flag is enabled. Existing naval-map early exits provide the map gate.

**Tech Stack:** Arma 2 OA 1.64 SQF, PowerShell, Python SQF lint gate, .NET LoadoutManager, git, GitHub CLI.

## Global Constraints

- Edit only the Chernarus mission root; use LoadoutManager for any byte-identical mirror propagation.
- Use Arma 2 SQF syntax; no A3-only commands or inline `private _x =` declarations.
- Do not add units, gates, behavior, live-server changes, deployment, or merge operations.
- New flag `WFBE_C_NAVAL_THEATER_RUMOR` defaults to `0`; interval `WFBE_C_NAVAL_THEATER_RUMOR_INTERVAL` defaults to `120` seconds.
- Server authors and broadcasts messages through existing `DashboardAnnounce`.
- Commit on `codex/naval-rumor-20260725`, push it, and create a draft PR against `master`.
- Do not add a `Co-Authored-By` trailer.

### Task 1: Add constants and hook existing gate edges

**Files:**
- Modify: `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf` beside the naval constants.
- Modify: `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Server_USVFlotilla.sqf` around the existing `_gateWasActive` transition log.
- Modify: `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Init/Init_NavalHVT.sqf` around the existing `_armed = true` transition.

**Interfaces:**
- Consumes: existing `WFBE_C_NAVAL_HVT`, `IS_naval_map`, USV `_gateWasActive`, CAP `_armed`, and `WFBE_CO_FNC_SendToClients`.
- Produces: `WFBE_C_NAVAL_THEATER_RUMOR`, `WFBE_C_NAVAL_THEATER_RUMOR_INTERVAL`, one USV announcement edge, and one per-carrier CAP announcement edge.

- [ ] **Step 1: Add the constants**

Add these lines to the naval constants area:

```sqf
	if (isNil "WFBE_C_NAVAL_THEATER_RUMOR") then {WFBE_C_NAVAL_THEATER_RUMOR = 0}; //--- 0 = no naval theatre activity announcements; >0 = announce existing gate flips.
	if (isNil "WFBE_C_NAVAL_THEATER_RUMOR_INTERVAL") then {WFBE_C_NAVAL_THEATER_RUMOR_INTERVAL = 120}; //--- seconds between announcements for the same gate.
```

- [ ] **Step 2: Hook the USV false-to-true edge**

Declare and initialize `_rumorLast` beside `_gateWasActive`. Inside the existing `_gateActive && {!_gateWasActive}` block, after the existing diagnostic line, add:

```sqf
	if ((missionNamespace getVariable ["WFBE_C_NAVAL_THEATER_RUMOR", 0]) > 0) then {
		if ((time - _rumorLast) >= (missionNamespace getVariable ["WFBE_C_NAVAL_THEATER_RUMOR_INTERVAL", 120])) then {
			[nil, "DashboardAnnounce", ["Hostile small craft are active on the coast."]] Call WFBE_CO_FNC_SendToClients;
			_rumorLast = time;
		};
	};
```

Do not move or alter the existing gate evaluation, spawn condition, or `_gateWasActive` assignment.

- [ ] **Step 3: Hook each CAP false-to-true edge**

Declare and initialize `_rumorLast` in each carrier thread's existing private list/state. Immediately after the existing `_armed = true` assignment inside the existing `_sideID == WFBE_C_GUER_ID` branch, add:

```sqf
						if ((missionNamespace getVariable ["WFBE_C_NAVAL_THEATER_RUMOR", 0]) > 0) then {
							if ((time - _rumorLast) >= (missionNamespace getVariable ["WFBE_C_NAVAL_THEATER_RUMOR_INTERVAL", 120])) then {
								[nil, "DashboardAnnounce", [Format ["Carrier CAP airborne near %1.", _loc getVariable ["name", "the carrier"]]]] Call WFBE_CO_FNC_SendToClients;
								_rumorLast = time;
							};
						};
```

Do not alter `_anyNear`, ownership checks, CAP composition, spawn calls, or inactivity despawn logic.

- [ ] **Step 4: Run focused static checks**

Run `git diff --check`, inspect the diff, verify braces and brackets are balanced per edited file, and assert no new A3 trap appears in the three touched files.

- [ ] **Step 5: Commit the implementation**

```powershell
git add docs/superpowers/specs/2026-07-25-naval-theater-rumor-design.md docs/superpowers/plans/2026-07-25-naval-theater-rumor.md Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Server_USVFlotilla.sqf Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Init/Init_NavalHVT.sqf
git commit -m "feat(naval): add rate-limited theatre rumor announces [flag WFBE_C_NAVAL_THEATER_RUMOR default 0]"
```

### Task 2: Mirror and verify the production-shaped source tree

**Files:**
- Modify: any mirror outputs produced by `Tools/LoadoutManager`; do not hand-edit Takistan or Zargabad.
- Create: `RESULT.md` after the PR exists.

**Interfaces:**
- Consumes: committed Chernarus changes and repository mirror tooling.
- Produces: mirror parity, lint evidence, inertness evidence, pushed branch, draft PR, and result receipt.

- [ ] **Step 1: Run the mirror generator**

Run `A2WASP_SKIP_ZIP=1 dotnet run -c RELEASE` from `Tools/LoadoutManager`. If it fails because the .NET SDK is unavailable, stop with that exact blocker.

- [ ] **Step 2: Restore/check templates and mirror scope**

Restore only any drifted TK/ZG `version.sqf.template` files from `origin/master`, then verify TK has `WF_MAXPLAYERS 61` and `STARTING_DISTANCE 7500`, and ZG has `WF_MAXPLAYERS 61` and `STARTING_DISTANCE 5000`, with no Chernarus/naval defines.

- [ ] **Step 3: Run the required verification**

Run the full prescribed `check_sqf.py` selector, `dotnet run -c RELEASE -- --check`, `Test-WaspVersionTemplates.ps1` if present, delimiter checks, `git diff --check`, and targeted assertions that flag `0` prevents both `DashboardAnnounce` branches. Record global pre-existing lint findings separately from findings in edited files.

- [ ] **Step 4: Push and open the draft PR**

Run:

```powershell
git push -u origin codex/naval-rumor-20260725
gh pr create --repo rayswaynl/a2waspwarfare --draft --base master --title "feat(naval): rate-limited theatre rumor announces on existing USV/CAP gates [WFBE_C_NAVAL_THEATER_RUMOR default 0]" --body "..."
```

The body must describe the two hooked gates, 120-second per-gate rate limit, map gating, default-off inertness, tests, mirror status, and `GUIDE-REV: GR-2026-07-08a`.

- [ ] **Step 5: Write the result receipt and verify final state**

Write `RESULT.md` with the PR number, files touched, hooked gates, verification summary, and any unmet deliverable (or explicitly state none). Re-read it, confirm branch/PR state, and leave `TASK.md` untracked and unchanged.
