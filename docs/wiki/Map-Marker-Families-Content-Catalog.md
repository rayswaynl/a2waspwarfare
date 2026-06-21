# Map Marker Families Content Catalog (name, type, color, locality per family)

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

A content lookup of every map-marker **family** the mission produces: marker-name pattern, marker TYPE (icon class), COLOR, SIZE, TEXT source, LOCALITY, and the CREATOR `path:line`. This page is the *what* (one compact table per family). For the *how* — the registrar/registry/consolidated-loop architecture, per-tick gating, and the FSM updaters — see [Marker Loop Engine and Registries](Marker-Loop-Engine-And-Registries) and [Client Marker FSM Updater Map](Client-Marker-FSM-Updater-Map). For the marker function APIs (`WF_createMarker`, `WFBE_CL_FNC_Delete_Marker`, `MarkerUpdate`), see [Marker Subsystem Function Reference](Marker-Subsystem-Function-Reference).

---

## Locality primer (A2 OA 1.64)

| Verb | Replicates? | Used by |
|------|-------------|---------|
| `createMarkerLocal` | No — marker exists on the calling client only | Almost every family below (town, camp, base, unit, team, patrol, AICOM, sniper, CBR-contact, ICBM-warning, UAV-spotted, respawn, airport, FT, defense rings, sell-preview) |
| `createMarker` | **Yes** — existence + position replicate to all clients | Current master AICOM-wildcard convoy/HVT, Bank, UAV self-marker, and `WF_createMarker` callers (fire mission, commander ICBM, radzone). PR #43 B68 removes the W17 convoy global marker. |
| `setMarker*Local` | No — style/text/pos local only | local recolor, live text, capture recolor |
| `setMarker*` (bare) | **Yes** | the GLOBAL families' initial style; sniper text (`setMarkerText`, `Skill_Sniper.sqf:16`) on an otherwise-local marker |

"GLOBAL" below means the marker's *existence* is created by `createMarker` and so is map-visible cross-client. Some GLOBAL markers (the `WF_createMarker` ones) still apply their **type/text/color only locally**, gated on `playerSide == _side_who_see_marker` (`Common/Functions/Common_CreateMarker.sqf:62-78`), so they exist everywhere but only paint for the addressed side.

---

## Marker-name counters

Each family draws its numeric suffix from a global counter. Several families share one counter, so suffixes are not contiguous within a family.

| Counter | Init | Families that increment it |
|---------|------|----------------------------|
| `unitMarker` | `Common/Init/Init_Common.sqf:177` (`unitMarker = 0`) | Unit/Vehicle (`Common/Init/Init_Unit.sqf:157`), AA-Radar (`Common/Common_AARadarMarkerUpdate.sqf:11`), Paratrooper (`Client/PVFunctions/HandleParatrooperMarkerCreation.sqf:29`), UAV-spotted (`Client/Functions/Client_FNC_Special.sqf:100`), respawn-menu (`Client/GUI/GUI_RespawnMenu.sqf`) — **shared across 5 families** |
| `buildingMarker` | `Client/Init/Init_Client.sqf:324` (`= 0`) | Base structure (`Client/Init/Init_BaseStructure.sqf:22`), commander defense rings (`Client/GUI/GUI_Menu_Tactical.sqf:717-718`) |
| `CCMarker` | `Client/Init/Init_Client.sqf:325` (`= 0`) | UAV-terminal range ring (`Client/Init/Init_BaseStructure.sqf:24`) |
| `CBRCircleMarker` | `Client/Init/Init_Client.sqf:326` (`= 0`) | CBR range ring (`Client/Init/Init_BaseStructure.sqf:59`) |
| `markerID` | `Client/Module/Skill/Skill_Sniper.sqf:10` (`if (isNil "markerID") then {markerID = 1}`) | Sniper spot (`Skill_Sniper.sqf:20`) |

The UAV self-marker walks its own free `_id` (loops while `markertype` is non-empty, `Client/Module/UAV/uav_interface.sqf:158-159`) rather than a global counter. Convoy/HVT, radzone, fire-mission, ICBM and CBR-contact suffix on a time token (`round time` / `diag_tickTime` / `str time`).

