# Upstream Changelog Feature Leads

This page captures candidate feature/status leads extracted from the imported Miksuu changelog archive.

These are not current-source claims. Treat every row as a research lead until a future pass checks current source, branch history, generated mission scope and runtime evidence.

## What this page is

- A queue of historical changelog features that may be missing from, or under-contextualized in, [Feature status register](Feature-Status-Register).
- A bridge from [Miksuu Wiki Archive: Changelog](Miksuu-Wiki-Archive-Changelog) into source-backed current docs.
- A reminder that the old changelog records live-server/event-time behavior, temporary removals, reverts and branch-only experiments.

## Verification rule

Before promoting any row:

1. Search current source and maintained Vanilla for the feature names, constants, scripts, actions and markers.
2. Check whether it is stable `origin/master`, docs/source branch only, upstream/Miksuu only, release branch only or removed.
3. Add the result to the owning current page, not only this backlog.
4. Keep old changelog wording as provenance, not current truth.

## Source-Checked Promotions 2026-06-03

| Lead | Current-source result | Owning pages |
| --- | --- | --- |
| Auto view-distance optimizer | **Live in source Chernarus.** Client init defaults `AUTO_DISTANCE_VIEW_TARGET_FPS` to 60 and starts with `TOOGLE_AUTO_DISTANCE_VIEW=false`; display 46 binds `User18` toggle plus `User19`/`User20` view-distance or target-FPS adjustment. The current automatic controller runs only when the toggle is on and the map is not visible, uses a +/-4 FPS band, not the old changelog's +/-2 wording, clamps view distance between 500 and 6000, lowers by 200 when below the band and raises by 300 or 50 otherwise. Profile restore/persistence uses `WFBE_TARGET_FPS`; performance audit snapshots target FPS and view distance. Evidence: `Client/Init/Init_Client.sqf:12-13,175-176,228-240`; `Client/FSM/updateclient.sqf:102-107`; `Common/Functions/Common_AdjustViewDistance.sqf:17-69`; `Common/Functions/Common_AutomaticViewDistance.sqf:6-36`; `Client/Init/Init_ProfileVariables.sqf:18-23`; `Common/Functions/Common_PerformanceAudit.sqf:62-64`. | [Client UI systems atlas](Client-UI-Systems-Atlas), [Performance opportunity sweep](Performance-Opportunity-Sweep), [Feature status register](Feature-Status-Register) |
| AFK policy and timer posture | **Live, but dual-path.** The active client FSM reads `WFBE_C_AFK_TIME`, converts minutes to seconds, warns below 10 minutes, switches to 30-second cadence above 120 seconds and every-tick seconds below 120, then publishes `kickAFK` for BattlEye. The older AFK module is also started from client init with a 30-minute local threshold, `AFKthresholdExceededName` logging and `failMission "END1"`. Current Chernarus parameter default is 15 minutes, not the old changelog's 10-minute wording. Evidence: `Rsc/Parameters.hpp:44-48`; `Client/FSM/updateclient.sqf:28-31,117-160`; `Client/Init/Init_Client.sqf:256-264`; `Client/Module/AFKkick/monitorAFK.sqf:19-30`; `Server/Module/afkKick/initAFKkickHandler.sqf:9-12`; `BattlEyeFilter/publicvariable.txt:1-2`. | [Player join/disconnect lifecycle](Player-Join-Disconnect-And-AntiStack-Lifecycle), [Public variable channel index](Public-Variable-Channel-Index), [External integrations](External-Integrations) |
| FAB-250/MK-82 remote destruction guard | **Partially live.** Plane init attaches `HandleShootBombs`; the handler deletes `Bo_FAB_250`/`Bo_Mk82` projectiles when local player distance to `cursorTarget` is at or beyond `WFBE_C_GAMEPLAY_BOMBS_DISTANCE_RESTRICTION` and hints `STR_WF_MESSAGE_BombDistanceRestriction`. The altitude block is present but commented out, so the `WFBE_C_GAMEPLAY_BOMBS_ALTITUDE` parameter exists without active altitude enforcement in this handler. Evidence: `Rsc/Parameters.hpp:284-294`; `Common/Init/Init_Unit.sqf:118-121`; `Common/Functions/Common_HandleShootBombs.sqf:15-30,32-44`. | [Support/specials/tactical modules atlas](Support-Specials-And-Tactical-Modules-Atlas), [Feature status register](Feature-Status-Register) |
| Missile terrain/range guardrails | **Live, with locality caveats.** `Init_Unit.sqf` adds `incomingMissile` range handling when `WFBE_C_GAMEPLAY_MISSILES_RANGE` is non-zero and adds a `Fired` handler to tanks/cars/air for terrain-masking deletion. The range handler deletes affected IR-lock/bomb-workaround projectiles after the configured range; the terrain-masking handler deletes guided missile-like projectiles when terrain blocks line-of-sight to `cursorTarget`. Evidence: `Rsc/Parameters.hpp:296-300`; `Common/Init/Init_Unit.sqf:125-128,207-212`; `Common/Functions/Common_HandleIncomingMissile.sqf:9-21`; `Common/Functions/Common_HandleShootMissiles.sqf:95-140`. | [Support/specials/tactical modules atlas](Support-Specials-And-Tactical-Modules-Atlas), [Feature status register](Feature-Status-Register) |

