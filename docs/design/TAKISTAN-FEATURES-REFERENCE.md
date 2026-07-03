# Takistan Features Reference - 2026-07-03

Read-only reference for the shipped Takistan identity layer on
`origin/claude/build84-cmdcon36` at `873c7f7af2`.

Scope: this page documents current source behavior only. It does not propose new
features, and it does not treat open PRs as shipped. Runtime code still lives in
the Chernarus source tree and is mirrored into the Takistan tree by
LoadoutManager; map-specific behavior is selected by `worldName`,
`IS_chernarus_map_dependent`, and `IS_naval_map`.

## Quick Identity Ledger

| Area | Takistan behavior | Main anchors |
|---|---|---|
| Map defines | `IS_CHERNARUS_MAP_DEPENDENT` and `IS_NAVAL_MAP` are commented out; `WF_MAXPLAYERS` is 61; `STARTING_DISTANCE` is 7500. | `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/version.sqf.template:7-13` |
| Oilfield | Takistan-only neutral resource objective with one-hour unlock, capture income, sabotage/repair, marker state, AICOM pull, and default-off GUER raids. | `Common/Init/Init_CommonConstants.sqf:374-414`, `Server/Init/Init_Server.sqf:1009-1013`, `Server/Server_Oilfields.sqf:74-79` |
| Land ICBM TEL | Land TEL feature is on by default. Each side gets a destroyable `MAZ_543_SCUD_TK_EP1` TEL through the SCUD/ICBM research path; NUKE keeps countdown/counterplay, conventional munitions are range-limited. | `Common/Init/Init_CommonConstants.sqf:974-998`, `Server/Init/Init_IcbmTel.sqf:8-28`, `Server/Init/Init_IcbmTel.sqf:329-406` |
| Producible SCUD | Takistan can buy conventional SCUD launch platforms from Heavy Factory level 3. Bought SCUDs are capped per side and never nuke. | `Common/Init/Init_CommonConstants.sqf:1006-1010`, `Server/Init/Init_IcbmTel.sqf:151-220` |
| AI SCUD use | AI commanders may evaluate and fire SCUDs on a slow tick if the target cluster is persistent, far enough from HQ, and economically allowed. | `Common/Init/Init_CommonConstants.sqf:1016-1025`, `Server/Init/Init_IcbmTel.sqf:417-478` |
| Terrain and range tuning | Takistan gets wider road standoff, narrower lane jitter, lower slope thresholds, wider recovery road search, shorter foot assault reach, and shorter TEL range than Chernarus. | `Common/Init/Init_CommonConstants.sqf:364-368`, `:966-979`, `:1238`, `:1253` |
| TK EASA roster | Takistan-only synthetic EASA loadout roster is on by default. Top-tier rows become airfield-exclusive at Rasman and Loy Manara. | `Common/Init/Init_CommonConstants.sqf:1433`, `Common/Functions/Common_TKEasaRoster.sqf:42-52`, `Common/Init/Init_Common.sqf:426-443` |
| Naval carriers | Takistan is not a naval map. The shared server launch exists, but `Init_NavalHVT.sqf` exits immediately when `IS_naval_map=false`, so Khe Sanh carrier HVTs and carrier SCUD pads are disabled on TK. | `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/version.sqf.template:9`, `Server/Init/Init_Server.sqf:995-997`, `Server/Init/Init_NavalHVT.sqf:27-30` |

## Parameter Ownership

Most Takistan identity switches are constants-only today. `Parameters.hpp` has
related generic rows, but it does not expose the oilfield, Heavy Factory SCUD,
AI SCUD, or AICOM terrain-tuning values as lobby parameters.

