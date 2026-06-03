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

## Candidate leads

| Lead | Upstream archive evidence | Current route | Suggested caveat |
| --- | --- | --- | --- |
| Auto view-distance optimizer | `v31072024`: target-FPS hotkeys/actions, +/-2 FPS band and profile persistence. | [Performance opportunity sweep](Performance-Opportunity-Sweep), [Client UI systems atlas](Client-UI-Systems-Atlas), [Feature status register](Feature-Status-Register) | Not represented as a dedicated lane; verify action bindings/profile variables before calling it live. |
| AFK policy and timer posture | `v23072024` and older `v05092023`: 10-minute default and 30-second warning/countdown context. | [External integrations](External-Integrations), [Feature status register](Feature-Status-Register) | Current docs cover AFK/BattlEye plumbing more than policy values; verify current constants and server config. |
| AFK lock discipline and abuse warning | `v23072024`: discipline/warning language around bypassing AFK scripts. | [External integrations](External-Integrations), [Pending owner decisions](Pending-Owner-Decisions) | Governance/live-admin wording should stay historical unless current server policy confirms it. |
| FAB-250/MK-82 remote destruction guard | `v23072024`: bomb destruction beyond long locked-target distances. | [Support/specials/tactical modules atlas](Support-Specials-And-Tactical-Modules-Atlas), [Feature status register](Feature-Status-Register) | Potential anti-exploit gameplay guard; verify current aircraft/bomb scripts before documenting as shipped. |
| Artillery circle/ellipse marker behavior | `v16072024`: artillery circle marker and optional marker params. | [Marker cleanup/restoration atlas](Marker-Cleanup-Restoration-Systems-Atlas), [Feature status register](Feature-Status-Register) | Current marker docs focus more on networking/locality; marker geometry and QA may need a lane. |
| Nuke blast radius and sound behavior | `v16072024`: 800m blast/radiation/sound tuning. | [ICBM authority playbook](ICBM-Authority-Playbook), [Support/specials/tactical modules atlas](Support-Specials-And-Tactical-Modules-Atlas) | Security/authority is documented; gameplay effect tuning needs source verification before adding detail. |
| Bomb altitude hard cap and multilingual warning | `v03072024`: max altitude and vehicle-channel notification/event-handler context. | [Support/specials/tactical modules atlas](Support-Specials-And-Tactical-Modules-Atlas), [Client UI systems atlas](Client-UI-Systems-Atlas) | Verify whether the hard cap and warning EH still exist. |
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
