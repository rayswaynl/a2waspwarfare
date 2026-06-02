# Construction And CoIn Systems Atlas

Page ownership: this page owns the construction/CoIn runtime map, source anchors, request-handler map and safe extension checklist. [Commander/HQ lifecycle](Commander-HQ-Lifecycle-Atlas) owns commander selection, HQ deploy/mobilize, HQ destruction, wreck markers and MHQ repair. [Deep-review findings](Deep-Review-Findings) DR-6 owns the exact per-handler construction-authority proof; [Server authority migration map](Server-Authority-Migration-Map) owns the broader migration design table.

This page maps the build system that turns commander/repair-truck actions into HQ state changes, factories, base defenses, static weapons and repair flows.

All source paths below are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`.

## Source Map

| Role | Files |
| --- | --- |
| Client entry actions | `Client/Action/Action_Build.sqf`, `Client/Action/Action_BuildRepair.sqf`, `Client/Action/Action_RepairMHQ.sqf` |
| CoIn data setup | `Client/Init/Init_Coin.sqf` |
| CoIn runtime UI | `Client/Module/CoIn/coin_interface.sqf` |
| Client action lifecycle | `Client/FSM/updateclient.sqf`, `Client/Functions/Client_PreRespawnHandler.sqf`, `Client/Functions/Client_OnKilled.sqf` |
| Server PVF entrypoints | `Server/PVFunctions/RequestStructure.sqf`, `Server/PVFunctions/RequestDefense.sqf`, `Server/PVFunctions/RequestMHQRepair.sqf` |
| Server construction workers | `Server/Construction/Construction_HQSite.sqf`, `Construction_SmallSite.sqf`, `Construction_MediumSite.sqf`, `Construction_StationaryDefense.sqf` |
| Structure config | `Common/Config/Core_Structures/Structures_*.sqf` |
| Server support functions | `Server_HandleBuildingRepair.sqf`, `Server_MHQRepair.sqf`, `Server_OnHQKilled.sqf`, `Server_HandleDefense.sqf`, `Server_CreateDefenseTemplate.sqf` |
| Client structure markers | `Client/Init/Init_BaseStructure.sqf` |

## High-Level Flow

```mermaid
flowchart TD
  A["Commander gets HQAction"] --> B["Action_Build.sqf"]
  C["Repair truck gets repair build action"] --> D["Action_BuildRepair.sqf"]
  B --> E["coin_interface.sqf with MCoin"]
  D --> E2["coin_interface.sqf with RCoin"]
  E --> F["Client-side cost, preview, placement checks"]
  E2 --> F
  F --> G["RequestStructure PVF"]
  F --> H["RequestDefense PVF"]
  G --> I["Server/Construction/Construction_*.sqf"]
  H --> J["ConstructDefense -> Construction_StationaryDefense.sqf"]
  I --> K["Server creates real object, vars, EHs, markers init"]
  J --> L["Server creates defense, optional AI gunner/artillery setup"]
  K --> M["Client Init_BaseStructure.sqf local markers"]
