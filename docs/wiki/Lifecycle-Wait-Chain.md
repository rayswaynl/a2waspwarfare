# Lifecycle Wait-Chain Reference

> Claude deep-dive page (source-cited). This is the canonical page for precise boot ordering, the machine-role truth table, JIP waits and the global-flag dependency graph that enforces init order. Use [Mission entrypoints and lifecycle](Mission-Entrypoints-And-Lifecycle) for the include graph, role dispatch and per-role init responsibility map.

All paths below are relative to the source mission root `Missions/[55-2hc]warfarev2_073v48co.chernarus/`.

## Why this matters

WFBE does **not** use the BIS Functions `CfgFunctions` auto-init system. There is no engine-managed `preInit`/`postInit` ordering. Instead, boot order is enforced entirely by hand-rolled `waitUntil {<flag>}` barriers on global variables. A script `execVM`'d before the flag it waits on is set will simply spin forever, silently hanging that machine's boot. Before reordering any init call, check this page.

## Machine-role truth table

Role is computed in `initJIPCompatible.sqf:52-56`. `isHeadLessClient` comes from `Headless/Functions/HC_IsHeadlessClient.sqf` (`!(hasInterface || isDedicated)`).

| Machine | `isServer` | `isDedicated` | `hasInterface` | `isHostedServer` | `isHeadLessClient` | Init branches run |
| --- | :---: | :---: | :---: | :---: | :---: | --- |
| Dedicated server | true | true | false | false | false | Server |
| Hosted (listen) server | true | false | true | true | false | Server **+** Client |
| Pure client | false | false | true | false | false | Client |
| Headless client (HC) | false | false | false | false | true | HC |
| Singleplayer | true | false | true | true | false | Server **+** Client |

`isHostedServer = !isMultiplayer || (isServer && !isDedicated)` (`initJIPCompatible.sqf:52`).

## Engine-driven entry order (every machine)

1. Engine parses `description.ext` → `#include "version.sqf"` (preprocessor `#define`s) + all `Rsc/*.hpp`, `Sounds/`, `Music/` includes.
2. Engine runs `init.sqf` (server-only: spawns `test/wasp_selftest.sqf`).
3. Engine runs `initJIPCompatible.sqf` — the **master bootstrap**, including on JIP clients.

Mission object init fields are also part of startup. In the Chernarus source mission, town logic objects call `Common\Init\Init_Town.sqf` from `mission.sqm`, while the `WF_Logic` object at `mission.sqm:3265` seeds town-mode lists and starts `Common\Init\Init_TownMode.sqf`. Treat `mission.sqm` as an init source when auditing town lifecycle, not just as map placement data.

> **Gotcha — `version.sqf` is generated and git-ignored.** It is `#include`d by `description.ext` and `initJIPCompatible.sqf` but is produced per-terrain by LoadoutManager (see [Tools and build workflow](Tools-And-Build-Workflow)) and listed in `.gitignore`. A fresh checkout will not compile until LoadoutManager has been run or a `version.sqf` is dropped in.

## Branch dispatch in `initJIPCompatible.sqf`

| Branch | Guard | Line |
| --- | --- | --- |
| Server | `isHostedServer \|\| isDedicated` → `ExecVM "Server/Init/Init_Server.sqf"` | `initJIPCompatible.sqf:218-220` |
| Client | `isHostedServer \|\| (!isHeadLessClient && !isDedicated)` → `execVM "Client/Init/Init_Client.sqf"` | `initJIPCompatible.sqf:224-233` |
| Headless | `isHeadLessClient` → `execVM "Headless/Init/Init_HC.sqf"` | `initJIPCompatible.sqf:237-238` |

The old WASP client-init block is commented out at `initJIPCompatible.sqf:241-245` (see [WASP overlay](WASP-Overlay)).

## Global-flag dependency graph

Each row: a flag, where it is **set**, and the `waitUntil` barriers it **unblocks**. Editing any producer line without its consumers (or vice-versa) risks a boot hang.

