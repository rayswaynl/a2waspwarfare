# AICOM Behavior Reference - 2026-07-02

Base: `claude/build84-cmdcon36` source state used by lane 168.

This page is a compact "what is live now" map for the AI commander. It is meant for fleet workers and soak reviewers who need to know which AICOM behaviors are already in the mission, which flags gate them, and which RPT tokens prove they are firing. It is not a proposal page, and it should not be used to mark unmerged follow-up PRs as live.

## Scope

- Docs-only source reference. No mission SQF, generated mission mirror, packaging, deploy, or live server setting change.
- Chernarus source is the reference path. Takistan inherits shared code through the normal mission source, with Takistan-only SCUD behavior called out separately.
- Source anchors are line numbers in this branch on 2026-07-02. If a later PR moves code, update the anchors and the smoke checklist together.
- The Fable behavior note remains useful rationale, but this page is the current live-behavior checklist.

## Live Control Model

The AI commander supervisor is enabled by default and ticks every 15 seconds. It logs a one-time boot snapshot with server group count, HC count, AI max, and start funds, then a recurring brief roughly every 300 seconds.

Source anchors:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:241` enables the AI commander by default.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:244` keeps `WFBE_C_AI_COMMANDER_LOCK` default-off, allowing hybrid player command.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:258-264` sets the total AI max and core supervisor cadences.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander.sqf:123-129` emits `[AICOM BOOT]`.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander.sqf:173-177` applies the AI commander lock override when the flag is enabled.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander.sqf:1022-1033` emits the recurring `[AICOM BRIEF]`.

Hybrid behavior is live. When a human occupies the commander slot, the AI still keeps non-player-led founded teams moving unless a team is under an explicit player order or a fresh manual pin. The econ sink also pauses on a physically seated human commander, even if lock mode would otherwise keep the AI in full command.

Source anchors:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_AssignTowns.sqf:32-37` detects a human commander.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_AssignTowns.sqf:181-218` preserves player-led and explicitly ordered teams.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander.sqf:575-582` pauses the econ sink while a human is seated.

## Strategy And Posture

The strategy worker computes posture from towns, effective strength, HQ strike state, front presence, and garrison bodies. It emits greppable posture, front, and stall telemetry so soak reviewers can explain whether the side is pressing, holding, defending, or stuck in dominance without captures.

Source anchors:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Strategy.sqf:913-965` builds `POSTURE` and `FRONT` telemetry.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Strategy.sqf:931-947` applies the losing-side press floor when the side is behind on towns but near strength parity and its base is safe.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Strategy.sqf:981-985` emits `STALL` for dominant-but-passive cases.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:822` gates `WFBE_C_AICOM_LOSING_PRESS`.

Primary RPT tokens:

- `AICOMSTAT|v1|POSTURE`
- `AICOMSTAT|v1|FRONT`
- `AICOMSTAT|v1|STALL`
- `AICOMSTAT|v1|EVENT|...|LOSING_PRESS_FLOOR`

## Team Budget And Founding

The live commander scales founded team targets by player-count bucket, clamps them with a hard cap, and blocks founding when the side AI count or side group count is already too high. It also has a rich-state economy path that can arm veteran founding, raise an econ-surge flag, and continue research while respecting the human-seated pause above.

Source anchors:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:277-281` defines the player-count team curve and hard cap.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Teams.sqf:230-255` gates founding on tiered side AI and group ceilings.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander.sqf:520-549` detects wealth conversion and arms veteran founding.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander.sqf:582-600` toggles econ-surge.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_AssignTypes.sqf:276` logs `TEAM_TYPED`.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_DisbandLowTier.sqf:79` logs low-tier `TEAM_RETIRED`.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Teams.sqf:215` logs player-count-scale `TEAM_RETIRED`.

Primary RPT tokens:

- `AICOMSTAT|v2|EVENT|...|TEAM_TYPED`
- `AICOMSTAT|v2|EVENT|...|TEAM_RETIRED`
- `AICOMSTAT|v1|EVENT|...|WEALTH_CONVERSION`
- `AICOMSTAT|v2|EVENT|...|ECON_SINK_SURGE`

## Target Allocation, Spread, And Hold

The active allocator fans teams across a widened fist instead of dogpiling one town. Human console posture and field-order stamps can bias assignment, while spread and hold flags keep the first captor on the center long enough for the town to settle.

