# Commander And HQ Lifecycle Atlas

> Canonical source-backed map for commander selection, commander-client affordances, HQ/MHQ deployment, HQ destruction, wreck tracking and MHQ repair. This page bridges [Construction and CoIn systems](Construction-And-CoIn-Systems-Atlas), [AI commander autonomy audit](AI-Commander-Autonomy-Audit), [Commander reassignment call shape](Commander-Reassignment-Call-Shape), [Server authority migration map](Server-Authority-Migration-Map) and [Public variable channel index](Public-Variable-Channel-Index).

Unless a branch/ref is named, source paths below are relative to the Chernarus mission root, `Missions/[55-2hc]warfarev2_073v48co.chernarus/`. The initial HQ/team-spawn section was refreshed against live mission `origin/master` `0139a3468` on 2026-06-21. The HQ score/bounty matrix was refreshed against docs/source `HEAD@c2d513ecb`, current stable/B74.1 `origin/master@f8a76de34`, B69 `origin/claude/b69@8d465fce`, B74 `origin/claude/b74-aicom-spend@b23f557f` and Miksuu score/HQ/bounty branch-name candidates on 2026-06-23; older branch-matrix rows keep their named provenance.

## How To Use This Page

| Need | Start here | Then route to |
| --- | --- | --- |
| Commander vote, no-commander outcome, manual reassignment | [Commander Vote Flow](#commander-vote-flow), [Manual Reassignment Flow](#manual-reassignment-flow) | [Commander vote/reassignment](Commander-Vote-And-Reassignment-Playbook), [Commander reassignment call shape](Commander-Reassignment-Call-Shape) |
| HQ deploy, mobilize and base-area state | [HQ Deploy And Mobilize](#hq-deploy-and-mobilize) | [Construction and CoIn systems](Construction-And-CoIn-Systems-Atlas), [Server authority migration map](Server-Authority-Migration-Map) |
| Initial HQ placement, editor team registration and first client spawn | [Initial HQ And Team Spawn Flow](#initial-hq-and-team-spawn-flow) | [Mission entrypoints and lifecycle](Mission-Entrypoints-And-Lifecycle), [Respawn and death lifecycle](Respawn-And-Death-Lifecycle-Atlas), [Networking and public variables](Networking-And-Public-Variables) |
| HQ kill score, bounty and wreck markers | [HQ Destruction And Wreck Markers](#hq-destruction-and-wreck-markers), [HQ kill score matrix](#hq-kill-score-and-bounty-branch-matrix) | [Feature status](Feature-Status-Register), [Source fix propagation queue](Source-Fix-Propagation-Queue) |
| MHQ repair and WASP cash HQ recovery | [MHQ Repair](#mhq-repair), [WASP Cash HQ Recovery](#wasp-cash-hq-recovery) | [Economy, towns and supply](Economy-Towns-And-Supply), [Server authority migration map](Server-Authority-Migration-Map) |
| Commander task pings and old task-system residue | [Authority And Risk Register](#authority-and-risk-register) | [Client UI systems atlas](Client-UI-Systems-Atlas), [Networking and public variables](Networking-And-Public-Variables) |
| AI commander assumptions | [Commander Vote Flow](#commander-vote-flow) | [AI commander autonomy audit](AI-Commander-Autonomy-Audit) |

## Current Branch Scope

Checked 2026-06-14 against current docs head `8c3942d2` (targeted commander/HQ source paths unchanged from `f82a9127` and `e2c9f6ed`), stable `origin/master` `cf2a6d6a`, Miksuu `b8389e74`, `origin/perf/quick-wins` `0076040f`, release `a96fdda2` and `origin/feat/ai-commander` `c20ce153`.

HQ score/bounty was rechecked 2026-06-23 against docs/source `HEAD@c2d513ecb` (source-unchanged from `9b7eb4bc` for checked HQ-score files), current stable/B74.1 `origin/master@f8a76de34`, B69 `origin/claude/b69@8d465fce`, B74 `origin/claude/b74-aicom-spend@b23f557f`, current Miksuu `b8389e748243`, `origin/perf/quick-wins@0076040f` and historical `a96fdda2` in both maintained roots. A same-day Miksuu branch-name scan classified score/HQ/bounty-looking branches as historical or branch-only evidence unless the table below says otherwise. Other rows keep their 2026-06-14 branch provenance until refreshed.

| Surface | Current branch truth | Route |
| --- | --- | --- |
| Commander vote semantics | Branch-split after the 2026-06-22 B74 refresh: current stable `origin/master@0139a346`, current B69 `origin/claude/b69@8d465fce` and adjacent B74 `origin/claude/b74-aicom-spend@b23f557f` use `_highest >= _aiVotes` at `Server_VoteForCommander.sqf:43` in both maintained roots, but `GUI_VoteMenu.sqf:88` still previews row-0/strict-majority AI/no commander. Docs/source `HEAD@e0d82714`, Miksuu `b8389e748243`, perf `0076040f`, historical `a96fdda2` and historical `c20ce153` still keep the old `>= || <=` winner condition. | [Commander vote/reassignment](Commander-Vote-And-Reassignment-Playbook#current-branch-scope) |
| Manual reassignment helper | Current docs head `8c3942d2` is source-unchanged from `e2c9f6ed`/`f82a9127` for this flow and still uses `_side = _this` in `Server_AssignNewCommander.sqf:3`; stable/Miksuu/perf/release/feat-ai unpack side + commander at `:4-5` in checked maintained roots, but duplicate `new-commander-assigned` senders remain. | [Commander reassignment call shape](Commander-Reassignment-Call-Shape#current-branch-matrix) |
| HQ score/bounty | Docs/source `HEAD@c2d513ecb`, current stable/B74.1 `origin/master@f8a76de34`, B69 `origin/claude/b69@8d465fce`, B74 `origin/claude/b74-aicom-spend@b23f557f`, current Miksuu `b8389e748243`, `origin/perf/quick-wins@0076040f` and historical `a96fdda2` still keep the generic HQ building score plus second HQ bounty shape in both maintained roots. B69/B74/B74.1 add base-fall smoke/sting code around the handler, but not a scoring fix. | [HQ kill score and bounty branch matrix](#hq-kill-score-and-bounty-branch-matrix) |
| Objective Ping / commander tasks | Docs/source `HEAD@86ab85b9d0b1`, Miksuu `b8389e748243` and perf `0076040f` leave maintained-root `SetTask` sends commented at `GUI_Menu_Command.sqf:335,337,343`; current stable `origin/master@0139a346`, B69 `origin/claude/b69@8d465fce`, B74 `origin/claude/b74-aicom-spend@b23f557f` and `origin/feat/naval-hvt-objectives@2e1c59317186` send targeted Objective Ping tasks at `:336,344`. Historical `a96fdda2` has live sends but no live `release/*` head. Old town `TaskSystem` remains separate/commented residue. | [Client UI systems atlas](Client-UI-Systems-Atlas), [Networking and public variables](Networking-And-Public-Variables) |
| HQ repair and base-area authority | `RequestMHQRepair` still sends only side, and base-area accounting still depends on client-bound `RequestBaseArea`; treat both as authority-sensitive before expanding HQ recovery or deploy limits. | [Server authority migration map](Server-Authority-Migration-Map), [Construction and CoIn systems](Construction-And-CoIn-Systems-Atlas) |

## Why This Matters

The commander/HQ layer is the hinge between RTS control and the rest of the Warfare mission. A wrong change here can strand players without build access, break JIP HQ state, duplicate commander messages, expose enemy-only HQ wreck markers, bypass economy authority, or make an AI commander look alive when only a few helper variables exist.

The useful mental model:

- side logic objects own canonical replicated state such as `wfbe_commander`, `wfbe_hq`, `wfbe_hq_deployed`, `wfbe_hq_repairing`, `wfbe_hq_repair_count`, `wfbe_votetime`, `wfbe_basearea` and radio-HQ variables;
- the server creates, destroys, repairs and swaps HQ/MHQ objects;
- clients watch replicated side-logic state to add/remove commander actions, initialize CoIn and draw local allied HQ wreck markers;
- several surrounding actions still trust client-side checks or direct publicVariable flows and need hardening before public-server confidence.

## Source Map

| Role | Files |
| --- | --- |
| Server side init/state | `Server/Init/Init_Server.sqf:389-450,475-492,844` |
| Initial start picker / HQ placement | `mission.sqm:50,250,267,284,302,320,323,4334-4788,5031-5043`, `Rsc/Parameters.hpp:153-164`, `Common/Init/Init_CommonConstants.sqf:242-250`, `Server/Init/Init_Server.sqf:153,205-218,236-368,389-502` |
| Initial team-slot registration / JIP matching | `mission.sqm:3849,3868,4928`, `Server/Init/Init_Server.sqf:544-645`, `initJIPCompatible.sqf:263-271`, `Server/Functions/Server_OnPlayerConnected.sqf:14,21-39,65-83,95-103` |
| Initial client placement / respawn split | `Client/Init/Init_Client.sqf:12-25,515-560`, `Client/Functions/Client_GetRespawnAvailable.sqf:7-113`, `Client/Functions/Client_OnRespawnHandler.sqf:29-52` |
| Commander vote worker | `Server/Functions/Server_VoteForCommander.sqf:9-57` |
| Vote restart request | `Client/GUI/GUI_Menu.sqf:75,91`, `Server/PVFunctions/RequestCommanderVote.sqf:3-22`, `Common/Init/Init_PublicVariables.sqf:12` |
| Manual reassignment path | `Client/GUI/GUI_Commander_VoteMenu.sqf:46`, `Server/PVFunctions/RequestNewCommander.sqf:3-16`, `Server/Functions/Server_AssignNewCommander.sqf:3-14` |
| Commander disconnect fallback | `Server/Functions/Server_OnPlayerDisconnected.sqf:136-146` |
| Commander getters/votes | `Common/Functions/Common_GetCommanderTeam.sqf:7-12`, `Common/Functions/Common_SetCommanderVotes.sqf:3-10` |
| HQ getters | `Common/Functions/Common_GetSideHQ.sqf:7-12`, `Common/Functions/Common_GetSideHQDeployStatus.sqf:7-12` |
| Client commander/HQ watchers | `Client/Init/Init_Client.sqf:382-388,489-503`, `Client/FSM/updateclient.sqf:184-244` |
| HQ deploy/mobilize worker | `Server/Construction/Construction_HQSite.sqf:13-104` |
| HQ killed worker | `Server/Functions/Server_OnHQKilled.sqf:26-48,51-86,89-119` |
| MHQ repair worker | `Client/Action/Action_RepairMHQ.sqf:5-42`, `Server/Functions/Server_MHQRepair.sqf:7-79` |
| Commander economy controls | `Client/GUI/GUI_Menu_Economy.sqf:24-27,74-79,104-150`, `Server/FSM/updateresources.sqf:36-43` |
| HQ build/base-area authority | `Client/Module/CoIn/coin_interface.sqf:13-26,494,718`, `Server/PVFunctions/RequestStructure.sqf:3-21`, `Client/PVFunctions/RequestBaseArea.sqf:1-4`, `Server/FSM/basearea.sqf:46-78` |
| WASP cash HQ recovery | `WASP/actions/Action_RepairMHQDepot.sqf:7-29` |
| PV/PVF registration | `Common/Init/Init_PublicVariables.sqf:13,17,33,38` |
| HQ wreck marker loop | `Client/FSM/updateclient.sqf:41-100` |
| Special message handlers | `Client/Functions/Client_FNC_Special.sqf:6-34,70-75`, `Client/PVFunctions/HandleSpecial.sqf:34`, `Server/Functions/Server_HandleSpecial.sqf:114-116` |

## Startup State

`Init_Server.sqf` creates each side's starting mobile HQ at the side's selected start logic position, sets `WFBE_Taxi_Prohib`, `wfbe_side`, `wfbe_trashable`, `wfbe_structure_type = "Headquarters"`, killed and hit event handlers, and Chernarus-dependent west textures (`Init_Server.sqf:389-403`).

The same side logic then publishes the baseline state:

| Variable | Initial value | Source |
| --- | --- | --- |
| `wfbe_commander` | `objNull` | `Init_Server.sqf:432` |
| `wfbe_hq` | starting MHQ object | `Init_Server.sqf:433` |
| `wfbe_hq_deployed` | `false` | `Init_Server.sqf:434` |
| `wfbe_hq_repair_count` | `1` | `Init_Server.sqf:435` |
| `wfbe_hq_repairing` | `false` | `Init_Server.sqf:436` |
| `wfbe_startpos` | selected side start logic position | `Init_Server.sqf:437` |
| `wfbe_votetime` | `WFBE_C_GAMEPLAY_VOTE_TIME` | `Init_Server.sqf:449` |
| `wfbe_hqinuse` | `false` | `Init_Server.sqf:450` |
| `wfbe_basearea` | `[]` when base-area mode is enabled | `Init_Server.sqf:460` |
| `wfbe_radio_hq`, `wfbe_radio_hq_id` | side radio logic and identity | `Init_Server.sqf:475-492` |

This is why fresh clients can wait on side logic variables instead of rediscovering HQ state from world objects. `Common_GetSideHQ.sqf` and `Common_GetSideHQDeployStatus.sqf` are thin side-to-logic readers, not search functions (`Common_GetSideHQ.sqf:7-12`, `Common_GetSideHQDeployStatus.sqf:7-12`).

## Initial HQ And Team Spawn Flow

_Source pass: live mission `origin/master` at `0139a3468`, checked 2026-06-21. This section describes committed Chernarus behavior; local test-only overrides in other worktrees are not treated as canonical._

Initial player arrival is a staged server/client handoff, not "spawn wherever the playable unit was placed in the editor." The editor slots and temp respawn markers get the engine safely into multiplayer, but the Warfare layer chooses the real start, creates the side HQ there, registers the synced playable groups as teams, and then moves the joining client out of the holding area.

### Mission Boot Order

`initJIPCompatible.sqf` starts common constants/config and towns first, then starts `Server/Init/Init_Server.sqf` on the server (`initJIPCompatible.sqf:252-258`). Clients do not enter `Init_Client.sqf` immediately: they wait for `WFBE_PRESENTSIDES`, then wait for each present side logic to publish `wfbe_teams` before caching `WFBE_%1TEAMS` and running client init (`initJIPCompatible.sqf:263-271`). That wait matters because client-side group menus, join placement, commander vote UI and later JIP cleanup all assume the side team registry already exists.

### Start Location Selection

The Chernarus `.sqm` contains many `LocationLogicStart` objects, side owner logics, and temp respawn markers. The important authored hints are `wfbe_spawn = "north"`, `"south"` or `"central"` on selected start logics, plus `wfbe_default` tags for fallback (`mission.sqm:323,4595,4684,4738`). The playable west/east/resistance groups are synchronized to `LocationLogicOwnerWest`, `LocationLogicOwnerEast` and `LocationLogicOwnerResistance` (`mission.sqm:3849,3868,4928`), while `WestTempRespawnMarker`, `EastTempRespawnMarker` and `GuerTempRespawnMarker` are just holding/respawn marker infrastructure (`mission.sqm:5031-5043`).

Server start choice happens in `Init_Server.sqf`:

1. It reads all `LocationLogicStart` objects into `startingLocations` (`Init_Server.sqf:153`).
2. If `WFBE_C_BASE_START_TOWN` is enabled, it refines candidates to start logics within 2000m of towns, falling back to all starts if fewer than three survive (`Init_Server.sqf:205-218`). The parameter default is enabled (`Rsc/Parameters.hpp:153-158`; `Init_CommonConstants.sqf:242`).
3. `WFBE_C_BASE_STARTING_MODE` selects west-north/east-south, west-south/east-north, or random; the default is random (`Rsc/Parameters.hpp:159-164`; `Init_CommonConstants.sqf:243`). In three-way mode the fixed north/south shortcut is skipped and random placement is used.
4. Random placement must satisfy the side spacing check and the egress-quality gate: at least 400m from Chernarus map edges, roads within 250m, and on OA at least three usable road segments where `roadsConnectedTo` returns two or more connections (`Init_Server.sqf:236-271`; `Init_CommonConstants.sqf:244-250`).
5. If random placement cannot settle within 2000 attempts, the fallback uses `.sqm` `wfbe_default` west/east tags, or random remaining starts if the defaults are missing (`Init_Server.sqf:337-365`).

### HQ And Starting Vehicles

For the committed Chernarus Combined Ops setup, common constants pick USMC for west and RU for east (`Init_CommonConstants.sqf:610-626`). Those roots compile side structure config, giving west `LAV25_HQ` / `LAV25_HQ_unfolded` and east `BTR90_HQ` / `BTR90_HQ_unfolded` (`Structures_USMC.sqf:6-7,127`; `Structures_RU.sqf:6-7,127`).

During global side initialization, the server passes the selected start logic position into `WFBE_CO_FNC_CreateVehicle`, stores the returned object as `wfbe_hq`, and publishes `wfbe_startpos` on the side logic (`Init_Server.sqf:378-437`). `Common_CreateVehicle.sqf` is the shared wrapper over the engine `createVehicle` command: it normalizes object positions/side IDs, creates the vehicle, applies direction/lock/bounty handlers, and uses `setVehicleInit` plus `processInitCommands` for global unit initialization when requested (`Common_CreateVehicle.sqf:15-24,39-73`).

After the MHQ is created, the server spawns configured starting vehicles near it. Current Chernarus roots give west `HMMWV_Ambulance` and `Pandur2_ACR`, east `GAZ_Vodnik_MedEvac` and `BTR90` (`Root_US_Camo.sqf:44`; `Root_RU.sqf:41`), then `Init_Server.sqf` places and cargo-clears them beside the HQ (`Init_Server.sqf:494-502`). WASP also runs `Wasp/unsort/StartVeh.sqf` and creates one random side-specific extra starting vehicle near the HQ before team registration (`Init_Server.sqf:506-542`).

### Team Registration

The initial west/east "teams" are editor-created groups, not newly spawned groups. For each present side, the server loops `synchronizedObjects _logik`, takes each synced man object's `group`, pushes that group into `_teams`, seeds funds, side, persistence, queue, vote, autonomy, respawn, team type and default move mode, then publishes `wfbe_teams` and `wfbe_teams_count` on the side logic (`Init_Server.sqf:544-580`).

Resistance player slots are gated separately. If `WFBE_C_GUER_PLAYERSIDE > 0`, the server registers synced resistance groups as harass-only GUER teams with 50k funds and starts `Server_GuerStipend.sqf` (`Init_Server.sqf:584-616`; `Rsc/Parameters.hpp:586-592`). With the default gate off, the synced GUER playable units are deleted server-side so clients cannot join a non-functional insurgent side (`Init_Server.sqf:618-627`). After registration, all still-untagged west/east/resistance editor groups are tagged `wfbe_group_src = "editor-player-slot"` for group-GC/audit visibility; this is audit state, not the mechanism that registers teams (`Init_Server.sqf:629-645`).

JIP player matching later depends on this registry. `Server_OnPlayerConnected.sqf` waits for `commonInitComplete && serverInitFull`, searches `playableUnits` for the joining UID, reads that unit's `group`, verifies `wfbe_side`, stores `wfbe_uid` / `wfbe_teamleader`, and seeds or restores `WFBE_JIP_USER<uid>` / `wfbe_funds` (`Server_OnPlayerConnected.sqf:14,21-39,65-83,95-103`). If team registration is broken, JIP symptoms often show up here rather than at the original server init line.

### Client Initial Placement

The player's first engine position is still the side's temp respawn/holding area. `Init_Client.sqf` immediately disables damage while the player is in that transit state, then a watchdog re-enables it once `WFBE_Client_DeadspawnEscaped` is set or after a 120-second timeout (`Init_Client.sqf:12-25`). The server also surrounds the three temp respawn markers with H-barriers after `serverInitFull` so side-slot bodies cannot shoot across the holding markers while clients are still joining (`Init_Server.sqf:649-657`).

Once the join gate has passed, client init performs an interim move to `wfbe_startpos` if available, then determines the final initial placement (`Init_Client.sqf:515-560`):

- resistance clients use a friendly/neutral town if possible, falling back to the GUER temp marker;
- west/east clients during the first 30 seconds use `wfbe_startpos`;
- later west/east joiners prefer the current side HQ, then scan side structures backward and use the newest live Barracks, Light, Heavy or Aircraft factory when one exists;
- if no live factory exists and the HQ object is null/dead, the client falls back to `wfbe_startpos`.

That final `setPos` sets `WFBE_Client_DeadspawnEscaped = true`, which lets the damage watchdog restore normal damage shortly after (`Init_Client.sqf:558-560`).

### Initial Join Is Not Respawn

Do not conflate the above client init placement with the later respawn menu. `Client_GetRespawnAvailable.sqf` builds a respawn list from HQ/factories, mobile respawn vehicles, redeploy trucks, leader respawn, three-way/defender special respawn, camps and GUER friendly/neutral towns (`Client_GetRespawnAvailable.sqf:7-113`). `Client_OnRespawnHandler.sqf` then either moves the player into cargo for eligible mobile/redeploy spawns or positions them near the selected spawn/town (`Client_OnRespawnHandler.sqf:29-52`). A bug in first-join deadspawn handling and a bug in later respawn availability can look similar in play, but they are different code paths.

### Change And Smoke Checklist

- Start-placement changes: smoke `WFBE_C_BASE_START_TOWN` on/off, start mode 0/1/2, north/south tag absence, the 2000-attempt fallback, and the edge/road egress gate.
- HQ type or starting vehicle changes: verify `WFBE_%1MHQNAME`, `WFBE_%1STARTINGVEHICLES`, `Common_CreateVehicle` global init and side-specific `PlaceNear` behavior.
- Slot/team changes: verify editor sync to side owner logics, `wfbe_teams_count`, commander vote rows, `Server_OnPlayerConnected` UID matching and JIP reconnect funds.
- Deadspawn changes: smoke launch join, mid-game JIP after factories exist, JIP after HQ death, and the 120-second damage watchdog timeout.
- Respawn changes: smoke the respawn menu separately from first join, especially mobile/redeploy cargo and GUER town selection.

Relevant BI command references for this flow: [`createVehicle`](https://community.bistudio.com/wiki/createVehicle), [`createUnit`](https://community.bistudio.com/wiki/createUnit), [`setVehicleInit`](https://community.bistudio.com/wiki/setVehicleInit), [`processInitCommands`](https://community.bistudio.com/wiki/processInitCommands), [`nearRoads`](https://community.bistudio.com/wiki/nearRoads), [`roadsConnectedTo`](https://community.bistudio.com/wiki/roadsConnectedTo), [`setPos`](https://community.bistudio.com/wiki/setPos), [`moveInCargo`](https://community.bistudio.com/wiki/moveInCargo). Check each page's game-version icons/caveats before applying newer-engine behavior to Arma 2 OA.

## Commander Vote Flow

At the end of server init, every present side starts `WFBE_SE_FNC_VoteForCommander` (`Init_Server.sqf:844`). The worker:

1. reads the side's vote time (`Server_VoteForCommander.sqf:9-11`);
2. counts down `wfbe_votetime` once per second and broadcasts it on side logic (`:13-14`);
3. counts player-group `wfbe_vote` values from `wfbe_teams` (`:17-29`);
4. resolves ties and AI/no-commander votes (`:31-46`);
5. sets `wfbe_commander` to the selected player group or `objNull` for AI/no commander (`:48-49`);
6. sends `HandleSpecial ["commander-vote", _commander]` to side clients (`:51-52`);
7. stops any running AI commander flag when a player commander is selected (`:54-57`).

`Common_SetCommanderVotes.sqf` is a helper that sets every team vote to a provided value (`Common_SetCommanderVotes.sqf:3-10`). It does not decide the winner.

The vote winner condition is branch-sensitive. Current stable `origin/master@0139a346`, B69 `origin/claude/b69@8d465fce` and B74 `origin/claude/b74-aicom-spend@b23f557f` count `wfbe_vote == -1` as AI/no-commander votes (`Server_VoteForCommander.sqf:18,26-27`) and assign a player only when `_highest >= _aiVotes` at `:43`; the checked B69..B74 vote-worker/preview diff is empty. Docs/source `HEAD@e0d82714`, current Miksuu `b8389e748243`, perf `0076040f`, historical release `a96fdda2` and historical AI-commander `c20ce153` still use the old tautology at `:43`, so any non-tied player candidate with `_highestTeam != -1` can be selected there. The client vote dialog still previews AI/no commander when the highest option is not above half of player voters or when row 0 wins (`GUI_VoteMenu.sqf:87-89`), so even current stable/B69/B74 need UI/policy smoke. Use [Commander vote/reassignment](Commander-Vote-And-Reassignment-Playbook) for the policy decision, patch order and smoke matrix.

There is also a client-triggered vote restart path. If the main menu sees `wfbe_votetime <= 0`, it sends `RequestCommanderVote` with `[sideJoined, name player]` (`GUI_Menu.sqf:75,91`). The server handler rechecks side logic vote time, resets team votes around the current commander team, spawns `VoteForCommander`, sends the side message and broadcasts `commander-vote-start` with the provided name (`RequestCommanderVote.sqf:3-22`). This is useful for recovery, but the handler does not prove requester identity beyond the payload, so keep it in commander-authority smoke when changing vote behavior.

The vote UI refresh loops also have an inclusive-bound edge. `WFBE_Client_Teams_Count` is set to `count WFBE_Client_Teams` (`Init_Client.sqf:273`), but both `GUI_Commander_VoteMenu.sqf:58-66` and `GUI_VoteMenu.sqf:29,61-66` loop `from 0 to WFBE_Client_Teams_Count`, which reaches one index past the array. Existing `isNil` guards reduce the blast radius, but this is still a source-level cleanup candidate for vote-menu polish.

## Manual Reassignment Flow

This atlas only anchors the HQ lifecycle boundary. The patch matrix and generated-mission propagation notes live on [Commander reassignment call shape](Commander-Reassignment-Call-Shape), while vote-policy ordering and smoke live on [Commander vote/reassignment](Commander-Vote-And-Reassignment-Playbook). Current docs head `8c3942d2` has no targeted reassignment-source drift from `e2c9f6ed` or `f82a9127`.

| Step | Local source anchor | Route |
| --- | --- | --- |
| Commander UI sends the request | `GUI_Commander_VoteMenu.sqf:33-46` stores row team ids but resolves the selected commander by visible leader-name text before sending `["RequestNewCommander", [side group player, _voted_commander]]`. | [Commander reassignment call shape](Commander-Reassignment-Call-Shape#evidence) |
| Server PVF mutates commander state | `RequestNewCommander.sqf:3-16` reads side/candidate, accepts only after `wfbe_votetime <= 0`, sets `wfbe_commander`, spawns `AssignNewCommander` and sends `new-commander-assigned`. | [Commander vote/reassignment](Commander-Vote-And-Reassignment-Playbook#manual-reassignment-boundary) |
| Helper remains branch-split | Docs head still uses `_side = _this` while also reading `_this select 1` (`Server_AssignNewCommander.sqf:3-5`); stable/Miksuu/perf/release/feat-ai unpack `_this select 0` / `_this select 1` but leave duplicate notification sender shape. | [Current branch matrix](Commander-Reassignment-Call-Shape#current-branch-matrix) |
| Client displays the outcome | `Client_FNC_Special.sqf:6-34` shows commander vote/reassignment messages and locally mirrors `wfbe_commander = objNull` for null reassignment. | [Client UI systems](Client-UI-Systems-Atlas#vote-help-and-main-menu-branch-matrix) |

Keep vote semantics, helper unpacking, notification ownership, UI row identity and requester authority as separate claims. Stable/release helper unpacking alone is not evidence that manual reassignment, duplicate-message behavior or commander authority is fixed.

## Commander Economy Controls

`GUI_Menu_Economy.sqf` gives commanders income-percent, structure sell and supply-truck respawn controls. The income-percent control updates side/group state from the client (`GUI_Menu_Economy.sqf:24-27,74-79`), and the server resource updater later consumes that value (`Server/FSM/updateresources.sqf:36-43`). Structure sale/refund logic is also commander-facing UI work (`GUI_Menu_Economy.sqf:104-150`) rather than a fully server-derived economy transaction.

These controls are live and useful, but they belong to the same server-authority migration class as upgrades, construction, side supply and MHQ repair. Do not treat them as AI commander autonomy work unless the owner explicitly decides to redesign commander economy behavior at the same time.

## Client Commander Affordances

`Init_Client.sqf` waits for `wfbe_commander` and then starts the main `updateclient.sqf` loop (`Init_Client.sqf:382-388`). That loop polls the side's commander team each tick (`updateclient.sqf:184`), detects changes, and updates the local player's UI/action state.

When the local player becomes commander:

- the current side HQ/MHQ gets lock/unlock actions (`updateclient.sqf:210-213`);
- CoIn is initialized in deployed or undeployed mode depending on `wfbe_hq_deployed` (`:214-219`);
- the commander build action `HQAction` is attached to the player with the `hqInRange && canBuildWHQ` condition (`:220`);
- title/hint/sound feedback is emitted (`:221-225`);
- a heavy attack action is lazily attached to the side HQ if side supply is at least `25000` (`:234-244`).

When commander status is lost, the loop removes MHQ actions 0-3, removes `HQAction`, clears HC groups and disables team autonomy (`updateclient.sqf:196-205,226-229`). This action-removal path is position/index-sensitive; changes to HQ/MHQ actions should be smoked in commander handoff, respawn and JIP flows.

Commander disconnect is handled server-side by clearing, not reassignment. `Server_OnPlayerDisconnected.sqf:136-146` checks whether the disconnecting team is the current commander team, sets side logic `wfbe_commander = objNull`, sends `CommanderDisconnected`, and clears team autonomy/respawn overrides. No `VoteForCommander`, `RequestNewCommander` or `AssignNewCommander` call appears in that disconnect block, so automatic replacement is not proven in current source. Treat auto-reassign/vote restart as a separate owner decision rather than assuming the AI commander or vote system takes over.

## HQ Deploy And Mobilize

HQ deployment/mobilization is a special CoIn structure flow handled by `Construction_HQSite.sqf`.

The worker first serializes HQ swaps with `wfbe_hqinuse` (`Construction_HQSite.sqf:13-15`) and reads the current HQ object and deployed state (`:17-18`).

When deploying an undeployed MHQ:

- the old MHQ is moved away (`:20-21`);
- the deployed HQ structure is created, positioned, assigned `wfbe_side` and `wfbe_structure_type = "Headquarters"` (`:23-27`);
- side logic broadcasts `wfbe_hq_deployed = true` and `wfbe_hq = _site` (`:29-30`);
- client base-structure init is pushed with `setVehicleInit` (`:32-33`);
- side messages and killed/hit/handleDamage handlers are attached (`:35-38`);
- base-area logic may be created and sent to clients through `RequestBaseArea` (`:40-59`);
- the old mobile HQ is deleted (`:64`).

When mobilizing a deployed HQ:

- the deployed HQ position/direction are preserved (`:66-68`);
- a new side-specific MHQ vehicle is created (`:72`);
- taxi/trash/side/type variables and hit/killed handlers are attached (`:73-89`);
- side logic broadcasts `wfbe_hq = _MHQ` and `wfbe_hq_deployed = false` (`:79-80`);
- clients receive `HandleSpecial ["set-hq-killed-eh", _mhq]` so non-server clients attach a killed event handler (`:91`);
- the old deployed structure is deleted (`:97`);
- `wfbe_hqinuse` is released (`:103-104`).

Base-area creation is unusual: the server creates the `LocationLogicStart`, but the actual `avail`, `side` and `wfbe_basearea` update is done by client-bound `RequestBaseArea.sqf` (`RequestBaseArea.sqf:1-4`). Treat base-area accounting as multiplayer-sensitive until it is proven under JIP and hostile clients.

The base-area limit itself is also only proven as a local client affordance at deploy time. `coin_interface.sqf:13-26` reads the client's `wfbe_basearea` array to decide whether HQ deploy/build controls are allowed, while `Server/FSM/basearea.sqf:46-78` later prunes invalid area logics. That later cleanup is useful housekeeping, but it is not a server-side veto for a forged or stale deploy/build request.

## HQ Destruction And Wreck Markers

HQ death is handled by `Server_OnHQKilled.sqf`. If the destroyed object was a deployed HQ, the server creates a dead MHQ object at the structure position, marks it damaged, flips `wfbe_hq_deployed = false`, updates `wfbe_hq` to the wreck, deletes the deployed-HQ shield walls and schedules deletion of the deployed structure (`Server_OnHQKilled.sqf:26-48`).

The same worker awards score/bounty messages (`:47-81` on docs/source; line drift is named in the branch matrix) and publishes allied-only HQ wreck marker state:

| Variable | Meaning | Source |
| --- | --- | --- |
| `IS_WEST_HQ_ALIVE` / `IS_EAST_HQ_ALIVE` | Whether allied clients should delete or show wreck marker. | `Server_OnHQKilled.sqf:104-119`, `Server_MHQRepair.sqf:60-76` |
| `HQ_WEST_MARKER_INFOS` / `HQ_EAST_MARKER_INFOS` | Marker name, position, type, text, color, side and tracked wreck object. | `Server_OnHQKilled.sqf:89-119` |

`updateclient.sqf` polls these missionNamespace variables every client update tick. West clients delete `HQ_WRECK_WEST` when alive, otherwise update the local marker against the tracked HQ wreck object (`updateclient.sqf:41-69`). East clients do the equivalent for `HQ_WRECK_EAST` (`:72-100`). The server intentionally does not create a global marker because enemies should not see allied HQ wrecks (`Server_OnHQKilled.sqf:89-99`).

### HQ Kill Score And Bounty Branch Matrix

DR-50 remains branch-unrescued after the 2026-06-23 current-B74.1 refresh. Every checked current maintained-root target still sets `_points = 30000 / 100 * WFBE_C_BUILDINGS_SCORE_COEF`, awards that generic HQ building score regardless of teamkill, then awards `_score = 900` again under the non-teamkill guard. The coefficient is still `3`, so a clean enemy HQ kill pays `900 + 900 = 1800`; a friendly/teamkill HQ kill still gets the generic `900`.

Do not treat Miksuu score/HQ/bounty branch names as fixes without file-level proof. The same-day upstream scan found older one-award ancestry, but current Miksuu `master@b8389e748243` still has the double-award shape in both maintained roots. `f17445c15` and `b31539b46` are ancestors of current Miksuu; later folder-structure work such as `96809ac35` moved a generic `_points` award into the current mission layout, so ancestry alone is not a DR-50 rescue.

| Ref / root | Evidence | Status |
| --- | --- | --- |
| Docs/source `HEAD@c2d513ecb` Chernarus + maintained Vanilla | `Server/Functions/Server_OnHQKilled.sqf:23,47,49,75,78,81`; `Common/Init/Init_CommonConstants.sqf:356`. Checked HQ-kill score paths are source-unchanged from prior docs `9b7eb4bc` / `97e4cdd0` / `4d4610f1`. | Double-award present in both maintained roots. |
| Current stable/B74.1 `origin/master@f8a76de34` and `origin/claude/b74.1-aicom@f8a76de34` Chernarus + maintained Vanilla | `Server/Functions/Server_OnHQKilled.sqf:23,64,66,106,109,112`; coefficient line drift is Chernarus `Common/Init/Init_CommonConstants.sqf:753` and maintained Vanilla `:555`. B74..B74.1 changes only Chernarus constants among checked HQ-score files. | Double-award present in both maintained roots; B74.1/current master is not a DR-50 scoring fix. |
| Current B69 `origin/claude/b69@8d465fce` and B74 `origin/claude/b74-aicom-spend@b23f557f` Chernarus + maintained Vanilla | B69..B74 has no `Server_OnHQKilled.sqf` delta. Both keep `Server/Functions/Server_OnHQKilled.sqf:23,64,66,106,109,112`; coefficient line drift is B69 Chernarus `Common/Init/Init_CommonConstants.sqf:721`, B74 Chernarus `:734`, and B69/B74 maintained Vanilla `:555`. Both also have base-fall smoke/sting code at `Server_OnHQKilled.sqf:57,103`. | Double-award still present in both maintained roots; B69/B74 spectacle code and Chernarus constants drift are not DR-50 scoring fixes. |
| Current Miksuu `b8389e748243` | `Server_OnHQKilled.sqf:23,47,49,75,78,81`; coefficient at `Init_CommonConstants.sqf:356`. Verified direct upstream `master` still resolves to `b8389e748243` on 2026-06-23. | Double-award present in both maintained roots. |
| `origin/perf/quick-wins@0076040f` | Same two-award shape at `Server_OnHQKilled.sqf:23,47,49,75,78,81`; coefficient at `Init_CommonConstants.sqf:356`. | Not fixed by perf branch. |
| Historical release commit `a96fdda2` | Same two-award shape at `Server_OnHQKilled.sqf:23,52,54,80,83,86`; coefficient at `Init_CommonConstants.sqf:372`. Current origin exposes no live `release/*`, `feat/*hq*`, `feat/*score*`, `feat/*bounty*` or `feat/*base*` heads on 2026-06-23; broad B74/commander matches are AI-commander context/log branches, not HQ-score rescue heads. | Historical evidence only; no current release head to treat as a rescue branch. |
| Historical Miksuu one-award ancestors | `miksuu/ScoreForKillingFactories@f17445c15190`, `miksuu/Fix0ScoreBountyBug@415615c9662a`, `miksuu/FixNukeMoneyGain@2ad3a7d38837` and `miksuu/TakistanNukeSoundFileMissing@f3eae47a24ad` share the older handler blob `12d33a8f87ee`: no `_points`, one `_score = 900`, and the award inside the non-teamkill guard. These branches use the old Chernarus plus old `Missions/[61-2hc]...takistan` layout, not the current `Missions_Vanilla/[61-2hc]...` maintained root. | Useful provenance only; not a current maintained-root rescue. |
| Miksuu branch-only one-award current-layout evidence | `miksuu/AntiHQTeamkillDisabledInDebugMode@5bafe566951a` has current `Missions_Vanilla` layout and one-award/non-teamkill-guard shape. Adjacent branch blobs such as `5aeea270e25f` and `bbfc46060f8a` carry similar branch-only one-award handlers. | Branch-only evidence; current Miksuu master does not contain it, so DR-50 remains open. |
| Miksuu bounty tune / non-fix branches | `miksuu/BountyModifierTo4@cc127ef40b4d` has no `_score = 900` and no `_points` in `Server_OnHQKilled.sqf`, so it predates the HQ score award rather than fixing the double-award. `96809ac35` is the relevant folder-structure history point for the current generic `_points` award shape. | Branch names are search leads only; file-level handler proof decides fix status. |

Patch shape: keep a single non-teamkill HQ score award, make friendly/teamkill HQ destruction award zero score, propagate maintained Vanilla, then smoke enemy HQ kill, friendly HQ teamkill and DR-20 idempotency/replayed-HQ-kill interactions.

Marker cleanup has two follow-up risks. `Server_MHQRepair.sqf:56` calls the client marker helper during repair, but `Client_Delete_Marker.sqf:24-25` comments `deleteMarkerLocal` while executing `deleteMarker`, so side-local cleanup semantics need smoke. Also, the dead-state marker branch only updates while the tracked wreck object is non-null; if the wreck disappears first, `Common_UpdateMarker.sqf:25` exits on null object instead of deleting the stale marker.

Mobile HQ killed event handling is mixed-locality. The server attaches its own killed EH when it creates HQ/MHQ objects, and also asks clients to attach `RequestSpecial ["process-killed-hq", _this]` for mobile HQ kills because the killed EH can fire locally (`Construction_HQSite.sqf:89-93`, `Server_MHQRepair.sqf:37-43`, `Client/PVFunctions/HandleSpecial.sqf:34`, `Init_Client.sqf:499-503`). The server receives that forwarded event through `Server_HandleSpecial.sqf:114-116`.

## MHQ Repair

The normal repair-truck action is client-led before it reaches the server:

- client requires the HQ to be dead and within 30m of the repair vehicle (`Action_RepairMHQ.sqf:5-6`);
- client checks `wfbe_hq_repairing`, repair count/price and currency (`:8-27`);
- client debits side supply or player funds (`:29-33`);
- client sends `RequestMHQRepair` with only `sideJoined` (`:35`);
- client flips local repair flags/count (`:37-40`).

The server worker creates a fresh MHQ at the wreck position, sets side/type/trash/taxi variables and event handlers, updates `wfbe_hq`, `wfbe_hq_deployed = false`, `wfbe_hq_repairing = false`, increments `wfbe_hq_repair_count`, sends commander lock state, broadcasts a mobilized side message, deletes the wreck, clears allied wreck markers and logs the repair (`Server_MHQRepair.sqf:7-79`).

This is functionally coherent for honest clients, but authority-light: the server receives only the side, not the requester/repair vehicle/payment context. The [Server authority migration map](Server-Authority-Migration-Map) already tracks this as part of the construction/economy authority class.

The repair worker also lacks a server-side duplicate-entry guard before setting `wfbe_hq_repairing` inside `Server_MHQRepair.sqf:23`. The client actions check `wfbe_hq_repairing` locally (`Action_RepairMHQ.sqf:8-9`; `WASP/actions/Action_RepairMHQDepot.sqf:10-11`), but two near-simultaneous requests can still enter the side-only server worker unless the future hardening patch rechecks and sets the mutex before creating the replacement MHQ.

### Branch Intel - Upstream HQ Repair Price Candidate

`origin/claude/upstream-hq-repair-price@440be3da0bda` is a branch-only MHQ repair price/action-label candidate, not current stable behavior and not a server-authority fix. Its merge-base with current stable is `be2bbd084`, an ancestor of `origin/master@f8a76de34`; direct diffs against current stable also include unrelated B74.1 `Init_CommonConstants.sqf:914-920` player-stats drift, so any port must preserve `WFBE_C_STATS_ENABLED = true`.

| Ref | Evidence | Status |
| --- | --- | --- |
| Current stable `origin/master@f8a76de34` | Source Chernarus and maintained Vanilla still register the repair-truck action as plain `localize 'STR_WF_Repair_MHQ'` at `Common/Init/Init_Unit.sqf:67`; `Action_RepairMHQ.sqf:42` hints `STR_WF_INFO_Repair_MHQ_Repair` without a next-price argument. The client-side repair prices are still `25000 / 40000 / 50000` at Chernarus `Common/Init/Init_CommonConstants.sqf:465-467` and maintained Vanilla `:287-289`; the client still debits and sends only `sideJoined` at `Action_RepairMHQ.sqf:24-35`, while `RequestMHQRepair.sqf:1` forwards that to `Server_MHQRepair.sqf:7-79`. | Current stable has the old label/hint shape and the same authority-light MHQ repair boundary. |
| `origin/claude/upstream-hq-repair-price@440be3da0bda` | Against merge-base `be2bbd084`, payload is six files / +76 / -26 and `git diff --check` is clean. In both maintained roots, `Init_Unit.sqf:71-78` formats the repair-truck action label with the spawn-time next price, `Action_RepairMHQ.sqf:43-55` formats the post-repair hint with the live next price or `-`, and `stringtable.xml:940-945` plus Chernarus `:4592-4597` / Vanilla `:4591-4596` add `%1` to the repair hint/action strings. There is no branch payload under `Server/`, `RequestMHQRepair.sqf` or `Init_PublicVariables.sqf`. | Branch-only UI/economy candidate. Review repair-count semantics before promotion: the inherited `Action_RepairMHQ.sqf:22` cap check exits when the current price equals `WFBE_C_BASE_HQ_REPAIR_PRICE_3RD`, so the branch can display the third-price slot as a next price after the second repair even though the next attempt may hit `STR_WF_INFO_MHQ_Repairs_Used`. Smoke labels, insufficient funds, first/second/third-attempt messaging, side-supply vs player-funds mode and maintained Vanilla parity. |

The explicit alive/dead HQ marker broadcasts and client update branches are west/east only. Resistance HQ recovery is therefore not covered by this marker state machine (`Server_OnHQKilled.sqf:104`, `Server_MHQRepair.sqf:60`, `updateclient.sqf:42`).

## WASP Cash HQ Recovery

`WASP/actions/Action_RepairMHQDepot.sqf` is a separate live WASP scroll action for commander-style cash recovery. It checks dead HQ and one-time `cashrepaired`, debits player funds, sends `RequestMHQRepair`, sets `cashrepaired`, moves the wreck above the player, and resets all friendly town `supplyvalue` to `10` client-side (`Action_RepairMHQDepot.sqf:7-29`).

This is not just "another repair UI." It mutates economy/town state and HQ positioning locally before the server repair path runs. Treat it as a server-authority migration lane before adding any new HQ recovery, paradrop or comeback mechanic.

## Authority And Risk Register

| Status | Risk | Evidence | Next owner action |
| --- | --- | --- | --- |
| Branch-split commander vote correctness | Current stable/B69/B74 fixed the server tautology to `_highest >= _aiVotes`, but UI preview/policy smoke remains open; docs/source/Miksuu/perf/historical refs still ignore AI/no-commander vote count when there is a non-tied player candidate. | Current stable/B69/B74 `Server_VoteForCommander.sqf:18,26-27,43`; old-shape refs `:43`; `GUI_VoteMenu.sqf:87-89` | Decide intended tie/AI/no-commander semantics, align preview/server behavior, and smoke player-majority, no-commander-majority, equal-vote and tie cases on the exact target branch. |
| Branch-split correctness | Current docs head manual commander reassignment helper still passes an array as `_side`; stable/Miksuu/perf/release/feat-ai fix helper unpacking but keep duplicate notification senders. | `RequestNewCommander.sqf:13-14`; docs `Server_AssignNewCommander.sqf:3-5,9`; fixed-helper refs `Server_AssignNewCommander.sqf:4-5,10` | Patch/port via [Commander reassignment call shape](Commander-Reassignment-Call-Shape), choose one notification owner, then smoke one client notification. |
| Authority-light | Normal MHQ repair is client-debited and sends only side to server. | `Action_RepairMHQ.sqf:24-35`; `RequestMHQRepair.sqf:1`; `Server_MHQRepair.sqf:7-79` | Server should validate requester, side, dead HQ, repair vehicle range, repair count and funds before creating the MHQ. |
| Race risk | MHQ repair uses local client locks, but the server worker does not reject duplicate in-flight repair requests before setting `wfbe_hq_repairing`. | `Action_RepairMHQ.sqf:8-9`; `WASP/actions/Action_RepairMHQDepot.sqf:10-11`; `Server_MHQRepair.sqf:23-57` | Add a server mutex check/set around the first side-logic read and smoke two rapid repair requests against one wreck. |
| Partial fallback | Commander disconnect clears `wfbe_commander` and warns the side, but does not prove automatic reassignment. | `Server_OnPlayerDisconnected.sqf:136-146`; `Server_VoteForCommander.sqf:48-57` | Decide whether disconnect should leave no commander, restart a vote, or restore AI commander behavior; smoke human commander disconnect and reconnect. |
| Authority-light | Commander income percent is client-written and server-consumed. | `GUI_Menu_Economy.sqf:24-27,74-79`; `updateresources.sqf:36-43` | Server should accept percent changes only from the current commander team and clamp the configured range. |
| Authority-light | Commander structure sell/refund is driven from Economy UI. | `GUI_Menu_Economy.sqf:104-150` | Move ownership, side, refund and destruction checks server-side before expanding sell/recovery mechanics. |
| Authority-light/high impact | WASP cash HQ recovery moves the wreck and resets town SV client-side. | `WASP/actions/Action_RepairMHQDepot.sqf:19-29` | Move one-time flag, funds debit, HQ recovery position and town-SV side effects to a server-owned request. |
| Mixed locality | Mobile-HQ killed EH can be forwarded by clients through `RequestSpecial`. | `Client/PVFunctions/HandleSpecial.sqf:34`; `Server_HandleSpecial.sqf:114-116` | If hardening `RequestSpecial`, preserve legitimate HQ-kill forwarding while rejecting forged/malformed payloads. |
| Patch-ready scoring correctness | HQ kill score is awarded once through the generic building score path and again through the HQ bounty path; teamkills still get the generic award. | [HQ kill score and bounty branch matrix](#hq-kill-score-and-bounty-branch-matrix) | Keep one non-teamkill score award, zero teamkill score, propagate maintained Vanilla and smoke enemy/friendly HQ kills plus DR-20 idempotency. |
| JIP-sensitive | HQ wreck markers are local client markers derived from server-published marker arrays and object refs. | `Server_OnHQKilled.sqf:89-119`; `updateclient.sqf:41-100` | Smoke late join after HQ kill, repaired HQ marker deletion, and moved wreck marker updates. |
| Cleanup risk | HQ wreck marker deletion/helper behavior mixes side-local intent with `deleteMarker`, and null wreck objects can leave stale markers. | `Server_MHQRepair.sqf:56`; `Client_Delete_Marker.sqf:24-25`; `Common_UpdateMarker.sqf:25` | Verify marker removal after repair and after wreck deletion; prefer local deletion for side-local markers if source smoke confirms intent. |
| Side coverage gap | HQ alive/dead marker broadcasts cover west/east, not resistance. | `Server_OnHQKilled.sqf:104`; `Server_MHQRepair.sqf:60`; `updateclient.sqf:42-100` | Keep resistance HQ/economy disabled or design a full three-side marker state machine before enabling resistance HQ recovery. |
| Multiplayer-sensitive | Base-area accounting is updated via client-bound `RequestBaseArea`, while deploy/build limits are first enforced through local client state. | `coin_interface.sqf:13-26`; `Construction_HQSite.sqf:54-59`; `RequestBaseArea.sqf:1-4`; `basearea.sqf:46-78` | Audit before changing defense availability, base area limits or server authority around CoIn; server should be able to reject stale or forged area/build requests. |
| Partial/latent | AI commander variable state exists, but full autonomous commander ownership is not proven. | `wfbe_commander = objNull`; `Server_VoteForCommander.sqf:48-57`; [AI commander autonomy audit](AI-Commander-Autonomy-Audit) | Keep AI commander revival separate from commander/HQ correctness patches. |
| Partial UI/order feature | Docs/source, Miksuu and perf Commander Set Task UI build task data and play HQ speech, but maintained-root `SetTask` sends are commented while `Client/PVFunctions/SetTask.sqf` still creates `CommanderOrder` if invoked. Current stable `origin/master@0139a346`, B69 `origin/claude/b69@8d465fce`, B74 `origin/claude/b74-aicom-spend@b23f557f` and `origin/feat/naval-hvt-objectives@2e1c59317186` re-enable targeted/client-bound sends as "Objective Ping" in both maintained roots, but old town `TaskSystem` remains disabled/separate. | Docs `GUI_Menu_Command.sqf:315-344`; docs `Client/PVFunctions/SetTask.sqf:8-14`; docs `Common/Init/Init_PublicVariables.sqf:33`; stable/B69/B74/naval-HVT `GUI_Menu_Command.sqf:336,344` and `Common/Init/Init_PublicVariables.sqf:40`; historical `a96fdda2` `Init_PublicVariables.sqf:36`; docs `Init_Client.sqf:75,744` | Hide the old-shape docs/Miksuu/perf affordance or deliberately port the current-stable Objective Ping shape with server/JIP/task-spam smoke; do not confuse it with revival of the old town TaskSystem. |
| HQ-specific construction authority | CoIn sends HQ/structure requests from the client; the server `RequestStructure` handler accepts side/class/position/direction and executes construction, while `Construction_HQSite` toggles deployed/mobile HQ state. | `coin_interface.sqf:494,718`; `RequestStructure.sqf:3-21`; `Construction_HQSite.sqf:17-23,80` | When hardening construction, include HQ-specific commander/range/role checks instead of treating HQ deploy/pack as only a generic building purchase. |

## Development Rules

1. Do not infer HQ state by nearest-object searches when side-logic state is available.
2. Keep `wfbe_hq` and `wfbe_hq_deployed` updates server-owned and globally broadcast.
3. Preserve client-side CoIn refresh after deploy/mobilize and commander reassignment.
4. When hardening `RequestSpecial`, preserve `process-killed-hq`'s legitimate locality bridge but validate payload shape and object side.
5. Do not merge WASP cash HQ recovery into normal repair without owner approval; it has extra economy/town side effects.
6. After any HQ lifecycle patch, run a JIP-oriented smoke: join after boot, deploy HQ, mobilize HQ, destroy deployed HQ, destroy mobile HQ, repair HQ, change commander, and verify markers/actions on both sides.

## Continue Reading

Previous: [Towns, camps and capture atlas](Towns-Camps-And-Capture-Atlas) | Next: [Construction and CoIn systems](Construction-And-CoIn-Systems-Atlas)

Main map: [Home](Home) | Authority map: [Server authority migration map](Server-Authority-Migration-Map) | PV map: [Public variable channel index](Public-Variable-Channel-Index)