## Candidate leads

| Lead | Upstream archive evidence | Current route | Suggested caveat |
| --- | --- | --- | --- |
| Auto view-distance optimizer | `v31072024`: target-FPS hotkeys/actions, +/-2 FPS band and profile persistence. | [Performance opportunity sweep](Performance-Opportunity-Sweep), [Client UI systems atlas](Client-UI-Systems-Atlas), [Feature status register](Feature-Status-Register) | Promoted above with current-source corrections: live, but current band is +/-4 and default target FPS is 60. |
| AFK policy and timer posture | `v23072024` and older `v05092023`: 10-minute default and 30-second warning/countdown context. | [External integrations](External-Integrations), [Feature status register](Feature-Status-Register) | Promoted above with current-source corrections: current parameter default is 15 minutes and two AFK paths are active. |
| AFK lock discipline and abuse warning | `v23072024`: discipline/warning language around bypassing AFK scripts. | [External integrations](External-Integrations), [Pending owner decisions](Pending-Owner-Decisions) | Governance/live-admin wording should stay historical unless current server policy confirms it. |
| FAB-250/MK-82 remote destruction guard | `v23072024`: bomb destruction beyond long locked-target distances. | [Support/specials/tactical modules atlas](Support-Specials-And-Tactical-Modules-Atlas), [Feature status register](Feature-Status-Register) | Promoted above: distance deletion is live for `Bo_FAB_250`/`Bo_Mk82`; altitude enforcement is currently commented. |
| Artillery circle/ellipse marker behavior | `v16072024`: artillery circle marker and optional marker params. | [Marker cleanup/restoration atlas](Marker-Cleanup-Restoration-Systems-Atlas), [Feature status register](Feature-Status-Register) | Current marker docs focus more on networking/locality; marker geometry and QA may need a lane. |
| Nuke blast radius and sound behavior | `v16072024`: 800m blast/radiation/sound tuning. | [ICBM authority playbook](ICBM-Authority-Playbook), [Support/specials/tactical modules atlas](Support-Specials-And-Tactical-Modules-Atlas) | Security/authority is documented; gameplay effect tuning needs source verification before adding detail. |
| Bomb altitude hard cap and multilingual warning | `v03072024`: max altitude and vehicle-channel notification/event-handler context. | [Support/specials/tactical modules atlas](Support-Specials-And-Tactical-Modules-Atlas), [Client UI systems atlas](Client-UI-Systems-Atlas) | Current handler keeps the altitude block commented out; treat the parameter as config-present/runtime-dormant until revived and smoke-tested. |
| Climbing gear for MHQ / Light Factory vehicles | `v16072024`: climbing gear added to MHQ/LF vehicles. | [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas), [Construction/CoIn atlas](Construction-And-CoIn-Systems-Atlas) | Missing from status docs; may be historical or drifted. |
| Anti-air radar upgrade ladder | `v20072023`: three upgrade levels, speed refresh and type reveal. | [Upgrades and research atlas](Upgrades-And-Research-Atlas), [Client UI systems atlas](Client-UI-Systems-Atlas), [Feature status register](Feature-Status-Register) | Not clearly represented; verify live upgrade constants/UI behavior. |
| AA radar UI/targeting aid and AA tab-lock whitelist | `v12062023`: radar/AA assistance and whitelist context. | [Client UI systems atlas](Client-UI-Systems-Atlas), [Support/specials/tactical modules atlas](Support-Specials-And-Tactical-Modules-Atlas) | Needs vehicle whitelist, ownership and smoke evidence before promotion. |
| Remote camera human-only filtering | `v22032024` and `v22032024_1`: patch and quick revert/recycle context. | [Client UI systems atlas](Client-UI-Systems-Atlas), [Feature status register](Feature-Status-Register) | Treat as rollback/noisy history unless current unit-camera source confirms final behavior. |
| Task-system removal context | `v22032024` and `v04032024`: task-system removal. | [Feature status register](Feature-Status-Register), [Abandoned feature revival](Abandoned-Feature-Revival-Review) | Already represented, but the changelog gives useful rationale and dependent-script context. |
| GUER barracks removal | `v22032024`: guerrilla barracks removal. | [Feature status register](Feature-Status-Register), [Resistance supply scaffold](Resistance-Supply-Scaffold) | Already represented; add gameplay/AI-defense consequences only after source review. |
| HQ repair cost escalation history | `v26102023` and related HQ notes. | [Commander HQ lifecycle atlas](Commander-HQ-Lifecycle-Atlas), [Feature status register](Feature-Status-Register) | Authority risk is documented, but pricing/tiering policy is not. |
| HQ wreck marker lifecycle | `v04032024`, `v15092023`, `v10092023`: restore/move/update marker notes. | [Marker cleanup/restoration atlas](Marker-Cleanup-Restoration-Systems-Atlas), [Commander HQ lifecycle atlas](Commander-HQ-Lifecycle-Atlas) | Needs explicit lifecycle spec: spawn, persistence, update-on-move, visibility and teardown. |
| Engineer salvage cooldown and skill hook | `v09022024`: 10-second cooldown and skill hook. | [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas), [Service menu affordability guards](Service-Menu-Affordability-Guards) | Not represented as a salvage lane; verify implementation path. |
| Spawn marker feature set | `v09022024` and `v19082023`: LF/HF/AF and barracks spawn marker context. | [Respawn/death lifecycle](Respawn-And-Death-Lifecycle-Atlas), [Marker cleanup/restoration atlas](Marker-Cleanup-Restoration-Systems-Atlas) | Verify marker ownership, spawn arbitration and fairness under contention. |
| Paratrooper and side marker regression history | `v20072023`, `v15092023`: paratrooper and multi-ICBM/artillery marker fixes. | [Paratrooper marker revival](Paratrooper-Marker-Revival), [Perf quick wins branch audit](Perf-Quick-Wins-Branch-Audit) | Partially represented but historically noisy; keep branch/verification scoped until release proof exists. |
| Modded map boundary/rotation and 7z workflow | `v24112023`: modded rotation, boundaries and archive workflow. | [Content structure and maps](Content-Structure-And-Maps), [Tools and build workflow](Tools-And-Build-Workflow), [Tooling release readiness audit](Tooling-Release-Readiness-Audit) | Split gameplay intent from current generated/release reality. |

## Next verification bundle

Highest-value next source pass:

- Auto view-distance optimizer.
- Anti-air radar ladder/UI.
- HQ wreck marker lifecycle.
- Engineer salvage.
- Spawn marker feature set.
- Bomb/ordnance guardrails.

These touch real user-facing gameplay and may either reveal shipped but undocumented systems or confirm old changelog-only drift.

## Continue Reading

Previous: [Miksuu Wiki Archive: Changelog](Miksuu-Wiki-Archive-Changelog) | Next: [Feature status register](Feature-Status-Register)

Related: [Community & Dev](Community-And-Dev) | [Miksuu upstream wiki import](Miksuu-Upstream-Wiki-Import) | [Developer history and upstream lessons](Developer-History-And-Upstream-Lessons)
