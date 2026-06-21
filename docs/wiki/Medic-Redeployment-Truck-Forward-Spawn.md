# Medic Redeployment Truck (Forward Spawn)

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

The medic redeployment truck is an experimental forward-spawn vehicle gated by `WFBE_C_UNITS_REDEPLOYTRUCK` (Common/Init/Init_CommonConstants.sqf:580). It is a mobile respawn point that **only Medics** may spawn at: a medic buys the truck, drives it forward, parks it, and any medic on the same side who dies can choose it as a respawn location from the death menu. It is a sibling of the older mobile-ambulance respawn (`WFBE_%1AMBULANCES`) but rides on its own faction array, its own class gate, and a stricter activation contract (stationary + engine-off + a 500 m enemy-town exclusion). The surrounding respawn-menu flow lives in the [Respawn and Death Lifecycle Atlas](Respawn-And-Death-Lifecycle-Atlas), which documents the mobile ambulance but does **not** cover this truck.

## Activation contract (when the truck is offered as a spawn)

Evaluated client-side in `Client_GetRespawnAvailable.sqf` every time the respawn menu rebuilds its location list (re-evaluated roughly once per second while the menu is open). The block is entered only when the feature constant is on **and** the local player's own class is Medic.

| Gate | Condition | Citation |
|------|-----------|----------|
| Feature on | `WFBE_C_UNITS_REDEPLOYTRUCK > 0` (defaults to `1`) | Client/Functions/Client_GetRespawnAvailable.sqf:54; Common/Init/Init_CommonConstants.sqf:580 |
| Medic-only | `WFBE_SK_V_Type == "Medic"` (the local player's own class) | Client/Functions/Client_GetRespawnAvailable.sqf:54 |
| Candidate set | trucks of side from `WFBE_%1REDEPLOYTRUCKS`, scanned via `_deathLoc nearEntities [_redeployTrucks,_range]` | Client/Functions/Client_GetRespawnAvailable.sqf:55-58 |
| In range | within the respawn range selected by the side's `WFBE_UP_RESPAWNRANGE` upgrade index into `WFBE_C_RESPAWN_RANGES` (`[250, 350, 500]` m) | Client/Functions/Client_GetRespawnAvailable.sqf:56-57; Common/Init/Init_CommonConstants.sqf:44, 454 |
| Free seat | `_veh emptyPositions "cargo" > 0` | Client/Functions/Client_GetRespawnAvailable.sqf:65 |
| Stationary | `abs(speed _veh) < 1` | Client/Functions/Client_GetRespawnAvailable.sqf:66 |
| Engine off | `!(isEngineOn _veh)` | Client/Functions/Client_GetRespawnAvailable.sqf:67 |
| Town exclusion | not within **500 m** of any town whose `sideID` differs from the spawning side (enemy-held or contested) | Client/Functions/Client_GetRespawnAvailable.sqf:68-74 |

The town-exclusion loop walks the global `towns` list, reads each town's `sideID` (default `-1`), and trips a `_tooClose` flag if any non-friendly town is inside 500 m of the truck; the truck is added to `_availableSpawn` only when `_tooClose` is false (Client/Functions/Client_GetRespawnAvailable.sqf:69-77). Because the menu re-evaluates continuously, a truck that starts moving, has its engine restarted, fills its cargo, or drifts within 500 m of a hostile town simply drops off the list on the next pass — there is no separate timer.

The source carries a design note that the Medic gate is the *binding* purchase restriction: `MTVR`/`Kamaz` are ordinary transports too, so restricting the **buy** menu by class would deny transport access to non-medics; the binding rule is the spawn-side class check, not a purchase block (Client/Functions/Client_GetRespawnAvailable.sqf:47-53).

## Per-faction classnames (`WFBE_%1REDEPLOYTRUCKS`)

The truck array is seeded per side in the Core_Root config. The side string is `"WEST"`/`"EAST"` (the `_side` value the Root file runs under), so the live variable is `WFBE_WESTREDEPLOYTRUCKS` / `WFBE_EASTREDEPLOYTRUCKS`.

| Root file | Side | Classname(s) | Citation |
|-----------|------|--------------|----------|
| Root_US.sqf | WEST | `MTVR_DES_EP1` (desert MTVR) | Common/Config/Core_Root/Root_US.sqf:14 |
| Root_RU.sqf | EAST | `Kamaz` | Common/Config/Core_Root/Root_RU.sqf:14 |
| Root_US_Camo.sqf (Chernarus map-variant) | WEST | `MTVR` (vanilla A2) | Common/Config/Core_Root/Root_US_Camo.sqf:15 |

The Chernarus US side uses the vanilla-A2 `MTVR` rather than the desert `MTVR_DES_EP1` used by the default WEST root. The source flags this divergence as **intentional** (a map-variant split), so it is not a bug to "fix" toward one classname (Common/Config/Core_Root/Root_US_Camo.sqf:15). The array is read with a `[]` default everywhere it is consumed, so a faction with no entry simply offers no redeploy truck rather than erroring.

## Buy-menu treatment

When the feature is on, `Client_UIFillListBuyUnits.sqf` recolors and relabels any buy-menu row whose classname is in the side's `WFBE_%1REDEPLOYTRUCKS` array. This is the only purchase-side change — the row appears wherever the vehicle's own config category places it (the in-game help and briefing both describe it as a **Light Factory** purchase).

| Aspect | Value | Citation |
|--------|-------|----------|
| Row tint (RGBA) | `[0.7, 0.4, 1.0, 0.6]` (violet) | Client/Functions/Client_UIFillListBuyUnits.sqf:122 |
| Row label suffix | `<description> + " [Medic Redeploy,Spawn]"` | Client/Functions/Client_UIFillListBuyUnits.sqf:123 |
| Gate | `WFBE_C_UNITS_REDEPLOYTRUCK > 0` | Client/Functions/Client_UIFillListBuyUnits.sqf:120 |
| Advertised factory | Light Factory, violet row | Client/GUI/GUI_Menu_Help.sqf:200; briefing.sqf:15 |

The violet tint is deliberately distinct from the neighboring vehicle highlights so the truck reads as a special at a glance: the ambulance row is yellow `[1.0, 1.0, 0.0, 0.6]` (Client/Functions/Client_UIFillListBuyUnits.sqf:114-115) and the salvage-truck row is green `[0.0, 1.0, 0.0, 0.6]` (Client/Functions/Client_UIFillListBuyUnits.sqf:128-129).

## Respawn handling (what happens when you pick it)

`Client_OnRespawnHandler.sqf` runs on the newly created player object. If the chosen spawn (`_typeof`) is a redeploy truck for the player's joined side and the vehicle is alive, the player is moved into a cargo seat rather than dropped on the ground.

| Step | Behavior | Citation |
|------|----------|----------|
| Spawn inside | if truck alive, has a free cargo seat, and is not `locked`, `_unit moveInCargo _spawn` and `_spawnInside = true` | Client/Functions/Client_OnRespawnHandler.sqf:35-37 |
| Menu label | the respawn-menu "spawn at" label is overridden to `"Redeploy Truck"` when the selected location's type is in `WFBE_%1REDEPLOYTRUCKS` | Client/GUI/GUI_RespawnMenu.sqf:99-101 |
| Default-gear force | when `WFBE_C_RESPAWN_MOBILE == 2`, spawning at a redeploy truck sets `_allowCustom = false` (custom loadout suppressed, default class gear given) | Client/Functions/Client_OnRespawnHandler.sqf:20-22 |

The default-gear rule mirrors the ambulance path: the same `WFBE_C_RESPAWN_MOBILE == 2` mode that forces default gear on ambulance respawn (Client/Functions/Client_OnRespawnHandler.sqf:16-18) also forces it on the redeploy truck (Client/Functions/Client_OnRespawnHandler.sqf:20-22). `WFBE_C_RESPAWN_MOBILE` defaults to `2` — "Enabled but default gear" (Common/Init/Init_CommonConstants.sqf:450) — so by default a redeploy-truck respawn always arrives in the medic's default kit. The `moveInCargo` step likewise parallels the ambulance handler at Client/Functions/Client_OnRespawnHandler.sqf:32-34.

## Relation to mobile respawn and the ambulance

Both the redeploy truck and the mobile ambulance are forward-spawn vehicles surfaced in the same death menu, share the same `WFBE_C_RESPAWN_RANGES` distance gate, and both honor the `WFBE_C_RESPAWN_MOBILE == 2` default-gear rule. They differ in who and how:

| | Mobile ambulance (`WFBE_%1AMBULANCES`) | Redeploy truck (`WFBE_%1REDEPLOYTRUCKS`) |
|---|---|---|
| Who may spawn | any player on the side | Medics only (`WFBE_SK_V_Type == "Medic"`) |
| Gated by | `WFBE_C_RESPAWN_MOBILE > 0` | `WFBE_C_UNITS_REDEPLOYTRUCK > 0` |
| Stationary / engine check | none (only free cargo) | requires `abs(speed) < 1` **and** engine off |
| Enemy-town exclusion | none | not within 500 m of a non-friendly town |
| Buy-menu tint | yellow `[1.0,1.0,0.0,0.6]` | violet `[0.7,0.4,1.0,0.6]` |
| Citations | Client/Functions/Client_GetRespawnAvailable.sqf:33-45; Client/Functions/Client_OnRespawnHandler.sqf:16-18, 32-34 | Client/Functions/Client_GetRespawnAvailable.sqf:54-81; Client/Functions/Client_OnRespawnHandler.sqf:20-22, 35-37 |

The ambulance block reads `WFBE_%1AMBULANCES` and only checks for an open cargo seat (Client/Functions/Client_GetRespawnAvailable.sqf:34-44); the redeploy truck is the stricter, medic-scoped forward post that must be parked and shut down in safe-ish ground. Note the redeploy truck is **not** keyed off the AMBULANCES array, so it is independent of the ambulance roster catalogued in the [Faction Root Variables Reference](Faction-Root-Variables-Reference).

## Advertised as a Medic ability (player-facing copy)

The truck is surfaced to players as a Medic class perk in several places (text only — these strings do not reference the `REDEPLOYTRUCK` variable, they describe the feature):

| Surface | Copy | Citation |
|---------|------|----------|
| Class-info action | Medic card lists "Spawn at Medic Redeployment Truck" | WASP/actions/ClassInfo.sqf:58-63 |
| Class diary record | "MEDIC - ... only class that can spawn at the Medic Redeployment Truck" | WASP/actions/AddActions.sqf:28 |
| Help menu (Other) | "Medic Redeployment Truck: medic-only forward spawn (Light Factory, violet row)" | Client/GUI/GUI_Menu_Help.sqf:200 |
| Briefing diary (Experimental Changes) | "Medics only: a forward spawn truck purchasable from the Light Factory (violet row). It activates when parked with engine off, a free cargo seat, and at least 500 m from any non-friendly town." | briefing.sqf:15 |

## Tunables

| Constant / variable | Value | Meaning | Citation |
|---------------------|-------|---------|----------|
| `WFBE_C_UNITS_REDEPLOYTRUCK` | `1` | feature toggle (experimental branch) | Common/Init/Init_CommonConstants.sqf:580 |
| `WFBE_%1REDEPLOYTRUCKS` | per-faction array | redeploy-truck classnames for the side | Common/Config/Core_Root/Root_US.sqf:14; Root_RU.sqf:14; Root_US_Camo.sqf:15 |
| `WFBE_UP_RESPAWNRANGE` | `7` | upgrade index selecting the respawn-range tier | Common/Init/Init_CommonConstants.sqf:44 |
| `WFBE_C_RESPAWN_RANGES` | `[250, 350, 500]` | range tiers (m) the truck must be within | Common/Init/Init_CommonConstants.sqf:454 |
| `WFBE_C_RESPAWN_MOBILE` | `2` | mobile-respawn mode; `2` forces default gear | Common/Init/Init_CommonConstants.sqf:450 |
| town exclusion radius | `500` (literal) | enemy/contested-town keep-out distance | Client/Functions/Client_GetRespawnAvailable.sqf:73 |

## Continue Reading

- [Respawn and Death Lifecycle Atlas](Respawn-And-Death-Lifecycle-Atlas) — the surrounding respawn-menu flow and the mobile-ambulance path this truck sits beside.
- [Faction Root Variables Reference](Faction-Root-Variables-Reference) — the `WFBE_%1AMBULANCES`/`REPAIRTRUCKS`/`SALVAGETRUCK` family of per-faction vehicle arrays.
- [Player Skill Abilities Reference](Player-Skill-Abilities-Reference) — the Medic class and its other abilities (fast healing, camp restore).
- [Factory and Purchase Systems Atlas](Factory-And-Purchase-Systems-Atlas) — how factory buy rows are built and colored.
