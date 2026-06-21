# Marker Subsystem Function Reference (primitives, helpers, signatures, callers)

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

This page is a per-function reference for the marker **primitives and helpers**: one section per function, each with its compiled handle, signature, return value, locality, behavior, and a caller census. The loop/tick internals (the consolidated client loop, registries, rebuild execution, ledger sweep) are deferred to [Marker Loop Engine and Registries](Marker-Loop-Engine-And-Registries); per-family marker content (town/camp/base/team/patrol marker types and colors) is deferred to [Map Marker Families Content Catalog](Map-Marker-Families-Content-Catalog).

**A2 locality reminder.** `createMarker` is global: it replicates the marker's *existence and position* to every machine. `createMarkerLocal` and every `setMarker*Local` verb are local: they apply only on the calling machine and do **not** replicate. The marker subsystem leans on this split deliberately — the only globally-replicating creator is `WF_createMarker`, and even it paints type/text/color with `…Local` verbs, then re-broadcasts the param array over a public variable so remote same-side clients can re-paint locally (see [Networking And Public Variables](Networking-And-Public-Variables)).

## Function Registry

| Handle | Source | Compiled at | Kind |
| --- | --- | --- | --- |
| `WF_createMarker` | `Common/Functions/Common_CreateMarker.sqf` | `Common/Init/Init_Common.sqf:167` | global creator + PV broadcaster (server or client) |
| `UpdateMarker` | `Common/Functions/Common_UpdateMarker.sqf` | `Client/Init/Init_Client.sqf:68` | local follow-marker updater (client) |
| `onEventHandler_MARKER_CREATION` | `Client/Functions/Client_onEventHandler_MARKER_CREATION.sqf` | `Client/FSM/updateclient.sqf:15`, bound `:16` | PV event handler (every remote client) |
| `WFBE_CL_FNC_Delete_Marker` | `Client/Functions/Client_Delete_Marker.sqf` | `Common/Init/Init_Common.sqf:168` | timed local deleter (client) |
| `GetStructureMarkerLabel` | `Client/Functions/Client_GetStructureMarkerLabel.sqf` | `Client/Init/Init_Client.sqf:78` | pure label lookup (client) |
| `MarkerAnim` | `Client/Functions/Client_MarkerAnim.sqf` | `Client/Init/Init_Client.sqf:83` | spawned local pulse animation (client) |
| (`Client_GetMarkerColoration.sqf`) | `Client/Functions/Client_GetMarkerColoration.sqf` | — never compiled | **dead code** (no registration, no caller) |
| (`Init_Markers.sqf`) | `Client/Init/Init_Markers.sqf` | run via `Call Compile` at `Client/Init/Init_Client.sqf:809` | JIP town/camp marker bootstrap script (client) |
| (`Common_MarkerRebuildRequest.sqf`) | `Common/Common_MarkerRebuildRequest.sqf` | run via `addAction` at `Common/Common_MarkerLoop.sqf:27` | local rebuild-flag setter (client) |

---

## `WF_createMarker` — global side-restricted marker creator

