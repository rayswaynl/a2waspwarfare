# Supply Missions (mechanics and reward reference)

> Source-verified 2026-06-21 against then-current master cf2a6d6a4; current origin/master is 0139a346, so recheck cited paths before current-head claims. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

Supply missions are the primary way non-commander players inject **team supply** directly into the economy. Only the **SpecOps** role has the scroll-menu actions to load and deliver supplies. A single successful run on a high-SV town can move the side's supply total more than several minutes of passive income.

---

## Role requirement

The `LOAD SUPPLIES` and `UNLOAD SUPPLIES` scroll actions are added exclusively to the SpecOps class in `Client/Module/Skill/Skill_Apply.sqf:50-70`. No other role receives them.

---

## Reading the map — what [+SUPPLY] means

Town markers on the map show `SV: <current>/<max>`. When a town is eligible for a supply run the marker text changes:

| You are playing | Marker text (cooldown OFF) | Marker text (cooldown ON) |
|---|---|---|
| SpecOps | `SV: 40/100  [+SUPPLY]` | `SV: 40/100  [MM:SS]` |
| Any other role | `SV: 40/100  [+]` | `SV: 40/100` |

The `[+SUPPLY]` label is set by `Client/FSM/updatetownmarkers.sqf:24-25` and is SpecOps-gated because only SpecOps can act on it. When cooldown is active — `supplyMissionCoolDownEnabled == true` on the town object — the `[+SUPPLY]` suffix is replaced by a live `[MM:SS]` countdown for SpecOps players (`updatetownmarkers.sqf:46-58`); non-SpecOps roles see the plain `SV: 40/100` with no suffix (`updatetownmarkers.sqf:60`). A town with no suffix cannot be collected from until the 30-minute cooldown expires (see [Cooldown](#cooldown) below).

---

## Truck supply run — step by step

1. **Pick a [+SUPPLY] town.** Drive your supply truck to the town center (near the main depot). Stay on foot — you must be dismounted.
2. **Check distance.** The action condition requires `player distance (call GetClosestFriendlyLocation) < 70` (`Skill_Apply.sqf:58`). The script itself enforces a stricter `_cursorTarget distance player < 50` at load time (`supplyMissionStart.sqf:53`). If you are over 50 m from the truck when you trigger the action the run will not start.
3. **Aim at an empty supply truck and scroll LOAD SUPPLIES.** The truck must be of a type in `WFBE_C_SUPPLY_TRUCK_TYPES` (see [Vehicle types](#vehicle-types)) and must not already be loaded (`SupplyAmount == 0`) or in the middle of loading (`SupplyLoading == false`).
4. **Drive to your Command Center** (marked **C** on the map). The server loop in `Server/Module/supplyMission/supplyMissionStarted.sqf:47-106` checks every second whether a `Base_WarfareBUAVterminal` object is within **80 m** of the truck (`supplyMissionStarted.sqf:59`).
5. **Delivery is automatic for trucks.** The moment the proximity check passes, the server resolves the delivering player and fires `WFBE_Server_PV_SupplyMissionCompleted`. No scroll action is needed.

---

## Helicopter supply run — additional steps

Helicopter supply requires the **Aircraft Factory upgraded to level 3** (`WFBE_UP_AIR >= 3`, checked at `supplyMissionStart.sqf:29,40`). The eligible helicopter classes on Chernarus are `MH60S` (WEST) and `Mi17_Ins` (EAST) (`Init_CommonConstants.sqf:181`). This feature can be disabled by the lobby parameter `WFBE_C_SUPPLY_HELI_ENABLED`; when set to anything other than `1`, `WFBE_C_SUPPLY_HELI_TYPES` is emptied and the helicopter option disappears entirely (`Init_CommonConstants.sqf:182-183`).

**Loading:**
- Exit the helicopter and stand within **15 m** of it (`supplyMissionStart.sqf:71`). Entering a vehicle or moving beyond 15 m cancels the load.
- Trigger `LOAD SUPPLIES` while aiming at the helicopter. A channeled 15-second timer runs (`WFBE_C_SUPPLY_HELI_LOAD_TIME = 15` at `Init_CommonConstants.sqf:176`).
- The on-screen counter shows `Loading supplies into the helicopter...  X / 15 s` during the wait (`supplyMissionStart.sqf:72`).
- The town cooldown is set immediately when loading begins for a helicopter and is rolled back if loading is cancelled (`supplyMissionStart.sqf:56,92`).

**Delivery:**
- Fly to the Command Center. The server checks horizontal distance (altitude is ignored for helicopters) against a 80 m 2D radius (`supplyMissionStarted.sqf:55-57`); the search radius for the terminal scan is extended to **400 m** for helicopters (`supplyMissionStarted.sqf:59`).
- Once in range, scroll `UNLOAD SUPPLIES`. A second 15-second channeled timer runs (`WFBE_C_SUPPLY_HELI_UNLOAD_TIME = 15` at `Init_CommonConstants.sqf:177`). Keep the helicopter alive and below **35 m altitude** (`supplyMissionUnload.sqf:56`).
- If the unload completes, `supplyMissionUnload.sqf:68-69` fires the same `WFBE_Server_PV_SupplyMissionCompleted` signal as the truck path.

---

## Payload formula

The supply amount loaded into the vehicle is calculated client-side at trigger time:

```
_supplyAmount = floor ((_sourceTown getVariable "supplyValue") * WFBE_C_ECONOMY_SUPPLY_MISSION_MULTIPLIER * _supplyUpgradeModifier)
```
`supplyMissionStart.sqf:61`

| Constant | Value | Source |
|---|---|---|
| `WFBE_C_ECONOMY_SUPPLY_MISSION_MULTIPLIER` | `20` | `Init_CommonConstants.sqf:171` |
| `_supplyUpgradeModifier` at Supply Rate upgrade 0–1 | `1.0` | `supplyMissionStart.sqf:58` |
| `_supplyUpgradeModifier` at Supply Rate upgrade 2 | `1.5` | `supplyMissionStart.sqf:60` |
| `_supplyUpgradeModifier` at Supply Rate upgrade 3+ | `2.0` | `supplyMissionStart.sqf:59` |

`supplyValue` is the town's current SV at the moment of loading. A town at SV 40 with no Supply Rate upgrade yields `floor(40 × 20 × 1) = 800 S`.

---

## Reward to the delivering player

Reward is applied client-side when `WFBE_Server_PV_SupplyMissionCompletedMessage` is received by the delivering player's machine (`supplyMissionCompletedMessage.sqf:20-23`).

| Delivery type | Cash reward | Score gain |
|---|---|---|
| Truck | `_supplyAmount` (e.g. `$800`) | `round(_supplyAmount / 100 × 1.5)` |
| Helicopter (Air level 3) | `round(_supplyAmount × 1.25)` | Same formula × 1.25 |

Constants: `WFBE_C_SUPPLY_HELI_REWARD_MULT = 1.25` (`Init_CommonConstants.sqf:173`); `WFBE_SUPPLY_MISSION_SCORE_COEF = 1.5` (`Init_CommonConstants.sqf:197`). Score gain is from `supplyMissionCompletedMessage.sqf:30-32`.

### Cash run (Air level 4)

When Air factory is upgraded to **level 4**, a helicopter delivery becomes a **cash run** (`supplyMissionCompleted.sqf:29`). Instead of adding supply to the team pool, the commander's funds receive a tithe:

```
commander team funds += round(_supplyAmount × 1.25 × 0.20)
```

The commander cut is `WFBE_C_SUPPLY_CASHRUN_COMMANDER_CUT = 0.20` (`Init_CommonConstants.sqf:174`). The delivering pilot still receives their full 1.25× cash reward (`supplyMissionCompletedMessage.sqf:17,21`). The side supply pool is **not** incremented on a cash run (`supplyMissionCompleted.sqf:33-41`).

---

## What happens to the team supply

For non-cash-run deliveries, `ChangeSideSupply` is called server-side with the full `_supplyAmount` (`supplyMissionCompleted.sqf:40`). The side supply pool is capped at `WFBE_C_MAX_ECONOMY_SUPPLY_LIMIT = 40000` and `WFBE_C_ECONOMY_SUPPLY_MAX_TEAM_LIMIT = 50000` (`Init_CommonConstants.sqf:164,170`).

---

## Cooldown

Each town has a **30-minute cooldown** after a supply run. The interval is `WFBE_CO_VAR_SupplyMissionRegenInterval = 1800` seconds (`Common/Init/Init_Common.sqf:203`). The cooldown is stored as `LastSupplyMissionRun` on the town object and compared against `time` by `Server/Module/supplyMission/isSupplyMissionActiveInTown.sqf:8,12`. When the cooldown is active the town marker loses its `[+SUPPLY]` suffix and attempting to load produces:

> *This town doesn't have enough supplies to be collected yet! You can start a supply mission in towns that have [+SUPPLY] added after their SV on map.*

(`supplyMissionStart.sqf:13`)

The cooldown resets automatically via `Server/Module/supplyMission/supplyMissionTimerForTown.sqf`, which sleeps for the interval and then broadcasts `WFBE_Server_PV_IsSupplyMissionActiveInTown` with `false`.

---

## Interdiction — enemy reward for a kill

If an enemy destroys a **loaded** supply vehicle (truck or helicopter), the killer's side receives **25% of the cargo** as supply (`WFBE_C_SUPPLY_INTERDICTION_CUT = 0.25`, `Init_CommonConstants.sqf:175`). This is handled by a `Killed` event handler attached to the vehicle at mission start (`supplyMissionStarted.sqf:15-30`). Only genuine enemy kills qualify; friendly fire does not trigger it (`supplyMissionStarted.sqf:24`).

---

## Vehicle types

### Trucks (always eligible)

All classnames are defined in `WFBE_C_SUPPLY_TRUCK_TYPES` (`Init_CommonConstants.sqf:179`):

| Classname | Faction |
|---|---|
| `WarfareSupplyTruck_USMC` | WEST (USMC) |
| `WarfareSupplyTruck_RU` | EAST (RU) |
| `WarfareSupplyTruck_INS` | INS |
| `WarfareSupplyTruck_Gue` | GUER |
| `WarfareSupplyTruck_CDF` | CDF |
| `UralSupply_TK_EP1` | TK (Takistan) |
| `MtvrSupply_DES_EP1` | USMC Desert EP1 |

### Helicopters (Air upgrade ≥ 3 required)

Defined in `WFBE_C_SUPPLY_HELI_TYPES` at `Init_CommonConstants.sqf:181`. On Chernarus (`IS_chernarus_map_dependent`):

| Classname | Side |
|---|---|
| `MH60S` | WEST (USMC) |
| `Mi17_Ins` | EAST |

---

## Common error messages

| Message | Cause | Fix |
|---|---|---|
| *This town doesn't have enough supplies to be collected yet!* | Town is on cooldown (`supplyMissionCoolDownEnabled == true`). | Wait for `[+SUPPLY]` to reappear (up to 30 min). |
| *Aim at an empty supply truck, or at an empty supply helicopter once Aircraft Factory is level 3.* | `cursorTarget` is null. | Aim directly at the vehicle before scrolling. |
| *Supply helicopters need the Aircraft Factory upgraded to level 3.* | Air upgrade level is below 3. | Wait for the commander to research Air level 3. |
| *This supply vehicle is already loaded with S X.* | `SupplyAmount > 0` on the vehicle. | Deliver the existing load first. |
| *Your supply vehicle is too far away to collect the supply from this town!* | Distance to vehicle exceeds 50 m. | Move closer to the truck before using the action. |
| *Exit the helicopter and stay outside for 15 seconds while supplies are loaded.* | Player is inside a vehicle when triggering heli load. | Exit the helicopter, then trigger the action on foot. |
| *Loading cancelled — you moved too far away from the helicopter.* | Moved more than 15 m during the heli load timer. | Stay within 15 m of the helicopter for the full 15-second window. |
| *Land or hover within 80m horizontal distance of your Command Center to unload supplies.* | Helicopter is not within 80 m (2D) of a `Base_WarfareBUAVterminal`. | Fly closer to the Command Center and re-trigger UNLOAD SUPPLIES. |

All messages sourced from `supplyMissionStart.sqf:11-101` and `supplyMissionUnload.sqf:33-65`.

---

## Continue Reading

- [Supply-Mission-Architecture](Supply-Mission-Architecture) — server state ownership, PVF flow, cooldown defects and authority hardening notes
- [Economy-Towns-And-Supply](Economy-Towns-And-Supply) — passive supply income, town SV mechanics and the supply pool
- [Upgrades-And-Research-Atlas](Upgrades-And-Research-Atlas) — full upgrade tree including `WFBE_UP_SUPPLYRATE` (index 6) and `WFBE_UP_AIR` (index 3)
- [Towns-Camps-And-Capture-Atlas](Towns-Camps-And-Capture-Atlas) — how towns are captured and SV is affected
- [Factory-And-Purchase-Systems-Atlas](Factory-And-Purchase-Systems-Atlas) — buying supply trucks and supply helicopters
