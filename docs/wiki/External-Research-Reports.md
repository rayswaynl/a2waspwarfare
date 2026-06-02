# External Research Reports

This page tracks external deep-research reports provided by Steff: three PDFs from 2026-06-01 and nine Markdown reports from 2026-06-02.

Treat this page as an intake ledger, not as source truth. Claims from the PDFs or Markdown reports must be checked against the repo before they are promoted into subsystem atlas pages or the feature-status register.

Claude later cross-checked the reports in Deep-Review Round 16 and found their citations are mostly downstream of this wiki or an upstream proxy, so they are corroboration of the current documentation rather than independent source verification. The wiki's source-backed DR findings are currently the stronger authority.

Machine-readable manifest: [`external-research-report-manifest.json`](external-research-report-manifest.json). Raw PDF extracted text is kept in the local Codex workspace cache (`work/research-intake/pdf-reports`) and is not mirrored into the wiki. Raw Markdown report contents are also not mirrored; the wiki stores metadata, status and source-checked deltas only.

## PDF Source Files

| Report | Local file | Pages | SHA-256 | Scout | Status |
| --- | --- | --- | --- | --- | --- |
| `Analytisch rapport over rayswaynl/a2waspwarfare` | `C:\Users\Steff\Downloads\Analytisch rapport over rayswaynl_a2waspwarfare.pdf` | 17 | `a8abae9656ec02a0b39894d2a7ec509a5c30c779160d6002f359ac9bdd7be469` | Sagan / Erdos / Dewey | External PDF digested again; repo verification required before promotion. |
| `Analyse van rayswaynl/a2waspwarfare` | `C:\Users\Steff\Downloads\Analyse van rayswaynl_a2waspwarfare.pdf` | 10 | `edb6237b1c52e91a5b1cd9d5ca1b84457d80dbe78045f0e7bc9f38b5f7db86fd` | Helmholtz / Arendt / Dewey | External PDF digested again; many claims overlap existing source-backed wiki findings. |
| `Diepgaande analyse van rayswaynl/a2waspwarfare` | `C:\Users\Steff\Downloads\Diepgaande analyse van rayswaynl_a2waspwarfare.pdf` | 12 | `61e5e77d80e485300fb37fc9fc273d769948c88eeb158dcd6d55d78e7dac94b3` | Parfit / Carver / Dewey | External PDF digested again; security/network posture focus. |

Extraction cache manifest: `work/research-intake/pdf-reports/manifest.json`.

## Markdown Report Intake 2026-06-02

Steff provided nine additional Markdown deep-research reports on 2026-06-02. Codex read them as a fresh intake batch, recorded hashes and titles in the manifest, and used them as candidate leads for future source-backed work.

