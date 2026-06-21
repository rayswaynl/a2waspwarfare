# Map-Control Template and Minimap Embed Reference

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

Every embedded minimap in the Warfare dialogs — Respawn, Buy Units, Command, Tactical, Unit Camera and Economy — is one engine map control inheriting a single shared template, `RscMapControl`, defined once in `Rsc/Ressources.hpp:563`. This page documents that base template (the `type=101` map control: its terrain/satellite render tuning, font set and background texture), the three marker sub-classes (`Task`, `CustomMark`, `Legend`), the 25 map-feature icon sub-classes (`Bunker` through `ActiveMarker`) that style on-map landmarks, and the six dialog controls that derive from it as `WF_MiniMap` / `CA_MiniMap`. It is the resource-class layer beneath the minimap; it does not catalog the dialog IDDs themselves (that is the Client UI Systems Atlas) nor the gameplay map markers placed on top of these controls (that is the Map Marker Families catalog).

## Base template: RscMapControl (Rsc/Ressources.hpp:563)

`RscMapControl` is an engine map control. It is never instantiated directly — it serves only as the inheritance base for the dialog `WF_MiniMap`/`CA_MiniMap` controls. The control class file `Rsc/Ressources.hpp` ends at line 851 with this template as its last (and largest) block.

| Field | Value | Path:line | Meaning |
|---|---|---|---|
| `type` | `101` | `Rsc/Ressources.hpp:564` | Engine control type for a 2D map control. |
| `moveOnEdges` | `1` | `Rsc/Ressources.hpp:565` | Map pans when the cursor reaches the edge. |
| `style` | `48` | `Rsc/Ressources.hpp:567` | Control style flags. |
| `x`/`y`/`w`/`h` | `0.2` each | `Rsc/Ressources.hpp:568-571` | Default geometry, always overridden by each derived control. |
| `text` | `\ca\ui\data\map_background2_co.paa` | `Rsc/Ressources.hpp:615` | The off-area background texture behind the map. |
| `font` | `EtelkaNarrowMediumPro` | `Rsc/Ressources.hpp:601` | Base font. |

The base also defines the satellite/contour render tuning that controls how the terrain is drawn at the minimap's small scale:

| Field group | Values | Path:line |
|---|---|---|
| `ptsPerSquareSea`/`Txt`/`CLn`/`Exp`/`Cost` | `8`, `10`, `10`, `10`, `10` | `Rsc/Ressources.hpp:572-576` |
| `ptsPerSquareFor`/`ForEdge`/`Road`/`Obj` | `"6.0f"`, `"15.0f"`, `"3f"`, `15` | `Rsc/Ressources.hpp:577-580` |
| `showCountourInterval` | `"false"` (string) | `Rsc/Ressources.hpp:581` |
| `maxSatelliteAlpha` | `0.75` | `Rsc/Ressources.hpp:582` |
| `alphaFadeStartScale`/`alphaFadeEndScale` | `0.15`, `0.29` | `Rsc/Ressources.hpp:583-584` |

Note the base value `showCountourInterval = "false"` is the engine default; every derived `WF_MiniMap`/`CA_MiniMap` flips it back on with `ShowCountourInterval = 1` (see the consumer table below).

The terrain colour palette (`colorLevels`, `colorSea`, `colorForest`, `colorRocks`, `colorCountlines`, `colorMainCountlines`, `colorPowerLines`, `colorRailWay`, `colorNames`, `colorInactive`, `colorText`, `colorBackground`, `colorOutside`, plus border/water variants) spans `Rsc/Ressources.hpp:585-602`, and a full label font set (`fontLabel`/`fontGrid`/`fontUnits`/`fontNames`/`fontInfo`/`fontLevel` all `Zeppelin32`, with their `sizeEx*` companions) spans `Rsc/Ressources.hpp:603-614`. Editing any of these recolours or re-fonts every embedded minimap at once, since all six consumers share this one base.

## Marker sub-classes

Three nested sub-classes drive the engine's task and custom-marker rendering on any control derived from `RscMapControl`.

