# Mission Parameters Localization And Generated Build Inputs

This page owns mission parameter flow, localization hazards and generated include/build inputs. It complements [Mission entrypoints and lifecycle](Mission-Entrypoints-And-Lifecycle), [Mission config/version include graph](Mission-Config-Version-Include-Graph), [Tools and build workflow](Tools-And-Build-Workflow), [Content structure and maps](Content-Structure-And-Maps) and [Source fix propagation queue](Source-Fix-Propagation-Queue).

## Source Of Truth

`description.ext:52` includes `Rsc\Parameters.hpp`; the `class Params` order is the authoritative `paramsArray` index order. `description.ext:39` and `initJIPCompatible.sqf:4` both include `version.sqf`. Recheck on 2026-06-14 at docs checkout `85679dba`: source Chernarus and maintained Vanilla Takistan have no present or tracked generated `version.sqf` files, while `.gitignore:1,23` still ignores those paths. LoadoutManager owns generation/update of version outputs for terrain copies, and several modded/stub roots remain incomplete without generated inputs.

Source refs:

- `Rsc/Parameters.hpp:3-561` declares mission parameters.
- `Common/Init/Init_Parameters.sqf:5-10` caches parameter values.
- `initJIPCompatible.sqf:121` compiles parameters before constants; `:212` sets `WFBE_Parameters_Ready`.
- `Common/Init/Init_CommonConstants.sqf:65-67` documents the nil-default pattern that avoids overriding MP parameters.
- `Client/GUI/GUI_Display_Parameters.sqf:3-12` displays parameter names/statuses from the same `Params` tree.

Full lobby/start parameter index: [Mission start parameters index](Mission-Start-Parameters-Index). Current maintained Chernarus and Vanilla Takistan have identical `Rsc/Parameters.hpp` files in docs checkout `85679dba`, with 89 active lobby-visible parameters plus one commented-out upgrade-clearance class that is not host-selectable.

## Parameter Cache Flow

1. `description.ext` includes `Rsc\Parameters.hpp`.
2. Arma populates `paramsArray` from `class Params` order in multiplayer.
3. `Init_Parameters.sqf` loops over `missionConfigFile >> "Params"`.
4. In multiplayer, it reads `paramsArray select _i`; in single-player, it reads each class `default`.
5. Each value is written to `missionNamespace` with the parameter class name.
6. `Init_CommonConstants.sqf` then fills nil defaults without overwriting already-cached MP values.

Runtime consumers include day/night duration, AFK timeout, AntiStack enable, performance audit enable, map icon blinking, bomb restrictions and many gameplay/economy toggles.

Current ordnance parameter caveat: `WFBE_C_GAMEPLAY_BOMBS_ALTITUDE` exists in `Rsc/Parameters.hpp:284-288`, but the current bomb handler comments out the altitude enforcement block (`Common/Functions/Common_HandleShootBombs.sqf:32-44`). By contrast, `WFBE_C_GAMEPLAY_BOMBS_DISTANCE_RESTRICTION` is consumed by the live distance-delete path (`Common_HandleShootBombs.sqf:21-30`). Do not describe the altitude parameter as active gameplay enforcement until that handler is revived and smoke-tested.

Parameter-name drift caveat: the generic importer does not normalize near-miss names. A 2026-06-04 config scout found `Rsc/Parameters.hpp:393-397` exposes `WFBE_C_MODULE_WFBE_IRS`, while common init and upgrade gates read `WFBE_C_MODULE_WFBE_IRSMOKE` (`Init_CommonConstants.sqf:238`, `Init_Common.sqf:320`, representative `Upgrades_CO_US.sqf:24-25`). Unless a later generation step deliberately aliases those variables, changing the lobby value does not control the runtime IR-smoke module gate.

Hidden-or-forced parameter caveat: some runtime switches are not ordinary lobby controls. `WFBE_C_GAMEPLAY_UPGRADES_CLEARANCE` is commented out in `Rsc/Parameters.hpp:351-356`, but constants/server init still use it (`Init_CommonConstants.sqf:225`, `Server/Init/Init_Server.sqf:333-349`) and boot code can force it to `7` (`initJIPCompatible.sqf:148,152`). `WFBE_C_ENVIRONMENT_WEATHER_VOLUMETRIC` exists in `Parameters.hpp:210-214`, but common constants and client init both force it to `0` (`Init_CommonConstants.sqf:212`, `Client/Init/Init_Client.sqf:218`). Treat these as internal/locked runtime state until the owner chooses to expose them deliberately.