```

## Structure Configuration

Each side/faction structure file builds the same parallel arrays. `Structures_CO_US.sqf` is a representative example:

| Array | Meaning | Example source |
| --- | --- | --- |
| `WFBE_<side>STRUCTURES` | Logical structure labels such as `Headquarters`, `Barracks`, `Light`, `CommandCenter`, `Heavy`, `Aircraft`, `ServicePoint`, `AARadar`. | Lines 23, 32, 41, 50, 59, 68, 77, 86. |
| `WFBE_<side>STRUCTURENAMES` | Actual classnames used by CoIn and server creation. | Lines 24, 33, 42, 51, 60, 69, 78, 88. |
| `WFBE_<side>STRUCTURECOSTS` | Build/deploy costs. | Lines 26, 35, 44, 53, 62, 71, 80, 90. |
| `WFBE_<side>STRUCTURETIMES` | Build time, `1` in debug, otherwise mostly `30`/`60`. | Lines 27, 36, 45, 54, 63, 72, 81, 91. |
| `WFBE_<side>STRUCTURESCRIPTS` | Server construction worker: `HQSite`, `SmallSite`, `MediumSite`. | Lines 28, 37, 46, 55, 64, 73, 82, 92. |
| `WFBE_<side>STRUCTUREDISTANCES` / `DIRECTIONS` | Placement offsets used by nearby-building logic and defense auto-manning. | Lines 29-30, 38-39, 47-48. |
| `WFBE_<side>DEFENSENAMES` | Defense, fortification, MASH, spawn marker, ammo and service objects. | Lines 115-166. |

After the arrays are built, the script stores them into `missionNamespace` at lines 105-113. In money-only mode, `Common/Init/Init_Common.sqf:350-356` multiplies all structure costs by five.

## Client CoIn Initialization

`Client/Init/Init_Coin.sqf` is the adapter between Warfare data and the BIS CoIn UI.

| Behavior | Evidence |
| --- | --- |
| Sets build area and funds labels on the CoIn logic. | Lines 8-12. |
| Shows only HQ deploy/mobilize when HQ is not deployed. | Lines 20-31. |
| Shows all structures and defenses once HQ is deployed. | Lines 30-40. |
| Repair-truck mode uses only defenses and player cash. | Line 31 and lines 51-55. |
| Builds CoIn categories and item arrays from structure/defense config. | Lines 57-81. |
| Assigns a `BIS_coin_<id>` vehicle variable and stores params. | Lines 83-91. |

CoIn is reinitialized from several lifecycle points:

| Trigger | Source |
| --- | --- |
| Initial client boot waits for `wfbe_hq_deployed`, then initializes `MCoin` based on deployed/undeployed HQ state. | `Client/Init/Init_Client.sqf:489-497`. |
| Repair-truck CoIn initializes `RCoin` with `"REPAIR"` mode. | `Client/Init/Init_Client.sqf:738-739`. |
| Becoming commander refreshes `MCoin` and adds `HQAction`. | `Client/FSM/updateclient.sqf:214-220`. |
| Server/client special message `hq-setstatus` refreshes `MCoin`. | `Client/Functions/Client_FNC_Special.sqf:70-75`. |

## Player Entry Points

| Entry | Behavior |
| --- | --- |
| `Client/Action/Action_Build.sqf` | Runs CoIn from player/HQ context: `[player, player, 2, MCoin, getpos player, side HQ] ExecVM "Client\Module\CoIn\coin_interface.sqf"`. |
| `Client/Action/Action_BuildRepair.sqf` | Runs CoIn from a repair truck using `RCoin`. |
| `Common/Init/Init_Unit.sqf:56-68` | Adds repair-truck build and MHQ repair actions to repair trucks. |
| `Client/FSM/updateclient.sqf:220` | Adds commander build menu action only for the commander, gated by `hqInRange`, `canBuildWHQ` and target player. |
| `Client/Functions/Client_PreRespawnHandler.sqf:36` | Re-adds commander HQAction after respawn. |
| `Client/Functions/Client_OnKilled.sqf:27-28` | Removes `HQAction` from the dead body. |

`Client/Functions/Client_HandleHQAction.sqf` is a small lag guard: it keeps `canBuildWHQ = false` while an HQ object still exists and flips it back once the object is gone.

## CoIn Runtime Behavior

`Client/Module/CoIn/coin_interface.sqf` is a large customized BIS CoIn controller.

| Area | Evidence |
| --- | --- |
| Aborts if the source object is dead. | Line 5. |
| Distinguishes HQ vs repair root and resets `lastBuilt` when switching roots. | Lines 8-24. |
| Enforces base-area limit client-side before opening the UI. | Lines 13-26. |
| Opens custom construction title resources and camera controls. | Lines 29-56. |
| Maintains command-menu reopen loop. | Lines 98-112 and 920-937. |
| Has a TODO on CoIn border relocation after logic movement. | Lines 114-120. |
| Allows quick-repeat of last built defense with User15. | Lines 220-228. |
| Allows toggling defense manning with User16. | Lines 231-236. |
| Lets commander sell/delete a pointed defense and refund player cash. | Lines 238-265. |
| Handles HQ mobilize/deploy specially for item index 0. | Lines 485-503. |
| Deducts structure/defense cost client-side before sending the server request. | Lines 658-695. |
| Sends `RequestStructure` / `RequestDefense` to the server. | Lines 718-723. |
| Decrements local base-area availability when placing defenses. | Lines 724-730. |
| Clears the custom title layer when closing. | Line 938. |

## Placement Rules

`Client/Init/Init_Client.sqf:599-728` defines `WFBE_C_STRUCTURES_PLACEMENT_METHOD` when `WFBE_C_STRUCTURES_COLLIDING == 1`.

Important checks:

| Check | Source |
| --- | --- |
| Base-area availability can force red preview. | Lines 611-613. |
| Water placement is rejected. | Line 614. |
| Structures avoid nearby houses/factories by bounding-box distance. | Lines 616-662. |
| Defenses avoid duplicate nearby defenses and enemy entities. | Lines 631-642. |
| Non-HQ structures avoid enemy base structures. | Lines 664-670. |
| Minefields are blocked inside base areas. | Lines 684-687. |
| Structures cannot be placed within 600m of hostile towns or inside enemy base areas. | Lines 694-703. |
| Enemy units near base block non-base placement. | Lines 705-722. |

These are preview/client rules. The server creation handlers do not repeat most of them.

## Server Request Handlers

`Common/Init/Init_PublicVariables.sqf:14-17` registers `RequestStructure`, `RequestDefense` and `RequestMHQRepair` as server PVF commands.

| Request | Server behavior |
| --- | --- |
| `RequestStructure` | Reads side, classname, position and direction from the client payload; maps classname to logical structure and construction script; sends `building-started` messages for major structures; executes `Server\Construction\Construction_<script>.sqf` if the classname exists. See `Server/PVFunctions/RequestStructure.sqf:3-21`. |
| `RequestDefense` | Looks up the classname in `WFBE_<side>DEFENSENAMES`; calls `ConstructDefense` when found. See `Server/PVFunctions/RequestDefense.sqf:2-10`. |
| `RequestMHQRepair` | Spawns `MHQRepair` with the received side. See `Server/PVFunctions/RequestMHQRepair.sqf:1`. |

### Authority Boundary

DR-6 confirms the authority boundary: the client pays cost and enforces most placement/role checks before sending the request, while server-side request handlers mainly check that the requested class exists in the side arrays. They do not re-check commander ownership, funds, build radius, base-area restrictions, hostile-town distance or most collision checks.

This atlas keeps the system map and checklist. For exact forged payload examples and the validation sketch, use [Deep-review findings](Deep-Review-Findings) DR-6; for migration sequencing across other economy authority paths, use [Economy authority first cut](Economy-Authority-First-Cut) and [Server authority migration map](Server-Authority-Migration-Map).

## Server Construction Workers

### HQSite

`Server/Construction/Construction_HQSite.sqf` toggles between deployed HQ structure and mobile HQ vehicle.

When deploying:

- Sets `wfbe_hqinuse` true.
- Creates the deployed HQ structure, sets `wfbe_side` and `wfbe_structure_type = "Headquarters"`.
- Sets `wfbe_hq_deployed = true` and `wfbe_hq` to the new site.
- Initializes client-side base marker via `Client\Init\Init_BaseStructure.sqf`.
- Adds killed, hit and damage handlers.
- Sends side message/logging.
- Deletes the old mobile HQ.

When mobilizing:

- Creates the side-specific MHQ vehicle from `WFBE_<side>MHQNAME`.
- Sets taxi/trash/side/type vars.
- Sets `wfbe_hq_deployed = false` and `wfbe_hq` to the vehicle.
- Sends a client `HandleSpecial` message so clients add killed EH to the mobile HQ.
- Locks/unlocks commander interaction and logs the change.
- Deletes the deployed HQ structure.

Base-area support is present but partly strange: the server creates a `LocationLogicStart`, sets `DefenseTeam` and `weapons`, then sends `RequestBaseArea` to clients. The older direct server-side `avail`, `side` and `wfbe_basearea` updates are inside a commented block at `Construction_HQSite.sqf:56-58`, while `Client/PVFunctions/RequestBaseArea.sqf` sets `avail`, `side`, `wfbe_basearea` on receipt. Treat base-area accounting as multiplayer-sensitive before changing defense availability.

### SmallSite / MediumSite

`Construction_SmallSite.sqf` and `Construction_MediumSite.sqf` are near twins. They:

- Resolve side logic, side ID, build time, construction-site classname and logical structure type.
- Optionally create construction-site objects and a logic with `WFBE_B_*` completion variables.
- Wait through construction steps, with different completion ratios and timing.
- Delete temporary construction objects.
- Create the real structure object.
- Set `wfbe_side` and `wfbe_structure_type`.
- Create wall/defense templates with `CreateDefenseTemplate`.
- Send `Constructed` side message.
- Add the site to `wfbe_structures`.
- Run `Client\Init\Init_BaseStructure.sqf` on clients via `setVehicleInit`.
- Add hit, damage and killed event handlers.

Medium sites use a lower completion ratio (`0.6`) and more staged waiting than small sites.

Focused construction review found a source asymmetry worth treating as a bug candidate rather than a vague TODO:

- `Construction_SmallSite.sqf:70` adds `_nearLogic` to `wfbe_structures_logic`, and `:98-99` says "Remove the logic from the list since it's built" but adds `_nearLogic` again.
- `Construction_MediumSite.sqf:70` adds `_nearLogic`, then `:113-114` removes it after construction.
- No source initializer for `wfbe_structures_logic` was found in the server init path; `Init_Server.sqf` initializes `wfbe_structures` and `wfbe_structures_live`, while `wfbe_structures_logic` appears only in SmallSite/MediumSite/repair-handler code.
- Wave P confirmed the same SmallSite add/add and MediumSite add/remove shape in maintained Vanilla Takistan and the main modded Eden/Napf copies. `Server_HandleBuildingRepair.sqf:81,99` removes repair logic entries, but no active source caller for `HandleBuildingRepair` was found beyond compile/init text, so repair cleanup does not prove SmallSite stale entries are cleared in live play.

Patch shape should be smoke-led: confirm whether small sites can leave duplicate/stale construction logic in a live build, then align SmallSite with MediumSite if the list is actually active.

### StationaryDefense

`Construction_StationaryDefense.sqf` creates defenses, fortifications, minefields and static weapons.

Notable paths:

- Creates the defense and sets `side` plus `wfbe_defense`.
- Special-cases `Sign_Danger` into a minefield and deletes the sign.
- Adds killed/damage handlers.
- If manning is requested and defense AI is enabled, finds a nearby barracks and spawns `HandleDefense`.
- `Server_HandleDefense.sqf` either delegates static defense crew creation to headless clients or creates a side soldier locally and moves it into the gunner seat.
- Artillery defenses can receive BIS ARTY interface initialization and `EquipArtillery`.

## Repair Flows

### MHQ Repair

Client side:

- `Action_RepairMHQ.sqf` requires a dead HQ within 30m of the repair vehicle.
- It checks `wfbe_hq_repairing`, repair count/price, and currency.
- It deducts side supply or player funds on the client, sends `RequestMHQRepair`, sets repair flags and increments the local count.

Server side:

- `Server_MHQRepair.sqf` creates a new MHQ at the wreck position, sets `wfbe_side`, `wfbe_structure_type`, trash/taxi vars and killed/hit handlers.
- It sets `wfbe_hq`, `wfbe_hq_deployed = false`, `wfbe_hq_repairing = false` and increments server `wfbe_hq_repair_count`.
- It sends `SetMHQLock` to the commander and broadcasts HQ-alive marker variables (`IS_WEST_HQ_ALIVE`, `HQ_WEST_MARKER_INFOS`, equivalent east values).
- It deletes the wreck and logs repair.

### Building Repair

`Server_HandleBuildingRepair.sqf` uses a repair logic with `WFBE_B_Completion`. It creates ruins, waits for completion, recreates the site if structure live limits allow it, re-adds init/event handlers and subtracts half the building cost from side supply in currency system 0. If completion stalls, it degrades over time and eventually deletes the repair logic.

Current status is latent/uncalled by static search: `Server_HandleBuildingRepair.sqf` is compiled, but no active caller was found in the source mission. Do not confuse this with the WASP base-repair flow, which is live and separate in `WASP/baserep/viem.sqf` and `WASP/baserep/repair.sqf`.

## Sale And Deletion Flows

There are two sale paths:

| Path | Behavior |
| --- | --- |
| Economy menu structure sale | `Client/GUI/GUI_Menu_Economy.sqf:105-151` lets commanders pick a nearby structure on the map, marks `WFBE_SOLD`, waits `WFBE_C_STRUCTURES_SALE_DELAY`, refunds `WFBE_C_STRUCTURES_SALE_PERCENT`, sends localized messages and damages the structure to 1. |
| CoIn defense sale | `coin_interface.sqf:238-265` lets commanders point at a nearby defense, checks side and prior `sold` state, refunds roughly `price / 2.5` to player funds, increments base-area `avail` and deletes the defense. |

Both are client-initiated. Future server hardening should be careful not to break the current UX but should move final authority for sale/refund/delete to the server.

## Client Markers

`Client/Init/Init_BaseStructure.sqf` waits for common/client init, ignores enemy structures, creates local markers for allied structures and deletes them when the structure dies. Command centers also create a local range ellipse.

The server reaches this script by `setVehicleInit` in construction scripts (`Construction_HQSite.sqf`, `SmallSite`, `MediumSite`) and repair flows.

## Current Risks And Safe Extension Points

| Area | Risk | Safer path |
| --- | --- | --- |
| Server request validation | `RequestStructure` / `RequestDefense` trust client-side payment and placement checks; see [Deep-review findings](Deep-Review-Findings) DR-6. | Add server-side validation of side, commander/repair-truck authority, class membership, funds, radius, base-area availability and collision restrictions before creating objects. Start in request handlers, not in CoIn UI. |
| PVF dispatch | Construction uses generic PVF channels; DR-1 already shows dispatch hardening is needed. | Validate PVF function strings and then validate construction payloads. |
| Base-area availability | `avail`/`weapons` are updated through client-visible logic and direct client CoIn mutations. | Before changing limits, trace `RequestBaseArea`, `coin_interface`, `Construction_StationaryDefense` and JIP behavior together. |
| SmallSite/MediumSite repair logic asymmetry | SmallSite adds `_nearLogic` where its comment says remove; MediumSite removes it. `wfbe_structures_logic` has no obvious source initializer. | Verify runtime list ownership before patching; if active, align SmallSite cleanup to MediumSite and smoke small/medium construction plus repair-logic cleanup. |
| Progressive repair/construction path appears dormant | Progressive mode code remains in construction scripts and economy UI, but `Rsc/Parameters.hpp` exposes only construction-time mode `0`. | Do not expand progressive repair UI until the mission parameter and live caller model are restored intentionally. |
| Cost deduction | Normal build/MHQ repair/sale costs are deducted client-side. | Server should become the final authority for final debits/refunds; client can keep previews and immediate feedback. |
| HQ killed EH locality | Mobile HQ killed EH fires locally, so server sends clients `set-hq-killed-eh`. | Preserve dedicated/JIP handling when touching HQ mobilize/repair/deploy. |
| `setVehicleInit` usage | Construction relies on legacy Arma 2 init broadcast patterns for client markers and artillery UI. | Avoid replacing without testing dedicated, hosted and JIP cases. |
| CoIn performance | CoIn uses camera/menu loops with `sleep 0.01` and rich nearest-object checks. | Keep new checks cached or server-side; avoid adding expensive per-frame scans to `coin_interface.sqf`. |

## Implementation Checklist

When changing construction:

1. Edit the Chernarus source mission first.
2. Identify whether the change is client preview, server authority, common config or generated tooling.
3. If adding a structure, update every relevant `Common/Config/Core_Structures/Structures_*.sqf` array in lockstep: logical label, classname, description, cost, time, script, distance and direction.
4. If adding a defense, update side defense configs and check repair-truck CoIn categories.
5. If adding a new server request, register it in `Common/Init/Init_PublicVariables.sqf` and document the PVF payload.
6. For authority changes, keep the existing client CoIn UX but make the server reject invalid payloads and send a clear message.
7. Run `Tools/LoadoutManager` after gameplay edits; remember the skip-list trap in [Tools and build workflow](Tools-And-Build-Workflow).
8. Update this page, [Feature status](Feature-Status-Register) and [`agent-context.json`](agent-context.json) when changing ownership or authority.

## Continue Reading

Previous: [Gameplay atlas](Gameplay-Systems-Atlas) | Next: [Factory and purchase systems](Factory-And-Purchase-Systems-Atlas)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
