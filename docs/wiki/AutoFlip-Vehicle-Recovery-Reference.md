# AutoFlip Vehicle Recovery Reference

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

This page documents the live AutoFlip vehicle recovery module and the separate manual **Flip Vehicle** action. AutoFlip is a client-started watcher: client init starts `Client\Module\AutoFlip\AutoFlip.sqf` after WASP base/action setup, and the watcher only evaluates while the player is alive and the game is not over (`Client/Init/Init_Client.sqf:647-653`; `Client/Module/AutoFlip/AutoFlip.sqf:75-100`).

## Runtime Route

| Step | Source-backed behavior |
| --- | --- |
| Client startup | Client init starts AutoFlip with `[] execVM "Client\Module\AutoFlip\AutoFlip.sqf"` (`Client/Init/Init_Client.sqf:652-653`). |
| Scan cadence | The watcher sleeps `_scanDelay = 3` seconds between scans (`Client/Module/AutoFlip/AutoFlip.sqf:9,75-76`). |
| Live guard | A scan runs only when `alive player && !gameOver` is true (`Client/Module/AutoFlip/AutoFlip.sqf:78`). |
| Watched vehicles | The scan adds the player's current vehicle when the player is mounted, then adds mounted vehicles used by units in the player's group while avoiding duplicates (`Client/Module/AutoFlip/AutoFlip.sqf:79-99`). |
| Per-vehicle worker | Each watched vehicle is passed to `_processVehicle` with the current `time` value (`Client/Module/AutoFlip/AutoFlip.sqf:16-20,95-99`). |

## Automatic Flip Gates

The automatic path only starts a stuck timer when every gate below passes.

| Gate | Required value | Source |
| --- | --- | --- |
| Vehicle exists and is alive | Null or dead vehicles exit immediately. | `Client/Module/AutoFlip/AutoFlip.sqf:22-23` |
| Vehicle type | Motorcycles, air vehicles and ships are excluded. | `Client/Module/AutoFlip/AutoFlip.sqf:25-26` |
| Tilt | `(vectorUp _vehicle) select 2` must be below `_tiltLimit = 0.35`. | `Client/Module/AutoFlip/AutoFlip.sqf:10,28,33,39` |
| Speed | Computed 3D speed must be below `_maxSpeed = 2`. | `Client/Module/AutoFlip/AutoFlip.sqf:13,29-34,40` |
| Height above ground | `getPos _vehicle select 2` must be below `3`. | `Client/Module/AutoFlip/AutoFlip.sqf:35,41` |
| Surface | `surfaceIsWater` must be false. | `Client/Module/AutoFlip/AutoFlip.sqf:36,42` |
| Cooldown | `time - WFBE_AutoFlip_LastFlip` must be greater than `_cooldown = 45`. | `Client/Module/AutoFlip/AutoFlip.sqf:12,31,37,43` |
| Stuck duration | After a vehicle first passes the gates, it must stay eligible for `_stuckDelay = 10` seconds before righting. | `Client/Module/AutoFlip/AutoFlip.sqf:11,45-55` |

Failed tilt, speed, height, water or cooldown gates reset `WFBE_AutoFlip_StuckSince` to `-1`, so the ten-second stuck timer restarts after the vehicle leaves and re-enters the eligible state (`Client/Module/AutoFlip/AutoFlip.sqf:39-43,45-55`).

## Righting Operation

