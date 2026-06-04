# Mission Config Version Include Graph

This page owns the small but important `version.sqf` contract that sits between mission metadata, generated terrain outputs and runtime boot flags. Use it with [Mission parameters/localization/build inputs](Mission-Parameters-Localization-And-Generated-Build-Inputs), [Mission entrypoints](Mission-Entrypoints-And-Lifecycle), [Content structure and maps](Content-Structure-And-Maps) and [Tools/build](Tools-And-Build-Workflow).

All source paths below are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/` unless another root is named.

## Include Chain

```mermaid
flowchart TD
    Version["version.sqf"] --> Description["description.ext"]
    Version --> Init["initJIPCompatible.sqf"]
    Description --> Header["Rsc/Header.hpp"]
    Header --> LoadScreen["mission load metadata"]
    Init --> RuntimeFlags["runtime map/version flags"]
```

`version.sqf` is not just a release-note file. It feeds both static mission config and runtime bootstrap:

| Consumer | Evidence | Contract |
| --- | --- | --- |
| `description.ext` | `description.ext:39` | Includes generated terrain metadata before `Rsc/Header.hpp`. |
| `Rsc/Header.hpp` | `Rsc/Header.hpp:5,9,21` | Uses `WF_RESPAWNDELAY`, `WF_MISSIONNAME` and `WF_MAXPLAYERS` for mission header values. |
| `initJIPCompatible.sqf` | `initJIPCompatible.sqf:4,31,111-113` | Includes `version.sqf`, logs `WF_MAXPLAYERS`, and converts `IS_CHERNARUS_MAP_DEPENDENT` into runtime `IS_chernarus_map_dependent`. |
| Vanilla/CO UI gate | `description.ext:61-63`, `Rsc/Header.hpp:12-14` | Uses the `VANILLA` preprocessor macro for OA/CO-dependent config. This is separate from the `Missions_Vanilla` folder name. |

## Current Generated Examples

| Mission root | Generated contract observed |
| --- | --- |
| Source Chernarus | Local generated `version.sqf` carries `WF_MAXPLAYERS = 55`, a Chernarus mission name, `IS_CHERNARUS_MAP_DEPENDENT` and `IS_NAVAL_MAP`. |
| Maintained Vanilla Takistan | Local generated `version.sqf` carries `WF_MAXPLAYERS = 61` and a Takistan mission name; the sampled output does not define the Chernarus/naval flags. |

These generated files are ignored by git, so do not assume a clean checkout has them. LoadoutManager owns normal generation.

Release gate: if any claimed mission root lacks a generated `version.sqf`, that root is blocked for pack, smoke and release wording. Verify the file exists and that its `WF_MAXPLAYERS`, `WF_MISSIONNAME`, `WF_RESPAWNDELAY`, map flags and debug/log flags match the terrain profile before treating later SQF validation as meaningful. The machine checklist is `agent-release-readiness.json` `versionSqfGeneratedInput`.

## Map Flag Semantics

`IS_CHERNARUS_MAP_DEPENDENT` is currently a binary switch. If the macro is absent, runtime code falls into non-Chernarus/Takistan-style defaults. This affects faction defaults and many class choices through `IS_chernarus_map_dependent`.

Source anchors:

- `initJIPCompatible.sqf:111-113` sets the runtime boolean.
- `initJIPCompatible.sqf:254-266` branches source boot behavior on it.
- `Common/Init/Init_CommonConstants.sqf:383-395` selects Chernarus-style versus Takistan-style faction defaults.
- `Common/Init/Init_Common.sqf:256-257` selects side root names from the same boolean.
- `Common/Config/Core_Structures/*` and `Common/Functions/Common_AddVehicleTexture.sqf` contain many Chernarus/non-Chernarus class branches.

Practical rule for modded maps: if a terrain is not truly Takistan-like, do not rely on the absence of `IS_CHERNARUS_MAP_DEPENDENT` as a neutral default. Add or document the intended terrain profile.

## Naval Flag

`IS_NAVAL_MAP` is live content metadata. Runtime init converts it into `IS_naval_map`, and unit/root configs use that to add boat classes.

Evidence:

- `initJIPCompatible.sqf:16-20` sets `IS_naval_map`.
- `Common/Config/Core_Units/Units_CO_US.sqf:307,335` adds `Zodiac`.
- `Common/Config/Core_Units/Units_CO_RU.sqf:262,292` adds `PBX`.

Terrain authors should verify naval intent before generating or packaging a new mission root; the flag changes purchasable content.

## Developer Rules

- Treat `version.sqf` as required generated terrain metadata, not optional docs.
- Missing generated `version.sqf` is a boot/release blocker for that mission root, even when all tracked source files look clean.
- Verify `WF_MAXPLAYERS`, `WF_MISSIONNAME`, `WF_RESPAWNDELAY`, `IS_CHERNARUS_MAP_DEPENDENT`, `IS_NAVAL_MAP`, `WF_DEBUG` and `WF_LOG_CONTENT` in the target mission root before release packaging.
- Do not confuse `Missions_Vanilla` with the `VANILLA` preprocessor macro. The folder is a generated target label; the macro gates OA/CO config paths inside mission headers.
- If a modded map needs different defaults than Chernarus and Takistan, document or implement a real terrain profile instead of inheriting the binary fallback by accident.

## Continue Reading

Previous: [Mission entrypoints and lifecycle](Mission-Entrypoints-And-Lifecycle) | Next: [Mission parameters/localization/build inputs](Mission-Parameters-Localization-And-Generated-Build-Inputs)

Main map: [Home](Home) | Content map: [Content structure and maps](Content-Structure-And-Maps) | Tooling: [Tools and build workflow](Tools-And-Build-Workflow)