| Sub-class | Role | Key fields | Path:line |
|---|---|---|---|
| `Task` | Mission-task icons with per-state icon/colour (current/created/canceled/done/failed) | `size = 27`, 5 state icons, 5 state colours | `Rsc/Ressources.hpp:616-631` |
| `CustomMark` | User/custom map marks | `icon = map_waypoint_ca.paa`, `size = 18` | `Rsc/Ressources.hpp:632-639` |
| `Legend` | Map legend box, pinned top-left | `x/y = SafeZoneX/Y`, `w = 0.34`, `h = 0.152`, carries a `//todo` comment | `Rsc/Ressources.hpp:640-649` |

## Map-feature icon sub-classes (Bunker .. ActiveMarker)

The remaining 25 nested sub-classes are the per-landmark icon styles the engine uses to draw map features (buildings, vegetation, waypoints) at scale-dependent sizes. Each defines an `icon` (`\ca\ui\data\map_*_ca.paa`), a `color[]`, a `size`, an `importance` (drives draw priority / when the icon appears as you zoom), and `coefMin`/`coefMax` scaling bounds. They run contiguously from `Rsc/Ressources.hpp:650` to the file end at `:850`.

| Sub-class | Icon | Size | coefMin/Max | Path:line |
|---|---|---|---|---|
| `Bunker` | `map_bunker_ca.paa` | 14 | 0.25 / 4 | `Rsc/Ressources.hpp:650-657` |
| `Bush` | `map_bush_ca.paa` | 14 | 0.25 / 4 | `Rsc/Ressources.hpp:658-665` |
| `BusStop` | `map_busstop_ca.paa` | 12 | 0.25 / 4 | `Rsc/Ressources.hpp:666-673` |
| `Command` | `map_waypoint_ca.paa` | 18 | 1 / 1 | `Rsc/Ressources.hpp:674-681` |
| `Cross` | `map_cross_ca.paa` | 16 | 0.25 / 4 | `Rsc/Ressources.hpp:682-689` |
| `Fortress` | `map_bunker_ca.paa` | 16 | 0.25 / 4 | `Rsc/Ressources.hpp:690-697` |
| `Fuelstation` | `map_fuelstation_ca.paa` | 16 | 0.75 / 4 | `Rsc/Ressources.hpp:698-705` |
| `Fountain` | `map_fountain_ca.paa` | 11 | 0.25 / 4 | `Rsc/Ressources.hpp:706-713` |
| `Hospital` | `map_hospital_ca.paa` | 16 | 0.5 / 4 | `Rsc/Ressources.hpp:714-721` |
| `Chapel` | `map_chapel_ca.paa` | 16 | 0.9 / 4 | `Rsc/Ressources.hpp:722-729` |
| `Church` | `map_church_ca.paa` | 16 | 0.9 / 4 | `Rsc/Ressources.hpp:730-737` |
| `Lighthouse` | `map_lighthouse_ca.paa` | 14 | 0.9 / 4 | `Rsc/Ressources.hpp:738-745` |
| `Quay` | `map_quay_ca.paa` | 16 | 0.5 / 4 | `Rsc/Ressources.hpp:746-753` |
| `Rock` | `map_rock_ca.paa` | 12 | 0.25 / 4 | `Rsc/Ressources.hpp:754-761` |
| `Ruin` | `map_ruin_ca.paa` | 16 | 1 / 4 | `Rsc/Ressources.hpp:762-769` |
| `SmallTree` | `map_smalltree_ca.paa` | 12 | 0.25 / 4 | `Rsc/Ressources.hpp:770-777` |
| `Stack` | `map_stack_ca.paa` | 20 | 0.9 / 4 | `Rsc/Ressources.hpp:778-785` |
| `Tree` | `map_tree_ca.paa` | 12 | 0.25 / 4 | `Rsc/Ressources.hpp:786-793` |
| `Tourism` | `map_tourism_ca.paa` | 16 | 0.7 / 4 | `Rsc/Ressources.hpp:794-801` |
| `Transmitter` | `map_transmitter_ca.paa` | 20 | 0.9 / 4 | `Rsc/Ressources.hpp:802-809` |
| `ViewTower` | `map_viewtower_ca.paa` | 16 | 0.5 / 4 | `Rsc/Ressources.hpp:810-817` |
| `Watertower` | `map_watertower_ca.paa` | 20 | 0.9 / 4 | `Rsc/Ressources.hpp:818-825` |
| `Waypoint` | `map_waypoint_ca.paa` | 14 | 0.5 / 4 | `Rsc/Ressources.hpp:826-833` |
| `WaypointCompleted` | `map_waypoint_completed_ca.paa` | 14 | 0.5 / 4 | `Rsc/Ressources.hpp:834-841` |
| `ActiveMarker` | `""` (empty) | 14 | 0.5 / 4 | `Rsc/Ressources.hpp:842-849` |

