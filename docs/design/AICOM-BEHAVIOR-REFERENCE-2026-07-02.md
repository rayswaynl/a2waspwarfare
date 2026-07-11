# AICOM Behavior Reference - 2026-07-02 (reconciled 2026-07-12)

Historical provenance: `claude/build84-cmdcon36`, the source state used by lane 168 for the original 2026-07-02 audit.

Current reconciliation: `origin/master@46d63b0651f67a418d00c951af015b33937af79e` on 2026-07-12. Dependency PR #1045 is present through merge commit `24a8696d535f56acd105ff08ae68551617a22da2`.

This page is a compact current-source map for the AI commander. It distinguishes default-active behavior from code that is implemented but default-dark, and lists the RPT tokens that prove an enabled path is firing. It is not a proposal page, and it must not be used to mark unmerged follow-up PRs as live.

## Scope

- Docs-only source reference. No mission SQF, generated mission mirror, packaging, deploy, or live server setting change.
- Chernarus is the reference path. At the reconciled commit, all 17 implementation files cited below are byte-identical in the Chernarus, Takistan, and Zargabad mission mirrors. Takistan-only SCUD activation is called out separately.
- Byte-identical mirrors do not imply identical runtime values: `worldName` branches and map-specific overrides intentionally vary selected caps, reach, route, slope, recovery, and air-start controls.
- Source anchors are line numbers at the exact reconciled commit above. If a later PR moves code or changes a default, update the anchors, default-state wording, and smoke checklist together.
- The Fable behavior note remains useful historical rationale. Current-state claims below come from the reconciled source and explicitly identify default-dark paths.

## Live Control Model

The AI commander supervisor is enabled by default and ticks every 15 seconds. It logs a one-time boot snapshot with server group count, HC count, the configured flat AI-max value, and start funds, then a recurring brief roughly every 300 seconds. Founding separately enforces the effective population-tier side-AI ceiling described below.

Source anchors:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:318` enables the AI commander by default.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:321` keeps `WFBE_C_AI_COMMANDER_LOCK` default-off, allowing hybrid player command.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:340-346` sets the total AI max and core supervisor cadences.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander.sqf:260-266` emits `[AICOM BOOT]`.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander.sqf:310-314` applies the AI commander lock override when the flag is enabled.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander.sqf:1299-1310` emits the recurring `[AICOM BRIEF]`.

Hybrid behavior is live. When a human occupies the commander slot, the AI still keeps non-player-led founded teams moving unless a team is under an explicit player order or a fresh manual pin. The econ sink also pauses on a physically seated human commander, even if lock mode would otherwise keep the AI in full command.

Source anchors:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_AssignTowns.sqf:32-37` detects a human commander.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_AssignTowns.sqf:190-227` preserves player-led, manually pinned, and explicitly ordered teams.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander.sqf:725-740` pauses the econ sink while a human is seated.

## Strategy And Posture

The strategy worker computes posture from towns, territory-credited effective strength, and HQ strike state. Front presence and garrison bodies are observational fields in the telemetry, not posture inputs. It emits greppable posture, front, and stall records so soak reviewers can explain whether the side is pressing, holding, defending, or stuck in dominance without captures.

Source anchors:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Strategy.sqf:1039-1093` derives posture and emits `POSTURE` and `FRONT` telemetry.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Strategy.sqf:1058-1076` applies the losing-side press floor when the side is behind on towns but near strength parity and its base is safe.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Strategy.sqf:1094-1118` emits `STALL` for dominant-but-passive cases while maintaining the dominance streak.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:1082` defaults `WFBE_C_AICOM_LOSING_PRESS` on.

Primary RPT tokens:

- `AICOMSTAT|v1|POSTURE`
- `AICOMSTAT|v1|FRONT`
- `AICOMSTAT|v1|STALL`
- `AICOMSTAT|v1|EVENT|...|LOSING_PRESS_FLOOR`

## Team Budget And Founding

The live commander derives founded-team targets from player-count buckets, then applies configured deltas/floors, banking or surge adjustments, and a hard cap; Zargabad has map-specific cap overrides. Founding also stops when the effective population-tier side-AI ceiling or the side group ceiling is reached. A rich-state economy path can arm veteran founding, raise an econ-surge flag, and continue research while respecting the human-seated pause above.

Source anchors:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:359-363` defines the player-count team curve and hard cap.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:370-412` defines the shared target delta/floor, population-tier side-AI ceilings, low-pop banking allowance, and group cap.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:2037-2048` applies Zargabad-specific side-AI, hard-cap, and low/mid-pop target overrides.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Teams.sqf:251-278` gates founding on target, tiered side-AI, and group ceilings.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander.sqf:674-703` detects wealth conversion and arms veteran founding.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander.sqf:722-757` gates the econ sink under a seated human and toggles econ-surge.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_AssignTypes.sqf:276` logs `TEAM_TYPED`.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_DisbandLowTier.sqf:88-96` logs low-tier or weak-team `TEAM_RETIRED`.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Teams.sqf:236` logs player-count-scale `TEAM_RETIRED`.