---

## TOWN

| Field | Value |
|-------|-------|
| Name | `WFBE_<townLogic>_CityMarker` (`Client/Init/Init_Markers.sqf:21`) |
| Type | `"Depot"` (`Init_Markers.sqf:23`) |
| Color | own-side `WFBE_C_<side>_COLOR` if `_townSide == WFBE_Client_SideID`, else `WFBE_C_UNKNOWN_COLOR` (`Init_Markers.sqf:15-17,24`) |
| Size | default (none set at creation) |
| Text | live SV/supply label set by FSM `Client/FSM/updatetownmarkers.sqf` — `"  SV: x/y  [+SUPPLY]"` `:40`, `"  SV: x/y  [+]"` `:42`, `"  SV: x/y  [mm:ss]"` `:53`, plain `:60`, cleared `""` `:63` |
| Creator | `Init_Markers.sqf:22` (`createMarkerLocal`) |
| Locality | **local** — side-recolored per client; recolored on capture `Client/PVFunctions/TownCaptured.sqf:24` |

## CAMP (town sub-objective)

| Field | Value |
|-------|-------|
| Name | `WFBE_<town>_CityMarker_Camp<i>` — assigned server-side `Common/Init/Init_Town.sqf:156`, read by clients via `_x getVariable "wfbe_camp_marker"` (`Init_Markers.sqf:44`) |
| Type | `"Strongpoint"` (`Init_Markers.sqf:46`) |
| Color | own-side / `WFBE_C_UNKNOWN_COLOR` (`Init_Markers.sqf:38-40,47`) |
| Size | `[0.5,0.5]` (`Init_Markers.sqf:48`) |
| Creator | `Init_Markers.sqf:45` (`createMarkerLocal`) |
| Locality | **local**; recolored on capture `Client/PVFunctions/CampCaptured.sqf:23,48` |

## BASE STRUCTURE (per-building, incl. HQ icon, ServicePoint, range rings)

File `Client/Init/Init_BaseStructure.sqf`, guarded `if (local player)` (`:7`) + own-side gate `if (_side != WFBE_Client_SideJoined) exitWith {}` (`:17`).

| Sub-marker | Name | Type | Color | Size | Text | Creator |
|------------|------|------|-------|------|------|---------|
| Structure icon | `BaseMarker<buildingMarker>` (`:21`) | `"mil_box"`, or `"Headquarters"` if `_hq` (`:34,36,37`) | `"colorBlack"` (`:35,43`) | `[0.5,0.5]` for non-HQ (`:40`) | letter from `GetStructureMarkerLabel` (`:40,42`) | `:25` (`createMarkerLocal`) |
| ServicePoint variant | (same marker, when label `== "S"`) | `"mil_objective"` (`:47`) | side color `WFBE_C_<side>_COLOR` (`:49`) | — | `"SP"` (`:48`) | `:46-50` |
| UAV-terminal range ring | `CCrange<CCMarker>` (`:23`) | Ellipse/Border (`:30,29`) | `"ColorBlack"` (`:31`) | `[_radius,_radius]` where `_radius = WFBE_C_STRUCTURES_COMMANDCENTER_RANGE` (`:15,32`) | — | `:28-32`; deleted with structure `:118` |
| CBR range ring | `CBRrange<CBRCircleMarker>` (`:58`) | Ellipse/Border (`:76,77`) | `"ColorRed"` (`:78`) | `[_cbrRadius,_cbrRadius]` (`:79`); live-resized in watch `:104`; deleted `:111` | — | `:75-79` |

Structure-icon label letters (`Client/Functions/Client_GetStructureMarkerLabel.sqf:14-23`): `B` Barracks, `L` Light, `C` CommandCenter, `H` Heavy, `A` Aircraft, `S` ServicePoint, `R` Bank/Federal Reserve, `AAR` AARadar, `AR` ArtilleryRadar, `RES` Reserve; default `""`. The structure marker is deleted on death (`:117`). The CBR ring radius is the fixed airfield 2000 m when the server broadcasts `wfbe_cbr_radius` (`Server/FSM/server_town.sqf:537`; read `Init_BaseStructure.sqf:63`, treated as the "fixed" non-resizing case `:91`), otherwise the upgrade tier `[750,1500,2000]` (`:64,72`).

