# Map Boundaries and Off-Map Enforcement

> Source-verified 2026-06-21 against then-current master cf2a6d6a4; current origin/master is 0139a346, so recheck cited paths before current-head claims. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

The boundaries system enforces a playable zone by shape-testing each client's position every 5 seconds, displaying a countdown hint when the player leaves the zone, and killing the vehicle/player when the countdown expires. It also clamps paradrop aircraft spawn points to map edges and drives the random-town distribution algorithm. The feature is parameter-controlled and silently self-disables on unregistered terrain.

---

## Init and Terrain Lookup

`Common/Init/Init_Boundaries.sqf` runs on every machine (client and server) from `Common/Init/Init_Common.sqf:317`. It sets the single missionNamespace variable that all consumers read.

```sqf
// Common/Init/Init_Boundaries.sqf:1-37 (abridged)
Private ['_boundariesXY'];
_boundariesXY = -1;

switch (toLower(worldName)) do {
    case 'chernarus':     {_boundariesXY = 15360};
    case 'eden':          {_boundariesXY = 12800};
    case 'isladuala':     {_boundariesXY = 10240};
    case 'takistan':      {_boundariesXY = 12800};
    case 'utes':          {_boundariesXY = 5120};
    case 'tasmania2010':  {_boundariesXY = 25360};
    case 'napf':          {_boundariesXY = 20500};
    case 'lingor':        {_boundariesXY = 10300};
    case 'smd_sahrani_a2':{_boundariesXY = 20480};
    case 'tavi':          {_boundariesXY = 25600};
    case 'dingor':        {_boundariesXY = 10300};
};
```

`Common/Init/Init_Boundaries.sqf:4-16`

### Terrain XY Table

| worldName (toLower) | WFBE_BOUNDARIESXY |
|---|---|
| chernarus | 15360 |
| eden | 12800 |
| isladuala | 10240 |
| takistan | 12800 |
| utes | 5120 |
| tasmania2010 | 25360 |
| napf | 20500 |
| lingor | 10300 |
| smd_sahrani_a2 | 20480 |
| tavi | 25600 |
| dingor | 10300 |
| *(any other worldName)* | -1 (feature disabled) |

`Common/Init/Init_Boundaries.sqf:4-16`

### Enabled-Parameter Branch

After the switch, the script branches on `WFBE_C_GAMEPLAY_BOUNDARIES_ENABLED` (`Common/Init/Init_Boundaries.sqf:19`):

| Condition | Result |
|---|---|
| Enabled AND terrain known | `missionNamespace setVariable ['WFBE_BOUNDARIESXY', _boundariesXY]` |
| Enabled AND terrain unknown (`_boundariesXY == -1`) | Forces `WFBE_C_GAMEPLAY_BOUNDARIES_ENABLED` to 0; nils `BoundariesIsOnMap` and `BoundariesHandleOnMap` on local player; logs warning |
| Disabled AND terrain known | Sets `WFBE_BOUNDARIESXY` anyway (support callers need it); logs `{Boundaries parameter is disabled}` |
| Disabled AND terrain unknown | Logs warning only |

The nil-out of `BoundariesIsOnMap`/`BoundariesHandleOnMap` only executes on the machine where `local player` is true, i.e. each client independently. `Common/Init/Init_Boundaries.sqf:23-24`

---

## Parameter Definition

| Parameter class | Default | Values | File |
|---|---|---|---|
| `WFBE_C_GAMEPLAY_BOUNDARIES_ENABLED` | `1` (Enabled) | `{0, 1}` | `Rsc/Parameters.hpp:285` |

The hardcoded fallback (if the mission starts without a lobby parameter value) is set at `Common/Init/Init_CommonConstants.sqf:234`:

```sqf
if (isNil "WFBE_C_GAMEPLAY_BOUNDARIES_ENABLED") then {WFBE_C_GAMEPLAY_BOUNDARIES_ENABLED = 1};
```

The timeout constant lives in the same file:

