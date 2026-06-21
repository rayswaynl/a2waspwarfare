# AI Squad Team Templates Catalog (per-faction compositions, types, upgrade requirements)

> Source-verified 2026-06-21 against then-current master cf2a6d6a4; current origin/master is 0139a346, so recheck cited paths before current-head claims. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

Each faction loads a set of AI team templates into `missionNamespace` during faction initialisation. These templates are the pre-built squad compositions that the AI commander can deploy. This page catalogs every template per faction, its unit composition, factory-gate, team type, and upgrade requirement.

---

## Data Model

### Runtime variables (keyed by `_side` string)

| Variable | Type | Description |
|---|---|---|
| `WFBE_%1AITEAMTEMPLATES` | Array of arrays | Unit classname lists, one array per template |
| `WFBE_%1AITEAMTEMPLATEDESCRIPTIONS` | Array of strings | Human-readable names shown in the Commander UI |
| `WFBE_%1AITEAMTEMPLATEREQUIRES` | Array of 4-bool arrays | `[barracks, light, heavy, air]` — factory presence gates |
| `WFBE_%1AITEAMTYPES` | Array of ints | Team type: `0`=Infantry, `1`=Motorized/Light, `2`=Armor/Heavy, `3`=Air |
| `WFBE_%1AITEAMUPGRADES` | Array of 4-int arrays | `[barracks_lvl, light_lvl, heavy_lvl, air_lvl]` — minimum upgrade level required |

Source: `Common/Config/Core_Squads/Squad_USMC.sqf:53-57`, same pattern in all faction files.

The `%1` substitution key is the string passed as `_side` when the Squad file is called (e.g. `"West"`, `"East"`, `"Guerrila"`). It is **not** the faction shorthand — see the faction-to-variable table below.

### Upgrade level constants (`WFBE_UP_*`)

The four positions in the requires/upgrades arrays map to these indices (index 0–3):

| Index | `WFBE_UP_*` constant | Upgrade |
|---|---|---|
| 0 | `WFBE_UP_BARRACKS` | Barracks |
| 1 | `WFBE_UP_LIGHT` | Light Factory |
| 2 | `WFBE_UP_HEAVY` | Heavy Factory |
| 3 | `WFBE_UP_AIR` | Air Factory |

Source: `Common/Init/Init_CommonConstants.sqf:37-40`

### Availability check (Commander UI)

At Commander menu open, `GUI_Menu_Command.sqf` iterates all templates and hides any where any `upgrades[k] > currentUpgrades[k]` for k in 0–3. A template is **visible and orderable** only when all four upgrade conditions are simultaneously satisfied.

Source: `Client/GUI/GUI_Menu_Command.sqf:40-54`

---

## Template Sources: Two Paths

Templates are populated by two mechanisms:

1. **`Squads_GetFactionGroups.sqf`** — auto-iterates `CfgGroups >> <side> >> <faction>` and builds templates from every non-blacklisted group found in config. Unit `QUERYUNITFACTORY` (index 6, defined at `Common/Init/Init_CommonConstants.sqf:12`) sets the team type; `QUERYUNITUPGRADE` (index 5, defined at `Common/Init/Init_CommonConstants.sqf:11`) drives the upgrade level array. Source: `Common/Config/Core_Squads/Squads_GetFactionGroups.sqf:8-81`

2. **Custom groups** — appended directly in each Squad file after the `Squads_GetFactionGroups.sqf` call. These override or supplement the auto-generated list with hardcoded unit arrays, requires masks, types, and upgrade levels.

---

## Faction Mapping: Which Squad File, Which `_side` Key

