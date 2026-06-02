# Networking And Public Variables

Arma 2 OA networking here is built around public variables, public-variable event handlers and wrapper functions that dispatch named PVF commands.

## Central PVF Registration

`Common/Init/Init_PublicVariables.sqf` creates two command lists:

Server PVF commands:

- `RequestVehicleLock`
- `RequestOnUnitKilled`
- `RequestChangeScore`
- `RequestCommanderVote`
- `RequestNewCommander`
- `RequestStructure`
- `RequestDefense`
- `RequestJoin`
- `RequestMHQRepair`
- `RequestSpecial`
- `RequestTeamUpdate`
- `RequestUpgrade`
- `RequestAutoWallConstructinChange`

Client PVF commands:

- `AllCampsCaptured`
- `AwardBounty`
- `AwardBountyPlayer`
- `CampCaptured`
- `ChangeScore`
- `HandleSpecial`
- `LocalizeMessage`
- `SetTask`
- `SetVehicleLock`
- `TownCaptured`
- `SetMHQLock`
- `Available`
- `RequestBaseArea`
- `HandleParatrooperMarkerCreation`
- `NukeIncoming`

Each command is compiled into either `SRVFNC...` or `CLTFNC...`, and `WFBE_PVF_<Command>` receives an event handler that passes payloads to `Server_HandlePVF` or `Client_HandlePVF`.

## Network Helper Layer

- `Common_SendToServer`: sends a server PVF; uses optimized `publicVariableServer` outside vanilla mode.
- `Common_SendToClients`: broadcasts client PVF to all clients.
- `Common_SendToClient`: targets one client where supported.

These wrappers are preferred over hand-coded public variable dispatch for new features.

## Direct Public Variables

Some systems use explicit public-variable channels outside the generic PVF list. The canonical inventory is [Public variable channel index](Public-Variable-Channel-Index), including registered `WFBE_PVF_*` commands, direct channels, source anchors and notable findings.

Why this matters: direct channels such as `ATTACK_WAVE_INIT`, supply mission PVs, side-supply temp variables, MASH marker channels, HQ marker/state broadcasts, AntiStack compensation, server FPS and AFK kick are not automatically covered by a future PVF dispatcher fix. Treat them as separate review targets when hardening the network layer.

### Direct PV Hardening Order

1. Fix PVF dispatcher command resolution first (DR-1), because that closes arbitrary command-string execution.
2. Harden registered high-impact handlers next: construction, upgrades, score, vehicle lock, commander/team changes.
3. Review the direct channels above separately, because they will not be protected by a `WFBE_PVF_*` allow-list.
4. Design BattlEye `publicvariable.txt` from both lists: registered `WFBE_PVF_*` channels plus explicit direct channels such as `kickAFK`, supply mission PVs, day/night, HQ markers, attack waves and AntiStack compensation. Use [External integrations](External-Integrations) for the canonical shipped BattlEye posture.

Replay/JIP rule of thumb: late players receive retained object/global state and the next heartbeat, not a replay of old publicVariable events. For revived event-only channels such as MASH marker relays, add a server-held list and explicit JIP re-send plan rather than assuming event replay.

## Safety Notes

- Keep payloads small and structured; Arma 2 public-variable traffic can be expensive.
- Prefer server authority for state changes. Client scripts should request, not mutate, team/base/economy state directly.
- When adding a PVF command, update both the registration list and the target `Client/PVFunctions` or `Server/PVFunctions` file.
- Hosted-server paths often call the handler locally in addition to broadcasting. Preserve those branches when modernizing code.

## PVF Dispatch Internals