Source anchors:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Allocate.sqf:44-51` lets fresh player `PUSH` or `HOLD` stamps bias the engage gate.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Allocate.sqf:228-280` assigns harass, neutral expansion, and cap-aware fist targets.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:636` sets `WFBE_C_AICOM2_FIST_TOWNS`.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:807-810` enables spread mode and first-captor hold mode.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_AssignTowns.sqf:246-267` preserves a live hold latch from retargeting.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_RunCommanderTeam.sqf:930-931` logs `CAPTURE_TRACE|ORDER_ACCEPT`.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_RunCommanderTeam.sqf:1586-1619` logs arrival-wait and begin-capture capture traces.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_RunCommanderTeam.sqf:1961-1984` claims the post-capture hold and logs `HOLD-CLAIM`.

Primary RPT tokens:

- `AICOMSTAT|v2|EVENT|...|CAPTURE_TRACE|ORDER_ACCEPT`
- `AICOMSTAT|v2|EVENT|...|CAPTURE_TRACE|ARRIVAL_WAIT`
- `AICOMSTAT|v2|EVENT|...|CAPTURE_TRACE|BEGIN_CAPTURE`
- `HOLD-CLAIM`

## Journey, Recovery, And Retargeting

The live dispatch watcher tracks a team from order acceptance to arrival or stranded closure. A progressing team can keep its current journey instead of being retargeted mid-leg. Combat orbiters, repeated failed journeys, position-stuck teams, and uncapturable centers all feed recovery or recycling rather than allowing indefinite milling.

Source anchors:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_AssignTowns.sqf:88-107` records arrival and increments the arrival counter.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_AssignTowns.sqf:153-158` closes timed-out dispatches as `ASSAULT_STRANDED`.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_AssignTowns.sqf:115-145` detects combat orbiters and logs `ORBITER_STUCK`.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_AssignTowns.sqf:430-479` abandons stalled or uncapturable targets, counts failed journeys, and can side-blacklist towns.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_AssignTowns.sqf:511-539` applies `WFBE_C_AICOM_JOURNEY_COMMIT` for progressing dispatches.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:830-832` gates journey commit, ladder decay, and failed-journey recycle.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:1113-1138` defines stuck, arrival, reach, transport, and slope constants.

Primary RPT tokens:

- `AICOMSTAT|v2|EVENT|...|ASSAULT_ARRIVED`
- `AICOMSTAT|v2|EVENT|...|ASSAULT_STRANDED`
- `AICOMSTAT|v2|EVENT|...|ORBITER_STUCK`
- `AICOMSTAT|v2|EVENT|...|JOURNEY_COMMIT`
- `AICOMSTAT|v2|EVENT|...|TARGET_ABANDON`
- `AICOMSTAT|v2|EVENT|...|SIDE_BLACKLIST`
- `AICOMSTAT|v2|EVENT|...|RECYCLE_FLAG`

Recovery v2 is live. A stuck re-issue can reverse and lane-flip a vehicle, swap a dead driver, force water-stuck road recovery, snap foot teams toward road nodes, and increment the WASPSCALE recovery counter. AutoFlip is also live as a separate server/HC loop for flipped AICOM ground vehicles.

Source anchors:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_RunCommanderTeam.sqf:930-972` accepts an order and starts the tiered unstuck action.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_RunCommanderTeam.sqf:986-1020` handles dead-driver swap, reverse pulse, and lane flip.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_RunCommanderTeam.sqf:1025-1080` handles vehicle and foot road-snap recovery.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_AICOM_AutoFlip.sqf:18-75` gates and logs `AUTOFLIP`.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:794` gates AutoFlip.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:874` gates recovery v2.

Primary RPT tokens:

- `AICOMSTAT|v2|EVENT|...|UNSTUCK_FIRED`
- `AICOMSTAT|v1|EVENT|...|AUTOFLIP`
- WASPSCALE field `recov=`

## Assault, Break-Off, Smoke, And Top-Up

On town arrival the executor pushes infantry into the depot-center ring, keeps them there until the town flips or a bounded timeout/abort fires, and latches post-capture hold if enabled. Depleted teams under fire can break off into a rally order rather than grinding to zero. Smoke is live on assault approach and break-off.

Source anchors:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_RunCommanderTeam.sqf:1274-1283` stamps `RALLY_FALLBACK`.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_RunCommanderTeam.sqf:1403-1410` defines approach-smoke behavior.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_RunCommanderTeam.sqf:1847-1879` lays the depot-center hold and drain-wait loop.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_RunCommanderTeam.sqf:1891-1941` detects break-off and emits break-off smoke.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_RunCommanderTeam.sqf:2223-2236` fires mobile artillery missions when friendly-fire clear.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_RunCommanderTeam.sqf:2243-2272` consumes HC top-up requests and logs `TOPUP_DONE`.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:820` gates break-off minimum live units.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:859-860` gates smoke and its cooldown.

Primary RPT tokens:

- `AICOMSTAT|v2|EVENT|...|RALLY_FALLBACK`
- `AICOMSTAT|v2|EVENT|...|SMOKE|ASSAULT`
- `AICOMSTAT|v2|EVENT|...|SMOKE|BREAKOFF`
- `AICOMSTAT|v2|EVENT|...|BREAKOFF`
- `AICOMSTAT|v1|EVENT|...|FIRE_MISSION_MOBILE`
- `AICOMSTAT|v1|EVENT|...|TOPUP_DONE`

## Self-Service And Retirement

Self-service is enabled in this base. A damaged or low-ammo team that is not in contact can detour to a safe friendly town or airfield, repair/rearm/heal, then clear its goto for a normal front retask. The detour has contact and timeout aborts, so it should not freeze a team away from the fight.

Source anchors:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_AICOMServiceTick.sqf:1-30` documents the live service contract and guardrails.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_AICOMServiceTick.sqf:56-99` handles en-route service completion or abort.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_AICOMServiceTick.sqf:180-205` chooses safe airfield/town service and logs `SERVICE_ENROUTE`.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:991-999` defines the self-service thresholds and reach.

Primary RPT tokens:

- `AICOMSTAT|v1|EVENT|...|SERVICE_ENROUTE`
- `AICOMSTAT|v1|EVENT|...|SERVICE_DONE`

## Aircraft, Airmobile, And Vehicle Lift

Aircraft founding is live with airfield gating. Held airfields can waive normal air tier for field buys, a held Aircraft Factory can enable heli templates, and air teams relocate to owned airfield spawn positions. Fixed-wing teams use plane-only runway/air-start logic while helis spawn grounded.

Source anchors:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:376-388` defines plane air-start, air cap, Aircraft Factory heli waive, and free-airfield behavior.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Teams.sqf:277-323` resolves airfield, free-air, and Aircraft Factory heli waive state.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Teams.sqf:1068-1089` detects jet versus generic air teams and relocates air spawns to held airfields.

