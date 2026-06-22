# LLM Agent Entry Pack

This is the compact operating brief for Codex, Claude and other AI assistants working on `rayswaynl/a2waspwarfare`.

Use this page first, then jump into the canonical pages and machine files it names. Do not treat this as a substitute for reading source before making code changes.

## Load Order

1. Read [`agent-entrypoint.json`](agent-entrypoint.json) for the compact machine-readable bootstrap and status vocabulary.
2. Read [`llms.txt`](llms.txt) for the high-level map.
3. Read [`agent-context.json`](agent-context.json) for the larger current repo rules and page inventory snapshot.
4. Read [`agent-machine-index.json`](agent-machine-index.json) when you need the shortest page-to-source/risk lookup.
5. Read [Feature status register](Feature-Status-Register) for current risk/partial/broken-system triage.
6. Read [`agent-feature-status.jsonl`](agent-feature-status.jsonl) for compact feature/risk status and canonical page routing.
7. Read [`agent-release-readiness.json`](agent-release-readiness.json) before claiming any source fix is propagated, smoked or release-complete.
8. Read [Progress dashboard](Progress-Dashboard), [`agent-status.json`](agent-status.json) and [`agent-events.jsonl`](agent-events.jsonl) to avoid duplicating active lanes.
9. Read [Arma 2 OA compatibility audit](Arma-2-OA-Compatibility-Audit) and [`agent-compatibility-audit.json`](agent-compatibility-audit.json) before accepting docs or prompts that mention Arma 3-era APIs.
10. Read the subsystem atlas/playbook for the thing you intend to change.
11. Inspect source directly before patching. The docs are guidance; the worktree is authoritative.

## Non-Negotiable Rules

| Rule | Why |
| --- | --- |
| Start gameplay edits in `Missions/[55-2hc]warfarev2_073v48co.chernarus`. | This is the source mission. |
| Treat `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan` as generated/copy output. | Propagation should happen through `Tools/LoadoutManager`, not hand-edited drift. |
| Do not claim Vanilla propagation unless LoadoutManager ran and generated diffs were inspected. | Current source/stable/Miksuu/perf need an `a2waspwarfare` ancestor; release `7ff18c49` adds marker-root discovery. Use `A2WASP_SKIP_ZIP=1` for propagation-only runs; runtime smoke is still a separate gate. |
| Treat `Modded_Missions/*` as divergent/stubbed unless a tooling owner proves otherwise. | Current generation/package paths do not actively maintain modded missions. |
| Use Arma 2 OA scripting references and the compatibility audit. | Arma 3 behavior is not a safe assumption; existing Arma 3 mentions are usually warnings, not implementation advice. |
| Keep public-server hardening conservative. | PVF/direct PV/economy paths include client- or payload-authoritative legacy behavior. |

## Highest-Risk Work First

| Lane | Read | Current posture |
| --- | --- | --- |
| PVF dispatch trust boundary | [PVF dispatch implementation](PVF-Dispatch-Implementation-Playbook), [Networking/PV](Networking-And-Public-Variables), [Public variable channel index](Public-Variable-Channel-Index) | P0. Current stable `origin/master@0139a346` has namespace/CODE lookup; finish explicit registered allowlist/logging if desired, port older compile-shaped refs and keep DR-55 sender authentication separate. |
| ICBM/Nuke authority | [ICBM authority](ICBM-Authority-Playbook), [Server authority map](Server-Authority-Migration-Map) | P0. Server must validate commander/upgrade/funds/side before damage. |
| Side-supply clamp | [Economy authority first cut](Economy-Authority-First-Cut), [Resistance supply scaffold](Resistance-Supply-Scaffold), [Server authority map](Server-Authority-Migration-Map) | P0 first economy hardening slice; resistance economy is scaffolded but unsupported. |
| Upgrade request authority | [Upgrades/research atlas](Upgrades-And-Research-Atlas), [Economy authority first cut](Economy-Authority-First-Cut), [Server authority map](Server-Authority-Migration-Map) | P1. Client menu validates/debits; server worker owns timer/state but must accept/reject authoritatively. |
| Attack-wave authority | [Attack-wave authority](Attack-Wave-Authority-Playbook), [Public variable channel index](Public-Variable-Channel-Index) | P1. Direct PV must become server-derived request flow. |
| Economy/server-authority class | [Server authority map](Server-Authority-Migration-Map), [Economy authority first cut](Economy-Authority-First-Cut) | P1 design lane. Do not patch build/buy/sell/gear/supply as unrelated one-offs. |
| Integration trust boundaries | [Integration trust boundary audit](Integration-Trust-Boundary-Audit), [AntiStack database extension audit](AntiStack-Database-Extension-Audit), [External integrations](External-Integrations), [Player stats branch audit](Player-Stats-Branch-Audit), [Feature status](Feature-Status-Register) | High local-write-gated DiscordBot JSON risk; separate from the in-repo extension writer, the absent AntiStack DB DLL and branch-only stats RPT/file integration gates. |

