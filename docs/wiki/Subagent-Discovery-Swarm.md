# Subagent Discovery Swarm

This page tracks the cheap read-only Codex discovery agents currently digging through `a2waspwarfare`.

The swarm is intentionally evidence-first: agents read source, report path/line-backed findings, and avoid editing docs or mission code. Codex integrates the useful findings into the wiki, `agent-context.json`, the coverage ledger and the feature-status register after review.

## Current Wave: Wave N

Spawned after Steff made this Codex tab the main LLM orchestrator and asked for more deep code discovery. All six read-only explorers returned. Codex has summarized the reports here and in machine records; the next pass should promote the highest-risk items into their owner pages.

| Agent | Lane | Status | Harvest summary |
| --- | --- | --- | --- |
| Tesla | `wasp-overlay-archaeology` | Returned / summary harvested | Live hooks are RPG dropping, marker monitor, base repair/actions, respawn rewiring and start vehicles. Dead/fragile areas include commented legacy WASP bootstrap, abandoned `WASP/Init_Client.sqf`, literal `"_initCMD"` in dead `procInitComm`, `208 = player addAction`, client-side cash HQ recovery effects, inclusive base repair loop and DropRPG locality risk. |
| Linnaeus | `join-jip-disconnect-resilience` | Returned / summary harvested | Join path and ACK retry are mapped. Main risks: disconnect deletes `_old_unit` before later `setPos`, `WFBE_SE_PLAYERLIST` is not pruned, delayed UID/teamleader clearing lacks revalidation and ACK retry loops indefinitely. |
| Lorentz | `pvf-special-router-tag-audit` | Returned / summary harvested | PVF registration and dispatcher symbols still need cross-checking. Risks cluster around `RequestSpecial` authority, client-to-client `HandleSpecial`, raw supply PVs, `SEND_MESSAGE` compile, partial MASH and stale delegation/update scripts. |
| Hubble | `gear-loadout-easa-profile` | Returned / summary harvested | Gear/EASA/profile lifecycle is mapped. Patch candidates include undefined `_u_upgrade` in profile save, six-element template select risk, inclusive EquipBackpack/EquipVehicle loops, backpack cargo-size index issue, exact-funds EASA rejection and shared EASA/Economy `idd=23000`. |
| Banach | `supports-artillery-icbm-uav` | Returned / summary harvested | `RequestSpecial` trampoline and `Server_HandleSpecial` tags are mapped. Main risks: server trusts support payloads after client cost/cooldown checks, `NukeIncoming`/`ICBM_launched` look stale, missing `airRaid` agrees with the assets atlas and RU para ammo likely expects a commented-out config array. |
| Curie | `towns-camps-resistance-static-defense` | Returned / summary harvested | Town/camp/static-defense runtime is mapped. Findings: resistance side remains scaffold, GUER static defense/update-back is partial, town mortars are dead scaffold (`ManageTownMortars` not compiled and `Server_SpawnTownMortars.sqf` has undefined `_positions`), `townModeSet` is fragile, reward authority is client-side and town AI vehicle cleanup remains risky. |

Harvest rule: Wave N is not a replacement for owner pages. Promote Tesla into [WASP overlay](WASP-Overlay), Linnaeus into [Join/disconnect lifecycle](Player-Join-Disconnect-And-AntiStack-Lifecycle), Lorentz/Banach into [Networking/PV](Networking-And-Public-Variables) and [Support/specials/modules atlas](Support-Specials-And-Tactical-Modules-Atlas), Hubble into [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas), and Curie into [Towns/camps/capture atlas](Towns-Camps-And-Capture-Atlas) after spot-checking citations.

## Current Wave: Wave L

Spawned on this Codex session after Steff asked to bring an agent team back in for the owner-page follow-up pass. These six scouts were read-only and scoped to the highest-value Feature Status adjacent pages, while Codex kept edits, validation and publishing local. Reports have returned, the useful findings were harvested into owner pages and machine records, and the results were published to both the wiki and `docs/wiki` mirror.

