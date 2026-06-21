# Faction Base Structures Catalog (HQ/factory/structure classnames)

> Source-verified 2026-06-21 against master cf2a6d6a4. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

Each faction has its own set of 3D object classnames for every base structure. This catalog lists the exact classnames, costs, and build times across twelve active Structures_*.sqf files (plus one unreferenced file, `Structures_OA_US.sqf` — see the OA_US note below), so developers can look up a classname without opening each file individually.

---

## Data model overview

Every Structures_*.sqf builds eleven parallel arrays and publishes them to `missionNamespace`:

| Variable (template: `WFBE_<side>STRUCTURES*`) | Content |
|---|---|
| `WFBE_<side>STRUCTURES` | Logical slot names (`"Barracks"`, `"Light"`, …) |
| `WFBE_<side>STRUCTURENAMES` | 3D classnames (parallel to above) |
| `WFBE_<side>STRUCTUREDESCRIPTIONS` | Display names from `CfgVehicles displayName` |
| `WFBE_<side>STRUCTURECOSTS` | Supply cost per slot |
| `WFBE_<side>STRUCTURETIMES` | Build time in seconds (live) |
| `WFBE_<side>STRUCTUREDISTANCES` | Placement distance from HQ in metres |
| `WFBE_<side>STRUCTUREDIRECTIONS` | Placement direction in degrees |
| `WFBE_<side>STRUCTURESCRIPTS` | Site-type string used by construction logic |
| `WFBE_<side>MHQNAME` | Mobile HQ (folded) classname |
| `WFBE_<side>FARP` | FARP/MASH building classname (deployed state) |
| `WFBE_<side>CONSTRUCTIONSITE` | Construction-crate classname |

The type index for each slot is also published as `WFBE_<side><Slot>TYPE` (e.g. `WFBE_WESTHQTYPE = 0`). `Common/Config/Core_Structures/Structures_CO_US.sqf:97-99`; variable publish block at `Structures_CO_GUE.sqf:105-114` (pattern identical in all files).

---

## Costs and build times — shared schema

Costs are identical across all factions. Build times depend on the specific file loaded: the standard 60 s profile applies to CO_US, CO_RU, CO_INS, Structures_USMC, Structures_RU, Structures_CDF, and Structures_OA_TKA; the slow profile applies to CO_GUE, CO_CDF, Structures_GUE, Structures_INS, and Structures_OA_TKGUE. The AARadar slot is omitted entirely if `WFBE_C_STRUCTURES_ANTIAIRRADAR == 0`; parameter default is `1` (enabled). `Rsc/Parameters.hpp:105-110`

| Logical slot | `_s` (site type) | Cost | Time — standard (60 s) files¹ | Time — slow files² |
|---|---|---|---|---|
| Headquarters | HQSite | `WFBE_C_STRUCTURES_HQ_COST_DEPLOY` (param; default 500) | 30 s | 30 s |
| Barracks | SmallSite | 200 | 60 s | 70 s |
| Light (factory) | MediumSite | 600 | 60 s | 90 s |
| CommandCenter | SmallSite | 1 200 | 60 s | 110 s |
| Heavy (factory) | MediumSite | 2 800 | 60 s | 130 s |
| Aircraft (factory) | SmallSite | 4 400 | 60 s | 150 s |
| ServicePoint | SmallSite | 700 | 60 s | 70 s |
| AARadar | MediumSite | 3 200 | 60 s | 280 s |

¹ Standard 60 s files: `Structures_CO_US.sqf`, `Structures_CO_RU.sqf`, `Structures_CO_INS.sqf`, `Structures_USMC.sqf`, `Structures_RU.sqf`, `Structures_CDF.sqf`. `Structures_CO_US.sqf:32-95`, `Structures_CO_INS.sqf:32-95`

² Slow files: `Structures_CO_GUE.sqf`, `Structures_CO_CDF.sqf`, `Structures_GUE.sqf`, `Structures_INS.sqf`. `Structures_CO_GUE.sqf:36-94`, `Structures_INS.sqf:32-95`

The HQ cost constant fallback (when the mission parameter is absent) is 100 Supply. `Common/Init/Init_CommonConstants.sqf:307`