```sqf
WFBE_C_PLAYERS_OFFMAP_TIMEOUT = 50; //--- Player may remain x second outside of the map before being killed.
```

`Common/Init/Init_CommonConstants.sqf:274`

---

## Globals Written

| Variable | Scope | Written by | Read by |
|---|---|---|---|
| `WFBE_BOUNDARIESXY` | missionNamespace | `Init_Boundaries.sqf` | `Client_IsOnMap.sqf`, three Support_Para*.sqf, `Init_Towns.sqf` |
| `WFBE_C_GAMEPLAY_BOUNDARIES_ENABLED` | missionNamespace | Parameters / `Init_CommonConstants.sqf` | `Init_Boundaries.sqf`, `updateavailableactions.fsm` |
| `WFBE_C_PLAYERS_OFFMAP_TIMEOUT` | missionNamespace | `Init_CommonConstants.sqf` | `Client_HandleOnMap.sqf` |
| `BoundariesIsOnMap` | missionNamespace (global code var) | `Init_Client.sqf:50` (compiled) | `updateavailableactions.fsm:134`, `Client_HandleOnMap.sqf:8` |
| `BoundariesHandleOnMap` | missionNamespace (global code var) | `Init_Client.sqf:51` (compiled) | `updateavailableactions.fsm:136` |
| `paramBoundariesRunning` | missionNamespace (global bool) | `Client_HandleOnMap.sqf:4` (set on spawn) | `updateavailableactions.fsm:136,139` |

---

## Square-Zone Geometry (Client_IsOnMap.sqf)

The playable zone is a **square** of side `WFBE_BOUNDARIESXY`, with its origin at `[0, 0]`. The script uses polar math to find the distance from the player to the nearest edge of the square, then compares it to the player's distance from the square's centre point.

```sqf
// Client/Functions/Client_IsOnMap.sqf:1-17
Private ['_adis','_bdis','_borderdis','_boundary','_difx','_dify','_dir',
         '_position','_positiondis','_sqrradH','_sqrradHR'];

_boundary   = missionNamespace getVariable 'WFBE_BOUNDARIESXY';
_sqrradH    = _boundary / 2;
_sqrradHR   = [_sqrradH, _sqrradH];                       // centre of the square
_position   = [getPos player select 0, getPos player select 1];

_difx = (_position select 0) - _sqrradH;
_dify = (_position select 1) - _sqrradH;
_dir  = atan (_difx / _dify);
if (_dify < 0) then {_dir = _dir + 180};
_adis       = abs (_sqrradH / cos (90 - _dir));
_bdis       = abs (_sqrradH / cos _dir);
_borderdis  = _adis min _bdis;                             // nearest edge distance
_positiondis = _position distance _sqrradHR;               // player distance from centre

if (_positiondis < _borderdis) then {true} else {false}
```

`Client/Functions/Client_IsOnMap.sqf:1-17`

### Geometry Notes

- `_sqrradH` is half the terrain XY value. For Chernarus this is `7680` — both the X and Y centre coordinates in world space.
- The polar decomposition (`atan`, then a cosine correction on each axis) computes the radius of the inscribed square at the player's bearing rather than a circle. A player directly on a diagonal can be further from the centre than one at a cardinal heading while both are at the same `_positiondis`.
- The check is **not** a circle radius test. On Chernarus a player at bearing 45° can be roughly 3.5% further from centre before triggering than a player at bearing 0° or 90°.
- The function is called with no arguments: `Call BoundariesIsOnMap`. Returns `true` (inside) or `false` (outside).

---

## Off-Map Kill Countdown (Client_HandleOnMap.sqf)

When the FSM detects the player is off-map and no countdown is already running, it spawns `BoundariesHandleOnMap`:

```sqf
// Client/Functions/Client_HandleOnMap.sqf:1-16
Private ['_isOnMap','_timeToKill'];

_timeToKill = missionNamespace getVariable "WFBE_C_PLAYERS_OFFMAP_TIMEOUT";
paramBoundariesRunning = true;

while {true} do {
    sleep 1;
    _isOnMap = Call BoundariesIsOnMap;
    if !(_isOnMap) then {
        hint parseText(Format[localize 'STR_WF_INFO_OffmapWarning', _timeToKill]);
        _timeToKill = _timeToKill - 1;
    };
    if (_timeToKill < 0 || _isOnMap || !(alive player)) exitWith {
        if !(_isOnMap && alive player) then {(vehicle player) setDamage 1};
        paramBoundariesRunning = false;
    };
};
```

`Client/Functions/Client_HandleOnMap.sqf:1-16`

### Countdown Behaviour

| Event | What happens |
|---|---|
| Player off-map | Hint fires each second: `STR_WF_INFO_OffmapWarning` formatted with remaining seconds |
| Player returns to map before timeout | `exitWith` fires; `setDamage 1` is **not** called; `paramBoundariesRunning = false` |
| Countdown reaches -1 | `exitWith` fires; `(vehicle player) setDamage 1` kills the player (and the vehicle if mounted) |
| Player dies while off-map | `!(alive player)` guard exits the loop; `setDamage 1` is not double-applied |

Default timeout: **50 seconds** (`Common/Init/Init_CommonConstants.sqf:274`).

The hint text (`stringtable.xml:1104`) is red and localised: English reads `Warning! You are leaving the battlefield! <N> Seconds left.`

**Design note:** `setDamage 1` is applied to `vehicle player`, not `player` directly. If the player is on foot, `vehicle player` returns the player unit and the effect is identical. If mounted, the vehicle is destroyed along with the player.

---

## FSM Caller — updateavailableactions.fsm

The FSM runs on each client and ticks roughly every 5 seconds (`condition: time - _lastUpdate > 5`). It is the only caller that decides whether to spawn a new countdown coroutine.

```sqf
// Client/FSM/updateavailableactions.fsm:46 (init section)
"_boundaries_enabled = if ((missionNamespace getVariable ""WFBE_C_GAMEPLAY_BOUNDARIES_ENABLED"") > 0) then {true} else {false};"

// Client/FSM/updateavailableactions.fsm:132-141 (Update_Client_Ac state)
"//--- Boundaries are limited ?"
"if (_boundaries_enabled) then {"
"    _isOnMap = Call BoundariesIsOnMap;"
"    if (!_isOnMap && alive player && !WFBE_Client_IsRespawning) then {"
"        if !(paramBoundariesRunning) then {_handle = [] Spawn BoundariesHandleOnMap};"
"    } else {"
"        if !(isNil '_handle') then {terminate _handle; _handle = nil};"
"        paramBoundariesRunning = false;"
"    };"
"};"
```

`Client/FSM/updateavailableactions.fsm:46,133-141`

### Gating Logic

| FSM check | Effect |
|---|---|
| `!_isOnMap && alive player && !WFBE_Client_IsRespawning` | Spawns `BoundariesHandleOnMap` if not already running |
| Player is on-map OR dead | Terminates any running `_handle`; clears `paramBoundariesRunning` |
| `WFBE_Client_IsRespawning` true | Suppresses spawn — prevents a false off-map kill during respawn fade |

The FSM's 5-second tick means there is a latency window: a player can step off-map and return before the next FSM update without seeing a hint or countdown, as long as `BoundariesHandleOnMap` has not already been spawned.

---

## Paradrop Edge-Spawn Clamping

All three paradrop support scripts use `WFBE_BOUNDARIESXY` to build a four-corner array of map-edge spawn positions at altitude ~400–600 m. If the variable is nil (terrain unregistered or script ran before init), they fall back to a two-point hardcoded array.

| File | Line | Usage |
|---|---|---|
| `Server/Support/Support_ParaAmmo.sqf` | 12 | `_bd = missionNamespace getVariable 'WFBE_BOUNDARIESXY'` |
| `Server/Support/Support_Paratroopers.sqf` | 14 | same |
| `Server/Support/Support_ParaVehicles.sqf` | 12 | same |

