# Progress Dashboard

This is the shared human + AI interface for seeing what Codex, Claude and Codex sub-agents are doing right now.

Keep this page open when parallel documentation work is running. It links to the live board, the event feed and the compact JSON status file so you do not have to click through the sidebar every time.

## At A Glance

| Agent | Status | Current lane | What to expect next |
| --- | --- | --- | --- |
| Codex | Active | `feature-status-reconciliation` + `cheap-explorer-wave-e` | Folding Claude DR-32 through DR-37 and fresh cheap explorer wave E into owner pages, direct-PV replay docs and machine-readable context. |
| Godel | Integrated locally | `ui-jip-hc-review-wave-e` | UI JIP/HC reviewed clean; stale `RscMenu_Upgrade` remains the only concrete UI orphan and is already documented. |
| Gauss | Integrated locally | `wasp-overlay-jip-locality-wave-e` | WASP live/dead split and HQ-recovery locality notes folded into [WASP overlay](WASP-Overlay) and [Feature status](Feature-Status-Register). |
| Popper | Integrated locally | `modules-support-status-wave-e` | Module gate/status table and paratrooper/MASH marker confirmations folded into [Function/module index](Function-And-Module-Index) and [Feature status](Feature-Status-Register). |
| Locke | Integrated locally | `direct-pv-replay-semantics-wave-e` | Direct publicVariable replay/JIP semantics folded into [Networking/PV](Networking-And-Public-Variables). |
| Planck | Integrated locally | `generated-mission-docs-qa-wave-e` | Generated mission tiers, `version.sqf` status and checkout path warning sharpened in [Content/maps](Content-Structure-And-Maps) and [Tools](Tools-And-Build-Workflow). |
| Schrodinger | Integrated locally | `agent-readable-docs-qa-wave-e` | Added compact `openLanes`, `coordinationProtocol` and PR #1 supply-heli context to [`agent-context.json`](agent-context.json). |
| Sagan | Report received | `external-pdf-analytisch-rapport` | Digested `Analytisch rapport over rayswaynl_a2waspwarfare.pdf`; claims captured in [External research reports](External-Research-Reports). |
| Helmholtz | Report received | `external-pdf-analyse` | Digested `Analyse van rayswaynl_a2waspwarfare.pdf`; many claims overlap existing source-backed findings. |
| Parfit | Report received | `external-pdf-diepgaande-analyse` | Digested `Diepgaande analyse van rayswaynl_a2waspwarfare.pdf`; security/network leads captured for verification. |
| Erdos | Active | `external-pdf-architecture-reconcile-v2` | Rechecking PDF architecture/lifecycle/bootstrap claims against source. |
| Arendt | Active | `external-pdf-feature-status-reconcile-v2` | Rechecking PDF broken/partial/abandoned/missing feature claims against source. |
| Carver | Active | `external-pdf-security-integration-reconcile-v2` | Rechecking PDF server/security/networking/external integration claims against source. |
| Laplace | Active | `external-pdf-ui-wiki-ux-reconcile-v2` | Checking report UI/HUD/wiki UX implications for source-backed or navigation updates. |
| Tesla | Active | `agent-readable-artifact-v3` | Designing the next practical machine-readable artifact/schema for future AI development work. |
| Archimedes | Integrated | `pv-matrix-second-pass-v2` | Full PV/direct-channel matrix folded into [Networking/PV](Networking-And-Public-Variables). |
| Wegener | Report received | `ai-commander-autonomy-second-pass-v2` | AI commander scheduler absence and dormant upgrade worker await integration into AI/headless docs. |
| Rawls | Report received | `wiki-agent-artifact-schema-v2` | Proposed agent-readable artifact schemas await integration into collaboration protocol/context. |
| Goodall | Report received | `known-broken-reference-second-pass-v2` | Unified broken-reference register awaits integration into feature status and owning atlases. |
| Euclid | Report received | `modded-presentation-parity-v2` | Modded presentation/media parity findings await integration into content/maps. |
| Aristotle | Report received | `supply-mission-authority-matrix-v2` | Master + PR #1 supply mission authority matrix awaits integration into supply docs. |
| Turing | Report received | `generated-output-parity-check-v2` | Chernarus/Takistan parity is clean except skipped `loadScreen.jpg`; modded trees are stale with uneven file counts. |
| Dirac | Report received | `assets-audio-textures-identity-v2` | Asset inventory, intro/outro wiring, malformed `soundPush`, shared overlay IDD and naming mismatch await integration. |
| Gibbs | Report received | `server-config-hosting-be-v2` | Missing `ServerInfo`, absent server.cfg/basic.cfg/scripts.txt, minimal BattlEye filter and external DLL assumptions await integration. |
| Newton | Partly integrated | `known-broken-reference-second-pass-v2` | AI supply truck, MASH marker and stale upgrade-dialog evidence folded into [Feature status](Feature-Status-Register), runtime and lifecycle pages. |
| Ampere | Integrated | `server-fsm-runtime-orchestration-v2` | Runtime loop roster, hosted FPS risk and AI supply truck missing FSM path folded into [Server runtime](Server-Gameplay-Runtime-Atlas). |
| Pascal | Integrated | `boot-include-parameter-graph-v2` | Include/init graph, wait gates, parameter overrides and missing root `version.sqf` folded into [Mission lifecycle](Mission-Entrypoints-And-Lifecycle) and [Feature status](Feature-Status-Register). |
| Boyle | Integrated | `ai-commander-autonomy-second-pass-v2` | Live AI upgrade worker/funds, partial autonomy, commander assignment bug and HC failover gap folded into [AI/headless](AI-Headless-And-Performance), runtime and function index. |
| Peirce | Integrated | `server-config-hosting-be-v2` | Missing server config bundle and no shipped BattlEye hardening folded into [External integrations](External-Integrations) and [Feature status](Feature-Status-Register). |
| Plato | Report received | `loadoutmanager-generator-deeper-v2` | Generator outputs, skip rules, Takistan propagation, stale modded path, 7za packaging and CRV7PG warning await integration. |
| Epicurus | Report received | `towns-camps-depots-economy-v2` | Town/camp capture lifecycle, depot/service role, supply/economy links, cooldown casing and AI supply partials await integration. |
| Hooke | Report received | `support-artillery-uav-paradrop-v2` | Support matrix, tactical hub, artillery/ICBM/UAV/IRS/CM status and paratrooper marker wiring issue await integration. |
| Carson | Report received | `cleanup-maintenance-runtime-v2` | Cleanup/object lifecycle queues, cadences, scan costs and fragile mine/empty-vehicle contracts await integration. |
| Aquinas | Report received | `stringtable-localization-copy-v2` | `stringtable.xml` status, hardcoded English, stale help text, bad/missing localization keys await integration. |
| Russell | Report received | `server-fsm-runtime-orchestration-v2` | Server bootstrap/runtime loop roster, duplicate FPS publishers, live `UpdateSupplyTruck` call and missing `supplytruck.fsm` await integration. |
| Galileo | Report received | `common-pv-network-authority-v2` | PVF architecture, thin server request handlers, JIP live-only broadcasts and local funds mutation report awaits integration. |
| Ptolemy | Report received | `boot-include-parameter-graph-v2` | Boot/include graph, role init order, wait gates and missing root `version.sqf` report awaits integration. |
| Boole | Report received | `commander-construction-factory-v2` | Commander/CoIn/factory authority split, latent `AIBuyUnit`, commander bug and service menu report awaits integration. |
| Faraday | Integrated | `discord-extension-antistack-integration-discovery` | Extension, DiscordBot, AntiStack DB, BattlEye and external trust report folded into [External integrations](External-Integrations). |
| Mencius | Report received | `parameters-config-localization-discovery` | Parameters/default mismatch, hidden runtime knobs, missing `version.sqf`, partial MASH marker and hardcoded help strings await integration. |
| Hilbert | Report received | `abandoned-code-missing-reference-discovery` | Missing root version include, unregistered paratrooper marker PV, partial MASH marker relay and WASP leftovers await integration. |
| Cicero | Report received | `ai-headless-delegation-discovery` | AI/headless delegation, partial AI commander, stale AI supply trucks, patrol timestamp issue and HC/client delegation risks await integration. |
| Curie | Report received | `wiki-ux-phase2-agent-interface-discovery` | Task navigation map, related-page blocks, dashboard mini-panel and artifact schema checklist awaits implementation. |
| Meitner | Report received | `pr1-supply-helicopter-delta-discovery` | PR #1 supply-helicopter branch delta, handler leak, cooldown casing and propagation-risk report awaits integration. |
| Claude | Ready-for-review + autonomous-ready | `discord-datapath-review` / DR-31 | DR-27 through DR-31 are folded or cross-linked into owner pages: [Networking/PV](Networking-And-Public-Variables), [External integrations](External-Integrations), [Economy](Economy-Towns-And-Supply), [Gear/EASA](Gear-Loadout-And-EASA-Atlas) and [Feature status](Feature-Status-Register). |
| Shared docs | Live | `docs/wiki` mirror plus GitHub wiki | Navigation, worklog, event feed and machine files should move together after validation. |

