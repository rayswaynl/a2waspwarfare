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

| Name / handle | Mentioned role or context | Source route |
| --- | --- | --- |
| Miksuu | Maintainer, changelog author, LoadoutManager and Discord/tooling context. | [Changelog archive](Miksuu-Wiki-Archive-Changelog), [LoadoutManager archive](Miksuu-Wiki-Archive-LoadoutManager), [Development process archive](Miksuu-Wiki-Archive-Development-Process) |
| Marty / `@marty0007` | Architecture wiki author and repeated feature/code contributor in upstream notes. | [Project architecture archive](Miksuu-Wiki-Archive-Project-Script-Architecture-Of-Chernarus-Mission), [Changelog archive](Miksuu-Wiki-Archive-Changelog) |
| `@rayswaycx`, `@rainbowbier`, `@eirik4461` | Donor/server-support gratitude in the 2023 announcement. | [Big announcements archive](Miksuu-Wiki-Archive-Big-Announcements) |
| `@DMR#1208`, `0=1`, `@cleinstein`, `@quadxd`, Panovich | Contributor thanks and patch/community context in upstream notes. | [Big announcements archive](Miksuu-Wiki-Archive-Big-Announcements), [Changelog archive](Miksuu-Wiki-Archive-Changelog) |
| Quad, Net_2, nonotgulag, opftafel007, malialek, Blu | Names surfaced by upstream changelog scout as reporters, contributors or community participants. | [Changelog archive](Miksuu-Wiki-Archive-Changelog) |
| Ray Reijnders | Recent upstream wiki git history: created then deleted `Raysway-Update-Notes.md` on 2026-06-02; no content remains at HEAD beyond history. | [Miksuu upstream wiki import](Miksuu-Upstream-Wiki-Import) |
| `@ezcoo` | Appears in mixed upstream contexts, including older contributor thanks and later recovery/conflict wording. Treat as history-source evidence only. | [Changelog archive](Miksuu-Wiki-Archive-Changelog), [Big announcements archive](Miksuu-Wiki-Archive-Big-Announcements) |

## Development culture

| Practice | Current documentation rule |
| --- | --- |
| Feature branches and test branch integration | Keep branch evidence scoped. Do not call branch-only work stable until owner decisions, propagation and smoke evidence are recorded. |
| Trello/Discord-style patch notes | Release notes should include user-facing effects, caveats, contributor credits and known follow-up gates. |
| SQF debugging by logging | Prefer targeted diagnostics such as existing mission logging helpers; remove or gate noisy logs before release. |
| Performance experiments | Server FPS, headless clients, hardware and view-distance notes are historically important but need current runtime proof. |
| Tool-assisted generated missions | Treat source mission, maintained Vanilla target and historical modded propagation as different scopes. |
| AI assistance | AI can accelerate archaeology and docs, but source verification is a project norm, not paperwork. |

## Upstream wiki archive

Imported from `Miksuu/a2waspwarfare.wiki` at commit `45ef3da367d65e6487de488bbe3b16a8a8b21ba3`.

| Archive page | Best use |
| --- | --- |
| [Miksuu upstream wiki import](Miksuu-Upstream-Wiki-Import) | Import manifest, provenance, caveats and historical-only pages. |
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
- The changelog and announcements are primary community history, not a release-readiness ledger.
- Names in upstream prose can be Discord handles, display names, authors, donors or reporters; cite them as "mentioned in source" unless separately verified.

## Continue Reading

Previous: [Knowledge platform roadmap](Knowledge-Platform-Roadmap) | Next: [Miksuu upstream wiki import](Miksuu-Upstream-Wiki-Import)

Related: [Developer history and upstream lessons](Developer-History-And-Upstream-Lessons) | [Upstream Miksuu commit intel](Upstream-Miksuu-Commit-Intel) | [PR8 and Drone upstream lesson match](PR8-And-Drone-Upstream-Lesson-Match)