Air Event override caveat: the old air-event setting is still present in both maintained mission roots. `Rsc/Parameters.hpp:26-30` exposes `WFBE_AIR_EVENT_ENABLED` with values `0` default/no override, `1` disabled and `2` enabled. During boot, `initJIPCompatible.sqf:125-140` converts that value plus the optional generated `IS_AIR_WAR_EVENT` define from ignored `version.sqf:6` into global `IS_air_war_event`. When enabled, it is not just a label: `initJIPCompatible.sqf:142-149` forces very high starting supply/funds, starts towns in mode `1` and sets upgrade clearance to `7`; upgrade configs hide ICBM (`Common/Config/Core_Upgrades/Upgrades_*.sqf:17`); the Tactical menu also hides the ICBM option (`Client/GUI/GUI_Menu_Tactical.sqf:253`); and representative CO heavy-unit configs omit the Avenger/Tunguska anti-air vehicles when `IS_air_war_event` is true (`Units_CO_US.sqf:233-245`, `Units_CO_RU.sqf:161-175`). Treat it as a live event-balance mode with ICBM and heavy-AA restrictions, not a full aircraft-event subsystem.

Visible-parameter runtime-consumer caveat, branch-checked 2026-06-05: current source Chernarus, maintained Vanilla Takistan, `origin/master`, `miksuu/master` and `origin/release/2026-06-feature-bundle` all expose `WFBE_C_AI_MAX` in `Rsc/Parameters.hpp` and default it in `Init_CommonConstants.sqf`, but the fixed-string source search found no active runtime reader outside the parameter/default paths in the maintained roots. Player follower limits are instead `WFBE_C_PLAYERS_AI_MAX`, read by the buy menu and RHUD and modified by Soldier skill init (`GUI_Menu_BuyUnits.sqf:37`, `Client_UpdateRHUD.sqf:312`, `Skill_Init.sqf:49`; release Chernarus line drift only). The same branch check shows `WFBE_C_UNITS_CLEAN_TIMEOUT` remains visible/defaulted but comment-only in cleanup: live corpse cleanup reads `WFBE_C_UNITS_BODIES_TIMEOUT` (`Common_TrashObject.sqf:19`), the old man/non-man split that references `WFBE_C_UNITS_CLEAN_TIMEOUT` is commented at `:20`, and empty vehicles use `WFBE_C_UNITS_EMPTY_TIMEOUT` through `Server_HandleEmptyVehicle.sqf:12,18`. Treat both as host-facing cleanup/balance debt until code owners either wire, hide, rename, or deliberately label them historical.

## MP Defaults Versus Constants Fallbacks

Wave O found a real default drift class: mission boot only calls `Common/Init/Init_Parameters.sqf` when `isMultiplayer` is true (`initJIPCompatible.sqf:121`). In non-MP boot paths, `Init_CommonConstants.sqf` fills any nil values instead of reading `Rsc/Parameters.hpp` defaults, even though `GUI_Display_Parameters.sqf` can display SP defaults directly from the config tree.

| Parameter | Lobby/config default | Constants fallback | Why it matters |
| --- | --- | --- | --- |
| `WFBE_C_AI_COMMANDER_ENABLED` | `Rsc/Parameters.hpp:92-97` default `0` | `Init_CommonConstants.sqf:91` fallback `1` | Solo/local tests can exercise AI-commander-adjacent code that the MP lobby default disables. |
| `WFBE_C_ARTILLERY` | `Rsc/Parameters.hpp:80-84` default `2` | `Init_CommonConstants.sqf:105` fallback `1` | Artillery range/timeout behavior can differ between hosted MP and non-MP tests. |
| `WFBE_C_BASE_AREA` | `Rsc/Parameters.hpp:104-108` default `3` | `Init_CommonConstants.sqf:119` fallback `2` | Construction/base-area limits differ under fallback-only boot. |
| `WFBE_ICBM_TIME_TO_IMPACT` | `Rsc/Parameters.hpp:32-36` default `5` | `Init_CommonConstants.sqf:239` fallback `1` | Nuke timing tests can look dramatically faster/shorter different outside MP. |
| `WFBE_RADZONE_TIME` | `Rsc/Parameters.hpp:38-42` default `10` | `Init_CommonConstants.sqf:240` fallback `1` | Radiation-duration tests can understate live lobby behavior. |

Practical rule: when a finding depends on mission parameters, state whether the evidence came from MP lobby defaults, non-MP/constants fallback, or generated mission config. Do not assume those three layers agree.

## In-Game Parameter Display