| Faction | Squad file | `_side` key | Loaded by Root file |
|---|---|---|---|
| USMC (Chernarus West) | `Squad_USMC.sqf` | `"West"` | `Root_USMC.sqf:129,140` |
| RU (Chernarus East) | `Squad_RU.sqf` | `"East"` | `Root_RU.sqf:122` |
| GUE (Chernarus Resistance) | `Squad_GUE.sqf` | `"Guerrila"` | `Root_GUE.sqf:117,128` |
| CDF (CO West alt) | `Squad_CDF.sqf` | `"West"` | `Root_CDF.sqf:117` (overwrites USMC West variable) |
| INS (CO East alt) | `Squad_INS.sqf` | `"East"` | `Root_INS.sqf:116` (overwrites RU East variable) |
| US (OA West) | `Squad_OA_US.sqf` | `"West"` | `Root_US.sqf:128` |
| TKA (OA East) | `Squad_OA_TKA.sqf` | `"East"` | `Root_TKA.sqf:140` |
| TKGUE / PMC (OA Resistance) | `Squad_OA_TKGUE.sqf` | `"Guerrila"` | `Root_TKGUE.sqf:110`, `Root_PMC.sqf:104` |

> **Note:** CDF overwrites `WFBE_WestAITEAMTEMPLATES` etc. in the same namespace slot as USMC. Only one West faction is active per mission instance.

---

## USMC — Chernarus West

**Squad file:** `Common/Config/Core_Squads/Squad_USMC.sqf`  
**`CfgGroups` source:** `"West" >> "USMC"`, blacklist: `["USMC_MQ9Squadron","USMC_FRTeam_Razor"]`  
**CfgGroups-derived templates:** all non-blacklisted USMC infantry, motorized, mechanized, armor, and air groups from game config (resolved at init, contents depend on installed DLC).  
**Custom templates appended:**

| Name | Units (classnames) | Type | Factory gate (requires) | Upgrade required |
|---|---|---|---|---|
| Armor - M1A1 Section | `M1A1`, `M1A1` | 2 (Heavy) | Heavy | Heavy ≥ 1 |
| Air - Infantry UH1Y Squadron | `UH1Y`, `USMC_Soldier_TL`, `USMC_Soldier_AR`, `USMC_Soldier_LAT`, `USMC_Soldier_Medic`, `USMC_Soldier` ×3 | 3 (Air) | Barracks + Air | Air ≥ 1 |
| Air - Infantry MH-60S Squadron | `MH60S`, `USMC_Soldier_TL`, `USMC_Soldier_MG`, `USMC_Soldier_AT`, `USMC_Soldier_Medic`, `USMC_Soldier` ×3 | 3 (Air) | Barracks + Air | Barracks ≥ 2 |

Sources: `Squad_USMC.sqf:13-51`

**Requires/upgrades arrays verbatim:**
- Armor M1A1 Section: requires `[false,false,true,false]`, upgrades `[0,0,1,0]`
- UH1Y Squadron: requires `[true,false,false,true]`, upgrades `[0,0,0,1]`
- MH-60S Squadron: requires `[true,false,false,true]`, upgrades `[2,0,0,0]`

---

## RU — Chernarus East

**Squad file:** `Common/Config/Core_Squads/Squad_RU.sqf`  
**`CfgGroups` source:** `"East" >> "RU"`, blacklist: `["RU_Pchela1TSquadron","RU_Ka52Squadron"]`  
**Custom templates appended:**

| Name | Units (classnames) | Type | Factory gate (requires) | Upgrade required |
|---|---|---|---|---|
| Armor - Anti Air Platoon | `2S6M_Tunguska` ×2 | 2 (Heavy) | Heavy | Heavy ≥ 3 |
| Armor - Tank Platoon (Light) | `T72_RU` ×2 | 2 (Heavy) | Heavy | Heavy ≥ 1 |
| Air - Infantry Mi-8 Squadron | `Mi17_Ins`, `MVD_Soldier_TL`, `MVD_Soldier_GL`, `MVD_Soldier_MG` ×2, `MVD_Soldier_Marksman`, `MVD_Soldier_AT` ×2 | 3 (Air) | Barracks + Air | Barracks ≥ 2 |
| Air - Infantry Mi-8 Squadron (Rockets) | `Mi17_rockets_RU`, `RU_Soldier_TL`, `RU_Soldier_AA`, `RU_Soldier_LAT` ×2, `RU_Soldier_MG` ×2 | 3 (Air) | Barracks + Air | Barracks ≥ 2, Air ≥ 1 |
| Air - Ka-52 Squadron | `Ka52Black`, `Ka52` | 3 (Air) | Air | Air ≥ 3 |