**Locality:** all base-structure sub-markers are **local** (`createMarkerLocal`).

## MHQ / HQ vehicle (mobile HQ unit marker)

| Field | Value |
|-------|-------|
| Name | `HQUndeployed` (literal, single per side) — `Common/Init/Init_Unit.sqf:186` |
| Type | `"Headquarters"` (`Init_Unit.sqf:186`) |
| Color | `"ColorPink"` (`Init_Unit.sqf:186`) |
| Size | `[1,1]` (`Init_Unit.sqf:186`) |
| Refresh | `0.2` s, no death-marker (`trackDeath = false`, `Init_Unit.sqf:186`) |
| Creator | params built `Init_Unit.sqf:186` → `_params Spawn MarkerUpdate` (`:201`) → `createMarkerLocal` in registrar `Common/Common_MarkerUpdate.sqf:39` |
| Locality | **local** (registry/loop, side-gated `Common_MarkerUpdate.sqf:25`) |

There is **no `HQDeployed` marker** — `HQUndeployed` is the only HQ-vehicle marker name in the whole mission (single source ref, `Init_Unit.sqf:186`); deploy/undeploy does not rename it.

## UNIT / VEHICLE (tracked infantry + vehicles)

File `Common/Init/Init_Unit.sqf:148-201`; side gate `if (!_perfSideMatch) exitWith {}` (`:146`).

| Field | Value |
|-------|-------|
| Name | `unitMarker<unitMarker>` (`Init_Unit.sqf:157-158`) |
| Type (man) | `"mil_dot"` (`:161`); immobile-vehicle override to `"mil_objective"` applied in the loop (`Common/Common_MarkerLoop.sqf:329`), not at creation |
| Type (vehicle) | role-keyed: `"SupplyVehicle"` (`:173`), `"RepairVehicle"` (`:174`), `"Attack"` (ammo truck `:179`), `"SalvageVehicle"` (`:184`); else default `"Vehicle"` (`:151`) |
| Color | own group `"ColorOrange"` (`:164`); Bicycle `"ColorWhite"` (`:169`); Plane/Heli `"ColorPink"` (`:170,171`); local+MP `"ColorOrange"` (`:172`); ammo `"ColorRed"` (`:179`); lifter `"ColorWhite"` (`:181`); ambulance `"ColorYellow"` (`:182`); salvage `"ColorKhaki"` (`:184`); repair `"ColorBrown"` (`:174`); arty `"ColorPink"` (`:176`); else side color (`:152`) |
| Size | man `[0.5,0.5]` (`:162`); supply `[1,1]` (`:173`); ammo `[0.4,0.4]` (`:179`); else `[5,5]` (`:153`) |
| Text | own-group AI digit via `GetAIDigit` (`:165`), else `""` |
| Death marker | type `"DestroyedVehicle"`, color = last color, applied in the loop for `WFBE_C_PLAYERS_MARKER_DEAD_DELAY` (`Common_MarkerLoop.sqf:176-182`); params carry it at index 8/9 (`Init_Unit.sqf:167,185`) |
| Creator | `_params Spawn MarkerUpdate` (`:201`) → `createMarkerLocal` registrar `Common_MarkerUpdate.sqf:39` |
| Locality | **local** (side-gated `Common_MarkerUpdate.sqf:25`) |

Combat-blink recolor (red↔original) is attached only when `WFBE_C_MAP_ICON_BLINKING_ENABLED == 1` (`Init_Unit.sqf:190`); the recolor helper `Client/Functions/Client_BlinkMapIcon.sqf:18,23,31,37` only re-colors an existing unit marker — it creates none.

## PARATROOPER

Effectively a Unit-family marker; distinguished only by its spawn path and audit tag. File `Client/PVFunctions/HandleParatrooperMarkerCreation.sqf`; side gate `if (sideID != _sideID) exitWith {}` (`:18`).

