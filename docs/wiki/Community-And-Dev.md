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

The public upstream repo snapshot is useful as a culture anchor, not a release ledger: the project presents itself as development from a 2018 Benny's Warfare base, with Miksuu-era development beginning in June 2023 and older pre-2016 work attributed in upstream prose to Spayker-era history. The public GitHub surface is light on formal releases, so practical history lives in commits, branches, Discord/Trello-style notes and imported wiki pages more than in GitHub Releases.

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

Git author density gives a second, repo-local signal about who shaped the project over time. On 2026-06-04, `git shortlog -sn --all --no-merges` showed the largest non-merge authors as: Miksuu `2770`, Ezcoo `1016`, rayswaynl `518`, Esa Oksman `293` and Marty865 `196`. Treat this as commit-volume evidence, not a current role or ownership claim.

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

Upstream diagnostic style note: the freshest local `miksuu/master` delta on 2026-06-04 was the town-defense diagnostics branch (`913ecdf6` -> `d5bfe3a2` -> merge `8bcc42b1`). It added an opt-in `WFBE_C_TOWN_DEFENSE_DIAGNOSTICS` / `TownDefenseDiagnosticsEnabled` path around town-defense code rather than broad permanent logging. That is a useful pattern for hot-loop work: add narrow feature diagnostics, keep defaults quiet and propagate source-Chernarus changes deliberately to maintained Vanilla/Takistan.

### Upstream Process Capsule

The imported [Development process](Miksuu-Wiki-Archive-Development-Process) page gives a compact picture of how the mission was actually developed upstream:

| Upstream practice | Lesson for current developers and agents |
| --- | --- |
| SQF had no breakpoint-driven workflow, so developers leaned on `WFBE_CO_FNC_LogContent` and official SQF docs. | Prefer small, targeted diagnostics and source-path evidence. Remove or gate noisy logs before release. |
| LoadoutManager was easier to evolve than SQF because it is C# and could encode repeatable generation logic. | Treat generator changes as source-of-truth edits, then inspect generated mission diffs instead of hand-editing generated outputs. |
| GPT-4 and Trello were used for complex LoadoutManager work and patch-note generation. | AI assistance is historically normal here, but every claim still needs source/branch/runtime scoping. |
| Feature work used per-feature branches merged into a test branch, with fixes made back on the feature branch. | Keep branch-only docs explicit; do not flatten test-branch or feature-branch behavior into stable-master truth. |
| Performance issues often came from always-running server/client loops, and scaling HC/server cores helped live performance. | Treat loop edits, headless delegation and runtime-performance claims as smoke-required; source shape alone is not enough. |

## Upstream and Decision-Ledger Gap

The 2026-06-04 community scout verified the local remotes as `origin` = `rayswaynl/a2waspwarfare` and `miksuu` = `Miksuu/a2waspwarfare`. At that check, `miksuu/master` was three commits ahead of `origin/master`: `913ecdf6` town defense diagnostics, `d5bfe3a2` Takistan update and merge `8bcc42b1`. The local `master` branch was also 29 commits behind `origin/master`, so use remote branch refs for provenance checks instead of trusting the local branch pointer.

This page, [Developer history and upstream lessons](Developer-History-And-Upstream-Lessons) and [Upstream Miksuu commit intel](Upstream-Miksuu-Commit-Intel) now overlap enough that future upstream archaeology needs a single decision ledger. The missing page should track:

| Decision record | Why it matters |
| --- | --- |
| Upstream PR/commit/revert rationale | Reverts and closed PRs often carry negative knowledge that is easy for agents to lose. |
| Behavior classification | Mark each imported lesson as gameplay, performance, tooling, compatibility, docs-only or historical. |
| Branch scope | Distinguish `origin/master`, `miksuu/master`, feature branches, release branches, source Chernarus, maintained Vanilla/Takistan targets and generated-output status. |
| Current action | Cherry-pick, source-check, document-only, owner decision, reject or archive. |

Until that ledger exists, treat upstream commit/wiki findings as leads and route implementation truth through current source plus the relevant subsystem page.

Archive caveat: imported upstream wiki history includes at least one very short-lived placeholder, `Raysway-Update-Notes.md`, which was created and deleted in the same small history window. Preserve its provenance in the archive ledger, but do not treat ephemeral pages as durable guidance without surviving content or matching source evidence.

## Upstream wiki archive

Imported from `Miksuu/a2waspwarfare.wiki` at commit `45ef3da367d65e6487de488bbe3b16a8a8b21ba3`.

The imported pages are intentionally treated as an archive set. They remain reachable through [Miksuu upstream wiki import](Miksuu-Upstream-Wiki-Import), but the sidebar exposes the archive index and source-check queues rather than every historical page. That keeps current development routes lighter while preserving the full upstream record.

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