| Source | What it owns |
|---|---|
| `Common/Init/Init_CommonConstants.sqf` | Default values for `WFBE_C_OILFIELD_*`, `WFBE_C_TK_SCUD_*`, `WFBE_C_TK_EASA_ROSTER`, and the per-world AICOM/TEL tuning. |
| `Rsc/Parameters.hpp:393` | Generic EASA module row, not the Takistan-only `WFBE_C_TK_EASA_ROSTER` flag. |
| `Rsc/Parameters.hpp:406-412` | Generic carrier/support SCUD cost and cooldown rows; these are not the Heavy Factory bought-SCUD constants. |
| `Rsc/Parameters.hpp:418-424` | Generic land TEL countdown and cooldown rows. The map-specific TEL range and munition costs remain constants-only. |
| Not present in `Parameters.hpp` | `WFBE_C_OILFIELD_*`, `WFBE_C_TK_SCUD_*`, `WFBE_C_AICOM_ROAD_STANDOFF`, `WFBE_C_AICOM_LANE_OFFSET`, `WFBE_C_AICOM_RECOVERY_*`, `WFBE_C_AICOM_ASSAULT_REACH_FOOT`, `WFBE_C_AICOM_SLOPE_Z`, and `WFBE_C_TK_EASA_ROSTER`. |

## Oilfield Defaults

The oilfield constants are defined in
`Common/Init/Init_CommonConstants.sqf:374-414` and launched only for Takistan by
`Server/Init/Init_Server.sqf:1009-1013`. The worker also self-gates on
`toLower worldName == "takistan"` and `WFBE_C_OILFIELD_ENABLE` at
`Server/Server_Oilfields.sqf:74-79`.

| Constant | Default | Gameplay effect |
|---|---:|---|
| `WFBE_C_OILFIELD_ENABLE` | 1 | Master on/off; active only on Takistan. |
| `WFBE_C_OILFIELD_UNLOCK_TIME` | 3600 | Seconds before marker, capture, and income go live. |
| `WFBE_C_OILFIELD_POS` | `[4600, 6200, 0]` | Legacy fallback anchor if dynamic placement is off or fails. |
| `WFBE_C_OILFIELD_ANCHOR_SEARCH` | 1200 | Search radius around the fallback anchor for a real oil/fuel object. |
| `WFBE_C_OILFIELD_RADIUS` | 120 | Capture and hold radius. |
| `WFBE_C_OILFIELD_SCAN_INTERVAL` | 15 | Presence scan cadence, floored in code. |
| `WFBE_C_OILFIELD_INCOME_INTERVAL` | 60 | Seconds between payouts while held and not sabotaged. |
| `WFBE_C_OILFIELD_INCOME_SUPPLY` | 25 | Supply credited per payout. |
| `WFBE_C_OILFIELD_INCOME_CAP` | 15000 | Per-round lifetime supply cap. |
| `WFBE_C_OILFIELD_PREMARK` | 1 | Shows the locked oilfield marker before unlock. |
| `WFBE_C_OILFIELD_PREMARK_UPDATE` | 30 | Countdown marker refresh cadence. |
| `WFBE_C_OILFIELD_PREMARK_COLOR` | `ColorYellow` | Locked marker color. |
| `WFBE_C_OILFIELD_PREMARK_LABEL` | `OILFIELD - opens in %1` | Locked marker label format. |
| `WFBE_C_OILFIELD_PREMARK_T5_MSG` | text | Five-minute warning broadcast. |
| `WFBE_C_OILFIELD_MARKER_LIVE` | 1 | Live marker label shows owner and payout state. |
| `WFBE_C_OILFIELD_SABOTAGE` | 1 | Enables sabotage/repair loop. |
| `WFBE_C_OILFIELD_SABOTAGE_SECS` | 45 | Enemy dwell time to sabotage after clearing holder. |
| `WFBE_C_OILFIELD_REPAIR_SECS` | 40 | Owner dwell time to repair; code can halve this with engineer/repair assets nearby. |
| `WFBE_C_OILFIELD_SMOKE_INTERVAL` | 18 | Burn/smoke refresh cadence while sabotaged. |
| `WFBE_C_OILFIELD_AICOM_PULL` | 1 | Applies a spearhead-weight bonus toward the nearest real town when a side does not hold the field. |
| `WFBE_C_OILFIELD_AICOM_WEIGHT` | 600 | Weight bonus applied by the AICOM pull. |
| `WFBE_C_OILFIELD_GUER_RAID` | 0 | Default-off optional GUER raid spawns while the field is paying. |
| `WFBE_C_OILFIELD_GUER_RAID_INTERVAL` | 1500 | Minimum seconds between optional raids. |
| `WFBE_C_OILFIELD_GUER_RAID_SIZE` | 4 | Raiders per optional raid. |
| `WFBE_C_OILFIELD_GUER_RAID_GRPCAP` | 120 | Resistance group cap guard before spawning optional raids. |
| `WFBE_C_OILFIELD_DYNAMIC` | 1 | Dynamic placement from HQ midpoint and ring search. |
| `WFBE_C_OILFIELD_HQ_WAIT` | 600 | Maximum wait for both starting HQs before fallback. |
| `WFBE_C_OILFIELD_RING_STEP` | 100 | Dynamic placement ring step. |
| `WFBE_C_OILFIELD_RING_MAX` | 2000 | Dynamic placement max search radius. |
| `WFBE_C_OILFIELD_FLAT_Z` | 0.90 | Minimum surface-normal z for placement. |
| `WFBE_C_OILFIELD_ROAD_CLEAR` | 60 | Reject dynamic candidate near a road. |
| `WFBE_C_OILFIELD_TOWN_CLEAR` | 500 | Reject dynamic candidate near a town center. |
| `WFBE_C_OILFIELD_HOUSE_CLEAR` | 80 | Reject dynamic candidate near buildings. |