| Field | Value |
|-------|-------|
| Name | `unitMarker<unitMarker>` (`:29-30`) |
| Type | `"mil_dot"` (`:32`) |
| Color | own group `"ColorOrange"` (`:35`), else side color (`:24`) |
| Size | `[0.5,0.5]` (`:33`) |
| Creator | params `:38` → `_params Spawn MarkerUpdate` (`:40`) → `Common_MarkerUpdate.sqf:39` |
| Locality | **local** (audit-tagged `paratrooper_marker_spawn` `:45`) |

## AA-RADAR (enemy-aircraft tracking)

Registrar `Common/Common_AARadarMarkerUpdate.sqf`, called from `Common/Init/Init_Unit.sqf:118` only when `WFBE_C_STRUCTURES_ANTIAIRRADAR > 0` and the tracked aircraft is on the **opposite** side (`:115-116`).

| Field | Value |
|-------|-------|
| Name | `unitMarker<unitMarker>` (`:11-12`) — shares the unit namespace |
| Type | `"mil_arrow2"` (filled arrow) (`:15`) |
| Color | `"ColorRed"` (`:16`) |
| Size | `[0.5,0.5]` (`:17`), alpha `0` until visible (`:18`) |
| Text (live) | `"<speed> <altitude> <name>"` written in the loop `Common/Common_MarkerLoop.sqf:469-471` (name only at AAR level > 1, `:457-459`); alpha→1 when visible `:464` |
| Creator | `:14` (`createMarkerLocal`); registry push `:45-46`; loop started `:50-51` |
| Locality | **local** (opposite-side gated `:33-39`) |

## TEAM (friendly squad/leader arrows)

File `Client/FSM/updateteamsmarkers.sqf`; one marker per `clientTeams` entry, cached by index.

| Field | Value |
|-------|-------|
| Name | `<sideText>AdvancedSquad<n>Marker` (`:22`) |
| Type | `"Arrow"` (`:25`) |
| Color | `"ColorBlack"` default (`:30`); player's own team `"ColorOrange"` (`:33`); live recolor `:243` |
| Size | `[0.7,0.7]` (`:27`), alpha `0` initial (`:28`) |
| Text | AI digit / role label `_label` set `:227`, cleared `""` `:259` |
| Creator | `:24` (`createMarkerLocal`) |
| Locality | **local**; arrow direction follows velocity (`setMarkerDirLocal`, FSM follow pass) |

## PATROL (friendly side-patrol leaders, Patrols upgrade)

File `Client/FSM/updatepatrolmarkers.sqf`; tracks `WFBE_ACTIVE_PATROLS` (`:19`).

| Field | Value |
|-------|-------|
| Name | `wfbe_patrolmarker_<i>` (`:32`) |
| Type | `"mil_arrow2"` (`:37`) |
| Color | `"ColorYellow"` (`:38`) |
| Size | `[0.6,0.6]` (`:39`) |
| Text | `"Patrol <i>"` (`:40`) |
| Creator | `:35` (`createMarkerLocal`); deleted on death `:73` |
| Locality | **local**, FRIENDLY-ONLY (`_sid == WFBE_Client_SideID`, `:25`) |

## AICOM (AI-commander HQ-team arrows)

File `Client/FSM/updateaicommarkers.sqf`; tracks `WFBE_ACTIVE_AICOM_TEAMS` (`:23`).

| Field | Value |
|-------|-------|
| Name | `wfbe_aicommarker_<i>` (`:56`) |
| Type | `"mil_arrow2"` (`:59`) |
| Color | side color by entry `sideID` (`:49-54,60`) |
| Size | `[0.7,0.7]` (`:61`) |
| Text | `"HQ Team"` (`:62`) |
| Creator | `:58` (`createMarkerLocal`); deleted `:109` |
| Locality | **local**, FRIENDLY-ONLY (`_sid == _mySid` where `_mySid = WFBE_Client_SideID`, `:34,42` — intel-leak guard) |

## AICOM WILDCARD events (server-global)