```sqf
// Shared pattern — e.g. Support_Paratroopers.sqf:14-27
_bd = missionNamespace getVariable 'WFBE_BOUNDARIESXY';
if !(isNil '_bd') then {
    _ranPos = [
        [0+random(200),       0+random(200),       400+random(200)],
        [0+random(200),       _bd-random(200),      400+random(200)],
        [_bd-random(200),     _bd-random(200),      400+random(200)],
        [_bd-random(200),     0+random(200),        400+random(200)]
    ];
    _ranDir = [45, 145, 225, 315];
} else {
    _ranPos = [[0+random(200),0+random(200),400+random(200)],
               [15000+random(200),0+random(200),400+random(200)]];
    _ranDir = [45, 315];
};
```

`Server/Support/Support_Paratroopers.sqf:14-27`

The fallback `15000` value is a bare constant and does not reflect any registered terrain's XY — a paradrop on an unregistered map wider than 15 km will spawn aircraft off one side only.

---

## Town Distribution Usage (Init_Towns.sqf)

When the random-towns parameter is active (case 3), `Init_Towns.sqf:71` reads `WFBE_BOUNDARIESXY` to compute a geometric centre and ellipse for allocating Resistance towns:

```sqf
// Server/Init/Init_Towns.sqf:71
_boundaries = missionNamespace getVariable 'WFBE_BOUNDARIESXY';
// ...
if !(isNil '_boundaries') then {
    _searchArea = [(_boundaries / 2)-0.1, (_boundaries / 2)+0.1, 0];
    // ellipse math to assign ~50% towns to Resistance
};
```

`Server/Init/Init_Towns.sqf:71`

If `WFBE_BOUNDARIESXY` is nil (unregistered terrain with boundaries disabled), the ellipse block is skipped entirely and town assignment falls through to a random-fill loop.

---

## Adding a New Map

1. Add a `case` entry to the `switch` block in `Common/Init/Init_Boundaries.sqf:4-16` with the correct full-map XY extent in world units.
2. Confirm the correct `worldName` string by checking `call BIS_fnc_worldName` or the terrain's `config.cpp`. The switch uses `toLower(worldName)`, so capitalisation in config does not matter.
3. Verify `WFBE_BOUNDARIESXY` covers the playable area — setting it too small kills players near valid terrain edges; too large allows unintended off-map vehicle use.
4. Without a registered entry, the system silently forces `WFBE_C_GAMEPLAY_BOUNDARIES_ENABLED` to 0 and paradrop aircraft use the hardcoded two-point fallback.

---

## Behaviour Matrix

| Scenario | BoundariesIsOnMap nil? | WFBE_BOUNDARIESXY set? | Countdown fires? | Paradrop corners? |
|---|---|---|---|---|
| Known terrain, Enabled=1 | No | Yes | Yes | 4-corner |
| Known terrain, Enabled=0 | No | Yes | No | 4-corner |
| Unknown terrain, Enabled=1 | Yes (nilled) | No | No (FSM call skipped — nil guard) | 2-point fallback |
| Unknown terrain, Enabled=0 | No | No | No | 2-point fallback |

---

## Continue Reading

- [Variable-And-Naming-Conventions](Variable-And-Naming-Conventions) — naming rules for `WFBE_C_*`, `WFBE_UP_*`, and global code variables like `BoundariesIsOnMap`
- [Networking-And-Public-Variables](Networking-And-Public-Variables) — how missionNamespace variables flow between server and clients; `WFBE_Client_IsRespawning` respawn gate
- [Server-Gameplay-Runtime-Atlas](Server-Gameplay-Runtime-Atlas) — runtime overview including support call dispatch; paradrop scripts in context
- [Function-And-Module-Index](Function-And-Module-Index) — full index of compiled functions and FSM entry points
- [SQF-Code-Atlas](SQF-Code-Atlas) — cross-reference of all SQF files including `Init_Common.sqf` and `Init_Client.sqf` init ordering
