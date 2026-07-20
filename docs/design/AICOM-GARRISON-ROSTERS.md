# AICOM and Town-Garrison Rosters

This is a source-grounded reference for the maintained WASP missions. It is documentation only: it does not tune spawn weights or add units.

## How the gates work

`Server_GetTownGroups.sqf` reads the owning side's current **Barracks**, **Light Factory**, and **Heavy Factory** research levels, then asks only for the matching `Team_<B>`, `Team_AT_<B>`, `Motorized_<L>`, `Mechanized_<H>`, and `Armored_<H>` group keys. It therefore cannot select a higher-tier town vehicle merely because that vehicle exists elsewhere in the faction config. Supply value chooses the mix and group count; it does not bypass a factory level. The standard band progression is:

| Town supply value | Eligible roster families | Infantry share | Maximum groups |
| --- | --- | ---: | ---: |
| under 10 | Team, AT team | 100% | 2 |
| 10-19 | Team, MG team, AT team, motorized | 80% | 4 |
| 20-39 | Squad, MG, Team, AT, AA, sniper, motorized, mechanized | 80% | 4 |
| 40-59 | Squad/advanced squad, MG, Team, AT, motorized, light AA, mechanized | 75% | 5 |
| 60-79 | Squad, MG, Team, AA, AT, sniper, motorized, mechanized | 70% | 5 |
| 80-99 | Squad/advanced squad, MG, Team, AT, mechanized, armored | 70% | 6 |
| 100-119 | Squad/advanced squad, MG, Team, AA, AT, sniper, mechanized, armored | 70% | 6 |
| 120+ | Squad/advanced squad, MG, Team, AA, AT, sniper, mechanized, armored | 70% | 7 |

The actual group roster is randomly selected from the side/faction group config. Infantry rosters may be consolidated into larger groups (up to ten classnames); vehicle rosters are deliberately not merged.

**Classification used here:** *lightly armed* means a gun truck, armed car, or wheeled APC/utility hull; *heavy* means tracked IFV/APC, tank, or dedicated heavy AA. This is a review aid, not a new engine classification.

## WEST rosters

### USMC / Chernarus WEST

| Factory level | Infantry unlocked | Light vehicles unlocked | Heavy vehicles unlocked |
| --- | --- | --- | --- |
| 0 | `Squad_0`, `Team_0`, `Team_MG_0`, `Team_AT_0`, `Team_Sniper_0`, `Team_AA` | `Motorized_0`: HMMWV M2 / Mk19 (lightly armed) | `Mechanized_0`: AAV; `Armored_0`: M2A2 (heavy tracked) |
| 1 | `Squad_1`, `Team_1`, `Team_MG_1`, `Team_AT_1`, `Team_Sniper_1` | `Motorized_1`: HMMWV M2 / Mk19 | `Mechanized_1`: M2A2; `Armored_1`: M2A3 |
| 2 | `Squad_2`, `Team_2`, `Team_MG_2`, `Team_AT_2`, `Team_Sniper_2` | `Motorized_2`: CROWS HMMWV M2/Mk19, Jackal GMG (lightly armed) | `Mechanized_2`: M2A2; `Armored_2`: M1A1 (heavy tank) |
| 3 | `Squad_3`, advanced FR squad, `Team_3`, `Team_MG_3`, `Team_AT_3`, `Team_Sniper_3` | `Motorized_3`: Stryker M2/Mk19, HMMWV TOW | `Mechanized_3`: FV510 and M2A3; `Armored_3`: M1A2 TUSK (heavy) |
| 4 | Barracks remains at its level-3 roster | `Motorized_4`: LAV-25, M1135 ATGMV, M1128 MGS (light/wheeled armored) | `Mechanized_4`: FV510/M2A3; `Armored_4`: M1A2 TUSK |

### US / Takistan and Zargabad WEST

The US group-key progression and roles match USMC. Classnames are OA desert variants: `US_*_EP1` infantry, desert HMMWV/Avenger variants, FV510_D and M1A1/M1A2 US desert armor. The only material late difference is `Mechanized_4`, which includes an M1A2 US TUSK alongside FV510_D/M2A3. This is still gated by heavy level 4 rather than a free town-defense exception.