Primary RPT tokens:

- `AICOMSTAT|v2|EVENT|...|TEAM_TYPED`
- `AICOMSTAT|v2|EVENT|...|TEAM_RETIRED`
- `AICOMSTAT|v1|EVENT|...|WEALTH_CONVERSION`
- `AICOMSTAT|v2|EVENT|...|ECON_SINK_SURGE`

## Target Allocation, Spread, And Hold

The active allocator fans teams across a widened fist instead of dogpiling one town. Human console posture and field-order stamps can bias assignment, while spread and hold flags keep the first captor on the center long enough for the town to settle.

Source anchors:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Allocate.sqf:87-110` lets fresh player posture and field-order stamps bias the engage gate.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Allocate.sqf:419-539` assigns harass, neutral-expansion, and cap-aware fist targets.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:774-775` defaults the allocator on and sets `WFBE_C_AICOM2_FIST_TOWNS`.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:1055-1059` defaults spread mode and first-captor hold mode on and defines their caps/timer.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_AssignTowns.sqf:258-288` preserves a live hold latch from retargeting.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_RunCommanderTeam.sqf:993-999` logs `CAPTURE_TRACE|ORDER_ACCEPT`.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_RunCommanderTeam.sqf:1873-1909` logs arrival-wait and begin-capture capture traces.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_RunCommanderTeam.sqf:2307-2339` claims the post-capture hold and logs `HOLD-CLAIM`.

Primary RPT tokens:

- `AICOMSTAT|v2|EVENT|...|CAPTURE_TRACE|ORDER_ACCEPT`
- `AICOMSTAT|v2|EVENT|...|CAPTURE_TRACE|ARRIVAL_WAIT`
- `AICOMSTAT|v2|EVENT|...|CAPTURE_TRACE|BEGIN_CAPTURE`
- `HOLD-CLAIM`

## Journey, Recovery, And Retargeting

The default-active dispatch watcher tracks a team from order acceptance to arrival or stranded closure. A progressing team can keep its current journey through normal AssignTowns retargeting; this is not a universal reservation because the default-dark `WFBE_C_AICOM_STRIKE_COMMIT` leaves progressing teams eligible for HQ-strike selection. Repeated failed journeys, position-stuck teams, and uncapturable centers feed recovery, retargeting, or recycling rather than allowing indefinite milling. Combat-orbiter detection (`WFBE_C_AICOM_ORBITER_DETECT`) and stuck-ladder decay (`WFBE_C_AICOM_STUCK_DECAY`) are implemented but default-dark at this base, so their behavior and telemetry are conditional rather than healthy-baseline expectations.

Source anchors:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_AssignTowns.sqf:86-118` records arrival, increments the arrival counter, and resets per-journey failure state.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_AssignTowns.sqf:162-180` closes timed-out dispatches as `ASSAULT_STRANDED` and can latch recycling.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_AssignTowns.sqf:120-161` implements combat-orbiter detection and `ORBITER_STUCK`, but only when `WFBE_C_AICOM_ORBITER_DETECT` is enabled.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_AssignTowns.sqf:500-566` abandons stalled or uncapturable targets, counts failed journeys, and can side-blacklist towns.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_AssignTowns.sqf:591-604` contains the default-dark stuck-ladder decay path and the default hard-reset path.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_AssignTowns.sqf:617-651` applies `WFBE_C_AICOM_JOURNEY_COMMIT` for progressing dispatches.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:1091-1101` defaults journey commit and failed-journey recycle active, while orbiter detection and stuck-ladder decay default to `0`.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:1439-1489` defines stuck, arrival, dynamic-timeout, reach, and transport controls, including map-aware values.

Primary RPT tokens:

