# Commander Vote And Reassignment Playbook

Source-backed implementation playbook for commander election, no-commander vote semantics, manual reassignment and the nearby commander-authority boundary.

Status: docs only; current stable `origin/master@0139a346` and current B69 `origin/claude/b69@8d465fce` have the server-side DR-47 tautology removed in both maintained roots, but vote UI preview/policy smoke remains open and older checked refs still carry the old comparison.

Scope: Arma 2 Operation Arrowhead 1.64 mission behavior. Gameplay patches should start in `Missions/[55-2hc]warfarev2_073v48co.chernarus`, then propagate maintained Vanilla through LoadoutManager.

Use this page with [Commander/HQ lifecycle](Commander-HQ-Lifecycle-Atlas), [Commander reassignment call shape](Commander-Reassignment-Call-Shape), [Server authority map](Server-Authority-Migration-Map), [Hardening roadmap](Hardening-Implementation-Roadmap), [Feature status](Feature-Status-Register), [Client UI systems](Client-UI-Systems-Atlas) and [Testing workflow](Testing-Debugging-And-Release-Workflow).

## How To Use This Page

| Need | Go here |
| --- | --- |
| Decide commander vote / no-commander policy | Use [Current Branch Scope](#current-branch-scope), then [Current Vote Behavior](#current-vote-behavior) and [Patch Order](#patch-order). |
| Patch manual reassignment helper shape | Use [Commander reassignment call shape](Commander-Reassignment-Call-Shape#current-branch-matrix); this page keeps only the adjacent smoke and ordering context. |
| Separate requester/server authority from vote semantics | Use [Server authority map](Server-Authority-Migration-Map#registered-server-pvf-handler-authority-matrix) for `RequestCommanderVote` / `RequestNewCommander` validation. |
| Debug HQ/MHQ lifecycle after commander changes | Use [Commander/HQ lifecycle](Commander-HQ-Lifecycle-Atlas). |
| Clean vote UI refresh loops, row colors or menu cadence | Use [Client UI systems](Client-UI-Systems-Atlas#vote-help-and-main-menu-branch-matrix). |
| Review AI commander stop/start implications | Use [AI commander autonomy audit](AI-Commander-Autonomy-Audit). |

## Current Branch Scope

Checked 2026-06-22 after `git fetch --all --prune`. Current stable `origin/master@0139a346` and current B69 `origin/claude/b69@8d465fce` differ from the older `8c3942d2` / `cf2a6d6a` branch evidence: the vote worker no longer uses the old `>= || <=` tautology, and the manual reassignment helper unpacking is present in both maintained roots. B69 has no `origin/master..origin/claude/b69` diff for the checked vote worker/preview paths and no `0a1ccb4d..8d465fce` or `b8530477..8d465fce` diff for checked reassignment paths. Miksuu `b8389e748243`, `origin/perf/quick-wins@0076040f`, historical release commit `a96fdda2` and historical AI-commander commit `c20ce153` still keep the old vote comparison; current origin exposes no `release/*`, `feat/*commander*`, `feat/*vote*` or `feat/*reassign*` heads on 2026-06-22.

| Surface | Current branch truth | Route |
| --- | --- | --- |
| Commander vote AI/no-commander outcome | Current stable `origin/master@0139a346` and current B69 `origin/claude/b69@8d465fce` Chernarus and maintained Vanilla still count `wfbe_vote == -1` into `_aiVotes` (`Server_VoteForCommander.sqf:18,26-27`) but now select a player commander only when `!_tie`, `_highestTeam != -1` and `_highest >= _aiVotes` (`:43`). Chernarus blame points to `cbc2294c4`; maintained Vanilla propagation points to `91dc6a75`. The client preview still treats row 0 or no strict majority as AI/no commander (`GUI_VoteMenu.sqf:88`), so UI/policy smoke remains open. Miksuu `b8389e748243`, perf `0076040f`, historical `a96fdda2` and historical `c20ce153` still use the old `>= || <=` comparison at `Server_VoteForCommander.sqf:43`. | Current stable/B69 server comparison is source-present/smoke-pending; this page owns the remaining UI/policy smoke matrix and old-branch route. |
| Manual reassignment helper shape | Current stable `origin/master@0139a346` and current B69 `origin/claude/b69@8d465fce` Chernarus and maintained Vanilla unpack `_side = _this select 0` / `_commander = _this select 1` at `Server_AssignNewCommander.sqf:4-5`, while `RequestNewCommander.sqf:13-14` still spawns the helper and also sends `new-commander-assigned`. Duplicate senders remain at helper `:10` plus caller `RequestNewCommander.sqf:14`; the UI identity edge remains open. Docs/source `HEAD@337ed166` still carries `_side = _this` in both maintained roots. | [Commander reassignment call shape](Commander-Reassignment-Call-Shape#current-branch-matrix) |
| Reassignment UI identity | Every checked root still stores team indexes with `lnbSetValue` (`GUI_Commander_VoteMenu.sqf:13,63`) but resolves the selected commander by visible leader-name text at `:33,37`. | Keep this smoke tied to DR-15; broader UI loop cleanup routes to [Client UI systems](Client-UI-Systems-Atlas#vote-help-and-main-menu-branch-matrix). |
| Requester authority | `RequestCommanderVote` and `RequestNewCommander` remain payload-side/requester-light flows; this pass did not patch sender authentication or authority validation. | [Server authority map](Server-Authority-Migration-Map#registered-server-pvf-handler-authority-matrix) |
| Objective Ping / old town tasks | Current docs head, Miksuu and perf still keep the commander-menu `SetTask` sends commented (`GUI_Menu_Command.sqf:335,337,343`) while registering `SetTask`; stable and release send targeted Objective Ping tasks at `GUI_Menu_Command.sqf:336,344` in both maintained roots. The old town `TaskSystem` remains commented in all checked roots. | [Client UI systems](Client-UI-Systems-Atlas#known-ui-risks-and-partial-work) |

## What It Covers

| Area | Finding | Current status |
| --- | --- | --- |
| Commander vote resolution | DR-47 server tautology is fixed on current stable `origin/master@0139a346` and current B69 `origin/claude/b69@8d465fce`: player candidate assignment now requires `_highest >= _aiVotes`. Older checked refs still use `>= || <=`. | Source-present on current stable/B69; Arma vote-smoke and UI/policy alignment still pending. |
| Vote UI preview | Client preview can still show AI/no commander for a distribution the current stable/B69 server resolves to a player, because `GUI_VoteMenu.sqf:88` uses row 0 / strict-majority preview logic rather than the server `_highest >= _aiVotes` rule. | Confirmed remaining mismatch risk. |
| Manual reassignment helper | DR-15 helper unpacking is source-present on current stable `origin/master@0139a346` and current B69 `origin/claude/b69@8d465fce`, but duplicate `new-commander-assigned` senders and UI visible-name targeting remain open. | Partial source-present; dedicated page owns exact patch/smoke shape. |
| Reassignment UI identity | UI stores team ids in rows but resolves selected commander by visible leader name text. | Confirmed UI correctness debt in every checked root. |
| Requester authority | Vote/reassign PVFs use payload side/name/candidate. | Separate hardening pass; do not mix with vote semantics. |

Not covered here: AI commander autonomy, HQ killed scoring, MHQ repair authority and construction authority. Route those through the owning pages linked above.

## Source Chain

All source refs below are from the Chernarus source mission unless the path starts with `Missions_Vanilla`.

| Flow | Evidence | What it means |
| --- | --- | --- |
| Vote worker starts | `Server/Functions/Server_VoteForCommander.sqf:9-14` sets `_side`, reads the side logic vote timer and broadcasts `wfbe_votetime`. | Server owns the countdown and final commander assignment. |
| Vote counting | `Server/Functions/Server_VoteForCommander.sqf:17-29` counts `wfbe_vote == -1` as `_aiVotes`; all other values increment a player-team vote bucket. | Row value `-1` represents AI/no commander in the worker. |
| Winner selection | Current stable/current B69 `Server/Functions/Server_VoteForCommander.sqf:31-43` finds `_highest`, `_highestTeam` and `_tie`, then assigns a player commander only when `_highest >= _aiVotes` and the top player candidate is not tied. Older Miksuu/perf/historical release/AI refs still use `_highest >= _aiVotes` OR `_highest <= _aiVotes` at `:43`. | Current stable/B69 removed the tautology; old-branch code can still select any non-tied player candidate regardless of no-commander votes. |
| Final assignment | Current stable/current B69 `Server/Functions/Server_VoteForCommander.sqf:49,54,57,61` applies the AI-commander lock override, writes `wfbe_commander`, broadcasts `commander-vote`, and stops AI commander state if a player commander wins. | Vote semantics affect commander, UI and AI handoff state. |
| Vote menu rows | `Client/GUI/GUI_VoteMenu.sqf:7-14` adds a No Commander row with value `-1` and player rows with team indexes. | Client row ids match the server's `wfbe_vote` value model. |
| Vote preview | `Client/GUI/GUI_VoteMenu.sqf:42-49,87-89` offsets `wfbe_vote + 1`, then previews AI/no commander when row 0 wins or no option has more than half the player count. | UI preview and server resolver can disagree. |
| Commander assign UI | `Client/GUI/GUI_Commander_VoteMenu.sqf:8-14,33-46` stores row team indexes but resolves the target by visible leader-name text before sending `RequestNewCommander`. | Duplicate or changed names can point the reassignment at the wrong team. |
| Vote restart PVF | `Server/PVFunctions/RequestCommanderVote.sqf:3-22` trusts payload side/name, resets votes, seeds the current commander vote and spawns `VoteForCommander`. | Useful recovery path, but requester identity hardening is separate from vote resolution. |
| Manual reassign PVF | `Server/PVFunctions/RequestNewCommander.sqf:3-14` reads side/candidate, writes `wfbe_commander`, spawns `[_side, _assigned_commander]` into the helper and sends `new-commander-assigned`. | The caller already mutates commander state before the helper runs. |
| Assign helper | Current stable/current B69 `Server/Functions/Server_AssignNewCommander.sqf:4-5,10` unpacks `_side` / `_commander` correctly, then sends another `new-commander-assigned`. `RequestNewCommander.sqf:13-14` still spawns the helper and sends the caller notification too. | DR-15 helper shape is source-present on current stable/B69, but duplicate notification ownership must still be decided. |
| Vanilla parity | Maintained Vanilla matches the named Chernarus current-stable/B69 shapes: server vote comparison and helper unpacking are source-present; UI preview logic, visible-name reassignment targeting, duplicate notification senders and old-branch vote comparison remain as documented above. | Use [Commander reassignment call shape](Commander-Reassignment-Call-Shape) for branch status before claiming the broader commander lane fixed. |

## Current Vote Behavior

On current stable `origin/master@0139a346` and current B69 `origin/claude/b69@8d465fce`, the server tracks no-commander votes and now lets `_aiVotes` block a player candidate when the AI/no-commander count is greater than the highest player-candidate count. A player candidate can still win on equality because the current comparison is `_highest >= _aiVotes`.

The client vote menu can still suggest a different rule. It previews AI/no commander when the leading row is the No Commander row or when no row has more than half of the counted player slots. That creates a remaining player-facing mismatch: the UI can imply no commander while the current stable/B69 server assigns a human commander under the `_highest >= _aiVotes` rule.

Older checked refs still carry the worse server comparison. On Miksuu `b8389e74`, `origin/perf/quick-wins` `0076040f`, historical release commit `a96fdda2` and historical AI-commander commit `c20ce153`, `_highest >= _aiVotes || _highest <= _aiVotes` is true for any pair of numeric counts, so any non-tied player candidate can win if at least one player candidate exists.

Before patching, choose the rule explicitly:

| Candidate rule | Consequence |
| --- | --- |
| Plurality winner | Highest vote count wins, including no-commander as a real candidate; ties produce no commander or previous commander by policy. |
| Strict majority | A player commander wins only with more than half of eligible/team voters; otherwise no commander or revote. |
| AI/no commander as veto | No-commander wins whenever `_aiVotes >= _highest`, otherwise highest non-tied player wins. |
| Preserve player preference | Player candidate wins any non-tied player plurality; update UI text to match the legacy behavior. |

Do not let the patch pick a policy accidentally by changing only the tautological comparison.

## Manual Reassignment Boundary

Manual reassignment is a separate flow from the vote result, but the fixes are adjacent:

1. `RequestNewCommander.sqf` already writes `wfbe_commander`.
2. It then spawns `Server_AssignNewCommander.sqf` with `[_side, _assigned_commander]`.
3. Old-shape targets read `_side = _this`, so side-logic routing receives an array instead of a side.
4. Current stable/current B69 maintained roots unpack the helper side correctly, so both caller and helper can send `new-commander-assigned`.

Patch or port the DR-15 helper call shape with [Commander reassignment call shape](Commander-Reassignment-Call-Shape) on old-shape targets. Current stable, current B69, Miksuu, perf, historical release and historical AI-commander already fix helper unpacking in both maintained roots, but still need one notification owner or clients can receive duplicate commander messages.

Patch the UI identity edge in the same implementation branch if possible. `GUI_Commander_VoteMenu.sqf` should use the row value/team index already stored in the listbox instead of comparing visible leader names.

## Patch Order

| Step | Action | Validation gate |
| --- | --- | --- |
| 1 | Decide vote semantics and write the expected outcome matrix before editing SQF. | Owner decision recorded in [Pending owner decisions](Pending-Owner-Decisions). |
| 2 | Patch `Server_VoteForCommander.sqf` so no-commander/tie/player-candidate outcomes match the chosen rule. | Dedicated or hosted smoke for player-majority, no-commander-majority, equal-vote and player-candidate tie cases. |
| 3 | Align `GUI_VoteMenu.sqf` preview text and leading-row logic with the server rule. | Client preview matches server broadcast after countdown. |
| 4 | Preserve or port `Server_AssignNewCommander.sqf` payload unpacking per DR-15; current stable/current B69 maintained roots already use `_this select 0`, while docs/source and modded full forks still need old-shape handling. | Manual reassignment affects the intended side on every claimed target root. |
| 5 | Choose one `new-commander-assigned` sender after the helper works. | Clients receive exactly one reassignment message. |
| 6 | Use row value/team identity in `GUI_Commander_VoteMenu.sqf`. | Duplicate/similar leader names cannot redirect reassignment. |
| 7 | Propagate maintained Vanilla and inspect generated diffs. | Chernarus and maintained Vanilla share the same behavior. |
| 8 | Treat `RequestCommanderVote` and `RequestNewCommander` requester validation as a separate server-authority branch if not handled in the same owner-approved scope. | Wrong-side/non-authorized request smoke is recorded separately. |

## Smoke Matrix

| Scenario | Expected evidence |
| --- | --- |
| One player candidate has chosen-rule majority | Server sets `wfbe_commander` to that team, clients receive the matching `commander-vote` message, UI preview agrees. |
| No Commander row wins under chosen rule | Server leaves commander null or AI/no-commander state as documented, UI preview agrees. |
| No Commander and player candidate tie | Tie result matches owner policy and does not accidentally assign due to comparison fall-through. |
| Two player candidates tie | Tie result matches owner policy and no stale previous candidate leaks through. |
| Vote restart after `wfbe_votetime <= 0` | `RequestCommanderVote` starts exactly one new vote for the intended side. |
| Manual reassignment to another player team | `wfbe_commander` changes on the intended side and clients get exactly one notification. |
| Duplicate or similar leader names | Commander assign UI targets the stored team row value, not visible text. |
| JIP after vote/reassign | Late client sees current commander state and does not replay stale preview text as truth. |
| Maintained Vanilla parity | Same source defects are patched or explicitly left unpatched in `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan`. |

## Agent Notes

- Treat DR-47 vote semantics, DR-15 reassignment call shape and commander requester-authority hardening as related but separate claims.
- Do not claim "commander voting fixed" if only the helper call shape is patched.
- Do not claim "commander authority fixed" if only the vote comparison is patched.
- Do not use stable/release DR-15 helper unpacking as evidence that vote semantics, duplicate notification ownership or UI identity are fixed.
- Keep all source refs relative to Chernarus first and update the Vanilla parity note after LoadoutManager propagation.
- Use Arma 2 OA-safe SQF only; do not import Arma 3 event/remoteExec assumptions.

## Continue Reading

Previous: [Commander/HQ lifecycle](Commander-HQ-Lifecycle-Atlas) | Next: [Commander reassignment call shape](Commander-Reassignment-Call-Shape)
