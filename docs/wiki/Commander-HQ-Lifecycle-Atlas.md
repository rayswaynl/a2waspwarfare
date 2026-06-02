# Commander And HQ Lifecycle Atlas

> Canonical source-backed map for commander selection, commander-client affordances, HQ/MHQ deployment, HQ destruction, wreck tracking and MHQ repair. This page bridges [Construction and CoIn systems](Construction-And-CoIn-Systems-Atlas), [AI commander autonomy audit](AI-Commander-Autonomy-Audit), [Commander reassignment call shape](Commander-Reassignment-Call-Shape), [Server authority migration map](Server-Authority-Migration-Map) and [Public variable channel index](Public-Variable-Channel-Index).

All source paths below are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`.

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
| Server side init/state | `Server/Init/Init_Server.sqf:313-371,380,397-413,622` |
| Commander vote worker | `Server/Functions/Server_VoteForCommander.sqf:9-57` |
| Manual reassignment path | `Client/GUI/GUI_Commander_VoteMenu.sqf:46`, `Server/PVFunctions/RequestNewCommander.sqf:3-16`, `Server/Functions/Server_AssignNewCommander.sqf:3-14` |
| Commander getters/votes | `Common/Functions/Common_GetCommanderTeam.sqf:7-12`, `Common/Functions/Common_SetCommanderVotes.sqf:3-10` |
| HQ getters | `Common/Functions/Common_GetSideHQ.sqf:7-12`, `Common/Functions/Common_GetSideHQDeployStatus.sqf:7-12` |
| Client commander/HQ watchers | `Client/Init/Init_Client.sqf:382-388,489-503`, `Client/FSM/updateclient.sqf:184-244` |
| HQ deploy/mobilize worker | `Server/Construction/Construction_HQSite.sqf:13-104` |
| HQ killed worker | `Server/Functions/Server_OnHQKilled.sqf:25-44,46-82,84-118` |
| MHQ repair worker | `Client/Action/Action_RepairMHQ.sqf:5-42`, `Server/Functions/Server_MHQRepair.sqf:7-79` |
| Commander economy controls | `Client/GUI/GUI_Menu_Economy.sqf:24-27,74-79,104-150`, `Server/FSM/updateresources.sqf:36-43` |
| WASP cash HQ recovery | `WASP/actions/Action_RepairMHQDepot.sqf:7-29` |
| PV/PVF registration | `Common/Init/Init_PublicVariables.sqf:13,17,36,38` |
| HQ wreck marker loop | `Client/FSM/updateclient.sqf:41-100` |
| Special message handlers | `Client/Functions/Client_FNC_Special.sqf:6-34,70-75`, `Client/PVFunctions/HandleSpecial.sqf:34`, `Server/Functions/Server_HandleSpecial.sqf:114-116` |

## Startup State

`Init_Server.sqf` creates each side's starting mobile HQ near the side start position, sets `WFBE_Taxi_Prohib`, `wfbe_side`, `wfbe_trashable`, `wfbe_structure_type = "Headquarters"`, killed and hit event handlers, and Chernarus-dependent west textures (`Init_Server.sqf:313-330`).

The same side logic then publishes the baseline state:

| Variable | Initial value | Source |
| --- | --- | --- |
| `wfbe_commander` | `objNull` | `Init_Server.sqf:356` |
| `wfbe_hq` | starting MHQ object | `Init_Server.sqf:357` |
| `wfbe_hq_deployed` | `false` | `Init_Server.sqf:358` |
| `wfbe_hq_repair_count` | `1` | `Init_Server.sqf:359` |
| `wfbe_hq_repairing` | `false` | `Init_Server.sqf:360` |
| `wfbe_votetime` | `WFBE_C_GAMEPLAY_VOTE_TIME` | `Init_Server.sqf:370` |
| `wfbe_hqinuse` | `false` | `Init_Server.sqf:371` |
| `wfbe_basearea` | `[]` when base-area mode is enabled | `Init_Server.sqf:380` |
| `wfbe_radio_hq`, `wfbe_radio_hq_id` | side radio logic and identity | `Init_Server.sqf:397-413` |

This is why fresh clients can wait on side logic variables instead of rediscovering HQ state from world objects. `Common_GetSideHQ.sqf` and `Common_GetSideHQDeployStatus.sqf` are thin side-to-logic readers, not search functions (`Common_GetSideHQ.sqf:7-12`, `Common_GetSideHQDeployStatus.sqf:7-12`).

## Commander Vote Flow

At the end of server init, every present side starts `WFBE_SE_FNC_VoteForCommander` (`Init_Server.sqf:622`). The worker:

1. reads the side's vote time (`Server_VoteForCommander.sqf:9-11`);
2. counts down `wfbe_votetime` once per second and broadcasts it on side logic (`:13-14`);
3. counts player-group `wfbe_vote` values from `wfbe_teams` (`:17-29`);
4. resolves ties and AI votes (`:31-46`);
5. sets `wfbe_commander` to the selected player group or `objNull` for AI/no commander (`:48-49`);
6. sends `HandleSpecial ["commander-vote", _commander]` to side clients (`:51-52`);
7. stops any running AI commander flag when a player commander is selected (`:54-57`).

`Common_SetCommanderVotes.sqf` is a helper that sets every team vote to a provided value (`Common_SetCommanderVotes.sqf:3-10`). It does not decide the winner.

## Manual Reassignment Flow

The commander vote menu sends:

```sqf
["RequestNewCommander", [side group player, _voted_commander]] Call WFBE_CO_FNC_SendToServer;
```

`RequestNewCommander` is registered as a server PVF (`Init_PublicVariables.sqf:13`). The server handler reads the side and target commander correctly, only accepts reassignment when `wfbe_votetime <= 0`, sets `wfbe_commander`, spawns `AssignNewCommander` and sends a `new-commander-assigned` special message (`RequestNewCommander.sqf:3-16`).

The helper currently has a confirmed call-shape bug: `Server_AssignNewCommander.sqf` uses `_side = _this` while also reading `_commander = _this select 1` (`Server_AssignNewCommander.sqf:3-5`). That means helper-side side-logic lookups and notification routing receive an array instead of a `SIDE`. Use [Commander reassignment call shape](Commander-Reassignment-Call-Shape) for the patch plan and generated-mission propagation notes.

Client-side special handlers show commander vote/reassignment messages and, for null reassignment, locally mirror `wfbe_commander = objNull` on the player's side logic (`Client_FNC_Special.sqf:6-34`).

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

## HQ Destruction And Wreck Markers

HQ death is handled by `Server_OnHQKilled.sqf`. If the destroyed object was a deployed HQ, the server creates a dead MHQ object at the structure position, marks it damaged, flips `wfbe_hq_deployed = false`, updates `wfbe_hq` to the wreck and schedules deletion of the deployed structure (`Server_OnHQKilled.sqf:25-44`).

The same worker awards score/bounty messages (`:46-82`) and publishes allied-only HQ wreck marker state:

| Variable | Meaning | Source |
| --- | --- | --- |
| `IS_WEST_HQ_ALIVE` / `IS_EAST_HQ_ALIVE` | Whether allied clients should delete or show wreck marker. | `Server_OnHQKilled.sqf:97-114`, `Server_MHQRepair.sqf:60-76` |
| `HQ_WEST_MARKER_INFOS` / `HQ_EAST_MARKER_INFOS` | Marker name, position, type, text, color, side and tracked wreck object. | `Server_OnHQKilled.sqf:84-114` |

`updateclient.sqf` polls these missionNamespace variables every client update tick. West clients delete `HQ_WRECK_WEST` when alive, otherwise update the local marker against the tracked HQ wreck object (`updateclient.sqf:41-69`). East clients do the equivalent for `HQ_WRECK_EAST` (`:72-100`). The server intentionally does not create a global marker because enemies should not see allied HQ wrecks (`Server_OnHQKilled.sqf:84-96`).

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

The explicit alive/dead HQ marker broadcasts and client update branches are west/east only. Resistance HQ recovery is therefore not covered by this marker state machine (`Server_OnHQKilled.sqf:97`, `Server_MHQRepair.sqf:60`, `updateclient.sqf:42`).

## WASP Cash HQ Recovery

`WASP/actions/Action_RepairMHQDepot.sqf` is a separate live WASP scroll action for commander-style cash recovery. It checks dead HQ and one-time `cashrepaired`, debits player funds, sends `RequestMHQRepair`, sets `cashrepaired`, moves the wreck above the player, and resets all friendly town `supplyvalue` to `10` client-side (`Action_RepairMHQDepot.sqf:7-29`).

This is not just "another repair UI." It mutates economy/town state and HQ positioning locally before the server repair path runs. Treat it as a server-authority migration lane before adding any new HQ recovery, paradrop or comeback mechanic.

## Authority And Risk Register

| Status | Risk | Evidence | Next owner action |
| --- | --- | --- | --- |
| Patch-ready correctness | Manual commander reassignment helper passes an array as `_side`. | `RequestNewCommander.sqf:13-14`; `Server_AssignNewCommander.sqf:3-5` | Patch via [Commander reassignment call shape](Commander-Reassignment-Call-Shape), then smoke one client notification. |
| Authority-light | Normal MHQ repair is client-debited and sends only side to server. | `Action_RepairMHQ.sqf:24-35`; `RequestMHQRepair.sqf:1`; `Server_MHQRepair.sqf:7-79` | Server should validate requester, side, dead HQ, repair vehicle range, repair count and funds before creating the MHQ. |
| Authority-light | Commander income percent is client-written and server-consumed. | `GUI_Menu_Economy.sqf:24-27,74-79`; `updateresources.sqf:36-43` | Server should accept percent changes only from the current commander team and clamp the configured range. |
| Authority-light | Commander structure sell/refund is driven from Economy UI. | `GUI_Menu_Economy.sqf:104-150` | Move ownership, side, refund and destruction checks server-side before expanding sell/recovery mechanics. |
| Authority-light/high impact | WASP cash HQ recovery moves the wreck and resets town SV client-side. | `WASP/actions/Action_RepairMHQDepot.sqf:19-29` | Move one-time flag, funds debit, HQ recovery position and town-SV side effects to a server-owned request. |
| Mixed locality | Mobile-HQ killed EH can be forwarded by clients through `RequestSpecial`. | `Client/PVFunctions/HandleSpecial.sqf:34`; `Server_HandleSpecial.sqf:114-116` | If hardening `RequestSpecial`, preserve legitimate HQ-kill forwarding while rejecting forged/malformed payloads. |
| JIP-sensitive | HQ wreck markers are local client markers derived from server-published marker arrays and object refs. | `Server_OnHQKilled.sqf:84-114`; `updateclient.sqf:41-100` | Smoke late join after HQ kill, repaired HQ marker deletion, and moved wreck marker updates. |
| Cleanup risk | HQ wreck marker deletion/helper behavior mixes side-local intent with `deleteMarker`, and null wreck objects can leave stale markers. | `Server_MHQRepair.sqf:56`; `Client_Delete_Marker.sqf:24-25`; `Common_UpdateMarker.sqf:25` | Verify marker removal after repair and after wreck deletion; prefer local deletion for side-local markers if source smoke confirms intent. |
| Side coverage gap | HQ alive/dead marker broadcasts cover west/east, not resistance. | `Server_OnHQKilled.sqf:97`; `Server_MHQRepair.sqf:60`; `updateclient.sqf:42-100` | Keep resistance HQ/economy disabled or design a full three-side marker state machine before enabling resistance HQ recovery. |
| Multiplayer-sensitive | Base-area accounting is updated via client-bound `RequestBaseArea`. | `Construction_HQSite.sqf:54-59`; `RequestBaseArea.sqf:1-4` | Audit before changing defense availability, base area limits or server authority around CoIn. |
| Partial/latent | AI commander variable state exists, but full autonomous commander ownership is not proven. | `wfbe_commander = objNull`; `Server_VoteForCommander.sqf:48-57`; [AI commander autonomy audit](AI-Commander-Autonomy-Audit) | Keep AI commander revival separate from commander/HQ correctness patches. |

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