| Report | Local file | SHA-256 | Scope | Status |
| --- | --- | --- | --- | --- |
| `Server Authority Refactor Design voor a2waspwarfare` | `C:\Users\Steff\Downloads\deep-research-report (8).md` | `e5aa6f998b6dfe347c14780171a8ddecce77e1daab66e7bc902790b366b17448` | Server authority redesign, trust boundary migration and staged hardening concepts. | Intake complete; design claims require source-backed implementation decisions. |
| `AI-onboarding en veilige refactor-playbook voor a2waspwarfare` | `C:\Users\Steff\Downloads\deep-research-report (9).md` | `b2fc2ebeeb732026c61bc3b14feea6d9b86d6a95c0f1f13e33671f84eab11601` | AI assistant onboarding, safe refactor rules, proposed agent files and machine context patterns. | Intake complete; do not copy generated guide text directly without review. |
| `Full Mission Runtime Architecture` | `C:\Users\Steff\Downloads\deep-research-report (1).md` | `b98d7a9a4396d8e0dbfb87915efa91323d637279675ef51e267cf2bad73bd396` | Mission boot, runtime split, common/client/server/headless flow. | Mostly overlaps existing architecture and lifecycle pages; use as corroboration. |
| `Multiplayer Trust Boundary Hardening Audit of a2waspwarfare` | `C:\Users\Steff\Downloads\deep-research-report (2).md` | `a3f90575c1dea9f4b61110ce88c2134a2e852f21e667322c1c7af08b570bd58d` | PVF/direct-PV trust boundaries, validation and hardening plan. | Overlaps DR-1/DR-6/DR-14/DR-16/DR-27/DR-28/DR-30/DR-41. |
| `Broken, Partial, Abandoned, and Missing Feature Archaeology for rayswaynl/a2waspwarfare` | `C:\Users\Steff\Downloads\deep-research-report (3).md` | `8e3022ab556d47068de88f2a1decf72ce3a1013c8da75bca9563da845fd6f955` | Feature archaeology, disabled code, partial systems and missing files. | Useful lead list; source-backed status remains in Feature Status and Deep Review Findings. |
| `Long-Term Modernization and Safe Development Strategy for a2waspwarfare` | `C:\Users\Steff\Downloads\deep-research-report (4).md` | `211487e06a3e6127f658195a093f87466d605ec9ac0f767ea4f5113bc0da09ea` | Long-term modernization sequence, testing posture and safer refactor strategy. | Treat as roadmap input, not current behavior proof. |
| `Deep research van rayswaynl a2waspwarfare locality en JIP architectuur` | `C:\Users\Steff\Downloads\deep-research-report (5).md` | `ee614a67de2cb2550b308b77d863cf7843786855aed8b8f77d97102e66a199b4` | Locality, JIP, headless and hosted/dedicated behavior. | Overlaps lifecycle, AI/headless and wait-chain docs; verify any new claim against source. |
| `Practical Testing, Debugging, and Release Workflow for Arma 2 OA a2waspwarfare` | `C:\Users\Steff\Downloads\deep-research-report (6).md` | `43e5c658715c57739bd081555a056c7f2a0c56d6e260e9794418e16055ec16ac` | Practical smoke tests, release gates, diagnostics and RPT workflow. | Overlaps Testing Workflow page; use for test-plan refinement ideas. |
| `Gameplay Systems and State Ownership Atlas for a2waspwarfare` | `C:\Users\Steff\Downloads\deep-research-report (7).md` | `37ee582812e06c34d2fd627487dc7f67f92427712cb334b0443f0743046d3951` | Towns, economy, commander, construction, factories and state ownership. | Overlaps gameplay/factory/construction/economy atlas pages. |

## Markdown Intake Synthesis

The Markdown batch is valuable as a structured second-brain pass, especially for server authority, AI onboarding and long-term refactor strategy. It does not replace source-backed wiki pages. Future agents should use the reports to find what to inspect next, then cite repository files or already-verified DR findings before changing canonical subsystem docs.

Claude's Round 34 independently triaged the same nine reports and found no contradictions with the current DR register. It recorded DR-43: the generated `version.sqf` source-completeness gap, plus `Init_Server.sqf` duplicate bind cleanup. Codex then re-checked the duplicate-bind count and corrected it to three live duplicate binds (`LogGameEnd`, `PlayerObjectsList`, `AwardScorePlayer`) plus three commented duplicate remnants (`InitAFKkickHandler`, `monitorServerFPS`, `MASH_MARKER`).

Confirmed overlap from this intake pass:

| Lead | Source-backed status |
| --- | --- |
| Modded mission propagation is not currently maintained by `Tools/LoadoutManager`. | Verified from `Tools/LoadoutManager/ZipManager.cs:10`, which packages only `Missions` and `Missions_Vanilla`, and `Tools/LoadoutManager/SqfFileGenerators/SqfFileGenerator.cs:132-133`, where modded-terrain propagation is commented with a TODO. Already covered by [Tools/build](Tools-And-Build-Workflow). |
| Runtime architecture, lifecycle and wait-chain reports broadly match current docs. | Already covered by [Architecture overview](Architecture-Overview), [Mission lifecycle](Mission-Entrypoints-And-Lifecycle) and [Lifecycle wait-chain](Lifecycle-Wait-Chain). |
| Server authority reports point at the same client-trusted economy class already found by Claude/Codex. | Use [Server authority map](Server-Authority-Migration-Map), [Deep-review findings](Deep-Review-Findings), [Attack-wave authority playbook](Attack-Wave-Authority-Playbook) and [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl) as the source-backed versions. |
| Testing and release workflow report is aligned with the newly published validation levels. | Use [Testing workflow](Testing-Debugging-And-Release-Workflow) and [`agent-test-plan.schema.json`](agent-test-plan.schema.json) for canonical validation language. |

