# Server Authority Migration Map

This page is the design map for moving A2 Wasp Warfare from trusted client affordances toward server-owned gameplay authority.

Scope: Chernarus source mission first, Arma 2 Operation Arrowhead 1.64 behavior only, then LoadoutManager propagation. All source paths below are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/` unless noted.

Use this with [Hardening roadmap](Hardening-Implementation-Roadmap), [Networking and public variables](Networking-And-Public-Variables), [Economy, towns and supply](Economy-Towns-And-Supply), [Feature status](Feature-Status-Register), [Testing workflow](Testing-Debugging-And-Release-Workflow) and [`agent-test-plan.schema.json`](agent-test-plan.schema.json).

Page ownership: this page owns the design model for authority migrations: principles, flow table, handler checklist, "do not migrate casually" notes and validation expectations. [Hardening roadmap](Hardening-Implementation-Roadmap) owns canonical patch order and branch sequencing. Focused playbooks own detailed implementation shape.

## Why This Exists

Many high-impact findings are not isolated bugs. They are the same ownership problem repeated across different mission systems:

- client UI validates affordability, role or range;
- client or payload chooses side, target, class, position, amount or reward;
- server executes a legitimate handler with limited recomputation;
- BattlEye filters in the repo do not provide a shipped fallback authority layer.

Do not patch seven spend/effect paths in seven unrelated styles. Pick an authority model first, then migrate flows in a consistent order.

## Authority Principles

| Principle | Rule for future patches |
| --- | --- |
| Client UI is affordance | Menus may show prices, buttons and hints, but the server owns final acceptance, debit and effect. |
| Server recomputes truth | Recompute side, role, funds, supply, cost, upgrade state, object validity, range and placement from server-held state. |
| Harden dispatch before payloads | Replace dispatch-time `Call Compile` in PVF handlers with validated namespace lookup before deeper per-handler rewrites. |
| Direct PV channels are separate | `ATTACK_WAVE_INIT`, side supply temps, supply mission PVs and marker/state PVs bypass the generic PVF dispatcher. |
| Arma 2 OA sender identity is weak | A publicVariable event handler does not hand the server a clean sender identity. If a handler needs authority, include a requester/player/team object where safe and cross-check group, side, ownership and UID when available. |
| Keep old UI until confirmation | Let the client request work and show feedback, but do not mutate final funds/effects until the server accepts or rejects. |
| Log compactly | Use small `INFORMATION` logs for accepted high-value transactions and `WARNING` logs for rejected malformed or unauthorized requests. Avoid hot-loop spam. |
| BattlEye is defense in depth | Public server filters can reduce attack surface, but they are not the mission's source of authority. The repo currently ships only a minimal `BattlEyeFilter/publicvariable.txt` AFK-related rule. |

## Patch Order Routing

Canonical patch sequencing lives in [Hardening roadmap](Hardening-Implementation-Roadmap). Use this page when designing or reviewing a specific authority migration, then return to the roadmap or machine backlog to claim work.

| Need | Open |
| --- | --- |
| Prioritized patch order | [Hardening roadmap](Hardening-Implementation-Roadmap) |
| Machine-readable work packages | [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl) |
| Generic PVF dispatcher patch | [PVF dispatch implementation](PVF-Dispatch-Implementation-Playbook) |
| Direct attack-wave channel patch | [Attack-wave authority](Attack-Wave-Authority-Playbook) |
| Economy first cut | [Economy authority first cut](Economy-Authority-First-Cut) |
| Supply truck/heli authority cleanup | [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook) |

## Migration Table

| Flow | Client entrypoint | Current server/current handler | Current trust | Target authority owner | Patch shape | First validation |
| --- | --- | --- | --- | --- | --- | --- |
| PVF dispatch | Any `WFBE_CO_FNC_SendToServer`, `SendToClient` or `SendToClients` command | `Server_HandlePVF.sqf:14`, `Client_HandlePVF.sqf:22`, registry in `Init_PublicVariables.sqf:23-51` | Dispatchers run `Spawn (Call Compile _script)` on command strings from the PV payload; init already compiles `SRVFNC*` and `CLTFNC*`. | Validated handler lookup in `missionNamespace`. | Use `missionNamespace getVariable [_script, {}]`, reject non-`CODE` and unregistered names, keep `Spawn` until scheduled handler needs are audited. | Valid `RequestJoin` or `RequestVehicleLock`, valid `LocalizeMessage` or `HandleSpecial`, bogus handler rejected and logged once. |
| ICBM / nuke | `Client/Module/Nuke/nukeincoming.sqf:23` | `Server/PVFunctions/RequestSpecial.sqf:1`, `"ICBM"` in `Server_HandleSpecial.sqf:97-111` | Client supplies side, base/target object, cruise object and team; server later spawns `NukeDammage`. | Server special-weapons authority. | Server validates commander/team, side, module/upgrade state, funds/cost, base/target object shape and range; server owns debit and launch acceptance. | Valid commander launch still works; forged non-commander, wrong-side, dead/invalid target and invalid base do not spawn `NukeDammage`. |
| Construction and defenses | `Client/Module/CoIn/coin_interface.sqf` | `Server/PVFunctions/RequestStructure.sqf:3-20`, `RequestDefense.sqf:2-8` | Client sends side, class/name, position, direction and manned flag; server mostly resolves class arrays and builds. | Server base-construction authority. | Include requester context, validate side and commander/repair-truck authority, funds, HQ/base area, placement, class allowlist and manned-defense permission; server debit before build. | Accepted HQ/factory/defense builds still work; wrong-side, unaffordable, out-of-base and disallowed manned-defense requests reject. |
| Player factory buy | `Client/GUI/GUI_Menu_BuyUnits.sqf:102-156` | No registered `RequestBuyUnit`; `Client/Functions/Client_BuildUnit.sqf:217,249,411-450` creates units/vehicles locally | Client checks funds, spawns `BuildUnit`, debits with `ChangePlayerFunds`, and creates units/vehicles locally. | Large redesign: server buy authority, or explicit public-server dependency on BattlEye script filters while locality is preserved. | Prefer a server-validated buy request for high-value purchases. If preserving client locality temporarily, document it as not server-authoritative and harden with BE `scripts.txt` outside mission code. | Buy infantry and vehicles on hosted/dedicated; forged createVehicle/createUnit path must be constrained by chosen authority model or BE posture. |
| Upgrades | `Client/GUI/GUI_UpgradeMenu.sqf` and upgrade menu send path | `Server/PVFunctions/RequestUpgrade.sqf:5`, `Server_ProcessUpgrade.sqf:12-18,40-44,85-87` | Raw payload selects side, upgrade id and level; server processes timing and state but cost/dependency authority is client-side. | Server upgrade authority. | Server validates commander/team, side, current level, requested next level, dependencies, cost and funds/supply; server owns debit and state transition. | Valid upgrade completes; invalid id/level, skipped dependency, insufficient funds and wrong-side/role reject. |
| Side supply | Common `ChangeSideSupply` callers | `Common_ChangeSideSupply.sqf:24-30`, `Server_ChangeSideSupply.sqf:1-45` | Common side broadcasts signed temp amount; server recomputes `_change` but the negative floor can turn overspend into a windfall. | Server side-supply ledger. | Fix negative clamp to zero/valid floor, restrict supply mutation callers, and prefer server-owned supply mutations for spend/reward flows. | Positive reward still applies; overspend cannot increase supply; west/east both covered; resistance owner decision documented. |
| Supply missions | `Client/Module/supplyMission/supplyMissionStart.sqf:20-39` | `supplyMissionStarted.sqf:1-65`, `supplyMissionCompleted.sqf:2-34` | Client stamps `SupplyFromTown` and `SupplyAmount` on vehicle; completion reads those vars and rewards side supply. | Server logistics authority. | Server re-derives source town/reward from trusted state where possible, standardizes cooldown casing, avoids duplicate loops/handlers, and narrows broad object scans. | Truck mission complete/repeat/JIP cooldown; forged reward/source ignored; PR #1 destruction reward pays once. |
| Attack waves | `Client/FSM/updateclient.sqf:240`, `Common/Functions/Common_AttackWaveActivate.sqf:3-8` | `Server_AttackWave.sqf:1-38`, `Server/PVFunctions/AttackWave.sqf:1-55` | Client/common side sends `ATTACK_WAVE_INIT = [_supply, _side]`; server uses `_supply` to compute discount and duration. DR-41 shows forged `_supply >= 70000` can drive side-wide unit price modifier to zero or negative. | Server support-mode authority. | Treat direct PV as a request; server re-derives side supply, validates requester side/permission, deducts intended cost and clamps modifier/duration before starting wave. | Legit wave starts; forged exaggerated supply cannot change modifier, duration or cost; wrong-side requests reject; late-join attack-wave state remains documented. |
| Gear, EASA and service | `GUI_BuyGearMenu.sqf:421-441`, `GUI_Menu_EASA.sqf:40-49`, `GUI_Menu_Service.sqf:126-230` | Mostly no server handler; support scripts run from client service menu | Gear/EASA/service affordability and effects are client-local. Service rearm/refuel debit unconditionally when action selected. | Server equipment/service ledger or explicit local-only trust decision. | Add server request/acceptance for public-server hardening. As a small correctness patch only, add local affordability guards for service rearm/refuel parity. | Gear buy, EASA equip, service repair/rearm/refuel/heal; unaffordable and wrong-context requests reject or are BE-constrained. |
| Structure sale | `Client/GUI/GUI_Menu_Economy.sqf` | No server sale PVF found in current docs/findings | Client commander check, refund and destruction are local. | Server economy/base authority. | Add sale request with server commander, ownership, object type, refund and destruction validation; server owns refund/effect. | Valid sale works once; wrong-side/non-commander/stale object sale rejects. |
| WASP HQ recovery | `WASP/actions/Action_RepairMHQDepot.sqf:8-28` | `RequestMHQRepair` server path plus client-side `cashrepaired` and town supply reset | Client checks/debits cash, sends side-only repair request, sets public flags and resets town `supplyvalue`. | Server HQ recovery authority. | Include requester context; server validates dead HQ, commander/side, one-time flag, funds and town-SV side effects before repair. | Valid recovery works once; wrong-side, insufficient-funds and second repair reject; town supply reset is server-owned. |

## Handler Validation Checklist

Use this checklist for every authority-sensitive handler before writing code:

| Check | Ask |
| --- | --- |
| Requester | Which player, unit or group is asking? Can the server verify that object is alive, local enough to inspect, and belongs to the claimed side? |
| Role | Must the requester be commander, driver, repair-truck user, team leader, support user or side member? |
| Side | Is side derived from server-known group/player/object state instead of a payload scalar/string? |
| Funds/supply | Does the server recompute price, balance and resulting floor/cap? |
| Object validity | Are object refs non-null, alive where required, the expected class, and not stale from a previous action? |
| Locality | Does the effect need to run on server, client owner, headless client or all clients? |
| Position/range | Is the target/base/source within valid distance and terrain/build constraints? |
| Class allowlist | Is the requested class/name in the side's server-held allowlist? |
| Upgrade/dependency | Does the requested level match current state and dependencies? |
| Idempotency | Can duplicate PVs, duplicate event handlers, JIP replays or retries apply the effect twice? |
| State broadcast | Does accepted server state need object variables, side logic vars, marker replay or pull-based JIP sync? |
| Logging | Is there one compact accepted/rejected log at the transition point? |
| BattlEye | Does production need a matching filter update as defense in depth? |
| Test record | Is a future or actual test entry compatible with [`agent-test-plan.schema.json`](agent-test-plan.schema.json)? |

## Do Not Migrate Casually Yet

| Area | Why |
| --- | --- |
| Client-local player factory buys | Moving createUnit/createVehicle authority can change locality, queue ownership, AI group ownership and buyer disconnect behavior. Design the request/acceptance model first. |
| Gear/EASA/service | Many UI/effect paths mutate inventory, weapons, magazines, fuel, damage and vehicle state locally. Quick local guards are not a full authority migration. |
| Modded missions | Napf, Eden and Lingor are divergent forks; other modded folders are stubs. Source fixes do not automatically make all modded missions safe. |
| Autonomous AI logistics | Supply truck/heli AI work sits on partially disabled/missing logistics code. Finish the owner decision before reviving autonomous behavior. |
| BattlEye posture | Filters usually live outside the mission PBO. Confirm production BEpath before claiming public-server hardening. |

## Interim Live-Server Posture

Until server authority is implemented, do not describe the repo as public-server hardened.

Minimum interim posture:

1. Harden PVF dispatch lookup first.
2. Add production BattlEye publicVariable and scripts filters for the highest-risk request/effect paths.
3. Treat `RequestSpecial` `"ICBM"`, construction/defense, upgrades, side supply, player buys, structure sale, supply rewards, attack waves, gear/EASA/service and WASP HQ recovery as a single trust-boundary class.
4. Record which flows are still client-authoritative in [Feature status](Feature-Status-Register).
5. For every patch, record validation level in [Testing workflow](Testing-Debugging-And-Release-Workflow) terms.

## Validation Tie-In

Every server-authority patch should produce a test record or planned test record shaped like [`agent-test-plan.schema.json`](agent-test-plan.schema.json).

Recommended minimum coverage by phase:

| Phase | Minimum evidence |
| --- | --- |
| PVF foundation | `source-only` registry check plus hosted or dedicated PV smoke. |
| ICBM and attack waves | `dedicated-smoke`; `live-server-sensitive` if BattlEye or production config changes. |
| Economy ledger | `dedicated-smoke` for each migrated flow; hosted/listen smoke if locality changes. |
| Supply and support systems | `dedicated-smoke`, `jip-smoke` for cooldown/state, PR #1 vehicle reuse/destruction tests when relevant. |
| HC/AI-adjacent migrations | `hc-smoke` if group ownership, delegation or AI spawning changes. |

## Machine Notes

Agents should read this page before claiming any `agent-hardening-backlog.jsonl` item with `network-authority`, `economy`, `gameplay-security`, `support-systems` or `BattlEye` categories.

This page does not change mission behavior. It is the source-backed design layer for future implementation branches such as `hardening/pvf-dispatch`, `hardening/icbm-authority`, `hardening/economy-ledger`, `hardening/supply-missions` and `hardening/attack-wave-authority`. For the order in which those branches should be claimed, use [Hardening roadmap](Hardening-Implementation-Roadmap).

Dedicated playbook: [Attack-wave authority](Attack-Wave-Authority-Playbook) expands the DR-41 row into an implementation-ready patch shape, including the current all-side-supply spend model.

First implementation cut: [Economy authority first cut](Economy-Authority-First-Cut) sequences the broad economy class into side-supply clamp, upgrade authority, construction/defense authority and deferred player-buy redesign.

## Continue Reading

Previous: [Hardening roadmap](Hardening-Implementation-Roadmap) | Next: [Attack-wave authority playbook](Attack-Wave-Authority-Playbook)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)

