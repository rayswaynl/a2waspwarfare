# GUER Air-Defense Loop (standalone Ka-137 / Mi-24 town defenders)

> Source-verified 2026-06-23 against master f8a76de3. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

GUER ("Insurgents", `resistance`) has **no AI commander** — so it has no wildcard deck and no Commander-driven air. The GUER Air-Defense Loop (`Server/Server_GuerAirDef.sqf`, B61, Ray 2026-06-21) is therefore GUER's *only* AI air: a single server-only maintain loop that keeps one airframe orbiting over each **active, GUER-held town**, defaulting to a Ka-137 light defender, with a chance of an EASA AT-missile variant and (on large contested towns) a Mi-24_P gunship. The loop self-cleans on a global alive cap, a per-defender lifetime recycle, and a quiet-despawn when no enemies are near.

The header is explicit about provenance (`Server/Server_GuerAirDef.sqf:3-6`): the loop's shape/guards are modelled on `Server/Server_GuerStipend.sqf`, and its self-clean (crew + hull + group teardown) is modelled on the W13 GUNSHIP STRIKE block in `Server/Functions/AI_Commander_Wildcard.sqf`. Nothing the loop spawns is tagged `wfbe_persistent`, so it can never accumulate across the registry rebuild.

## Why it exists outside the playable-side gate

The loop keys entirely off **town ownership** (`sideID == WFBE_C_GUER_ID`, i.e. `2`, `Common/Init/Init_CommonConstants.sqf:32`), not off whether GUER is a playable side. A B62 fix (2026-06-21) moved its `execVM` out of the old `WFBE_C_GUER_PLAYERSIDE > 0` block — previously the loop was **dead in production** because the playable-side param is `0` (`Server/Server_GuerAirDef.sqf:37-39`, `Server/Init/Init_Server.sqf:795-801`). GUER is always the AI town-defender, so the air-def must run regardless.

## Launch wiring (`Server/Init/Init_Server.sqf`)

| Element | Detail | Source |
| --- | --- | --- |
| `AIPatrol` compile | `AIPatrol = Compile preprocessFile "Server\AI\Orders\AI_Patrol.sqf"` (the patrol order the loop calls) | `Server/Init/Init_Server.sqf:20` |
| Launch gate | `if (isServer && {(missionNamespace getVariable ["WFBE_C_GUER_AIRDEF_ENABLE", 1]) > 0})` | `Server/Init/Init_Server.sqf:799` |
| Launch | `[] execVM "Server\Server_GuerAirDef.sqf"` | `Server/Init/Init_Server.sqf:800` |
| Placement | gated **after** the GUER-OFF player-slot cleanup block, independent of `WFBE_C_GUER_PLAYERSIDE` | `Server/Init/Init_Server.sqf:776,794-801` |

The script re-checks `isServer` and `WFBE_C_GUER_AIRDEF_ENABLE` internally (`Server/Server_GuerAirDef.sqf:36,40`), so it is double-guarded.

## Boot sequence (`Server/Server_GuerAirDef.sqf`)

| Stage | Behavior | Source |
| --- | --- | --- |
| Server gate | `if !(isServer) exitWith {}` | `Server/Server_GuerAirDef.sqf:36` |
| Enable gate | `if ((missionNamespace getVariable ["WFBE_C_GUER_AIRDEF_ENABLE", 1]) < 1) exitWith {}` | `Server/Server_GuerAirDef.sqf:40` |
| Read tunables | all `WFBE_C_GUER_AIRDEF_*` via 2-arg `getVariable` with inline fallbacks | `Server/Server_GuerAirDef.sqf:44-53` |
| Boot wait | `waitUntil` for `towns` populated **and** `WFBE_L_GUE` side-logic non-null, then `sleep 45` to let town ownership settle | `Server/Server_GuerAirDef.sqf:56-60` |
| Crew classes | `_pilotClass = WFBE_GUERRESPILOT` (default `"GUE_Soldier_Pilot"`), `_crewClass = WFBE_GUERRESCREW` (default `"GUE_Soldier_Crew"`) | `Server/Server_GuerAirDef.sqf:62-63` |
| Registry | `_defenders = []` — script-local, **not** `wfbe_persistent`; each entry is `[town, vehicle, group, spawnTime, lastEnemyTime]` | `Server/Server_GuerAirDef.sqf:65-67` |
| Marker feed init | `WFBE_ACTIVE_GUER_AIR = []; publicVariable "WFBE_ACTIVE_GUER_AIR"` so a JIP client never reads nil | `Server/Server_GuerAirDef.sqf:75-76` |

