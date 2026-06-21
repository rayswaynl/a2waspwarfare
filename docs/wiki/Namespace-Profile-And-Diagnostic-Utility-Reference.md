# Namespace, Profile Persistence and Diagnostic Utilities

> Source-verified 2026-06-21 against then-current master cf2a6d6a4; current origin/master is 0139a346, so recheck cited paths before current-head claims. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

This page documents six platform-layer utility functions registered during common initialisation. Contributors frequently treat them as standard SQF builtins; they are not. Each carries non-obvious behaviour that has caused subtle bugs.

---

## Registration

All six functions are compiled in `Common/Init/Init_Common.sqf` (executed via `ExecVM` from `initJIPCompatible.sqf` line 217). `WFBE_CO_FNC_LogContent` is compiled earlier, directly in `initJIPCompatible.sqf` line 37, so it is available before any other function.

| Global variable | Source file | Registration site | Registration line |
|---|---|---|---|
| `GetNamespace` | `Common/Functions/Common_GetNameSpace.sqf` | not found in Init_Common — used as bare global | (see note below) |
| `SetNamespace` | `Common/Functions/Common_SetNamespace.sqf` | not found in Init_Common — used as bare global | (see note below) |
| `WFBE_CO_FNC_LogContent` | `Common/Functions/Common_LogContent.sqf` | `initJIPCompatible.sqf` | 37 |
| `GetSleepFPS` | `Common/Functions/Common_GetSleepFPS.sqf` | `Common/Init/Init_Common.sqf` | 45 |
| `GetAIDigit` | `Common/Functions/Common_GetAIDigit.sqf` | `Common/Init/Init_Common.sqf` | 24 |
| `WFBE_CO_FNC_GetProfileVariable` | `Common/Functions/Common_GetProfileVariable.sqf` | `Common/Init/Init_Common.sqf` | 170 |
| `WFBE_CO_FNC_SetProfileVariable` | `Common/Functions/Common_SetProfileVariable.sqf` | `Common/Init/Init_Common.sqf` | 172 |
| `WFBE_CO_FNC_SaveProfile` | `Common/Functions/Common_SaveProfile.sqf` | `Common/Init/Init_Common.sqf` | 171 |

**Note on `GetNamespace` / `SetNamespace`:** Neither is compiled by an explicit `Compile preprocessFileLineNumbers` line in the Chernarus init chain. Both are referenced as bare-name globals (e.g. `_variable Call GetNamespace` in `Common/Functions/Common_SetNamespace.sqf:9`; `(Format[...]) Call GetNamespace` in `Common/Functions/Common_GetClientTeam.sqf:6`). The source files `Common/Functions/Common_GetNameSpace.sqf` and `Common/Functions/Common_SetNamespace.sqf` exist on disk but are not explicitly compiled by any line in the scanned master branch. Do not assume they are accessible until this registration gap is resolved.

**Profile functions are version-gated.** `WFBE_CO_FNC_GetProfileVariable`, `WFBE_CO_FNC_SetProfileVariable`, and `WFBE_CO_FNC_SaveProfile` are compiled only when `ARMA_VERSION >= 162 && ARMA_RELEASENUMBER > 97105 || ARMA_VERSION > 162` (`Common/Init/Init_Common.sqf:169-173`). All callers guard against this with `if !(isNil 'WFBE_CO_FNC_SetProfileVariable') then {...}`.

---

## Logging — `WFBE_CO_FNC_LogContent`

### Overview

Diagnostic sink for all mission subsystems. Every init file, server loop, and client function routes structured log output through this one function. All output is silently discarded unless `LOG_CONTENT_STATE == "ACTIVATED"`.

### Activation gate

`LOG_CONTENT_STATE` is initialised to `""` at `initJIPCompatible.sqf:6`, then conditionally overwritten via a preprocessor branch (`initJIPCompatible.sqf:9-13`):

```sqf
#ifdef WF_LOG_CONTENT
    LOG_CONTENT_STATE = "ACTIVATED";
#else
    LOG_CONTENT_STATE = "NOT ACTIVATED";
#endif
```

Headless clients always activate logging regardless of the build flag (`initJIPCompatible.sqf:59`):

```sqf
if (isHeadLessClient) then {LOG_CONTENT_STATE = "ACTIVATED"};
```

The current state is written to the RPT at mission start (`initJIPCompatible.sqf:32`).

### Log level

`WFBE_LogLevel` is set to `0` in `initJIPCompatible.sqf:38`:

```sqf
WFBE_LogLevel = 0; //--- Logging level (0: Trivial, 1: Information, 2: Warnnings, 3: Errors).
```