---

## Placement offsets

| Slot | Distance from HQ | Direction |
|---|---|---|
| Headquarters | 15 m | 0° |
| Barracks | 18 m | 90° |
| Light | 25 m | 90° |
| CommandCenter | 20 m | 90° |
| Heavy | 25 m | 90° |
| Aircraft | 31 m | 90° |
| ServicePoint | 21 m | 90° |
| AARadar | 21 m | 90° |

All factions share these offsets. `Common/Config/Core_Structures/Structures_USMC.sqf:29-94`

---

## Which file loads on which map

Each faction Root file branches on `WF_A2_CombinedOps` (Combined Operations DLC present), not on the active map. The CO_* files serve both Chernarus and Takistan, switching classnames internally via `IS_chernarus_map_dependent`. The OA_TKA and OA_TKGUE files are loaded only in the vanilla (non-CO) branch of TKA/TKGUE roots. `Common/Config/Core_Root/Root_*.sqf`

| Faction | `WF_A2_CombinedOps = true` (CO DLC) | `WF_A2_CombinedOps = false` (A2 vanilla) |
|---|---|---|
| US¹ | `Structures_CO_US.sqf` | `Structures_CO_US.sqf` (loaded unconditionally) |
| US_Camo | `Structures_CO_US.sqf` | `Structures_USMC.sqf` |
| USMC | `Structures_CO_US.sqf` | `Structures_USMC.sqf` |
| RU | `Structures_CO_RU.sqf` | `Structures_RU.sqf` |
| CDF | `Structures_CO_CDF.sqf` | `Structures_CDF.sqf` |
| GUE | `Structures_CO_GUE.sqf` | `Structures_GUE.sqf` |
| INS | `Structures_CO_INS.sqf` | `Structures_INS.sqf` |
| TKA | `Structures_CO_RU.sqf` | `Structures_OA_TKA.sqf` |
| TK_GUE / PMC | `Structures_CO_GUE.sqf` | `Structures_OA_TKGUE.sqf` |

`Root_RU.sqf:124,133,139`, `Root_CDF.sqf:123,128`, `Root_GUE.sqf:111,119,130`, `Root_INS.sqf:122,124,127`, `Root_TKA.sqf:123,131,142`, `Root_TKGUE.sqf:118,127`, `Root_PMC.sqf:112,121`

> ¹ `Root_US.sqf` loads `Structures_CO_US.sqf` unconditionally — no `WF_A2_CombinedOps` branch is present for the structures call. `Root_US_Camo.sqf` and `Root_USMC.sqf` do branch on `WF_A2_CombinedOps`. `Root_US.sqf:134-135`, `Root_US_Camo.sqf:128-142`, `Root_USMC.sqf:123-142`

---

## Classname catalog — main building structures

### USMC / US / US_Camo (CO_US variant — Chernarus)

`Common/Config/Core_Structures/Structures_CO_US.sqf:6-20`

| Slot | Classname (Chernarus) | Classname (Takistan / OA map) |
|---|---|---|
| Mobile HQ (folded) | `LAV25_HQ` | `LAV25_HQ` |
| Headquarters | `LAV25_HQ_unfolded` | `M1130_HQ_unfolded_EP1` |
| Barracks | `USMC_WarfareBBarracks` | `US_WarfareBBarracks_EP1` |
| Light Factory | `USMC_WarfareBLightFactory` | `US_WarfareBLightFactory_EP1` |
| Command Center | `USMC_WarfareBUAVterminal` | `US_WarfareBUAVterminal_EP1` |
| Heavy Factory | `USMC_WarfareBHeavyFactory` | `US_WarfareBHeavyFactory_EP1` |
| Aircraft Factory | `USMC_WarfareBAircraftFactory` | `US_WarfareBAircraftFactory_EP1` |
| Service Point | `USMC_WarfareBVehicleServicePoint` | `US_WarfareBVehicleServicePoint_EP1` |
| AA Radar | `USMC_WarfareBAntiAirRadar` | `US_WarfareBAntiAirRadar_EP1` |
| FARP | `Camp_EP1` | `Camp_EP1` |
| Construction crate | `US_WarfareBContructionSite_EP1` | `US_WarfareBContructionSite_EP1` |

