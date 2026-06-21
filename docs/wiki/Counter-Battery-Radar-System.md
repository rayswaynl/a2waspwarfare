# Counter-Battery Radar System (CBR detection, radius tiers, AI threat)

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

The **Counter-Battery Radar (CBR)** detects enemy artillery the moment it fires, drops a timed "CB CONTACT" marker on the firing position for the owning side, and arms the AI commander's artillery-threat response. It is a config-gated WEST/EAST endgame structure (`WFBE_C_STRUCTURES_COUNTERBATTERY`) with its own research track, detection-radius tiers, per-gun rate limiting, and a parallel static "airfield CBR" variant. This page documents the end-to-end runtime; the build entry itself is catalogued in [Faction Base Structures Catalog](Faction-Base-Structures-Catalog).

---

## Enable Gate and Eligibility

The whole system is behind one parameter, defaulted on:

| Constant | Default | Source |
|----------|--------:|--------|
| `WFBE_C_STRUCTURES_COUNTERBATTERY` | `1` (enabled) | `Common/Init/Init_CommonConstants.sqf:576` |
| `WFBE_C_CBR_FIRE_MISSION_WINDOW` | `30` s (read with fallback; not set in constants) | `Server/Functions/Server_CounterBattery.sqf:41` |

Every entry point exits immediately when the gate is `0`: the detection function (`Server_CounterBattery.sqf:22`), the PVF handler (`Server/PVFunctions/CounterBatteryFired.sqf:9`), the registry init (`Server/Init/Init_Server.sqf:113`), and the artillery Fired-EH install (`Common/Functions/Common_FireArtillery.sqf:45`).

The buildable **CB Radar structure** ($2,400, `SmallSite`) exists only in the WEST and EAST structure files (`Structures_CO_US.sqf:99-108`, `Structures_CO_RU.sqf:99-108`); the GUER/CDF/INS files stop at AA Radar, so **resistance has no CBR** (`Server/FSM/server_town.sqf:520` comment: "resistance has no CBR registry").

---

## Per-Side CBR Registry

The server keeps one CBR array per side and scans it on every enemy artillery shot.

| Step | Behaviour | Source |
|------|-----------|--------|
| Init | `WFBE_CBR_WEST` / `WFBE_CBR_EAST` set to `[]` (gated) | `Server/Init/Init_Server.sqf:113-115` |
| Register on build | A constructed `CBRadar` SmallSite is appended to its side's registry and gets composition dressing | `Server/Construction/Construction_SmallSite.sqf:111-121` |
| Auto-walls skipped | `CBRadar` and `AARadar` are excluded from auto-wall construction | `Server/Construction/Construction_SmallSite.sqf:123-130` |
| Prune | Dead/null CBRs are filtered out of the registry at the end of each detection scan | `Server/Functions/Server_CounterBattery.sqf:100-104` |

Pruning uses an explicit filter loop, not `select {…}` — the source notes that the `select` command form is Arma 3-only (`Server_CounterBattery.sqf:101`).

### Airfield static CBRs

Some maps place a static CBR at an airfield. When such a location changes hands, `server_town.sqf` removes the old radar from **both** side registries and deletes it, then — only for WEST/EAST — spawns a fresh radar, registers it under the new owner, and pins its detection radius to a fixed **2000 m** via `wfbe_cbr_radius` (broadcast so clients draw the fixed circle rather than an upgrade tier):

- De-register + delete old radar: `Server/FSM/server_town.sqf:508-517`
- Spawn, fixed-radius set, dressing, client circle init, re-register: `Server/FSM/server_town.sqf:521-560`

The per-object `wfbe_cbr_radius` override is read first in detection (`Server_CounterBattery.sqf:69`), so airfield CBRs ignore the upgrade-tier radius below.

---

## Detection Flow

```
enemy artillery fires
        │  ('Fired' EH installed by Common_FireArtillery.sqf when gate on)
        ▼
 server-local gun ──► WFBE_SE_FNC_CounterBatteryCheck   (AI arty is server-local)
 player-crewed gun ─► "CounterBatteryFired" SendToServer ─► CounterBatteryFired.sqf ─► same check
        ▼
 Server_CounterBattery.sqf: rate-limit ► count fire missions ► scan opposing CBR registry ► notify
```

The Fired event handler is installed on the artillery vehicle only when the gate is on (`Common/Functions/Common_FireArtillery.sqf:45-53`). Because the EH fires in the vehicle's locality, AI artillery (server-local) calls the check directly, while a player-crewed gun routes the event to the server through `WFBE_CO_FNC_SendToServer` → the `CounterBatteryFired` PVF (`Server/PVFunctions/CounterBatteryFired.sqf:15`). Both paths converge on `WFBE_SE_FNC_CounterBatteryCheck`, which always runs server-side (`Server/Functions/Server_CounterBattery.sqf`).

### What the check does

| Stage | Logic | Source |
|-------|-------|--------|
| Rate limit | Skip if this gun pinged a CBR within the last 10 s (`wfbe_cbr_lastping`) | `Server_CounterBattery.sqf:31-32` |
| Fire-mission count | Once per `WFBE_C_CBR_FIRE_MISSION_WINDOW` (30 s) per side, increment `wfbe_aicom_enemy_arty_fire_count` on the opposing side's logic | `Server_CounterBattery.sqf:41-48` |
| Arm threat (cond-b) | At `>= 3` fire missions, set `wfbe_aicom_arty_threat = true` on the opposing logic | `Server_CounterBattery.sqf:50-54` |
| Scan | For each CBR on the **opposing** side, compare firing distance to the CBR's radius | `Server_CounterBattery.sqf:58-98` |
| Notify | On a hit, mark the gun's rate limit and send a side-targeted `CounterBatteryContact` PVF with `[markerPos, "HH:MM"]` | `Server_CounterBattery.sqf:80-95` |