Sources: `Squad_RU.sqf:13-68`

> **Note:** The Mi-8 Infantry template uses `MVD_Soldier_AT` as an RPG-7VR carrier (comment at `Squad_RU.sqf:38-39`). The comment at line 38 reads: `// MVD_Soldier_AT acts as RPG-7VR soldier now`.

**Requires/upgrades arrays verbatim:**
- Anti Air Platoon: requires `[false,false,true,false]`, upgrades `[0,0,3,0]`
- Tank Platoon (Light): requires `[false,false,true,false]`, upgrades `[0,0,1,0]`
- Mi-8 Infantry: requires `[true,false,false,true]`, upgrades `[2,0,0,0]`
- Mi-8 (Rockets): requires `[true,false,false,true]`, upgrades `[2,0,0,1]`
- Ka-52 Squadron: requires `[false,false,false,true]`, upgrades `[0,0,0,3]`

---

## GUE — Chernarus Resistance

**Squad file:** `Common/Config/Core_Squads/Squad_GUE.sqf`  
**`CfgGroups` source:** `"Guerrila" >> "GUE"` — no blacklist, no custom groups appended.  
**Custom templates:** none.

All templates come from CfgGroups auto-resolution only. No hardcoded custom groups are defined in this file. Source: `Squad_GUE.sqf:6-17`

---

## CDF — Chernarus West (Combined Operations only)

**Squad file:** `Common/Config/Core_Squads/Squad_CDF.sqf`  
**`CfgGroups` source:** `"West" >> "CDF"` — no blacklist.  
**Custom templates appended:**

| Name | Units (classnames) | Type | Factory gate (requires) | Upgrade required |
|---|---|---|---|---|
| Armor - APC Platoon | `BMP2_CDF` ×2 | 2 (Heavy) | Heavy | Heavy ≥ 2 |
| Armor - AA Platoon | `ZSU_CDF` ×2 | 2 (Heavy) | Heavy | Heavy ≥ 1 |
| Air - Mi-8 Infantry Squadron | `Mi17_CDF`, `CDF_Soldier_Medic`, `CDF_Soldier_MG`, `CDF_Soldier_AR`, `CDF_Soldier_RPG` ×2, `CDF_Soldier_Spotter`, `CDF_Soldier` | 3 (Air) | Air only | Barracks ≥ 1 |

Sources: `Squad_CDF.sqf:14-45`

> **Note:** The CDF Mi-8 air template requires only `[false,false,false,true]` (Air factory only, not Barracks) but the upgrade check requires `barracks >= 1`. This is an unusual combination — the AI can only order it when barracks has been upgraded at least once and an Air factory exists.

**Requires/upgrades arrays verbatim:**
- APC Platoon: requires `[false,false,true,false]`, upgrades `[0,0,2,0]`
- AA Platoon: requires `[false,false,true,false]`, upgrades `[0,0,1,0]`
- Mi-8 Infantry: requires `[false,false,false,true]`, upgrades `[1,0,0,0]`

---

## INS — Chernarus East (Combined Operations only)

**Squad file:** `Common/Config/Core_Squads/Squad_INS.sqf`  
**`CfgGroups` source:** `"East" >> "INS"` — no blacklist.  
**Custom templates appended:**

| Name | Units (classnames) | Type | Factory gate (requires) | Upgrade required |
|---|---|---|---|---|
| Armor - APC Platoon | `BMP2_INS` ×2 | 2 (Heavy) | Heavy | Heavy ≥ 2 |
| Armor - AA Platoon | `ZSU_INS` ×2 | 2 (Heavy) | Heavy | Heavy ≥ 1 |
| Air - Mi-8 Infantry Squadron | `Mi17_Ins`, `Ins_Soldier_Medic`, `Ins_Soldier_MG`, `Ins_Soldier_AR`, `Ins_Soldier_AT` ×2, `Ins_Soldier_Sniper`, `Ins_Soldier_1` | 3 (Air) | Air only | Barracks ≥ 1 |

Sources: `Squad_INS.sqf:14-45`