### USMC (vanilla A2 — Structures_USMC.sqf)

`Common/Config/Core_Structures/Structures_USMC.sqf:6-20`

| Slot | Classname |
|---|---|
| Mobile HQ (folded) | `LAV25_HQ` |
| Headquarters | `LAV25_HQ_unfolded` |
| Barracks | `USMC_WarfareBBarracks` |
| Light Factory | `USMC_WarfareBLightFactory` |
| Command Center | `USMC_WarfareBUAVterminal` |
| Heavy Factory | `USMC_WarfareBHeavyFactory` |
| Aircraft Factory | `USMC_WarfareBAircraftFactory` |
| Service Point | `USMC_WarfareBVehicleServicePoint` |
| AA Radar | `USMC_WarfareBAntiAirRadar` |
| FARP | `Camp` |
| Construction crate | `USMC_WarfareBContructionSite` |

### RU (CO_RU variant — Chernarus/TKA)

`Common/Config/Core_Structures/Structures_CO_RU.sqf:6-20`

| Slot | Classname (Chernarus) | Classname (Takistan / OA map) |
|---|---|---|
| Mobile HQ (folded) | `BTR90_HQ` | `BTR90_HQ` |
| Headquarters | `BTR90_HQ_unfolded` | `BTR90_HQ_unfolded` |
| Barracks | `RU_WarfareBBarracks` | `TK_WarfareBBarracks_EP1` |
| Light Factory | `RU_WarfareBLightFactory` | `TK_WarfareBLightFactory_EP1` |
| Command Center | `RU_WarfareBUAVterminal` | `TK_WarfareBUAVterminal_EP1` |
| Heavy Factory | `RU_WarfareBHeavyFactory` | `TK_WarfareBHeavyFactory_EP1` |
| Aircraft Factory | `RU_WarfareBAircraftFactory` | `TK_WarfareBAircraftFactory_EP1` |
| Service Point | `RU_WarfareBVehicleServicePoint` | `TK_WarfareBVehicleServicePoint_EP1` |
| AA Radar | `RU_WarfareBAntiAirRadar` | `TK_WarfareBAntiAirRadar_EP1` |
| FARP | `CampEast_EP1` | `CampEast_EP1` |
| Construction crate | `TK_WarfareBContructionSite_EP1` | `TK_WarfareBContructionSite_EP1` |

### RU (vanilla A2 — Structures_RU.sqf)

`Common/Config/Core_Structures/Structures_RU.sqf:6-20`

| Slot | Classname |
|---|---|
| Mobile HQ (folded) | `BTR90_HQ` |
| Headquarters | `BTR90_HQ_unfolded` |
| Barracks | `RU_WarfareBBarracks` |
| Light Factory | `RU_WarfareBLightFactory` |
| Command Center | `RU_WarfareBUAVterminal` |
| Heavy Factory | `RU_WarfareBHeavyFactory` |
| Aircraft Factory | `RU_WarfareBAircraftFactory` |
| Service Point | `RU_WarfareBVehicleServicePoint` |
| AA Radar | `RU_WarfareBAntiAirRadar` |
| FARP | `CampEast` |
| Construction crate | `RU_WarfareBContructionSite` |

### CDF (CO_CDF — Chernarus; Structures_CDF — fallback)

`Common/Config/Core_Structures/Structures_CDF.sqf:6-20`; `Structures_CO_CDF.sqf:6-20` (identical classnames, different build times)

| Slot | Classname |
|---|---|
| Mobile HQ (folded) | `BMP2_HQ_CDF` |
| Headquarters | `BMP2_HQ_CDF_unfolded` |
| Barracks | `CDF_WarfareBBarracks` |
| Light Factory | `CDF_WarfareBLightFactory` |
| Command Center | `CDF_WarfareBUAVterminal` |
| Heavy Factory | `CDF_WarfareBHeavyFactory` |
| Aircraft Factory | `CDF_WarfareBAircraftFactory` |
| Service Point | `CDF_WarfareBVehicleServicePoint` |
| AA Radar | `CDF_WarfareBAntiAirRadar` |
| FARP | `Camp` |
| Construction crate | `CDF_WarfareBContructionSite` |