New or sharpened leads to source-check later:

| Lead | Suggested verification target |
| --- | --- |
| Headless delegation lease/ACK/failover model for future stability. | `Headless/`, `Common/Functions/Common_CreateUnit.sqf`, town AI activation and HC creation paths. |
| Server shadow ledger for staged economy hardening. | `Server_ChangeSideSupply.sqf`, funds/supply PV flows, buy/build/sell/upgrade/supply request handlers. |
| Root `AGENTS.md` addition for repo-native AI onboarding. | Compare the report's proposed agent guide against current `CLAUDE.md`, [AI assistant guide](AI-Assistant-Developer-Guide) and shared machine files before adding a new root file. |
| PVF dispatch implementation playbook. | `Common/Init/Init_PublicVariables.sqf`, `Server_HandlePVF.sqf`, `Client_HandlePVF.sqf`, DR-1 and DR-38. |

## Second Reconciliation Wave

On 2026-06-02 Codex extracted the PDFs into shared text artifacts and spawned a cheap read-only explorer wave:

| Explorer | Focus |
| --- | --- |
| Erdos | Architecture, lifecycle, bootstrap and wait-chain claims. |
| Arendt | Broken, partial, abandoned and missing feature claims. |
| Carver | Server, security, networking and external integration claims. |
| Laplace | UI/HUD/dialog source findings and GitHub wiki UX implications. |
| Tesla | Agent-friendly artifact/schema proposal for future development work. |
| Dewey | Third-pass external report claim triage against the published wiki and hardening backlog. |

Promotion rule: explorer output from this wave is still external-report reconciliation. It becomes canonical only after a repo file, branch diff, wiki source page or generated inventory backs the claim.

## Provenance Update

| Finding | Meaning |
| --- | --- |
| Claude found raw GitHub wiki citations in the PDF reports. | Treat the reports as downstream summaries of the wiki and upstream proxy material, not as independent audits. |
| The reports re-derive several already-known risks, especially DR-1, DR-6, DR-7, partial supply logistics and PR #1 handler concerns. | Useful confirmation, but the source-backed wiki pages remain canonical. |
| The current DR register is broader than the PDFs. | The PDFs do not cover later findings such as victory/endgame, commander assignment, supply cooldown, hosted FPS, HQ-kill scoring, supply/upgrade economy exploits and license/governance details. |
| Claude resolved the license uncertainty as DR-26. | `LICENSE.md` is custom/proprietary/source-available, not OSI open source; see [Deep-review findings](Deep-Review-Findings). |

## Verified Overlap With Current Wiki

These PDF themes already match source-backed findings in the wiki. Use the owning pages below for the verified version.

| PDF theme | Current wiki status | Owning pages |
| --- | --- | --- |
| Runtime split across `Common`, `Server`, `Client` and `Headless`, booted through `description.ext` and `initJIPCompatible.sqf`. | Verified from mission source. | [Architecture overview](Architecture-Overview), [Mission lifecycle](Mission-Entrypoints-And-Lifecycle), [Lifecycle wait-chain](Lifecycle-Wait-Chain) |
| Chernarus is the source mission; Takistan and modded missions are generated or derived targets. | Verified; modded generation is stale/disabled. | [Content/maps](Content-Structure-And-Maps), [Tools/build](Tools-And-Build-Workflow) |
| PVF dispatch and direct `publicVariable` channels form a major network trust boundary. | Verified; DR-1 and scout PV matrix cover this in detail. | [Networking/PV](Networking-And-Public-Variables), [Deep-review findings](Deep-Review-Findings) |
| Construction, purchase and sale flows are heavily client-authoritative. | Verified by Codex and Claude reviews. | [Construction/CoIn atlas](Construction-And-CoIn-Systems-Atlas), [Factory/purchase atlas](Factory-And-Purchase-Systems-Atlas), [Feature status](Feature-Status-Register) |
| `UpdateSupplyTruck` / AI supply logistics are partial or broken. | Verified as latent breakage; missing `supplytruck.fsm` is in the risk register. | [Server runtime atlas](Server-Gameplay-Runtime-Atlas), [Feature status](Feature-Status-Register) |
| PR #1 supply helicopter work risks repeated `Killed` event handlers. | Verified in Claude and scout findings; PR remains pending. | [Current supply heli PR](Current-Work-Supply-Helicopters-PR1), [Supply mission architecture](Supply-Mission-Architecture) |
| LoadoutManager controls generated EASA/balance output and target mission propagation. | Verified. | [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas), [Tools/build](Tools-And-Build-Workflow) |
| AntiStack, `callExtension`, DiscordBot and BattlEye are important external trust boundaries. | Verified at subsystem level; further integration docs are pending. | [External integrations](External-Integrations), [Deep-review findings](Deep-Review-Findings) |

