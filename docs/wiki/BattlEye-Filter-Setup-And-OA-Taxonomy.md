# BattlEye Filter Setup and OA File Taxonomy

> Source-verified 2026-06-21 against then-current master cf2a6d6a4; current origin/master is 0139a346, so recheck cited paths before current-head claims. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

This page is the operator guide for BattlEye filter setup on a public WASP Warfare server. It documents the one shipped filter file, the complete AFK-kick flow it enables, the OA-era filter file taxonomy an operator must supply, and how to verify that filters load. The security posture summary lives in [External Integrations](External-Integrations); this page is the actionable setup companion to it.

---

## What The Repo Ships

Only one BattlEye file is committed to the repository (`BattlEyeFilter/` at repo root, not inside the mission folder):

| File | Full content | Purpose |
| --- | --- | --- |
| `BattlEyeFilter/publicvariable.txt` | `//new` then `5 "kickAFK"` | Enables BattlEye-mediated AFK kick. Rule `5` = kick any client that broadcasts the named variable. |

There is no `scripts.txt`, `createvehicle.txt`, `setvariable.txt`, `setdamage.txt`, `deletevehicle.txt`, `mpeventhandler.txt`, `basic.cfg` or `server.cfg` in the repository. The repo cannot claim shipped public-server BattlEye hardening beyond the single `kickAFK` rule. (`BattlEyeFilter/publicvariable.txt:1-2`; confirmed by [External Integrations](External-Integrations).)

A `.docx` README (`BattlEyeFilter/READ ME FIRST - Using BattlEye filter to auto kick.docx`) accompanies the filter. Its content is captured in this page.

---

## AFK Kick Flow End-to-End

The shipped `publicvariable.txt` rule is the endpoint of a multi-step client-side flow. No `serverCommand` path is used; that command is unavailable or disabled in the OA multiplayer context, which is why BattlEye is the kick mechanism.

### Step 1 — Timeout parameter

`WFBE_C_AFK_TIME` is a lobby parameter exposed to the server operator via `Rsc/Parameters.hpp:51-56`. Its allowed values and defaults are:

| Values (minutes) | Default |
| --- | --- |
| 1, 5, 10, 15, 20, 30 | 15 |

At single-player / non-multiplayer (solo testing), `updateclient.sqf:27` hard-sets `WFBE_C_AFK_TIME = 10` via `missionNamespace setVariable`. In multiplayer the lobby value is used directly.

### Step 2 — Client loop reads and converts the parameter

`Client/FSM/updateclient.sqf:28-29`:
```
_rawInactivityTimeout = missionNamespace getVariable "WFBE_C_AFK_TIME";
_inactivityTimeout = _rawInactivityTimeout * 60;
```
The raw value (minutes) is multiplied by 60 to produce seconds. When `WF_Debug` is true, `_inactivityTimeout` is further multiplied by `99999` so AFK kick never fires during debug sessions (`updateclient.sqf:31`).

### Step 3 — AFK warning countdown

While the elapsed time since last movement approaches the timeout, the client loop shows hint warnings:

- More than 120 seconds remaining: hint every 30 seconds with minutes remaining (`updateclient.sqf:153-155`).
- 120 seconds or fewer remaining: hint every loop tick with seconds remaining (`updateclient.sqf:157-159`).

The `WASP_AFK` variable is broadcast globally (via `player setVariable [..., true]`) when the countdown drops below 600 seconds, and cleared when the player becomes active again (`updateclient.sqf:132-136`). This drives minimap AFK markers visible to other players.

### Step 4 — Kick broadcast

When `_elapsedTime > _inactivityTimeout` (`updateclient.sqf:139`):

1. `AFKthresholdExceededName` is set to the player name and sent to the server via `publicVariableServer` (`updateclient.sqf:145-146`). The server receives this for its own logging/record but does not itself execute a kick.
2. `kickAFK` is set to `format["%1 Kicked for AFKing", _namePlayer]` and broadcast to all machines via `publicVariable` (`updateclient.sqf:148-149`).

BattlEye intercepts the `kickAFK` broadcast from that client and, if `publicvariable.txt` rule `5 "kickAFK"` is loaded, kicks the broadcasting player. The client loop exits via the `!_afkKickRequested` guard (`updateclient.sqf:43`).

### Why `publicVariable` and not `serverCommand`

`serverCommand` is not available to clients in Arma 2 OA multiplayer. The BattlEye filter is the only mechanism by which a client can trigger its own kick without server-side authority intervention. This is intentional by design; the comment at `updateclient.sqf:138` states: "request the real BattleEye kick through the public variable filter."

---

## BattlEye Filter File Path (BEpath)

BattlEye filter files are read from the directory pointed to by `BEpath` in `server.cfg`. If `BEpath` is not set, the default location is a `battleye/` subdirectory under the server profile/userdata directory.