> Note: `Structures_CO_CDF.sqf` and `Structures_CDF.sqf` share the same classnames. Build times differ: `Structures_CO_CDF.sqf` uses the slow profile (70/90/110/130/150/70/280 s), while `Structures_CDF.sqf` uses standard 60 s times. `Structures_CO_CDF.sqf:36,45,54,63,72,81,91`; `Structures_CDF.sqf:36,45,54,63,72,81,91`. Root_CDF loads the CO variant when `WF_A2_CombinedOps` is true, and the vanilla `Structures_CDF.sqf` otherwise. `Root_CDF.sqf:123-128`

### GUE / CO_GUE

`Common/Config/Core_Structures/Structures_CO_GUE.sqf:6-20`; `Structures_GUE.sqf:6-14`

The two files use different classname prefixes for Command Center and Aircraft Factory. The CO_GUE file (active when `WF_A2_CombinedOps` is true) uses a lowercase `Gue_` prefix for the Chernarus branch of those slots; the vanilla GUE file uses the uppercase `GUE_` prefix.

| Slot | CO_GUE — Chernarus (`IS_chernarus_map_dependent`) | CO_GUE — Takistan | GUE vanilla (`Structures_GUE.sqf`) |
|---|---|---|---|
| Mobile HQ (folded) | `BRDM2_HQ_Gue` | `BRDM2_HQ_Gue` | `BRDM2_HQ_Gue` |
| Headquarters | `BRDM2_HQ_Gue_unfolded` | `BRDM2_HQ_Gue_unfolded` | `BRDM2_HQ_Gue_unfolded` |
| Barracks | `Gue_WarfareBBarracks` | `TK_GUE_WarfareBBarracks_EP1` | `Gue_WarfareBBarracks` |
| Light Factory | `Gue_WarfareBLightFactory` | `TK_GUE_WarfareBLightFactory_EP1` | `Gue_WarfareBLightFactory` |
| Command Center | `Gue_WarfareBUAVterminal` | `TK_GUE_WarfareBUAVterminal_EP1` | `GUE_WarfareBUAVterminal` |
| Heavy Factory | `Gue_WarfareBHeavyFactory` | `TK_GUE_WarfareBHeavyFactory_EP1` | `Gue_WarfareBHeavyFactory` |
| Aircraft Factory | `Gue_WarfareBAircraftFactory` | `TK_GUE_WarfareBAircraftFactory_EP1` | `GUE_WarfareBAircraftFactory` |
| Service Point | `Gue_WarfareBVehicleServicePoint` | `TK_GUE_WarfareBVehicleServicePoint_EP1` | `GUE_WarfareBVehicleServicePoint` |
| AA Radar | `Gue_WarfareBAntiAirRadar` | `TK_GUE_WarfareBAntiAirRadar_EP1` | `Gue_WarfareBAntiAirRadar` |
| FARP | `Land_A_tent` | `Land_A_tent` | `CampEast` |
| Construction crate | `Gue_WarfareBContructionSite` | `Gue_WarfareBContructionSite` | `Gue_WarfareBContructionSite` |

`Structures_CO_GUE.sqf:10,12` (`Gue_` prefix, Chernarus branch); `Structures_GUE.sqf:10,12` (`GUE_` prefix, vanilla). `Structures_GUE.sqf:17` (FARP `CampEast`); `Structures_CO_GUE.sqf:17` (FARP `Land_A_tent`).

### INS (CO_INS — Chernarus; Structures_INS — vanilla)

`Common/Config/Core_Structures/Structures_INS.sqf:6-20`; `Structures_CO_INS.sqf:6-14`

| Slot | Classname |
|---|---|
| Mobile HQ (folded) | `BMP2_HQ_INS` |
| Headquarters | `BMP2_HQ_INS_unfolded` |
| Barracks | `Ins_WarfareBBarracks` |
| Light Factory | `Ins_WarfareBLightFactory` |
| Command Center | `INS_WarfareBUAVterminal` |
| Heavy Factory | `Ins_WarfareBHeavyFactory` |
| Aircraft Factory | `INS_WarfareBAircraftFactory` |
| Service Point | `INS_WarfareBVehicleServicePoint` |
| AA Radar | `INS_WarfareBAntiAirRadar` |
| FARP | `Land_A_tent` / `CampEast` | 
| Construction crate | `Ins_WarfareBContructionSite` |