- `AICOMSTAT|v2|EVENT|...|ASSAULT_ARRIVED`
- `AICOMSTAT|v2|EVENT|...|ASSAULT_STRANDED`
- `AICOMSTAT|v2|EVENT|...|ORBITER_STUCK` (only when the default-dark orbiter detector is enabled)
- `AICOMSTAT|v2|EVENT|...|JOURNEY_COMMIT`
- `AICOMSTAT|v2|EVENT|...|TARGET_ABANDON`
- `AICOMSTAT|v2|EVENT|...|SIDE_BLACKLIST`
- `AICOMSTAT|v2|EVENT|...|RECYCLE_FLAG`

Recovery v2 is live. A stuck re-issue can reverse and lane-flip a vehicle, swap a dead driver, force water-stuck road recovery, snap foot teams toward road nodes, and increment the WASPSCALE recovery counter. AutoFlip is also live as a separate server/HC loop for flipped AICOM ground vehicles.

Source anchors:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_RunCommanderTeam.sqf:993-1063` accepts an order and starts/logs the tiered unstuck action.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_RunCommanderTeam.sqf:1076-1150` handles dead-driver swap, reverse pulse, and lane flip.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_RunCommanderTeam.sqf:1153-1295` handles guarded vehicle and foot road-snap/no-road recovery.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_AICOM_AutoFlip.sqf:42-96` gates, rights, and logs `AUTOFLIP`.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:1040` defaults AutoFlip on.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:1168-1173` defaults Recovery V2 and its no-road fallback on and defines its recovery controls.

Primary RPT tokens:

- `AICOMSTAT|v2|EVENT|...|UNSTUCK_FIRED`
- `AICOMSTAT|v1|EVENT|...|AUTOFLIP`
- WASPSCALE field `recov=`

## Assault, Break-Off, Smoke, And Top-Up

On town arrival the executor pushes infantry into the depot-center ring, keeps them there until the town flips or a bounded timeout/abort fires, and latches post-capture hold if enabled. A depleted team can break off into a rally order when enemy resistance remains in the depot capture ring, rather than grinding to zero. Smoke is live on assault approach and break-off.

Source anchors:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_RunCommanderTeam.sqf:1510-1519` stamps `RALLY_FALLBACK`.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_RunCommanderTeam.sqf:1640-1647` defines approach-smoke behavior.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_RunCommanderTeam.sqf:2181-2230` lays the depot-center hold and drain-wait loop.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_RunCommanderTeam.sqf:2236-2288` detects break-off and emits break-off smoke.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_RunCommanderTeam.sqf:2598-2611` fires mobile artillery missions when friendly-fire clear.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_RunCommanderTeam.sqf:2618-2658` consumes HC top-up requests and logs `TOPUP_DONE`.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:1018` defaults mobile artillery on.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:1069` sets the default break-off minimum live units.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:1145-1146` defaults smoke on and sets its cooldown.

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
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:1103` admits understrength infantry teams to service by default.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:1307-1315` enables self-service and defines its thresholds, safety radius, reach, and timeout.

Primary RPT tokens:

- `AICOMSTAT|v1|EVENT|...|SERVICE_ENROUTE`
- `AICOMSTAT|v1|EVENT|...|SERVICE_DONE`

## Aircraft, Airmobile, And Vehicle Lift

Fixed-wing founding is airfield-gated. A held airfield can waive normal air tier for field buys, while a held Aircraft Factory can independently enable heli templates; when an airfield is held, air teams relocate to its spawn positions. Fixed-wing teams use plane-only runway/air-start logic while helis spawn grounded.

Source anchors:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:469-483` defines plane air-start, air cap, Aircraft Factory heli waive, and free-airfield behavior.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Teams.sqf:300-346` resolves airfield, free-air, and Aircraft Factory heli-waive state.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Teams.sqf:1220-1250` detects jet versus generic air teams and relocates air spawns to held airfields.

Airmobile legs and retained team transports are live. A retained transport can fly later ordered legs, hot LZs can trigger paradrop, and eligible owned ground vehicles can be slung and deep-dropped behind the target.

Source anchors:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:497-501` defaults airmobile, air-retain, and vehicle-lift paths on.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:501-509` defines vehicle-lift depth, armor tiers, air-tier gates, and allowlist fallback.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_RunCommanderTeam.sqf:657-681` retains founding air transports and logs `AIR_RETAIN`.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_AICOMAirLeg.sqf:124` logs hot-LZ `AIRMOBILE_PARADROP`.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_AICOMAirLeg.sqf:171-186` resolves vehicle-lift tier.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_AICOMAirLeg.sqf:262-277` slings a vehicle and logs `VEHLIFT` plus `AIRMOBILE_LEG`.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_AICOMAirLeg.sqf:385-397` detaches the deep-dropped vehicle and logs `VEHDROP`.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_AICOMAirReturn.sqf:1-79` returns the retained transport to a live HQ or owned-town fallback and clears the airborne exemption.

