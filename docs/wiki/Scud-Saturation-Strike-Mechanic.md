# SCUD Saturation Strike (naval-HVT payoff weapon)

> Source-verified 2026-06-23 against master f8a76de3. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

The SCUD Saturation Strike is a player-callable, pilotless ballistic barrage. Owning an offshore oil-platform naval HVT lets a team spend funds to fire one missile from the platform; on arrival it MIRV-splits a mixed warhead saturation over the player-chosen target zone. It is the payoff reward for the naval HVT objective — for the platform itself and how a team comes to own one, see [Naval HVT Objectives Atlas](Naval-HVT-Objectives-Atlas); this page documents only the strike weapon.

The whole feature is behind the master gate `WFBE_C_NAVAL_HVT` (default `1`). With the gate at `0`, `KAT_ScudStrike` is never compiled, the `ScudStrike` case logs a `WARNING` and no-ops, and the strike helper exits immediately (`Server/Init/Init_Server.sqf:53-56`, `Server/Functions/Server_HandleSpecial.sqf:70-74`, `Server/Support/Support_ScudStrike.sqf:15-17`).

## Tunable Numbers

All five tunables live in the `WFBE_C_SCUD_*` block, set once if nil during constant init.

| Constant | Value | Meaning | Source |
| --- | --- | --- | --- |
| `WFBE_C_SCUD_COST` | `25000` | Server-validated funds cost, debited from the calling team's `wfbe_funds` | `Common/Init/Init_CommonConstants.sqf:946` |
| `WFBE_C_SCUD_COOLDOWN` | `300` | Per-platform cooldown, seconds | `Common/Init/Init_CommonConstants.sqf:947` |
| `WFBE_C_SCUD_ZONE_RADIUS` | `300` | Target acquisition / saturation radius, metres | `Common/Init/Init_CommonConstants.sqf:948` |
| `WFBE_C_SCUD_WARHEAD_HE` | `"Sh_125_HE"` | HE area-burst round (even-phase warheads) | `Common/Init/Init_CommonConstants.sqf:953` |
| `WFBE_C_SCUD_WARHEAD_SADARM` | `"Bo_GBU12_LGB"` | Top-attack precision round (odd-phase warheads) | `Common/Init/Init_CommonConstants.sqf:954` |
| `WFBE_C_SCUD_WARHEAD_WP` | `"SmokeShellWhite"` | WP / incendiary smoke layer (final phase) | `Common/Init/Init_CommonConstants.sqf:955` |

The warhead block carries a `NEEDS REVIEW` comment instructing a live RPT check that all three classnames `createVehicle` cleanly on first test (`Common/Init/Init_CommonConstants.sqf:951-952`). For the catalog-wide view of these constants see [Mission Tunable Constants Catalog](Mission-Tunable-Constants-Catalog).

## Request Route

The strike is requested from the client and dispatched server-side through the standard `RequestSpecial`/`HandleSpecial` router. The naval-HVT scroll action runs a local affordance check, then a map-click handler sends the request.

| Stage | Behaviour | Source |
| --- | --- | --- |
| Local pre-check | Action reads `WFBE_C_SCUD_COST`, compares against `(group _caller) getVariable ["wfbe_funds",0]`, and hints `STR_WF_SCUD_NO_FUNDS` if short | `Server/Init/Init_NavalHVT.sqf:235-237` |
| Target select | Hints `STR_WF_SCUD_SELECT_TARGET`, `openMap true`, installs `onMapSingleClick` | `Server/Init/Init_NavalHVT.sqf:238-241` |
| Send | On click: `["RequestSpecial", ["ScudStrike", playerSide, _pos, group player]] Call WFBE_CO_FNC_SendToServer`, hints `STR_WF_SCUD_LAUNCHED` | `Server/Init/Init_NavalHVT.sqf:243-244` |
| Router case | `Server_HandleSpecial.sqf` `case "ScudStrike"`: if `KAT_ScudStrike` is defined, `_args spawn KAT_ScudStrike`; else log a `WARNING` | `Server/Functions/Server_HandleSpecial.sqf:69-75` |
| Compile | `KAT_ScudStrike = Compile preprocessFile "Server\Support\Support_ScudStrike.sqf"` — only when `WFBE_C_NAVAL_HVT == 1` | `Server/Init/Init_Server.sqf:53-56` |

