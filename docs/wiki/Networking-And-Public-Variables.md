# Networking And Public Variables

Arma 2 OA networking here is built around public variables, public-variable event handlers and wrapper functions that dispatch named PVF commands.

For external engine grounding, see [External Arma 2 OA reference index](External-Arma-2-OA-Reference-Index). In short: `publicVariable` broadcasts and is JIP-persistent; `publicVariableServer` and `publicVariableClient` target one direction; `addPublicVariableEventHandler` reacts to broadcasts but does not provide a trusted sender identity. This is why DR-1 (PVF command-string validation) and DR-41 (direct-PV server authority) are separate hardening layers.

## Central PVF Registration

`Common/Init/Init_PublicVariables.sqf` creates two command lists: 13 server-bound commands and 14 client-bound commands. Use [Public variable channel index](Public-Variable-Channel-Index#1-registered-pvf-commands) as the canonical inventory; it includes purpose notes, notable DR findings and source anchors for every registered `WFBE_PVF_*` command.

Each command is compiled into either `SRVFNC...` or `CLTFNC...`, and `WFBE_PVF_<Command>` receives an event handler that passes payloads to `Server_HandlePVF` or `Client_HandlePVF`.

## Network Helper Layer

- `Common_SendToServer`: sends a server PVF; uses optimized `publicVariableServer` outside vanilla mode.
- `Common_SendToClients`: broadcasts client PVF to all clients.
- `Common_SendToClient`: targets one client where supported.

These wrappers are preferred over hand-coded public variable dispatch for new features.

## Direct Public Variables

Some systems use explicit public-variable channels outside the generic PVF list. Do not maintain a second channel table here; use [Public variable channel index](Public-Variable-Channel-Index#2-direct-publicvariable-channels-own-event-handlers) as the canonical inventory for BattlEye whitelist work and direct-PV authority hardening.

High-risk examples to keep visible on this networking page:

- **Attack wave:** `ATTACK_WAVE_INIT` is broadcast with `publicVariableServer` from `Common/Functions/Common_AttackWaveActivate.sqf` and is the confirmed DR-41 direct-PV authority issue.
- **MASH markers:** the intended `WFBE_CL_MASH_MARKER_CREATED` -> `WFBE_SE_MASH_MARKER_SENT` relay is not currently a working channel. The client receiver compile is commented and the send trigger is absent, leaving an orphaned server PVEH. See [Deep-review findings](Deep-Review-Findings) DR-34.
- **AFK kick:** `kickAFK` is intentionally caught by BattlEye filters because `serverCommand` is unavailable; [External integrations](External-Integrations) and [Deep-review findings](Deep-Review-Findings) DR-30 cover the current filter posture.

## Safety Notes

- Keep payloads small and structured; Arma 2 public-variable traffic can be expensive.
- Prefer server authority for state changes. Client scripts should request, not mutate, team/base/economy state directly.
- When adding a PVF command, update both the registration list and the target `Client/PVFunctions` or `Server/PVFunctions` file.
- Hosted-server paths often call the handler locally in addition to broadcasting. Preserve those branches when modernizing code.

## Authority Surfaces To Audit Together

DR-1 closes the most dangerous PVF issue, but it does not by itself make gameplay requests authoritative. Two server-facing surfaces need separate hardening:

- **PVF command surface.** ICBM uses `RequestSpecial`: `Client/Module/Nuke/nukeincoming.sqf:23` reaches `Server/Functions/Server_HandleSpecial.sqf:97-111`. Keep payload/impact/fix details in [Deep-review findings](Deep-Review-Findings) DR-27; the networking takeaway is that legitimate PVF commands still need per-handler authority validation after the DR-1 dispatch lookup is fixed.
- **Direct public-variable surface.** Attack wave does not use PVF. `Common/Functions/Common_AttackWaveActivate.sqf:6-8` writes `ATTACK_WAVE_INIT = [_supply, _side]` and sends it with `publicVariableServer`; `Server/Functions/Server_AttackWave.sqf:1-27` trusts that supplied side/supply to calculate `ATTACK_WAVE_PRICE_MODIFIER` and broadcast `ATTACK_WAVE_DETAILS`. Server-side validation should derive current side supply and authority from trusted state, not from the payload.

Treat these as sibling work items when refactoring economy authority. A validated PVF lookup prevents arbitrary function-string execution; it does not validate that the requested game action is allowed.

## PVF dispatch internals (Claude deep-dive, source-cited)

The registry above tells you *which* commands exist; this section documents *how a message is actually routed and executed* once it arrives. Paths are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`.

### One PV variable per command — no numeric multiplexing

Registration (`Common/Init/Init_PublicVariables.sqf:43-51`) creates one PV name per command (`WFBE_PVF_RequestJoin`, `WFBE_PVF_TownCaptured`, …), each with its own `addPublicVariableEventHandler`. There is **no** single multiplexed channel with a numeric protocol ID. The handlers are gated by role: client handlers register under `if (!isServer || local player)`; server handlers under `if (isServer)`.

### Index-0 routing on the client side

`Client/Functions/Client_HandlePVF.sqf` inspects element 0 of the payload to decide whether *this* client should run the function:

- `nil` → run on **all** clients.
- a `SIDE` value → run only if `sideJoined == destination` (`:14`).
- a `STRING` (player UID) → run only if `getPlayerUID player == destination` (`:15`).

The actual function is resolved from element 1 (`"CLTFNC<Command>"`) and executed by the generic PVF dispatcher. The current generic dispatch trust/perf issue is tracked in [PVF dispatch playbook](PVF-Dispatch-Implementation-Playbook) and [Deep-review findings](Deep-Review-Findings) DR-1/DR-38.

### The four send wrappers map to four engine primitives

| Wrapper (compiled name `WFBE_CO_FNC_…`) | Direction | Engine primitive | Element 0 |
| --- | --- | --- | --- |
| `Common_SendToServer` / `…Optimized` → `SendToServer` | client→server | `publicVariable` (vanilla) / `publicVariableServer` (OA/CO) | n/a |
| `Common_SendToClients` → `SendToClients` | server→clients | `publicVariable` | destination (`nil`/SIDE/UID) |
| `Common_SendToClient` → `SendToClient` | server→one client | `publicVariableClient` to `owner _player` | player object (rewritten to UID for the client filter) |

### Two layers of multiplexing

A second routing layer lives *inside* two god-functions, dispatched by a runtime string tag:

- `Client/PVFunctions/HandleSpecial.sqf:8-37` — `switch (_request)` over 20+ cases (`join-answer`, `attack-wave`, `commander-vote`, `endgame`, …). Server side mirrors this in `Server/Functions/Server_HandleSpecial.sqf`.
- `Client/PVFunctions/LocalizeMessage.sqf:10-113` — `switch` over message keys (`Teamkill`, `FundsTransfer`, `AttackModeActivated`, …).

When tracing a feature, a single registered command (`WFBE_PVF_HandleSpecial`) can carry many heterogeneous messages — grep for the string tag, not just the command name.

### Gotchas

- **UID-targeted broadcast is wasteful.** `SendToClients` with a UID at element 0 (e.g. `Server/PVFunctions/RequestOnUnitKilled.sqf:86` awarding bounty) still `publicVariable`s to *every* client; each non-matching client deserializes and discards it in `Client_HandlePVF.sqf:15`. For true unicast prefer `SendToClient` (`publicVariableClient`).
- **All handlers `Spawn` (not `Call`).** Messages run in fresh scheduled threads with no ordering guarantee; two rapid messages mutating the same state (e.g. back-to-back `ChangeScore`) can race.
- **PVF dispatch boundary.** Both generic handlers still compile the registered handler-name string per message. Keep source proof and fix shape in [PVF dispatch playbook](PVF-Dispatch-Implementation-Playbook) and DR-1/DR-38.
- **Per-side copy-paste channels.** Some bare-PV channels are duplicated per side rather than parameterized, e.g. `wfbe_supply_temp_west` / `wfbe_supply_temp_east` each get their own event handler in `Server/Functions/Server_ChangeSideSupply.sqf` (no resistance handler).

### Security: generic PVF dispatch boundary

`Server_HandlePVF.sqf` / `Client_HandlePVF.sqf` are the DR-1 generic dispatch trust boundary. Keep the source proof and behavior-preserving patch shape in [PVF dispatch playbook](PVF-Dispatch-Implementation-Playbook) and [Deep-review findings](Deep-Review-Findings) DR-1/DR-38; this page only tracks the boundary and the residual: validated dispatch does not authorize legitimate handler payloads or direct `publicVariable` channels.
