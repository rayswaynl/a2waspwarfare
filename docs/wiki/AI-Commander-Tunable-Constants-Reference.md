# AI Commander Tunable Constants Reference (WFBE_C_AI_COMMANDER_* / WFBE_C_AICOM_*)

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

Every AI-commander tunable lives in one contiguous block of `Common/Init/Init_CommonConstants.sqf` under the `//--- AI.` heading (with three late-defined stuck/assault/slope constants under `//--- Camps.`). This page tabulates each constant by its exact source line, default value, and one-line role. It is a config catalog, not a behavior audit — for what is/isn't actually wired into the supervisor, see [AI Commander Autonomy Audit](AI-Commander-Autonomy-Audit).

Two naming conventions coexist: the older `WFBE_C_AI_COMMANDER_*` (V0.x revival series) and the newer short `WFBE_C_AICOM_*` (B36/B37/V0.7+ tuning). Constants defined with `if (isNil "X") then {X = ...}` are param/override-overridable; bare `X = ...` assignments are forced (cannot be changed by a lobby param). None of the AI-commander constants carry a `WF_Debug` branch — `START_FUNDS` is a flat 200000 regardless of debug mode.

## Master switches and locks

| Constant | Default | Line | Override? | Meaning |
|---|---|---|---|---|
| `WFBE_C_AI_COMMANDER_ENABLED` | `1` | 103 | yes | Enable or disable the AI commanders. |
| `WFBE_C_AI_COMMANDER_LOCK` | `1` | 106 | yes | When 1, AI retains full command regardless of who occupies the slot (protects eval/night sessions from accidental human takeover). Comment notes "Default 0 = normal play" but the live value is 1. |
| `WFBE_C_AI_COMMANDER_ARTILLERY` | `0` | 165 | no (forced) | Steff 2026-06-13: the AI must NOT use artillery. Forced off so no param can enable it — blocks both the fire-mission worker AND building base guns. |
| `WFBE_C_AI_COMMANDER_LOG` | `1` | 167 | no | V0.4: always-on `[AICOM]` diag_log (independent of `WF_LOG_CONTENT`; 0 to silence). |
| `WFBE_C_AI_COMMANDER_USE_ARC_APPROACH` | `1` | 121 | no | 1: SetTownAttackPath arc approach; 0: simple AIMoveTo fallback. |

## Difficulty and economy (the LEVEL switch)

`WFBE_C_AI_COMMANDER_LEVEL` (line 170, default 1) drives a `switch` (lines 171-175) that sets three synthetic-money multipliers. Supply stays real on every level; only the synthetic FUNDS are tuned (Init_CommonConstants.sqf:168-169).

| Constant | Line | Easy (LEVEL 0) | Normal (LEVEL 1, default) | Hard (LEVEL 2) |
|---|---|---|---|---|
| `WFBE_C_AI_COMMANDER_LEVEL` | 170 | 0 | 1 (default) | 2 |
| `WFBE_C_AI_COMMANDER_FUNDS_MULT` | 172 / 174 / 173 | `1.0` | `1.5` | `2.0` |
| `WFBE_C_AI_COMMANDER_INCOME_MULT` | 172 / 174 / 173 | `1.0` | `1.5` | `2.0` |
| `WFBE_C_AI_COMMANDER_INCOME_STIPEND` | 172 / 174 / 173 | `0` | `2000` | `3000` |

The Normal branch is the `default` case at line 174: base commander UBI = $2000/min CASH (the 60s income tick means per-tick == per-min). It is an unconditional per-tick AI-commander funds drip that keeps the AI fielding armies on a near-empty server.

| Constant | Default | Line | Override? | Meaning |
|---|---|---|---|---|
| `WFBE_C_AI_COMMANDER_START_FUNDS` | `200000` | 311 | yes | B36 hotfix (Ray 2026-06-15): AI commander starts with a flat 200k cash (was `FUNDS_START × FUNDS_MULT ≈ 45k`); it runs the whole side. Players start with 30k. Defined in the `//--- Economy.` block, not the `//--- AI.` block. |
| `WFBE_C_AICOM_INCOME_MULT_MAX` | `3.0` | 150 | no | Hard ceiling on the scaled commander income multiplier (packed-server runaway guard). |

## Worker cadences and unit caps