Runtime notes:

- `Server/Server_Oilfields.sqf:111-164` resolves dynamic placement and fallback.
- `Server/Server_Oilfields.sqf:340-392` handles pre-unlock and live markers.
- `Server/Server_Oilfields.sqf:656-682` owns capture state.
- `Server/Server_Oilfields.sqf:703-729` owns sabotage and repair state.
- `Server/Server_Oilfields.sqf:736-753` pays income and then optionally checks GUER raids.

## Land TEL And SCUD Defaults

The land TEL layer is shared source, but several values are map-specific or
Takistan-only. Constants are in
`Common/Init/Init_CommonConstants.sqf:974-1025`; runtime behavior is in
`Server/Init/Init_IcbmTel.sqf`.

| Constant | Default | Gameplay effect |
|---|---:|---|
| `WFBE_C_ICBM_TEL` | 1 | Enables the land TEL feature. |
| `WFBE_C_ICBM_TEL_COUNTDOWN` | 300 | NUKE countdown; destroying the TEL before T-0 aborts without refund. |
| `WFBE_C_ICBM_TEL_PING_FUZZ` | 400 | Enemy intel ping fuzz during NUKE countdown. |
| `WFBE_C_ICBM_TEL_RESPAWN` | 600 | Research TEL respawn delay after destruction. |
| `WFBE_C_ICBM_TEL_COOLDOWN` | 300 | Shared cooldown for research TEL launches; bought SCUD conventional launches use per-platform clocks. |
| `WFBE_C_ICBM_TEL_RANGE` | TK 8240, CH 10350 | Conventional range cap; NUKE remains unlimited. |
| `WFBE_C_ICBM_TEL_SAT_COST` | 12000 | SATURATION munition cost. |
| `WFBE_C_ICBM_TEL_RECON_COST` | 10000 | RECON FLASH cost. |
| `WFBE_C_ICBM_TEL_RECON_R` | 800 | Recon reveal radius. |
| `WFBE_C_ICBM_TEL_RECON_SECS` | 45 | Recon reveal duration. |
| `WFBE_C_ICBM_TEL_FASCAM_COST` | 14000 | FASCAM mine barrage cost. |
| `WFBE_C_ICBM_TEL_FASCAM_MINES` | 24 | Mines per FASCAM field. |
| `WFBE_C_ICBM_TEL_FASCAM_R` | 150 | Mine scatter radius. |
| `WFBE_C_ICBM_TEL_FASCAM_MINS` | 20 | Minutes before FASCAM cleanup. |
| `WFBE_C_ICBM_TEL_FASCAM_MAX` | 2 | Max live FASCAM fields per side. |
| `WFBE_C_ICBM_TEL_RAIN_COST` | 9000 | STEEL RAIN cost. |
| `WFBE_C_ICBM_TEL_RAIN_BURSTS` | 18 | Airbursts per STEEL RAIN barrage. |
| `WFBE_C_ICBM_TEL_RAIN_R` | 300 | STEEL RAIN spread radius. |
| `WFBE_C_ICBM_TEL_RAIN_BURST_R` | 40 | Per-burst infantry kill radius. |
| `WFBE_C_ICBM_TEL_BUSTER_COST` | 18000 | BUNKER BUSTER cost. |
| `WFBE_C_ICBM_TEL_BUSTER_R` | 30 | Structure-kill radius around impact. |