`ActiveMarker` is the only feature class with an empty `icon` string — the engine renders it without a texture glyph. These are stock A2 OA map-feature classes carried verbatim into the mission's template; they are styling data, not gameplay logic.

## Consumers: WF_MiniMap / CA_MiniMap embed (Rsc/Dialogs.hpp)

Six dialog controls inherit `RscMapControl`. Five are named `WF_MiniMap`; the Unit Camera menu's is `CA_MiniMap`. Each lives inside that dialog's `class controls` block, overrides only geometry plus a few render/event fields, and re-enables `ShowCountourInterval = 1`. The four input-heavy menus also wire `onMouseMoving` / `onMouseButtonDown` / `onMouseButtonUp` to write the global `mouseX`/`mouseY`/`mouseButtonDown`/`mouseButtonUp` variables their order/marker logic reads.

| Dialog (idd) | Embed class | idc | onMouse* wired | Path:line |
|---|---|---|---|---|
| `WFBE_RespawnMenu` (511000) | `WF_MiniMap` | 511001 | yes (Moving/Down/Up) | `Rsc/Dialogs.hpp:387` |
| `RscMenu_BuyUnits` (12000) | `WF_MiniMap` | 12015 | no | `Rsc/Dialogs.hpp:1681` |
| `RscMenu_Command` (14000) | `WF_MiniMap` | 14002 | yes (Moving/Down/Up) | `Rsc/Dialogs.hpp:1914` |
| `RscMenu_Tactical` (17000) | `WF_MiniMap` | 17002 | yes (Moving/Down/Up) | `Rsc/Dialogs.hpp:2286` |
| `RscMenu_UnitCamera` (21000) | `CA_MiniMap` | 21007 | yes (Moving/Down/Up); also `widthRailWay = 1` | `Rsc/Dialogs.hpp:2814` |
| `RscMenu_Economy` (23000) | `WF_MiniMap` | 23002 | yes (Moving/Down/Up) | `Rsc/Dialogs.hpp:3043` |

Notes for contributors:

- The Buy Units embed (`Rsc/Dialogs.hpp:1681`) is the only one that does NOT bind the mouse globals — it is a display-only minimap with no marker placement, so it keeps just `idc`, geometry and `ShowCountourInterval`.
- The Respawn embed (`Rsc/Dialogs.hpp:387`) uses `_this Select 1`/`Select 2` lowercase-different formatting from the others but writes the same `mouseX`/`mouseY` globals; all four interactive embeds funnel into the same global-variable contract.
- The Unit Camera `CA_MiniMap` (`Rsc/Dialogs.hpp:2814`) is the only consumer that additionally sets `widthRailWay = 1` and the only one named with the `CA_` prefix instead of `WF_`.
- Because all six share the single `RscMapControl` base, a change to the base template's colours, fonts, satellite alpha or background texture in `Rsc/Ressources.hpp:563-849` propagates to every minimap simultaneously — per-dialog overrides are limited to the geometry and event fields shown above.

## Distinction from the IDD/marker catalogs

The Client UI Systems Atlas lists `Rsc/Ressources.hpp` only as a file row ("Base control classes: buttons, listboxes, structured text, maps, controls groups...", `Client-UI-Systems-Atlas.md:60`) and catalogs the dialog IDDs, but it does not enumerate `RscMapControl` or any of its sub-classes — that resource family is this page's scope. Likewise, the gameplay markers drawn *on top of* these controls (side/town/objective marker families) are content for the Map Marker Families catalog, not styling classes in this template.

## Continue Reading

- [Client UI Systems Atlas](Client-UI-Systems-Atlas)
- [Client UI HUD And Menus](Client-UI-HUD-And-Menus)
- [Map Marker Families Content Catalog](Map-Marker-Families-Content-Catalog)
- [UI Resource Parity Cleanup](UI-Resource-Parity-Cleanup)
- [Respawn And Death Lifecycle Atlas](Respawn-And-Death-Lifecycle-Atlas)