| Agent | Lane | Status | Expected output |
| --- | --- | --- | --- |
| Confucius | `paratrooper-pv-status-drift` | Returned/harvested | Confirmed DR-2 is superseded for source Chernarus + maintained Vanilla Takistan; modded missing-handler drift and Arma smoke remain. |
| Pasteur | `easa-gear-client-menu-edges` | Returned/harvested | Added EASA exact-funds rejection, stale unsupported-vehicle no-op/debit risk, buy-detail price drift and special-vehicle UI incompleteness. |
| Beauvoir | `external-integrations-tooling-posture` | Returned/harvested | Corrected docs-CI posture, DiscordBot config source ambiguity, active `TypeNameHandling.All` reader risk, legacy x86 Extension build caveat and HC-count heuristic. |
| Dewey | `construction-coin-lifecycle-asymmetry` | Returned/harvested | Promoted SmallSite/MediumSite `wfbe_structures_logic` asymmetry, latent stock building repair and separate live WASP base-repair note. |
| Averroes | `server-runtime-supply-loop-followup` | Returned/harvested | Clarified post-game patrol loops as mostly inert polling, current-master supply duplicate-start risk and PR #1 handler separation. |
| Kuhn | `feature-status-wiki-llm-navigation` | Returned/harvested | Added release-readiness links, owner-page routing for gear/service/construction/support items and refreshed JSONL status drift. |

Harvest rule: Wave L findings were leads until Codex spot-checked high-risk claims. The owner-page harvest is now published and validated; remaining work is future Arma 2 OA smoke or code-owner implementation, not scout integration.

## Previous Wave: Wave K

Spawned on 2026-06-02 after Steff asked Codex to spin up an agent team to aid the feature-status/documentation work. All six scouts were read-only and returned. Codex harvested the findings into the Feature Status Register, UI docs, SQF/PV indexes, navigation pages and the new agent bootstrap file.

| Agent | Lane | Status | Integrated output |
| --- | --- | --- | --- |
| Hubble | `feature-status-evidence-hardening` | Returned/harvested | Corrected stale paratrooper/SQF atlas state, attack-wave PV direction, MASH marker nuance, resistance supply wording and compile counts. |
| Dirac | `server-runtime-partial-features` | Returned/harvested | Added supply completion-loop note, construction small-site stale-logic candidate, patrol game-over loop cleanup and HC delegation unevenness. |
| Lovelace | `client-ui-ux-partials` | Returned/harvested | Added command task UI partial, EASA/service edge routing and UI Risk Index links. |
| Nietzsche | `tooling-integrations-status` | Returned/harvested | Added DiscordBot command/config ambiguity, Extension build caveat, GLOBALGAMESTATS HC-count edge and docs-CI partial status. |
| Franklin | `agent-readable-pack` | Returned/harvested | Added `agent-entrypoint.json` and clarified machine-file/status vocabulary. |
| Linnaeus | `feature-status-navigation-bloat` | Returned/harvested | Added Feature Status quick jumps, stronger Continue Reading links and local-status section naming cleanup. |

Harvest rule: Wave K promoted only source-backed corrections and navigation/status improvements that had a clear owner page. Larger schema normalization remains a future machine-file cleanup lane.

## Previous Wave: Wave J

Spawned on 2026-06-02 after Steff asked Codex to spin up an agent team to aid the long-running developer-wiki goal. This wave was read-only and deliberately split into narrow lanes so Codex could keep editing/integration local. All six reports returned and were harvested into owner pages, status files and follow-up backlog notes.