Airmobile legs and retained team transports are live. A retained transport can fly later ordered legs, hot LZs can trigger paradrop, and eligible owned ground vehicles can be slung and deep-dropped behind the target.

Source anchors:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:401-405` gates airmobile, air retain, and vehicle lift.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:405-413` defines vehicle lift depth, armor tiers, air-tier gates, and allowlist fallback.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_RunCommanderTeam.sqf:643-667` retains founding air transports and logs `AIR_RETAIN`.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_AICOMAirLeg.sqf:123` logs hot-LZ `AIRMOBILE_PARADROP`.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_AICOMAirLeg.sqf:170-185` resolves vehicle-lift tier.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_AICOMAirLeg.sqf:261-276` slings a vehicle and logs `VEHLIFT` plus `AIRMOBILE_LEG`.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_AICOMAirLeg.sqf:381-393` detaches the deep-dropped vehicle and logs `VEHDROP`.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_AICOMAirReturn.sqf:1-50` returns the retained transport to base and clears the airborne exemption.

Primary RPT tokens:

- `AICOMSTAT|v2|EVENT|...|AIRMOBILE_PARADROP`
- `AICOMSTAT|v2|EVENT|...|AIRMOBILE_LEG`
- `AICOMSTAT|v2|EVENT|...|VEHLIFT`
- `AICOMSTAT|v2|EVENT|...|VEHDROP`
- `AICOMSTAT|v2|EVENT|...|AIR_RETAIN`

## Base, Forward Base, And MHQ Relocation

The base worker builds and logs structures, factory rally positions, forward-base structures, and optional redundant-base sells. MHQ relocation is live with relaxed ring search, minimum advance, human-front defer, route contact handling, stuck nudges/teleports, and final deploy revalidation.

Source anchors:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Base.sqf:765` logs `FACTORY_RALLY_SET`.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Base.sqf:774` logs `STRUCTURE_BUILT`.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Base.sqf:964` logs `FWDBASE_BUILD`.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_BaseSell.sqf:12` keeps base selling gated dark by default.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_BaseSell.sqf:97` logs `BASE_SELL` when enabled.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_MHQReloc.sqf:176-203` logs relaxed relocation or aborts for insufficient advance/no buffer-clear standoff.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_MHQReloc.sqf:215-236` defers human-front relocation or triggers the relocation lifecycle.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_MHQReloc.sqf:360-374` toggles route-contact and route-clear behavior.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_MHQReloc.sqf:387-413` nudges and stuck-teleports the MHQ.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_MHQReloc.sqf:520-552` final-revalidates and logs deployed relocation.

Primary RPT tokens:

