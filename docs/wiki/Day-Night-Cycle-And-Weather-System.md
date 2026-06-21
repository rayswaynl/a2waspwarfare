# Day/Night Cycle and Weather System (Server_DayNightCycle runtime)

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

The hybrid accelerated day/night cycle runs the in-game clock far faster than real time so a single round cycles through dawn, full daylight, dusk and night without the long dead hours of a real 24-hour day. The design is server-authoritative but JIP-tolerant: the **server** advances the only authoritative clock with small `skipTime` steps (`Server/Functions/Server_DayNightCycle.sqf:83`), while each **remote client** animates its own local clock and uses the broadcast server date only as a *drift reference* — never calling `setDate` on every tick, because `setDate` can freeze rendering while the environment recalculates (`Client/Functions/Client_DayNightCycle.sqf:9-12`). Weather is deliberately suppressed while the cycle is enabled, because accelerated `skipTime` makes low clouds stutter (`Server/Init/Init_Server.sqf:178`). This page documents the runtime algorithm; the lobby parameter rows live in [the start-parameters index](Mission-Start-Parameters-Index) and the broadcast channel in [the public-variable index](Public-Variable-Channel-Index).

## Architecture: who owns the clock

| Role | Script / handler | What it does |
| --- | --- | --- |
| Server authoritative clock | `Server/Functions/Server_DayNightCycle.sqf` | Loops, advances `skipTime` per tick, broadcasts `WFBE_DAYNIGHT_DATE` every sync interval (`Server/Functions/Server_DayNightCycle.sqf:72-94`) |
| Launch gate | `Server/Init/Init_Server.sqf:855-858` | Runs `Server\Functions\Server_DayNightCycle.sqf` via `execVM` only when `WFBE_DAYNIGHT_ENABLED == 1` (`Server/Init/Init_Server.sqf:856-857`) |
| Client smoother | `Client/Functions/Client_DayNightCycle.sqf` | Each remote client animates time locally and pays back drift gradually (`Client/Functions/Client_DayNightCycle.sqf:86-130`) |
| Client launch gate | `initJIPCompatible.sqf:245-247` | `execVM`s the client smoother only on a non-dedicated, non-server, non-headless machine when enabled (`initJIPCompatible.sqf:245-246`) |
| PV receive handler | `initJIPCompatible.sqf:212-222` | `addPublicVariableEventHandler` on `WFBE_DAYNIGHT_DATE`: validates the date array and raises a pending-sync flag (`initJIPCompatible.sqf:214-221`) |
| JIP/initial date | `initJIPCompatible.sqf:225-243` | On mission/JIP start, applies the last broadcast date or the forced 28-June fallback (`initJIPCompatible.sqf:230-235`) |

The hosted (listen-server) player runs the *server* loop, not the client smoother — the client script exits immediately on a server or dedicated machine (`Client/Functions/Client_DayNightCycle.sqf:47`).

## Phase model and rate math

The 24-hour clock is split into four phases by four boundary hours. Dawn and dusk (twilight) are deliberately advanced **slower** than full daylight for smoother visual transitions; the slowdown factor is the twilight weight (`Server/Functions/Server_DayNightCycle.sqf:61-64`).

| Phase | Hour range | Game hours | Rate used per tick | Source |
| --- | --- | --- | --- | --- |
| Dawn (twilight) | `dawn_start` ≤ h < `dawn_end` (04:00–05:00) | `dawn_end - dawn_start` = 1 | `_twilight_hours_per_second` | `Server/Functions/Server_DayNightCycle.sqf:56,78` |
| Full day | `dawn_end` ≤ h < `dusk_start` (05:00–20:30) | `dusk_start - dawn_end` = 15.5 | `_day_hours_per_second` | `Server/Functions/Server_DayNightCycle.sqf:57,79` |
| Dusk (twilight) | `dusk_start` ≤ h < `dusk_end` (20:30–21:30) | `dusk_end - dusk_start` = 1 | `_twilight_hours_per_second` | `Server/Functions/Server_DayNightCycle.sqf:58,80` |
| Night (wrap-around default) | otherwise | `(24 - dusk_end) + dawn_start` = 6.5 | `_night_hours_per_second` | `Server/Functions/Server_DayNightCycle.sqf:59,77` |