| Constant | Default | Line | Meaning |
|---|---|---|---|
| `WFBE_C_AI_COMMANDER_TICK` | `15` | 126 | Supervisor base tick (s); how often the order-executor runs (hybrid responsiveness). |
| `WFBE_C_AI_COMMANDER_BASE_INTERVAL` | `60` | 127 | V0.2: base worker cadence (HQ deploy → doctrine build order → defenses). |
| `WFBE_C_AI_COMMANDER_TEAMS_INTERVAL` | `90` | 128 | V0.2: team-founding cadence. |
| `WFBE_C_AI_COMMANDER_UPGRADE_INTERVAL` | `120` | 122 | Upgrade-worker cadence (s). |
| `WFBE_C_AI_COMMANDER_TOWN_INTERVAL` | `120` | 123 | Town-assignment worker cadence (s). |
| `WFBE_C_AI_COMMANDER_PRODUCE_INTERVAL` | `45` | 124 | Production worker cadence (s). |
| `WFBE_C_AI_COMMANDER_TYPES_INTERVAL` | `30` | 125 | Team-typing worker cadence (s). |
| `WFBE_C_AI_COMMANDER_STRATEGY_INTERVAL` | `60` | 176 | V0.5: war-strategy worker cadence (spearheads/relief/strike/arty). |
| `WFBE_C_AI_COMMANDER_MOVE_INTERVALS` | `3600` | 117 | Movement re-issue interval (s). |
| `WFBE_C_AI_COMMANDER_TOTAL_AI_MAX` | `72` | 120 | Per-side AI ceiling for AI-commander unit production (FPS safety cap). |
| `WFBE_C_AI_COMMANDER_SUPPLY_TRUCKS_MAX` | `5` | 118 | Max supply trucks the AI commander fields. |
| `WFBE_C_AI_COMMANDER_DEFENSES_MAX` | `4` | 133 | V0.2: manned base statics the AI places around its HQ. |
| `WFBE_C_AI_COMMANDER_BUILD_GRACE` | `300` | 131 | B36: seconds with NO human commander (from start, re-armed when a human leaves) before the AI builds/spends. |

## Team founding and dynamic population scaling

The static founding target plus the inverse-population team curve (B36.1, Ray 2026-06-15) consumed by `AI_Commander_Teams.sqf`. The team count is the dominant server-FPS lever, so the founding target scales INVERSELY with live human player count (headless clients excluded): more players → fewer HQ squads.

| Constant | Default | Line | Meaning |
|---|---|---|---|
| `WFBE_C_AI_COMMANDER_TEAMS_TARGET` | `2` | 129 | B36: HALVED 4→2 to cut HC saturation + group count. With `MAX_EXTRA 1` the founding cap is 3 teams/side. Rollback: 4. |
| `WFBE_C_AI_COMMANDER_TEAMS_MAX_EXTRA` | `1` | 132 | B36: `TARGET(2)+MAX_EXTRA(1)` = 3 teams/side cap, HALVED from B35's 6, to relieve HC saturation. Rollback: 2. |
| `WFBE_C_AICOM_TEAMS_PC_LOW` | `7` | 139 | 0-2 players bucket. |
| `WFBE_C_AICOM_TEAMS_PC_MID` | `5` | 140 | 3-5 players bucket (B36.1, was 4). |
| `WFBE_C_AICOM_TEAMS_PC_HIGH` | `3` | 141 | 6-9 players bucket. |
| `WFBE_C_AICOM_TEAMS_PC_FULL` | `2` | 142 | 10+ players bucket. Rollback the whole curve: set all four to 2. |
| `WFBE_C_AICOM_DISBAND_SAFE_DIST` | `600` | 143 | B36.1 on-join cleanup: retire a rear AI team only when NO player is within this many metres of its leader AND it is not in combat. |

## Income scaling and the banking valve

Inverted income bonus (highest at LOW pop, to fund the team-curve flood) plus the B37 banking valve that converts low-pop banked funds into squads.

| Constant | Default | Line | Meaning |
|---|---|---|---|
| `WFBE_C_AICOM_INCOME_PC_BONUS` | `0.06` | 144 | B36.1: +6% AI-commander CASH income per human player UNDER the REF pop (inverted; 0 disables → flat `INCOME_MULT`). |
| `WFBE_C_AICOM_INCOME_PC_REF` | `10` | 145 | B36.1: player count at/above which the inverted income boost is ZERO (base income). |
| `WFBE_C_AICOM_BANKING_VALVE` | `1` | 147 | B37: 1=on (low-pop funds→squads valve + income trim); 0=B36.1 behaviour. |
| `WFBE_C_AICOM_TEAMS_LOWPOP_EXTRA` | `2` | 148 | B37: max extra HQ teams a rich low/mid-pop (≤5) commander may field when the valve is on. Dialed back to 2 (Ray 2026-06-16; was 6). |
| `WFBE_C_AICOM_INCOME_PC_BONUS_VALVE` | `0.045` | 149 | B37: gentler low-pop income boost when the valve is on (vs 0.06), so more-squads does not over-bank. |