## One-Link Check

| Need | Open |
| --- | --- |
| Human progress page | [Progress dashboard](Progress-Dashboard) |
| Sub-agent swarm board | [Discovery swarm](Subagent-Discovery-Swarm) |
| Detailed coordination page | [Coordination board](Coordination-Board) |
| Machine progress file | [`agent-status.json`](agent-status.json) |
| Active lanes and ownership | [`agent-collaboration.json`](agent-collaboration.json) |
| Agent-readable knowledge records | [`agent-knowledge.jsonl`](agent-knowledge.jsonl) |
| Latest event stream | [`agent-events.jsonl`](agent-events.jsonl) |
| Dated narrative notes | [Agent worklog](Agent-Worklog) |
| External PDF intake | [External research reports](External-Research-Reports) |

## Current Lanes

| Lane | Owner | Status | Meaning |
| --- | --- | --- | --- |
| `factory-purchase-atlas` | Codex | Integrated | Codex published [Factory and purchase systems atlas](Factory-And-Purchase-Systems-Atlas). |
| `gear-loadout-easa-atlas-integration` | Codex | Integrated | Codex published [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas) and linked the risk/register updates. |
| `external-pdf-research-intake` | Codex + Sagan/Helmholtz/Parfit + Claude | Integrated | Three Steff-provided PDF reports were digested, then Claude clarified they are downstream corroboration; see [External research reports](External-Research-Reports). |
| `external-pdf-reconciliation-wave-d` | Codex + Erdos/Arendt/Carver/Laplace/Tesla | Active | PDFs were extracted to `outputs/external-reports/`; second cheap explorer wave is reconciling report claims with repo evidence and agent-readable artifact needs. |
| `cheap-explorer-wave-e` | Codex + Godel/Gauss/Popper/Locke/Planck/Schrodinger | Integrated locally | Remaining thin cells reviewed: UI JIP/HC clean, WASP locality, modules/support gates, direct-PV replay semantics, generated-mission docs QA and agent-readable schema gaps. |
| `cheap-discovery-swarm-v2` | Codex | Harvested | Cheap scout wave is complete; no active scout slots remain. |
| `integration-backlog-batch-a` | Codex | Active | PV matrix, external integration trust and DR-27 through DR-31 have landed; next batch should continue explorer-wave reports and lower-risk atlas polish. |
| `cheap-explorer-wave-c` | Codex | Mostly integrated | Newton, Ampere, Pascal, Boyle and Peirce are folded into owner pages; Linnaeus supply-mission report is still expected or pending capture. |
| `pv-matrix-second-pass-v2` | Archimedes/James | Integrated | Full PV matrix and compact wiki table layout folded into [Networking/PV](Networking-And-Public-Variables). |
| `ai-commander-autonomy-second-pass-v2` | Wegener/Boyle | Integrated | Scout reports reconciled: AI commander has live state/funds and upgrade worker, but no proven end-to-end autonomous scheduler. |
| `wiki-agent-artifact-schema-v2` | Rawls | Reported, pending integration | Scout report received: JSON/JSONL schemas for findings, lane reports, PV entries, risks, atlas metadata and handoffs. |
| `known-broken-reference-second-pass-v2` | Goodall/Newton | Partly integrated | High-confidence broken refs promoted: generated `version.sqf`, AI supply truck, MASH marker listener and stale upgrade dialog. Lower-risk resource/localization items remain queued. |
| `modded-presentation-parity-v2` | Euclid | Reported, pending integration | Scout report received: Chernarus full asset baseline; Napf stale with conflict markers; other modded missions partial/hand-maintained. |
| `supply-mission-authority-matrix-v2` | Aristotle | Reported, pending integration | Scout report received: master truck flow, PR #1 heli/cash/interdiction delta, cooldown race, object-var trust and AI deferral. |
| `generated-output-parity-check-v2` | Turing | Reported, pending integration | Scout report received: Chernarus/Takistan parity clean except skipped `loadScreen.jpg`; modded folders stale/non-authoritative. |
| `assets-audio-textures-identity-v2` | Dirac | Reported, pending integration | Scout report received: asset inventory, intro/outro wiring, malformed `soundPush`, shared overlay IDD and music naming mismatch. |
| `server-config-hosting-be-v2` | Gibbs/Peirce | Integrated | Missing server configs/scripts.txt, minimal BattlEye PV filter and external deployment assumptions are folded into External/Feature pages and Claude DR-30. |
| `loadoutmanager-generator-deeper-v2` | Plato | Reported, pending integration | Scout report received: generator outputs, skip/blacklist rules, stale modded path, 7za behavior and CRV7PG warning classes. |
| `towns-camps-depots-economy-v2` | Epicurus | Reported, pending integration | Scout report received: town/camp capture, depot/service role, supply economy, cooldown casing and AI supply partials. |
| `support-artillery-uav-paradrop-v2` | Hooke | Reported, pending integration | Scout report received: artillery, ICBM, UAV, IRS, countermeasures, paradrops, tactical hub and paratrooper marker wiring. |
| `cleanup-maintenance-runtime-v2` | Carson | Reported, pending integration | Scout report received: cleanup/object lifecycle ownership, cadences, large-radius scans, queues and fragile contracts. |
| `stringtable-localization-copy-v2` | Aquinas | Reported, pending integration | Scout report received: `stringtable.xml` source, hardcoded English, stale help text, mistranslated Russian entries and missing key. |
| `server-fsm-runtime-orchestration-v2` | Russell/Ampere | Integrated | Server loop roster, cleanup/runtime flow, hosted FPS publishers, live `UpdateSupplyTruck` call and missing `supplytruck.fsm` folded into runtime docs. |
| `common-pv-network-authority-v2` | Galileo | Reported, pending integration | Scout report received: PVF registration/transport/dispatch architecture, thin request handlers, live-only broadcasts and funds locality. |
| `boot-include-parameter-graph-v2` | Ptolemy/Pascal | Integrated | `description.ext -> initJIPCompatible -> Common/Towns -> role init`, wait gates, parameter gates and generated `version.sqf` folded into lifecycle docs. |
| `commander-construction-factory-v2` | Boole | Reported, pending integration | Scout report received: client/server authority split, CoIn, factories, service UX, latent `AIBuyUnit` and commander assignment bug. |
| `victory-endgame-runtime-atlas` | Codex | Paused | Victory/endgame mapping is temporarily paused while gear/EASA integration and swarm refresh are published. |
| `economy-town-factory-upgrade-discovery` | Faraday | Reported, pending integration | Scout report received; Codex should integrate negative supply delta, upgrade authority, resistance supply handler gap and AI supply truck evidence. |
| `gear-loadout-easa-balance-discovery` | Faraday | Integrated locally, publish pending | Scout report produced the new [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas) and linked risk/register updates. |
| `discord-extension-antistack-integration-discovery` | Faraday | Integrated | Extension/DiscordBot/AntiStack/BattlEye trust boundaries and callExtension contracts folded into [External integrations](External-Integrations). |
| `modules-review-dr27` | Claude + Codex | Integrated | Critical ICBM/Nuke `RequestSpecial` authority finding folded into [Networking/PV](Networking-And-Public-Variables) and [Feature status](Feature-Status-Register). |
| `client-jip-lifecycle-discovery` | Mencius | Reported, pending integration | Scout report received; Codex should integrate duplicated `Skill_Init`, legacy WASP leftovers, join ACK sensitivity and respawn-loop cost. |
| `respawn-medical-mash-support-discovery` | Mencius | Reported, pending integration | Scout report received; Codex should integrate respawn source precedence, MASH marker half-wiring and support authority notes. |
| `parameters-config-localization-discovery` | Mencius | Reported, pending integration | Scout report received for parameters, defaults, includes, version files and localization/string resources. |
| `server-runtime-scheduler-discovery` | Hilbert | Reported, pending integration | Scout report received; Codex should integrate cleanup loops, FPS publishers, inverse sleep risk and missing supplytruck FSM evidence. |
| `abandoned-code-missing-reference-discovery` | Hilbert | Reported, pending integration | Scout report received: missing `version.sqf`, unregistered paratrooper marker PV, partial MASH marker relay, stale WASP leftovers. |
| `ai-headless-delegation-discovery` | Cicero | Reported, pending integration | Scout report received for AI teams, AI commander, HC delegation and town AI lifecycle. |
| `wiki-ux-navigation-discovery` | Curie | Reported, pending integration | Scout report received; Codex should add task-oriented navigation, related-page blocks and a dashboard mini-panel. |
| `wiki-ux-phase2-agent-interface-discovery` | Curie | Reported, pending integration | Scout report received: task map, related-page blocks, dashboard mini-panel and artifact schema checklist. |
| `content-drift-generation-discovery` | Meitner | Reported, pending integration | Scout report received; Codex should integrate source/generated/stale mission folder and generation-rule findings. |
| `pr1-supply-helicopter-delta-discovery` | Meitner | Reported, pending integration | Scout report received: PR branch diff, heli mechanics, handler stacking risk, cooldown casing, authority and propagation notes. |
| `network-pv-boundary-deep-index` | Hilbert | Completed + integrated | Direct PV channels and registered-command forgery risks are now documented. |
| `server-gameplay-loops-deep-index` | Cicero | Completed + integrated | Server runtime atlas added for town/economy/AI/supply/performance loops. |
| `ui-hud-dialogs-deep-index` | Curie | Completed + integrated | Stale upgrade dialog, duplicate IDDs, suspect control config and buy-gear partials are documented. |
| `tooling-integrations-deep-index` | Meitner | Completed + integrated | LoadoutManager run hazards, generated mission rules and extension-to-Discord flow are documented. |
| `autonomous-claude-research` | Claude | Open | Claude can self-select the next subsystem/risk lane and keep going after a pass finishes. |
| `pvf-hardening-review` | Claude | Ready-for-review | Claude published a behavior-preserving PVF dispatch hardening playbook in [Deep-review findings](Deep-Review-Findings). |
| `victory-endgame-review` | Claude | Ready-for-review | Claude published DR-11..DR-13 on winner inversion, broken threeway mode and stale `LogGameEnd`. |
| `factory-purchase-authority` | Claude | Ready-for-review | Claude published DR-14..DR-15 on client-authoritative purchasing and the commander assignment bug. |
| `feature-status-reconciliation` | Codex | Open | Codex should keep folding confirmed findings into owning atlas/risk pages. |