Night is the wrap-around default: each tick starts by assuming night, and the dawn/day/dusk `if` blocks override `_hours_to_add` only when the current hour falls inside their range (`Server/Functions/Server_DayNightCycle.sqf:76-80`). The client uses the identical phase/rate logic (`Client/Functions/Client_DayNightCycle.sqf:114-118`).

The rate formulas (`Server/Functions/Server_DayNightCycle.sqf:62-65`, mirrored at `Client/Functions/Client_DayNightCycle.sqf:73-76`):

| Quantity | Formula | Defaults resolved |
| --- | --- | --- |
| `_day_weighted_hours` | `day_hours + (dawn_hours + dusk_hours) * twilight_weight` | `15.5 + (1+1)*3 = 21.5` |
| `_day_hours_per_second` | `day_weighted_hours / (day_duration_real * 60)` | `21.5 / (180*60) = 21.5/10800` |
| `_twilight_hours_per_second` | `day_weighted_hours / (day_duration_real_seconds * twilight_weight)` | `(day rate) / 3` |
| `_night_hours_per_second` | `night_hours / (night_duration_real * 60)` | `6.5 / (30*60) = 6.5/1800` |

The full daylight half therefore takes the configured day-duration minutes (default 180), and the night half takes the configured night-duration minutes (default 30), with twilight smeared `twilight_weight×` slower so dawn/dusk are not jarring (`Server/Functions/Server_DayNightCycle.sqf:46-47,61-65`).

## Tunable constants and defaults

These default in `Common/Init/Init_CommonConstants.sqf` under the "Day/night cycles" block; the `WFBE_DAY_DURATION`/`WFBE_NIGHT_DURATION`/`WFBE_DAYNIGHT_ENABLED` values can be overridden by lobby parameters, the rest are fixed.

| Constant | Default | Meaning | Source |
| --- | --- | --- | --- |
| `WFBE_DAYNIGHT_ENABLED` | 1 | Master enable for the hybrid cycle | `Common/Init/Init_CommonConstants.sqf:84` |
| `WFBE_DAY_DURATION` | 180 | Real-life daytime length in minutes | `Common/Init/Init_CommonConstants.sqf:86` |
| `WFBE_NIGHT_DURATION` | 30 | Real-life nighttime length in minutes | `Common/Init/Init_CommonConstants.sqf:87` |
| `WFBE_DAYNIGHT_CLIENT_TICK` | 0.1 | Seconds between each small time step (`sleep _tick`) | `Common/Init/Init_CommonConstants.sqf:89` |
| `WFBE_DAYNIGHT_SERVER_SYNC_INTERVAL` | 30 | Seconds between authoritative date broadcasts | `Common/Init/Init_CommonConstants.sqf:90` |
| `WFBE_DAYNIGHT_CLIENT_MAX_CORRECTION` | 0.0005 | Max drift correction in game hours per client tick | `Common/Init/Init_CommonConstants.sqf:91` |
| `WFBE_DAYNIGHT_CLIENT_HARD_SYNC_DRIFT` | 6 | Drift in game hours before one exceptional `setDate` | `Common/Init/Init_CommonConstants.sqf:92` |
| `WFBE_DAYNIGHT_FORCED_MONTH` | 6 | June forced when cycle enabled | `Common/Init/Init_CommonConstants.sqf:94` |
| `WFBE_DAYNIGHT_FORCED_DAY` | 28 | 28th forced when cycle enabled | `Common/Init/Init_CommonConstants.sqf:95` |
| `WFBE_DAYNIGHT_DAWN_START` | 4 | Dawn begins ~04:00 | `Common/Init/Init_CommonConstants.sqf:96` |
| `WFBE_DAYNIGHT_DAWN_END` | 5 | Full daylight ~05:00 | `Common/Init/Init_CommonConstants.sqf:97` |
| `WFBE_DAYNIGHT_DUSK_START` | 20.5 | Dusk begins ~20:30 | `Common/Init/Init_CommonConstants.sqf:98` |
| `WFBE_DAYNIGHT_DUSK_END` | 21.5 | Night begins ~21:30 | `Common/Init/Init_CommonConstants.sqf:99` |
| `WFBE_DAYNIGHT_TWILIGHT_WEIGHT` | 3 | Dawn/dusk game hours take ×3 longer than daylight | `Common/Init/Init_CommonConstants.sqf:100` |

