# Review: towns & garrison map visualization GUI (wasp-review-towns-garrison-viz-20260731)

Reviewer: kimi-main-07311829-night (kimi) — 2026-07-31
Target: worktree `C:/Users/Steff/_wt-townsviz`, branch `codex/towns-garrison-viz`, base `e34750c49c`, 10 files uncommitted (+277/-21), READ-ONLY review (no stash, no edits).

## Verdict

**DO NOT SHIP — already shipped and armed on master. The worktree diff is an obsolete pre-merge draft.**

The exact change under review landed on `origin/master` as **PR #1321** (`f7f8fc4714 feat(townsviz): per-town garrison view in Towns tab [flag WFBE_C_TOWNS_TAB_GARRISON default 0]`), and was subsequently **armed to default 1** on 2026-07-28 by `191b9f51e5 fix(ui): Towns button dead on WEST/EAST - un-gate it + arm the garrison view`, with a follow-up `48cc57ef8f fix(ui): re-gate the Economy button - self-correction of #1561`.

### Evidence

- New panel `Client/GUI/GUI_Menu_TownsGarrison.sqf` in the worktree is **byte-identical (mod CRLF) to origin/master** on all three terrains (CH/TK/ZG).
- `Tools/Lint/test_wfmenu_towns_route.py` worktree version is **byte-identical** to origin/master.
- Master `Init_CommonConstants.sqf:2430` already registers `WFBE_C_TOWNS_TAB_GARRISON` — **default 1 (ARMED)**, with the owner-driven rationale recorded inline ("The towns button is not working for Blufor / Opfor").
- Master `Rsc/Dialogs.hpp:5335` already contains `class WFBE_TownsGarrisonMenu` (idd 31100).
- Master `GUI_Menu.sqf:303` already contains the flag-gated `MenuAction == 26` route (flag-on → `WFBE_TownsGarrisonMenu`; flag-off → legacy GUER Commissar route / W-E hint).
- The remaining file diffs vs master are only **master having moved on** since base `e34750c49c` (cmd-clipping, cmd-deck, econ-regate, VBIED speed, GUER airdef tuning). Applying the worktree diff now would *revert* those newer master changes.

## Overlap check vs `codex/07180826-1-map-clarity-toggles` (fold-wave-2)

**No overlap.** That branch touches only `Server/Functions/Server_HandleSpecial.sqf` (×3 terrains, AICOM team-marker feed nil-guard) plus `Tools/Aicom/Test-CommanderTeamMarkerFeed.ps1`. Zero shared files with the towns-garrison-viz set (GUI_Menu.sqf, Dialogs.hpp, Init_CommonConstants.sqf, GUI_Menu_TownsGarrison.sqf, lint test). No double-shipping risk between the two — and the viz side is moot anyway since it is already merged.

## Functional sanity of the shipped code (spot-check, since it is live-armed)

- Intel gate is sound: own-side only via `(_town getVariable ["sideID", -1]) == _ownSideID` plus `side _unit == sideJoined`; enemy/unknown towns never enumerated.
- Data path is legit: `WFBE_IsTownDefenderAI` is stamped with the 3-arg **public** broadcast (`setVariable [..., true, true]`) from all server spawn paths (`Server_SpawnTownDefense.sqf`, `Server_OperateTownDefensesUnits.sqf`, `Common_CreateTownUnits.sqf`, GUER wildcard/QRF/airdef), so clients can actually read it.
- No A2 OA hard-stop traps: no `pushBack`/`remoteExec`/`params`/`#`-selector; array append via `set [count ...]`; 2-arg `getVariable` on objects (not groups) — fine.
- idd 31100 unique in Dialogs.hpp; `MenuAction` 90/91 do not collide with any existing `GUI_Menu.sqf` handler (only `MenuAction == 9` exists in the 9x range).
- Flag-off path is behavior-identical to the pre-feature route (GUER → Commissar panel, W/E → hint).
- Minor cosmetic note (not worth a PR on its own): panel falls back `_range` default 600 then clamps `if (_range < 700) then {_range = 700}` — the 600 default is dead. Harmless.

## Fold plan

None required — nothing to fold. Recommended disposition (owner action, outside this read-only review):

1. Retire/delete worktree `C:/Users/Steff/_wt-townsviz` and branch `codex/towns-garrison-viz`; the uncommitted draft is fully superseded by master (`f7f8fc4714` + `191b9f51e5` + `48cc57ef8f`).
2. Fold-wave-2 card `wasp-fold-wave2-20260731` proceeds with `codex/07180826-1-map-clarity-toggles` only — no towns-viz content to dedupe against it.
3. If a fleet card still tracks "arm WFBE_C_TOWNS_TAB_GARRISON": close it — already armed at default 1 since 2026-07-28.