## Common Task Bundles

| Task | Read these first |
| --- | --- |
| Startup, init, parameter or generated include change | [Mission entrypoints](Mission-Entrypoints-And-Lifecycle), [Lifecycle wait-chain](Lifecycle-Wait-Chain), [Join/disconnect lifecycle](Player-Join-Disconnect-And-AntiStack-Lifecycle), [Parameters/build inputs](Mission-Parameters-Localization-And-Generated-Build-Inputs), [SQF atlas](SQF-Code-Atlas) |
| PublicVariable/PVF change | [Networking/PV](Networking-And-Public-Variables), [Public variable channel index](Public-Variable-Channel-Index), [PVF dispatch implementation](PVF-Dispatch-Implementation-Playbook) |
| Economy, upgrade or purchase change | [Economy/towns/supply](Economy-Towns-And-Supply), [Resistance supply scaffold](Resistance-Supply-Scaffold), [Factory/purchase atlas](Factory-And-Purchase-Systems-Atlas), [Upgrades/research atlas](Upgrades-And-Research-Atlas), [Server authority map](Server-Authority-Migration-Map) |
| Commander, HQ, MHQ or base-area lifecycle change | [Commander/HQ lifecycle](Commander-HQ-Lifecycle-Atlas), [Commander vote/reassignment](Commander-Vote-And-Reassignment-Playbook), [Construction/CoIn atlas](Construction-And-CoIn-Systems-Atlas), [Commander reassignment call shape](Commander-Reassignment-Call-Shape), [Server authority map](Server-Authority-Migration-Map), [Public variable channel index](Public-Variable-Channel-Index) |
| Town capture, camps or SV visibility | [Towns/camps/capture atlas](Towns-Camps-And-Capture-Atlas), [Economy/towns/supply](Economy-Towns-And-Supply), [Town AI vehicle safety](Town-AI-Vehicle-Despawn-Safety), [Testing workflow](Testing-Debugging-And-Release-Workflow) |
| Victory, endgame or match statistics | [Victory/endgame atlas](Victory-And-Endgame-Atlas), [Deep-review findings](Deep-Review-Findings) DR-11/DR-12/DR-13/DR-36, [Hardening roadmap](Hardening-Implementation-Roadmap), [Testing workflow](Testing-Debugging-And-Release-Workflow) |
| Supply mission or PR #1 work | [Supply mission architecture](Supply-Mission-Architecture), [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook), [Current supply heli PR](Current-Work-Supply-Helicopters-PR1) |
| Support/special/tactical module work | [Support/specials/modules atlas](Support-Specials-And-Tactical-Modules-Atlas), [Server authority map](Server-Authority-Migration-Map), [ICBM authority](ICBM-Authority-Playbook), [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook) |
| Marker, cleanup or restoration work | [Marker cleanup/restoration atlas](Marker-Cleanup-Restoration-Systems-Atlas), [Client UI systems atlas](Client-UI-Systems-Atlas), [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas), [Performance opportunity sweep](Performance-Opportunity-Sweep) |
| AI or headless change | [AI/headless/performance](AI-Headless-And-Performance), [AI commander autonomy audit](AI-Commander-Autonomy-Audit), [AI Commander B69 improvement roadmap](AI-Commander-B69-Improvement-Roadmap), [AI Commander B69 implementation sketches](AI-Commander-B69-Implementation-Sketches), [HC delegation/failover](Headless-Delegation-And-Failover-Playbook), [Town AI vehicle safety](Town-AI-Vehicle-Despawn-Safety) |
| FPS, old mission comparison or player-AI cap debate | [Old WarfareBE performance comparison](Old-WarfareBE-Performance-Comparison), [Player AI caps and role balance](Player-AI-Caps-And-Role-Balance), [AI/headless/performance](AI-Headless-And-Performance), [Performance opportunity sweep](Performance-Opportunity-Sweep) |
| UI/HUD/dialog change | [Client UI systems atlas](Client-UI-Systems-Atlas), [Respawn/death lifecycle](Respawn-And-Death-Lifecycle-Atlas), [UI IDD collision repair](UI-IDD-Collision-Repair), [Client UI/HUD/menus](Client-UI-HUD-And-Menus), [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas), [Gear template profile filter](Gear-Template-Profile-Filter), [Vehicle cargo equip loop bounds](Vehicle-Cargo-Equip-Loop-Bounds), [Service menu affordability guards](Service-Menu-Affordability-Guards) |
| Build/tooling/release change | [Parameters/build inputs](Mission-Parameters-Localization-And-Generated-Build-Inputs), [Tools/build workflow](Tools-And-Build-Workflow), [Source fix propagation queue](Source-Fix-Propagation-Queue), [`agent-release-readiness.json`](agent-release-readiness.json), [Testing workflow](Testing-Debugging-And-Release-Workflow), [Content/maps](Content-Structure-And-Maps), [Knowledge platform roadmap](Knowledge-Platform-Roadmap) |
| Discord/extension/AntiStack/BattlEye change | [Integration trust boundary audit](Integration-Trust-Boundary-Audit), [AntiStack database extension audit](AntiStack-Database-Extension-Audit), [External integrations](External-Integrations), [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl) |
| Revival/removal decision | [Abandoned feature revival](Abandoned-Feature-Revival-Review), [Pending owner decisions](Pending-Owner-Decisions), [Feature status](Feature-Status-Register) |