> `Structures_CO_INS.sqf` uses `Land_A_tent`; `Structures_INS.sqf` uses `CampEast`. `Structures_CO_INS.sqf:17`, `Structures_INS.sqf:17`

### TKA (Structures_OA_TKA — Takistan only)

`Common/Config/Core_Structures/Structures_OA_TKA.sqf:6-20`

| Slot | Classname |
|---|---|
| Mobile HQ (folded) | `BMP2_HQ_TK_EP1` |
| Headquarters | `BMP2_HQ_TK_unfolded_EP1` |
| Barracks | `TK_WarfareBBarracks_EP1` |
| Light Factory | `TK_WarfareBLightFactory_EP1` |
| Command Center | `TK_WarfareBUAVterminal_EP1` |
| Heavy Factory | `TK_WarfareBHeavyFactory_EP1` |
| Aircraft Factory | `TK_WarfareBAircraftFactory_EP1` |
| Service Point | `TK_WarfareBVehicleServicePoint_EP1` |
| AA Radar | `TK_WarfareBAntiAirRadar_EP1` |
| FARP | `CampEast_EP1` |
| Construction crate | `TK_WarfareBContructionSite_EP1` |

### TK_GUE (Structures_OA_TKGUE — Takistan only)

`Common/Config/Core_Structures/Structures_OA_TKGUE.sqf:6-20`

| Slot | Classname |
|---|---|
| Mobile HQ (folded) | `BRDM2_HQ_TK_GUE_EP1` |
| Headquarters | `BRDM2_HQ_TK_GUE_unfolded_EP1` |
| Barracks | `TK_GUE_WarfareBBarracks_EP1` |
| Light Factory | `TK_GUE_WarfareBLightFactory_EP1` |
| Command Center | `TK_GUE_WarfareBUAVterminal_EP1` |
| Heavy Factory | `TK_GUE_WarfareBHeavyFactory_EP1` |
| Aircraft Factory | `TK_GUE_WarfareBAircraftFactory_EP1` |
| Service Point | `TK_GUE_WarfareBVehicleServicePoint_EP1` |
| AA Radar | `TK_GUE_WarfareBAntiAirRadar_EP1` |
| FARP | `CampEast_EP1` |
| Construction crate | `TK_GUE_WarfareBContructionSite_EP1` |

### OA_US — dead code (Structures_OA_US.sqf is never loaded)

> `Structures_OA_US.sqf` exists in the repository but is never loaded by any Root file — it is dead code. `Root_US.sqf` loads `Structures_CO_US.sqf` unconditionally for all maps (`Root_US.sqf:134-135`); no `WF_A2_CombinedOps` branch is present for the structures call in that file. The Takistan classnames (`M1130_HQ_unfolded_EP1`, `US_WarfareBBarracks_EP1`, etc.) reach the mission via the `IS_chernarus_map_dependent` branch inside `Structures_CO_US.sqf`, not from this file.

---

## AI auto-build defense classnames

Each file also registers a `WFBE_<side>DEFENSES_*` set. The AI construction authority reads these when selecting which defenses to build autonomously.