## Update Ritual

| Moment | Codex / Claude action | Human-visible result |
| --- | --- | --- |
| Starting work | Update `agent-collaboration.json` and append a `claim` event. | This dashboard and the coordination board show who owns what. |
| Still working after a long pass | Append a `heartbeat` event. | You can see that an agent is alive and where it is reading. |
| Finding a source-backed issue | Append a `finding` event and add a short worklog note. | The finding is visible even before the full page is integrated. |
| Finishing a lane | Append a `complete` event, update affected pages and note validation status. | The lane moves from active to ready/integrated. |
| Handing off | Append a `handoff` event with the exact next action. | The other agent can pick it up without chat memory. |

## Status Legend

| Status | Meaning |
| --- | --- |
| `active` | Someone is working this lane now. |
| `open` | Available for an agent to claim. |
| `ready-for-review` | Work exists but should be checked before publishing or relying on it. |
| `integrated` | Published into the wiki/docs set and reflected in navigation/context. |
| `blocked` | Needs user input, missing access or an external state change. |

## For Agents

1. Load [`agent-status.json`](agent-status.json), [`agent-collaboration.json`](agent-collaboration.json), [`agent-knowledge.jsonl`](agent-knowledge.jsonl), [`agent-events.jsonl`](agent-events.jsonl) and [Agent collaboration protocol](Agent-Collaboration-Protocol) before claiming work.
2. Treat `agent-events.jsonl` as append-only.
3. Keep claims bounded by source scope.
4. Never overwrite another agent's page or navigation changes from a stale branch.
5. Publish human notes to [Agent worklog](Agent-Worklog) and machine notes to the JSON files.

## Continue Reading

Previous: [Agent context](Agent-Context) | Next: [Coordination board](Coordination-Board)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