`RscDisplay_Parameters` loads `Client/GUI/GUI_Display_Parameters.sqf`, which reads titles/texts/values from `missionConfigFile >> "Params"` and current values from `paramsArray` or default. That makes the `Params` tree both the host setup source and the in-game reference display source.

## Localization Integrity

The scout pass found no live missing `$STR_...` keys for `Rsc/Parameters.hpp` references. Known quality gaps remain:

- `WFBE_C_ANTISTACK_ENABLED` and `WFBE_C_PERFORMANCE_AUDIT_ENABLED` use literal English titles in `Parameters.hpp:547-555`.
- `WFBE_C_GAMEPLAY_BOMBS_DISTANCE_RESTRICTION` reuses `$STR_WF_PARAMETER_BombAltitude` at `Parameters.hpp:290-291`, while the consumer is distance-based.
- `STR_Supplies_2` in `stringtable.xml:188-193` still tells players supply-truck deliveries pay `4 x the actual value`; current source grants raw `_supplyAmount` from the supply mission cargo calculation (`supplyMissionStart.sqf:32`, `supplyMissionCompletedMessage.sqf:13-14`), while `WFBE_C_PLAYERS_SUPPLY_TRUCKS_DELIVERY_FUNDS_COEF = 4` is defined but not consumed in that live flow.
- Live UI controllers still include hardcoded English player-facing text: Buy Units vehicle-help hints at `GUI_Menu_BuyUnits.sqf:443-457` and Tactical artillery ammo request status at `GUI_Menu_Tactical.sqf:604-605`.
- Several translated parameter/help strings fall back to English or contain stale text; treat `stringtable.xml` as functional but not polished.

## Version And Include Generation

`version.sqf` is included by both `description.ext` and `initJIPCompatible.sqf`. In the current 2026-06-14 docs checkout, `Test-Path` is false for `Missions/[55-2hc]warfarev2_073v48co.chernarus/version.sqf` and `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/version.sqf`; `git --literal-pathspecs ls-files -- .../version.sqf` returns no tracked rows. `.gitignore:1,23` ignores both generated paths. `Tools/LoadoutManager/FileManagement/FileManager.cs:92-100` treats `version.sqf` specially during copy/delete, and `Tools/LoadoutManager/Data/Terrains/BaseTerrain.cs:99-102,346-367` writes the generated version output from the C# terrain flow.

The concrete contract lives in [Mission config/version include graph](Mission-Config-Version-Include-Graph): `description.ext:39` includes `version.sqf`, `Rsc/Header.hpp:5,9,21` uses `WF_RESPAWNDELAY`, `WF_MISSIONNAME` and `WF_MAXPLAYERS`, and `initJIPCompatible.sqf:4,31,111-113` includes/logs those values and converts `IS_CHERNARUS_MAP_DEPENDENT` into runtime `IS_chernarus_map_dependent`. The same graph also records that `IS_NAVAL_MAP` changes purchasable boat content through `IS_naval_map`.

Practical rule: verify the target mission root, not just source Chernarus. A source checkout may be packable, while generated Vanilla or modded/stub folders still need LoadoutManager output or terrain-specific generated files. Use LoadoutManager from a normal `a2waspwarfare` clone or any repo root that contains `Missions`, `Missions_Vanilla` and `Tools/LoadoutManager/LoadoutManager.csproj`. For propagation-only work, set `A2WASP_SKIP_ZIP=1` so missing `7za` does not block generation/copy.

## LoadoutManager Overwrite Boundaries

Important tooling evidence:

- `FileManager.cs:59-84` and `:103-136` copy/delete outputs and remove destination extras.
- `FileManager.cs:140-180` first accepts an ancestor folder literally named `a2waspwarfare`, then falls back to a repo-marker check for `Missions`, `Missions_Vanilla` and `Tools/LoadoutManager/LoadoutManager.csproj`.
- `BaseTerrain.cs:94-104` writes generated mission files such as EASA/balance/aircraft names/version outputs.
- `BaseTerrain.cs:35-66` rewrites the source mission `Sounds/description.ext` from `.ogg` filenames.
- `SqfFileGenerator.cs:127-135` calls package/zip operations after generation.
- `ZipManager.cs:73-77` throws if the `7za` environment variable is not set during packaging; propagation-only runs can skip packaging with `A2WASP_SKIP_ZIP=1`.

This means current Codex checkouts such as `work\a` can run LoadoutManager after the repo-marker discovery update. Do not revive older documentation that says the literal folder name is the only valid path.

## Patch And Validation Checklist