The opposing-side registry is chosen by the firing side: a WEST gun is scanned against `WFBE_CBR_EAST` and vice-versa (`Server_CounterBattery.sqf:58`).

---

## Detection Radius and the CBRADAR Upgrade

Unless a per-object override is set, the detection radius scales with the detecting side's Counter-Battery Radar research level (`WFBE_UP_CBRADAR = 22`, `Common/Init/Init_CommonConstants.sqf:59`):

| Research level | Detection radius | Source |
|---------------:|-----------------:|--------|
| 0 | 750 m | `Server/Functions/Server_CounterBattery.sqf:76` |
| 1 | 1,500 m | `Server/Functions/Server_CounterBattery.sqf:76` |
| 2 (max) | 2,000 m | `Server/Functions/Server_CounterBattery.sqf:76` |

The level is read from the side logic's `wfbe_upgrades` array at index `WFBE_UP_CBRADAR` and clamped to 2 (`Server_CounterBattery.sqf:72-76`). The **CBRADAR research** itself (from the WEST reference `Upgrades_CO_US.sqf`):

| Property | Value | Source |
|----------|-------|--------|
| Levels | 2 | `Upgrades_CO_US.sqf:84` |
| Cost (funds, supply) | L1 `[3500,0]`, L2 `[6500,0]` | `Upgrades_CO_US.sqf:56` |
| Research time | 60 s / 90 s | `Upgrades_CO_US.sqf:148` |
| Prerequisite | L1 requires AA Radar research L1; L2 requires AA Radar research L2 | `Upgrades_CO_US.sqf:120` |
| Availability | gated on `WFBE_C_STRUCTURES_COUNTERBATTERY > 0` | `Upgrades_CO_US.sqf:28` |

So the CB Radar *research* is gated behind the AA Radar research, matching the design note "requires own AAR" (`Init_CommonConstants.sqf:576`). The buildable structure itself gates only on the `COUNTERBATTERY` parameter. Upgrade-array column semantics are owned by [Upgrade Research (cross-faction)](Upgrade-Research-Cross-Faction-Reference).

---

## Client Contact Marker

`CounterBatteryContact` is addressed to a specific side, so only clients on the detecting side receive it (`Server_CounterBattery.sqf:92-93`). The handler draws a local, timed map marker:

| Property | Value | Source |
|----------|-------|--------|
| Marker type | `mil_destroy`, colour `ColorRed`, size `[0.8, 0.8]` | `Client/PVFunctions/CounterBatteryContact.sqf:22-25` |
| Text | `"CB CONTACT" + " HH:MM"` (`STR_WF_CBR_Contact` = "CB CONTACT", `stringtable.xml:9527-9528`) | `Client/PVFunctions/CounterBatteryContact.sqf:19` |
| Lifetime | auto-deleted after 75 s | `Client/PVFunctions/CounterBatteryContact.sqf:28` |
| Guard | no-op if `WFBE_Client_SideID` is nil (uninitialised client) | `Client/PVFunctions/CounterBatteryContact.sqf:13` |

The marker is local (`createMarkerLocal`), so it is per-client and JIP-safe by construction — late joiners simply never see expired contacts.

---

## AI Commander Threat Response

The CBR detection path is one of three inputs that arm the AI commander's artillery-threat flag, `wfbe_aicom_arty_threat`, on a side's logic. **This is AI scaffold only — human commanders are unaffected** (`Server/AI/Commander/AI_Commander_Base.sqf:218-223`).

| Condition | Trigger | Threshold | Source |
|-----------|---------|-----------|--------|
| (a) | Friendly units killed by enemy artillery | `>= 2` arty kills | `Server/PVFunctions/RequestOnUnitKilled.sqf:71` |
| (b) | Enemy fire missions observed via CBR path | `>= 3` fire missions | `Server/Functions/Server_CounterBattery.sqf:50` |
| (c) | Enemy has a built artillery piece and round time `> 60 min` | first qualifying scan | `Server/AI/Commander/AI_Commander_Base.sqf:234-244` |

Once armed, the AI scaffold lets `CBRadar` enter its build order — further gated by round time `>= WFBE_C_AICOM_CBR_MIN_TIME` (default 2,700 s / 45 min) and supply `>= CBR cost + WFBE_C_AICOM_SUPPLY_RESERVE` (default 500) (`AI_Commander_Base.sqf:251-259`) — and appends CBR research reactively (`Server/AI/Commander/AI_Commander.sqf:240`). Each arming logs an `AICOMSTAT|v1|EVENT|…|ARTY_THREAT_ARMED|cond-a/b/c` telemetry line (`Server_CounterBattery.sqf:53`, `RequestOnUnitKilled.sqf:74`, `AI_Commander_Base.sqf:244`).

---

## Continue Reading

- [Faction Base Structures Catalog](Faction-Base-Structures-Catalog) — the CB Radar build entry, cost and classname alongside the other base structures
- [Upgrade Research (cross-faction)](Upgrade-Research-Cross-Faction-Reference) — the CBRADAR research track and the AA Radar prerequisite chain
- [AI Commander Autonomy Audit](AI-Commander-Autonomy-Audit) — how the `wfbe_aicom_arty_threat` flag drives the AI commander's reactive build/research
- [Construction and CoIn Systems Atlas](Construction-And-CoIn-Systems-Atlas) — the SmallSite construction worker that builds and registers the CB Radar
- [Networking and Public Variables](Networking-And-Public-Variables) — the `SendToServer` / `SendToClients` PVF routing used by the fired-EH and contact-marker paths