At level `0` every call whose `_logLevel` is `>= 0` (i.e. all of them, since the optional parameter defaults to `0`) reaches `diag_log`. In practice the gate is the `LOG_CONTENT_STATE` string check, not the level filter.

### Signature

| Parameter | Index | Type | Notes |
|---|---|---|---|
| `_logType` | 0 | String | Free-form category tag, e.g. `"INITIALIZATION"`, `"INFORMATION"`, `"WARNING"`, `"TRIVIAL"` |
| `_logContent` | 1 | String | Message body; typically a `Format[...]` expression |
| `_logLevel` | 2 | Number | Optional; defaults to `0` if omitted (`Common/Functions/Common_LogContent.sqf:14`) |

**Return:** nothing (side-effect only).

**Output format** (`Common/Functions/Common_LogContent.sqf:16`):

```
[WFBE (<logType>)] [frameno:<N> | ticktime:<T> | fps:<F>] <logContent>
```

### Source

`Common/Functions/Common_LogContent.sqf` (17 lines):

```sqf
if (LOG_CONTENT_STATE == "ACTIVATED") then {
    Private ["_logContent","_logLevel","_logType"];

    _logType = _this select 0;
    _logContent = _this select 1;
    _logLevel = if (count _this > 2) then {_this select 2} else {0};

    if (_logLevel >= WFBE_LogLevel) then {
        diag_log Format["[WFBE (%1)] [frameno:%2 | ticktime:%3 | fps:%4] %5",
            _logType, diag_frameno, diag_tickTime, diag_fps, _logContent]
    };
};
```

### Typical call patterns

```sqf
// No level argument — fires at any WFBE_LogLevel value
["INITIALIZATION", "Init_Common.sqf: Functions are initialized."] Call WFBE_CO_FNC_LogContent;
// Common/Init/Init_Common.sqf:163

// With Format — typical init breadcrumb
["INFORMATION", Format ["Init_Boundaries.sqf: Boundaries [%1] found for island [%2]",
    _boundariesXY, worldName]] Call WFBE_CO_FNC_LogContent;
// Common/Init/Init_Boundaries.sqf:29
```

### Debugging caveat

If `WF_LOG_CONTENT` is not defined at build time, the entire body of every `Call WFBE_CO_FNC_LogContent` is a no-op evaluated at the outer `if` check. Developers who add new `Call WFBE_CO_FNC_LogContent` lines and see no RPT output must rebuild with the `WF_LOG_CONTENT` preprocessor define or connect as/via a Headless Client.

---

## Namespace Read — `GetNamespace`

### Signature

| Parameter | Type | Notes |
|---|---|---|
| `_this` (caller left-hand) | String | Variable name to read from `missionNamespace` |

**Return:** the value stored under `_variable` in `missionNamespace`, or `nil` if not set.

**Call form:** `_variable Call GetNamespace` (bare-name style, not `WFBE_CO_FNC_*`).

### Source

`Common/Functions/Common_GetNameSpace.sqf` (4 lines):

```sqf
Private ['_variable'];

_variable = _this;

missionNamespace getVariable _variable
```

### Usage

Read-only wrapper for `missionNamespace getVariable`. Callers use it when the variable name is itself stored in a string (common in the team/faction data model):

```sqf
_team = ((Format["WFBE_%1TEAMS",str _side]) Call GetNamespace) select (_ID - 1);
// Common/Functions/Common_GetClientTeam.sqf:6
```

The commented-out line in `Client/Init/Init_Client.sqf:562` shows an older calling pattern that was never removed:

```sqf
// [player, Format ["WFBE_%1DEFAULTWEAPONS",sideJoinedText] Call GetNamespace, ...] Call EquipLoadout;
```

---

## Nil-Safe Namespace Write — `SetNamespace`

### Signature

| Parameter | Index | Type | Notes |
|---|---|---|---|
| `_variable` | 0 | String | Variable name to write in `missionNamespace` |
| `_value` | 1 | Any | Value to store |
| `_override` | 2 | Bool | Optional; defaults to `false` |

**Return:** nothing.

**Call form:** `[_variable, _value] Call SetNamespace` or `[_variable, _value, true] Call SetNamespace`.

### Source

`Common/Functions/Common_SetNamespace.sqf` (15 lines):

```sqf
Private ['_get','_override','_variable','_value'];

_variable = _this select 0;
_value = _this select 1;
_override = if (count _this > 2) then {_this select 2} else {false};

//--- BIS Bug, typename doesn't work properly with nil.
if !(_override) then {
    _get = _variable Call GetNamespace;
    if (isNil '_get') then {
        missionNamespace setVariable [_variable,_value];
    };
} else {
    missionNamespace setVariable [_variable,_value];
};
```