The payload shape consumed by the helper is `["ScudStrike", _side, _destination, _playerTeam]` (`Server/Support/Support_ScudStrike.sqf:6,23-25`). The client-side `_funds`/`_cost` gate is UX only; the funds debit, cooldown stamp and ownership check are all re-done server-side (next section). For the router and PVF binding internals defer to [Server HandleSpecial Request Router Reference](Server-HandleSpecial-Request-Router-Reference).

## Validation / Affordability / Cooldown Gate

`Support_ScudStrike.sqf` runs server-only and rejects the request before firing if any gate fails. Funds are debited and the cooldown stamped **before** the missile is created, closing the double-fire race.

| Gate | Rule | On failure | Source |
| --- | --- | --- | --- |
| Server-only | `if (!isServer) exitWith {}` | silent | `Server/Support/Support_ScudStrike.sqf:14` |
| Feature flag | `WFBE_C_NAVAL_HVT` must equal `1` | `INFORMATION` log, exit | `Server/Support/Support_ScudStrike.sqf:15-17` |
| 1. Ownership | Caller's side must own a registered platform: scan `WFBE_NAVAL_HVT_PLATFORMS` for a non-null entry whose `sideID == _sideID` and `wfbe_is_naval_hvt`; reject if none | `INFORMATION` "no owned oil platform", exit | `Server/Support/Support_ScudStrike.sqf:36-43` |
| 2. Cooldown | Per-platform key `WFBE_SCUD_LAST_<platform>`; reject while `(time - _lastFired) < WFBE_C_SCUD_COOLDOWN` | `INFORMATION` "cooldown (Ns left)", exit | `Server/Support/Support_ScudStrike.sqf:46-50` |
| 3a. Null team | `_playerTeam` must not be null | `WARNING` "null calling team", exit | `Server/Support/Support_ScudStrike.sqf:53` |
| 3b. Funds | `_playerTeam getVariable ["wfbe_funds",0]` must be `>= WFBE_C_SCUD_COST` | `INFORMATION` "insufficient funds", exit | `Server/Support/Support_ScudStrike.sqf:54-57` |
| Commit | Debit `wfbe_funds -= WFBE_C_SCUD_COST` (broadcast), stamp `WFBE_SCUD_LAST_<platform> = time` | proceed to launch | `Server/Support/Support_ScudStrike.sqf:60-61` |

`_sideID` comes from `_side call GetSideID` (`Server/Support/Support_ScudStrike.sqf:26`; `GetSideID` compiled at `Common/Init/Init_Common.sqf:41`). The default `_lastFired` is `-99999`, so an as-yet-unfired platform always clears the cooldown gate.

## Launch / Ballistic Flight

The missile is a single `Chukar_EP1` flown as a pure velocity vector — no AI pilot, mirroring the ICBM module rather than the piloted drone strike (`Server/Support/Support_ScudStrike.sqf:1-5`).

| Step | Detail | Source |
| --- | --- | --- |
| Spawn point | Launch position is the platform's `getPos` X/Y at altitude `350` | `Server/Support/Support_ScudStrike.sqf:67,75` |
| Aim vector | `_dx`/`_dy` to destination, normalised by `_len = sqrt(_dx^2+_dy^2)` (floored to `1`) | `Server/Support/Support_ScudStrike.sqf:68-72` |
| Create | `createVehicle ["Chukar_EP1", _launchPos, [], 0, "FLY"]`, then `setPosASL` at `350` | `Server/Support/Support_ScudStrike.sqf:74-75` |
| Velocity | `setVectorDir` along the aim vector; `setVelocity` at `140` m/s along that vector (flat, Z=0) | `Server/Support/Support_ScudStrike.sqf:76-77` |
| Cruise | `flyInHeight 350`, `setSpeedMode "FULL"` | `Server/Support/Support_ScudStrike.sqf:78-79` |
| GC exempt | `setVariable ["wfbe_naval_cap", true, true]` so group/vehicle garbage-collection leaves the missile alone | `Server/Support/Support_ScudStrike.sqf:80` |
| Travel time | `_travelTime = ((_dist / 140) min 30) max 4` — clamped to 4-30 s | `Server/Support/Support_ScudStrike.sqf:82` |
| Attribution | `_caller = leader _playerTeam` (used to attribute SADARM kills) | `Server/Support/Support_ScudStrike.sqf:83` |

