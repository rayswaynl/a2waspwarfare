# External Research Reports

This page tracks three PDF deep-research reports provided by Steff on 2026-06-01 and digested by Codex sub-agents Sagan, Helmholtz and Parfit.

Treat this page as an intake ledger, not as source truth. Claims from the PDFs must be checked against the repo before they are promoted into subsystem atlas pages or the feature-status register.

Claude later cross-checked the reports in Deep-Review Round 16 and found their citations are mostly downstream of this wiki or an upstream proxy, so they are corroboration of the current documentation rather than independent source verification. The wiki's source-backed DR findings are currently the stronger authority.

## Source Files

| Report | Local file | Scout | Status |
| --- | --- | --- | --- |
| `Analytisch rapport over rayswaynl/a2waspwarfare` | `C:\Users\Steff\Downloads\Analytisch rapport over rayswaynl_a2waspwarfare.pdf` | Sagan | External PDF digested; repo verification required. |
| `Analyse van rayswaynl/a2waspwarfare` | `C:\Users\Steff\Downloads\Analyse van rayswaynl_a2waspwarfare.pdf` | Helmholtz | External PDF digested; many claims overlap existing source-backed wiki findings. |
| `Diepgaande analyse van rayswaynl/a2waspwarfare` | `C:\Users\Steff\Downloads\Diepgaande analyse van rayswaynl_a2waspwarfare.pdf` | Parfit | External PDF digested; security/network posture focus. |

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
  "sourceType": "external_pdf_intake",
  "status": "unverified_claims_must_be_repo_checked",
  "reports": [
    "Analytisch rapport over rayswaynl_a2waspwarfare.pdf",
    "Analyse van rayswaynl_a2waspwarfare.pdf",
    "Diepgaande analyse van rayswaynl_a2waspwarfare.pdf"
  ],
  "scouts": ["Sagan", "Helmholtz", "Parfit"],
  "promotionRule": "Only promote claims to subsystem pages after source-file verification."
}
```

## Continue Reading

Previous: [Deep-review findings](Deep-Review-Findings) | Next: [Codebase coverage ledger](Codebase-Coverage-Ledger)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
