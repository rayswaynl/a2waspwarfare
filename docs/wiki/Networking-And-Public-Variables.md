# Networking And Public Variables

Arma 2 OA networking here is built around:

- `publicVariable`, `publicVariableServer`, `publicVariableClient`
- `addPublicVariableEventHandler`
- `missionNamespace setVariable`/`getVariable`
- PVF registration and dispatch wrappers

Use this page before adding or changing any client/server channel.

For engine grounding, use [Arma 2 OA external reference guide](Arma-2-OA-External-Reference-Guide), then [External Arma 2 OA reference index](External-Arma-2-OA-Reference-Index) and [Arma 2 OA compatibility audit](Arma-2-OA-Compatibility-Audit) for command behavior caveats.

## Source-backed model

In this codebase, three boundaries matter:

1. **Transport boundary** (`publicVariable*`) — moves a variable/value.
2. **Dispatch boundary** (`WFBE_PVF_*`) — chooses which handler runs.
3. **Authority boundary** (handler code) — decides whether to mutate state.

This split is why DR-1 (dispatch trust), DR-38 (dispatch performance/race), DR-41 (attack wave), DR-27 (ICBM), and DR-44 (supply temp channels) are separate lanes.

## Primitive comparison in this repo

### `publicVariable`

- Full fan-out to all peers.
- Last-value replication semantics when a variable is public and named in mission namespace.
- JIP gets the latest known value, not guaranteed event history.

### `publicVariableServer`

- Client- or hosted-client-initiated send toward server.
- Transport-only in OA context; handler trust is still a separate problem.

### `publicVariableClient`

- Targeted send to one client (`owner _player`) in this source.
- OA docs treat this as not persistent/JIP by default.

### `addPublicVariableEventHandler`

- Triggers logic when a variable arrives.
- It does not prove who sent the payload or that the sender had gameplay authority.

### mission namespace

- `missionNamespace setVariable [name, value, true]` is state replication, not command transport.
- `missionNamespace getVariable` is retrieval from shared runtime state (not a network trust claim by itself).
- Use this for durable state (scores/supply/day-night/HQ), then route UI with explicit commands.

## Central PVF registration

`Common/Init/Init_PublicVariables.sqf` creates:

- 13 server-bound command entries.
- 14 client-bound command entries.
- two dispatch binders (`WFBE_SE_FNC_HandlePVF`, `WFBE_CL_FNC_HandlePVF`).

Each command becomes a separate `WFBE_PVF_<Command>` variable with its own event handler; there is no single numeric multiplexing channel. Compiled handler references are stored in mission namespace as `SRVFNC*` / `CLTFNC*`.

## Mission namespace and helper wrappers

| Wrapper | Direction | Engine primitive | Engine behavior | Typical use |
| --- | --- | --- | --- | --- |
| `Common_SendToServer` | client -> server | `publicVariable` / hosted local dispatch | One wrapper name, no dedicated `isServer` transport call | Standard safe baseline for request channels in mixed/locality environments |
| `Common_SendToServerOptimized` | client -> server | `publicVariableServer` in supported paths | Uses OA direct server API where possible | Performance-oriented request lane |
| `Common_SendToClients` | server -> clients | `publicVariable` | Optional target filter (nil/SIDE/UID) applied in `Client_HandlePVF.sqf` | Broad/conditional broadcasts and state sync |
| `Common_SendToClient` | server -> one client | `owner _player publicVariableClient` | Writes player UID in payload to preserve filters | One-client replies and direct UX updates |

## Direct publicVariable channels are separate

`Public-Variable-Channel-Index.md` owns the canonical direct channel table with sender/receiver/payload/JIP-risk and source references.

Use this map when you are tempted to add a new `publicVariable` call:
- Is the receiver local/client-specific?
- Is the payload directly mutable game state?
- Is the channel recoverable for late joiners?
- Can sender identity be proven in server logic?
- Does retry or dedupe matter?

## Remote-style function dispatch pattern (not Arma 3 remoteExec)

Two layers exist:

1. **First dispatch layer:** one `WFBE_PVF_<Command>` selects one handler entry.
2. **Second in-handler layer:** some client handlers switch internally (`HandleSpecial`, `LocalizeMessage`) and treat payload key as local action type.

This pattern means a trusted handler can still execute many side effects from one transport route. Treat each case as an independent authority boundary.

## `onPlayerConnected` / `onPlayerDisconnected` and authority context