## Combined-arms mix and air gate

| Constant | Default | Line | Meaning |
|---|---|---|---|
| `WFBE_C_AICOM_TYPE_MIX` | `[0.65, 0.20, 0.12, 0.03]` | 160 | P1 combined-arms ratio: target class mix `[infantry, light, heavy, air]` for newly-typed teams. Weights need not sum to 1 (normalised at pick time); falls back to a lower class then infantry if the rolled class has no buildable. |
| `WFBE_C_AICOM_AIR_MIN_TOWNS` | `4` | 151 | Aircraft are deferred until the AI holds this many towns (air is a late, established-only asset). 0 = no gate. |

## Coherent-front spearhead scoring (V0.8)

The frontier prefilter + distance-dominant scorer that makes the army advance as a wave onto nearby objectives instead of cherry-picking the enemy's rear (claude-gaming 2026-06-14).

| Constant | Default | Line | Meaning |
|---|---|---|---|
| `WFBE_C_AICOM_FRONTIER_RADIUS` | `3000` | 187 | m: a candidate town is "on the front" if within this distance of one of OUR owned towns (fallback: our HQ). Beyond is deprioritised, not banned. |
| `WFBE_C_AICOM_DISTANCE_DIVISOR` | `50` | 188 | Score divisor on distance-to-front: one supply point is worth this many metres of march. Was effectively 150 (too weak). |
| `WFBE_C_AICOM_HQ_PULL_DIVISOR` | `250` | 189 | Score divisor on distance-to-ENEMY-HQ: small spearhead bias toward the enemy capital. Larger = weaker pull. 0 disables. |
| `WFBE_C_AICOM_FAR_PENALTY` | `1000` | 190 | Flat score penalty applied to any candidate OUTSIDE the frontier radius, so a rich deep city can't buy its way over a near contestable town. |
| `WFBE_C_AICOM_CONCENTRATION` | `3` | 195 | Base teams massed on the primary spearhead (used when a town's type is unknown; the per-tier table refines per target). |
| `WFBE_C_AICOM_SPEARHEAD_TOWNS_MAX` | `2` | 196 | Cap on how many DISTINCT spearhead towns the army splits across (was implicitly 5). 1-2 keeps the punch concentrated early. |
| `WFBE_C_AI_COMMANDER_SPEARHEAD_PER_TOWN` | `3` | 180 | V0.5: teams concentrated per spearhead town (legacy/fallback quota; per-tier quota overrides). |

## Bootstrap stipend (0-town opening)

V0.7 bootstrap: bias the first capture and trickle funds+supply per supervisor tick while town count == 0.

| Constant | Default | Line | Meaning |
|---|---|---|---|
| `WFBE_C_AICOM_BOOTSTRAP_BIAS` | `1` | 199 | 1 enable, 0 disable: bias target selection to the nearest-to-base, lowest-value town so the AI captures its first income source fast. |
| `WFBE_C_AICOM_BOOTSTRAP_FUNDS` | `100` | 201 | Funds per minute (scaled to tick spacing) while 0 towns owned. |
| `WFBE_C_AICOM_BOOTSTRAP_SUPPLY` | `50` | 202 | Supply per minute (scaled to tick spacing) while 0 towns owned. |
| `WFBE_C_AICOM_BOOTSTRAP_MAXTIME` | `3600` | 203 | Hard cutoff (s): stipend stops even if no town yet. |

## Upgrade funds fallback and supply reserve

| Constant | Default | Line | Meaning |
|---|---|---|---|
| `WFBE_C_AICOM_UPGRADE_FUNDS_RATE` | `2` | 211 | ENABLED 2026-06-15: cash-rich/supply-starved AI converts funds→Light/Heavy/Air tech (pays supply price × rate as a FUNDS surcharge). AI-commander-only; never touches shared/human supply. 0 disables. |
| `WFBE_C_AICOM_SUPPLY_RESERVE` | `8000` | 212 | Raised 2026-06-15 from 500: keep an 8k SUPPLY buffer for UNIT PRODUCTION so the AI can't drain bootstrap supply on upgrades (routes upgrades to FUNDS below this via `FUNDS_RATE`). |

## Reinforcement ranges and critical-strength refill

| Constant | Default | Line | Meaning |
|---|---|---|---|
| `WFBE_C_AI_COMMANDER_RELIEF_MAX` | `2` | 213 | V0.5: max simultaneous town-relief diversions. |
| `WFBE_C_AI_COMMANDER_REINFORCE_RANGE` | `1200` | 214 | V0.5: Produce only refills teams this close to base (wiped teams reform at base). |
| `WFBE_C_AICOM_FWD_REINFORCE_RANGE` | `500` | 215 | Forward-reinforce: deep teams beyond `REINFORCE_RANGE` may still refill if their leader hugs an owned town within this radius (refill spawns at the nearest factory). |
| `WFBE_C_AICOM_CRITICAL_STRENGTH` | `0.30` | 216 | Rank-2 health-gated refill: a team below this fraction of its template size is rushed to FULL strength in one Produce cycle. Bounded by funds/factory/AI-cap. 0 disables. |

## Wildcard events

| Constant | Default | Line | Override? | Meaning |
|---|---|---|---|---|
| `WFBE_C_AI_COMMANDER_WILDCARD` | `1` | 178 | yes | V0.6: one free random event per AI-commanded side per interval. 0 disables wildcard events entirely. |
| `WFBE_C_AI_COMMANDER_WILDCARD_INTERVAL` | `900` | 179 | yes | Seconds between wildcard events per side (15 min testing cadence, claude-gaming 2026-06-14; was 1800/30min). |

## Stuck-reaction, assault watcher, and slope governor

Three late-defined groups sitting under the `//--- Camps.` heading (not `//--- AI.`), all `if (isNil 'X')`-guarded with single-quoted names.

| Constant | Default | Line | Meaning |
|---|---|---|---|
| `WFBE_C_AICOM_STUCK_SECS` | `210` | 274 | Commander stuck-reaction: the AssignTowns breadcrumb re-issues a parked team's order after this many seconds (was hardcoded 600s). |
| `WFBE_C_AICOM_STUCK_MOVED` | `200` | 275 | Distance (m) under which a team counts as "not moved" for the stuck check. |
| `WFBE_C_AICOM_STUCK_FAR` | `300` | 276 | Distance (m) from objective beyond which a parked team is considered stuck-far. |
| `WFBE_C_AICOM_ASSAULT_ARRIVE_RADIUS` | `250` | 281 | Dispatch→arrival watcher: m to count "at the town" (≈ town SAD radius + leader margin; AIMoveTo uses 200). |
| `WFBE_C_AICOM_ASSAULT_TIMEOUT` | `420` | 282 | Dispatch→arrival budget (s): ≈ 3 watcher passes before a team is declared stranded. |
| `WFBE_C_AICOM_ASSAULT_REACH_FOOT` | `3500` | 291 | m: foot teams won't be sent at ongoing-front spearheads farther than this; pick nearest reachable town instead. |
| `WFBE_C_AICOM_ASSAULT_REACH_MOUNTED` | `9000` | 292 | m: teams with a drivable vehicle may take the long leg to a far spearhead. |
| `WFBE_C_AICOM_SLOPE_Z` | `0.86` | 298 | Careful-gear governor: downshift NORMAL→LIMITED while the lead hull's `surfaceNormal.z` is below this (z = cos slope; 0.86 ≈ 31°). A2-fix: was 0.93 (~21°, too eager). |

## Cross-cutting AI constants (referenced by the commander, in the same block)

These are not commander-namespaced but bound the same AI subsystem.

| Constant | Default | Line | Meaning |
|---|---|---|---|
| `WFBE_C_AI_MAX` | `12` | 113 | Max AI allowed in each AI group. |
| `WFBE_C_TOWNS_ACTIVE_MAX` | `12` | 108 | Active-town budget: max concurrently active towns (FPS lever). |
| `WFBE_C_GUER_GROUPS_MAX` | `80` | 112 | Hard ceiling on total resistance groups (bounds runaway GUER growth toward the engine's ~144-groups/side limit). Raise to 999 for instant rollback. |
| `WFBE_C_SIM_GATING` | `0` | 166 | 1 only on the NEXT arm: enableSimulation off for AI far from any active town. |
| `WFBE_C_AB_ARM` | `"NEXT-T1c"` | 162 | A/B experiment arm label + sim-gating switch (LEGACY arm = control, gating off). |

## Continue Reading

- [AI Commander Autonomy Audit](AI-Commander-Autonomy-Audit) — what these constants actually drive (which workers are wired vs dead).
- [Quad AI Commander](Quad-AI-Commander) — the four-side AI-commander architecture these tunables configure.
- [AI Squad Team Templates Catalog](AI-Squad-Team-Templates-Catalog) — the team templates the `TYPE_MIX` and team-founding constants build.
- [Economy Towns And Supply](Economy-Towns-And-Supply) — the real-supply income these synthetic FUNDS multipliers sit alongside.
- [Commander HQ Lifecycle Atlas](Commander-HQ-Lifecycle-Atlas) — HQ deploy and the build-grace gate the commander runs against.
