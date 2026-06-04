# Community & Dev

This page is the human and AI map for Wasp Warfare's community history, developer culture, contributor memory and upstream wiki archive.

Use it when you need to understand why the mission looks the way it does, who shaped it, which old notes are primary-source history, and which upstream claims need current-source verification before implementation.

## What this page is

- A cultural and historical entrypoint for the A2 Wasp Warfare project.
- A routing page for Miksuu upstream wiki content imported into this wiki.
- A contributor and development-practice ledger based on upstream wiki pages, changelog notes, git history and existing source-backed history pages.

## Where it lives

- Wiki page: `docs/wiki/Community-And-Dev.md`
- Upstream import manifest: [Miksuu upstream wiki import](Miksuu-Upstream-Wiki-Import)
- Machine-readable import ledger: [`agent-upstream-wiki-imports.jsonl`](agent-upstream-wiki-imports.jsonl)

## Project lineage

The upstream welcome page describes the mission as an Arma 2 OA CTI/Warfare project initially revised by the WASP team and continued by the Miksuu community. The current `rayswaynl/a2waspwarfare` wiki builds on that history rather than replacing it.

For implementation decisions, treat this lineage as context, not proof of current runtime behavior. Current technical claims still need source, branch and mission-target evidence.

## Community-driven development model

The upstream wiki shows a Discord-first development culture:

| Pattern | What it means for current work |
| --- | --- |
| Discord release notes | Preserve release-note style and community credits, but verify old implementation claims against current source. |
| Suggestions and votes | Balance and event direction often came from community input, so "why" may live in changelog prose, not only code. |
| Live-server caveats | Several notes were written for active server operations; do not treat old event or server-state text as current policy. |
| Donor support | Server funding and events were part of the project culture; keep credits visible. |
| GPT-assisted writing/development | AI help is part of the project's history, but current docs require source-backed validation. |

## Contributors and community names

This is a non-exhaustive "mentioned in upstream sources" ledger, not an ownership or current-role claim.

| Canonical name | Aliases seen | Mentioned role or context | Source route |
| --- | --- | --- | --- |
| Miksuu | `@miksuu` | Core maintainer, release lead, changelog author, LoadoutManager and Discord/tooling context. | [Changelog archive](Miksuu-Wiki-Archive-Changelog), [LoadoutManager archive](Miksuu-Wiki-Archive-LoadoutManager), [Development process archive](Miksuu-Wiki-Archive-Development-Process) |
| Marty | `@marty0007` | Architecture wiki author, core developer and repeated feature/balance contributor in upstream notes. | [Project architecture archive](Miksuu-Wiki-Archive-Project-Script-Architecture-Of-Chernarus-Mission), [Changelog archive](Miksuu-Wiki-Archive-Changelog) |
| Rayswaycx | `@Rayswaycx#3767`, `@rayswaycx` | Donor, server-support and event context in upstream notes. | [Big announcements archive](Miksuu-Wiki-Archive-Big-Announcements), [Changelog archive](Miksuu-Wiki-Archive-Changelog) |
| DMR | `@DMR#1208` | Long-running contributor and patch/air-balance context. | [Big announcements archive](Miksuu-Wiki-Archive-Big-Announcements), [Changelog archive](Miksuu-Wiki-Archive-Changelog) |
| Quad | `@quadxd` | Contributor across scripts, ideas, QA/testing and community feedback. | [Big announcements archive](Miksuu-Wiki-Archive-Big-Announcements), [Changelog archive](Miksuu-Wiki-Archive-Changelog) |
| Cleinstein | `@cleinstein` | Contributor, air balance and loadout context. | [Big announcements archive](Miksuu-Wiki-Archive-Big-Announcements), [Changelog archive](Miksuu-Wiki-Archive-Changelog) |
| 0=1 | `0=1` | Contributor, marker and feature-authoring context. | [Changelog archive](Miksuu-Wiki-Archive-Changelog) |
| Panovich | `Panovich` | Contributor, FPS optimization note. | [Changelog archive](Miksuu-Wiki-Archive-Changelog) |
| Net_2 | `Net_2` | Contributor/release-tag context. | [Changelog archive](Miksuu-Wiki-Archive-Changelog) |
| nonotgulag | `@nonotgulag` | Feature patch contributor. | [Changelog archive](Miksuu-Wiki-Archive-Changelog) |
| opftafel007 | `@opftafel007` | Bug report and feedback contributor. | [Changelog archive](Miksuu-Wiki-Archive-Changelog) |
| malialek | `@malialek` | Suggestion contributor. | [Changelog archive](Miksuu-Wiki-Archive-Changelog) |
| rainbowbier | `@rainbowbier` | Donor and QA/feedback context. | [Big announcements archive](Miksuu-Wiki-Archive-Big-Announcements), [Changelog archive](Miksuu-Wiki-Archive-Changelog) |
| eirik4461 | `@eirik4461` | Donor and Patreon context. | [Big announcements archive](Miksuu-Wiki-Archive-Big-Announcements) |
| Ray Reijnders | Ray | Recent upstream wiki git history: created then deleted `Raysway-Update-Notes.md` on 2026-06-02; no content remains at HEAD beyond history. | [Miksuu upstream wiki import](Miksuu-Upstream-Wiki-Import) |
| ezcoo | `@ezcoo`, `@ezcoo's old code` | Legacy contributor/code-source context plus later recovery/conflict wording. Treat as history-source evidence only. | [Changelog archive](Miksuu-Wiki-Archive-Changelog), [Big announcements archive](Miksuu-Wiki-Archive-Big-Announcements) |

Do not treat `Arma2Warfare GPT`, `Mr. James`, `Contributor`, `Game Admin` or `Veteran` as individual contributor rows unless a later source proves they are handles rather than tools/roles/context.