### Nil-safe semantics — critical detail

Without the third argument (or with `_override = false`), `SetNamespace` **only writes the value if the variable is currently nil**. If the variable already holds any value, the call is silently discarded. This is the intended initialisation-safe pattern: it sets a default without overwriting an already-initialised value.

To force an unconditional write, pass `true` as the third argument:

```sqf
[_variable, _value, true] Call SetNamespace;  // always writes
[_variable, _value] Call SetNamespace;         // writes only if nil (default)
```

The comment `//--- BIS Bug, typename doesn't work properly with nil.` explains why `isNil '_get'` is used rather than a `typename` check — `typename nil` is unreliable in Arma 2 OA.

---

## Profile Persistence

Three functions form the profile persistence layer. They are only available on builds running ArmA 2 OA build > 97105 (condition: `ARMA_VERSION >= 162 && ARMA_RELEASENUMBER > 97105 || ARMA_VERSION > 162`, `Common/Init/Init_Common.sqf:169`). All write to the player's `profileNamespace`, which survives between sessions.

### `WFBE_CO_FNC_GetProfileVariable`

| Parameter | Index | Type | Notes |
|---|---|---|---|
| `_var` | 0 | String | profileNamespace key |
| `_default` | 1 | Any | Returned if the key is not set |

**Return:** the stored value, or `_default`.

**Source** (`Common/Functions/Common_GetProfileVariable.sqf:13`):

```sqf
profileNamespace getVariable [_var, _default]
```

### `WFBE_CO_FNC_SetProfileVariable`

| Parameter | Index | Type | Notes |
|---|---|---|---|
| `_var` | 0 | String | profileNamespace key |
| `_value` | 1 | Any | Value to store |

**Return:** nothing. Does not call `saveProfileNamespace` — callers must follow up with `WFBE_CO_FNC_SaveProfile` to persist to disk.

**Source** (`Common/Functions/Common_SetProfileVariable.sqf:13`):

```sqf
profileNamespace setVariable [_var, _value]
```

### `WFBE_CO_FNC_SaveProfile`

No parameters. Calls `saveProfileNamespace` (`Common/Functions/Common_SaveProfile.sqf:5`).

Call this after one or more `WFBE_CO_FNC_SetProfileVariable` calls, not after each individual set. Callers batch the writes and call `SaveProfile` once:

```sqf
if !(isNil 'WFBE_CO_FNC_SetProfileVariable') then {
    ['WFBE_PERSISTENT_CONST_VIEW_DISTANCE', _currentVD] Call WFBE_CO_FNC_SetProfileVariable;
    _need_save = true
};
// ... more sets ...
if !(isNil 'WFBE_CO_FNC_SaveProfile') then {Call WFBE_CO_FNC_SaveProfile};
// Client/GUI/GUI_Menu_Team.sqf:193, 214
```

### Profile keys in use

| Key | Type | Written by | Loaded by |
|---|---|---|---|
| `WFBE_PERSISTENT_CONST_VIEW_DISTANCE` | Number | `GUI_Menu_Team.sqf:193` | `Client/Init/Init_ProfileVariables.sqf:9` |
| `WFBE_PERSISTENT_CONST_TERRAIN_GRID` | Number | `GUI_Menu_Team.sqf:197` | `Client/Init/Init_ProfileVariables.sqf:37` |
| `WFBE_TARGET_FPS` | Number | `Common_AdjustViewDistance.sqf:39,59` | `Client/Init/Init_ProfileVariables.sqf:19` |
| `WFBE_HIGH_CLIMBING_DEFAULT_ENABLED` | Bool | `GUI_Menu_Team.sqf:176` | `Client/Init/Init_ProfileVariables.sqf:28` |
| `WFBE_PERSISTENT_<side>_GEAR_TEMPLATE` | Array | `Client_UI_Gear_SaveTemplateProfile.sqf:94` (via `profileNamespace setVariable`) | `Client/Init/Init_ProfileVariables.sqf:48` |

All profile reads in `Init_ProfileVariables.sqf` apply a `typeName` sanity check before applying the value, guarding against corrupted or cross-version profile data.

---

## FPS-Adaptive Sleep — `GetSleepFPS`

### Signature

| Parameter | Type | Notes |
|---|---|---|
| `_this` (caller left-hand) | Number | Base sleep delay in seconds |

**Return:** Number — the adjusted delay to pass to `sleep`.

**Call form:** `_delay Call GetSleepFPS` (bare-name style).

### Source

`Common/Functions/Common_GetSleepFPS.sqf` (10 lines):