No enemy warning is broadcast on launch (`Server/Support/Support_ScudStrike.sqf:5`). Enemy sides for target acquisition are derived once as `(WFBE_PRESENTSIDES - [_side]) + [resistance]` (`Server/Support/Support_ScudStrike.sqf:66`; `WFBE_PRESENTSIDES` set at `Common/Init/Init_Common.sqf:293`).

## MIRV Split / Warhead Barrage

After launch the strike forks a `spawn` thread holding the missile, destination, zone radius, three warhead classes, enemy-side list, caller and travel time (`Server/Support/Support_ScudStrike.sqf:86-97`). It `sleep`s the travel time, then delivers the barrage in three phases over the zone before deleting the missile.

| Phase | Count | Round | Placement | Source |
| --- | --- | --- | --- | --- |
| Acquire | — | — | `nearestObjects [_dest, ["LandVehicle","StaticWeapon"], _zoneR]` filtered to alive enemy non-`Air` `LandVehicle`/`StaticWeapon` into `_armour` | `Server/Support/Support_ScudStrike.sqf:101-107` |
| SADARM | 2 | `Bo_GBU12_LGB` | Top-attack at altitude `120` over the two best `_armour` targets (stamps `wfbe_lasthitby` = `_caller`, `wfbe_lasthittime` = `time`); if fewer than 2 exist, scatter at random angle within `0.6 * _zoneR`; `sleep 0.4` between | `Server/Support/Support_ScudStrike.sqf:109-120` |
| HE | 3 | `Sh_125_HE` | Ground bursts at random angle, radius `random _zoneR`; `sleep 0.3` between | `Server/Support/Support_ScudStrike.sqf:122-127` |
| WP | 3 | `SmokeShellWhite` | Ground bursts at random angle within `0.7 * _zoneR`; `sleep 0.2` between | `Server/Support/Support_ScudStrike.sqf:129-134` |
| Cleanup | — | — | Log `saturation delivered (N armour targets)`, then `deleteVehicle` the missile crew and the `Chukar` | `Server/Support/Support_ScudStrike.sqf:136-138` |

Each warhead is dropped with `createVehicle` (e.g. `_warHE createVehicle [...]`), the A2-valid spawn form, so detonation is the engine's ammo behaviour, not a scripted damage call. The total saturation is 8 warheads (2 SADARM + 3 HE + 3 WP) staggered across roughly 2 seconds of placement sleeps after impact.

## Contrast With the ICBM Module

Both are pilotless server-fired ordnance, but they are separate systems. The ICBM module trusts a client-supplied impact object and applies scripted map-wide `NukeDammage`, with affordability checked only client-side; the SCUD re-validates ownership, funds and cooldown server-side and delivers a zone-bounded engine-ammo barrage. See [ICBM Authority Playbook](ICBM-Authority-Playbook) for that module's trust boundary, and [Arty Module Special Munitions](Arty-Module-Special-Munitions) for the related artillery round set.

## Continue Reading

- [Naval HVT Objectives Atlas](Naval-HVT-Objectives-Atlas)
- [Server HandleSpecial Request Router Reference](Server-HandleSpecial-Request-Router-Reference)
- [ICBM Authority Playbook](ICBM-Authority-Playbook)
- [Arty Module Special Munitions](Arty-Module-Special-Munitions)
- [Mission Tunable Constants Catalog](Mission-Tunable-Constants-Catalog)