Takistan bought-SCUD constants:

| Constant | Default | Gameplay effect |
|---|---:|---|
| `WFBE_C_TK_SCUD_HF` | 1 | Enables the Heavy Factory bought-SCUD row on Takistan. Runtime registration exits outside Takistan. |
| `WFBE_C_TK_SCUD_HF_COST` | 28000 | Buy-row price. |
| `WFBE_C_TK_SCUD_HF_LEVEL` | 3 | Required Heavy Factory upgrade level. |
| `WFBE_C_TK_SCUD_HF_MAX` | 2 | Max live bought SCUDs per side; purchase is refused and refunded at cap. |
| `WFBE_C_TK_SCUD_HF_TYPE` | `MAZ_543_SCUD_TK_EP1` | Bought launcher hull. |
| `WFBE_C_TK_SCUD_AI` | 1 | Enables AI SCUD usage on Takistan. |
| `WFBE_C_TK_SCUD_AI_TICK` | 120 | Seconds between AI SCUD evaluations. |
| `WFBE_C_TK_SCUD_AI_INTERVAL` | 600 | Per-side minimum seconds between AI launches. |
| `WFBE_C_TK_SCUD_AI_MIN_CLUSTER` | 8 | Enemy units required in the candidate cluster. |
| `WFBE_C_TK_SCUD_AI_CLUSTER_R` | 300 | Cluster scan radius. |
| `WFBE_C_TK_SCUD_AI_MAX_ANCHORS` | 6 | Max candidate anchors scanned per tick. |
| `WFBE_C_TK_SCUD_AI_HQ_EXCLUSION` | 900 | Hard no-fire ring around enemy HQ. |
| `WFBE_C_TK_SCUD_AI_CONFIRM_R` | 350 | Radius used to confirm the cluster persists across ticks. |
| `WFBE_C_TK_SCUD_AI_BUY` | 1 | Allows rich AI sides to buy one SCUD through the player register path. |
| `WFBE_C_TK_SCUD_AI_BUY_FUNDS` | 60000 | Treasury threshold for AI SCUD buy consideration. |

Runtime notes:

- `Server/Init/Init_IcbmTel.sqf:183-184` gates bought-SCUD registration on `WFBE_C_TK_SCUD_HF` and `worldName == "Takistan"`.
- `Server/Init/Init_IcbmTel.sqf:329-340` keeps NUKE research-TEL-only and lets a bought SCUD waive only the conventional level-1 requirement.
- `Server/Init/Init_IcbmTel.sqf:378-406` applies range and munition costs.
- `Server/Init/Init_IcbmTel.sqf:417-427` uses AI treasury charging for AI fires.
- `Server/Init/Init_IcbmTel.sqf:478-514` logs launch and emits the global 60-second SCUD launch marker for conventional fires.

## AICOM, Terrain, And Range Tuning

Takistan's movement and range constants are not separate features; they are
per-world defaults that make shared systems behave on a steeper, more open, more
sparsely roaded map.