File `Server/Functions/AI_Commander_Wildcard.sqf`. On current `origin/master@0139a346`, these are the **GLOBAL, fully-cross-side-visible** wildcard markers created with bare `createMarker`/`setMarker*` server-side. PR #43 / B68 branch head `b8a1505f` removes the W17 Supply Convoy global marker route at Chernarus `AI_Commander_Wildcard.sqf:994` because own-side convoy visibility already comes through friendly unit markers; W18 remains intentionally global branch evidence until separately changed.

| Sub-family | Name | Type | Color | Text | Creator / delete |
|------------|------|------|-------|------|------------------|
| Supply Convoy (W17) | `aicom_convoy_<sideText>_<round time>` (`:980`) | `"mil_destroy"` (`:982`) | `"ColorBlue"` west / `"ColorRed"` (`:983`) | `"Supply Convoy (<side>)"` (`:984`) | create `:981`; `deleteMarker` `:1006` |
| Bounty HVT (W18) | `hvt_<sideText>_<round time>` (`:1036`) | `"mil_dot"` (`:1038`) | `"ColorBlue"` west / `"ColorRed"` (`:1039`) | `"HVT (<enemySide>)"` (`:1040`) | create `:1037`; `deleteMarker` `:1045` |

**Locality:** GLOBAL (visible to all sides) on current master. Branch note: `origin/claude/b57-soak-proposals@b8a1505f` removes W17 creation, so smoke PR #43 for friendly-only convoy visibility and enemy non-visibility before merging or release wording.

## SUPPLY / ECONOMY

| Sub-family | Name | Type | Color | Size | Text | Locality | Creator |
|------------|------|------|-------|------|------|----------|---------|
| Bank (Federal Reserve / Bank Rossii) | `wfbe_bank_<west\|east>` (`Server/Construction/Construction_MediumSite.sqf:134`) | `"mil_warning"` (`:138`) | `"ColorBlue"` west / `"ColorRed"` east (`:135`) | default | `"FEDERAL RESERVE"` / `"BANK ROSSII"` (`:136`) | **GLOBAL** (`createMarker` `:137`) | `:137-140` |
| Sell-mode preview | `wfbe_econ_sell_<idx>` (`Client/GUI/GUI_Menu_Economy.sqf:201`) | `"Empty"` (`:203`) | `"ColorYellow"` (`:204`) | `[0.7,0.7]` (`:205`) | `"$<refund>"` (`:206`) | **local** | `:202` (`createMarkerLocal`) |

## RESPAWN

| Sub-family | Name | Shape / Type | Color | Size | Locality | Creator |
|------------|------|--------------|-------|------|----------|---------|
| Side respawn zones | `respawn_east` / `respawn_west` / `respawn_guerrila` (`Common/Init/Init_Common.sqf:189,195,201`) | RECTANGLE / BORDER (`:191-192`) | `"ColorGreen"` (`:190`) | `[15,15]`, alpha 0 (`:193-194`) | **local** | `:189,195,201` (`createMarkerLocal`) |

## AIRPORT

| Field | Value |
|-------|-------|
| Name | `wfbe_airport_<i>` (`Common/Init/Init_Airports.sqf:25`) |
| Type | `"mil_triangle"` (`:26`) |
| Color | `"ColorYellow"` (`:27`) |
| Creator | `:25` (`createMarkerLocal`), guarded `if (local player)` (`:24`) |
| Locality | **local** |

## ARTILLERY / FIRE-MISSION / COUNTER-BATTERY

