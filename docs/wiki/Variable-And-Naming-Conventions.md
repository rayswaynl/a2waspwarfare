# Variable and Naming Conventions (WFBE_*)

> Claude-owned reference (2026-06-02). The WASP/WFBE (Benny Warfare BE) codebase uses systematic prefixes for globals, functions, and per-object variables. They are consistent across the mission but were never collected in one place, so every agent session re-derived them from context. This is the canonical glossary. Paths are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`. Arma 2 OA 1.64.

## Prefix table

| Prefix | Meaning | Scope / machine | Representative source |
| --- | --- | --- | --- |
| `WFBE_C_*` | **Config constant / parameter** (gameplay tunables, gates) | Common; set once at boot, read everywhere | `Common/Init/Init_CommonConstants.sqf:166` (`WFBE_C_ECONOMY_SUPPLY_MAX_TEAM_LIMIT = 50000`); module gates like `WFBE_C_MODULE_WFBE_*`, `WFBE_C_ANTISTACK_ENABLED` |
| `WFBE_CO_FNC_*` | **Common/shared function name** (usually runs on any machine, but the prefix is not a strict compile-owner guarantee) | Mostly compiled in `Common/Init/Init_Common.sqf`; a few shared names are compiled earlier or from server init | `WFBE_CO_FNC_LogContent` is defined early at `initJIPCompatible.sqf:37`; most helper names are in `Common/Init/Init_Common.sqf:94-160`; server-owned shared names include `WFBE_CO_FNC_InitAFKkickHandler` / `WFBE_CO_FNC_LogGameEnd` (`Server/Init/Init_Server.sqf:63-64,89`) and HC delegation helpers (`:99-100`) |
| `WFBE_SE_FNC_*` | **Server function** (server-only logic) | Server; compiled in `Server/Init/Init_Server.sqf` | `Server/Init/Init_Server.sqf:53` (`WFBE_SE_FNC_HandlePVF = … Server_HandlePVF.sqf`) |
| `WFBE_CL_FNC_*` | **Client function** (client-local logic) | Client + HC (HC reuses the client receive path); compiled in `Client/Init/Init_Client.sqf` | `Client/Init/Init_Client.sqf:110` (`WFBE_CL_FNC_HandlePVF = … Client_HandlePVF.sqf`) |
| `SRVFNC<Name>` | **Pre-compiled server PVFunction handler** (one global per registered command) | Server; built at boot from `Server/PVFunctions/<Name>.sqf` | `Common/Init/Init_PublicVariables.sqf:49` (`SRVFNC%1 = compile preprocessFileLineNumbers 'Server\PVFunctions\%1.sqf'`) |
| `CLTFNC<Name>` | **Pre-compiled client PVFunction handler** | Client; built at boot from `Client/PVFunctions/<Name>.sqf` | `Common/Init/Init_PublicVariables.sqf:44` (`CLTFNC%1 = compile preprocessFileLineNumbers 'Client\PVFunctions\%1.sqf'`) |
| `WFBE_PVF_<Name>` | **Registered publicVariable channel name** for a PVF command; the `addPublicVariableEventHandler` key | network (server- and client-bound) | `Common/Init/Init_PublicVariables.sqf:45,50` (`Format['WFBE_PVF_%1',_x] addPublicVariableEventHandler {…}`) |
| `wfbe_*` (lowercase) | **Replicated object/group state key** set via `setVariable` (often broadcast with the `true` global flag -> JIP-persistent) | attached to side logic, town/building objects and team/group objects depending on key | side logic examples: `wfbe_commander` and `wfbe_structures` at `Server/Init/Init_Server.sqf:356,363`; group funds: `wfbe_funds` at `Server/Init/Init_Server.sqf:474` and `Common/Functions/Common_ChangeTeamFunds.sqf:8` |
| `WFBE_HEADLESSCLIENTS_ID`, `WFBE_PRESENTSIDES`, `WFBE_GameOver`, … | **Top-level runtime globals** (no functional prefix) | mixed; see usage | scattered; e.g. `WFBE_PRESENTSIDES` gates client init (`initJIPCompatible.sqf:225`) |

## Key implications

- **`WFBE_C_MODULE_WFBE_<X>` gates a module** — most `Client/Module/*` and `Common/Module/*` subsystems are config-gated by one of these (e.g. `WFBE_C_MODULE_WFBE_EASA`, `WFBE_C_MODULE_WFBE_FLARES`, `WFBE_C_MODULE_WFBE_ICBM`, `WFBE_C_MODULE_WFBE_IRSMOKE`). See the [Modules atlas](Modules-Atlas).
- **Short legacy globals and newer `WFBE_CO_FNC_*` names can point at the same helper file** — `Init_Common.sqf:24-63` compiles old names such as `GetSideID` / `GetTeamFunds`, while `:94-160` compiles newer prefixed names such as `WFBE_CO_FNC_GetSideID` / `WFBE_CO_FNC_GetTeamFunds`. Treat this as naming-era overlap and maintenance debt, not two independent implementations unless the target file differs.
- **`WFBE_CO_FNC_*` is mostly common, not exclusively `Init_Common`** — `WFBE_CO_FNC_LogContent` must exist before common init starts, so `initJIPCompatible.sqf:37` compiles it early; server init also compiles a few `WFBE_CO_FNC_*` names for AFK kick, game-end logging and headless delegation. Use the actual compile site as authority.
- **`SRVFNC*`/`CLTFNC*` are pre-compiled once at boot**, but the dispatchers `Server_HandlePVF.sqf`/`Client_HandlePVF.sqf` `Call Compile` the sender-provided command string per message instead of using these pre-compiled globals — that is both the DR-1 RCE and a per-message recompile (DR-38). See [Networking](Networking-And-Public-Variables).
- **`wfbe_*` with `setVariable [..., true]` is the replication mechanism** — the "true" makes the value global and JIP-synced; this is also why the economy ledger is *replicated client state* rather than a server source of truth (the economy-authority class, DR-6/14/16/22/23/27/28/41/44).
- **Not every replicated key uses the `wfbe_` prefix** — factory queues use the legacy key `"queu"` on building objects (`Client/Functions/Client_BuildUnit.sqf:169-172`, `Server/Functions/Server_BuyUnit.sqf:21-24`). Do not use that key as an example of the lowercase `wfbe_*` convention.
- **SQF identifiers are case-insensitive, but `setVariable`/`getVariable` keys are case-SENSITIVE** — the source of DR-18 (`lastSupplyMissionRun` vs `LastSupplyMissionRun`). Watch casing on `wfbe_*` keys specifically.

## Continue Reading

PV channels: [Public variable channel index](Public-Variable-Channel-Index) | Dispatch: [Networking](Networking-And-Public-Variables) | Map: [Home](Home)