| Faction / file | MG | GL | AA pod | AT pod | Cannon | Mortar | MASH |
|---|---|---|---|---|---|---|---|
| USMC (`Structures_USMC.sqf:165-172`) | `M2StaticMG` | `MK19_TriPod` | `Stinger_Pod` | `TOW_TriPod` | `M119` | `M252` | `MASH` |
| CO_US (`Structures_CO_US.sqf:180-186`) | `M2StaticMG_US_EP1` | `MK19_TriPod_US_EP1` | `Stinger_Pod_US_EP1` | `TOW_TriPod_US_EP1` | `M119_US_EP1` | `M252_US_EP1` | `MASH_EP1` |
| RU (`Structures_RU.sqf:166-173`) | `KORD_high` | `AGS_RU` | `Igla_AA_pod_East`, `ZU23_Ins` | `Metis`, `SPG9_Ins` | `D30_RU` | `2b14_82mm` | `MASH` |
| CO_RU / OA_TKA (`Structures_CO_RU.sqf:177-184`) | `KORD_high_TK_EP1` | `AGS_TK_EP1` | `Igla_AA_pod_TK_EP1`, `ZU23_TK_EP1` | `Metis_TK_EP1`, `SPG9_TK_INS_EP1` | `D30_TK_EP1` | `2b14_82mm_TK_EP1` | `MASH_EP1` |
| CDF (`Structures_CDF.sqf:157-164`) | `DSHKM_CDF` | `AGS_CDF` | `ZU23_CDF` | `SPG9_CDF` | `D30_CDF` | `2b14_82mm_CDF` | `MASH` |
| CO_CDF (`Structures_CO_CDF.sqf:157-163`) | `DSHKM_CDF` | `AGS_CDF` | `ZU23_CDF` | `SPG9_CDF` | `D30_CDF` | — *(no mortar set)* | `MASH` |
| GUE (`Structures_GUE.sqf:154-161`) | `DSHKM_Gue` | `DSHKM_Gue` | `ZU23_Gue` | `SPG9_Gue` | `SPG9_Gue` | `2b14_82mm_GUE` | `MASH` |
| CO_GUE (`Structures_CO_GUE.sqf:157-164`) | `DSHKM_Gue` | `DSHKM_Gue` | `ZU23_Gue` | `SPG9_Gue` | `SPG9_Gue` | `2b14_82mm_TK_GUE_EP1` | `MASH` |
| INS (`Structures_INS.sqf:157-164`) | `DSHKM_Ins` | `AGS_Ins` | `ZU23_Ins` | `SPG9_Ins` | `D30_Ins` | `2b14_82mm_INS` | `MASH` |
| CO_INS (`Structures_CO_INS.sqf:157-164`) | `DSHKM_Ins` | `AGS_Ins` | `ZU23_Ins` | `SPG9_Ins` | `D30_Ins` | — *(not set)* | `MASH` |
| OA_TKGUE (`Structures_OA_TKGUE.sqf:155-162`) | `DSHKM_TK_GUE_EP1` | `AGS_TK_GUE_EP1` | `ZU23_TK_GUE_EP1` | `SPG9_TK_GUE_EP1` | `D30_TK_GUE_EP1` | `2b14_82mm_TK_GUE_EP1` | `MASH_EP1` |

---

## Runtime variable publishing

After populating all arrays each Structures_*.sqf also publishes per-faction shorthand variables via a `forEach` loop so other scripts can read e.g. `WESTHQ` directly without indexing the array:

```sqf
{
    missionNamespace setVariable [Format ["%1%2",_side, _x select 0], _x select 1];
} forEach [["HQ",_HQ],["BAR",_BAR],["LVF",_LVF],["CC",_CC],["HEAVY",_HEAVY],["AIR",_AIR],["SP",_SP],["AAR",_AAR]];
```

`Common/Config/Core_Structures/Structures_CO_US.sqf:101-103` (pattern is identical in all files)

This produces variables of the form `<side>HQ`, `<side>BAR`, `<side>LVF`, `<side>CC`, `<side>HEAVY`, `<side>AIR`, `<side>SP`, `<side>AAR` — useful when null-guarding or comparing classnames in construction scripts.

---

## Continue Reading

- [Construction-And-CoIn-Systems-Atlas](Construction-And-CoIn-Systems-Atlas) — structure array schema, construction site lifecycle, CoIn placement logic
- [Defense-Structures-Catalog](Defense-Structures-Catalog) — full DEFENSENAMES list per faction, build-menu items, AI defense priorities
- [Factory-And-Purchase-Systems-Atlas](Factory-And-Purchase-Systems-Atlas) — what each factory tier unlocks and how purchase requests are validated
- [Faction-Unit-And-Vehicle-Roster-Catalog](Faction-Unit-And-Vehicle-Roster-Catalog) — unit/vehicle classnames per faction, cross-references the structure-owner side
- [Variable-And-Naming-Conventions](Variable-And-Naming-Conventions) — `WFBE_C_*` constant naming, `WFBE_<side>*` pattern, side token values
