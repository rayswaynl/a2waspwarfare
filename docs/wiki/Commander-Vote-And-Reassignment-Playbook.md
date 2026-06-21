# Commander Vote And Reassignment Playbook

Source-backed implementation playbook for commander election, no-commander vote semantics, manual reassignment and the nearby commander-authority boundary.

Status: docs only; vote outcome semantics are unpatched in every checked maintained root, while the DR-15 reassignment helper is branch-split.

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

Checked 2026-06-14 on current docs head `8c3942d2`; targeted vote/reassignment source files are unchanged from line-anchor checkpoint `e2c9f6ed`. Stable `origin/master` remains `cf2a6d6a`, Miksuu `b8389e74`, `origin/perf/quick-wins` `0076040f`, release `a96fdda2` and `origin/feat/ai-commander` `c20ce153`.

| Surface | Current branch truth | Route |
| --- | --- | --- |
| Commander vote AI/no-commander outcome | Every checked Chernarus and maintained Vanilla root still counts `wfbe_vote == -1` into `_aiVotes` and then uses the tautological `_highest >= _aiVotes` OR `_highest <= _aiVotes` player-candidate condition (`Server_VoteForCommander.sqf:18,27,43`). The client preview still treats row 0 or no strict majority as AI/no commander (`GUI_VoteMenu.sqf:88`). | This page owns the policy decision and smoke matrix. |
| Manual reassignment helper shape | Current docs head `8c3942d2` is source-unchanged from `e2c9f6ed` and still has `_side = _this` in `Server_AssignNewCommander.sqf:3` in both maintained roots, while `RequestNewCommander.sqf:13-14` spawns the helper and also sends `new-commander-assigned`. Stable, Miksuu, perf, release and `feat/ai-commander` fix helper unpacking at `Server_AssignNewCommander.sqf:4-5` in both roots, but keep duplicate senders at helper `:10` plus caller `RequestNewCommander.sqf:14`. | [Commander reassignment call shape](Commander-Reassignment-Call-Shape#current-branch-matrix) |
| Reassignment UI identity | Every checked root still stores team indexes with `lnbSetValue` (`GUI_Commander_VoteMenu.sqf:13,63`) but resolves the selected commander by visible leader-name text at `:33,37`. | Keep this smoke tied to DR-15; broader UI loop cleanup routes to [Client UI systems](Client-UI-Systems-Atlas#vote-help-and-main-menu-branch-matrix). |
| Requester authority | `RequestCommanderVote` and `RequestNewCommander` remain payload-side/requester-light flows; this pass did not patch sender authentication or authority validation. | [Server authority map](Server-Authority-Migration-Map#registered-server-pvf-handler-authority-matrix) |
| Objective Ping / old town tasks | Current docs head, Miksuu and perf still keep the commander-menu `SetTask` sends commented (`GUI_Menu_Command.sqf:335,337,343`) while registering `SetTask`; stable and release send targeted Objective Ping tasks at `GUI_Menu_Command.sqf:336,344` in both maintained roots. The old town `TaskSystem` remains commented in all checked roots. | [Client UI systems](Client-UI-Systems-Atlas#known-ui-risks-and-partial-work) |

## What It Covers

| Area | Finding | Current status |
| --- | --- | --- |
| Commander vote resolution | DR-47: server counts AI/no-commander votes but then selects any non-tied player candidate. | Confirmed; owner decision needed before code. |
| Vote UI preview | Client preview can show AI/no commander for a distribution the server resolves to a player. | Confirmed mismatch. |
| Manual reassignment helper | DR-15: current docs head helper receives `[_side, _assigned_commander]` but treats the whole payload as `_side`; stable/Miksuu/perf/release/AI-commander fix only that unpacking. | Branch-split; dedicated page owns exact patch shape. |
| Reassignment UI identity | UI stores team ids in rows but resolves selected commander by visible leader name text. | Confirmed UI correctness debt in every checked root. |
| Requester authority | Vote/reassign PVFs use payload side/name/candidate. | Separate hardening pass; do not mix with vote semantics. |

Not covered here: AI commander autonomy, HQ killed scoring, MHQ repair authority and construction authority. Route those through the owning pages linked above.

## Source Chain

All source refs below are from the Chernarus source mission unless the path starts with `Missions_Vanilla`.

| Flow | Evidence | What it means |
| --- | --- | --- |
| Vote worker starts | `Server/Functions/Server_VoteForCommander.sqf:9-14` sets `_side`, reads the side logic vote timer and broadcasts `wfbe_votetime`. | Server owns the countdown and final commander assignment. |
| Vote counting | `Server/Functions/Server_VoteForCommander.sqf:17-29` counts `wfbe_vote == -1` as `_aiVotes`; all other values increment a player-team vote bucket. | Row value `-1` represents AI/no commander in the worker. |
| Winner selection | `Server/Functions/Server_VoteForCommander.sqf:31-43` finds `_highest`, `_highestTeam` and `_tie`, then checks `!_tie && _highest >= _aiVotes && _highestTeam != -1`. | Player candidate wins only when not tied, top vote count meets or exceeds AI/abstain votes, and a valid team index exists. The prior tautological `>= || <=` OR form is resolved in master (recorded in source comment on line 43); DR-47 vote-semantics assessment should be re-evaluated against the current master condition. |
| Final assignment | `Server/Functions/Server_VoteForCommander.sqf:45-57` writes `wfbe_commander`, broadcasts `commander-vote`, and stops AI commander state if a player commander wins. | Vote semantics affect commander, UI and AI handoff state. |
| Vote menu rows | `Client/GUI/GUI_VoteMenu.sqf:7-14` adds a No Commander row with value `-1` and player rows with team indexes. | Client row ids match the server's `wfbe_vote` value model. |
| Vote preview | `Client/GUI/GUI_VoteMenu.sqf:42-49,87-89` offsets `wfbe_vote + 1`, then previews AI/no commander when row 0 wins or no option has more than half the player count. | UI preview and server resolver can disagree. |
| Commander assign UI | `Client/GUI/GUI_Commander_VoteMenu.sqf:8-14,33-46` stores row team indexes but resolves the target by visible leader-name text before sending `RequestNewCommander`. | Duplicate or changed names can point the reassignment at the wrong team. |
| Vote restart PVF | `Server/PVFunctions/RequestCommanderVote.sqf:3-22` trusts payload side/name, resets votes, seeds the current commander vote and spawns `VoteForCommander`. | Useful recovery path, but requester identity hardening is separate from vote resolution. |
| Manual reassign PVF | `Server/PVFunctions/RequestNewCommander.sqf:3-14` reads side/candidate, writes `wfbe_commander`, spawns `[_side, _assigned_commander]` into the helper and sends `new-commander-assigned`. | The caller already mutates commander state before the helper runs. |
| Assign helper | Current docs head `Server/Functions/Server_AssignNewCommander.sqf:4-5` uses `_this select 0` / `_this select 1`; the DR-15 unpacking fix is already present on master. The helper still sends `new-commander-assigned` at `:10` while `RequestNewCommander.sqf:14` also sends it. | DR-15 unpacking is already patched on master. Duplicate notification ownership remains unresolved across all checked roots and must still be decided. |
| Vanilla parity | Maintained Vanilla matches the named Chernarus branch shapes: vote semantics are unpatched everywhere checked; the reassignment helper bug is present only on current docs head among this pass's checked refs; UI name-text selection and duplicate notification sender shape remain everywhere. | Use [Commander reassignment call shape](Commander-Reassignment-Call-Shape) for branch status before claiming this lane fixed. |

## Current Vote Behavior

The server tracks no-commander votes, but the final comparison does not actually let `_aiVotes` beat a non-tied player candidate. The expression `_highest >= _aiVotes || _highest <= _aiVotes` is true for any pair of numeric counts, so the real server rule is closer to "any non-tied player candidate wins if at least one player candidate exists".

The client vote menu suggests a different rule. It previews AI/no commander when the leading row is the No Commander row or when no row has more than half of the counted player slots. That creates a player-facing mismatch: the UI can imply no commander while the server assigns a human commander.

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
3. The helper reads `_side = _this`, so side-logic routing receives an array instead of a side.
4. Both caller and helper contain `new-commander-assigned` sends, but the helper send is partly blocked today by the bad side argument.

Patch or port the DR-15 helper call shape with [Commander reassignment call shape](Commander-Reassignment-Call-Shape). Stable, Miksuu, perf, release and `feat/ai-commander` already fix helper unpacking in both maintained roots, but still need one notification owner or clients can receive duplicate commander messages.

Patch the UI identity edge in the same implementation branch if possible. `GUI_Commander_VoteMenu.sqf` should use the row value/team index already stored in the listbox instead of comparing visible leader names.

## Patch Order

| Step | Action | Validation gate |
| --- | --- | --- |
| 1 | Decide vote semantics and write the expected outcome matrix before editing SQF. | Owner decision recorded in [Pending owner decisions](Pending-Owner-Decisions). |
| 2 | Patch `Server_VoteForCommander.sqf` so no-commander/tie/player-candidate outcomes match the chosen rule. | Dedicated or hosted smoke for player-majority, no-commander-majority, equal-vote and player-candidate tie cases. |
| 3 | Align `GUI_VoteMenu.sqf` preview text and leading-row logic with the server rule. | Client preview matches server broadcast after countdown. |
| 4 | Fix `Server_AssignNewCommander.sqf` payload unpacking per DR-15. | Manual reassignment affects the intended side. |
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