## Claims To Verify Before Promotion

These are useful leads, but should not be copied into subsystem pages until a repo reader confirms them.

| Lead | Verification target |
| --- | --- |
| `!isServer` / `!isDedicated` may be used as overly broad client predicates, affecting headless or hosted-server behavior. | Scan client/server/headless init, long loops and UI-only actions for locality checks; classify real bugs separately from harmless shortcuts. |
| `waitUntil` chains without timeout can silently hang startup. | Build a wait-chain audit table: condition, owner, expected producer, timeout/logging state. |
| Town AI despawn may delete a vehicle if the group leader is not a player even when a player is inside the vehicle. | Inspect `Server/FSM/server_town_ai.sqf` and vehicle cleanup interactions. |
| Broadcast-heavy PV delivery may be overused where targeted delivery would be safer or cheaper. | Extend the PV matrix with target model, fan-out cost and late-join behavior. |
| `spawn`-based dispatch can create ordering uncertainty for mutating flows. | Identify only flows where ordering actually matters, such as commander updates, economy mutation and construction. |
| License/provenance state is unclear. | Check root license, inherited mission provenance and any redistributed asset/licensing notes. |
| CI for .NET builds, generated drift and docs/status consistency is missing. | Check GitHub Actions or other CI config, then decide whether this is a missing feature or out-of-scope for the mission repo. |

## Recommendations Intake

The reports recommend these longer-term hardening moves. They are consistent with the current docs direction, but still need design decisions before implementation.

| Recommendation | Suggested owner page |
| --- | --- |
| Replace dynamic PVF `Call Compile` dispatch with a handler map or allow-list. | [Networking/PV](Networking-And-Public-Variables) |
| Move decisive validation for building, defenses, MHQ repair, score/team/commander changes and purchases server-side. | [Feature status](Feature-Status-Register), [Deep-review findings](Deep-Review-Findings) |
| Convert broad broadcasts to targeted delivery where semantics allow it. | [Networking/PV](Networking-And-Public-Variables) |
| Add payload schemas, request IDs and idempotency for mutating network requests. | [Agent collaboration protocol](Agent-Collaboration-Protocol), future hardening plan |
| Harden `callExtension` with input/output validation, circuit breakers and secret/config separation. | [External integrations](External-Integrations) |
| Add generated-file drift checks and decide whether `Modded_Missions` is authoritative or deprecated. | [Tools/build](Tools-And-Build-Workflow), [Content/maps](Content-Structure-And-Maps) |

## Agent Index Facts

```json
{
  "page": "External-Research-Reports",
  "sourceType": "external_report_intake",
  "status": "unverified_claims_must_be_repo_checked",
  "pdfReports": [
    "Analytisch rapport over rayswaynl_a2waspwarfare.pdf",
    "Analyse van rayswaynl_a2waspwarfare.pdf",
    "Diepgaande analyse van rayswaynl_a2waspwarfare.pdf"
  ],
  "markdownReports": 9,
  "scouts": ["Sagan", "Helmholtz", "Parfit"],
  "promotionRule": "Only promote claims to subsystem pages after source-file verification."
}
```

## Continue Reading

Previous: [Deep-review findings](Deep-Review-Findings) | Next: [Codebase coverage ledger](Codebase-Coverage-Ledger)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