The phase boundaries are calibrated for Chernarus on 28 June, which is why the cycle forces that effective date (`Common/Init/Init_CommonConstants.sqf:93`).

## Server loop step-by-step

Per iteration of `while {WFBE_DAYNIGHT_ENABLED == 1}` (`Server/Functions/Server_DayNightCycle.sqf:72-94`):

1. Read the current hour with `_hour = daytime` (`Server/Functions/Server_DayNightCycle.sqf:74`).
2. Pick the per-tick advance: night rate by default, overridden to twilight/day rate inside the phase ranges (`Server/Functions/Server_DayNightCycle.sqf:77-80`).
3. `skipTime _hours_to_add` — advances **only** the server clock (`Server/Functions/Server_DayNightCycle.sqf:83`).
4. Accumulate `_sync_elapsed`; once it reaches `WFBE_DAYNIGHT_SERVER_SYNC_INTERVAL`, set `WFBE_DAYNIGHT_DATE = date`, `publicVariable` it, and reset the counter (`Server/Functions/Server_DayNightCycle.sqf:85-91`). `_sync_elapsed` is primed to `_sync_interval` so the very first tick broadcasts immediately (`Server/Functions/Server_DayNightCycle.sqf:70`).
5. `sleep _tick` (default 0.1s) (`Server/Functions/Server_DayNightCycle.sqf:93`).

The loop guards `isServer` and re-checks the `WFBE_DAYNIGHT_ENABLED == 1` parameter on entry (`Server/Functions/Server_DayNightCycle.sqf:39-41`).

## JIP date sync and the WFBE_DAYNIGHT_DATE channel

`WFBE_DAYNIGHT_DATE` is the single public-variable channel for the cycle. The server publishes an absolute `date` array on the sync interval (`Server/Functions/Server_DayNightCycle.sqf:88-89`). Clients receive it without paying the per-broadcast `setDate` cost:

| Step | Behavior | Source |
| --- | --- | --- |
| Receive | `addPublicVariableEventHandler` stores the array into `WFBE_DAYNIGHT_SERVER_DATE` and sets `WFBE_DAYNIGHT_PENDING_SYNC = true` if it is an array of ≥5 elements | `initJIPCompatible.sqf:214-221` |
| Defer | The handler does **no** expensive work — the decision is made once, in the client loop | `Client/Functions/Client_DayNightCycle.sqf:87` |
| Drift calc | When pending, the client computes `_drift_hours` from `dateToNumber` of server vs local date, plus a year delta | `Client/Functions/Client_DayNightCycle.sqf:91-97` |
| Hard sync | If `abs _drift_hours > WFBE_DAYNIGHT_CLIENT_HARD_SYNC_DRIFT` (6) — only after a bad JIP or broken local clock — a single `setDate _server_date` snaps the clock and clears the pending correction | `Client/Functions/Client_DayNightCycle.sqf:99-103` |
| Soft sync | Otherwise the drift is added to `WFBE_DAYNIGHT_CORRECTION_HOURS` and paid back gradually | `Client/Functions/Client_DayNightCycle.sqf:104-106` |

The pending-sync and correction accumulators are initialized defensively in case the PV handler fires before the loop is reached — the loop never erases a pending sync (`Client/Functions/Client_DayNightCycle.sqf:82-84`).

### Initial / JIP date application

On mission or JIP start, a spawned block waits for `time > 0`, then (when the cycle is enabled) applies the last broadcast `WFBE_DAYNIGHT_DATE` if one exists, else falls back to the forced 28-June date at the starting hour (`initJIPCompatible.sqf:225-237`):

- Enabled + a broadcast already seen: `setDate WFBE_DAYNIGHT_DATE` (`initJIPCompatible.sqf:231-232`).
- Enabled + no broadcast yet: `setDate [year, WFBE_DAYNIGHT_FORCED_MONTH, WFBE_DAYNIGHT_FORCED_DAY, WFBE_C_ENVIRONMENT_STARTING_HOUR, minute]` (`initJIPCompatible.sqf:235`).
- Cycle disabled (legacy path): `setDate` to `WFBE_C_ENVIRONMENT_STARTING_MONTH` + starting hour, then a JIP client syncs mission time via `skipTime (time / 3600)` (`initJIPCompatible.sqf:238-240`).