The main loop then runs `while {!WFBE_GameOver} do { sleep _interval; ... }` (`Server/Server_GuerAirDef.sqf:78-79`) — the cadence sleep is at the **top**, so the first maintain pass happens one full interval after boot.

## Maintain cadence — three passes per interval

Every `WFBE_C_GUER_AIRDEF_INTERVAL` (default 120 s) the loop runs prune → self-clean → maintain, then rebuilds the marker feed.

### (1) Prune + (2) self-clean (`Server/Server_GuerAirDef.sqf:84-139`)

The registry is rebuilt into `_kept`; any entry that should die is torn down and dropped, freeing a slot in the global cap.

| Drop reason | Condition | Source |
| --- | --- | --- |
| `destroyed` | `isNull _eVeh \|\| !(alive _eVeh)` | `Server/Server_GuerAirDef.sqf:101` |
| `town_lost` | town `sideID != WFBE_C_GUER_ID` | `Server/Server_GuerAirDef.sqf:105,107` |
| `town_inactive` | town `wfbe_active` is `false` | `Server/Server_GuerAirDef.sqf:106,108` |
| `quiet` | `(_now - _eLastEnemy) > _quiet` — no enemies near the town for `WFBE_C_GUER_AIRDEF_QUIET_DESPAWN` s | `Server/Server_GuerAirDef.sqf:118` |
| `lifetime` | `(_now - _eSpawn) > _lifetime` — forced recycle (anti-accumulation) | `Server/Server_GuerAirDef.sqf:121` |

Enemy presence is recomputed each pass: `west`/`east` units alive within `(town range, min 600 m)` of the town (`Server/Server_GuerAirDef.sqf:112-114`). A surviving entry with enemies present has its `lastEnemyTime` stamped to `_now`, which is what holds off the `quiet` despawn.

**Teardown is player-safe** (B66, `Server/Server_GuerAirDef.sqf:123-132`): the hull + its crew are deleted only if **no** crew member is a player (`{isPlayer _x} count (crew _eVeh)) == 0`); group teardown deletes only non-player units (`if (!(isPlayer _x)) then {deleteVehicle _x}`). GUER is playable now, so a player who boarded a defender is never deleted — the registry entry is dropped either way, so the maintain sweep simply stops tracking that hull. This is the W13 crew+hull+group self-clean pattern (`Server/Server_GuerAirDef.sqf:129-131`).

### (3) Maintain — one defender per active GUER town (`Server/Server_GuerAirDef.sqf:141-241`)

Iterating `forEach towns`, the loop spawns a fresh defender for a town only when **all** of these hold (`Server/Server_GuerAirDef.sqf:146-150`):

| Gate | Condition | Source |
| --- | --- | --- |
| Under cap | `_aliveCount < _maxAir` (`WFBE_C_GUER_AIRDEF_MAX`) | `Server/Server_GuerAirDef.sqf:146` |
| Town valid | `!(isNull _town)` | `Server/Server_GuerAirDef.sqf:147` |
| GUER-held | `(_town getVariable ["sideID", -1]) == WFBE_C_GUER_ID` | `Server/Server_GuerAirDef.sqf:148` |
| Active | `_town getVariable ["wfbe_active", false]` | `Server/Server_GuerAirDef.sqf:149` |
| No live air already | `!(_town in _townsWithAir)` | `Server/Server_GuerAirDef.sqf:150` |

## Airframe selection — Ka-137 default, AT variant, Mi-24 on large contested towns

| Decision | Rule | Source |
| --- | --- | --- |
| Enemies near town | `west`/`east` alive within `(town range, min 600 m)` | `Server/Server_GuerAirDef.sqf:155` |
| LARGE-town test | `maxSupplyValue >= WFBE_C_GUER_AIRDEF_LARGE_SV` **OR** `wfbe_town_type` ∈ {`LargeTown1`,`LargeTown2`,`HugeTown1`,`HugeTown2`} | `Server/Server_GuerAirDef.sqf:157-161` |
| Mi-24 roll | `_useMi24 = true` only if **LARGE AND enemies > 0 AND `random 1 < WFBE_C_GUER_AIRDEF_MI24_CHANCE`** | `Server/Server_GuerAirDef.sqf:163-165` |
| Class chosen | `_class = if (_useMi24) then {_classMi24} else {_classKa}` | `Server/Server_GuerAirDef.sqf:167` |
| AT roll | `_useAT = true` if **not** Mi-24 and `random 1 < WFBE_C_GUER_AIRDEF_AT_CHANCE` (Ka-137 only — the Mi-24 is already an AT gunship by config) | `Server/Server_GuerAirDef.sqf:169-171` |

