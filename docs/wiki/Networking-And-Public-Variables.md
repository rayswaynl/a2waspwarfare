# Networking And Public Variables

Arma 2 OA networking here is built around public variables, public-variable event handlers and wrapper functions that dispatch named PVF commands.

## How To Use This Page

This page is the architecture gateway for network transport and trust boundaries. Use it to understand how public-variable traffic moves, then follow the owner page before editing a specific channel.

| Need | Start here |
| --- | --- |
| Complete registered/direct channel inventory or BattlEye filter inputs | [Public variable channel index](Public-Variable-Channel-Index) |
| PVF dispatcher allow-list patch shape and branch matrix for DR-1/DR-38 | [PVF dispatch implementation](PVF-Dispatch-Implementation-Playbook#current-branch-matrix) |
| Registered server PVF authority, sender authentication and DR-55 follow-up | [Server authority migration map](Server-Authority-Migration-Map#registered-server-pvf-handler-authority-matrix) |
| Direct channel fixes for `SEND_MESSAGE`, attack waves or side supply | [Public variable channel index](Public-Variable-Channel-Index#send_message-direct-compile-branch-matrix), [Attack-wave authority playbook](Attack-Wave-Authority-Playbook), [Economy authority first cut](Economy-Authority-First-Cut) |
| Client-side PVF effects, JIP behavior and user-visible network results | [Registered Client PVF Runtime Matrix](#registered-client-pvf-runtime-matrix) below and [Client UI systems](Client-UI-Systems-Atlas) |
| Release/smoke readiness and open patch queues | [Feature status register](Feature-Status-Register), [Source fix propagation queue](Source-Fix-Propagation-Queue), [Testing workflow](Testing-Debugging-And-Release-Workflow) |

## Current Branch Scope

Unless a row names another ref, source anchors below use current docs/source head `docs/developer-wiki-index` `4d4610f1`; checked Chernarus network/PVF paths are unchanged from `ade4d356`. The older `4277a2ad`, `1e16527b`, `8701aacc` and `59deb306` source-scope passes remain provenance, but the current spot-check anchors are: registered PVF lists and PVEHs at `Common/Init/Init_PublicVariables.sqf:9-21,26-40,46,51`, generic dispatch-time compile at `Server/Functions/Server_HandlePVF.sqf:14` and `Client/Functions/Client_HandlePVF.sqf:22`, direct `SEND_MESSAGE` registration at `Client/FSM/updateclient.sqf:12`, receiver compile at `Client/Functions/Client_onEventHandler_SEND_MESSAGE.sqf:27` and helper compile/broadcast at `Common/Functions/Common_SendMessage.sqf:26,37-38`.

2026-06-22 current-stable/current-B69/adjacent-B74 PVF dispatch refresh: `origin/master@0139a346`, `origin/claude/b69@8d465fce` and `origin/claude/b74-aicom-spend@b23f557f` Chernarus plus maintained Vanilla no longer use dispatch-time `Call Compile` in `Server_HandlePVF.sqf` or `Client_HandlePVF.sqf`. They resolve `_code = missionNamespace getVariable _script` and spawn only `CODE` at server `:14-15` and client `:32-33`. Chernarus blame is `7d60b02b4`; maintained Vanilla propagation blame is `9b49883cb`; the checked B69..B74 generic PVF dispatcher/init delta is empty. `Init_PublicVariables.sqf:55-61` still precompiles/registers handlers without a registered-handler allowlist or warning log, and `:56,61` still forwards only the PVEH value tuple, so this is a partial dispatcher hardening, not full PVF/network authority closure.

2026-06-22 `SEND_MESSAGE` addendum: docs/source `HEAD@40c477be` is unchanged from `16247fc8f` for checked `SEND_MESSAGE` paths, and current B69 `origin/claude/b69@8d465fce` matches current stable for this direct channel. Both maintained roots still register `SEND_MESSAGE` at `Client/FSM/updateclient.sqf:12`, compile receiver text at `Client_onEventHandler_SEND_MESSAGE.sqf:27`, and compile/broadcast helper text at `Common_SendMessage.sqf:26,37-38`; checked B69 diffs from `0a1ccb4d` and `b8530477` to current head are empty for those paths.

| Ref | Network source shape | Practical route |
| --- | --- | --- |
| Docs/source `HEAD@86ab85b9d0b1` (PVF paths unchanged from `4d4610f1` / `ade4d356`) | Chernarus keeps the older dispatcher line shape (`Server_HandlePVF.sqf:14`, `Client_HandlePVF.sqf:22`) and value-only PVF registration at `Init_PublicVariables.sqf:46,51`; commander `SetTask` sends remain commented at `GUI_Menu_Command.sqf:335,337,343` while registering the client `SetTask` handler at `Common/Init/Init_PublicVariables.sqf:33`. | Use this page for architecture, then use [Public variable channel index](Public-Variable-Channel-Index) for inventory and [PVF dispatch implementation](PVF-Dispatch-Implementation-Playbook#current-branch-matrix) before making patch-status claims. |
| Current stable `origin/master@0139a346` | Both maintained roots now replace registered PVF dispatch-time compile with `_code = missionNamespace getVariable _script` plus `typeName _code == "CODE"` before spawn (`Server_HandlePVF.sqf:14-15`, `Client_HandlePVF.sqf:32-33`). No maintained-root dispatcher still matched `Call Compile _script`, but no `PVF_ALLOWED` allowlist symbol was found, and PVEHs still pass only the value tuple at `Init_PublicVariables.sqf:56,61`. Direct `SEND_MESSAGE` still compiles payload text at `Client_onEventHandler_SEND_MESSAGE.sqf:27` and helper text at `Common_SendMessage.sqf:26`, with registration at `updateclient.sqf:12`; the targeted `cf2a6d6a..0139a346` diff does not touch those checked receiver/helper paths. Stable also carries branch-local `RequestEnqueue` / `RequestDequeue` at `Init_PublicVariables.sqf:22-23` and targeted Objective Ping sends at `GUI_Menu_Command.sqf:336,344` with `SetTask` registration at `:40`. | Treat DR-1/DR-38 compile removal as source-present but partial on current stable: finish explicit allowlisting/logging and smoke. Keep DR-55 sender authentication and DR-46 direct `SEND_MESSAGE` hardening open; current origin advertises no `release/*` heads on 2026-06-22, and historical release commit `a96fdda2` remains old-shape for PVF dispatcher lookup while carrying live Objective Ping sends. |
| Current B69 `origin/claude/b69@8d465fce` and adjacent B74 `origin/claude/b74-aicom-spend@b23f557f` | Match current stable's registered PVF init/dispatcher shape in both maintained roots: value-only PVEHs at `Init_PublicVariables.sqf:56,61`, server namespace/CODE dispatch at `Server_HandlePVF.sqf:14-15`, and client namespace/CODE dispatch at `Client_HandlePVF.sqf:32-33`. The B69 `0a1ccb4d..8d465fce` checked PVF-path delta changes only `Client/PVFunctions/HandleSpecial.sqf`, adding default-off `aicom-team-merge` at `:57` with `WFBE_C_AICOM_HC_MERGE_ENABLE` gate at `:59` in both maintained roots; the checked B69..B74 generic PVF dispatcher/init delta is empty. Direct `SEND_MESSAGE` remains unchanged from old B69/provenance refs: `updateclient.sqf:12`, `Client_onEventHandler_SEND_MESSAGE.sqf:27` and `Common_SendMessage.sqf:26,37-38` still carry the direct-channel compile route. For Objective Ping, B69 and B74 match current stable's targeted `SetTask` sends at `GUI_Menu_Command.sqf:336,344` and `Init_PublicVariables.sqf:40` registration. | Treat B69/B74 as branch-only evidence: dispatcher lookup and Objective Ping match current stable, but sender authentication, registered-handler allowlist/logging, Objective Ping smoke and DR-46 `SEND_MESSAGE` direct compile remain open. The client special tag is a separate AICOM/HC branch feature, not a networking authority closure. |
| Historical release commit `a96fdda2` | The 2026-06-21 recheck confirmed `Spawn (Call Compile _script)` in server dispatcher `Server_HandlePVF.sqf:14` and HC-filtered client dispatcher `Client_HandlePVF.sqf:32`, plus direct `SEND_MESSAGE` compile at receiver/helper lines `:27` and `:26`. | Keep dispatcher and direct-channel hardening open for this historical release proof; do not describe it as a current release branch while `origin` exposes no `release/*` heads. |
| Miksuu `b8389e748243`, `origin/perf/quick-wins@0076040f` and historical `c20ce1534be0` | Miksuu and perf were rechecked for PVF dispatcher shape and still use dispatch-time `Call Compile`; checked roots keep the direct `SEND_MESSAGE` compile route and leave commander `SetTask` sends commented at `GUI_Menu_Command.sqf:335,337,343` while registering `SetTask` at `Init_PublicVariables.sqf:33`. Miksuu and historical `c20ce1534be0` omit paratrooper marker PVF registration in both maintained roots; perf registers it only in Chernarus. None of these refs carries the current-stable queue PVFs. | Recheck exact branch/root lines before merge wording; do not import stable/B69/B74 queue, paratrooper or Objective Ping status into these refs. |

This page summarizes architecture and trust boundaries. The channel index owns full inventory, the PVF playbook owns dispatcher branch status, and the server-authority map owns per-handler hardening status.

## Central PVF Registration

This gateway no longer keeps a copied command inventory. Use the canonical registry matrix in [Public variable channel index](Public-Variable-Channel-Index#current-branch-registry-matrix) before citing command counts, branch splits, `RequestEnqueue` / `RequestDequeue`, or paratrooper-registration status.

| Question | Canonical owner |
| --- | --- |
| Which `WFBE_PVF_*` commands exist on a branch/root? | [Public variable channel index](Public-Variable-Channel-Index#current-branch-registry-matrix) |
| How should dispatch-time `Call Compile` be patched? | [PVF dispatch implementation](PVF-Dispatch-Implementation-Playbook#current-branch-matrix) |
| Which registered server handlers still trust payloads after dispatcher hardening? | [Server authority migration map](Server-Authority-Migration-Map#registered-server-pvf-handler-authority-matrix) |
| What do client-bound handlers do after destination filtering? | [Registered Client PVF Runtime Matrix](#registered-client-pvf-runtime-matrix) below |

Code-reading shorthand: `Common/Init/Init_PublicVariables.sqf` compiles registered command files into `SRVFNC...` / `CLTFNC...` globals, registers one `WFBE_PVF_<Command>` event handler per command, and hands payloads to `Server_HandlePVF` or `Client_HandlePVF`.

## Network Helper Layer

- `Common_SendToServer`: sends a server PVF; uses optimized `publicVariableServer` outside vanilla mode.
- `Common_SendToClients`: broadcasts client PVF to all clients.
- `Common_SendToClient`: targets one client where supported.

These wrappers are preferred over hand-coded public variable dispatch for new features.

Transport is not authority. `publicVariable`, `publicVariableServer` and `publicVariableClient` only decide how a value moves; they do not prove who was allowed to request the effect. Treat client-authored request/state packets such as `CLIENT_INIT_READY`, `WFBE_C_PLAYER_OBJECT`, `WFBE_CLIENT_HAS_CONNECTED_AT_LAUNCH`, `WFBE_Client_PV_IsSupplyMissionActiveInTown`, `WFBE_Client_PV_SupplyMissionStarted`, `REQUEST_SUPPLY_VALUE`, `SUPPLY_VALUE_REQUESTED`, `MARKER_CREATION`, `SERVER_FPS_GUI` and `WFBE_VAR_SERVER_FPS` as transport channels whose receiver still needs explicit trust, replay and timeout rules.

## Direct Public Variables

Some systems use explicit public-variable channels outside the generic PVF list. The canonical inventory is [Public variable channel index](Public-Variable-Channel-Index), including registered `WFBE_PVF_*` commands, direct channels, source anchors and notable findings.

Why this matters: direct channels such as `ATTACK_WAVE_INIT`, `ATTACK_WAVE_DETAILS`, `SEND_MESSAGE`, supply mission PVs, side-supply temp variables, side-supply mirror state (`wfbe_supply_WEST` / `wfbe_supply_EAST`), MASH marker channels, request/reply state channels, HQ marker/state broadcasts, AntiStack compensation, server FPS and AFK kick are not automatically covered by a future PVF dispatcher fix. Treat them as separate review targets when hardening the network layer. DR-46 proves this is not only theoretical: `SEND_MESSAGE` compiles direct-PV payload text on receiving clients, and its common helper has the same local compile branch before broadcast.

### Direct PV Hardening Order

1. Fix PVF dispatcher command resolution first where the target branch still has dispatch-time compile (DR-1); on current stable, finish the missing registered allowlist/logging before calling the lane closed.
2. Harden registered high-impact handlers next: construction, upgrades, score, vehicle lock, commander/team changes.
3. Review the direct channels above separately, because they will not be protected by a `WFBE_PVF_*` allow-list. Start with DR-46 `SEND_MESSAGE` (branch/root matrix: [Public variable channel index](Public-Variable-Channel-Index#send_message-direct-compile-branch-matrix)), DR-41/`ATTACK_WAVE_INIT`, `ATTACK_WAVE_DETAILS` and DR-44 side-supply temp channels.
4. Design BattlEye `publicvariable.txt` from both lists: registered `WFBE_PVF_*` channels plus explicit direct channels such as `kickAFK`, supply mission PVs, day/night, HQ markers, attack waves and AntiStack compensation. Use [External integrations](External-Integrations) for the canonical shipped BattlEye posture.

Replay/JIP rule of thumb: late players receive retained object/global state and the next heartbeat, not a replay of old publicVariable events. For revived event-only channels such as MASH marker relays, add a server-held list and explicit JIP re-send plan rather than assuming event replay.

## Safety Notes

- Keep payloads small and structured; Arma 2 public-variable traffic can be expensive.
- Prefer server authority for state changes. Client scripts should request, not mutate, team/base/economy state directly.
- When adding a PVF command, update both the registration list and the target `Client/PVFunctions` or `Server/PVFunctions` file.
- Hosted-server paths often call the handler locally in addition to broadcasting. Preserve those branches when modernizing code.

## PVF Dispatch Internals

Claude independently deep-read the dispatch path. Keep this gateway focused on reader orientation; detailed branch matrices and patch shapes live on the owner pages.

| Dispatch fact | Practical meaning | Owner |
| --- | --- | --- |
| One public variable exists per registered command, e.g. `WFBE_PVF_RequestJoin`. | Do not treat PVF as one numeric multiplexed channel. | [Public variable channel index](Public-Variable-Channel-Index#1-registered-pvf-commands) |
| Client-bound payload element `0` is a destination filter: `nil`, side, or UID string. | Runtime/JIP review has to distinguish broadcast, side-targeted and UID-targeted messages. | [Registered Client PVF Runtime Matrix](#registered-client-pvf-runtime-matrix) |
| Server-bound payload element `0` names `SRVFNC<Command>`; client-bound element `1` names `CLTFNC<Command>`. | Current stable resolves this through `missionNamespace getVariable`; old refs still use `Call Compile`, and current stable still needs an explicit registered-handler allowlist. | [PVF dispatch implementation](PVF-Dispatch-Implementation-Playbook) |
| `Common_SendToServer`, `Common_SendToClients` and `Common_SendToClient` map wrapper calls to `publicVariable`, `publicVariableServer` or `publicVariableClient`. | Transport direction is not authority. | [Network Helper Layer](#network-helper-layer), [Server authority migration map](Server-Authority-Migration-Map) |
| `HandleSpecial` and `LocalizeMessage` are second-level routers. | Grep the string tag as well as the PVF command name. | [Client Router Tag Triage](#client-router-tag-triage) |

### Registered Client PVF Runtime Matrix

This is the server-to-client counterpart to the [registered server handler matrix](Server-Authority-Migration-Map#registered-server-pvf-handler-authority-matrix). It answers "what happens on the receiving client?" after `Client_HandlePVF` destination filtering.

Registration source: `Common/Init/Init_PublicVariables.sqf:26-40` registers 15 client-bound commands, while `:45-46` compiles each `CLTFNC*` handler and adds client PVEHs.

| Handler | Runtime effect | JIP / authority note |
| --- | --- | --- |
| `AllCampsCaptured` | Recolors all camp markers for the relevant old/new sides (`AllCampsCaptured.sqf:17-21`). | Visual/event-only. Late joiners need marker refresh, not old PV replay. |
| `AwardBounty` / `AwardBountyPlayer` | Computes a local bounty message and calls `ChangePlayerFunds` (`AwardBounty.sqf:44-49`; `AwardBountyPlayer.sqf:20-21`). `RequestOnUnitKilled.sqf:97-100` has a separate AI-team branch that credits the killer group with `ChangeTeamFunds` when AI teams are enabled. | Client-local money effect plus AI-team fund mutation; server kill authority should decide eligibility before sending or crediting. |
| `CampCaptured` | Updates camp marker color and, for nearby friendly captures, awards local funds and sends `RequestChangeScore` (`CampCaptured.sqf:22-40`). | Not just visual. Capture reward migration must move funds/score authority server-side. |
| `ChangeScore` | Replaces local score for the payload unit (`ChangeScore.sqf:7-8`). | Mirror/update of server score decision; do not use as authority source. |
| `HandleSpecial` | Router for actions, commander vote, HC delegation, endgame, HQ status, ICBM display, join answer, UAV reveal, upgrade/building notices, HQ killed EH, auto-wall and attack-wave state (`HandleSpecial.sqf:9-37`). | Mixed router. For JIP, durable state must be re-sent or polled; event-only tags are not replayed automatically. |
| `LocalizeMessage` | Router for chat/title text and several local money effects such as `Teamkill`, `SecondaryAward` and `HeadHunterReceiveBounty` (`LocalizeMessage.sqf:49,53,67,116-118`). | Treat money-changing messages as gameplay effects, not harmless text. |
| `SetTask` | Creates/replaces `comTask`, sets destination and spawns a local completion timer (`SetTask.sqf:1-31`). | Docs/source `HEAD@86ab85b9d0b1`, Miksuu, perf and historical `c20ce1534be0` register `SetTask` but leave commander-menu sends commented at `GUI_Menu_Command.sqf:335,337,343`; current stable `origin/master@0139a346`, B69 `origin/claude/b69@8d465fce`, B74 `origin/claude/b74-aicom-spend@b23f557f` and `origin/feat/naval-hvt-objectives@2e1c59317186` send targeted Objective Ping tasks at `GUI_Menu_Command.sqf:336,344` in both maintained roots. Historical `a96fdda2` has live sends but no live `release/*` head. Old town `Client_TaskSystem.sqf` remains separate/commented residue. Smoke target/audience, JIP and task-spam behavior before promotion. |
| `SetVehicleLock` / `SetMHQLock` | Applies local vehicle lock or adds MHQ lock/unlock actions (`SetVehicleLock.sqf:1`; `SetMHQLock.sqf:1-3`). | Reflects server lock state; local action setup depends on deploy status. |
| `TownCaptured` | Recolors town marker, shows capture message, awards local funds and sends `RequestChangeScore` for eligible players/commanders (`TownCaptured.sqf:23-80`). | Not just visual. Town reward authority belongs with server-side capture reward migration. |
| `Available` | Shows a hint with available items (`Available.sqf:1`). | UI notification only. |
| `RequestBaseArea` | Moves a base-area object, sets `avail`/`side`, and appends it to `wfbe_basearea` (`RequestBaseArea.sqf:1-4`). | Client-bound despite the name; the callback performs the state mutation locally with no validation, so HQ/base-area deploy changes need server-origin and replay assumptions checked before reuse. |
| `HandleParatrooperMarkerCreation` | Waits for `clientInitComplete`, optionally equips east paratroopers with NVGs, and spawns a local marker update with PerformanceAudit logging (`HandleParatrooperMarkerCreation.sqf:9-45`). | Source/Vanilla registration is propagated; Arma smoke pending. Transient marker, no replay unless owner asks for historical drops. |
| `NukeIncoming` | Plays the air-raid sound (`NukeIncoming.sqf:1-7`). | Presentation-only pair to the ICBM authority path. |

### Client Router Tag Triage

`HandleSpecial` and `LocalizeMessage` deserve tag-level review when a feature is touched:

| Router | Tag family | Why it matters |
| --- | --- | --- |
| `HandleSpecial` | `join-answer`, `commander-vote*`, `new-commander-assigned`, `endgame`, `hq-setstatus`, `attack-wave` | Updates local control flow and durable local variables. JIP/retry behavior must be checked per tag. |
| `HandleSpecial` | `delegate-townai`, `delegate-ai`, `delegate-ai-static-defence`, `set-hq-killed-eh` | Starts locality-sensitive AI/HQ handoffs and event handlers. `delegate-townai` can report vehicles back through `RequestSpecial` / `update-town-delegation`, but static-defense has no matching `update-delegation-static_defence` server branch today; HC/disconnect work should smoke these tags and the report-back gap. (`connected-hc` is a server-side tag handled in `Server_HandleSpecial.sqf:406`, not in client `HandleSpecial`.) |
| `HandleSpecial` | `upgrade-started`, `upgrade-complete`, `building-started`, `icbm-display`, `uav-reveal` | User feedback with side effects: upgrade completion refreshes local artillery vehicles; ICBM display waits on object death and spawns FX. |
| `LocalizeMessage` | `Teamkill`, `SecondaryAward`, `HeadHunterReceiveBounty` | Message tags can mutate player funds locally. Treat them as part of the economy authority surface. |
| `LocalizeMessage` | `Teamstack` | Waits until `WFBE_BLUFOR_SCORE_JOIN` and `WFBE_OPFOR_SCORE_JOIN` exist before formatting the message. This relies on the join-answer path setting those variables. |

### Gotchas

- UID-targeted `SendToClients` still broadcasts to every client and lets non-matching clients discard locally. Use `SendToClient` for true unicast when possible.
- PVF handlers use `Spawn`, so rapid messages that mutate shared state have no strict ordering guarantee.
- Current stable dispatchers use `missionNamespace getVariable` plus `CODE` guards, so the dispatch-time `Call Compile` / DR-38 recompile class is source-present there. Older docs/Miksuu/perf refs still use `Call Compile`, and current stable still needs a registered-handler allowlist to prevent arbitrary existing global `CODE` entrypoints from being selected by payload.
- DR-55 is a separate sender-authentication problem: even after handler-name allowlisting, a forged payload sent to a real handler still reaches that handler unless the server can tie it to an authenticated requester and re-derive side/role/funds from that requester.
- Some bare PV channels are copied per side. The temp mutation handlers are lowercase `wfbe_supply_temp_west` / `wfbe_supply_temp_east`; the replicated balance mirrors use side text (`wfbe_supply_WEST` / `wfbe_supply_EAST`) and are JIP-relevant because clients wait for `wfbe_supply_<sideJoinedText>` during init.
- DR-44: the side-supply temp handlers trust the payload side as well as the payload amount. A hardened handler must reject side/channel mismatches such as a west temp channel carrying an east-side payload and must derive the allowed delta server-side.
- `PLAYER_RADIATED` is not a server-authoritative radiation channel in current source; the client-side radzone script publishes it and the client FSM receives it. Treat it as a local/effect broadcast unless a future nuke rewrite moves radiation authority server-side.
- `REQUEST_SUPPLY_VALUE` is safer than the temp mutation channels because the server derives the reply, but `Common_GetSideSupply.sqf` waits for the local `wfbe_supply_%side` cache without a timeout. Add bounded waits/fallbacks before putting more UI or economy gates behind this request/reply path.
- `SEND_MESSAGE` is not harmless chat plumbing: its multi-language branch compiles payload text on receiving clients (`Client_onEventHandler_SEND_MESSAGE.sqf:25-31`), and `Common_SendMessage.sqf:24-27` has the same local compile branch before broadcasting. Treat DR-46 as a direct-channel RCE until rewritten to structured localization keys/args.
- A real BattlEye PV filter must include direct non-PVF channels as well as `WFBE_PVF_*`; shipped filter evidence is tracked in [External integrations](External-Integrations).
- Supply-heli branch scope is split: docs checkout `8701aacc`, Miksuu `b8389e74` and perf `0076040f` are still truck-only in the checked maintained roots, while stable `origin/master` `cf2a6d6a` and release `a96fdda2` carry supply-heli/cash-run source (`supplyMissionStart.sqf:23,80`, `supplyMissionUnload.sqf:34-57`, `supplyMissionCompleted.sqf:26,37,44`, release `Init_CommonConstants.sqf:169,172-180`, stable line drift `:173,176-184`). Treat supply-heli as branch-present on stable/release but still authority/smoke-pending; route mechanics through [Supply mission architecture](Supply-Mission-Architecture#current-branch-matrix) and [Economy, towns and supply](Economy-Towns-And-Supply#supply-mission-reward-formula-and-stale-copy).

### Security: the `Call Compile` trust boundary

`Server_HandlePVF.sqf` and `Client_HandlePVF.sqf` used to dispatch registered PVF payloads through `Spawn (Call Compile _script)` on the handler name carried in the public-variable value. Current stable `origin/master@0139a346` has replaced that with `missionNamespace getVariable` plus `CODE` guards in both maintained roots, but it still lacks an explicit registered-handler allowlist and sender authentication. This page keeps the architectural warning; [Current Branch Scope](#current-branch-scope) owns the docs-head/source-stable split, [PVF dispatch implementation](PVF-Dispatch-Implementation-Playbook#current-branch-matrix) owns the exact branch/root matrix and remaining patch recipe, [Server authority migration map](Server-Authority-Migration-Map#registered-server-pvf-handler-authority-matrix) owns DR-55 requester/payload validation, and [Public variable channel index](Public-Variable-Channel-Index#send_message-direct-compile-branch-matrix) owns DR-46 `SEND_MESSAGE` direct compile.

### Residual Authority Risks After Dispatch Hardening

Replacing dispatch-time `Call Compile` with namespace lookup removes arbitrary SQF-text compilation, and current stable already has that partial fix. Add a registered-handler allowlist before treating forged handler-name execution as fully closed. Even then, it will not authenticate the requester or validate payload fields for legitimate handlers. Keep the post-dispatch work queue on [Server authority migration map](Server-Authority-Migration-Map#registered-server-pvf-handler-authority-matrix); it owns `RequestChangeScore`, construction/defense, upgrades, vehicle lock, team update, auto-wall and `RequestSpecial` triage with exact source evidence.

### Highest-Priority Registered Command: ICBM / Nuke

DR-27 makes `RequestSpecial` `"ICBM"` the highest-priority registered-command hardening target discovered so far. Keep implementation detail in [ICBM authority](ICBM-Authority-Playbook) and broader `RequestSpecial` tag triage in [Server authority migration map](Server-Authority-Migration-Map#requestspecial-tag-triage).

### Direct Channel Authority: Attack Waves

Attack waves are a direct publicVariable authority lane, not a registered PVF dispatch lane. Use [Attack-wave authority playbook](Attack-Wave-Authority-Playbook) for the source chain, branch/root matrix, all-supply spend model and safe patch shape for `ATTACK_WAVE_INIT` plus `ATTACK_WAVE_DETAILS`.

## Continue Reading

Previous: [Function/module index](Function-And-Module-Index) | Next: [Gameplay atlas](Gameplay-Systems-Atlas)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