- `AICOMSTAT|v2|EVENT|...|STRUCTURE_BUILT`
- `AICOMSTAT|v1|EVENT|...|FACTORY_RALLY_SET`
- `AICOMSTAT|v1|EVENT|...|FWDBASE_BUILD`
- `AICOMSTAT|v1|EVENT|...|BASE_SELL`
- `AICOMSTAT|v1|MHQRELOC|...|RELAXED`
- `AICOMSTAT|v1|MHQRELOC|...|DEFER|human-front`
- `AICOMSTAT|v1|MHQRELOC|...|TRIGGER`
- `AICOMSTAT|v1|MHQRELOC|...|NUDGE`
- `AICOMSTAT|v1|MHQRELOC|...|STUCK_TELEPORT`
- `AICOMSTAT|v1|MHQRELOC|...|FINAL_REVALIDATE`
- `AICOMSTAT|v1|MHQRELOC|...|DEPLOYED`

## Takistan AI SCUD

AI SCUD use is Takistan-only. The evaluator waits for mission initialization, runs a low-cadence loop, scans bounded candidate anchors, requires a persistent enemy cluster, enforces per-side launch intervals, avoids bankrupting the AI treasury, and can optionally buy one mobile SCUD for a rich AI side.

Source anchors:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:926-935` defines the AI SCUD master flag, cadence, cluster thresholds, HQ exclusion, confirmation radius, and buy thresholds.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Init/Init_IcbmTel.sqf:1087-1111` clears or tracks clusters and logs `AI_SCUD_TRACK`.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Init/Init_IcbmTel.sqf:1113-1133` enforces interval/funds gate, fires, and logs `AI_SCUD` or `AI_SCUD_SKIP_FUNDS`.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Init/Init_IcbmTel.sqf:1136-1194` gates rich AI SCUD purchase and logs `AI_SCUD_BUY`.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Init/Init_IcbmTel.sqf:1197-1223` starts or skips the Takistan evaluator loop.

Primary RPT tokens:

- `AICOMSTAT|v2|EVENT|all|...|AI_SCUD_LOOP|online`
- `AICOMSTAT|v2|EVENT|...|AI_SCUD_TRACK`
- `AICOMSTAT|v2|EVENT|...|AI_SCUD_SKIP_FUNDS`
- `AICOMSTAT|v2|EVENT|...|AI_SCUD`
- `AICOMSTAT|v2|EVENT|...|AI_SCUD_BUY`
- `AICOMSTAT|v2|EVENT|all|...|AI_SCUD_LOOP|offline (game over)`

## Soak Smoke Checklist

Use this as a quick RPT scan after a long AI-vs-AI or low-pop soak.

Healthy baseline:

- One `[AICOM BOOT]` per AI side after startup.
- Repeating `[AICOM BRIEF]` per active side roughly every 300 seconds.
- `POSTURE` and `FRONT` lines per side; `STALL` only when a dominant side is not pressing.
- `CAPTURE_TRACE|ORDER_ACCEPT` followed by either `ASSAULT_ARRIVED`, `BEGIN_CAPTURE`, or a bounded `ASSAULT_STRANDED`.
- `HOLD-CLAIM` after a town flips, then later normal retargeting.
- Some mix of `TEAM_TYPED`, `STRUCTURE_BUILT`, `TOPUP_DONE`, and service or recovery events depending on battle state.

Watch for suspicious patterns:

- Hundreds of `UNSTUCK_FIRED` for the same team without later `ASSAULT_ARRIVED`, `TARGET_ABANDON`, `RECYCLE_FLAG`, or retarget evidence.
- Repeated `ORBITER_STUCK` on the same town with no `TARGET_ABANDON` or side-blacklist follow-up.
- `MHQRELOC|ABORT|no-buffer-clear-standoff` every evaluation with no `RELAXED`, `DEFER`, or `TRIGGER`, especially on a compressed front.
- `AI_SCUD_SKIP_FUNDS` every evaluation after rich/econ-surge conditions should exist.
- `SERVICE_ENROUTE` without later `SERVICE_DONE` or a normal front retarget after timeout/contact.
- A side emitting `STALL` for many intervals while holding a large town lead and not emitting `LOSING_PRESS_FLOOR`, `HQ_STRIKE`, or capture progress.

## Relation To Fable Work

The Fable behavior page is analysis and design rationale. Several named ideas are live in this base and are source-backed above: journey commit, orbiter detection, ladder decay/recycle, losing-side press floor, MHQ relocation relax/final validation, recovery v2, and spread/hold. Future Fable PRs may refine those systems further, so do not treat the Fable page alone as live-state evidence. For release notes, cite the source anchors and RPT tokens from this reference.