## Current Truth Notes

- Do not treat this page as the live source-fix dashboard. For current source/Vanilla propagation and smoke status, read [Current source status snapshot](Current-Source-Status-Snapshot), [Source fix propagation queue](Source-Fix-Propagation-Queue) and [`agent-release-readiness.json`](agent-release-readiness.json).
- Machine-file contract: [`agent-entrypoint.json`](agent-entrypoint.json) is the small canonical bootstrap file. `agent-status.json`, `agent-collaboration.json`, `agent-context.json`, `agent-release-readiness.json`, `agent-compatibility-audit.json` and [`agent-machine-index.json`](agent-machine-index.json) are snapshots. `agent-events.jsonl`, `agent-knowledge.jsonl`, `agent-feature-status.jsonl` and `agent-hardening-backlog.jsonl` are append-oriented evidence streams; do not assume event rows are timestamp-sorted, and prefer the newest explicit `status`/`supersedes` record when older rows disagree.
- Use the task bundles above to find owner pages for MASH/respawn, service menu guards, integration trust, commander/HQ lifecycle, victory/endgame, marker/lifecycle and generated-version work. Owner pages carry the source evidence and current caveats.

## Agent Output Rules

- Put short status and dashboard rows in [Feature status](Feature-Status-Register) or [Progress dashboard](Progress-Dashboard).
- Put detailed evidence in subsystem pages or playbooks.
- Put durable machine-readable findings in [`agent-feature-status.jsonl`](agent-feature-status.jsonl), [`agent-knowledge.jsonl`](agent-knowledge.jsonl) or [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl).
- Put source-fix propagation, generated-target and smoke-gate status in [`agent-release-readiness.json`](agent-release-readiness.json).
- Put engine compatibility classifications in [`agent-compatibility-audit.json`](agent-compatibility-audit.json) when new Arma 3-era terms are intentionally added to docs.
- If you discover a stale claim, correct the prose page and the machine file that would mislead future agents.
- If you patch source Chernarus but cannot run LoadoutManager, write `source fix; propagation pending`; if LoadoutManager runs with inspected generated diffs but no Arma smoke, write `propagated; smoke pending`.
- Before handoff, run `docs/validate-wiki.ps1` from the repo root when you changed docs or machine files.

## Continue Reading

Previous: [Quickstart](Quickstart-For-Humans-And-Agents) | Next: [Feature status](Feature-Status-Register)

Main map: [Home](Home) | Machine entry: [`agent-entrypoint.json`](agent-entrypoint.json) | Machine index: [`agent-machine-index.json`](agent-machine-index.json) | LLM map: [`llms.txt`](llms.txt)