Claude independently deep-read the dispatch path and confirmed these runtime details. Paths are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`.

### One PV Variable Per Command

`Common/Init/Init_PublicVariables.sqf:43-51` creates one public-variable name per command, such as `WFBE_PVF_RequestJoin` and `WFBE_PVF_TownCaptured`, each with its own `addPublicVariableEventHandler`. This is not one numeric multiplexed protocol channel. Client handlers register under `if (!isServer || local player)`; server handlers register under `if (isServer)`.

### Client-Side Index-0 Routing

`Client/Functions/Client_HandlePVF.sqf` uses payload element 0 as the destination filter:

| Element 0 | Client behavior |
| --- | --- |
| `nil` | Run on all clients. |
| `SIDE` | Run only if `sideJoined == destination`. |
| `STRING` | Run only if `getPlayerUID player == destination`. |

The actual function name comes from element 1 (`CLTFNC<Command>`) and is executed with `_parameters Spawn (Call Compile _script)`. `Server/Functions/Server_HandlePVF.sqf` is simpler: it resolves `SRVFNC<Command>` and spawns it with no destination filtering.

### Wrapper To Engine Primitive Map

| Wrapper | Direction | Engine primitive | Destination handling |
| --- | --- | --- | --- |
| `Common_SendToServer` / optimized variant | client -> server | `publicVariable` or `publicVariableServer` | Server PVF receives command payload. |
| `Common_SendToClients` | server -> clients | `publicVariable` | Payload element 0 is `nil`, side, or UID. |
| `Common_SendToClient` | server -> one client | `publicVariableClient` to `owner _player` | Player object is rewritten to UID for the client filter. |

### Second-Level Multiplexers

Some registered commands are broad routers:

- `Client/PVFunctions/HandleSpecial.sqf` switches over tags such as `join-answer`, `attack-wave`, `commander-vote` and `endgame`.
- `Client/PVFunctions/LocalizeMessage.sqf` switches over message keys such as `Teamkill`, `FundsTransfer` and `AttackModeActivated`.

When tracing one feature, grep the string tag as well as the PVF command name.

### Registered Client PVF Runtime Matrix

This is the server-to-client counterpart to the [registered server handler matrix](Server-Authority-Migration-Map#registered-server-pvf-handler-authority-matrix). It answers "what happens on the receiving client?" after `Client_HandlePVF` destination filtering.

Registration source: `Common/Init/Init_PublicVariables.sqf:25-40` registers 15 client-bound commands, while `:45-46` compiles each `CLTFNC*` handler and adds client PVEHs.

| Handler | Runtime effect | JIP / authority note |
| --- | --- | --- |
| `AllCampsCaptured` | Recolors all camp markers for the relevant old/new sides (`AllCampsCaptured.sqf:17-21`). | Visual/event-only. Late joiners need marker refresh, not old PV replay. |
| `AwardBounty` / `AwardBountyPlayer` | Computes a local bounty message and calls `ChangePlayerFunds` (`AwardBounty.sqf:44-49`; `AwardBountyPlayer.sqf:20-21`). | Client-local money effect; server kill authority should decide eligibility before sending. |
| `CampCaptured` | Updates camp marker color and, for nearby friendly captures, awards local funds and sends `RequestChangeScore` (`CampCaptured.sqf:22-40`). | Not just visual. Capture reward migration must move funds/score authority server-side. |
| `ChangeScore` | Replaces local score for the payload unit (`ChangeScore.sqf:7-8`). | Mirror/update of server score decision; do not use as authority source. |
| `HandleSpecial` | Router for actions, commander vote, HC delegation, endgame, HQ status, ICBM display, join answer, UAV reveal, upgrade/building notices, HQ killed EH, auto-wall and attack-wave state (`HandleSpecial.sqf:9-37`). | Mixed router. For JIP, durable state must be re-sent or polled; event-only tags are not replayed automatically. |
| `LocalizeMessage` | Router for chat/title text and several local money effects such as `Teamkill`, `SecondaryAward` and `HeadHunterReceiveBounty` (`LocalizeMessage.sqf:49,53,67,116-118`). | Treat money-changing messages as gameplay effects, not harmless text. |
| `SetTask` | Creates/replaces `comTask`, sets destination and spawns a local completion timer (`SetTask.sqf:1-31`). | Visible dormant/partial system: command menu `SetTask` sends are currently commented, so smoke before revival. |
| `SetVehicleLock` / `SetMHQLock` | Applies local vehicle lock or adds MHQ lock/unlock actions (`SetVehicleLock.sqf:1`; `SetMHQLock.sqf:1-3`). | Reflects server lock state; local action setup depends on deploy status. |
| `TownCaptured` | Recolors town marker, shows capture message, awards local funds and sends `RequestChangeScore` for eligible players/commanders (`TownCaptured.sqf:23-80`). | Not just visual. Town reward authority belongs with server-side capture reward migration. |
| `Available` | Shows a hint with available items (`Available.sqf:1`). | UI notification only. |
| `RequestBaseArea` | Moves a base-area object, sets `avail`/`side`, and appends it to `wfbe_basearea` (`RequestBaseArea.sqf:1-4`). | Client-bound despite the name; multiplayer-sensitive base/HQ state edge. |
| `HandleParatrooperMarkerCreation` | Waits for `clientInitComplete`, optionally equips east paratroopers with NVGs, and spawns a local marker update with PerformanceAudit logging (`HandleParatrooperMarkerCreation.sqf:9-45`). | Source/Vanilla registration is propagated; Arma smoke pending. Transient marker, no replay unless owner asks for historical drops. |
| `NukeIncoming` | Plays the air-raid sound (`NukeIncoming.sqf:1-7`). | Presentation-only pair to the ICBM authority path. |

### Client Router Tag Triage

`HandleSpecial` and `LocalizeMessage` deserve tag-level review when a feature is touched:

| Router | Tag family | Why it matters |
| --- | --- | --- |
| `HandleSpecial` | `join-answer`, `commander-vote*`, `new-commander-assigned`, `endgame`, `hq-setstatus`, `attack-wave` | Updates local control flow and durable local variables. JIP/retry behavior must be checked per tag. |
| `HandleSpecial` | `delegate-townai`, `delegate-ai`, `delegate-ai-static-defence`, `set-hq-killed-eh` | Starts locality-sensitive AI/HQ handoffs and event handlers. HC/disconnect work should smoke these tags. |
| `HandleSpecial` | `upgrade-started`, `upgrade-complete`, `building-started`, `icbm-display`, `uav-reveal` | User feedback with side effects: upgrade completion refreshes local artillery vehicles; ICBM display waits on object death and spawns FX. |
| `LocalizeMessage` | `Teamkill`, `SecondaryAward`, `HeadHunterReceiveBounty` | Message tags can mutate player funds locally. Treat them as part of the economy authority surface. |
| `LocalizeMessage` | `Teamstack` | Waits until `WFBE_BLUFOR_SCORE_JOIN` and `WFBE_OPFOR_SCORE_JOIN` exist before formatting the message. This relies on the join-answer path setting those variables. |

### Gotchas

- UID-targeted `SendToClients` still broadcasts to every client and lets non-matching clients discard locally. Use `SendToClient` for true unicast when possible.
- PVF handlers use `Spawn`, so rapid messages that mutate shared state have no strict ordering guarantee.
- Both dispatchers use `Call Compile` on the generated function-name string per dispatch. DR-38 notes this is redundant as well as unsafe: `Init_PublicVariables.sqf` already precompiles `SRVFNC*` / `CLTFNC*` globals at init, so a validated `missionNamespace getVariable` lookup removes per-message recompilation and closes the DR-1 RCE with the same change.
- Some bare PV channels are copied per side, such as `wfbe_supply_temp_west` and `wfbe_supply_temp_east`; there is no resistance-side handler in that path.
- A real BattlEye PV filter must include direct non-PVF channels as well as `WFBE_PVF_*`; shipped filter evidence is tracked in [External integrations](External-Integrations).
- The master/Chernarus branch documented here does not ship PR #1 supply-helicopter source; it has the older truck supply mission path plus direct support/supply/ICBM channels. Treat supply-heli mechanics as PR-only until the branch is merged.

### Security: the `Call Compile` trust boundary

`Server_HandlePVF.sqf` / `Client_HandlePVF.sqf` run `Call Compile` on the function-name string taken from the **value a remote machine broadcast** (`select 0` / `select 1`), with no check that it names a registered command. Validate the command string against the known `SRVFNC*`/`CLTFNC*` set before compiling, and add a real BattlEye PV filter as defense in depth. Full dispatcher analysis: [Deep-review findings](Deep-Review-Findings) DR-1. Shipped BattlEye evidence and production-owner caveats: [External integrations](External-Integrations).

### Residual Authority Risks After Dispatch Hardening

Replacing `Call Compile` with mission-namespace lookup closes arbitrary code execution from forged function-name strings, but it does not make registered commands authoritative. The full post-dispatch queue is now in [Server authority migration map](Server-Authority-Migration-Map#registered-server-pvf-handler-authority-matrix). The table below keeps only the highest-risk examples:

| Handler | Trust issue | Evidence |
| --- | --- | --- |
| `RequestChangeScore` | Client payload can overwrite score and broadcast the result. | `Server/PVFunctions/RequestChangeScore.sqf:3-13` |
| `RequestStructure` / `RequestDefense` | Server side mostly checks class existence, then trusts side, position, direction and manning. | `Server/PVFunctions/RequestStructure.sqf:3-21`, `RequestDefense.sqf:2-10` |
| `RequestUpgrade` | Directly spawns upgrade processing; handler itself does not show commander/funds validation. | `Server/PVFunctions/RequestUpgrade.sqf:5`, `Server/Functions/Server_ProcessUpgrade.sqf:40-43` |
| `RequestVehicleLock` | Locks the payload vehicle without visible owner/side/range check. | `Server/PVFunctions/RequestVehicleLock.sqf:3-8` |
| `RequestTeamUpdate` | Accepts array or side and mutates group behavior/combat/formation/speed. | `Server/PVFunctions/RequestTeamUpdate.sqf:3-26` |
| `RequestSpecial` | Broad router for paratroops, support, ICBM, camp repair, teamleader update and HC registration. Claude DR-27 found the `"ICBM"` branch can be forged to server-spawn `NukeDammage` at a client-chosen position with no upgrade/commander/funds validation. | `Client/Module/Nuke/nukeincoming.sqf:23`, `Server/PVFunctions/RequestSpecial.sqf:1`, `Server/Functions/Server_HandleSpecial.sqf:97-112` |

### Highest-Priority Registered Command: ICBM / Nuke

DR-27 makes `RequestSpecial` the highest-priority registered-command hardening target discovered so far. The Tactical menu does client-side ICBM gating and the client sends `["RequestSpecial", ["ICBM", side, baseObj, cruiseObj, team]]`; the server's `HandleSpecial` `"ICBM"` case trusts the payload and spawns nuke damage from it. A forged PV therefore becomes a server-applied map-wide kill. Fixes belong server-side in the `"ICBM"` branch, paired with BattlEye restrictions around `RequestSpecial`.

### Direct Channel Authority: Attack Waves

McClintock's 2026-06-02 PV scout found one direct-channel authority issue outside the generic PVF dispatcher, and Claude DR-41 source-verified it as high risk:

- `Client/FSM/updateclient.sqf:240` gates the action with a client-side `GetSideSupply >= 25000` condition.
- `Common/Functions/Common_AttackWaveActivate.sqf:3-8` sends `ATTACK_WAVE_INIT = [_supply, _side]` via `publicVariableServer`.
- `Server/Functions/Server_AttackWave.sqf:5-15` takes both values directly from the payload and computes `ATTACK_WAVE_PRICE_MODIFIER`.
- `WFBE_C_ECONOMY_SUPPLY_MAX_TEAM_LIMIT = 50000` at `Common/Init/Init_CommonConstants.sqf:166`, so a forged `_supply >= 70000` can drive the side-wide unit price modifier to zero; larger values can make it negative.
- The repo's `BattlEyeFilter/publicvariable.txt` does not cover `ATTACK_WAVE_INIT`.

A PVF lookup hardening patch does not touch this path. The forgery class has two surfaces: registered PVF commands and direct `publicVariableServer` channels. The attack-wave fix should treat `ATTACK_WAVE_INIT` as a request, re-derive real side supply and permissions server-side, deduct any intended cost server-side, clamp the resulting modifier and ignore client-supplied economic fields. Implementation detail is captured in [Attack-wave authority playbook](Attack-Wave-Authority-Playbook).

## Continue Reading

Previous: [Function/module index](Function-And-Module-Index) | Next: [Gameplay atlas](Gameplay-Systems-Atlas)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
