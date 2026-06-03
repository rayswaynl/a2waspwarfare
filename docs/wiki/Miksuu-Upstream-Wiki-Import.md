# Miksuu Upstream Wiki Import

This page records the import of the upstream `Miksuu/a2waspwarfare` GitHub wiki into the `rayswaynl/a2waspwarfare` developer wiki.

The import is intentionally namespaced under `Miksuu-Wiki-Archive-*` pages so current docs can remain canonical while still preserving every upstream page at HEAD.

## Snapshot

| Field | Value |
| --- | --- |
| Source wiki | `https://github.com/Miksuu/a2waspwarfare.wiki.git` |
| Imported commit | `45ef3da367d65e6487de488bbe3b16a8a8b21ba3` |
| Commit summary | `Destroyed Raysway Update Notes (markdown)` |
| Snapshot date | 2026-06-03 |
| Current tracked Markdown pages | 9 |
| Binary attachments in wiki repo | None tracked at HEAD |
| Machine ledger | [`agent-upstream-wiki-imports.jsonl`](agent-upstream-wiki-imports.jsonl) |

## Imported pages

| Upstream file | Imported archive page | Import class | Current use |
| --- | --- | --- | --- |
| `Welcome.md` | [Miksuu Wiki Archive: Project Welcome](Miksuu-Wiki-Archive-Welcome) | Summarize and archive | Lineage, CTI explanation, contribution culture. |
| `Home.md` | [Miksuu Wiki Archive: Wiki Home Stub](Miksuu-Wiki-Archive-Home) | Archive only | Original one-line upstream landing page. |
| `Changelog.md` | [Miksuu Wiki Archive: Changelog](Miksuu-Wiki-Archive-Changelog) | Verbatim archive | Primary 2023-2024 community release-note history. |
| `Big-announcements.md` | [Miksuu Wiki Archive: Big Announcements](Miksuu-Wiki-Archive-Big-Announcements) | Verbatim archive | Donors, contributors, GPT/HC/performance/event culture. |
| `Gameplay-videos.md` | [Miksuu Wiki Archive: Gameplay Videos](Miksuu-Wiki-Archive-Gameplay-Videos) | Archive/link | Gameplay media. |
| `Discord-Bot.md` | [Miksuu Wiki Archive: Discord Bot](Miksuu-Wiki-Archive-Discord-Bot) | Archive/link | DiscordBotFramework provenance only. |
| `LoadoutManager.md` | [Miksuu Wiki Archive: LoadoutManager](Miksuu-Wiki-Archive-LoadoutManager) | Archive with caveat | Tool rationale and examples; current generation scope must be rechecked. |
| `Project-Script-Architecture-of-Chernarus-mission.md` | [Miksuu Wiki Archive: Chernarus Mission Script Architecture](Miksuu-Wiki-Archive-Project-Script-Architecture-Of-Chernarus-Mission) | Archive with caveat | Historical architecture checklist and external diagram/PDF links. |
| `Development-process-(for-Miksuu's-Portfolio-return).md` | [Miksuu Wiki Archive: Development Process](Miksuu-Wiki-Archive-Development-Process) | Summarize and archive | SQF debugging, GPT, Trello, branch/test workflow, performance lessons. |

## History-only pages not imported as standalone pages

| Historical file | Git history | Decision |
| --- | --- | --- |
| `Problems-and-solutions-(for-Miksuu's-Portfolio-return).md` | Created `58915c8`, updated, then deleted/replaced by the development-process page at `b098512` on 2024-03-25. | Do not import separately; current content lineage is represented by [Development process](Miksuu-Wiki-Archive-Development-Process). |
| `Big-annoucenements.md` | Typo predecessor created `1076ef2`, deleted/renamed by `bc0d79c` on 2023-12-23. | Do not import separately; represented by [Big announcements](Miksuu-Wiki-Archive-Big-Announcements). |
| `Raysway-Update-Notes.md` | Created by Ray Reijnders at `12b6fd4` and deleted ten seconds later at `45ef3da` on 2026-06-02. | Do not import; the only observed content was a transient placeholder and no page remains at HEAD. |
| `test1.md`, `Home-test1.md` | Marty-created test pages on 2023-06-11, then deleted. | Skip as test artifacts. |

## External media to preserve as links

The upstream wiki does not track binary files at HEAD, but several pages link to external media:

| Page | External media |
| --- | --- |
| [Chernarus mission architecture](Miksuu-Wiki-Archive-Project-Script-Architecture-Of-Chernarus-Mission) | Discord-hosted architecture PNG and PDF. |
| [Changelog](Miksuu-Wiki-Archive-Changelog) | GitHub asset images, Discord CDN images, videos and `.ogg` audio links. |
| [Gameplay videos](Miksuu-Wiki-Archive-Gameplay-Videos) | YouTube Live gameplay link. |

Do not rewrite or mirror external media without a separate asset-preservation pass. Keep the original URLs visible so the archive remains traceable.

## Current-source caveats

| Upstream claim area | Why it needs caution | Current canonical route |
| --- | --- | --- |
| LoadoutManager terrain propagation | Upstream pages describe broad modded-terrain copying. Current docs/source say maintained generated output is Vanilla Takistan and modded propagation is inactive or non-authoritative. | [Tools and build workflow](Tools-And-Build-Workflow), [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas) |
| Architecture folder walkthrough | The upstream architecture page is broad and partly stale; current file names and compile ownership should be taken from source-backed atlases. | [Architecture overview](Architecture-Overview), [SQF code atlas](SQF-Code-Atlas), [Function and module index](Function-And-Module-Index) |
| Discord bot page | Upstream page is a stub and does not document the current in-repo `.NET` bot shape. | [External integrations](External-Integrations), [Integration trust boundary audit](Integration-Trust-Boundary-Audit) |
| Changelog feature status | Old release notes may describe old server state, branch state or reverted work. | [Feature status register](Feature-Status-Register), [Current source status snapshot](Current-Source-Status-Snapshot) |

## Agent rules

1. Use these archive pages as provenance and candidate lessons.
2. Promote a claim only after checking current source, branch history or the existing source-backed docs.
3. Preserve contributor names and cultural context, but avoid converting Discord-era wording into current-role claims.
4. When an upstream page conflicts with current source-backed docs, keep both: archive the upstream claim and route implementation work to the current canonical page.

## Continue Reading

Previous: [Community & Dev](Community-And-Dev) | Next: [Miksuu Wiki Archive: Project Welcome](Miksuu-Wiki-Archive-Welcome)

Related: [Developer history and upstream lessons](Developer-History-And-Upstream-Lessons) | [Upstream Miksuu commit intel](Upstream-Miksuu-Commit-Intel) | [`agent-upstream-wiki-imports.jsonl`](agent-upstream-wiki-imports.jsonl)