> **Note:** The comment at `Squad_INS.sqf:36-37` reads: `// Ins_Soldier_AT acts as Dragon soldier now`. The same air-only factory + barracks-upgrade pattern as CDF applies here.

**Requires/upgrades arrays verbatim:**
- APC Platoon: requires `[false,false,true,false]`, upgrades `[0,0,2,0]`
- AA Platoon: requires `[false,false,true,false]`, upgrades `[0,0,1,0]`
- Mi-8 Infantry: requires `[false,false,false,true]`, upgrades `[1,0,0,0]`

---

## OA US — Takistan West (Operation Arrowhead)

**Squad file:** `Common/Config/Core_Squads/Squad_OA_US.sqf`  
**`CfgGroups` source:** `"West" >> "BIS_US"`, blacklist: `["US_AH6XFlight","US_C130JFlight","US_MQ9Flight"]`  
**Custom templates appended:**

| Name | Units (classnames) | Type | Factory gate (requires) | Upgrade required |
|---|---|---|---|---|
| Armor - APC Platoon (Bradley) | `M2A2_EP1` ×2 | 2 (Heavy) | Heavy | Heavy ≥ 1 |
| Armor - Anti-Air Platoon | `M6_EP1` ×2 | 2 (Heavy) | Heavy | Heavy ≥ 3 |
| Air - Infantry CH-47F Squadron | `CH_47F_EP1`, `US_Soldier_TL_EP1`, `US_Soldier_AR_EP1`, `US_Soldier_LAT_EP1`, `US_Soldier_Medic_EP1`, `US_Soldier_EP1` ×3 | 3 (Air) | Barracks + Air | none (upgrades `[0,0,0,0]`) |

Sources: `Squad_OA_US.sqf:13-45`

> **Note:** The CH-47F squadron has `upgrades = [0,0,0,0]` — it requires both a Barracks and Air factory to be built (requires gate), but no upgrade level on either. It is available immediately once those two factories exist.

**Requires/upgrades arrays verbatim:**
- APC Platoon (Bradley): requires `[false,false,true,false]`, upgrades `[0,0,1,0]`
- Anti-Air Platoon: requires `[false,false,true,false]`, upgrades `[0,0,3,0]`
- CH-47F Squadron: requires `[true,false,false,true]`, upgrades `[0,0,0,0]`

---

## OA TKA — Takistan East (Operation Arrowhead)

**Squad file:** `Common/Config/Core_Squads/Squad_OA_TKA.sqf`  
**`CfgGroups` source:** `"East" >> "BIS_TK"`, blacklist: `["TK_An2Flight"]`  
**Custom templates appended:**

| Name | Units (classnames) | Type | Factory gate (requires) | Upgrade required |
|---|---|---|---|---|
| Armor - IFV Platoon (Light) | `BMP2_TK_EP1` ×2 | 2 (Heavy) | Heavy | none (upgrades `[0,0,0,0]`) |
| Armor - Anti Air Platoon | `ZSU_TK_EP1` ×2 | 2 (Heavy) | Heavy | Heavy ≥ 1 |
| Air - Infantry Mi-17 Squadron | `Mi17_TK_EP1`, `TK_Soldier_SL_EP1`, `TK_Soldier_AA_EP1` ×2, `TK_Soldier_LAT_EP1` ×2, `TK_Soldier_MG_EP1` ×2 | 3 (Air) | Barracks + Air | Barracks ≥ 2 |

Sources: `Squad_OA_TKA.sqf:13-45`

> **Note:** The IFV Platoon (Light) has no upgrade requirement (upgrades `[0,0,0,0]`), only a Heavy factory presence gate. It is the earliest armor team available to TKA.

**Requires/upgrades arrays verbatim:**
- IFV Platoon (Light): requires `[false,false,true,false]`, upgrades `[0,0,0,0]`
- Anti Air Platoon: requires `[false,false,true,false]`, upgrades `[0,0,1,0]`
- Mi-17 Squadron: requires `[true,false,false,true]`, upgrades `[2,0,0,0]`

---

## OA TKGUE / PMC — Takistan Resistance (Operation Arrowhead)