Primary RPT tokens:

- `AICOMSTAT|v2|EVENT|...|AIRMOBILE_PARADROP`
- `AICOMSTAT|v2|EVENT|...|AIRMOBILE_LEG`
- `AICOMSTAT|v2|EVENT|...|VEHLIFT`
- `AICOMSTAT|v2|EVENT|...|VEHDROP`
- `AICOMSTAT|v2|EVENT|...|AIR_RETAIN`

## Base, Forward Base, And MHQ Relocation

The base worker builds and logs structures, factory rally positions, and forward-base structures. Base selling is default-active but only acts when its stranded-old-base or redundancy criteria select a safe victim. MHQ relocation is live with relaxed ring search, minimum advance, human-front defer, route contact handling, stuck nudges/teleports, and final deploy revalidation.

Source anchors:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Base.sqf:829` logs `FACTORY_RALLY_SET`.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Base.sqf:838` logs `STRUCTURE_BUILT`.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Base.sqf:1084` logs `FWDBASE_BUILD`.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:697-705` defaults base selling and stranded-old-base preference on and defines its cadence/refund/redundancy controls.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_BaseSell.sqf:12` applies the base-sell master gate.
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
- `AICOM2|v1|SELL|...|event=BASE_SELL`
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

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:1222-1231` defines the AI SCUD master flag, cadence, cluster thresholds, HQ exclusion, confirmation radius, and buy thresholds.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Init/Init_IcbmTel.sqf:1127-1151` clears or tracks clusters and logs `AI_SCUD_TRACK`.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Init/Init_IcbmTel.sqf:1153-1173` enforces interval/funds gate, fires, and logs `AI_SCUD` or `AI_SCUD_SKIP_FUNDS`.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Init/Init_IcbmTel.sqf:1176-1234` gates rich AI SCUD purchase and logs `AI_SCUD_BUY`.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Init/Init_IcbmTel.sqf:1237-1263` starts or skips the Takistan evaluator loop.

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

- One `[AICOM BOOT]` per active supervisor instance after startup; ownership-generation restarts may create another instance.
- Repeating `[AICOM BRIEF]` per active side roughly every 300 seconds.
- `POSTURE` and `FRONT` lines per side; `STALL` only when a dominant side is not pressing.
- `CAPTURE_TRACE|ORDER_ACCEPT` followed by either `ASSAULT_ARRIVED`, `BEGIN_CAPTURE`, or a bounded `ASSAULT_STRANDED`.
- `HOLD-CLAIM` after a town flips, then later normal retargeting while hold mode remains enabled (default on).
- Some mix of `TEAM_TYPED`, `STRUCTURE_BUILT`, `TOPUP_DONE`, and service or recovery events depending on battle state.

Watch for suspicious patterns:

- Hundreds of `UNSTUCK_FIRED` for the same team without later `ASSAULT_ARRIVED`, `TARGET_ABANDON`, `RECYCLE_FLAG`, or retarget evidence.
- When `WFBE_C_AICOM_ORBITER_DETECT` is explicitly enabled, repeated `ORBITER_STUCK` on the same town with no `TARGET_ABANDON` or side-blacklist follow-up. At the reconciled default `0`, no `ORBITER_STUCK` line is expected.
- `MHQRELOC|ABORT|no-buffer-clear-standoff` every evaluation with no `RELAXED`, `DEFER`, or `TRIGGER`, especially on a compressed front.
- `AI_SCUD_SKIP_FUNDS` every evaluation after rich/econ-surge conditions should exist.
- `SERVICE_ENROUTE` without later `SERVICE_DONE` or a normal front retarget after timeout/contact.
- A side emitting `STALL` for many intervals while holding a large town lead and not emitting `HQ_STRIKE` or capture progress.

## Relation To Fable Work

The Fable behavior page is historical analysis and design rationale. Default-active ideas source-backed above include journey commit, failed-journey recycle, the losing-side press floor, MHQ relocation relax/final validation, Recovery V2, and spread/hold. Combat-orbiter detection and stuck-ladder decay are implemented but default-dark (`0`) at the reconciled base and must not be described as live without an explicit runtime override. Future Fable PRs may refine these systems further, so do not treat the Fable page alone as current-state evidence. For release notes, cite the exact reconciled commit, source anchors, effective defaults, and RPT tokens from this reference.