So the precedence is: a large town under attack first rolls for the Mi-24; only if that does **not** win does the Ka-137 path roll for the AT loadout. A quiet town, or a small town, can never field a Mi-24 — it always gets a Ka-137 (recon MG or AT-5).

### Spawn, crew, and orders

| Step | Detail | Source |
| --- | --- | --- |
| Spawn point | airborne `900 m` off the town at a random bearing, height `_flyHeight + 60` | `Server/Server_GuerAirDef.sqf:174-175` |
| Create vehicle | `[_class, _spawnPos, resistance, _ang, false, true, true, "FLY"] Call WFBE_CO_FNC_CreateVehicle` | `Server/Server_GuerAirDef.sqf:176` |
| Create group | `[resistance, "guer-airdef"] Call WFBE_CO_FNC_CreateGroup` | `Server/Server_GuerAirDef.sqf:179` |
| Pilot | `WFBE_CO_FNC_CreateUnit` → `moveInDriver` | `Server/Server_GuerAirDef.sqf:186-188` |
| Gunner | also a gunner for **both** airframes (B62: the Ka-137 MainTurret is gunner-fired, so a pilot-only Ka-137 flies but never engages) → `moveInGunner` | `Server/Server_GuerAirDef.sqf:189-190` |
| Tags | `_veh setVariable ["wfbe_guer_airdef", true, true]` and `["wfbe_guer_airdef_town", _town]` | `Server/Server_GuerAirDef.sqf:205-206` |
| Orders (never idle) | `flyInHeight _flyHeight` → `AIPatrol` over town → `setBehaviour "COMBAT"`, `setCombatMode "RED"`, `setSpeedMode "NORMAL"` | `Server/Server_GuerAirDef.sqf:213-217` |
| Register | append `[_town, _veh, _grp, time, time]`; `_aliveCount = _aliveCount + 1` | `Server/Server_GuerAirDef.sqf:219-221` |

The order sequence is load-bearing (B66, `Server/Server_GuerAirDef.sqf:208-212`): `AIPatrol` internally re-sets behaviour to AWARE/YELLOW, so it must run **before** the engage posture, otherwise it clobbers COMBAT/RED and the air just orbits passively. Patrol first, then stamp COMBAT/RED last so the defender actually presses attacks. Failed spawns (null vehicle, null group, or no pilot) tear down the freshly-created empty hull player-safely and log `GUERAIRDEF|SPAWNFAIL` (`Server/Server_GuerAirDef.sqf:224-239`).

### EASA AT loadout (server-side turret swap)

`EASA_Init.sqf` runs **client-only**, so `WFBE_EASA_Loadouts` / the client `EASA_Equip` path are not present in the server's `missionNamespace` (`Server/Server_GuerAirDef.sqf:25-31`). The AT variant is therefore applied directly on the server using the exact classnames from the Ka-137 EASA AT entry, on the MainTurret path `[-1]` (the same path `EASA_RemoveLoadout.sqf` uses for `Ka137_MG_PMC`):

| Step | Commands | Source |
| --- | --- | --- |
| Strip recon MG | `removeMagazineTurret ["100Rnd_762x54_PKT", [-1]]`, `removeWeaponTurret ["PKT", [-1]]` | `Server/Server_GuerAirDef.sqf:197-198` |
| Add AT-5 set | `addMagazineTurret ["5Rnd_AT5_BRDM2", "64Rnd_57mm"]`, `addWeaponTurret ["AT5Launcher", "57mmLauncher"]` | `Server/Server_GuerAirDef.sqf:199-200` |

This is a true swap (PKT removed first), and the load tag becomes `"AT5"` in the `GUERAIRDEF|SPAWN` diag line (`Server/Server_GuerAirDef.sqf:201,223`).

## Map-marker feed (GUER players only)

After both passes, the loop rebuilds `WFBE_ACTIVE_GUER_AIR = [[vehicle, sideID], ...]` from the live registry (alive hulls only) and `publicVariable`s it every interval (B67, `Server/Server_GuerAirDef.sqf:243-252`). `updatepatrolmarkers.sqf` reads this array; the `sideID` is always the GUER id, and the client side-gates on `WFBE_Client_SideID`, so only GUER players see these air arrows. The re-broadcast each interval doubles as the JIP catch-up safety net (`publicVariable` is not JIP-replayed in A2-OA).