- **Handle / binding:** `WF_createMarker = compile preprocessFileLineNumbers "Common\Functions\Common_CreateMarker.sqf";` (`Common/Init/Init_Common.sqf:167`). Compiled in the common init, so the handle exists on server and all clients.
- **Signature:** `[_markerName, _position, _markerType, _markerText, _markerColor, _side_who_see_marker, _markerNameElipse(opt), _markerRadius(opt)] call WF_createMarker` — six required params read at `Common_CreateMarker.sqf:34-39`; optional ellipse params 6 & 7 read at `:46-47`.
- **Optional-ellipse gate:** `if (count _this > 7)` — i.e. needs **8** elements to enable the ellipse; sets `_hasElipse = true` (`Common_CreateMarker.sqf:44-48`).
- **Return value:** none usable. The last statements are `missionNamespace setVariable [...]` then `publicVariable "MARKER_CREATION"` (`Common_CreateMarker.sqf:82-83`); callers `call` it for side effects only. (`_markerName` is locally reassigned to the `createMarker` result at `:53`, but that is not the function's return.)
- **Locality:** the marker *object* is created **GLOBAL** — `createMarker [_markerName, _markerPosition]` (`Common_CreateMarker.sqf:53`), and the optional ellipse is also global, `createMarker [_markerNameElipse, _markerPosition]` (`:59`). Header comment states the intent: "It must exist globally so that late-joining clients can receive and process it." (`:52`). Styling is **LOCAL** and side-gated.

| Step | Detail | path:line |
| --- | --- | --- |
| Global create (main) | `createMarker [_markerName, _markerPosition]` | `Common_CreateMarker.sqf:53` |
| Global create (ellipse) | `createMarker [_markerNameElipse, _markerPosition]` (only if `_hasElipse`) | `Common_CreateMarker.sqf:59` |
| Side gate | `if (playerSide == _side_who_see_marker)` | `Common_CreateMarker.sqf:62` |
| Local style (main) | `setMarkerTypeLocal`, `setMarkerTextLocal`, `setMarkerColorLocal` | `Common_CreateMarker.sqf:65-67` |
| Local style (ellipse) | `setMarkerShapeLocal "ELLIPSE"`, `setMarkerSizeLocal [_markerRadius,_markerRadius]`, `setMarkerColorLocal`, `setMarkerAlphaLocal 0.5`, `setMarkerBrushLocal "Solid"` | `Common_CreateMarker.sqf:72-76` |
| Broadcast | `missionNamespace setVariable ["MARKER_CREATION", _this]` then `publicVariable "MARKER_CREATION"` | `Common_CreateMarker.sqf:82-83` |

- **Behavior:** create the marker globally (so JIP clients receive its existence/position), paint side-restricted styling locally on the calling machine only, then stuff the entire input array into the single `MARKER_CREATION` slot and `publicVariable` it. The broadcast fires the PV event handler on every *other* machine, where matching-side clients re-paint the styling locally (see the companion handler below). This is the side-restricted-visibility mechanism: the marker exists globally but only the matching side gets type/text/color, so the other side sees nothing meaningful.
- **Caller census:**

| Caller | Arity | Ellipse | Side arg | Runs on | path:line |
| --- | --- | --- | --- | --- | --- |
| Artillery fire-mission marker (`Destroy`, params built `:22-29`) | 8 | yes | `playerSide` | client | `Client/Functions/Client_RequestFireMission.sqf:31` — auto-deleted after 80s via `WFBE_CL_FNC_Delete_Marker` `:32-33` |
| ICBM aim marker (`mil_warning`, params built `:474-481`) | 8 | yes | `playerSide` | client (tactical menu) | `Client/GUI/GUI_Menu_Tactical.sqf:483` — deleted after countdown via `WFBE_CL_FNC_Delete_Marker` `:504-505` |
| Radiation zone — WEST | 8 | yes | `west` (literal) | **server** | `Client/Module/Nuke/radzone.sqf:64-73` |
| Radiation zone — EAST | 8 | yes | `east` (literal) | **server** | `Client/Module/Nuke/radzone.sqf:76-85` |
| HQ-killed wreck marker | 6 | no | `_side` | (server) | **DEAD — commented out** `Server/Functions/Server_OnHQKilled.sqf:99` |

- **Notes:**
  - `radzone.sqf` runs server-side (header: "This script is run on server side", `radzone.sqf:8`), so its two calls global-create + broadcast to all clients; the dedicated server has no `playerSide` to match, so the producer styles nothing and every client paints via the PV handler. The two GUI/arty callers run client-side, so the calling client styles its own marker at create time *and* broadcasts to the others.
  - All four live callers pass the full 8-element form. The 6-param-only path is reachable only by the dead HQ-killed call (`Server_OnHQKilled.sqf:99`), now replaced by a PV-broadcast HQ-state pattern (`:101` onward).
  - `MARKER_CREATION` is a single shared `missionNamespace` slot (`:82`), so the global var is last-writer-wins; in practice each `publicVariable` enqueues its own network event and the receiver reads the value from the event payload (`_this select 1`), not from the global, so rapid successive calls do not corrupt delivery.

---

## `UpdateMarker` — local HQ-wreck follow-marker updater

- **Handle / binding:** `UpdateMarker = Compile preprocessFile "Common\Functions\Common_UpdateMarker.sqf";` (`Client/Init/Init_Client.sqf:68`). Compiled in client init only → client-side handle.
- **Signature:** `[_markerObject, _markerName, _markerType, _markerText, _markerColor] call UpdateMarker` — 5 params, all required, read at `Common_UpdateMarker.sqf:19-23`.
- **Return value:** none usable. The last statement is `_markerName setMarkerPosLocal _markerPosition` (`Common_UpdateMarker.sqf:37`).
- **Locality:** fully **LOCAL / client-side** by design ("intended for client-side team-only markers", `Common_UpdateMarker.sqf:14`). Never replicates.
- **Behavior:**

| Step | Detail | path:line |
| --- | --- | --- |
| Null guard | `if (isNull _markerObject) exitWith {};` | `Common_UpdateMarker.sqf:25` |
| Create-if-absent | `if ((getMarkerType _markerName) == "") then { createMarkerLocal [_markerName, getPos _markerObject] };` | `Common_UpdateMarker.sqf:28-30` |
| Local style | `setMarkerTypeLocal`, `setMarkerTextLocal`, `setMarkerColorLocal` | `Common_UpdateMarker.sqf:32-34` |
| Position track | `_markerPosition = getPos _markerObject; _markerName setMarkerPosLocal _markerPosition;` | `Common_UpdateMarker.sqf:36-37` |

- **Caller census (both in the client FSM, both gated by `if (!isNull _hq)`):**

| Caller | Context | Gates | path:line |
| --- | --- | --- | --- |
| WEST HQ-wreck tracker | When `IS_WEST_HQ_ALIVE` is false, reads `HQ_WEST_MARKER_INFOS` (index 6 = the tracked HQ object) | outer `(count _MARKER_infos) >= 7` (`:62`), then `if (!isNull _hq)` (`:72`) | `Client/FSM/updateclient.sqf:74` |
| EAST HQ-wreck tracker | Mirror of above, reads `HQ_EAST_MARKER_INFOS` | outer `(count _MARKER_infos) >= 7` (`:92`), then `if (!isNull _hq)` (`:102`) | `Client/FSM/updateclient.sqf:104` |

---

## `onEventHandler_MARKER_CREATION` — remote-replication half of `WF_createMarker`

- **Handle / binding:** compiled inline in the client FSM — `onEventHandler_MARKER_CREATION = compile preprocessFileLineNumbers "Client\Functions\Client_onEventHandler_MARKER_CREATION.sqf";` (`Client/FSM/updateclient.sqf:15`), then bound as the PV event handler `"MARKER_CREATION" addPublicVariableEventHandler {_this call onEventHandler_MARKER_CREATION};` (`updateclient.sqf:16`).
- **Signature:** invoked by the PV-EH, so `_this = [pvName, value]`. It reads `_MARKER_infos = _this select 1` ("select 1 not 0 to get the value", `Client_onEventHandler_MARKER_CREATION.sqf:15`), then unpacks the same 6/8-element param array as `WF_createMarker` (`:18-23`, optional ellipse `:28-29`).
- **Return value:** none.
- **Locality:** **runs on every client that receives the broadcast** (publicVariable does not fire on the sender). It applies styling only for the matching side, `if (playerSide == _side_who_see_marker)` (`:32`), via the same `setMarker*Local` verbs (`:36-48`).
- **Behavior — does NOT create the marker:** the `createMarkerLocal` (`:35`) and `createMarker` (`:43`) lines are commented out. The handler relies on the global marker already existing from `WF_createMarker`'s `createMarker` (`Common_CreateMarker.sqf:53`); it only paints local style on the matching side. This is the architectural crux of the channel, not a bug.
- **Quirks:**
  - **Optional-param gate mismatch (latent off-by-one).** The handler enables the ellipse on `count _MARKER_infos > 6` (`:26`), looser than the producer's `count _this > 7` (`Common_CreateMarker.sqf:44`). On an exactly-7-element array the handler would read `_MARKER_infos select 7` (`:29`) and miss. Harmless in practice — every live producer call passes either 6 or 8 elements — but worth flagging.
  - **Casing slip.** The private list declares `_marker_name` (`:13`), but the assignments use `_markerName` (`:18`). Benign; `_markerName` ends up function-local either way.
  - The ellipse branch guards on `if (!isNil {_markerNameElipse})` (`:41`) rather than re-checking `count`.

---

## `WFBE_CL_FNC_Delete_Marker` — timed local marker deletion

- **Handle / binding:** `WFBE_CL_FNC_Delete_Marker = compile preprocessFileLineNumbers "Client\Functions\Client_Delete_Marker.sqf";` (`Common/Init/Init_Common.sqf:168`).
- **Signature:** `[_marker_name, _deleteTime] call WFBE_CL_FNC_Delete_Marker` — `_marker_name = _this select 0`, `_deleteTime = _this select 1` (seconds) (`Client_Delete_Marker.sqf:14-15`).
- **Return value:** none — the spawned thread handle is not captured.
- **Locality:** **client-local** (`deleteMarkerLocal`, `:24`), runs on whichever machine calls it.
- **Behavior:** `[_marker_name,_deleteTime] spawn { ... sleep _deleteTime; deleteMarkerLocal _marker_name; }` (`Client_Delete_Marker.sqf:17-25`). Using `spawn` keeps the caller non-blocking (header note `:8`).
- **Caller census:**

| Caller | Delay | path:line |
| --- | --- | --- |
| Arty marker + ellipse | 80s | `Client/Functions/Client_RequestFireMission.sqf:32-33` |
| ICBM marker + ellipse | countdown (`WFBE_ICBM_TIME_TO_IMPACT` min → s) | `Client/GUI/GUI_Menu_Tactical.sqf:504-505` |

- **Quirks:**
  - Header `Name:` field is stale — it reads `Client_Delete_LocalMarker.sqf` (`:3`) but the file is `Client_Delete_Marker.sqf`.
  - The map note flags a server-side caller (`Server_MHQRepair.sqf`); the two confirmed live callers above are both client-side. If invoked from server code, `deleteMarkerLocal` would affect only the host's local marker, not remote clients — a locality consideration for any future server caller.

---

## `GetStructureMarkerLabel` — structure class → single-letter map label

- **Handle / binding:** `GetStructureMarkerLabel = Compile preprocessFile "Client\Functions\Client_GetStructureMarkerLabel.sqf";` (`Client/Init/Init_Client.sqf:78`).
- **Signature:** `[_structure, _side] Call GetStructureMarkerLabel` — `_structure = _this select 0`, `_side = _this select 1` (a side *name* string) (`Client_GetStructureMarkerLabel.sqf:3-4`).
- **Return value:** the label string `_label` (`Client_GetStructureMarkerLabel.sqf:27`).
- **Locality:** pure/local helper — reads `missionNamespace` only (`WFBE_%1STRUCTURES` / `WFBE_%1STRUCTURENAMES`, `:8-9`); no marker writes.
- **Behavior:** `_class = typeOf _structure` (`:6`); resolve the structure's "real type" via `_structures select (_structuresNames find _class)` (`:11`); a `switch` maps real-type → label (`:13-25`):

| Real type | Label | Real type | Label |
| --- | --- | --- | --- |
| `Barracks` | `B` | `ServicePoint` | `S` |
| `Light` | `L` | `Bank` | `R` (Federal Reserve / economy bank, `:20`) |
| `CommandCenter` | `C` | `AARadar` | `AAR` |
| `Heavy` | `H` | `ArtilleryRadar` | `AR` |
| `Aircraft` | `A` | `Reserve` | `RES` |
| | | `default` | `""` (`:24`) |

- **Caller census (single):** `Client/Init/Init_BaseStructure.sqf:40` — `if (!_hq) then {_text = [_structure, _side] Call GetStructureMarkerLabel; _marker setMarkerSizeLocal [0.5,0.5]}`. The caller passes `_side` already converted to a side *name* via `WFBE_CO_FNC_GetSideFromID` (`Init_BaseStructure.sqf:14`), null-guards the result with `if (isNil "_text")` (`:41`), and special-cases `"S"` → ServicePoint `mil_objective` / `"SP"` marker (`:46-50`).
- **Quirk:** if `_class` is absent from `_structuresNames`, `find` returns `-1` and `_structures select -1` errors in A2 — the helper relies on every base structure class being present in the side table; `default {""}` only covers the known-type-but-unlabeled case, not the not-found case.

---

## `MarkerAnim` — spawned local pulse/rotate order-preview marker

- **Handle / binding:** `MarkerAnim = Compile preprocessFile "Client\Functions\Client_MarkerAnim.sqf";` (`Client/Init/Init_Client.sqf:83`). Invoked with `Spawn` (own scope).
- **Signature:** `[_markerName, _markerPosition, _markerType, _markerSize, _markerColor, _markerMin, _markerMax, _additionalErase(opt)] Spawn MarkerAnim` — params 0–6 at `Client_MarkerAnim.sqf:2-8`; `_additionalErase = ""` default (`:9`), overridden from index 7 only `if (count _this > 7)` (`:10`).
- **Return value:** none (spawned thread).
- **Locality:** **client-local** marker effects throughout (`deleteMarkerLocal` / `CreateMarkerLocal` / `setMarker*Local`). The loop flag `activeAnimMarker` is a **client global** used to stop the loop from elsewhere.
- **Behavior:**

| Step | Detail | path:line |
| --- | --- | --- |
| Recreate marker locally | `deleteMarkerLocal _markerName; CreateMarkerLocal [...]; set type/color/size` | `Client_MarkerAnim.sqf:12-16` |
| Pulse step | `_difference = (_markerMax - _markerMin)/10` | `Client_MarkerAnim.sqf:18` |
| Set loop flag | `activeAnimMarker = true` | `Client_MarkerAnim.sqf:21` |
| Optional area circle | if `_additionalErase != ""`, read `WFBE_C_AI_PATROL_RANGE` and make an `Ellipse` marker sized to range | `Client_MarkerAnim.sqf:23-30` |
| Animation loop | `while {activeAnimMarker} do { sleep 0.03; _direction = (_direction + 1) % 360; setMarkerDirLocal; bounce size between min/max }` | `Client_MarkerAnim.sqf:32-42` |
| Teardown | `deleteMarkerLocal _markerName` + delete area circle if present | `Client_MarkerAnim.sqf:44-45` |

- **Caller census (all in `Client/GUI/GUI_Menu_Command.sqf`):** preview of the current order — `:194` move (`ColorOrange`), `:195` patrol (`ColorYellow` + `"areaPatrol"` circle), `:196` defense (`ColorRed`), `:200` towns (`ColorBlue`); all use marker name `"TempAnim"`, type `"selector_selectedMission"`, size 1, min 1 / max 1.2. The click-to-order path spawns a prebuilt array at `:313` (`_array Spawn MarkerAnim`).
- **Loop-stop sites (set `activeAnimMarker = false`):** `GUI_Menu_Command.sqf:109, 110, 186, 260, 311, 540` (line 540 is the dialog-teardown cleanup). One writer-true (`Client_MarkerAnim.sqf:21`), one reader (`:32`); only one `"TempAnim"` animation is meant to run at a time, and a new `Spawn MarkerAnim` implicitly replaces the previous one because they share the global flag and marker name.
- **Quirk:** `_difference` (`:18`) is used but is missing from the `Private[...]` declaration at `:1`. Because `MarkerAnim` is `Spawn`ed into its own scope, `_difference` is effectively script-local to the thread anyway — harmless, an undeclared-private inconsistency, not an error.

---

## `Client_GetMarkerColoration.sqf` — DEAD CODE

- **Status:** **not registered, not called.** `grep -rn "GetMarkerColoration"` across the whole mission returns only the file itself — no `Init_*` compile, no caller.
- **As written (single minified line):** `_colorFor = _this` (a string); `switch (_colorFor)`: `"Friendly"`→`"ColorGreen"`, `"Enemy"`→`"ColorRed"`, `"Resistance"`→`"ColorGreen"`; returns `_color` (default `""`). The `WFBE_MAPCOLORATION` / `GetNamespace` logic is commented out inline (`Client_GetMarkerColoration.sqf:1`); `_colorationMode` is declared but unused.
- **What actually does side→color:** the live mapping uses `WFBE_C_%1_COLOR` missionNamespace vars with a `WFBE_C_UNKNOWN_COLOR` fallback (see `Init_Markers.sqf` below and [Map Marker Families Content Catalog](Map-Marker-Families-Content-Catalog)), not this helper. Flag as vestigial.

---

## `Init_Markers.sqf` — JIP town/camp marker bootstrap

- **Kind / invocation:** a script (not a registered function); `scriptName` set at `Client/Init/Init_Markers.sqf:5`. Run once per client at boot/JIP via `Call Compile preprocessFileLineNumbers "Client\Init\Init_Markers.sqf";` (`Client/Init/Init_Client.sqf:809`), inside a `[] Spawn { sleep 2; ... }` JIP block (`Init_Client.sqf:806-810`, log line "Updating JIP Markers." `:808`).
- **Locality:** **client-local** marker creation (`createMarkerLocal`), colored per-client against `WFBE_Client_SideID` (captured at `Init_Client.sqf:311`).
- **Behavior (`forEach towns`, `:7-50`):**

| Step | Detail | path:line |
| --- | --- | --- |
| Wait for sideID | `waitUntil {!isNil {_x getVariable "sideID"}}`; read `_townSide` | `Init_Markers.sqf:11-12` |
| Color (fog-of-war) | default `WFBE_C_UNKNOWN_COLOR`; only if `_townSide == WFBE_Client_SideID` resolve real owner color `WFBE_C_%1_COLOR` (`%1 = _townSide Call WFBE_CO_FNC_GetSideFromID`) | `Init_Markers.sqf:15-18` |
| Town marker | name `Format ["WFBE_%1_CityMarker", str _x]`, `createMarkerLocal` at `getPos _x`, type `"Depot"`, color | `Init_Markers.sqf:21-24` |
| Camps sub-loop | after `waitUntil` camps init; per camp same side/color logic; marker name from the camp's `wfbe_camp_marker` var, `createMarkerLocal`, type `"Strongpoint"`, color, size `[0.5,0.5]` | `Init_Markers.sqf:27-49` |

- **Marker-name contract:** the `WFBE_%1_CityMarker` and `wfbe_camp_marker` markers this script creates are the markers the town/camp capture PV handlers later re-color (deferred — see [Marker Loop Engine and Registries](Marker-Loop-Engine-And-Registries) and [Map Marker Families Content Catalog](Map-Marker-Families-Content-Catalog)). Enemy/neutral towns show the "unknown" color to this client — fog-of-war via color.

---

## `Common_MarkerRebuildRequest.sqf` — local marker-rebuild trigger

- **Kind / invocation:** a tiny script run by an `addAction` ("Rebuild Map Markers"), attached at `Common/Common_MarkerLoop.sqf:27` (and re-attached after respawn at `:66`, because the player-object change drops the action).
- **Body (entire file):** `WFBE_CL_MarkerRebuildRequested = true;` then `hint "Rebuilding local map markers...";` (`Common_MarkerRebuildRequest.sqf:2-3`). Header cross-references the loop (`:1`).
- **Return value:** none.
- **Locality:** **local to the requesting client.** It sets a flag only.
- **Behavior:** purely sets `WFBE_CL_MarkerRebuildRequested` (initialized `false` at `Common_MarkerLoop.sqf:25`). The actual delete-and-recreate rebuild work runs inside the consolidated loop when it sees the flag (`Common_MarkerLoop.sqf:82-83`) — that execution, the auto-trigger (sub-`WFBE_C_MARKER_REBUILD_FPS` for 60s, default 15, `:30`), the cooldown, and the registries are deferred to [Marker Loop Engine and Registries](Marker-Loop-Engine-And-Registries). This script is the manual entry point only; it sends nothing over the network.

---

## Continue Reading

- [Marker Loop Engine and Registries](Marker-Loop-Engine-And-Registries) — the consolidated client loop, registrars, rebuild execution, and ledger sweep this page defers.
- [Map Marker Families Content Catalog](Map-Marker-Families-Content-Catalog) — per-family marker types, colors, and side→color mapping.
- [Client Marker FSM Updater Map](Client-Marker-FSM-Updater-Map) — the FSM scripts that wire the PV handler and drive HQ-wreck / team / patrol marker updates.
- [Marker Cleanup Restoration Systems Atlas](Marker-Cleanup-Restoration-Systems-Atlas) — timed deletion, orphan GC, and state restoration across the marker subsystem.
- [Networking And Public Variables](Networking-And-Public-Variables) — the `MARKER_CREATION` public-variable channel and the broader PV/event model.