| Result | Source-backed behavior |
| --- | --- |
| Vehicle orientation | AutoFlip sets the vehicle upright with `setVectorUp [0,0,1]` (`Client/Module/AutoFlip/AutoFlip.sqf:57-58`). |
| Vehicle position | AutoFlip keeps the current X/Y position and moves the vehicle to Z `0.5` (`Client/Module/AutoFlip/AutoFlip.sqf:57-59`). |
| Vehicle velocity | AutoFlip sets velocity to `[0,0,-0.5]` after repositioning (`Client/Module/AutoFlip/AutoFlip.sqf:60`). |
| Cooldown marker | AutoFlip writes `WFBE_AutoFlip_LastFlip` with public flag `true`, then clears `WFBE_AutoFlip_StuckSince` locally with public flag `false` (`Client/Module/AutoFlip/AutoFlip.sqf:61-62`). |
| Client notification | The local watcher resolves the vehicle display name, localizes `STR_WF_INFO_AutoFlip_Righted`, falls back to an English template if the localization is empty, and sends `systemChat` (`Client/Module/AutoFlip/AutoFlip.sqf:64-68`; `stringtable.xml:9540-9547`). |
| Debug logging | With `WF_Debug`, AutoFlip logs both the initial tracking state and the final righting event (`Client/Module/AutoFlip/AutoFlip.sqf:50-52,70-72`). |

## Manual Flip Action

Manual **Flip Vehicle** is a separate on-demand path. It is added to tanks and cars from `Init_Unit.sqf`, appears only when the target's `vectorUp` Z value is below `0.35` and the target is within `10` meters of the player, and calls `WASP\actions\FlipVehicle.sqf` (`Common/Init/Init_Unit.sqf:71-84`).

| Surface | Automatic AutoFlip | Manual Flip Vehicle |
| --- | --- | --- |
| Startup | Starts from client init and keeps looping (`Client/Init/Init_Client.sqf:652-653`; `Client/Module/AutoFlip/AutoFlip.sqf:75-100`). | Added as a per-vehicle action on tank and car init paths (`Common/Init/Init_Unit.sqf:71-84`). |
| Target selection | Watches the player's vehicle plus vehicles used by units in the player's group (`Client/Module/AutoFlip/AutoFlip.sqf:79-99`). | Runs on the addAction target vehicle (`WASP/actions/FlipVehicle.sqf:9-12`). |
| Delay and cooldown | Requires the stuck timer and cooldown gates (`Client/Module/AutoFlip/AutoFlip.sqf:11-12,45-55`). | The script comment says it bypasses AutoFlip's stuck timer and cooldown, and the script only checks null/alive before righting (`WASP/actions/FlipVehicle.sqf:1-19`). |
| Righting technique | Uses `setVectorUp`, `setPos` and `setVelocity` (`Client/Module/AutoFlip/AutoFlip.sqf:57-60`). | Uses the same `setVectorUp`, `setPos` and `setVelocity` shape (`WASP/actions/FlipVehicle.sqf:16-19`). |

Do not confuse either vehicle-righting path with Valhalla low gear. Valhalla's low-gear actions are adjacent tank/car actions that call `Client\Module\Valhalla\LowGear_Toggle.sqf` and gate on driver/vehicle state, not tilt recovery (`Common/Init/Init_Unit.sqf:71-84`).

## Practical Limits

| Limit | Source-backed meaning |
| --- | --- |
| Not map-wide cleanup | AutoFlip only scans the player's mounted vehicle and mounted vehicles used by units in the player's group, not every abandoned vehicle on the map (`Client/Module/AutoFlip/AutoFlip.sqf:79-99`). |
| Not for air, ships or motorcycles | The automatic worker exits for `Motorcycle`, `Air` and `Ship`, while the manual action is only attached in the tank and car init blocks (`Client/Module/AutoFlip/AutoFlip.sqf:25-26`; `Common/Init/Init_Unit.sqf:71-84`). |
| Not a water recovery feature | The automatic worker exits when `surfaceIsWater` is true (`Client/Module/AutoFlip/AutoFlip.sqf:36,42`). |
| Local notification only | The notification comment says it is sent only to the client whose watcher actually rights the vehicle, and the implementation uses `systemChat` inside that local script (`Client/Module/AutoFlip/AutoFlip.sqf:64-68`). |

## Continue Reading

- [Modules atlas](Modules-Atlas)
- [WASP overlay](WASP-Overlay)
- [Player vehicle/travel actions](Player-Vehicle-And-Travel-Actions-Reference)
- [Valhalla vehicle climbing assist](Valhalla-Vehicle-Climbing-Assist)
- [Player UI workflow map](Player-UI-Workflow-Map)