## EAST rosters

### RU / Chernarus EAST

| Factory level | Infantry unlocked | Light vehicles unlocked | Heavy vehicles unlocked |
| --- | --- | --- | --- |
| 0 | `Squad_0`, `Team_0`, `Team_MG_0`, `Team_AT_0`, `Team_Sniper_0`, `Team_AA` | `Motorized_0`: UAZ MG / AGS-30 (lightly armed) | `Mechanized_0`: BMP-2; `Armored_0`: BMP-2/BMP-3 |
| 1 | `Squad_1`, `Team_1`, `Team_MG_1`, `Team_AT_1`, `Team_Sniper_1` | `Motorized_1`: UAZ MG / AGS-30 | `Mechanized_1`: BMP-2; `Armored_1`: BMP-3 |
| 2 | `Squad_2`, `Team_2`, `Team_MG_2`, `Team_AT_2`, `Team_Sniper_2` | `Motorized_2`: Vodnik, BRDM-2 (light/wheeled armored) | `Mechanized_2`: BMP-2; `Armored_2`: T-72 |
| 3 | `Squad_3`, MVD advanced squad, `Team_3`, MVD MG team, `Team_AT_3`, `Team_Sniper_3` | `Motorized_3`: Vodnik HMG, UAZ SPG-9 | `Mechanized_3`: BMP-2/BMP-3; `Armored_3`: T-72/T-90 (heavy) |
| 4 | Barracks remains at its level-3 roster | `Motorized_4`: BRDM-2 ATGM, BTR-90 | `Mechanized_4`: BMP-2/BMP-3; `Armored_4`: T-90 |

`AA_Light` is ZSU; `AA_Heavy` adds Tunguska. Both are selected only by the town supply bands that name AA; they are not a generic vehicle pool.

### TKA / Takistan EAST

| Factory level | Infantry unlocked | Light vehicles unlocked | Heavy vehicles unlocked |
| --- | --- | --- | --- |
| 0 | `Squad_0`, `Team_0`, `Team_MG_0`, `Team_AT_0`, `Team_Sniper_0`, `Team_AA` | `Motorized_0`: UAZ MG / AGS-30 (lightly armed) | `Mechanized_0`: T-34; `Armored_0`: BMP-2/BMP-3 |
| 1 | `Squad_1`, `Team_1`, `Team_MG_1`, `Team_AT_1`, `Team_Sniper_1` | `Motorized_1`: Land Rover MG, UAZ MG/AGS | `Mechanized_1`: T-34/BMP-2; `Armored_1`: BMP-3 |
| 2 | `Squad_2`, `Team_2`, `Team_MG_2`, `Team_AT_2`, `Team_Sniper_2` | `Motorized_2`: BRDM-2 (wheeled armored) | `Mechanized_2`: BMP-2; `Armored_2`: T-72 |
| 3 | `Squad_3`, Special Forces advanced squad, `Team_3`, SF MG team, `Team_AT_3`, `Team_Sniper_3` | `Motorized_3`: BTR-60, BRDM-2, UAZ SPG-9 | `Mechanized_3`: BMP-2/BMP-3; `Armored_3`: T-72/T-90 (heavy) |
| 4 | Barracks remains at its level-3 roster | `Motorized_4`: BTR-90, BRDM-2 ATGM | `Mechanized_4`: BMP-2/BMP-3; `Armored_4`: T-90 |

`AA_Light` is ZSU_TK; `AA_Heavy` adds Tunguska. TKA infantry roles mirror RU but use `TK_*_EP1` and Takistani Special Forces at the higher keys.

## GUER: explicit variety exemption

GUER does **not** use the normal `Team_<level>` / `Motorized_<level>` town planner naming. Its garrison config is a broader faction pool, and its wildcard checkpoint reads the independent `WFBE_GUER_VEHICLE_TIER` progression. That is the intended exception to WEST/EAST factory-level gating.