**Squad file:** `Common/Config/Core_Squads/Squad_OA_TKGUE.sqf`  
**`CfgGroups` source:** `"Guerrila" >> "BIS_TK_GUE"` — no blacklist, no custom groups appended.  
**Custom templates:** none.

All templates come from CfgGroups auto-resolution only. This file is also loaded for the PMC faction via `Root_PMC.sqf:104`. Source: `Squad_OA_TKGUE.sqf:6-17`

---

## Upgrade Level Cross-Reference

The four upgrade slots used across all custom templates map as follows. "Upgrade level" is the minimum value the current side upgrade must reach; 0 means no upgrade needed beyond the factory presence gate.

| Upgrade slot | Values seen in templates | Effect |
|---|---|---|
| Barracks (index 0) | 0, 1, 2 | 0 = any barracks OK; 1 = barracks upgrade 1 done; 2 = barracks upgrade 2 done |
| Light (index 1) | 0 only | Light factory upgrade gate is unused in all custom templates |
| Heavy (index 2) | 0, 1, 2, 3 | 1 = first heavy upgrade; 3 = max heavy upgrade required (Tunguska, Anti-Air platoons) |
| Air (index 3) | 0, 1, 3 | 1 = first air upgrade; 3 = max air upgrade required (Ka-52 squadron) |

---

## Summary: Custom Templates by Faction

| Faction | Map | Side key | Custom templates | Notes |
|---|---|---|---|---|
| USMC | Chernarus | `West` | 3 | M1A1 Section, UH1Y, MH-60S |
| RU | Chernarus | `East` | 5 | Two armor + three air; Ka-52 needs Air 3 |
| GUE | Chernarus | `Guerrila` | 0 | CfgGroups auto only |
| CDF | Combined Ops | `West` | 3 | BMP2, ZSU, Mi-8 |
| INS | Combined Ops | `East` | 3 | BMP2, ZSU, Mi-8 |
| OA US | Takistan | `West` | 3 | Bradley, M6 Linebacker, CH-47F (no upgrades) |
| OA TKA | Takistan | `East` | 3 | BMP2, ZSU, Mi-17 |
| TKGUE / PMC | Takistan | `Guerrila` | 0 | CfgGroups auto only |

---

## Adding a New Custom Template

To append a template to a faction's list, edit the corresponding Squad file and follow this pattern after the `Squads_GetFactionGroups.sqf` call:

```sqf
_u = ["VehicleClass"];
_u = _u + ["InfantryClass1"];
_u = _u + ["InfantryClass2"];

_aiTeamTemplateName = _aiTeamTemplateName + ["Category - Display Name"];
_aiTeamTemplates = _aiTeamTemplates + [_u];
_aiTeamTemplateRequires = _aiTeamTemplateRequires + [[false,false,true,false]];
_aiTeamTypes = _aiTeamTypes + [2];
_aiTeamUpgrades = _aiTeamUpgrades + [[0,0,1,0]];
```

The five `missionNamespace setVariable` calls at the end of each Squad file write the final accumulated arrays to the namespace — ensure those lines remain at the bottom and are not duplicated.

Source: `Squad_USMC.sqf:53-57`, `Squad_RU.sqf:70-74`, etc.

---

## Continue Reading

- [AI-Commander-Autonomy-Audit](AI-Commander-Autonomy-Audit) — scheduling flow and how the AI commander decides which templates to deploy
- [Upgrades-And-Research-Atlas](Upgrades-And-Research-Atlas) — upgrade level definitions, costs, and what each level unlocks
- [Factory-And-Purchase-Systems-Atlas](Factory-And-Purchase-Systems-Atlas) — factory presence gates and how `WFBE_UP_*` maps to factory structures
- [Variable-And-Naming-Conventions](Variable-And-Naming-Conventions) — `WFBE_*` naming pattern and `QUERYUNIT*` index constants
- [Assets-Config-Localization-And-Parameters-Atlas](Assets-Config-Localization-And-Parameters-Atlas) — how unit classnames are registered and the `QUERYUNITFACTORY`/`QUERYUNITUPGRADE` slots