| Constant | Takistan | Chernarus | Why TK differs |
|---|---:|---:|---|
| `WFBE_C_AICOM_ROAD_STANDOFF` | 40 | 24 | Spawn factories and service points sit farther off roads on open TK terrain. |
| `WFBE_C_AICOM_LANE_OFFSET` | 60 | 120 | Narrower valley and switchback roads cannot tolerate the CH-sized sideways lane jitter. |
| `WFBE_C_AICOM_RECOVERY_SLOPE_Z` | 0.80 | 0.85 | Ordinary TK ridges trip the CH threshold too often; lower value snaps only genuinely steep foot nodes. |
| `WFBE_C_AICOM_RECOVERY_FOOT_ROAD_R` | 300 | 200 | Wider road search helps sparse mountain-road recovery find a track. |
| `WFBE_C_AICOM_ASSAULT_REACH_FOOT` | 1800 | 2500 | Foot teams sent beyond about 1800 m on TK mountain towns can grind on ridgelines instead of arriving. |
| `WFBE_C_AICOM_SLOPE_Z` | 0.80 | 0.86 | Prevents convoy gear governor from over-throttling on ordinary TK inclines. |
| `WFBE_C_ICBM_TEL_RANGE` | 8240 | 10350 | Keeps conventional TEL footprint closer to the map's size instead of making TK launches nearly map-spanning. |

Current source note: `WFBE_C_BASE_EGRESS_MAP_BOUNDS` is not part of the
current shipped TK identity on this base. Zargabad pre-sets it to `1` at
`Init_CommonConstants.sqf:96`, while the common fallback remains `0` at
`Init_CommonConstants.sqf:1192`.

## Airfields, EASA, And No Naval Carriers

Takistan airfield identity now has two layers:

| Constant | Default | Gameplay effect |
|---|---:|---|
| `WFBE_C_TK_EASA_ROSTER` | 1 | Enables the Takistan-only synthetic EASA loadout roster. Chernarus always receives an empty catalog regardless of this flag. |

- Generic TK airfield units are selected by the non-Chernarus content branch in
  `Common/Init/Init_Common.sqf:411-424`.
- Rasman and Loy Manara receive the top-tier TK-EASA exclusive roster from
  `Common/Init/Init_Common.sqf:426-443`.

`Common/Functions/Common_TKEasaRoster.sqf` is the roster catalog. It returns an
empty array on Chernarus or when `WFBE_C_TK_EASA_ROSTER` is off
(`Common_TKEasaRoster.sqf:42-52`). The catalog uses synthetic buy tokens that
map to real hulls and proven EASA weapon kits, then offers the top-tier rows
only at captured Takistan airfields.

Takistan also intentionally has no carrier HVT layer:

- TK template leaves `IS_NAVAL_MAP` commented out.
- `initJIPCompatible.sqf:15-17` derives `IS_naval_map`.
- `Init_NavalHVT.sqf:27-30` exits immediately when that variable is false.

That means Chernarus carrier air-shops and carrier SCUD pads do not exist on
Takistan; TK's SCUD identity is the land TEL plus Heavy Factory bought SCUD.

## Current Vs Proposed

This reference treats these as shipped:

- Oilfield objective.
- Land TEL and conventional SCUD munition suite.
- Takistan Heavy Factory bought SCUD.
- AI SCUD evaluator and optional AI buy path.
- TK AICOM terrain/movement constants listed above.
- TK EASA roster and Rasman/Loy Manara exclusives.
- Naval carriers disabled through `IS_naval_map=false`.

This reference does not treat these as shipped unless a later merge changes the
base:

- A Takistan land-HVT replacement for the Chernarus carrier HVT layer.
- Additional Takistan town-mode presets, briefing text updates, or mission.sqm
  airport metadata fixes described in `docs/design/TK-DEEP-PARITY.md`.
- Enabling base-egress map bounds for Takistan on the current base.

## Future Edit Checklist

When changing this area, verify:

- Any `.sqf` edit starts in the Chernarus source tree and is mirrored to
  Takistan/Zargabad with LoadoutManager.
- New lobby-tunable identity values get a `Parameters.hpp` row, or the PR body
  explicitly says they are constants-only.
- New Takistan-only runtime code has a `worldName == "Takistan"` or
  `IS_chernarus_map_dependent`/`IS_naval_map` gate where appropriate.
- Naval HVT changes still exit cleanly on Takistan.
- PR descriptions distinguish shipped features from TK parity proposals.
