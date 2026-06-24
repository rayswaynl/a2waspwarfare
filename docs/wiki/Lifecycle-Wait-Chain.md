# Lifecycle Wait-Chain Reference

> Claude deep-dive page (source-cited). This is the canonical page for precise boot ordering, the machine-role truth table, JIP waits and the global-flag dependency graph that enforces init order. Use [Mission entrypoints and lifecycle](Mission-Entrypoints-And-Lifecycle) for the include graph, role dispatch and per-role init responsibility map.

All paths below are relative to the source mission root `Missions/[55-2hc]warfarev2_073v48co.chernarus/`. Unless another ref is named, line refs are from docs branch `docs/developer-wiki-index` `HEAD@55cb55e2170f`; the 2026-06-24 entrypoint refresh found targeted diffs from earlier docs anchor `05664f17` through `HEAD` empty for the checked lifecycle paths. [Mission entrypoints and lifecycle](Mission-Entrypoints-And-Lifecycle#source-scope) owns the current checkpoint, checked path list and branch refs; use that source-scope note before turning these Chernarus line refs into branch-specific claims.

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
2. Current tracked source has no root `init.sqf`; `rg --files` finds only nested feature init files such as `WASP/baserep/init.sqf`, and [WASP overlay](WASP-Overlay) records the old `test/wasp_selftest.sqf` description as a documentation error.
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
| `VERSION_SET` | `Common/Init/Init_Version.sqf:9,17` | `initJIPCompatible.sqf:49` |
| `WFBE_Parameters_Ready` | `initJIPCompatible.sqf:212` | `Common/Init/Init_TownMode.sqf:3`, `Init_Town.sqf:18` |
| `townModeSet` | `Common/Init/Init_TownMode.sqf:21`, started by `mission.sqm:3265` | `Init_Towns.sqf:3`, `Init_Town.sqf:18` |
| `BIS_fnc_init` (engine) | engine | `Common/Init/Init_Common.sqf:205-206` |
| `WFBE_PRESENTSIDES` | `Common/Init/Init_Common.sqf:282` | client branch `initJIPCompatible.sqf:225`; no live self-test consumer exists in current tracked source |
| `commonInitComplete` | `Common/Init/Init_Common.sqf:371` | `Init_Server.sqf:127`, `Init_Client.sqf:165`, `Init_Town.sqf:42`, `Init_Unit.sqf:18` |
| `townInit` | `Common/Init/Init_Towns.sqf:13` | `Init_Server.sqf:127`, client FSM launches, `Init_Client.sqf:596` |
| `serverInitComplete` | `Init_Server.sqf:117` | town model creation in `Init_Town.sqf:92` |
| `serverInitFull` | `Init_Server.sqf:507` | signals all per-side setup done (HC `sleep 20` is a crude proxy) |
| `clientInitComplete` | `Init_Client.sqf:956` | `Init_Unit.sqf:33`; then `CLIENT_INIT_READY` is set and `publicVariableServer`'d (`Init_Client.sqf:960-962`) |

Current stable/B74.1 line-drift for the key boot barriers is `WFBE_Parameters_Ready` at `initJIPCompatible.sqf:250`, `commonInitComplete` at `Common/Init/Init_Common.sqf:427`, `serverInitComplete` at `Server/Init/Init_Server.sqf:156`, `serverInitFull` at `:824` and `clientInitComplete` at `Client/Init/Init_Client.sqf:1213`. Current B74.2 keeps maintained Vanilla stable-shaped and line-drifts source Chernarus to `serverInitFull` `:837` and `clientInitComplete` `:1240`.

### Ordered boot timeline (server)

`Init_Version` → `WFBE_Parameters_Ready` → `Init_Common` (sets `WFBE_PRESENTSIDES`, then `commonInitComplete`) → `Init_Towns` (`townInit`) → `Init_Server` (`serverInitComplete` early, `serverInitFull` after per-side loop) → launch `server_town.sqf`, `server_town_ai.sqf`, cleaners/restorers, `updateresources.sqf`, victory loop.

### Ordered boot timeline (client)

Block on `WFBE_PRESENTSIDES` + `wfbe_teams` → `Init_Client` compiles functions → block on `commonInitComplete` → set up HUD/modules/JIP handshake → block on `townInit` → launch map/marker/action FSMs → remove blackout (`Init_Client.sqf:773-774`) → `clientInitComplete` → broadcast `CLIENT_INIT_READY`.

### Headless client

Docs/source `Init_HC.sqf` compiles `Client_DelegateTownAI`, `Client_DelegateAI`, `Client_DelegateAIStaticDefence` plus `Client_HandlePVF`, then **`sleep 20`** and notifies the server via `["RequestSpecial", ["connected-hc", player]]`. Current stable/B74-shaped refs add `Client_CleanupDelegatedTownAI`, then run the newer HC reseat/deadspawn/persistent-watcher bootstrap before the same registration notify. See [AI, headless and performance](AI-Headless-And-Performance) for the runtime source router and [Headless delegation and failover](Headless-Delegation-And-Failover-Playbook) for DR-21/DR-42 patch policy.

Source-check note: docs/source `Init_HC.sqf:12` is the fixed sleep and `:15` sends the HC registration request. Current stable/B74.1 and current B74.2 use `Init_HC.sqf:14` for the fixed sleep, `:28` for `waitUntil {!isNull player}`, `:35-101` for bounded reseat polling and `:122` / `:129` for `connected-hc` sends. Neither branch shape waits explicitly for `serverInitFull`.

Page ownership note: this lifecycle page owns HC boot timing and wait-chain risk only. HC work tracking, update-back choices, disconnect policy and failover design intentionally live in [Headless delegation and failover](Headless-Delegation-And-Failover-Playbook).

## JIP specifics

There is no `didJIP` variable; JIP is handled implicitly because `initJIPCompatible.sqf` runs identically on joining clients, hitting the same barriers.

- **Time catch-up:** `initJIPCompatible.sqf:202` — `if (local player) then {skipTime (time/3600)}` when the accelerated day/night cycle is disabled; `WFBE_DAYNIGHT_DATE` is applied at `:193-194` when the accelerated cycle is enabled.
- **Spawn position:** `Init_Client.sqf:462` — `if (time < 30)` use start position, else (JIP) spawn at newest factory building.
- **Markers:** `Init_Client.sqf:732-736` — deferred re-init of town/camp markers from already-synced object variables after a short sleep.
- **State sync:** town `sideID`/`supplyValue`, side-logic commander/HQ/upgrades/teams, and team `wfbe_funds` are all written with `setVariable [..., true]` so the engine replicates them to JIP clients automatically (see the JIP section of [Networking and public variables](Networking-And-Public-Variables)).

Claude DR-37 reviewed the boot/JIP path as broadly correct: the `RequestJoin` handshake has a 30-second retry, time/date/team/client state is replicated through broadcast variables, and the apparent `while {true}` joins at `Init_Client.sqf:419` and `:444` are bounded handshake polls. The remaining robustness gap is the post-join serial wait chain in `Init_Client.sqf:367-502`: waits for `wfbe_structures`, side supply, `wfbe_commander`, radio HQ state, start position, HQ, deployment state and vote time have no timeout or log fallback. A single missed synced variable can leave a JIP client black-screened or stuck forever. Treat defensive timeouts here as a robustness improvement, not evidence that the normal JIP path is broken.

### Post-Join Wait Audit

Gap closure note (2026-06-03): this table is the source-backed wait-chain audit promised by the old `gap-wait-chain-timeouts` machine record. It is intentionally scoped to boot/JIP gates rather than ordinary gameplay loops. Rows distinguish retrying handshakes from timeout-less replicated-variable waits and cite both the consumer gate and the producer where practical.

Bernoulli's 2026-06-02 wait-chain audit split the client join gates into two classes: retrying handshake gates and replicated-variable waits with no terminal timeout.

| Gate | Producer | Consumer / source anchors | Timeout / retry state | Failure mode | Fix direction |
| --- | --- | --- | --- | --- | --- |
| `RequestJoin` -> `WFBE_P_CANJOIN` | `RequestJoin.sqf` sends `HandleSpecial ["join-answer", ...]`; client `HandleSpecial.sqf` writes `WFBE_P_CANJOIN`. | `Init_Client.sqf:416-431`, `RequestJoin.sqf:75-79`, `HandleSpecial.sqf:24-28`. | Polls and resends every 30 seconds; no hard terminal timeout. | Black screen / join pending forever if no answer; explicit lobby return if denied. | Keep retry but add hard timeout, log and fail-soft fallback. |
| Launch ACK -> `WFBE_P_HAS_CONNECTED_AT_LAUNCH_ACK` | Server PVEH records launch side and replies to the player owner; client PVEH stores the ACK variable. | `Init_Client.sqf:441-456`, `clientHasConnectedAtLaunch.sqf:1-15`, `hasConnectedAtLaunchACK.sqf:1-6`. | Polls and resends every 30 seconds; no hard terminal timeout. | Join remains pending if ACK is lost. | Add bounded retry budget and diagnostic log. |
| `wfbe_structures` / optional side supply | Server seeds `wfbe_structures` and initial side supply; side-supply PVEH later updates `wfbe_supply_<side>`. | `Init_Client.sqf:367-371`, `Init_Server.sqf:363,386`, `Server_ChangeSideSupply.sqf:19-21,43-45`. | No timeout, no retry. | Client never reaches action/resources init. | Add timeout/log fallback around structure and supply sync. |
| `wfbe_commander` | Server init seeds side commander state; vote/reassignment/disconnect handlers later mutate it. | `Init_Client.sqf:384`, `Init_Server.sqf:356`, `RequestNewCommander.sqf:12-14`, `Server_OnPlayerDisconnected.sqf:136-146`. | No timeout, no retry. | Commander FSM/UI state never starts correctly. | Guard with timeout and missing-broadcast diagnostic. |
| `wfbe_radio_hq` / `wfbe_radio_hq_id` | Server init creates side radio HQ objects and topic IDs. | `Init_Client.sqf:394-405`, `Init_Server.sqf:401-413`. | No timeout, no retry. | HQ announcer identity/radio wiring stalls. | Add sync check and log. |
| Spawn location: `wfbe_startpos`, else `wfbe_hq` + `wfbe_structures` | Server init seeds start position, HQ and structures; later construction/kill/repair paths mutate HQ state. | `Init_Client.sqf:461-486`, `Init_Server.sqf:357,361,363`. | No timeout, no retry. | Spawn position never resolves or resolves poorly. | Fail soft if HQ/structures are absent. |
| `wfbe_hq_deployed` and nested `wfbe_hq` | Server init seeds deployment/HQ; HQ construction, death and repair paths later update them. | `Init_Client.sqf:490-506`, `Init_Server.sqf:357-358`, `Construction_HQSite.sqf:79-91`, `Server_MHQRepair.sqf:41-43`. | No timeout, no retry. | CoIn/HQ event-handler setup can block; JIP client may miss HQ killed handler. | Timeout and skip/retry only the dependent setup instead of stalling all client boot. |
| `townInit` | `Common/Init/Init_Towns.sqf` sets `townInit = true`; client waits before JIP town/FSM setup. | `Init_Client.sqf:595`, `Init_Towns.sqf:13`. | No timeout, no retry. | Town, marker and action FSMs never launch. | Log a town-init stall before launching client FSM bundle. |
| `wfbe_votetime` | Server init seeds vote time from mission constants; vote code later updates countdown state. | `Init_Client.sqf:787-789`, `Init_Server.sqf:370`. | No timeout, no retry. | Vote menu does not open when vote state should exist. | Treat as optional/lazy-polled with timeout and log. |

## Known ordering hazards

- **Always-on economy override (`WFBE_C_AB_AMPLE_ECON`):** `initJIPCompatible.sqf:151-162` forces starting funds to 30000 and supply to 12800 per side whenever `WFBE_C_AB_AMPLE_ECON > 0` (default 1, i.e. active on every run). This block is NOT gated on `WF_Debug`. A separate `if (WF_Debug)` block at `:189-200` further overrides funds/supply to 999999 and sets gameplay parameters (upgrades clearance, town occupation, AI delegation, town starting mode, EASA). Set `WFBE_C_AB_AMPLE_ECON=0` to disable the always-on override; confirm both variable states before comparing economy behavior against mission parameters.
- **Server-only code inside Common:** `Init_Common.sqf:303-308` runs an `if (isServer)` town-group load from the *common* path. Functionally correct but architecturally surprising.
- **Mission object init can look invisible in SQF-only scans:** town setup begins from `mission.sqm` object `init` fields. Audit `mission.sqm` together with `Init_Town*.sqf` before changing town startup, town-mode filters, town count assumptions or generated mission propagation.
- **Duplicate compiles in `Init_Server`:** several functions are compiled twice (e.g. `WFBE_SE_FNC_PlayerObjectsList`, `WFBE_CO_FNC_LogGameEnd`); harmless (second overwrites first) but wasteful.
- **`gameOver` vs `WFBE_GameOver` vs `WFBE_gameover`:** SQF identifiers are case-insensitive, so `WFBE_gameover == WFBE_GameOver`; the lowercase-`gameOver` is a separate variable also set at boot. No bug, but easy to misread.

## Continue Reading

Previous: [Mission lifecycle](Mission-Entrypoints-And-Lifecycle) | Next: [Source inventory](Source-Inventory)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
