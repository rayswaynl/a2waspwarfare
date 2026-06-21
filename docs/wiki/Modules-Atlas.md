# Modules Atlas

> Source-refreshed 2026-06-14 on docs head `86244c24`; targeted diffs from `20a19676` through `HEAD` over checked module init, unit-creation and module-folder paths return no source changes. Behavioral map of the `Client/Module/*`, `Server/Module/*` and `Common/Module/*` subsystems. Most modules are config-gated QoL/combat features (gate = a `WFBE_C_MODULE_WFBE_<X>` constant; see [Variable and naming conventions](Variable-And-Naming-Conventions)). Exact branch matrices stay on owner pages except the compact Reaktiv dormant-module table below. Paths below are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/` unless a branch/root note says otherwise. Arma 2 OA 1.64.

## How To Use This Atlas

| Need | Start here | Why |
| --- | --- | --- |
| Find a module's boot or attach edge | This page, then [SQF code atlas](SQF-Code-Atlas) | This page names the live init/unit-creation edge before you edit a module file. |
| Review tactical/authority modules | [Support specials and tactical modules](Support-Specials-And-Tactical-Modules-Atlas), [ICBM authority](ICBM-Authority-Playbook), [Server authority migration map](Server-Authority-Migration-Map) | ICBM, support specials and request handlers have deeper branch matrices and server-trust notes there. |
| Review loadout/service/UI modules | [Gear, loadout and EASA](Gear-Loadout-And-EASA-Atlas), [Client UI systems](Client-UI-Systems-Atlas) | EASA/service affordability, UI loops and resource risks are owned by narrower UI/loadout pages. |
| Review supply, MASH or respawn modules | [Supply mission architecture](Supply-Mission-Architecture), [Respawn and death lifecycle](Respawn-And-Death-Lifecycle-Atlas) | Supply and mobile-respawn behavior spans client/server modules and PV state. |
| Review runtime/performance channels | [Server runtime and operations](Server-Runtime-And-Operations), [Hosted server FPS loop sleep](Hosted-Server-FPS-Loop-Sleep), [Public variable channel index](Public-Variable-Channel-Index) | FPS publishing, AFK enforcement and PV channels need runtime/BE context outside module folders. |
| Decide archive vs revive | [Dead/stale code register](Dead-Code-And-Stale-Code-Register) | Dormant modules such as Reaktiv should not be revived or removed from a folder diff alone. |

## Covered By Owner Pages

| Module | Owner route | Source anchor |
| --- | --- | --- |
| Nuke / ICBM | [ICBM authority](ICBM-Authority-Playbook), [Support specials](Support-Specials-And-Tactical-Modules-Atlas) | Common init compiles `Client\Module\Nuke\ICBM_Init.sqf` when `WFBE_C_MODULE_WFBE_ICBM > 0` (`Init_Common.sqf:319`). |
| EASA aircraft loadout | [Gear, loadout and EASA](Gear-Loadout-And-EASA-Atlas), [Service menu affordability guards](Service-Menu-Affordability-Guards) | Client init compiles `Client\Module\EASA\EASA_Init.sqf` when enabled (`Init_Client.sqf:588`). |
| AntiStack external DB | [Player join/disconnect and AntiStack lifecycle](Player-Join-Disconnect-And-AntiStack-Lifecycle), [AntiStack database extension audit](AntiStack-Database-Extension-Audit) | Server init compiles AntiStack helpers at `Init_Server.sqf:72-80,85-87` and starts optional loops at `:599-608`. |
| supplyMission | [Supply mission architecture](Supply-Mission-Architecture), [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook) | Server init compiles supplyMission helpers at `Init_Server.sqf:66-69,71,81,91`. |
| MASH markers | [Respawn and death lifecycle](Respawn-And-Death-Lifecycle-Atlas#mash-split-live-respawn-dead-marker-relay) | Client receiver is commented at `Init_Client.sqf:132`; server marker helper is compiled/comment-split at `Init_Server.sqf:70,92`. |
| UAV terminal/module | [Support specials](Support-Specials-And-Tactical-Modules-Atlas), [Client UI systems](Client-UI-Systems-Atlas) | Current UI keeps the `_button == 007` branch disabled (`uav_interface.sqf:226`, `uav_interface_oa.sqf:100`). |
| serverFPS | [Hosted server FPS loop sleep](Hosted-Server-FPS-Loop-Sleep), [Server runtime](Server-Runtime-And-Operations) | Server init has old commented compile lines at `Init_Server.sqf:65,90` and still starts the publisher at `:595`. |
| AFKkick | [Public variable channel index](Public-Variable-Channel-Index), [Feature status](Feature-Status-Register#afk-enforcement-policy) | Client init compiles/runs `Client\Module\AFKkick` at `Init_Client.sqf:256-264`; server handler compile is `Init_Server.sqf:63` with an older commented duplicate at `:88`. |

## Combat / vehicle modules

### IRS — IR-smoke missile countermeasure (`Common/Module/IRS/`)
Compiles `WFBE_CO_MOD_IRS_CreateSmoke/DeploySmoke/HandleMissile/OnIncomingMissile` (`IRS_Init.sqf:5-8`). Tunables (`IRS_Init.sqf:10-14`): `WFBE_IRS_AREA_OPERATING=35`, `WFBE_IRS_AUTO_DETECT_RANGE=200`, `WFBE_IRS_FLARE_DELAY=60`, `WFBE_IRS_MISSILE_CHECK_RANGE=200`. Flow: built tanks/cars always get the generic AT missile handler at `Client_BuildUnit.sqf:342` (`HandleATMissiles`); only the gated IRS branch adds the IRS-specific `incomingMissile` EH at `:356` (`WFBE_CO_MOD_IRS_OnIncomingMissile`) to deploy IR smoke when a missile enters range. **Gate:** `WFBE_C_MODULE_WFBE_IRSMOKE > 0` **and** the side owns `WFBE_UP_IRSMOKE` (upgrade level doubles smoke at level 2). Per-vehicle `wfbe_irs_flares` broadcast.

### CM — flares / chaff / spoofing (`Client/Module/CM/`)
`CM_Init.sqf:1-3` compiles `CM_Countermeasures`, `CM_Flares`, `CM_Spoofing`. **Gate for the CM module:** `WFBE_C_MODULE_WFBE_FLARES > 0 && WF_A2_Vanilla` (`Init_Client.sqf:589`). The separate built-aircraft CM-removal block is the non-vanilla/OA path: `Client_BuildUnit.sqf:275-283` runs under `if !(WF_A2_Vanilla)` and removes countermeasures when the module is disabled or the side lacks `WFBE_UP_FLARESCM`. Do not describe the removal block as vanilla-only.

### Reaktiv — reactive (ERA) armor (`Common/Module/Reaktiv/`)
Current docs/source status: **dead / unreachable**. `Common/Module/Reaktiv/Reaktiv_Init.sqf:5` compiles `WFBE_CO_MOD_Reaktiv_OnDamageReceived` (`Reaktiv_OnHandleDamage.sqf`), but no current init or runtime file calls `Reaktiv_Init.sqf`. Current Chernarus and maintained Vanilla `Init_Common.sqf:319-323` initialize ICBM, IRS and CIPHER, with no Reaktiv compile path. If revived, it would apply a `HandleDamage`-based per-hit-selection damage model (the init's comment block enumerates hull/turret/track/engine selections for an Abrams under `R_M136_AT`) and alter how AT hits map to vehicle hitpoints.

Branch check refreshed 2026-06-14:

| Ref | Maintained-root Reaktiv files | Init caller | Modded copies |
| --- | --- | --- | --- |
| docs head `86244c24` (source-unchanged from `20a19676`) | Present in source Chernarus and maintained Vanilla (`Reaktiv_Init.sqf:5`, `Reaktiv_OnHandleDamage.sqf:7`) | No Reaktiv call; only ICBM/IRS/CIPHER at `Init_Common.sqf:319-323` | Napf, Eden and Lingor still carry `Common/Module/Reaktiv`. |
| stable `origin/master` `cf2a6d6a` | No maintained-root `Common/Module/Reaktiv` hits | No Reaktiv call; only ICBM/IRS/CIPHER at `Init_Common.sqf:320-324` | Napf, Eden and Lingor still carry `Common/Module/Reaktiv`. |
| Miksuu `b8389e74` | Present in source Chernarus and maintained Vanilla | No Reaktiv call; only ICBM/IRS/CIPHER at `Init_Common.sqf:319-323` | Napf, Eden and Lingor still carry `Common/Module/Reaktiv`. |
| `perf/quick-wins` `0076040f` | Present in source Chernarus and maintained Vanilla | No Reaktiv call; only ICBM/IRS/CIPHER at `Init_Common.sqf:319-323` | Napf, Eden and Lingor still carry `Common/Module/Reaktiv`. |
| release `a96fdda2` | No maintained-root `Common/Module/Reaktiv` hits | No Reaktiv call; only ICBM/IRS/CIPHER at `Init_Common.sqf:319-323` | Napf, Eden and Lingor still carry `Common/Module/Reaktiv`. |

### Engines — "stealth" engine-off (`Client/Module/Engines/`)
`Engine.sqf` toggles a stealth mode: saves current fuel into the vehicle's `Fuel` variable and `setFuel 0` (engine cannot run), swapping the addAction to `STEALTH OFF` -> `Startengine.sqf` which restores fuel. Added to purchased tanks/wheeled-APCs (`Client_BuildUnit.sqf:417-418`) and WASP extra start vehicles (`Server/Init/Init_Server.sqf:521-522,539-540`). Details and refuel-state caveats: [Engine stealth fuel toggle](Engine-Stealth-Fuel-Toggle-Reference).

### AutoFlip — auto-right flipped vehicles (`Client/Module/AutoFlip/AutoFlip.sqf`, by Marty)
Client polling loop that rights nearby flipped ground vehicles after they stay stuck briefly. Parameters (`:9-13`): `_scanDelay=3`, `_tiltLimit=0.35`, `_stuckDelay=10`, `_cooldown=45`, `_maxSpeed=2`. Per-vehicle linear checks (tilt/speed/grounded/dry/cooldown) before flipping. Local, bounded by scan delay.

### ZetaCargo — helicopter sling-load (`Client/Module/ZetaCargo/`, by Benny)
`Zeta_Init.sqf` defines the lifter allow-list `Zeta_Lifter` (MH60S, MV22, C130J, Mi17 variants, UH60M, CH-47, Merlin, …), liftable `Zeta_Types = ["Car","Motorcycle","Tank","Ship"]`, default hook offset `[0,0,-10]`, and a special C-130 offset (`Zeta_Special`/`Zeta_SpecialPosition`). `Zeta_Hook.sqf`/`Zeta_Unhook.sqf` attach/detach cargo. Client-driven.

### Valhalla — low-gear / high-climb movement (`Client/Module/Valhalla/`)
`Init_Valhalla.sqf` compiles `VALHALLA_FNC_LowGear` and installs `KeyDown`/`KeyUp` EHs on display 46 tracking the `carForward` action keys (`Local_KeyPressedForward`) to drive a "high climbing mode" (`Local_HighClimbingModeOn`). Plus an AI low-gear manager variant (`Common_AI_LowGear.sqf`, `Func_Client_AI_LowGear_Manager.sqf`). Client-local movement enhancement.

## Player / AI / utility modules

### Skill — player class abilities (`Client/Module/Skill/`, by Benny)
`Skill_Init.sqf` compiles `WFBE_SK_FNC_Apply` and defines class→group maps (`WFBE_SK_V_Engineers`, `WFBE_SK_V_Soldiers`, plus LR/Officer/Salvage/Sniper/SpecOps via `Skill_*.sqf`). Each group grants abilities: Engineer (repair/salvage/camps-restore), Soldier (AI cap becomes `ceil(1.5 * WFBE_C_PLAYERS_AI_MAX)` at `Skill_Init.sqf:49`, plus camp restore), Officer (incl. `Actions/Officer_Undeploy_MASH.sqf`), etc. Applied per player based on unit classname.

### NEURO — AI taxi / vehicle-sharing (`Server/Module/NEURO/NEURO.sqf`, by Benny)
Server-side system that assigns unassigned AI infantry into nearby empty/compatible vehicles heading toward their waypoint, to reduce on-foot AI. Config hook: `missionNamespace setVariable ["NEURO_TAXI_CONDITION", "<code>"]` decides boarding eligibility (e.g. excludes vehicles flagged `WFBE_Taxi_Prohib`). Helpers clear assignments when a unit is dead or >900 m away (`NEURO_BE_ClearVehiclePositions`), measure emptiness, and (per the body) paradrop AI at altitude. Server-authoritative AI behavior.

### CIPHER — string/array sort utility (`Common/Module/CIPHER/`, by Benny)
Utility library plus one boot-time script. `CIPHER_Init.sqf` defines compiled helpers such as `CIPHER_CompareString`, `CIPHER_SortArray` and `CIPHER_SortArrayIndex` (`CIPHER_Init.sqf:58,94`); `Labels_Upgrades.sqf:127` separately `ExecVM`s `Common\Module\CIPHER\CIPHER_Sort.sqf`, which sorts upgrade labels into `WFBE_C_UPGRADES_SORTED` via `CIPHER_SortArrayIndex` (`CIPHER_Sort.sqf:37-39`). **No network or gameplay side effects** — safe utility/data-prep scope, but do not treat `CIPHER_Sort.sqf` as a compiled function.

## Notes for hardening / review
- Module **gates** are config constants (`WFBE_C_MODULE_WFBE_*`) read at boot; toggling them is the supported on/off switch.
- Combat modules attach their EHs at **unit creation** in `Client/Functions/Client_BuildUnit.sqf` (IRS/CM/Engines and inline rearmor handlers), so they are client-local on the buyer's machine — consistent with the factory locality model (DR-33). Do not count Reaktiv in that live set unless `Reaktiv_Init.sqf` is deliberately wired back in.
- Before editing a module, name its runtime edge and smoke that edge: boot init (`Init_Common.sqf:319-323`, `Init_Client.sqf:127-135`, `:587-589`), respawn reapply (`Init_Client.sqf:570-571` and respawn skill reapply paths), unit creation attach (`Client_BuildUnit.sqf:275-283`, `:336-356`), PV/PVF event, or server loop. A module file diff alone is not enough proof that the live behavior changed.
- The only module here with a map-wide forged-payload defect is **Nuke/ICBM** (DR-27). EASA/service, supply, MASH and PV/PVF trust surfaces are routed to their owner pages above; do not flatten those into this compact module map.

## Continue Reading

Conventions: [Variable and naming conventions](Variable-And-Naming-Conventions) | Function index: [Function and module index](Function-And-Module-Index) | Findings: [Deep-review findings](Deep-Review-Findings)