Lifecycle handlers in this repo:

- `Server/Functions/Server_OnPlayerConnected.sqf`
- `Server/Functions/Server_OnPlayerDisconnected.sqf`

Typical roles in live flows:

- initialize player state and side ownership tracking;
- initialize JIP fallback paths and retry handshakes;
- publish or clear session-owned replicated values.

For audit, classify each player lifecycle variable as:

- `publicVariable`-transported event,
- mission namespace state,
- or server-owned cached bookkeeping not yet mirrored to clients.

## Replication and JIP risk map (concise)

- `publicVariable` for `setVariable true` state variables: late joiners can recover the latest value.
- pure `publicVariableClient`: targeted ephemeral event, not state/JIP.
- pure `addPublicVariableEventHandler` request channels: event-only unless state is republished.
- command paths with pull responses (for example, supply value request/response): robust for late-join when implemented as query+response.

## Safe conventions for future networking edits

1. Keep mutation flows in `publicVariableServer`/PVF request channels unless explicit state needs broad fan-out.
2. Use `missionNamespace` state + explicit re-broadcast for durable shared state.
3. Treat every direct channel as untrusted input; validate side, ownership, object locality, and payload shape server-side.
4. Include sender/receiver and JIP behavior in any changelist and in `Public-Variable-Channel-Index.md`.
5. Prefer `publicVariableClient` only for one-client responses; avoid using it as primary state replication.
6. For multiplexer handlers (`HandleSpecial`, `LocalizeMessage`) add idempotency for repeated packets.
7. Preserve hosted-listen behavior (`isServer`/`local`) when touching helper wrappers.
8. Do not introduce Arma 3-only APIs (`remoteExec`, `remoteExecCall`, `CfgRemoteExec`, `remoteExecutedOwner`, `isRemoteExecuted`) in this OA branch.

## Unclear ownership / likely risk patterns

- `ATTACK_WAVE_INIT` direct payload trust remains live: not in PVF dispatch and still trusts client-side price/side parameters.
- `wfbe_supply_temp_*` direct channels remain direct client-writable mutation attempts with arithmetic and auth gaps.
- MASH marker relay path has sender/receiver inconsistencies and appears effectively dormant.
- `Client_HandlePVF.sqf` destination filtering still runs after broadcast, not before send.
- `Spawn` dispatch remains non-deterministic in packet ordering for rapid-fire events.

## Replication checklist (when auditing an issue)

1. **Name the primitive first** (who uses transport, who reads state).
2. **Separate event vs state.**
3. **Prove authority in handler** (requester side, funds, role, range, ownership).
4. **Prove JIP behavior** (latest-value state, pull-response, or event-only).
5. **Check handler idempotency** (`Spawn`, duplicate packets, and multi-key switches).

## Safety notes

- `publicVariableClient` is for targeted, one-client response flow; treat as non-persistent.
- `publicVariable` with `setVariable true` can carry state snapshots and can be recovered by JIP.
- PVF dispatch validation and handler validation are separate; closing one gap does not close the other.
- Multiple wrapper paths must preserve hosted/listen behavior (`if (local)` and local dispatch branches in handlers).

## Source and follow-up indexes

- Command inventory and direct channel map: [Public Variable Channel Index](Public-Variable-Channel-Index)
- Deep findings and status lanes: [Deep-review findings](Deep-Review-Findings), [Feature-Status-Register](Feature-Status-Register)
- Implementation sequence and validation gates: [PVF Dispatch Implementation Playbook](PVF-Dispatch-Implementation-Playbook), [Server-Authority-Migration-Map](Server-Authority-Migration-Map)

## PVF dispatch internals (source-cited deep dive)

### One PV variable per command

There is no shared numeric multiplexing channel. Each registered command owns its own `WFBE_PVF_*` name and handler branch.

### Destination filter semantics

Client side destination is in `_requestDestination`:

- `nil` -> all clients
- `SIDE` -> side-only
- `STRING` -> uid-only

### `Client_HandlePVF` / `Server_HandlePVF` execution shape

Both dispatchers compile the sender-shape string before running the resolved handler. The command lookup issue (DR-1) is addressed separately in the dispatch playbook, but no dispatch fix currently validates the semantic correctness of mutable commands.

## Ongoing lanes

- `PVF-Dispatch-Implementation-Playbook` for DR-1/DR-38 boundary hardening.
- `Feature-Status-Register` for live patch backlog and open authority lanes.