| Flag | Set at | Unblocks (consumer `waitUntil`) |
| --- | --- | --- |
| `VERSION_SET` | `Common/Init/Init_Version.sqf` | `initJIPCompatible.sqf:49` |
| `WFBE_Parameters_Ready` | `initJIPCompatible.sqf:212` | `Common/Init/Init_TownMode.sqf:3`, `Init_Town.sqf:18` |
| `townModeSet` | `Common/Init/Init_TownMode.sqf:21`, started by `mission.sqm:3265` | `Init_Towns.sqf:3`, `Init_Town.sqf:18` |
| `BIS_fnc_init` (engine) | engine | `Common/Init/Init_Common.sqf:205-206` |
| `WFBE_PRESENTSIDES` | `Common/Init/Init_Common.sqf:282` | client branch `initJIPCompatible.sqf:235`; `test/wasp_selftest.sqf` |
| `commonInitComplete` | `Common/Init/Init_Common.sqf:371` | `Init_Server.sqf:127`, `Init_Client.sqf:165`, `Init_Town.sqf:42`, `Init_Unit.sqf:18` |
| `townInit` | `Common/Init/Init_Towns.sqf:13` | `Init_Server.sqf:127`, client FSM launches, `Init_Client.sqf:596` |
| `serverInitComplete` | `Init_Server.sqf:117` | town model creation in `Init_Town.sqf:92` |
| `serverInitFull` | `Init_Server.sqf:507` | signals all per-side setup done (HC `sleep 20` is a crude proxy) |
| `clientInitComplete` | `Init_Client.sqf:957` | `Init_Unit.sqf:33`; then `CLIENT_INIT_READY` is `publicVariableServer`'d (`Init_Client.sqf:961-963`) |

### Ordered boot timeline (server)

`Init_Version` → `WFBE_Parameters_Ready` → `Init_Common` (sets `WFBE_PRESENTSIDES`, then `commonInitComplete`) → `Init_Towns` (`townInit`) → `Init_Server` (`serverInitComplete` early, `serverInitFull` after per-side loop) → launch `server_town.sqf`, `server_town_ai.sqf`, cleaners/restorers, `updateresources.sqf`, victory loop.

### Ordered boot timeline (client)

Block on `WFBE_PRESENTSIDES` + `wfbe_teams` → `Init_Client` compiles functions → block on `commonInitComplete` → set up HUD/modules/JIP handshake → block on `townInit` → launch map/marker/action FSMs → remove blackout (`Init_Client.sqf:775`) → `clientInitComplete` → broadcast `CLIENT_INIT_READY`.

### Headless client

`Init_HC.sqf` compiles the three delegation handlers (`Client_DelegateTownAI`, `Client_DelegateAI`, `Client_DelegateAIStaticDefence`) plus `Client_HandlePVF`, then **`sleep 20`** (a hard wait used in place of a `waitUntil {serverInitFull}` barrier) and notifies the server via `["RequestSpecial", ["connected-hc", player]]`. See [AI, headless and performance](AI-Headless-And-Performance) for what gets delegated.

Source-check note: `Init_HC.sqf:12` is the fixed sleep and `:15` sends the HC registration request. `serverInitFull` is not set until `Server/Init/Init_Server.sqf:507`, after `serverInitComplete` at `:117` and the `commonInitComplete && townInit` wait at `:127`.

## JIP specifics

There is no `didJIP` variable; JIP is handled implicitly because `initJIPCompatible.sqf` runs identically on joining clients, hitting the same barriers.

- **Time catch-up:** `initJIPCompatible.sqf:212` — `if (local player) then {skipTime (time/3600)}`; initial date applied from `WFBE_DAYNIGHT_DATE` if present (`:203`).
- **Spawn position:** `Init_Client.sqf:462` — `if (time < 30)` use start position, else (JIP) spawn at newest factory building.
- **Markers:** `Init_Client.sqf:732-736` — deferred re-init of town/camp markers from already-synced object variables after a short sleep.
- **State sync:** town `sideID`/`supplyValue`, side-logic commander/HQ/upgrades/teams, and team `wfbe_funds` are all written with `setVariable [..., true]` so the engine replicates them to JIP clients automatically (see the JIP section of [Networking and public variables](Networking-And-Public-Variables)).

Claude DR-37 reviewed the boot/JIP path as broadly correct: the `RequestJoin` handshake has a 30-second retry, time/date/team/client state is replicated through broadcast variables, and the apparent `while {true}` joins at `Init_Client.sqf:419` and `:444` are bounded handshake polls. The remaining robustness gap is the post-join serial wait chain in `Init_Client.sqf:367-502`: waits for `wfbe_structures`, side supply, `wfbe_commander`, radio HQ state, start position, HQ, deployment state and vote time have no timeout or log fallback. A single missed synced variable can leave a JIP client black-screened or stuck forever. Treat defensive timeouts here as a robustness improvement, not evidence that the normal JIP path is broken.