## Tunable set (`Common/Init/Init_CommonConstants.sqf`)

All values are `isNil`-guarded defaults — override any of them before mission init to retune without touching the loop.

| Constant | Default | Meaning | Source |
| --- | --- | --- | --- |
| `WFBE_C_GUER_AIRDEF_ENABLE` | `1` | master switch (set `0` to disable the loop entirely) | `Common/Init/Init_CommonConstants.sqf:86` |
| `WFBE_C_GUER_AIRDEF_INTERVAL` | `120` | seconds between maintain sweeps | `Common/Init/Init_CommonConstants.sqf:87` |
| `WFBE_C_GUER_AIRDEF_MAX` | `4` | global alive cap on GUER air defenders (hard FPS bound) | `Common/Init/Init_CommonConstants.sqf:88` |
| `WFBE_C_GUER_AIRDEF_AT_CHANCE` | `0.20` | chance a spawned Ka-137 carries the EASA AT (Konkurs/AT-5) loadout | `Common/Init/Init_CommonConstants.sqf:89` |
| `WFBE_C_GUER_AIRDEF_MI24_CHANCE` | `0.25` | chance a LARGE GUER town under attack fields a Mi-24 gunship instead | `Common/Init/Init_CommonConstants.sqf:90` |
| `WFBE_C_GUER_AIRDEF_CLASS_KA` | `"Ka137_MG_PMC"` | default light air defender (recon/strike) | `Common/Init/Init_CommonConstants.sqf:91` |
| `WFBE_C_GUER_AIRDEF_CLASS_MI24` | `"Mi24_P"` | heavy gunship for large contested towns | `Common/Init/Init_CommonConstants.sqf:92` |
| `WFBE_C_GUER_AIRDEF_LIFETIME` | `900` | max seconds a defender lives before forced recycle (anti-accumulation) | `Common/Init/Init_CommonConstants.sqf:93` |
| `WFBE_C_GUER_AIRDEF_QUIET_DESPAWN` | `300` | despawn after this many seconds with no enemies near the town | `Common/Init/Init_CommonConstants.sqf:94` |
| `WFBE_C_GUER_AIRDEF_LARGE_SV` | `2500` | `maxSupplyValue` at/above which a town counts as LARGE (Mi-24 eligible); `town_type` Large/Huge also qualifies | `Common/Init/Init_CommonConstants.sqf:95` |
| `WFBE_C_GUER_AIRDEF_HEIGHT` | `120` | `flyInHeight` for spawned GUER air | `Common/Init/Init_CommonConstants.sqf:96` |

## Map / port notes

The source tree carries the mission under `Missions/`, `Missions_Vanilla/`, and `Modded_Missions/`. The loop is map-agnostic — it keys off the runtime `towns` array and town `sideID`/`maxSupplyValue`/`wfbe_town_type`, not off map geometry — so it ports as a straight copy. A byte-identical Takistan port already ships in `master` as of f8a76de3 at `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/Server_GuerAirDef.sqf` (253 lines, `diff` against the Chernarus copy = identical), wired into that mission's `Server/Init/Init_Server.sqf:793-794` with the same `isServer && WFBE_C_GUER_AIRDEF_ENABLE` gate.

## Continue Reading

- [GUER Insurgents Branch Audit](GUER-Insurgents-Branch-Audit) — the wider GUER partition: the Ka-137 in the player depot pool, the GUER economy/stipend, and why GUER runs without an AI commander
- [Naval HVT Objectives Atlas](Naval-HVT-Objectives-Atlas) — the GUER-owned offshore LHD HVTs and their proximity-gated CAP, the air mechanic this town-defender loop complements
- [Town AI Group Composition Catalog](Town-AI-Group-Composition-Catalog) — the ground garrisons of GUER-held towns that the air defenders orbit and protect
- [Towns, Camps, and Capture Atlas](Towns-Camps-And-Capture-Atlas) — town `sideID`, `wfbe_active`, `wfbe_town_type` and `range`/`maxSupplyValue`, the town fields this loop reads each pass
- [Mission Tunable Constants Catalog](Mission-Tunable-Constants-Catalog) — the full `WFBE_C_*` constant index this `WFBE_C_GUER_AIRDEF_*` set belongs to
