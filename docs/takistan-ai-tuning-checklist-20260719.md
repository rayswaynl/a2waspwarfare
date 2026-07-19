# Takistan AI-behaviour tuning checklist (post RC2 rotation)

Context: a2waspwarfare is a VIDEO GAME (Arma 2 OA mission scripting). All AI/combat terms below refer to fictional in-game entities (AI commander logic, town-capture AI, artillery AI). Prepared ahead of the RC2 rotator's Zargabad -> Takistan handoff (`wasp-rc2-rotation-campaign-20260719`) so live tuning can start immediately after the switch instead of re-discovering these levers from scratch.

Source: `Common\Init\Init_CommonConstants.sqf` (identical structure in both the `.zargabad` and `.takistan` mission mirrors; every value below is read live from the Takistan mirror). All of these already carry a live-tuned `worldName == "Takistan"` branch or note, distinct from Zargabad/Chernarus — this is not a fresh design, it's the existing tuned baseline to review against how the live round actually plays.

## Already Takistan-tuned (verify these still feel right on the live round)

| Constant | Takistan value | Elsewhere | Why (from code comments) |
|---|---|---|---|
| `WFBE_C_AICOM_ASSAULT_REACH_FOOT` | 1800m | 2500m | Evidence-based: TK foot teams dispatched >~1800m to mountain towns got stuck on ridgelines (RPT-verified stall pattern, 2026-07-02). Watch for teams still stranding above ~1800m after the switch. |
| `WFBE_C_AICOM_SLOPE_Z` | 0.80 (~37deg) | 0.86 CH | TK inclines are steeper on average; a Chernarus-tuned threshold over-throttled TK convoys to LIMITED speed constantly. |
| `WFBE_C_AICOM_RECOVERY_SLOPE_Z` | 0.80 | 0.85 | Same ridge-grade issue for the foot-waypoint-to-road recovery snap. |
| `WFBE_C_AICOM_RECOVERY_FOOT_ROAD_R` | 300m | 200m | Wider search radius — TK's mountain road net is sparser, needs more room to find a snap target. |
| `WFBE_C_AICOM_ROAD_STANDOFF` | 40m | 24m | Wider so AI base placement stops hugging TK's open highways. |
| `WFBE_C_AICOM_LANE_OFFSET` | 60m | 120m | Halved — TK's narrow switchback valley roads: a 120m sideways lane-jitter guess leaves the road and forces a cross-country beeline over a ridge. |
| `WFBE_C_AICOM_ASSAULT_ROUTE_FACTOR` | 1.5 | 1.35 ZG / 1.25 CH | Route-length inflation factor — TK's mountain routing needs the most slack. |
| `WFBE_C_ICBM_TEL_RANGE` | 8240m | 10350m CH/ZG | Deliberately NOT map-width-proportional — sized to ~64% of TK's width for footprint parity with the other maps' ~67-81%. |
| `WFBE_C_OILFIELD_GUER_RAID` | ON (1) | OFF (0) elsewhere | GUER foot-party raids on paying oilfields default enabled only on Takistan. |
| `WFBE_C_AMBIENT_SKIRMISH_CENTER` / `_RADIUS` | `[6400,6400,0]` / 5600m | ZG `[4000,4000,0]`/3000m, else `[7680,7680,0]`/6200m | Ambient AI-vs-AI skirmish zone sized/centred per map. |
| `WFBE_C_SUPPLY_HELI_TYPES` | `UH60M_EP1` (WEST) / `Mi17_TK_EP1` (EAST) | Chernarus: `MH60S` / `Mi17_Ins` | Faction-appropriate supply helicopters; verify against the live buy lists once on TK. |
| `WFBE_C_ECONOMY_INCOME_COEF` / `_SUPPLY_INCOME_MULT` | 14 / 1.0 (stock) | ZG 42 / 5.0 (3x cash, 5x supply — ZG's small 11-town map needs the boost) | TK/CH run the un-boosted baseline economy; confirm town-driven pacing still feels right after weeks of ZG-boosted play. |

## General AI-commander levers (map-independent, but worth re-baselining on a fresh map)

All in `Init_CommonConstants.sqf`, consumed by `Server\AI\Commander\AI_Commander_*.sqf`:

- `WFBE_C_AI_COMMANDER_ENABLED` / `_LOCK` — master AI-commander switch + human-takeover lock (currently unlocked: players can vote out the AI commander, AI then assists).
- `WFBE_C_TOWNS_ACTIVE_MAX` = 12 — concurrently-active-town budget, the primary server-FPS lever.
- `WFBE_C_AICOM_TEAMS_PC_LOW/MID/HIGH/FULL` (15/7/4/3) + `WFBE_C_AICOM_TEAMS_HARD_CAP` (10) + `WFBE_C_AICOM_TEAMS_DELTA` (-1) / `_FLOOR` (3) — population-scaled HQ team founding target; this whole curve was tuned against Chernarus/Zargabad soak data, worth watching closely on the first live Takistan round for over/under-fielding.
- `WFBE_C_AI_COMMANDER_UPGRADE_INTERVAL` = 300s — tech-tree pacing (~185min for the full ~37-entry research order).
- `WFBE_C_AI_COMMANDER_TEAMS_TARGET` / `_TEAMS_MAX_EXTRA` / `_DEFENSES_MAX` — team-founding cadence and base-defense count, not map-branched today; candidates if TK's terrain makes the current pacing feel off.
- `WFBE_C_GUER_GROUPS_MAX` = 80 — hard ceiling on GUER resistance groups (engine cap is ~144/side).

## GUER-specific levers relevant to Takistan

- `WFBE_C_GUER_FOB_TRUCKS` — terrain-branched: Takistan/Zargabad use `["Ural_TK_CIV_EP1","V3S_Open_TK_CIV_EP1","V3S_TK_EP1"]`; everywhere else uses `["Ural_INS","UralOpen_INS","GAZ_Vodnik"]`. **Cross-reference with the live GUER base-building-truck bug report** (`wasp-guer-mechanics-audit-20260719`) — these are the exact classnames to watch for once the round is on Takistan.
- `WFBE_C_GUER_FOB_BUILD_DIST` / `_BUILD_RANGE` / `_TOWN_BLOCK` — FOB placement distance-from-truck, player-to-truck build range, and no-FOB-near-enemy-town buffer; not map-branched, worth checking against TK's terrain (steeper ground raises `isFlatEmpty` rejection odds — see `WFBE_FNC_GuerFobBlocked` in the same file).
- `WFBE_C_GUER_MORTAR_*` / `_HELIBOMB_*` / `_AIRDEF_*` — GUER call-in and air-defence tuning, not map-branched; the RPT sweep for this cycle showed active GUER air-defence (Ka-137 spawns, flares, swarm rolls) on Zargabad — worth a sanity pass once the same systems run over Takistan's more open terrain (longer sightlines may change how often AA/AT rolls matter).

## Lobby-override precedence — READ BEFORE TUNING LIVE

Per standing project knowledge: `server-pr8.cfg` lobby `class Parameters` `default=` values WIN over any constant set in `Init_CommonConstants.sqf` for whichever params the lobby exposes (`Rsc\Parameters.hpp` in each mission mirror lists which constants are lobby-exposed). Before changing a constant above and expecting it to take effect, check whether that constant has a matching lobby parameter — if so, the lobby default is what actually governs the live server, not the file edit.

## Suggested first-session pass with the owner (no changes made yet)

1. Watch the AICOM founding curve (`TEAMS_PC_*` / `HARD_CAP` / `DELTA`/`FLOOR`) for 15-20 minutes at current population — confirm team counts land in the expected band before touching anything.
2. Watch for foot-team stalls beyond ~1800m (the same RPT signature that drove the `ASSAULT_REACH_FOOT` tune) — if TK still shows stragglers, the threshold or the road-recovery radius may need another pass.
3. Confirm GUER FOB trucks (`Ural_TK_CIV_EP1` / `V3S_Open_TK_CIV_EP1` / `V3S_TK_EP1`) actually spawn in the depot and are buyable — this directly informs the open GUER-truck bug investigation.
4. Sanity-check the economy baseline (14 cash coef / 1.0 supply mult, no ZG-style boost) against how fast AI factions tech up and field armor — TK/CH were never boosted, so this should look like "pre-ZG-boost" pacing, not identical to the last several weeks of Zargabad play.