| Sub-family | Name | Type | Color | Size | Text | Locality | Creator / delete |
|------------|------|------|-------|------|------|----------|------------------|
| Player fire mission | `ARTY_<diag_tickTime>` + ellipse `Elipse_ARTY_...` (`Client/Functions/Client_RequestFireMission.sqf:22,29`) | `"Destroy"` (`:24`) | `"ColorRed"` (`:26`) | radius `_arty_radius` (`:28`) | `"ARTY [<player>]"` (`:25`) | **GLOBAL** via `WF_createMarker` (`:31`), side-gated display | auto-deleted 80 s `:32-33` |
| Tactical-menu arty preview | `artilleryMarker` + `artilleryAreaMarker` (`Client/GUI/GUI_Menu_Tactical.sqf:26,32`) | `"mil_destroy"` (`:28`) + Ellipse (`:34`) | `"ColorRed"` (`:29,35`) | `[1,1]` / `[artyRange,artyRange]` (`:30,36`) | — | **local** | `:27,33` (`createMarkerLocal`) |
| Counter-battery contact | `WFBE_CBR_<diag_tickTime>` (`Client/PVFunctions/CounterBatteryContact.sqf:18`) | `"mil_destroy"` (`:22`) | `"ColorRed"` (`:23`) | `[0.8,0.8]` (`:25`) | localized contact + time (`:19,24`) | **local** (side-addressed PVF) | `:21` (`createMarkerLocal`); auto-deleted 75 s `:28` |

## NUKE / ICBM / RADZONE

| Sub-family | Name | Type | Color | Text | Locality | Creator |
|------------|------|------|-------|------|----------|---------|
| ICBM impact warning | `icbmstrike` (`Client/Module/Nuke/OnEventHandler_ICBM_Launch.sqf:26`) | `"mil_warning"` (`:27`) | `"ColorRed"` (`:29`) | `"ICBM"` (`:28`) | **local**, side-gated (`playerSide == _ICBM_side`, `:22`) | `:26` (`createMarkerLocal`) |
| Commander ICBM (tactical) | `ICBM_<time>` + `Elipse_<name>` (`Client/GUI/GUI_Menu_Tactical.sqf:474,481`) | `"mil_warning"` (`:476`) | `"ColorRed"` (`:478`) | `"ICBM by commander"` (`:477`) | **GLOBAL** via `WF_createMarker` (`:483`) | `:483` |
| Radiation zone | `RADZONE_<west\|east>_<round time>_<rand>` + ellipse (`Client/Module/Nuke/radzone.sqf:57,58`) | `"mil_warning"` (`:51`) | `"ColorGreen"` (`:53`) | `"RADIOACTIVE ZONE"` (`:52`) | **GLOBAL** per-side via `WF_createMarker` (west `:64-73`, east `:76-85`) | `:64,76` |

## UAV

| Sub-family | Name | Type | Color | Size | Text | Locality | Creator |
|------------|------|------|-------|------|------|----------|---------|
| UAV self-marker | `_user_defined_UAV_MARKER_<id>` (`Client/Module/UAV/uav_interface.sqf:162`; OA variant `uav_interface_oa.sqf:68`) | `"mil_destroy"` (`:163` / `:69`) | `"colorred"` (`:164` / `:70`) | `[0.5,0.5]` (`:165` / `:71`) | `"UAV <id>: <time>"` (`:167` / `:73`) | **GLOBAL** (`createmarker`) | `:162` / `:68` |
| UAV spotted (FNC_Special) | `WFBE_UAV_SPOTTED_<unitMarker>` (`Client/Functions/Client_FNC_Special.sqf:99`) | Ellipse (`:102`) | `"ColorOrange"` (`:103`) | `[_size,_size]` (`:104`) | — | **local** | `:101` (`createMarkerLocal`); auto-deleted `:108` |

## SNIPER SPOT (skill)

File `Client/Module/Skill/Skill_Sniper.sqf`.

| Field | Value |
|-------|-------|
| Name | `Spot<markerID>` (`:13`) |
| Type | `"mil_destroy"` (`:17`) |
| Color | `"ColorRed"` (`:18`) |
| Size | `[0.5,0.5]` (`:19`) |
| Text | `"SPOTTED: <time>"` (`:16`) |
| Creator | `:14` (`createMarkerLocal`; text applied via global `setMarkerText` `:16`); auto-deleted 180 s `:27-28` |
| Locality | **local** |

## DEFENSIVE-RANGE rings (commander defense view)

File `Client/GUI/GUI_Menu_Tactical.sqf:715-733`; suffix walks the `buildingMarker` counter (`:717-718`).