```sqf
Private ["_delay"];

_delay = _this;

if (diag_fps > 15) exitWith {_delay};
if (diag_fps <= 15 && diag_fps > 10) exitWith {_delay * 0.85};
if (diag_fps <= 10 && diag_fps > 7) exitWith {_delay * 0.75};
if (diag_fps <= 7 && diag_fps > 5) exitWith {_delay * 0.70};
if (diag_fps <= 5) exitWith {_delay * 0.50};

_delay
```

### FPS threshold table

| `diag_fps` range | Multiplier applied | Resulting delay |
|---|---|---|
| `> 15` | 1.00 (passthrough) | `_delay` |
| `<= 15` and `> 10` | 0.85 | 15% reduction |
| `<= 10` and `> 7` | 0.75 | 25% reduction |
| `<= 7` and `> 5` | 0.70 | 30% reduction |
| `<= 5` | 0.50 | 50% reduction |

### Design rationale

Under server load the `diag_fps` metric falls. Shorter sleep intervals allow server loops to process more work per real-time second, partially compensating for performance degradation. The function is only called by `Server/FSM/updateresources.sqf:74`:

```sqf
_awaits = (_ii) Call GetSleepFPS;
sleep _awaits;
```

Where `_ii` is `missionNamespace getVariable "WFBE_C_ECONOMY_INCOME_INTERVAL"` (`Server/FSM/updateresources.sqf:4`).

### Note

`GetSleepFPS` reads `diag_fps` at call time, which is the instantaneous frame rate of the local machine. On a dedicated server `diag_fps` reflects server frame rate, not any connected client's rate. The adaptive correction is a heuristic, not a guaranteed performance floor.

---

## AI Unit Name Parser — `GetAIDigit`

### Signature

| Parameter | Type | Notes |
|---|---|---|
| `_this` (caller left-hand) | Object | The unit to classify |

**Return:** String — `"Leader"` if the unit leads its group, otherwise the numeric suffix extracted from the unit's display name after the `:` character, or `"0"` if no suffix is found.

**Call form:** `_unit Call GetAIDigit` (bare-name style).

### Source

`Common/Functions/Common_GetAIDigit.sqf` (20 lines):

```sqf
Private ["_i","_split","_unit","_yield"];

_unit = _this;

if (_unit == leader (group _unit)) exitWith {"Leader"};

_split = toArray(str _unit);

_find = _split find 58;   // ASCII 58 = ':'
_yield = [];

if (_find != -1) then {
    for '_i' from (_find+1) to count(_split)-1 do {
        if ((_split select _i) == 65 || (_split select _i) == 32) exitWith {};
        _yield = _yield + [_split select _i];
    };
};

if (count _yield == 0) exitWith {"0"};

toString(_yield)
```

### Logic detail

1. If `_unit` is the leader of its group, return `"Leader"` immediately.
2. Convert `str _unit` (the display name) to an ASCII array with `toArray`.
3. Find the colon character (ASCII 58, `:`) in the array.
4. Extract characters after `:` up to but not including `A` (ASCII 65) or space (ASCII 32).
5. Convert the collected byte array back to a string with `toString`.

The extraction loop breaks on `A` (ASCII 65) because ArmA unit names commonly end with a letter/rank suffix after the numeric digit. If no colon is found, or if nothing follows it, returns `"0"`.

**Note:** `_find` is assigned without `Private` declaration (`Common/Functions/Common_GetAIDigit.sqf:9`). In Arma 2 OA this leaks `_find` into the calling scope as a script-local variable, which is harmless in practice but is a latent hygiene issue.

### Usage

Called from `Common/Init/Init_Unit.sqf:161` when creating the map marker label for a unit in the player's group:

```sqf
_txt = (_unit) Call GetAIDigit;
// Common/Init/Init_Unit.sqf:161
```

The result becomes the marker text displayed on the map for player-group AI members.

---

## Continue Reading

- [Variable-And-Naming-Conventions](Variable-And-Naming-Conventions) — covers the `WFBE_CO_FNC_*` / `WFBE_SE_FNC_*` / `WFBE_CL_FNC_*` naming convention and bare-name legacy globals
- [Hosted-Server-FPS-Loop-Sleep](Hosted-Server-FPS-Loop-Sleep) — the server FSM loop that calls `GetSleepFPS` in context
- [Gear-Template-Profile-Filter](Gear-Template-Profile-Filter) — the gear template flow that drives `SetProfileVariable` / `SaveProfile` calls
- [Networking-And-Public-Variables](Networking-And-Public-Variables) — `missionNamespace` variable broadcast patterns that complement `GetNamespace` / `SetNamespace`
- [Function-And-Module-Index](Function-And-Module-Index) — full index of all compiled function variables
