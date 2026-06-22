# Mission Start Parameters Index

This page indexes the multiplayer lobby/start parameters for the maintained Wasp Warfare mission roots. Source of truth is `Rsc/Parameters.hpp` under `class Params`; Arma uses this class order to populate `paramsArray`, and `Common/Init/Init_Parameters.sqf` writes the selected values into `missionNamespace` using the parameter class names.

Current source check on 2026-06-14 at docs checkout `85679dba`: Chernarus `Missions/[55-2hc]warfarev2_073v48co.chernarus/Rsc/Parameters.hpp` and maintained Vanilla Takistan `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Rsc/Parameters.hpp` have identical SHA-256 hashes. The table below has 89 active lobby-visible parameters, with one additional upgrade-clearance class commented out in source.

Related context: [Mission parameters, localization and generated build inputs](Mission-Parameters-Localization-And-Generated-Build-Inputs), [Feature status register](Feature-Status-Register), [Player AI caps and role balance](Player-AI-Caps-And-Role-Balance).

## Reading Notes

- `#` is zero-based source order inside `class Params`; do not reorder this list without auditing `paramsArray` assumptions.
- `Lobby title` preserves the literal `title` field. `$STR_...` values are stringtable keys, while quoted English literals are hardcoded labels.
- `Choices` uses `value=display text` from `values[]` and `texts[]`.
- Defaults are config defaults for the MP lobby. Non-MP fallback constants can differ; see the fallback drift section on [Mission parameters](Mission-Parameters-Localization-And-Generated-Build-Inputs#mp-defaults-versus-constants-fallbacks).

## Category Map

| Range | Area |
| --- | --- |
| `0-6` | Day/night, Air Event, ICBM/radzone, AFK |
| `7-14` | AI delegation, AI/team settings, artillery, AI commander |
| `15-23` | Base, construction, HQ deploy, start location |
| `24-30` | Economy, funds, supply, income interval |
| `31-35` | Environment and DLC/module toggles |
| `36-62` | Gameplay, aircraft, cleanup, tracking, victory, modules |
| `63-70` | Respawn rules |
| `71-81` | Towns, camps, resistance, town gear |
| `82-88` | World cleanup and admin/performance toggles |

## Known Caveats

| Parameter | Caveat |
| --- | --- |
| `WFBE_AIR_EVENT_ENABLED` | Live event-balance override. Value `0` means generated/default event state; value `1` disables; value `2` enables. When enabled, boot forces high economy/start settings and restrictions around ICBM/heavy AA. |
| `WFBE_C_GAMEPLAY_UPGRADES_CLEARANCE` | Not lobby-visible in current maintained roots because the class is commented out at `Parameters.hpp:351-356`; boot/constants can still force or read the variable internally. |
| `WFBE_C_AI_MAX` | Branch-sensitive. Docs/perf/historical release refs still look readless, but current stable `origin/master@0139a346` and current Miksuu `master@d9506078` read it in `AI_Commander_Produce.sqf:89` as an AI commander production cap. Player follower cap is still `WFBE_C_PLAYERS_AI_MAX`. |
| `WFBE_C_UNITS_CLEAN_TIMEOUT` | Branch-sensitive. Docs/perf/historical release refs keep the old split comment-only; current stable `origin/master@0139a346` and current Miksuu `master@d9506078` use it in `Common_TrashObject.sqf:21` for non-man wreck cleanup. Bodies use `WFBE_C_UNITS_BODIES_TIMEOUT`; empty vehicles use `WFBE_C_UNITS_EMPTY_TIMEOUT`. |
| `WFBE_C_GAMEPLAY_BOMBS_ALTITUDE` | Visible, but current altitude enforcement in `Common_HandleShootBombs.sqf` is commented out. |
| `WFBE_C_GAMEPLAY_BOMBS_DISTANCE_RESTRICTION` | Live distance restriction, but its lobby title reuses the bomb altitude string key. |
| `WFBE_C_ENVIRONMENT_WEATHER_VOLUMETRIC` | Visible with only disabled choice and forced off in common/client init paths. |
| `WFBE_C_MODULE_WFBE_IRS` | Lobby class name does not match runtime `WFBE_C_MODULE_WFBE_IRSMOKE` consumers documented on the parameter-flow page. |
| `WFBE_C_MODULE_BIS_HC` | Visible toggle, but treat as owner-review until runtime consumers are reconfirmed. |

## Full Source-Order Index

| # | Source | Parameter | Lobby title | Default | Choices |
| --- | --- | --- | --- | --- | --- |
| 0 | `Parameters.hpp:5` | `WFBE_DAYNIGHT_ENABLED` | `"$STR_WF_PARAMETER_DAYNIGHT_ENABLED"` | `1` | `0="$STR_WF_Disabled"; 1="$STR_WF_Enabled"` |
| 1 | `Parameters.hpp:12` | `WFBE_DAY_DURATION` | `"$STR_WF_PARAMETER_DAY_DURATION"` | `180` | `1="1 minute"; 30="30 minutes"; 40="40 minutes"; 50="50 minutes"; 60="60 minutes"; 90="90 minutes"; 180="180 minutes"` |
| 2 | `Parameters.hpp:20` | `WFBE_NIGHT_DURATION` | `"$STR_WF_PARAMETER_NIGHT_DURATION"` | `30` | `1="1 minute"; 5="5 minutes"; 10="10 minutes"; 15="15 minutes"; 20="20 minutes"; 30="30 minutes"; 60="60 minutes"` |
| 3 | `Parameters.hpp:26` | `WFBE_AIR_EVENT_ENABLED` | `"$STR_WF_PARAMETER_AIR_EVENT_ENABLED"` | `0` | `0="Default (no override)"; 1="Disabled"; 2="Enabled"` |
| 4 | `Parameters.hpp:32` | `WFBE_ICBM_TIME_TO_IMPACT` | `"$STR_WF_PARAMETER_ICBM_IMPACT_TIME"` | `5` | `1="1 minute"; 5="5 minutes"; 10="10 minutes"; 15="15 minutes"; 20="20 minutes"` |
| 5 | `Parameters.hpp:38` | `WFBE_RADZONE_TIME` | `"$STR_WF_PARAMETER_RADZONE_TIME"` | `10` | `1="1 minute"; 5="5 minutes"; 10="10 minutes"; 15="15 minutes"; 20="20 minutes"` |
| 6 | `Parameters.hpp:44` | `WFBE_C_AFK_TIME` | `"$STR_WF_PARAMETER_AFK_Time"` | `15` | `1="1 minute"; 5="5 minutes"; 10="10 minutes"; 15="15 minutes"; 20="20 minutes"; 30="30 minutes"` |
| 7 | `Parameters.hpp:50` | `WFBE_C_AI_DELEGATION` | `"$STR_WF_PARAMETER_AI_Delegation"` | `2` | `0="$STR_WF_Disabled"; 1="$STR_WF_PARAMETER_AI_Delegation_Client"; 2="$STR_WF_PARAMETER_AI_Delegation_HeadlessClient"` |
| 8 | `Parameters.hpp:56` | `WFBE_C_AI_MAX` | `"$STR_WF_PARAMETER_GroupSizeAI"` | `4` | `2="2"; 4="4"; 6="6"; 8="8"; 10="10"; 12="12"; 14="14"; 16="16"; 18="18"; 20="20"; 22="22"; 24="24"; 26="26"; 28="28"; 30="30"; 35="35"; 40="40"; 45="45"; 50="50"; 60="60"; 70="70"; 80="80"; 90="90"; 100="100"` |
| 9 | `Parameters.hpp:62` | `WFBE_C_PLAYERS_AI_MAX` | `"$STR_WF_PARAMETER_GroupSizePlayer"` | `15` | `2="2"; 4="4"; 6="6"; 8="8"; 10="10"; 12="12"; 14="14"; 15="15"; 16="16"` |
| 10 | `Parameters.hpp:68` | `WFBE_C_AI_TEAMS_JIP_PRESERVE` | `"$STR_WF_PARAMETER_KeepAI"` | `0` | `0="$STR_WF_PARAMETER_No"; 1="$STR_WF_PARAMETER_Yes"` |
| 11 | `Parameters.hpp:74` | `WFBE_C_AI_TEAMS_ENABLED` | `"$STR_WF_PARAMETER_AI"` | `0` | `0="$STR_WF_Disabled"; 1="$STR_WF_Enabled"` |
| 12 | `Parameters.hpp:80` | `WFBE_C_ARTILLERY` | `"$STR_WF_PARAMETER_Arty"` | `2` | `0="$STR_WF_Disabled"; 1="$STR_WF_PARAMETER_Long"; 2="$STR_WF_PARAMETER_Medium"; 3="$STR_WF_PARAMETER_Short"` |
| 13 | `Parameters.hpp:86` | `WFBE_C_ARTILLERY_UI` | `"$STR_WF_PARAMETER_ArtilleryUI"` | `0` | `0="$STR_WF_Disabled"; 1="$STR_WF_Enabled"` |
| 14 | `Parameters.hpp:92` | `WFBE_C_AI_COMMANDER_ENABLED` | `"$STR_WF_PARAMETER_AICommander"` | `0` | `0="$STR_WF_PARAMETER_No"; 1="$STR_WF_PARAMETER_Yes"` |
| 15 | `Parameters.hpp:98` | `WFBE_C_STRUCTURES_ANTIAIRRADAR` | `"$STR_WF_PARAMETER_AntiAirRadar"` | `1` | `0="$STR_WF_Disabled"; 1="$STR_WF_Enabled"` |
| 16 | `Parameters.hpp:104` | `WFBE_C_BASE_AREA` | `"$STR_WF_PARAMETER_BaseArea"` | `3` | `0="$STR_WF_Disabled"; 1="1"; 2="2"; 3="3"; 4="4"; 5="5"; 6="6"; 7="7"; 8="8"; 9="9"; 10="10"; 12="12"; 14="14"; 16="16"; 18="18"; 20="20"; 22="22"; 24="24"` |
| 17 | `Parameters.hpp:110` | `WFBE_C_BASE_DEFENSE_MANNING_RANGE` | `"$STR_WF_PARAMETER_AutoDefense_Range"` | `350` | `50="50m"; 100="100m"; 150="150m"; 200="200m"; 250="250m"; 300="300m"; 350="350m"; 400="400m"; 450="450m"; 500="500m"; 600="600m"; 700="700m"; 800="800m"; 900="900m"; 1000="1000m"` |
| 18 | `Parameters.hpp:116` | `WFBE_C_STRUCTURES_MAX` | `"$STR_WF_PARAMETER_BuildingsLimit"` | `2` | `1="1"; 2="2"; 3="3"; 4="4"; 5="5"; 6="6"; 7="7"; 8="8"; 9="9"; 10="10"` |
| 19 | `Parameters.hpp:122` | `WFBE_C_STRUCTURES_CONSTRUCTION_MODE` | `"$STR_WF_PARAMETER_ConstructionMode"` | `0` | `0="$STR_WF_PARAMETER_Time"` |
| 20 | `Parameters.hpp:128` | `WFBE_C_STRUCTURES_HQ_COST_DEPLOY` | `"$STR_WF_PARAMETER_HQDeployCost"` | `500` | `500="S 500"; 600="S 600"; 700="S 700"; 800="S 800"; 900="S 900"; 1000="S 1000"; 1500="S 1500"; 2000="S 2000"; 2500="S 2500"; 3000="S 3000"; 3500="S 3500"; 4000="S 4000"; 5000="S 5000"; 6000="S 6000"; 7000="S 7000"; 8000="S 8000"; 9000="S 9000"; 10000="S 10000"` |
| 21 | `Parameters.hpp:134` | `WFBE_C_STRUCTURES_HQ_RANGE_DEPLOYED` | `"$STR_WF_PARAMETER_HQDeployRange"` | `200` | `50="50m"; 60="60m"; 70="70m"; 80="80m"; 90="90m"; 100="100m"; 110="110m"; 120="120m"; 130="130m"; 140="140m"; 150="150m"; 160="160m"; 170="170m"; 180="180m"; 190="190m"; 200="200m"; 220="220m"; 240="240m"; 260="260m"; 280="280m"; 300="300m"; 320="320m"; 340="340m"; 360="360m"; 380="380m"; 400="400m"` |
| 22 | `Parameters.hpp:140` | `WFBE_C_BASE_START_TOWN` | `"$STR_WF_PARAMETER_SpawnSystemRestrict"` | `1` | `0="$STR_WF_PARAMETER_No"; 1="$STR_WF_PARAMETER_Yes"` |
| 23 | `Parameters.hpp:146` | `WFBE_C_BASE_STARTING_MODE` | `"$STR_WF_PARAMETER_StartingLocations"` | `2` | `0="$STR_WF_PARAMETER_StartingLocations_WestNorth"; 1="$STR_WF_PARAMETER_StartingLocations_WestSouth"; 2="$STR_WF_PARAMETER_StartingLocations_Random"` |
| 24 | `Parameters.hpp:152` | `WFBE_C_ECONOMY_CURRENCY_SYSTEM` | `"$STR_WF_PARAMETER_Currency"` | `0` | `0="$STR_WF_PARAMETER_Money_Supply"; 1="$STR_WF_PARAMETER_Money"` |
| 25 | `Parameters.hpp:158` | `WFBE_C_ECONOMY_INCOME_INTERVAL` | `"$STR_WF_PARAMETER_IncomeInterval"` | `60` | `60="1 Minute"; 75="1 Minute 15 Seconds"; 90="1 Minute 30 Seconds"; 105="1 Minute 45 Seconds"; 120="2 Minutes"; 150="2 Minutes 30 Seconds"; 180="3 Minutes"; 240="4 Minutes"; 300="5 Minutes"; 360="6 Minutes"; 420="7 Minutes"; 480="8 Minutes"; 540="9 Minutes"; 600="10 Minutes"` |
| 26 | `Parameters.hpp:164` | `WFBE_C_ECONOMY_FUNDS_START_EAST` | `"$STR_WF_PARAMETER_Funds_East"` | `25600` | `800="$ 800"; 1600="$ 1600"; 2400="$ 2400"; 3200="$ 3200"; 4000="$ 4000"; 4800="$ 4800"; 6400="$ 6400"; 8000="$ 8000"; 12800="$ 12800"; 25600="$ 25600"; 51200="$ 51200"; 102400="$ 102400"; 204800="$ 204800"; 409600="$ 409600"; 819200="$ 819200"` |
| 27 | `Parameters.hpp:170` | `WFBE_C_ECONOMY_FUNDS_START_WEST` | `"$STR_WF_PARAMETER_Funds_West"` | `25600` | `800="$ 800"; 1600="$ 1600"; 2400="$ 2400"; 3200="$ 3200"; 4000="$ 4000"; 4800="$ 4800"; 6400="$ 6400"; 8000="$ 8000"; 12800="$ 12800"; 25600="$ 25600"; 51200="$ 51200"; 102400="$ 102400"; 204800="$ 204800"; 409600="$ 409600"; 819200="$ 819200"` |
| 28 | `Parameters.hpp:176` | `WFBE_C_ECONOMY_SUPPLY_START_EAST` | `"$STR_WF_PARAMETER_Supply_East"` | `9600` | `1200="S 1200"; 2400="S 2400"; 3600="S 3600"; 4800="S 4800"; 6000="S 6000"; 7200="S 7200"; 8400="S 8400"; 9600="S 9600"; 12800="S 12800"; 16000="S 16000"; 19200="S 19200"; 38400="S 38400"; 76800="S 76800"` |
| 29 | `Parameters.hpp:182` | `WFBE_C_ECONOMY_SUPPLY_START_WEST` | `"$STR_WF_PARAMETER_Supply_West"` | `9600` | `1200="S 1200"; 2400="S 2400"; 3600="S 3600"; 4800="S 4800"; 6000="S 6000"; 7200="S 7200"; 8400="S 8400"; 9600="S 9600"; 12800="S 12800"; 16000="S 16000"; 19200="S 19200"; 38400="S 38400"; 76800="S 76800"` |
| 30 | `Parameters.hpp:189` | `WFBE_C_MAX_ECONOMY_SUPPLY_LIMIT` | `"$STR_WF_PARAMETER_Max_Supply_Limit"` | `50000` | `30000="S 30000"; 35000="S 35000"; 40000="S 40000"; 45000="S 45000"; 50000="S 50000"; 60000="S 60000"; 80000="S 80000"; 100000="S 100000"` |
| 31 | `Parameters.hpp:196` | `WFBE_C_ENVIRONMENT_STARTING_HOUR` | `"$STR_WF_PARAMETER_Hour"` | `9` | `0="00:00"; 1="01:00"; 2="02:00"; 3="03:00"; 4="04:00"; 5="05:00"; 6="06:00"; 7="07:00"; 8="08:00"; 9="09:00"; 10="10:00"; 11="11:00"; 12="12:00"; 13="13:00"; 14="14:00"; 15="15:00"; 16="16:00"; 17="17:00"; 18="18:00"; 19="19:00"; 20="20:00"; 21="21:00"; 22="22:00"; 23="23:00"` |
| 32 | `Parameters.hpp:203` | `WFBE_C_ENVIRONMENT_STARTING_MONTH` | `"$STR_WF_PARAMETER_Month"` | `6` | `1="January"; 2="February"; 3="March"; 4="April"; 5="May"; 6="June"; 7="July"; 8="August"; 9="September"; 10="October"; 11="November"; 12="December"` |
| 33 | `Parameters.hpp:210` | `WFBE_C_ENVIRONMENT_WEATHER_VOLUMETRIC` | `"$STR_WF_PARAMETER_Clouds"` | `0` | `0="$STR_WF_Disabled"` |
| 34 | `Parameters.hpp:216` | `WFBE_C_ENVIRONMENT_WEATHER` | `"$STR_WF_PARAMETER_Weather"` | `0` | `0="$STR_WF_PARAMETER_Weather_Clear"; 1="$STR_WF_PARAMETER_Weather_Cloudy"; 2="$STR_WF_PARAMETER_Weather_Rainy"` |
| 35 | `Parameters.hpp:223` | `WFBE_C_MODULE_BIS_PMC` | `"$STR_WF_PARAMETER_PMC"` | `1` | `0="$STR_WF_Disabled"; 1="$STR_WF_Enabled"` |
| 36 | `Parameters.hpp:230` | `WFBE_C_GAMEPLAY_AIR_AA_MISSILES` | `"$STR_WF_PARAMETER_AirAA"` | `2` | `0="$STR_WF_Disabled"; 1="$STR_WF_PARAMETER_Enabled_Upgrade"; 2="$STR_WF_Enabled"` |
| 37 | `Parameters.hpp:236` | `WFBE_C_GAMEPLAY_HANGARS_ENABLED` | `"$STR_WF_PARAMETER_Hangars"` | `1` | `0="$STR_WF_Disabled"; 1="$STR_WF_Enabled"` |
| 38 | `Parameters.hpp:242` | `WFBE_C_UNITS_CLEAN_TIMEOUT` | `"$STR_WF_PARAMETER_BodiesTimeout"` | `240` | `60="1 Minute"; 120="2 Minutes"; 180="3 Minutes"; 240="4 Minutes"; 300="5 Minutes"; 600="10 Minutes"; 900="15 Minutes"; 1200="20 Minutes"; 1800="30 Minutes"; 2400="40 Minutes"; 3000="50 Minutes"; 3600="1 Hour"` |
| 39 | `Parameters.hpp:248` | `WFBE_C_UNITS_EMPTY_TIMEOUT` | `"$STR_WF_PARAMETER_VehicleDelay"` | `600` | `60="1 Minute"; 120="2 Minutes"; 180="3 Minutes"; 240="4 Minutes"; 300="5 Minutes"; 600="10 Minutes"; 900="15 Minutes"; 1200="20 Minutes"; 1800="30 Minutes"; 2400="40 Minutes"; 3000="50 Minutes"; 3600="1 Hour"` |
| 40 | `Parameters.hpp:254` | `WFBE_C_GAMEPLAY_FAST_TRAVEL` | `"$STR_WF_PARAMETER_FastTravel"` | `0` | `0="$STR_WF_Disabled"; 1="$STR_WF_PARAMETER_Free"; 2="$STR_WF_PARAMETER_Fee"` |
| 41 | `Parameters.hpp:260` | `WFBE_C_GAMEPLAY_HANDLE_FRIENDLYFIRE` | `"$STR_WF_PARAMETER_FriendlyFire"` | `1` | `0="$STR_WF_Disabled"; 1="$STR_WF_Enabled"` |
| 42 | `Parameters.hpp:266` | `WFBE_C_ENVIRONMENT_MAX_CLUTTER` | `"$STR_WF_PARAMETER_Grass"` | `50` | `10="Far"; 20="Medium"; 30="Short"; 50="Toggleable"` |
| 43 | `Parameters.hpp:272` | `WFBE_C_GAMEPLAY_TEAMSWAP_DISABLE` | `"$STR_WF_PARAMETER_KickTeamswapper"` | `1` | `0="$STR_WF_Disabled"; 1="$STR_WF_Enabled"` |
| 44 | `Parameters.hpp:278` | `WFBE_C_GAMEPLAY_BOUNDARIES_ENABLED` | `"$STR_WF_PARAMETER_LimitedBoundaries"` | `1` | `0="$STR_WF_Disabled"; 1="$STR_WF_Enabled"` |
| 45 | `Parameters.hpp:284` | `WFBE_C_GAMEPLAY_BOMBS_ALTITUDE` | `"$STR_WF_PARAMETER_BombAltitude"` | `2000` | `0="$STR_WF_Disabled"; 500="500m"; 1000="1000m"; 1500="1500m"; 2000="2000m"; 2500="2500m"; 3000="3000m"; 3500="3500m"; 4000="4000m"; 4500="4500m"; 5000="5000m"; 5500="5500m"; 6000="6000m"; 6500="6500m"; 7000="7000m"; 7500="7500m"; 8000="8000m"; 8500="8500m"; 9000="9000m"; 9500="9500m"; 10000="10000m"` |
| 46 | `Parameters.hpp:290` | `WFBE_C_GAMEPLAY_BOMBS_DISTANCE_RESTRICTION` | `"$STR_WF_PARAMETER_BombAltitude"` | `2000` | `0="$STR_WF_Disabled"; 500="500m"; 1000="1000m"; 1500="1500m"; 2000="2000m"; 2500="2500m"; 3000="3000m"; 3500="3500m"; 4000="4000m"; 4500="4500m"; 5000="5000m"; 5500="5500m"; 6000="6000m"; 6500="6500m"; 7000="7000m"; 7500="7500m"; 8000="8000m"; 8500="8500m"; 9000="9000m"; 9500="9500m"; 10000="10000m"` |
| 47 | `Parameters.hpp:296` | `WFBE_C_GAMEPLAY_MISSILES_RANGE` | `"$STR_WF_PARAMETER_MissileRange"` | `3000` | `0="$STR_WF_Disabled"; 500="500m"; 1000="1000m"; 1500="1500m"; 2000="2000m"; 2500="2500m"; 3000="3000m"; 3500="3500m"; 4000="4000m"; 4500="4500m"; 5000="5000m"; 5500="5500m"; 6000="6000m"; 6500="6500m"; 7000="7000m"; 7500="7500m"; 8000="8000m"; 8500="8500m"; 9000="9000m"; 9500="9500m"; 10000="10000m"` |
| 48 | `Parameters.hpp:302` | `WFBE_C_GAMEPLAY_UID_SHOW` | `"$STR_WF_PARAMETER_ShowUID"` | `1` | `0="$STR_WF_Disabled"; 1="$STR_WF_Enabled"` |
| 49 | `Parameters.hpp:308` | `WFBE_C_UNITS_PRICING` | `"$STR_WF_PARAMETER_Specialization"` | `0` | `0="$STR_WF_PARAMETER_None"; 1="$STR_WF_PARAMETER_Infantry"; 2="$STR_WF_PARAMETER_LandVehicles"; 3="$STR_WF_PARAMETER_Aircraft"` |
| 50 | `Parameters.hpp:314` | `WFBE_C_GAMEPLAY_THERMAL_IMAGING` | `"$STR_WF_PARAMETER_ThermalImaging"` | `3` | `0="$STR_WF_Disabled"; 1="$STR_WF_PARAMETER_Weapons"; 2="$STR_WF_PARAMETER_Vehicles"; 3="$STR_WF_Enabled"` |
| 51 | `Parameters.hpp:320` | `WFBE_C_UNITS_TRACK_INFANTRY` | `"$STR_WF_PARAMETER_TrackAI"` | `0` | `0="$STR_WF_Disabled"; 1="$STR_WF_Enabled"` |
| 52 | `Parameters.hpp:326` | `WFBE_C_UNITS_TRACK_LEADERS` | `"$STR_WF_PARAMETER_TrackPlayers"` | `1` | `0="$STR_WF_Disabled"; 1="$STR_WF_Enabled"` |
| 53 | `Parameters.hpp:333` | `WFBE_C_MAP_ICON_BLINKING_ENABLED` | `"$STR_WF_PARAMETER_MapIconBlinking"` | `0` | `0="$STR_WF_Disabled"; 1="$STR_WF_Enabled"` |
| 54 | `Parameters.hpp:339` | `WFBE_C_UNITS_BALANCING` | `"$STR_WF_PARAMETER_Balance"` | `1` | `0="$STR_WF_Disabled"; 1="$STR_WF_Enabled"` |
| 55 | `Parameters.hpp:345` | `WFBE_C_UNITS_BOUNTY` | `"$STR_WF_PARAMETER_UnitsBounty"` | `1` | `0="$STR_WF_Disabled"; 1="$STR_WF_Enabled"` |
| 56 | `Parameters.hpp:357` | `WFBE_C_GAMEPLAY_VICTORY_CONDITION` | `"$STR_WF_PARAMETER_VictoryCondition"` | `2` | `0="$STR_WF_PARAMETER_Victory_Annihilation"; 1="$STR_WF_PARAMETER_Victory_Assassination"; 2="$STR_WF_PARAMETER_Victory_Supremacy"; 3="$STR_WF_PARAMETER_Victory_Towns"` |
| 57 | `Parameters.hpp:363` | `WFBE_C_ENVIRONMENT_MAX_VIEW` | `"$STR_WF_PARAMETER_ViewDistance"` | `6000` | `200="200m"; 500="500m"; 800="800m"; 1000="1000m"; 1500="1500m"; 2000="2000m"; 2500="2500m"; 3000="3000m"; 3500="3500m"; 4000="4000m"; 4500="4500m"; 5000="5000m"; 6000="6000m"` |
| 58 | `Parameters.hpp:369` | `WFBE_C_MODULE_WFBE_FLARES` | `"$STR_WF_PARAMETER_Countermeasures"` | `2` | `0="$STR_WF_Disabled"; 1="$STR_WF_PARAMETER_Enabled_Upgrade"; 2="$STR_WF_Enabled"` |
| 59 | `Parameters.hpp:375` | `WFBE_C_MODULE_WFBE_EASA` | `"$STR_WF_PARAMETER_EASA"` | `1` | `0="$STR_WF_Disabled"; 1="$STR_WF_Enabled"` |
| 60 | `Parameters.hpp:381` | `WFBE_C_MODULE_BIS_HC` | `"$STR_WF_PARAMETER_HighCommand"` | `0` | `0="$STR_WF_Disabled"; 1="$STR_WF_Enabled"` |
| 61 | `Parameters.hpp:387` | `WFBE_C_MODULE_WFBE_ICBM` | `"$STR_WF_PARAMETER_ICBM"` | `1` | `0="$STR_WF_Disabled"; 1="$STR_WF_Enabled"` |
| 62 | `Parameters.hpp:393` | `WFBE_C_MODULE_WFBE_IRS` | `"$STR_WF_PARAMETER_IRS"` | `1` | `0="$STR_WF_Disabled"; 1="$STR_WF_Enabled"` |
| 63 | `Parameters.hpp:399` | `WFBE_C_RESPAWN_CAMPS_MODE` | `"$STR_WF_PARAMETER_Camp"` | `1` | `0="$STR_WF_Disabled"; 1="$STR_WF_PARAMETER_Classic"; 2="$STR_WF_PARAMETER_Respawn_CampsNearby"; 3="$STR_WF_PARAMETER_Respawn_Defender"` |
| 64 | `Parameters.hpp:405` | `WFBE_C_RESPAWN_CAMPS_RULE_MODE` | `"$STR_WF_PARAMETER_CampRespawnRule"` | `1` | `0="$STR_WF_Disabled"; 1="$STR_WF_PARAMETER_Respawn_CampsRule_WestEast"; 2="$STR_WF_PARAMETER_Respawn_CampsRule_WestEastRes"` |
| 65 | `Parameters.hpp:411` | `WFBE_C_RESPAWN_DELAY` | `"$STR_WF_PARAMETER_Respawn"` | `30` | `10="10 Seconds"; 15="15 Seconds"; 20="20 Seconds"; 25="25 Seconds"; 30="30 Seconds"; 35="35 Seconds"; 40="40 Seconds"; 45="45 Seconds"; 50="50 Seconds"; 55="55 Seconds"; 60="60 Seconds"; 65="65 Seconds"; 70="70 Seconds"; 75="75 Seconds"; 80="80 Seconds"; 85="85 Seconds"; 90="90 Seconds"` |
| 66 | `Parameters.hpp:418` | `WFBE_C_RESPAWN_LEADER` | `"$STR_WF_PARAMETER_LeaderRespawn"` | `0` | `0="$STR_WF_Disabled"; 1="$STR_WF_Enabled"; 2="$STR_WF_Enabled_DefaultGear"` |
| 67 | `Parameters.hpp:424` | `WFBE_C_RESPAWN_MASH` | `"$STR_WF_PARAMETER_Respawn_MASH"` | `1` | `0="$STR_WF_Disabled"; 1="$STR_WF_Enabled"; 2="$STR_WF_Enabled_DefaultGear"` |
| 68 | `Parameters.hpp:430` | `WFBE_C_RESPAWN_MOBILE` | `"$STR_WF_PARAMETER_MobileRespawn"` | `1` | `0="$STR_WF_Disabled"; 1="$STR_WF_Enabled"; 2="$STR_WF_Enabled_DefaultGear"` |
| 69 | `Parameters.hpp:436` | `WFBE_C_RESPAWN_PENALTY` | `"$STR_WF_PARAMETER_Respawn_Penalty"` | `0` | `0="$STR_WF_Disabled"; 1="$STR_WF_PARAMETER_Respawn_Penalty_Remove"; 2="$STR_WF_PARAMETER_Respawn_Penalty_Full"; 3="$STR_WF_PARAMETER_Respawn_Penalty_OneHalf"; 4="$STR_WF_PARAMETER_Respawn_Penalty_OneFourth"; 5="$STR_WF_PARAMETER_Respawn_Penalty_Mobile"` |
| 70 | `Parameters.hpp:442` | `WFBE_C_RESPAWN_CAMPS_RANGE` | `"$STR_WF_PARAMETER_TownRespawnRange"` | `400` | `50="50m"; 100="100m"; 150="150m"; 200="200m"; 250="250m"; 300="300m"; 350="350m"; 400="400m"; 450="450m"; 500="500m"; 550="550m"; 600="600m"; 650="650m"; 700="700m"; 750="750m"; 800="800m"; 850="850m"; 900="900m"; 950="950m"; 1000="1000m"; 1500="1500m"; 2000="2000m"; 2500="2500m"; 3000="3000m"; 3500="3500m"; 4000="4000m"` |
| 71 | `Parameters.hpp:448` | `WFBE_C_TOWNS_AMOUNT` | `"$STR_WF_PARAMETER_TownsAmount"` | `4` | `0="$STR_WF_PARAMETER_Extra_Small"; 1="$STR_WF_PARAMETER_Small"; 2="$STR_WF_PARAMETER_Medium"; 3="$STR_WF_PARAMETER_Large"; 4="$STR_WF_PARAMETER_Full"; 5="$STR_WF_PARAMETER_RemovedBigTowns"; 6="$STR_WF_PARAMETER_RemovedCentralLine"; 7="$STR_WF_PARAMETER_RemovedSmallTowns"` |
| 72 | `Parameters.hpp:454` | `WFBE_C_CAMPS_CREATE` | `"$STR_WF_PARAMETER_TownsCamps"` | `1` | `0="$STR_WF_Disabled"; 1="$STR_WF_Enabled"` |
| 73 | `Parameters.hpp:460` | `WFBE_C_TOWNS_CAPTURE_MODE` | `"$STR_WF_PARAMETER_TownsCaptureMode"` | `2` | `0="$STR_WF_PARAMETER_Classic"; 1="$STR_WF_PARAMETER_TownsCaptureMode_Threshold"; 2="$STR_WF_PARAMETER_TownsCaptureMode_AllCamps"` |
| 74 | `Parameters.hpp:466` | `WFBE_C_TOWNS_DEFENDER` | `"$STR_WF_PARAMETER_Defender"` | `2` | `0="$STR_WF_Disabled"; 1="$STR_WF_PARAMETER_Light"; 2="$STR_WF_PARAMETER_Medium"; 3="$STR_WF_PARAMETER_Hard"; 4="$STR_WF_PARAMETER_Impossible"` |
| 75 | `Parameters.hpp:472` | `WFBE_C_TOWNS_GEAR` | `"$STR_WF_PARAMETER_TownsGear"` | `1` | `0="$STR_WF_Disabled"; 1="$STR_WF_PARAMETER_CampSel"; 2="$STR_WF_PARAMETER_Depot"; 3="$STR_WF_PARAMETER_CampnDepot"` |
| 76 | `Parameters.hpp:478` | `WFBE_C_TOWNS_OCCUPATION` | `"$STR_WF_PARAMETER_Occupation"` | `1` | `0="$STR_WF_Disabled"; 1="$STR_WF_PARAMETER_Light"; 2="$STR_WF_PARAMETER_Medium"; 3="$STR_WF_PARAMETER_Hard"; 4="$STR_WF_PARAMETER_Impossible"` |
| 77 | `Parameters.hpp:484` | `WFBE_C_TOWNS_PATROLS` | `"$STR_WF_PARAMETER_MaxResPatrols"` | `0` | `0="$STR_WF_Disabled"; 1="1"; 2="2"; 3="3"; 4="4"; 5="5"; 6="6"; 7="7"; 8="8"; 9="9"; 10="10"; 11="11"; 12="12"; 13="13"; 14="14"; 15="15"; 16="16"; 17="17"; 18="18"; 19="19"; 20="20"; 22="22"; 24="24"; 26="26"; 28="28"; 30="30"; 32="32"; 34="34"; 36="36"; 38="38"; 40="40"; 50="50"; 60="60"; 70="70"; 80="80"; 90="90"; 100="100"` |
| 78 | `Parameters.hpp:490` | `WFBE_C_TOWNS_BUILD_PROTECTION_RANGE` | `"$STR_WF_PARAMETER_TownProtectionRange"` | `100` | `0="0m"; 50="50m"; 100="100m"; 150="150m"; 200="200m"; 250="250m"; 300="300m"; 350="350m"; 400="400m"; 450="450m"; 500="500m"` |
| 79 | `Parameters.hpp:496` | `WFBE_C_UNITS_TOWN_PURCHASE` | `"$STR_WF_PARAMETER_TownsPurchaseMilita"` | `1` | `0="$STR_WF_Disabled"; 1="$STR_WF_Enabled"` |
| 80 | `Parameters.hpp:502` | `WFBE_C_TOWNS_VEHICLES_LOCK_DEFENDER` | `"$STR_WF_PARAMETER_Resistance_VehLock"` | `0` | `0="$STR_WF_Disabled"; 1="$STR_WF_Enabled"` |
| 81 | `Parameters.hpp:508` | `WFBE_C_TOWNS_STARTING_MODE` | `"$STR_WF_PARAMETER_StartingMode"` | `0` | `0="$STR_WF_PARAMETER_None"; 1="$STR_WF_PARAMETER_Divided_Towns"; 2="$STR_WF_PARAMETER_Nearby_Town"; 3="$STR_WF_PARAMETER_StartingLocations_Random"` |
| 82 | `Parameters.hpp:515` | `WFBE_C_BUILDING_RESTORER_TIME_PERIOD` | `"$STR_WF_PARAMETER_BuildingRestorerInterval"` | `1800` | `1800="30 Minutes"; 3600="1 Hour"; 5400="90 Minutes"; 7200="2 Hours"` |
| 83 | `Parameters.hpp:521` | `WFBE_C_CRATER_CLEANER_TIME_PERIOD` | `"$STR_WF_PARAMETER_CraterCleanerInterval"` | `1800` | `1800="30 Minutes"; 3600="1 Hour"; 5400="90 Minutes"; 7200="2 Hours"` |
| 84 | `Parameters.hpp:527` | `WFBE_C_DROPPEDITEMS_CLEANER_TIME_PERIOD` | `"$STR_WF_PARAMETER_DroppedItemsCleanerInterval"` | `120` | `60="1 Minute"; 75="1 Minute 15 Seconds"; 90="1 Minute 30 Seconds"; 105="1 Minute 45 Seconds"; 120="2 Minutes"; 150="2 Minutes 30 Seconds"; 180="3 Minutes"; 240="4 Minutes"; 300="5 Minutes"; 360="6 Minutes"; 420="7 Minutes"; 480="8 Minutes"; 540="9 Minutes"; 600="10 Minutes"` |
| 85 | `Parameters.hpp:533` | `WFBE_C_MINEFIELDS_CLEANER_TIME_PERIOD` | `"$STR_WF_PARAMETER_MinefieldCleanerInterval"` | `5400` | `1800="30 Minutes"; 3600="1 Hour"; 5400="90 Minutes"; 7200="2 Hours"` |
| 86 | `Parameters.hpp:539` | `WFBE_C_RUINS_CLEANER_TIME_PERIOD` | `"$STR_WF_PARAMETER_RuinsCleanerInterval"` | `1800` | `1800="30 Minutes"; 3600="1 Hour"; 5400="90 Minutes"; 7200="2 Hours"` |
| 87 | `Parameters.hpp:547` | `WFBE_C_ANTISTACK_ENABLED` | `"AntiStack"` | `1` | `0="$STR_WF_Disabled"; 1="$STR_WF_Enabled"` |
| 88 | `Parameters.hpp:554` | `WFBE_C_PERFORMANCE_AUDIT_ENABLED` | `"Performance audit"` | `1` | `0="$STR_WF_Disabled"; 1="$STR_WF_Enabled"` |

## Continue Reading

Previous: [Mission parameters, localization and generated build inputs](Mission-Parameters-Localization-And-Generated-Build-Inputs) | Next: [Player AI caps and role balance](Player-AI-Caps-And-Role-Balance)
