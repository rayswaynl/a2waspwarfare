# Deadcode + Consistency Status (Lane 8)

Scope: post-merge lane-8 status sweep for the live target `claude/build84-cmdcon36`. This note does not remove source. It records which deadcode cleanups already landed, which apparent deadcode is live-loaded, and which follow-ups belong to another lane or an owner decision.

## Current Verdict

The safe lane-8 cleanup work that was already claimed earlier has merged:

- PR #144, `codex/deadcode-consistency-sweep`, merged on 2026-07-02. It removed the stale Parameters dialog `22005` uptime comment from Chernarus and the generated Takistan mirror.
- PR #146, `codex/deadcode-stale-defense-comments`, merged on 2026-07-02. It removed stale commented `Common\Config\Config_Defenses.sqf` scaffolds from the nine maintained defense config files and their Takistan mirror.

The current target has no remaining `22005` or `Config_Defenses.sqf` references in the maintained mission roots. Do not reopen those exact edits.

## False Positive: Defense Config Files

`docs/design/BASE-COMPOSITIONS-PROPOSAL.md:221` and `:277` call the old defense price arrays a footgun/dead-code delete candidate. The current source says the files themselves are not dead and should not be deleted under lane 8.

Live load chain:

- `Common/Init/Init_Common.sqf:332-334` compiles `Common\Config\Defenses\Defenses_%1.sqf` for west, east, and resistance.
- Each loaded defense file still calls `Common\Config\Config_Defenses_Towns.sqf` on the server, for example `Common/Config/Defenses/Defenses_US.sqf:72`, `Defenses_RU.sqf:72`, `Defenses_TKA.sqf:84`, and `Defenses_GUE.sqf:29`.
- `Common/Config/Config_Defenses_Towns.sqf:24` logs category registration.
- Runtime consumers read the resulting defense variables, including `Server/PVFunctions/RequestDefense.sqf:11`, `:154`, and `:199`, plus `Server/FSM/basearea.sqf:12-13`, `Client/Module/CoIn/coin_interface.sqf:245`, `:673`, and `:732`.

Conclusion: only the stale commented scaffold was dead, and PR #146 already removed it. Deleting `Defenses_*.sqf` would remove live town-defense category setup.

## Real But Not This Lane

Several items still look dead or transitional, but are not clean lane-8 cuts right now:

- `WFBE_C_SIM_GATING` is still registered at `Common/Init/Init_CommonConstants.sqf:506` and logged/read at `Server/Init/Init_Server.sqf:182` and `Server/AI/Commander/AI_Commander.sqf:1061`. The prompt assigns this to lane 172, which already has open PR #283 for another slice of that lane. Do not splice it into lane 8 without coordinating with lane 172.
- `WFBE_C_WALLS_V2` remains registered at `Common/Init/Init_CommonConstants.sqf:1725`, with comments at `Server/Init/Init_Defenses.sqf:61`, `Construction_SmallSite.sqf:127`, and `Construction_MediumSite.sqf:170` saying the wall-ladder implementation was reverted while V3 carries the active slab path. This is a compatibility/rollback naming decision, not an obvious deletion.
- `AI_Commander_HCTopUp.DRAFT.sqf` is still present, and `AI_Commander.sqf:428` nil-guards `WFBE_SE_FNC_AI_Com_HCTopUp`. Current top-up behavior also exists through the live `wfbe_aicom_topup_req` path in `AI_Commander_Produce.sqf:131-183` and `Common_RunCommanderTeam.sqf:2255-2289`. Because this touches HC/AICOM behavior and lane 97 history, do not delete the draft from a generic deadcode sweep.
- `docs/design/MISSION-AUDIT-60.md:49` mentions a double starved-infantry fallback in `AI_Commander_Teams.sqf`. That is AICOM source and should be handled in a coordinated AICOM lane with fresh source proof, not as broad cleanup.

## Suggested Next Lane-8 Shape

A future lane-8 PR should be one narrow, deletion-only cleanup with caller proof in the PR body. Good candidates should satisfy all of these:

- The target is not named by another active/open lane.
- `rg` proves no compile, call, event-handler, or missionNamespace consumer remains.
- The change is deletion-only or comment-only.
- Chernarus is edited first and Takistan is generated with LoadoutManager if mission source changes.

For now, lane 8 is best treated as partially complete: the two stale-comment cleanups are merged, the defense-file deletion candidate is a false positive, and the remaining interesting items are lane-owned or AICOM-sensitive.