| GUER pool | Contents | How it differs |
| --- | --- | --- |
| Foot | GUE squad/team/MG/AT/AA/sniper plus PMC contractor and advanced squads | Broader role mix than a single factory level; some group keys have several variants. |
| Light / motorized | DShKM/SPG-9 technicals, Armored SUV, PMC SUV | Can combine vehicle and PMC dismounts in a single `Motorized` roster. |
| Mechanized / armored | BRDM-2, M113 UN, BMP-2, T-72 | Exposed as named GUER groups rather than WEST/EAST numbered factory keys. |
| AA | Ural ZU-23 light/heavy entries | Separate GUER defense options. |

For the **G2 pop-up checkpoint**, the vehicle is kill-tier gated rather than factory gated: tier 0 technical; tier 1 BRDM (30 kills); tier 2 T-55 (80); tier 3 T-72 (160) on Chernarus. On non-Chernarus maps the checkpoint tier-3 fallback remains T-55 because the script's map-specific class choice does so. BMP-2 is a separate global GUER tier-3 unlock, not a checkpoint hull. The M113 VBIED is a separate 50-kill purchase unlock, not a standard garrison vehicle. These checkpoint groups are additional GUER wildcard events, not evidence that WEST or EAST towns can skip factory tiers.

## AICOM team-template roster and mounted bias

`AI_Commander_Teams.sqf` obtains its templates from the faction's `WFBE_<SIDE>AITEAMTEMPLATES` and rejects templates whose required `[Barracks, Light, Heavy, Air]` levels are not met. `AI_Commander_Produce.sqf` also maps normal purchases to Barracks/Light/Heavy and uses the same per-unit unlock check. In short: AICOM uses the faction template catalog, but still requires a live appropriate factory and its research tier.

| Template class | Requirement vector | Examples | Foot or mounted |
| --- | --- | --- | --- |
| Infantry | typically `[B,0,0,0]` | rifle, MG/AT, AA, engineer and sniper squads | Pure foot unless the far-front transport rule adds a troop truck. |
| Light | typically `[0,L,0,0]` | truck squad, HMMWV/UAZ/technical scout or gun team, Avenger/AA team | Mounted/lightly armed; may carry small dismount teams. |
| Heavy | typically `[0,0,H,0]` | Stryker/BTR/BMP/Bradley plus infantry; armor/IFV combined teams | Mounted/heavy; templates with infantry dismounts are preferred. |
| Air | typically `[0,0,0,A]` | transport-heli assault, attack/scout air teams | Air-mounted; transport teams retain or use their air mobility under the active settings. |

The reviewed defaults deliberately push away from pure-foot founding when vehicle buckets exist: `WFBE_C_AICOM_MECH_BIAS = 1.5`, `WFBE_C_AICOM_MOTOR_BIAS = 1.4`, and `WFBE_C_AICOM_DISMOUNT_BIAS = 1.6`. The first two increase heavy/motorized bucket weights; the third increases the weight of a heavy template that also contains infantry dismounts. A pure-foot template at a distant front can have a troop truck prepended when a Light-or-better factory is live. These are the specific levers relevant to the sibling Takistan capture-stall tuning: there are still early pure-foot templates, but they are no longer the only or preferred option once a side can field armed carriers.

## Source map

- Town-defense object placement: `Server/Functions/Server_SpawnTownDefense.sqf` and `Server_ManageTownDefenses.sqf`.
- Standard town roster planner and factory-level key selection: `Server/Functions/Server_GetTownGroups.sqf`.
- Defender/GUER roster path: `Server/Functions/Server_GetTownGroupsDefender.sqf` and `Common/Config/Groups/Groups_GUE.sqf`.
- Conventional faction group definitions: `Common/Config/Groups/Groups_USMC.sqf`, `Groups_US.sqf`, `Groups_RU.sqf`, and `Groups_TKA.sqf`.
- AICOM template and production gates: `Server/AI/Commander/AI_Commander_Teams.sqf`, `AI_Commander_Produce.sqf`, `Common/Config/Core_Squads/Squad_*.sqf`, and `Common/Functions/Common_IsUnitUnlocked.sqf`.
- GUER checkpoint exemption and tier choices: `Server/Functions/AI_Commander_Wildcard_GUER.sqf` and `Common/Init/Init_CommonConstants.sqf`.