`WFBE_C_ENVIRONMENT_STARTING_HOUR` defaults to 9 and `WFBE_C_ENVIRONMENT_STARTING_MONTH` to 6 (`Common/Init/Init_CommonConstants.sqf:378-379`).

## Client drift smoothing

The client loop mirrors the server's phase/rate selection (`Client/Functions/Client_DayNightCycle.sqf:114-118`), then layers on the gradual drift payback (`Client/Functions/Client_DayNightCycle.sqf:121-126`):

- Read the accumulated `WFBE_DAYNIGHT_CORRECTION_HOURS`.
- If its magnitude exceeds `0.0001`, clamp one step to ±`WFBE_DAYNIGHT_CLIENT_MAX_CORRECTION` (0.0005 game-hours/tick), add it to `_hours_to_skip`, and subtract the applied step from the remaining correction.
- `skipTime _hours_to_skip` then `sleep _tick` (`Client/Functions/Client_DayNightCycle.sqf:128-129`).

This keeps the client visually in sync without abrupt time jumps; the only hard `setDate` on the client path is the >6-hour emergency snap.

## Weather handling

While the cycle is enabled the sky is forced clear and rain off, because accelerated `skipTime` makes low clouds stutter — so day/night "owns" the weather (`Server/Init/Init_Server.sqf:178`, `Client/Init/Init_Client.sqf:235`). Both the server (`Server/Init/Init_Server.sqf:179-195`) and each client (`Client/Init/Init_Client.sqf:236-251`) run the same `Call {}` weather block with this precedence:

| Condition | Action | Source |
| --- | --- | --- |
| `WFBE_DAYNIGHT_ENABLED == 1` | `exitWith {0 setOvercast 0; 0 setRain 0}` — instant clear sky, no rain | `Server/Init/Init_Server.sqf:181-184` |
| `WFBE_C_ENVIRONMENT_WEATHER == 3` | `exitWith {}` — leave weather untouched (manual/editor control) | `Server/Init/Init_Server.sqf:185` |
| Server-only guard | `if (!isDedicated) exitWith {}` (server block only) | `Server/Init/Init_Server.sqf:186` |
| Otherwise | map `WFBE_C_ENVIRONMENT_WEATHER` → overcast and apply over 60s | `Server/Init/Init_Server.sqf:188-194` |

The overcast mapping when the cycle is disabled (`Server/Init/Init_Server.sqf:188-194`, identical on client at `Client/Init/Init_Client.sqf:244-250`):

| `WFBE_C_ENVIRONMENT_WEATHER` | Overcast | Meaning |
| --- | --- | --- |
| 0 | `0 setOvercast 0` over 60s | Clear |
| 1 | `0.5` | Cloudy |
| 2 | `1` | Rainy |
| 3 | (untouched) | Manual / editor-controlled |

`WFBE_C_ENVIRONMENT_WEATHER` defaults to 0 (clear) (`Common/Init/Init_CommonConstants.sqf:380`). Two related environment constants are hard-forced regardless of parameter: volumetric clouds are disabled globally (`WFBE_C_ENVIRONMENT_WEATHER_VOLUMETRIC = 0`, `Common/Init/Init_CommonConstants.sqf:382`, re-asserted on the client at `Client/Init/Init_Client.sqf:254`), and the disabled-cycle transition period is `WFBE_C_ENVIRONMENT_WEATHER_TRANSITION = 600` seconds (`Common/Init/Init_CommonConstants.sqf:383`). The server logs `Init_Server.sqf: Weather module is loaded.` after the block (`Server/Init/Init_Server.sqf:197`).

## Continue Reading

- [Public Variable Channel Index](Public-Variable-Channel-Index) — the `WFBE_DAYNIGHT_DATE` channel in the full PV inventory.
- [Mission Start Parameters Index](Mission-Start-Parameters-Index) — the lobby rows for `WFBE_DAYNIGHT_ENABLED`, day and night duration.
- [Mission Parameters Localization And Generated Build Inputs](Mission-Parameters-Localization-And-Generated-Build-Inputs) — where the volumetric-weather force-off is noted.
- [Networking And Public Variables](Networking-And-Public-Variables) — broader public-variable and JIP networking model.
- [Server Runtime And Operations](Server-Runtime-And-Operations) — server-side loops and init ordering.
