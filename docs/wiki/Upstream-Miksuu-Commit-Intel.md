# Upstream Miksuu Commit Intel

Source-grounded index of useful context from [Miksuu/a2waspwarfare](https://github.com/Miksuu/a2waspwarfare). Use this page when comparing `rayswaynl/master`, current docs/source branches, Miksuu's active master and old PR discussions.

Snapshot time: `2026-06-03T14:55:00+02:00`.

## Snapshot

| Field | Current finding |
| --- | --- |
| Upstream repo | [Miksuu/a2waspwarfare](https://github.com/Miksuu/a2waspwarfare) |
| Default branch | `master` |
| GitHub pushed time | `2026-06-03T05:35:51Z` from `gh repo view` |
| Local checkout | `work/miksuu-a2waspwarfare` |
| Rays comparison remote | `miksuu` remote in the `work/a` checkout |
| Tags | None returned by `git ls-remote --tags origin` |
| Issues | `gh issue list --state all` returned no issues |
| PRs | 12 PRs total; 10 merged, 2 closed/unmerged |
| Recent PR comments | Recent PRs #10-#12 have no comments; bodies and commit messages are the useful context |

## Delta Against Rays Master

`rayswaynl/master` and `miksuu/master` currently share merge base `2cdf5fb8058b4ede4faa212ecc4fc52d9d83eef8` (`Merge branch 'Marty_fix_dead_AI_command_bar'`, 2026-06-02).

Miksuu's current master is 3 commits ahead of that base:

| Commit | Date | Scope | Why it matters |
| --- | --- | --- | --- |
| [`913ecdf6`](https://github.com/Miksuu/a2waspwarfare/commit/913ecdf6b55698ad8ea5de70dc1ecb33193b17ce) | 2026-06-02 | Chernarus source | Adds town-defense diagnostics and null-safety around group/unit/vehicle creation. |
| [`d5bfe3a2`](https://github.com/Miksuu/a2waspwarfare/commit/d5bfe3a26d677d84c49188abe8d92c03b72f049f) | 2026-06-02 | Vanilla Takistan | Propagates the same town-defense diagnostics/safety changes to maintained Vanilla Takistan. |
| [`8bcc42b1`](https://github.com/Miksuu/a2waspwarfare/commit/8bcc42b1d9becd9f0baa95a4a570f88113204a9a) | 2026-06-02 | Merge | Merges `Marty_town_defense_diagnostics` into Miksuu master. |

The diff from the merge base to `miksuu/master` touches 22 files and is mirrored source/Vanilla work:

- `Common/Functions/Common_CreateTeam.sqf`
- `Common/Functions/Common_CreateTownUnits.sqf`
- `Common/Functions/Common_CreateUnit.sqf`
- `Common/Functions/Common_CreateUnitForStaticDefence.sqf`
- `Common/Functions/Common_CreateVehicle.sqf`
- `Common/Init/Init_Parameters.sqf`
- `Rsc/Parameters.hpp`
- `Server/FSM/server_town.sqf`
- `Server/FSM/server_town_ai.sqf`
- `Server/FSM/server_town_patrol.sqf`
- `Server/Functions/Server_OperateTownDefensesUnits.sqf`

Each file is changed in both `Missions/[55-2hc]warfarev2_073v48co.chernarus` and `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan`.

## Latest Town-Defense Diagnostics Batch

The upstream commit message says the batch:

- adds `WFBE_C_TOWN_DEFENSE_DIAGNOSTICS`, enabled by default;
- initializes `TownDefenseDiagnosticsEnabled` from mission parameters;
- logs capture-side transitions and town-AI activation state under `TOWN_DEFENSE_DIAG`;
- logs group/null state, units, crews, vehicles and locality during town unit creation;
- keeps diagnostic `Format` payloads gated behind the dedicated parameter rather than broad `WF_Debug`.

Source implications:

| Area | Upstream behavior | Development lesson |
| --- | --- | --- |
| Dedicated diagnostic flag | `Rsc/Parameters.hpp` adds `WFBE_C_TOWN_DEFENSE_DIAGNOSTICS`; `Init_Parameters.sqf` sets `TownDefenseDiagnosticsEnabled`. | Prefer focused, parameter-gated diagnostics for hot loops instead of enabling broad debug formatting. |
| Group-limit safety | `server_town_ai.sqf` creates groups first, skips templates when `createGroup` returns `grpNull`, then only delegates valid group/template pairs. | Treat Arma engine object creation as fallible under runtime limits; do not assume `createGroup` succeeds. |
| Vehicle crew safety | `Common_CreateTeam.sqf` tracks actually created crew and deletes a town combat vehicle immediately if no crew could be created. | Empty town vehicles from failed crew creation are worse than no spawn; fail the template clearly. |
| Null unit guards | `Common_CreateUnitForStaticDefence.sqf` and `Server_OperateTownDefensesUnits.sqf` check `objNull` before assigning/moving gunners. | Static-defense code should not run commands on `objNull` under group/unit pressure. |
| Delegation diagnostics | `server_town_ai.sqf` logs activation start, valid group count, client delegation, HC delegation and server-create results. | The right RPT evidence for town-AI bugs is activation/delegation state, not just final vehicle counts. |
| Propagation pattern | Chernarus commit is followed by `update taki`. | Source changes should still start in Chernarus and then propagate/verify maintained Vanilla. |

Adoption note for `rayswaynl/a2waspwarfare`: this is a good candidate to review, but do not cherry-pick blindly onto the docs/source branch or release branch. Current rays branches already contain additional AI/capture hardening work, so compare conflicts against the active source branch first. Also decide whether diagnostics should be default-on for a live public server or default-off after the investigation window.

## Recent Miksuu Commit Themes

Miksuu's May/June 2026 master history shows an active stabilization direction:

| Theme | Representative commits | Learning for this wiki |
| --- | --- | --- |
| Town defense activation and diagnostics | [`913ecdf6`](https://github.com/Miksuu/a2waspwarfare/commit/913ecdf6b55698ad8ea5de70dc1ecb33193b17ce), [`ea0bff2e`](https://github.com/Miksuu/a2waspwarfare/commit/ea0bff2e) | Town AI bugs are being debugged through activation state, side filtering, group creation and static-defense ownership, not just patrol cleanup. |
| Town vehicle crew creation | [`782c9b8a`](https://github.com/Miksuu/a2waspwarfare/commit/782c9b8a) | Crew creation and mount ordering are recurring risk areas for town vehicles. |
| Dead AI command bar cleanup | [`399a5d95`](https://github.com/Miksuu/a2waspwarfare/commit/399a5d95), [`97a7fc15`](https://github.com/Miksuu/a2waspwarfare/commit/97a7fc15) | Player-AI lifecycle and UI command state should be treated as runtime systems, not cosmetic UI only. |
| High-climbing / low-gear AI | [`c39e789d`](https://github.com/Miksuu/a2waspwarfare/commit/c39e789d), [`37395b26`](https://github.com/Miksuu/a2waspwarfare/commit/37395b26) | Vehicle behavior fixes may span player preference, AI manager loops and team menu/UI state. |
| Upgrade/UI feedback | [`545e67a0`](https://github.com/Miksuu/a2waspwarfare/commit/545e67a0), [`4c5dc697`](https://github.com/Miksuu/a2waspwarfare/commit/4c5dc697) | Upgrade countdowns and artillery ammo selection are active UX improvements around real server-side state. |
| Support feedback | [`670ef47d`](https://github.com/Miksuu/a2waspwarfare/commit/670ef47d), [`009cf1dd`](https://github.com/Miksuu/a2waspwarfare/commit/009cf1dd) | Small player-facing messages often reveal missing runtime evidence paths. |

## PR Context

Miksuu's recent PR history is sparse in discussion but useful for original intent:

| PR | State | Context |
| --- | --- | --- |
| [#12 Fix "supply truck too far" notification being run during JIP](https://github.com/Miksuu/a2waspwarfare/pull/12) | Merged 2025-06-12 | Body says the change keeps backwards compatibility while suppressing the extra too-far notification on spawn/JIP. No comments. |
| [#11 Add "supply truck too far" notification](https://github.com/Miksuu/a2waspwarfare/pull/11) | Merged 2025-06-12 | Body says players get a group-chat message when trying to load supplies from a truck more than 50 meters away. No comments. |
| [#10 Supply run remote activation glitch fix](https://github.com/Miksuu/a2waspwarfare/pull/10) | Merged 2025-06-09 | Body documents the exploit: keeping a supply truck near a remote command center and remotely activating a supply mission for instant base collection. No comments. |
| [#6 Buy Units menu improvements](https://github.com/Miksuu/a2waspwarfare/pull/6) | Merged 2023-10-24 | Adds hints for special vehicles and disables the AI driver slot by default. |
| [#5 Add supply runs](https://github.com/Miksuu/a2waspwarfare/pull/5) | Merged 2023-10-24 | Original supply-run PR; adds support-class supply mission files and mission.sqm class descriptions. |
| [#3 Add increasing cost of repairing HQ](https://github.com/Miksuu/a2waspwarfare/pull/3) | Merged 2023-10-24 | Earlier context for HQ repair economy/comeback tuning. |
| [#1](https://github.com/Miksuu/a2waspwarfare/pull/1) / [#2](https://github.com/Miksuu/a2waspwarfare/pull/2) separated-codebase merge attempts | Closed/unmerged | Large historical merge attempts; PR #1 body calls it a test pull request for merging separated codebases. Useful for archaeology, not a clean patch source. |

## Apply Learning Here

| Destination | Update to keep in mind |
| --- | --- |
| [Towns/camps/capture atlas](Towns-Camps-And-Capture-Atlas) | Town AI activation docs should mention the upstream `TOWN_DEFENSE_DIAG` pattern and the group/null guards as a source-available hardening direction. |
| [Town AI vehicle safety](Town-AI-Vehicle-Despawn-Safety) | This is adjacent, not a replacement. Miksuu's latest patch guards failed creation and empty spawned vehicles; DR-45 still concerns deleting an already tracked vehicle with a player aboard. |
| [Feature status register](Feature-Status-Register) | Track the latest Miksuu town-defense diagnostics as a source-available upstream candidate, with adoption pending conflict review and smoke. |
| [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook) | PRs #10-#12 reinforce that supply starts need proximity, JIP and remote-activation abuse tests before heli or truck expansion. |
| [Testing workflow](Testing-Debugging-And-Release-Workflow) | Add RPT checks for `TOWN_DEFENSE_DIAG` only when the focused parameter is enabled; avoid broad debug on hot loops unless deliberately profiling. |

## Suggested Adoption Checklist

1. Diff `miksuu/master` against the current target branch, not only `rayswaynl/master`.
2. Decide whether `WFBE_C_TOWN_DEFENSE_DIAGNOSTICS` should default to enabled on public servers.
3. Review conflicts with current town AI/capture fixes and [Town AI vehicle safety](Town-AI-Vehicle-Despawn-Safety).
4. If adopted, apply Chernarus source first, then propagate maintained Vanilla Takistan.
5. Smoke a town with infantry, crewed vehicles, static defenses, client delegation, HC delegation if available, group-limit pressure if reproducible and town inactivity cleanup.
6. Inspect RPT for `TOWN_DEFENSE_DIAG` lines and warning lines around skipped group/unit/vehicle creation.

## Related Pages

- [Towns/camps/capture atlas](Towns-Camps-And-Capture-Atlas)
- [Town AI vehicle safety](Town-AI-Vehicle-Despawn-Safety)
- [AI, headless and performance](AI-Headless-And-Performance)
- [Headless delegation and failover](Headless-Delegation-And-Failover-Playbook)
- [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook)
- [Feature status register](Feature-Status-Register)

## Continue Reading

Previous: [Source inventory](Source-Inventory) | Next: [Towns/camps/capture atlas](Towns-Camps-And-Capture-Atlas)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