| Finding | Patch shape | Validation |
| --- | --- | --- |
| Literal English admin parameter titles | Add stringtable-backed titles for AntiStack and performance audit, or document them as intentionally admin-only English. | Parameter display shows intended labels; no missing stringtable keys. |
| Bomb distance title reuses altitude text | Add `STR_WF_PARAMETER_BombDistanceRestriction` and use it for `WFBE_C_GAMEPLAY_BOMBS_DISTANCE_RESTRICTION`. | Host parameter list and in-game parameter display distinguish altitude from distance. |
| Bomb altitude parameter is visible but dormant | Either revive/smoke the commented `Common_HandleShootBombs.sqf` altitude block or hide/rename the host parameter as historical. | Host/admin UX does not imply an active restriction that the runtime does not enforce. |
| Missing fallback for bomb distance | Add an `Init_CommonConstants.sqf` fallback or use `getVariable` default in the consumer. | Bomb-distance handling works in SP, MP and generated missions. |
| Supply reward stringtable drift | Update `STR_Supplies_2` to match live reward math, or change the reward implementation and stringtable together during supply-authority redesign. | Player help text, runtime load message and completion reward agree for default supply upgrades and upgraded supply-rate cases. |
| Hardcoded live controller text | Add stringtable keys for Buy Units vehicle-help hints and Tactical artillery ammo request status, then replace the literal strings. | English and translated clients see the same help/status intent; tactical ammo request formatting remains readable. |
| IR-smoke parameter/runtime name split | Rename the lobby class to `WFBE_C_MODULE_WFBE_IRSMOKE`, change all runtime consumers to `WFBE_C_MODULE_WFBE_IRS`, or add a small explicit alias immediately after parameter import. | Lobby disabled/enabled values actually change `IRS_Init.sqf` startup and `WFBE_UP_IRSMOKE` upgrade availability. |
| Hidden/forced parameter exposure | Either remove hidden/dead lobby rows or wire them to real runtime behavior. Current examples: hidden `WFBE_C_GAMEPLAY_UPGRADES_CLEARANCE`, forced-off volumetric weather and orphan-looking `WFBE_C_MODULE_BIS_HC`. | Host parameter list, in-game parameter display and runtime variables agree; no operator-facing switch implies behavior that is forced elsewhere. |
| Visible no-op/comment-only parameters | Decide the fate of `WFBE_C_AI_MAX` and `WFBE_C_UNITS_CLEAN_TIMEOUT`: wire `WFBE_C_AI_MAX` to real AI-team sizing or hide/label it historical; either make `WFBE_C_UNITS_CLEAN_TIMEOUT` drive a real non-man/body split, remove/rename it, or keep the body/empty-vehicle split explicit. | Host/admin parameter list does not imply a live AI-group cap or corpse-cleanup setting that maintained source does not consume. |
| Root discovery drift | Keep LoadoutManager's repo-marker root discovery documented and do not reintroduce literal-folder-only assumptions. | LoadoutManager runs from `work\a` and a normal `a2waspwarfare` clone. |
| Missing `7za` during propagation-only work | Use `A2WASP_SKIP_ZIP=1`; require `7za` only for release packaging. | Generated files land even when package creation is skipped. |
| Generated files lack banners | Add generated-file banners to generated SQF/description/version outputs. | Future agents avoid hand-editing generated targets. |
| Lobby/default fallback drift | Either deliberately align the constants fallback values with `Rsc/Parameters.hpp` or document which non-MP fallback differences are intentional. | Compare MP lobby, non-MP boot and generated mission behavior for AI commander, artillery, base area and nuke/radzone timings. |

## Developer Rules

- Do not reorder `class Params` without auditing every `paramsArray` index.
- Do not trust a parameter by label alone. Check the class name imported by `Init_Parameters.sqf`, any constants fallback and any later forced assignment before calling it active.
- Do not hand-edit generated Vanilla mission drift as a substitute for LoadoutManager propagation.
- Treat `version.sqf` as required generated/terrain metadata. Prepared local checkouts may have ignored copies, but clean checkouts, generated targets and modded targets still need explicit verification before pack/test/release claims.
- Keep Arma 2 OA config syntax in mind; do not import Arma 3 `description.ext` assumptions.

## Continue Reading

Previous: [Mission entrypoints and lifecycle](Mission-Entrypoints-And-Lifecycle) | Next: [Tools and build workflow](Tools-And-Build-Workflow)

Main map: [Home](Home) | Release gate: [Source fix propagation queue](Source-Fix-Propagation-Queue) | Machine ledger: [`agent-release-readiness.json`](agent-release-readiness.json)