| Agent | Lane | Status | Expected output |
| --- | --- | --- | --- |
| Socrates | `feature-status-evidence-audit` | Returned/integrated | Feature Status corrections for MASH/paratrooper/modded drift, task dormancy, PR #1 supply-heli separation, HQ authority wording, version/build inputs and BattlEye posture. |
| Tesla | `propagated-fix-smoke-gates` | Returned/integrated | Concrete smoke matrix for the five propagated fixes; folded into [Testing workflow](Testing-Debugging-And-Release-Workflow#propagated-fix-smoke-pack). |
| Boyle | `supply-mission-authority-and-abuse` | Returned/integrated | Supply start authority, split reward trust boundary, player-object disconnect leakage, cooldown casing and live-vs-dead scan scope folded into supply/lifecycle docs. |
| Zeno | `wiki-navigation-human-ai-ux` | Returned/partly integrated | No dead internal links found; Home wording, footer gaps and duplicate navigation were patched. Larger dashboard/sidebar slimming remains a later editorial lane. |
| Carver | `agent-readable-pack-validation` | Returned/integrated | JSON/JSONL parse state, snapshot-vs-log contract, release-readiness freshness and duplicate backlog-ID issue documented/patched. |
| Gibbs | `abandoned-partial-system-sweep` | Returned/integrated | MASH, map-icon tracking, TaskSystem, AT/bomb hooks, WASP startup, air-vehicle modification and AI logistics evidence folded into status/revival pages. |

Harvest rule: reports are leads until Codex promotes them into owner pages, [Feature status](Feature-Status-Register), [Progress dashboard](Progress-Dashboard) and machine-readable records. Agents do not edit files.

## Latest Harvest: Wave G

Spawned on 2026-06-02 after Steff asked Codex to bring an agent team back into the long-running archivist goal. These scouts are read-only and scoped to lanes that do not overlap with Codex's current integration work.

| Agent | Lane | Result |
| --- | --- | --- |
| Godel | `markers-cleaners-restorers-atlas-scout` | Integrated locally into [Marker cleanup/restoration atlas](Marker-Cleanup-Restoration-Systems-Atlas). |
| Rawls | `parameters-localization-build-scout` | Integrated locally into [Parameters/build inputs](Mission-Parameters-Localization-And-Generated-Build-Inputs). |
| Jason | `supports-specials-modules-scout` | Integrated locally into [Support/specials/modules atlas](Support-Specials-And-Tactical-Modules-Atlas). |
| Locke | `disconnect-join-antistack-lifecycle-scout` | Integrated locally into [Join/disconnect lifecycle](Player-Join-Disconnect-And-AntiStack-Lifecycle). |

Harvest rule: scout output becomes canonical only after Codex integrates it into the owning atlas, [Feature status](Feature-Status-Register) and machine-readable records with source evidence. Wave G has owner pages now; validation and mirror parity are the remaining gates.

## Latest Harvest: Wave I

Spawned on 2026-06-02 after Steff asked Codex to spin up another agent team. This wave deliberately uses small source-path-bounded scouts because previous broad scouts hit context limits.

| Agent | Lane | Status | Integrated output |
| --- | --- | --- | --- |
| Kepler | `economy-reward-integrity-small` | Harvested | Economy/score/funds/side-supply trust boundaries integrated into [Economy authority first cut](Economy-Authority-First-Cut), [Economy/towns/supply](Economy-Towns-And-Supply), [Public variable channel index](Public-Variable-Channel-Index) and [Feature status](Feature-Status-Register). |
| Kierkegaard | `ui-hud-dialog-feature-status-small` | Harvested | Stale upgrade resource, IDD collisions, RHUD ownership, service/EASA stale TODO and economy cleanup notes integrated into [Client UI systems atlas](Client-UI-Systems-Atlas) and [UI IDD collision repair](UI-IDD-Collision-Repair). |
| Copernicus | `antistack-database-identity-lifecycle-small` | Harvested | UID/object/owner identity model, launch-connect client-pushed signal and unchecked disconnect persistence integrated into [AntiStack database audit](AntiStack-Database-Extension-Audit) and [Join/disconnect lifecycle](Player-Join-Disconnect-And-AntiStack-Lifecycle). |
| Laplace | `commander-ai-autonomy-privilege-small` | Harvested | Human commander live vs AI autonomy partial split, commander percent/sell/MHQ repair authority edges integrated into [AI commander autonomy audit](AI-Commander-Autonomy-Audit) and [Commander/HQ lifecycle](Commander-HQ-Lifecycle-Atlas). |
| Aquinas | `respawn-mash-hq-marker-cleanup-small` | Harvested | Local MASH respawn vs dead marker sync, HQ marker cleanup/stale marker/resistance gap integrated into [Respawn/death lifecycle](Respawn-And-Death-Lifecycle-Atlas), [Commander/HQ lifecycle](Commander-HQ-Lifecycle-Atlas) and [Marker cleanup/restoration atlas](Marker-Cleanup-Restoration-Systems-Atlas). |
| n/a | `generated-mission-drift-small` | Could not spawn | Thread limit reached; Codex owns this deterministic local drift check. |

Harvest rule: keep reports compact, promote only source-backed findings into owner pages, then mirror them into `agent-feature-status.jsonl`, `agent-hardening-backlog.jsonl` or `agent-knowledge.jsonl` when they affect future work.

## Latest Harvest: Wave H

Spawned on 2026-06-02 after Steff asked for another agent team. The app hit its active thread limit after six scouts, so this wave is intentionally focused rather than huge.

| Agent | Lane | Status | Expected output |
| --- | --- | --- | --- |
| Huygens | `supply-mission-player-object-lifecycle-scout` | Harvested | Supply mission player-object lifecycle, reconnect/JIP hazards, stale rows and smoke gates; source player-object list index patch is now queued for propagation. |
| Popper | `economy-authority-and-reward-integrity-scout` | Closed after context error | Broad economy scout exceeded context; replaced by Wave I Kepler with a smaller scope. |
| Wegener | `respawn-mhq-hq-recovery-victory-scout` | Harvested | Reconfirmed victory/endgame correctness, PVF dispatch, HQ repair authority, respawn mode-5 edge, HQ-kill forwarding schema and dead MASH marker relay. |
| Dalton | `ui-dialogs-hud-ux-feature-status-scout` | Closed after context error | Broad UI/HUD ask exceeded context; split later into smaller UI slices such as IDD/resource collisions and menu-specific audits. |
| Darwin | `generated-mission-drift-and-propagation-scout` | Harvested | Confirmed source-only propagation matrix, LoadoutManager build configs, package scope, modded-generation disablement and literal-root blocker. |
| McClintock | `pvf-networking-attack-surface-scout` | Closed after context error | Original all-PVF ask exceeded context; replaced by the smaller direct-PV index scout below. |
| Euler | `direct-public-variable-index-scout-small` | Harvested | Top-risk direct `publicVariable*` index confirms attack-wave, supply mission, side-supply, AntiStack lifecycle, MASH marker and nuke/radiation channels need owner-page routing. |
| Aristotle | `high-impact-request-handler-authority-scout-small` | Harvested | Top registered request-handler authority risks are now reflected in [Networking/PV](Networking-And-Public-Variables) and [Server authority map](Server-Authority-Migration-Map): score, join, commander, MHQ repair, vehicle lock, base area and special-router paths. |

Harvest rule: wait for each report, spot-check high-risk claims, then integrate only into the owning page plus [Feature status](Feature-Status-Register), [Source fix queue](Source-Fix-Propagation-Queue) and machine files where relevant.

## Latest Harvest: Wave F

Spawned on 2026-06-02 after Steff re-shared three external research PDFs. All wave-F agents were read-only, have returned, and were closed after harvest.

| Agent | Lane | Result |
| --- | --- | --- |
| Anscombe | Mission lifecycle and entrypoints | Source-backed lifecycle context; no direct docs delta beyond existing lifecycle pages. |
| McClintock | PV/network authority | Confirmed PVF `Call Compile`; added `ATTACK_WAVE_INIT` client-supply authority gap. |
| Darwin | Economy/construction/factory authority | Confirmed client-led construction, upgrade, factory, service and economy paths. |
| Kierkegaard | Town AI/headless/performance | Confirmed static-defense HC sync partiality and HC/AI performance notes. |
| Avicenna | UI/HUD/dialogs | Confirmed player menu graph, stale upgrade dialog and hardcoded Help/localization debt. |
| Beauvoir | Support modules | Confirmed truck-only master supply baseline, MASH marker breakage, AFK/AntiStack/FPS/ICBM support status. |
| Dalton | Tooling/integrations | Confirmed LoadoutManager path/`7za` assumptions, DiscordBot config, Extension vs AntiStack split. |
| Dewey | External PDF claim triage | Found PDFs mostly covered; promoted JIP wait-chain polish and town-AI passenger-despawn verification. |
| Einstein | Town-AI vehicle safety verifier | Confirmed `server_town_ai.sqf` can delete occupied vehicles when the player is not group leader. |
| Bernoulli | Lifecycle wait-chain audit | Produced post-join wait table now integrated into [Lifecycle wait-chain](Lifecycle-Wait-Chain). |

## Current Pool

| Agent | Lane | Status | Expected output |
| --- | --- | --- | --- |
| Codex | `integration-backlog-batch-a` | Active integrator | Scout wave harvested; integrate PV/network trust and external integration/AntiStack first, then publish clean batches. |
| Sagan | `external-pdf-analytisch-rapport` | Report received | External PDF digest captured in [External research reports](External-Research-Reports). |
| Helmholtz | `external-pdf-analyse` | Report received | External PDF digest captured in [External research reports](External-Research-Reports). |
| Parfit | `external-pdf-diepgaande-analyse` | Report received | External PDF digest captured in [External research reports](External-Research-Reports). |
| Turing | `generated-output-parity-check-v2` | Report received | Source/generated/modded mission drift, docs mirror parity and generation-rule report. |
| Dirac | `assets-audio-textures-identity-v2` | Report received | Music, sounds, textures, identities, load screens, briefing assets and missing/stale asset report. |
| Gibbs | `server-config-hosting-be-v2` | Report received | Server configs, BattlEye filters, ServerInfo, hosting/deploy assumptions and ops-risk report. |
| Plato | `loadoutmanager-generator-deeper-v2` | Report received | LoadoutManager internals, terrain copy rules, generated SQF and package workflow report. |
| Epicurus | `towns-camps-depots-economy-v2` | Report received | Town capture, camps/depots, supply values, occupation and economy edge report. |
| Hooke | `support-artillery-uav-paradrop-v2` | Report received | Artillery, ICBM, UAV, IRS, countermeasures, paradrop/paratroopers, mines and tactical support report. |
| Carson | `cleanup-maintenance-runtime-v2` | Report received | Garbage collector, empty vehicles, mines, craters, ruins, building restorer and object lifecycle report. |
| Aquinas | `stringtable-localization-copy-v2` | Report received | Stringtable/UI text, side messages, hints, stale copy and localization gap report. |
| Russell | `server-fsm-runtime-orchestration-v2` | Report received | Server FSM/runtime orchestration, cleanup, victory/disconnect/FPS and missing-FSM report. |
| Galileo | `common-pv-network-authority-v2` | Report received | Common/PV/network authority, SendToClient/Server, funds/message and JIP-safety report. |
| Ptolemy | `boot-include-parameter-graph-v2` | Report received | Boot/include graph, init order, parameters, constants and version/include report. |
| Boole | `commander-construction-factory-v2` | Report received | Commander, CoIn, construction, factories, service points, base destruction and buy queue report. |
| Faraday | `discord-extension-antistack-integration-discovery` | Report received | Extension, DiscordBot, AntiStack DB, BattlEye and external trust report. |
| Mencius | `parameters-config-localization-discovery` | Report received | Parameters, defaults, includes, version files and localization report. |
| Hilbert | `abandoned-code-missing-reference-discovery` | Report received | Commented compiles, missing scripts, TODOs, dead PV handlers and stale leftovers report. |
| Cicero | `ai-headless-delegation-discovery` | Report received | AI squads, autonomous teams, AI commander, HC delegation and town AI report. |
| Curie | `wiki-ux-phase2-agent-interface-discovery` | Report received | Concrete implementation checklist for human + LLM wiki UX improvements. |
| Meitner | `pr1-supply-helicopter-delta-discovery` | Report received | PR #1 supply-helicopter branch delta, deferred AI work and merge-risk report. |
| Archimedes/James | `pv-matrix-second-pass-v2` | Report received | Full PV matrix plus compact wiki table layout. |
| Wegener | `ai-commander-autonomy-second-pass-v2` | Report received | AI commander/autonomous team scheduler and dormant-worker evidence. |
| Rawls | `wiki-agent-artifact-schema-v2` | Report received | Agent-readable artifact schema proposal. |
| Goodall | `known-broken-reference-second-pass-v2` | Report received | Unified missing/stale/broken reference register. |
| Euclid | `modded-presentation-parity-v2` | Report received | Modded presentation/media/help parity report. |
| Aristotle | `supply-mission-authority-matrix-v2` | Report received | Master + PR #1 supply mission authority matrix. |

## Rotation Queue

Wave I is harvested. Next scout wave should be smaller again, and should wait until validation/mirror parity is clean unless Steff explicitly asks for more parallel discovery.

| Priority | Lane | Scope |
| --- | --- | --- |
| 1 | `integration-backlog-batch-a` | PV/network trust, PV matrix, direct non-PVF events, and command-forgery cross-links. |
| 2 | `integration-backlog-batch-b` | External integrations: AntiStack DB, in-repo Extension, DiscordBot, BattlEye and missing hosting files. |
| 3 | `integration-backlog-batch-c` | Construction/factory/economy authority and commander/AI partials. |
| 4 | `integration-backlog-batch-d` | Supply mission master + PR #1 matrix, support markers and broken-reference register. |

## Reports Waiting For Integration

| Lane | Agent | Status | Integration targets |
| --- | --- | --- | --- |
| `client-jip-lifecycle-discovery` | Mencius | Report received | [Mission lifecycle](Mission-Entrypoints-And-Lifecycle), [Lifecycle wait-chain](Lifecycle-Wait-Chain), [Client UI systems atlas](Client-UI-Systems-Atlas), [Feature status](Feature-Status-Register), [`agent-context.json`](agent-context.json). |
| `economy-town-factory-upgrade-discovery` | Faraday | Report received | [Economy/towns/supply](Economy-Towns-And-Supply), [Factory/purchase atlas](Factory-And-Purchase-Systems-Atlas), [Server runtime atlas](Server-Gameplay-Runtime-Atlas), [Feature status](Feature-Status-Register), [`agent-context.json`](agent-context.json). |
| `gear-loadout-easa-balance-discovery` | Faraday | Integrated locally; publish pending | [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas), [Client UI systems atlas](Client-UI-Systems-Atlas), [Tools/build](Tools-And-Build-Workflow), [Feature status](Feature-Status-Register), [`agent-context.json`](agent-context.json). |
| `external-pdf-research-intake` | Sagan/Helmholtz/Parfit | Captured; source reconciliation pending | [External research reports](External-Research-Reports), [Feature status](Feature-Status-Register), [Deep-review findings](Deep-Review-Findings), [`agent-context.json`](agent-context.json). |
| `discord-extension-antistack-integration-discovery` | Faraday | Integrated | [External integrations](External-Integrations), [Networking/PV](Networking-And-Public-Variables), [Feature status](Feature-Status-Register), [`agent-context.json`](agent-context.json). |
| `respawn-medical-mash-support-discovery` | Mencius | Report received | [Gameplay atlas](Gameplay-Systems-Atlas), [Client UI systems atlas](Client-UI-Systems-Atlas), [Feature status](Feature-Status-Register), [`agent-context.json`](agent-context.json). |
| `server-runtime-scheduler-discovery` | Hilbert | Report received | [Server runtime atlas](Server-Gameplay-Runtime-Atlas), [AI/performance](AI-Headless-And-Performance), [Feature status](Feature-Status-Register), [`agent-context.json`](agent-context.json). |
| `abandoned-code-missing-reference-discovery` | Hilbert | Report received | [Feature status](Feature-Status-Register), [Mission lifecycle](Mission-Entrypoints-And-Lifecycle), [Networking/PV](Networking-And-Public-Variables), [`agent-context.json`](agent-context.json). |
| `server-fsm-runtime-orchestration-v2` | Russell | Report received | [Server runtime atlas](Server-Gameplay-Runtime-Atlas), [Lifecycle wait-chain](Lifecycle-Wait-Chain), [Feature status](Feature-Status-Register), [`agent-context.json`](agent-context.json). |
| `common-pv-network-authority-v2` | Galileo | Integrated | [Networking/PV](Networking-And-Public-Variables), [Deep-review findings](Deep-Review-Findings), [Function/module index](Function-And-Module-Index), [`agent-context.json`](agent-context.json). |
| `boot-include-parameter-graph-v2` | Ptolemy | Report received | [Mission lifecycle](Mission-Entrypoints-And-Lifecycle), [Lifecycle wait-chain](Lifecycle-Wait-Chain), [SQF code atlas](SQF-Code-Atlas), [`agent-context.json`](agent-context.json). |
| `commander-construction-factory-v2` | Boole | Report received | [Construction/CoIn atlas](Construction-And-CoIn-Systems-Atlas), [Factory/purchase atlas](Factory-And-Purchase-Systems-Atlas), [Client UI systems atlas](Client-UI-Systems-Atlas), [`agent-context.json`](agent-context.json). |
| `towns-camps-depots-economy-v2` | Epicurus | Report received | [Economy/towns/supply](Economy-Towns-And-Supply), [Gameplay atlas](Gameplay-Systems-Atlas), [Server runtime atlas](Server-Gameplay-Runtime-Atlas), [`agent-context.json`](agent-context.json). |
| `support-artillery-uav-paradrop-v2` | Hooke | Report received | [Gameplay atlas](Gameplay-Systems-Atlas), [Client UI systems atlas](Client-UI-Systems-Atlas), [Networking/PV](Networking-And-Public-Variables), [`agent-context.json`](agent-context.json). |
| `cleanup-maintenance-runtime-v2` | Carson | Report received | [Server runtime atlas](Server-Gameplay-Runtime-Atlas), [AI/performance](AI-Headless-And-Performance), [Feature status](Feature-Status-Register), [`agent-context.json`](agent-context.json). |
| `stringtable-localization-copy-v2` | Aquinas | Report received | [Content/maps](Content-Structure-And-Maps), [Client UI systems atlas](Client-UI-Systems-Atlas), [Feature status](Feature-Status-Register), [`agent-context.json`](agent-context.json). |
| `wiki-ux-navigation-discovery` | Curie | Report received | [Home](Home), [Quickstart](Quickstart-For-Humans-And-Agents), [Progress dashboard](Progress-Dashboard), [`agent-context.json`](agent-context.json). |
| `wiki-ux-phase2-agent-interface-discovery` | Curie | Report received | [Home](Home), [Progress dashboard](Progress-Dashboard), [Agent collaboration protocol](Agent-Collaboration-Protocol), [`agent-context.json`](agent-context.json). |
| `content-drift-generation-discovery` | Meitner | Report received | [Content/maps](Content-Structure-And-Maps), [Tools/build](Tools-And-Build-Workflow), [Feature status](Feature-Status-Register), [`agent-context.json`](agent-context.json). |
| `pr1-supply-helicopter-delta-discovery` | Meitner | Report received | [Supply mission architecture](Supply-Mission-Architecture), [Current supply-heli PR](Current-Work-Supply-Helicopters-PR1), [Feature status](Feature-Status-Register), [`agent-context.json`](agent-context.json). |
| `pv-matrix-second-pass-v2` | Archimedes/James | Integrated | [Networking/PV](Networking-And-Public-Variables), [Function/module index](Function-And-Module-Index), [`agent-context.json`](agent-context.json). |
| `ai-commander-autonomy-second-pass-v2` | Wegener | Report received | [AI/headless/performance](AI-Headless-And-Performance), [Server runtime atlas](Server-Gameplay-Runtime-Atlas), [Feature status](Feature-Status-Register). |
| `wiki-agent-artifact-schema-v2` | Rawls | Report received | [Agent collaboration protocol](Agent-Collaboration-Protocol), [Agent context](Agent-Context), [`agent-context.json`](agent-context.json). |
| `known-broken-reference-second-pass-v2` | Goodall | Report received | [Feature status](Feature-Status-Register), [Mission lifecycle](Mission-Entrypoints-And-Lifecycle), [Client UI systems atlas](Client-UI-Systems-Atlas), [Content/maps](Content-Structure-And-Maps). |
| `modded-presentation-parity-v2` | Euclid | Report received | [Content/maps](Content-Structure-And-Maps), [Client UI systems atlas](Client-UI-Systems-Atlas), [Source inventory](Source-Inventory). |
| `supply-mission-authority-matrix-v2` | Aristotle | Report received | [Supply mission architecture](Supply-Mission-Architecture), [Current supply-heli PR](Current-Work-Supply-Helicopters-PR1), [Feature status](Feature-Status-Register). |

## Integration Rules

- Scouts do not edit files, commit, push or publish.
- Codex should trust scout source citations, then spot-check high-risk claims before adding them to user-facing docs.
- Findings should land in the owning atlas page first, then in [Feature status](Feature-Status-Register), [Coverage ledger](Codebase-Coverage-Ledger), [Agent worklog](Agent-Worklog) and machine files if relevant.
- If Claude is working the same subsystem, prefer adding a handoff note instead of overwriting Claude-owned review pages.

## Continue Reading

Previous: [Progress dashboard](Progress-Dashboard) | Next: [Coordination board](Coordination-Board)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-status.json`](agent-status.json)