## Development culture

| Practice | Current documentation rule |
| --- | --- |
| Feature branches and test branch integration | Keep branch evidence scoped. Do not call branch-only work stable until owner decisions, propagation and smoke evidence are recorded. |
| Trello/Discord-style patch notes | Release notes should include user-facing effects, caveats, contributor credits and known follow-up gates. |
| SQF debugging by logging | Prefer targeted diagnostics such as existing mission logging helpers; remove or gate noisy logs before release. |
| Performance experiments | Server FPS, headless clients, hardware and view-distance notes are historically important but need current runtime proof. |
| Tool-assisted generated missions | Treat source mission, maintained Vanilla target and historical modded propagation as different scopes. |
| AI assistance | AI can accelerate archaeology and docs, but source verification is a project norm, not paperwork. |

## Upstream and Decision-Ledger Gap

The 2026-06-04 community scout verified the local remotes as `origin` = `rayswaynl/a2waspwarfare` and `miksuu` = `Miksuu/a2waspwarfare`. At that check, `miksuu/master` was three commits ahead of `origin/master`: `913ecdf6` town defense diagnostics, `d5bfe3a2` Takistan update and merge `8bcc42b1`.

This page, [Developer history and upstream lessons](Developer-History-And-Upstream-Lessons) and [Upstream Miksuu commit intel](Upstream-Miksuu-Commit-Intel) now overlap enough that future upstream archaeology needs a single decision ledger. The missing page should track:

| Decision record | Why it matters |
| --- | --- |
| Upstream PR/commit/revert rationale | Reverts and closed PRs often carry negative knowledge that is easy for agents to lose. |
| Behavior classification | Mark each imported lesson as gameplay, performance, tooling, compatibility, docs-only or historical. |
| Branch scope | Distinguish `origin/master`, `miksuu/master`, feature branches, release branches, source Chernarus, maintained Vanilla/Takistan targets and generated-output status. |
| Current action | Cherry-pick, source-check, document-only, owner decision, reject or archive. |

Until that ledger exists, treat upstream commit/wiki findings as leads and route implementation truth through current source plus the relevant subsystem page.

## Upstream wiki archive

Imported from `Miksuu/a2waspwarfare.wiki` at commit `45ef3da367d65e6487de488bbe3b16a8a8b21ba3`.

| Archive page | Best use |
| --- | --- |
| [Miksuu upstream wiki import](Miksuu-Upstream-Wiki-Import) | Import manifest, provenance, caveats and historical-only pages. |
| [Upstream changelog feature leads](Upstream-Changelog-Feature-Leads) | Candidate backlog of old changelog features that need current-source verification. |
| [Project welcome](Miksuu-Wiki-Archive-Welcome) | CTI overview, WASP -> Miksuu lineage, contribution culture. |
| [Changelog](Miksuu-Wiki-Archive-Changelog) | Primary community timeline and release-note archive. |
| [Big announcements](Miksuu-Wiki-Archive-Big-Announcements) | 2023 end-of-year community, donor, contributor and HC/GPT history. |
| [Development process](Miksuu-Wiki-Archive-Development-Process) | Miksuu process notes: SQF debugging, GPT-4, Trello, branches and performance lessons. |
| [LoadoutManager](Miksuu-Wiki-Archive-LoadoutManager) | Historical rationale for the C# generation tool; verify current generated-mission scope before using. |
| [Chernarus mission architecture](Miksuu-Wiki-Archive-Project-Script-Architecture-Of-Chernarus-Mission) | Marty-era architecture overview and external diagram/PDF links; use as checklist, not canonical current atlas. |
| [Discord Bot](Miksuu-Wiki-Archive-Discord-Bot) | Thin provenance note for DiscordBotFramework. |
| [Gameplay videos](Miksuu-Wiki-Archive-Gameplay-Videos) | Upstream media link. |
| [Wiki home stub](Miksuu-Wiki-Archive-Home) | One-line original upstream wiki home, preserved for completeness. |

## Caveats for agents

- Do not promote upstream wiki claims to current truth without checking current source, branch and mission target.
- The old LoadoutManager pages describe broad terrain propagation; current docs/source treat modded mission propagation as inactive or non-authoritative.
- The old architecture page is useful as a historical checklist, but current canonical structure lives in [Architecture overview](Architecture-Overview), [SQF code atlas](SQF-Code-Atlas) and [Source inventory](Source-Inventory).
- Old modded-map and V9/V10 event notes are event history, not current release propagation rules; route current generated-mission claims through [Tools and build workflow](Tools-And-Build-Workflow).
- Server ops, HC and performance anecdotes are live-ops snapshots; route current HC/failover/runtime claims through [AI, headless and performance](AI-Headless-And-Performance) and [Headless delegation/failover](Headless-Delegation-And-Failover-Playbook).
- DiscordBot archive notes are provenance only; route current bot/security/trust claims through [External integrations](External-Integrations) and [Integration trust boundary audit](Integration-Trust-Boundary-Audit).
- The changelog and announcements are primary community history, not a release-readiness ledger.
- Names in upstream prose can be Discord handles, display names, authors, donors or reporters; cite them as "mentioned in source" unless separately verified.

## Continue Reading

Previous: [Knowledge platform roadmap](Knowledge-Platform-Roadmap) | Next: [Miksuu upstream wiki import](Miksuu-Upstream-Wiki-Import)

Related: [Upstream changelog feature leads](Upstream-Changelog-Feature-Leads) | [Developer history and upstream lessons](Developer-History-And-Upstream-Lessons) | [Upstream Miksuu commit intel](Upstream-Miksuu-Commit-Intel) | [PR8 and Drone upstream lesson match](PR8-And-Drone-Upstream-Lesson-Match)