Copy `BattlEyeFilter/publicvariable.txt` (repo root) into your active `BEpath` directory alongside any other filter files you create. The file must be named exactly `publicvariable.txt` (lowercase).

---

## OA-Era Filter File Taxonomy

The following table lists the filter files relevant to Arma 2 OA. Each file controls a specific class of client action; BattlEye applies rule entries in order and kicks/logs on a match. Do **not** list `remoteexec.txt` — `remoteExec` and `remoteExecCall` are Arma 3 commands and do not exist in OA.

| File | What it filters | WASP relevance |
| --- | --- | --- |
| `publicvariable.txt` | `publicVariable` / `publicVariableServer` / `publicVariableClient` broadcasts by name | **Required.** Repo ships rule `5 "kickAFK"`. All other channels (PVF, supply, attack waves, etc.) are currently unfiltered; see [Public Variable Channel Index](Public-Variable-Channel-Index). |
| `scripts.txt` | Script commands executed on a client (covers client-side `createVehicle`, `createUnit`, `addWeapon`, etc.) | High value for public servers; prevents script injection and unsanctioned unit spawning from client machines. Not present in repo. |
| `createvehicle.txt` | `createVehicle` calls from clients | Supplement to `scripts.txt`; catches direct classname spawns. Not present in repo. |
| `setvariable.txt` | `setVariable` calls from clients | Protects mission namespace and object variable manipulation. Not present in repo. |
| `setdamage.txt` | `setDamage` calls from clients | Prevents client-triggered instant damage/destruction. Not present in repo. |
| `deletevehicle.txt` | `deleteVehicle` / `deleteGroup` calls from clients | Prevents unauthorized object deletion. Not present in repo. |
| `mpeventhandler.txt` | `addMPEventHandler` registrations from clients | Restricts unauthorized event hook registration. Not present in repo. |

Additional OA filter files (lower priority for most servers): `setpos.txt`, `teamswitch.txt`, `selectplayer.txt`, `attachto.txt`, `cargo*.txt`, `waypointcondition.txt`. Include these if your server population and threat model warrant them.

---

## Rule Entry Format

Each line in a BattlEye filter file is one rule. The format is:

```
<action_code> "<regex_pattern>"
```

| Action code | Meaning |
| --- | --- |
| `1` | Log to `BEserver.log` only |
| `2` | Log and kick |
| `3` | Log and kick (alternative) |
| `4` | Log and ban (1 minute) |
| `5` | Kick (no log to ban list) |
| `7` | Kick and log |

The shipped rule `5 "kickAFK"` uses action code `5`: kick any player whose client broadcasts a variable matching the pattern `kickAFK` (exact string match as BattlEye treats the pattern as a regex; `kickAFK` with no regex metacharacters matches exactly that variable name).

The first line of `publicvariable.txt` is `//new` — this is a comment marker BattlEye ignores.

---

## Verifying Filters Are Loaded

BattlEye logs filter-load events to the server's `BattlEye/BEserver.log`. On startup, look for a line similar to:

```
Filter(publicvariable.txt) loaded
```

If the file is missing from the active `BEpath` or is unreadable, BattlEye will not report loading it. Test the AFK kick path in a local non-dedicated or LAN server by setting `WFBE_C_AFK_TIME = 1` in the lobby and confirming that a stationary client is kicked after approximately 60 seconds. Check `BEserver.log` for a `Kicked` entry referencing `kickAFK` to confirm the filter fired (rather than the kick coming from a different path).

---

## Operator Setup Checklist

1. Locate your active `BEpath` (or create a `battleye/` directory under your server profile).
2. Copy `BattlEyeFilter/publicvariable.txt` from the repo into that directory.
3. Create additional filter files (`scripts.txt`, `createvehicle.txt`, etc.) appropriate for your server's public exposure. The repo provides no template for these.
4. Set `WFBE_C_AFK_TIME` in the lobby to your preferred timeout (default 15 minutes; `Rsc/Parameters.hpp:51-56`).
5. After server startup, confirm `Filter(publicvariable.txt) loaded` appears in `BEserver.log`.
6. Record the full `BEpath`, all active filter files and their versions in your deployment inventory (see [Server Ops Runbook](Server-Ops-Runbook)).

---

## Continue Reading

- [External Integrations](External-Integrations) — canonical security posture: what the repo ships and what it explicitly does not claim to protect
- [Public Variable Channel Index](Public-Variable-Channel-Index) — full inventory of every `publicVariable` channel; the design surface for extending `publicvariable.txt` beyond `kickAFK`
- [Networking And Public Variables](Networking-And-Public-Variables) — architecture overview of PVF dispatch, trust boundaries and authority model
- [Server Ops Runbook](Server-Ops-Runbook) — deployment inventory checklist, missing artifact register and release steps
- [Variable And Naming Conventions](Variable-And-Naming-Conventions) — `WFBE_C_*` parameter naming conventions referenced above