### Post-Join Wait Audit

Bernoulli's 2026-06-02 wait-chain audit split the client join gates into two classes: retrying handshake gates and replicated-variable waits with no terminal timeout.

| Gate | Producer | Timeout / retry state | Failure mode | Fix direction |
| --- | --- | --- | --- | --- |
| `RequestJoin` -> `WFBE_P_CANJOIN` | `Server/PVFunctions/RequestJoin.sqf` then client `HandleSpecial.sqf` writes `WFBE_P_CANJOIN`. | Polls and resends every 30 seconds; no hard terminal timeout. | Black screen / join pending forever if no answer; explicit lobby return if denied. | Keep retry but add hard timeout, log and fail-soft fallback. |
| Launch ACK -> `WFBE_P_HAS_CONNECTED_AT_LAUNCH_ACK` | `Server/Module/AntiStack/clientHasConnectedAtLaunch.sqf` then `Client/Module/AntiStack/hasConnectedAtLaunchACK.sqf`. | Polls and resends every 30 seconds; no hard terminal timeout. | Join remains pending if ACK is lost. | Add bounded retry budget and diagnostic log. |
| `wfbe_structures` / optional side supply | `Init_Server.sqf` seeds structures/supply; `Server_ChangeSideSupply.sqf` updates supply. | No timeout, no retry. | Client never reaches action/resources init. | Add timeout/log fallback around structure and supply sync. |
| `wfbe_commander` | Server init seeds side commander state; vote/disconnect handlers rebroadcast. | No timeout, no retry. | Commander FSM/UI state never starts correctly. | Guard with timeout and missing-broadcast diagnostic. |
| `wfbe_radio_hq` / `wfbe_radio_hq_id` | Server init creates radio HQ and topic ID. | No timeout, no retry. | HQ announcer identity/radio wiring stalls. | Add sync check and log. |
| Spawn location: `wfbe_startpos`, else `wfbe_hq` + `wfbe_structures` | Server init plus HQ construction/kill/repair paths. | No timeout, no retry. | Spawn position never resolves or resolves poorly. | Fail soft if HQ/structures are absent. |
| `wfbe_hq_deployed` and nested `wfbe_hq` | Server init and HQ construction/kill/repair paths. | No timeout, no retry. | CoIn/HQ event-handler setup can block; JIP client may miss HQ killed handler. | Timeout and skip/retry only the dependent setup instead of stalling all client boot. |
| `townInit` | `Common/Init/Init_Towns.sqf`. | No timeout, no retry. | Town, marker and action FSMs never launch. | Log a town-init stall before launching client FSM bundle. |
| `wfbe_votetime` | Server init and vote countdown. | No timeout, no retry. | Vote menu does not open when vote state should exist. | Treat as optional/lazy-polled with timeout and log. |

## Known ordering hazards

- **Debug-only economy override:** `initJIPCompatible.sqf:151-162` raises starting funds/supply and other test parameters only inside `if (WF_Debug)`. Confirm `WF_Debug` state before comparing economy behavior against mission parameters.
- **Server-only code inside Common:** `Init_Common.sqf:303-308` runs an `if (isServer)` town-group load from the *common* path. Functionally correct but architecturally surprising.
- **Mission object init can look invisible in SQF-only scans:** town setup begins from `mission.sqm` object `init` fields. Audit `mission.sqm` together with `Init_Town*.sqf` before changing town startup, town-mode filters, town count assumptions or generated mission propagation.
- **Duplicate compiles in `Init_Server`:** several functions are compiled twice (e.g. `WFBE_SE_FNC_PlayerObjectsList`, `WFBE_CO_FNC_LogGameEnd`); harmless (second overwrites first) but wasteful.
- **`gameOver` vs `WFBE_GameOver` vs `WFBE_gameover`:** SQF identifiers are case-insensitive, so `WFBE_gameover == WFBE_GameOver`; the lowercase-`gameOver` is a separate variable also set at boot. No bug, but easy to misread.

## Continue Reading

Previous: [Mission lifecycle](Mission-Entrypoints-And-Lifecycle) | Next: [Source inventory](Source-Inventory)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
