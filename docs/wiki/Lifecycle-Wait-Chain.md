# Lifecycle Wait-Chain Reference

> Claude deep-dive page (source-cited). Complements [Mission entrypoints and lifecycle](Mission-Entrypoints-And-Lifecycle) with the precise boot ordering, the machine-role truth table, and the global-flag dependency graph that enforces init order.

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

> **Gotcha — `version.sqf` is generated and git-ignored.** It is `#include`d by `description.ext` and `initJIPCompatible.sqf` but is produced per-terrain by LoadoutManager (see [Tools and build workflow](Tools-And-Build-Workflow)) and listed in `.gitignore`. A fresh checkout will not compile until LoadoutManager has been run or a `version.sqf` is dropped in.

## Branch dispatch in `initJIPCompatible.sqf`

| Branch | Guard | Line |
| --- | --- | --- |
| Server | `isHostedServer \|\| isDedicated` → `ExecVM "Server/Init/Init_Server.sqf"` | ~228-230 |
| Client | `isHostedServer \|\| (!isHeadLessClient && !isDedicated)` → `execVM "Client/Init/Init_Client.sqf"` | ~234-244 |
| Headless | `isHeadLessClient` → `execVM "Headless/Init/Init_HC.sqf"` | ~247-249 |

The old WASP client-init block is commented out at `initJIPCompatible.sqf:251-255` (see [WASP overlay](WASP-Overlay)).

## Global-flag dependency graph

Each row: a flag, where it is **set**, and the `waitUntil` barriers it **unblocks**. Editing any producer line without its consumers (or vice-versa) risks a boot hang.

| Flag | Set at | Unblocks (consumer `waitUntil`) |
| --- | --- | --- |
| `VERSION_SET` | `Common/Init/Init_Version.sqf` | `initJIPCompatible.sqf:49` |
| `WFBE_Parameters_Ready` | `initJIPCompatible.sqf:222` | `Common/Init/Init_TownMode.sqf:18` |
| `townModeSet` | `Common/Init/Init_TownMode.sqf:20` | `Init_Towns.sqf:3`, `Init_Town.sqf:18` |
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

## JIP specifics

There is no `didJIP` variable; JIP is handled implicitly because `initJIPCompatible.sqf` runs identically on joining clients, hitting the same barriers.

- **Time catch-up:** `initJIPCompatible.sqf:212` — `if (local player) then {skipTime (time/3600)}`; initial date applied from `WFBE_DAYNIGHT_DATE` if present (`:203`).
- **Spawn position:** `Init_Client.sqf:462` — `if (time < 30)` use start position, else (JIP) spawn at newest factory building.
- **Markers:** `Init_Client.sqf:732-736` — deferred re-init of town/camp markers from already-synced object variables after a short sleep.
- **State sync:** town `sideID`/`supplyValue`, side-logic commander/HQ/upgrades/teams, and team `wfbe_funds` are all written with `setVariable [..., true]` so the engine replicates them to JIP clients automatically (see the JIP section of [Networking and public variables](Networking-And-Public-Variables)).

## Known ordering hazards

- **Debug-only economy override:** `initJIPCompatible.sqf:151-162` raises starting funds/supply and other test parameters (to 999999) **only inside `if (WF_Debug)`** — it is build-gated, not unconditional. Confirm `WF_Debug` state (set by the generated `version.sqf` per build config) before comparing economy behaviour against mission parameters. *(Corrected 2026-06-01 after Codex flagged an over-statement in the round-1 draft; an earlier feat-branch variant used a different, ungated form.)*
- **Server-only code inside Common:** `Init_Common.sqf:303-308` runs an `if (isServer)` town-group load from the *common* path. Functionally correct but architecturally surprising.
- **Duplicate compiles in `Init_Server`:** several functions are compiled twice (e.g. `WFBE_SE_FNC_PlayerObjectsList`, `WFBE_CO_FNC_LogGameEnd`); harmless (second overwrites first) but wasteful.
- **`gameOver` vs `WFBE_GameOver` vs `WFBE_gameover`:** SQF identifiers are case-insensitive, so `WFBE_gameover == WFBE_GameOver`; the lowercase-`gameOver` is a separate variable also set at boot. No bug, but easy to misread.
- **Timeout-less post-join waits:** after common/town init, `Client/Init/Init_Client.sqf` still waits indefinitely for replicated side-logic and namespace values such as `wfbe_structures` (`:367`), side supply (`:369`), commander (`:384`), HQ radio (`:394-397`), JIP HQ/start state (`:463-467`, `:490`, `:502`) and vote time (`:788`). If one producer stops publishing a value, a JIP client can hang silently. Add diagnostic timeouts or fallback paths before reordering these producers. See DR-37.
