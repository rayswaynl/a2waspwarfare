# Modules Atlas

> Claude-owned, source-verified (2026-06-02). Behavioral map of the `Client/Module/*`, `Server/Module/*` and `Common/Module/*` subsystems — most are config-gated QoL/combat features (gate = a `WFBE_C_MODULE_WFBE_<X>` constant; see [Variable and naming conventions](Variable-And-Naming-Conventions)). The high-stakes module (Nuke/ICBM) and the integration modules (AntiStack, supplyMission, MASH) have dedicated findings; this page documents the **previously-undocumented** ones. Paths relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`. Arma 2 OA 1.64.

## Already covered elsewhere (cross-links)
- **Nuke / ICBM** — [Deep-review findings](Deep-Review-Findings) DR-27. `Client/Module/Nuke/`.
- **EASA** (aircraft loadout) — DR-28 (client-authoritative). `Client/Module/EASA/`.
- **AntiStack** (external DB) — DR-7..DR-10. `Server/Module/AntiStack/`, `Client/Module/AntiStack/`.
- **supplyMission** — DR-39 (dead twin + pull-based JIP). `Server/Module/supplyMission/`.
- **MASH markers** — DR-34 (dead both ends). `Client/Module/MASH/`, `Server/Module/MASH/`.
- **UAV** — DR-27 round (the `_button == 007` branch is `comment 'DISABLED'`, `uav_interface.sqf:226` / `uav_interface_oa.sqf:100`). `Client/Module/UAV/`.
- **serverFPS** — DR-19 (hosted busy-loop). `Server/Module/serverFPS/`.
- **AFKkick** — `kickAFK` PV is the one BattlEye-filtered channel (DR-30). `Client/Module/AFK/`, `Server/Module/afkKick/`.

## Combat / vehicle modules

### IRS — IR-smoke missile countermeasure (`Common/Module/IRS/`)
Compiles `WFBE_CO_MOD_IRS_CreateSmoke/DeploySmoke/HandleMissile/OnIncomingMissile` (`IRS_Init.sqf:5-8`). Tunables (`IRS_Init.sqf:10-14`): `WFBE_IRS_AREA_OPERATING=35`, `WFBE_IRS_AUTO_DETECT_RANGE=200`, `WFBE_IRS_FLARE_DELAY=60`, `WFBE_IRS_MISSILE_CHECK_RANGE=200`. Flow: a built tank/car gets an `incomingMissile` EH (`Client_BuildUnit.sqf:342,356`) that spawns `WFBE_CO_MOD_IRS_OnIncomingMissile` → deploys IR smoke when a missile enters range. **Gate:** `WFBE_C_MODULE_WFBE_IRSMOKE > 0` **and** the side owns `WFBE_UP_IRSMOKE` (upgrade level doubles smoke at level 2). Per-vehicle `wfbe_irs_flares` broadcast.

### CM — flares / chaff / spoofing (`Client/Module/CM/`)
`CM_Init.sqf:1-3` compiles `CM_Countermeasures`, `CM_Flares`, `CM_Spoofing`. **Gate:** `WFBE_C_MODULE_WFBE_FLARES > 0 && WF_A2_Vanilla` (`Init_Client.sqf:590`); on built aircraft, CM is removed unless enabled + the side owns `WFBE_UP_FLARESCM` (`Client_BuildUnit.sqf:276-283`). Vanilla-only by design.

### Reaktiv — reactive (ERA) armor (`Common/Module/Reaktiv/`)
`Reaktiv_Init.sqf:5` compiles `WFBE_CO_MOD_Reaktiv_OnDamageReceived` (`Reaktiv_OnHandleDamage.sqf`). The handler would apply a `HandleDamage`-based per-hit-selection damage model from `*_Reaktiv` missionNamespace data (`Reaktiv_OnHandleDamage.sqf:7-21`), and the init's comment block enumerates hull/turret/track/engine selections for an Abrams under `R_M136_AT`. Current source scan found the compile/handler but no live attachment point outside the module, so verify liveness before treating Reaktiv as an active armor feature.

### Engines — "stealth" engine-off (`Client/Module/Engines/`)
`Engine.sqf` toggles a stealth mode: saves current fuel into the vehicle's `Fuel` variable and `setFuel 0` (engine cannot run), swapping the addAction to `STEALTH OFF` → `Startengine.sqf` which restores fuel. Added to built tanks/wheeled-APCs (`Client_BuildUnit.sqf:336-337`). Client addAction-driven, local.

### AutoFlip — auto-right flipped vehicles (`Client/Module/AutoFlip/AutoFlip.sqf`, by Marty)
Client polling loop that rights nearby flipped ground vehicles after they stay stuck briefly. Parameters (`:9-13`): `_scanDelay=3`, `_tiltLimit=0.35`, `_stuckDelay=10`, `_cooldown=45`, `_maxSpeed=2`. Per-vehicle linear checks (tilt/speed/grounded/dry/cooldown) before flipping. Local, bounded by scan delay.

### ZetaCargo — helicopter sling-load (`Client/Module/ZetaCargo/`, by Benny)
`Zeta_Init.sqf` defines the lifter allow-list `Zeta_Lifter` (MH60S, MV22, C130J, Mi17 variants, UH60M, CH-47, Merlin, …), liftable `Zeta_Types = ["Car","Motorcycle","Tank","Ship"]`, default hook offset `[0,0,-10]`, and a special C-130 offset (`Zeta_Special`/`Zeta_SpecialPosition`). `Zeta_Hook.sqf`/`Zeta_Unhook.sqf` attach/detach cargo. Client-driven.

### Valhalla — low-gear / high-climb movement (`Client/Module/Valhalla/`)
`Init_Valhalla.sqf` compiles `VALHALLA_FNC_LowGear` and installs `KeyDown`/`KeyUp` EHs on display 46 tracking the `carForward` action keys (`Local_KeyPressedForward`) to drive a "high climbing mode" (`Local_HighClimbingModeOn`). Plus an AI low-gear manager variant (`Common_AI_LowGear.sqf`, `Func_Client_AI_LowGear_Manager.sqf`). Client-local movement enhancement.

## Player / AI / utility modules

### Skill — player class abilities (`Client/Module/Skill/`, by Benny)
`Skill_Init.sqf` compiles `WFBE_SK_FNC_Apply` and defines class→group maps (`WFBE_SK_V_Engineers`, `WFBE_SK_V_Soldiers`, plus LR/Officer/Salvage/Sniper/SpecOps via `Skill_*.sqf`). Each group grants abilities: Engineer (repair/salvage/camps-restore), Soldier (double team size + camp restore), Officer (incl. `Actions/Officer_Undeploy_MASH.sqf`), etc. Applied per player based on unit classname.

### NEURO — AI taxi / vehicle-sharing (`Server/Module/NEURO/NEURO.sqf`, by Benny)
Server-side system that assigns unassigned AI infantry into nearby empty/compatible vehicles heading toward their waypoint, to reduce on-foot AI. Config hook: `missionNamespace setVariable ["NEURO_TAXI_CONDITION", "<code>"]` decides boarding eligibility (e.g. excludes vehicles flagged `WFBE_Taxi_Prohib`). Helpers clear assignments when a unit is dead or >900 m away (`NEURO_BE_ClearVehiclePositions`), measure emptiness, and (per the body) paradrop AI at altitude. Server-authoritative AI behavior.

### CIPHER — string/array sort utility (`Common/Module/CIPHER/`, by Benny)
Pure utility library: `CIPHER_CompareString` (lexicographic compare via `toArray`) and `CIPHER_Sort` (selection sort), used by list-building UI code. **No network or gameplay side effects** — safe to call anywhere.

## Notes for hardening / review
- Module **gates** are config constants (`WFBE_C_MODULE_WFBE_*`) read at boot; toggling them is the supported on/off switch.
- Combat modules such as IRS/CM/Engines attach their EHs or actions at **unit creation** in `Client/Functions/Client_BuildUnit.sqf`, so they are client-local on the buyer's machine — consistent with the factory locality model (DR-33). Reaktiv is different: current source evidence shows a compiled damage handler, but no live attachment point outside `Common/Module/Reaktiv/`.
- The only module with a dedicated authority finding is **Nuke/ICBM** (DR-27); the rest are cosmetic/QoL or AI behavior with no client-to-server trust surface beyond the shared PVF dispatcher.

## Continue Reading

Conventions: [Variable and naming conventions](Variable-And-Naming-Conventions) | Function index: [Function and module index](Function-And-Module-Index) | Findings: [Deep-review findings](Deep-Review-Findings)