| Sub-marker | Name | Shape | Color | Size / brush | Creator |
|------------|------|-------|-------|--------------|---------|
| Large range | `WFBE_A_Large<track>` (`:720`) | ELLIPSE (`:723`) | `"ColorBlue"` (`:722`) | `[_maxRange,_maxRange]`, alpha 0.4, brush by mode (`:725-729`) | `:721` (`createMarkerLocal`) |
| Small range | `WFBE_A_Small<track>` (`:730`) | ELLIPSE (`:733`) | `"ColorBlack"` (`:732`) | — | `:731` (`createMarkerLocal`) |

**Locality:** local.

## FAST-TRAVEL (tactical menu)

File `Client/GUI/GUI_Menu_Tactical.sqf`.

| Field | Value |
|-------|-------|
| Name | `FTMarker<i>` (`:201`); fee marker `FTMarker<i><i>` when `_ft == 2` (`:209`) |
| Type | `"mil_circle"` (`:204,212`) |
| Color | `"ColorYellow"` (`:205,213`) |
| Size | `[1,1]` (`:206`); fee marker `[0,0]` (`:214`) |
| Text (fee) | `"$<fee>"` (`:215`) |
| Creator | `:203,211` (`createMarkerLocal`) |
| Locality | **local** |

---

## Shared marker helpers (not a family)

These are used by several families above; APIs are documented in [Marker Subsystem Function Reference](Marker-Subsystem-Function-Reference).

- **`WF_createMarker`** = `Common/Functions/Common_CreateMarker.sqf` — creates the marker **GLOBAL** (`createMarker` `:53`) plus an optional ellipse (`:59`), but applies type/text/color **locally only if `playerSide == _side_who_see_marker`** (`:62-78`), then sets `MARKER_CREATION` and `publicVariable`s it (`:82-83`). Callers: fire mission, commander ICBM, radzone.
- **`Client/Functions/Client_onEventHandler_MARKER_CREATION.sqf`** — the `MARKER_CREATION` PV consumer. The `createMarkerLocal`/`createMarker` lines are **commented out** (`:35,43`); the handler only re-styles already-created (global) markers (`:36-46`).
- **`Client/Functions/Client_BlinkMapIcon.sqf`** — combat-blink recolor of an existing unit marker (`unitMarkerBlink` / `OriginalMarkerColor`, `:18,23,31,37`); creates no markers.

## Dead-code / quirk notes

- **No `HQDeployed` marker** — only `HQUndeployed` (`Init_Unit.sqf:186`); deploy state never renames the HQ marker.
- `Client_onEventHandler_MARKER_CREATION.sqf:35,43` — marker-creation lines commented out; the PV path only re-styles.
- `Server/Functions/Server_OnHQKilled.sqf:99` — its `WF_createMarker` call is commented out (dead).
- `mil_dot` → `mil_objective` immobile-vehicle swap happens in the loop (`Common_MarkerLoop.sqf:329`), not at creation.
- The `unitMarker<n>` namespace is shared across Unit/Vehicle, AA-Radar, Paratrooper, UAV-spotted and respawn-menu markers, so suffixes are not contiguous within any one of those families.
- No marker family is created by an "RHUD" path — RHUD is a resource/control HUD, not a map-marker producer.

## Continue Reading

- [Marker Loop Engine and Registries](Marker-Loop-Engine-And-Registries) — the registrar → registry → consolidated-loop architecture and per-tick gating
- [Client Marker FSM Updater Map](Client-Marker-FSM-Updater-Map) — the town/team/patrol/AICOM FSM updaters that drive live text, color and direction
- [Marker Subsystem Function Reference](Marker-Subsystem-Function-Reference) — `WF_createMarker`, `MarkerUpdate`, `WFBE_CL_FNC_Delete_Marker` and related APIs
- [Towns Camps And Capture Atlas](Towns-Camps-And-Capture-Atlas) — town/camp logic, sideID coloring and the capture recolor path
- [Counter-Battery Radar System](Counter-Battery-Radar-System) — CBR range rings, the 750/1500/2000 tier ladder and counter-battery contact markers
