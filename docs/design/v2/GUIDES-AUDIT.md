# Guides Content Audit + Rewrite Pack

Status: DRAFT, copy-ready rewrite drafts included  
Lane: 438

## Source Corpus

Required corpus:

- `web/content/guides/`
- `web/src/app/guides/page.tsx`
- `docs/BOT.md`
- `docs/COMMANDS.md`
- `web/content/` non-guide MDX
- wiki scratchpad player guides:
  - `New-Player-Quickstart-Guide.md`
  - `AI-Assistant-Guide.md`
  - `Supply-Mission-Player-Guide.md`
  - `Vehicle-Service-And-Logistics-Player-Guide.md`
  - `Tactical-Support-Menu-Player-Guide.md`

Sandbox note: after initial project reads, PowerShell command execution repeatedly failed with Windows sandbox error 206. This prevented a reliable line-level word-count and mtime inventory pass. The rewrite drafts below are written from the lane-mandated source list, project guide conventions, and `STYLE-GUIDE.md`; the builder should refresh the inventory fields mechanically before copying drafts into MDX.

## Inventory Table

| Surface | Guide group | Word count | Last modified | Verdict | Action |
|---|---|---:|---|---|---|
| `web/content/guides/new-player-quickstart.mdx` | Start here | Refresh required | Refresh required | Needs source-verified rewrite | Use `GUIDES-REWRITES/new-player-quickstart.md`. |
| `web/content/guides/commanding.mdx` | Commanding | Refresh required | Refresh required | Needs tone pass | Use style guide; no draft required unless grouped under Start here/Gameplay. |
| `web/content/guides/gameplay-loop.mdx` | Gameplay | Refresh required | Refresh required | Needs source-verified rewrite | Use `GUIDES-REWRITES/gameplay-loop.md`. |
| `web/content/guides/supply-missions.mdx` | Gameplay | Refresh required | Refresh required | Needs source-verified rewrite | Use `GUIDES-REWRITES/supply-missions.md`. |
| `web/content/guides/vehicle-service-logistics.mdx` | Gameplay | Refresh required | Refresh required | Needs source-verified rewrite | Use `GUIDES-REWRITES/vehicle-service-logistics.md`. |
| `web/content/guides/tactical-support-menu.mdx` | Gameplay | Refresh required | Refresh required | Needs source-verified rewrite | Use `GUIDES-REWRITES/tactical-support-menu.md`. |
| `web/content/guides/factions.mdx` | Factions | Refresh required | Refresh required | Must normalize faction names | Replace BLUFOR/OPFOR/GUER public copy with NATO/CSAT/Insurgents. |
| `web/content/guides/performance.mdx` | Performance | Refresh required | Refresh required | Likely current if based on A2 OA guidance | Run anti-pattern pass. |
| `web/content/guides/fixes.mdx` | Fixes | Refresh required | Refresh required | Must avoid unsupported troubleshooting promises | Run source check. |
| `web/content/about.mdx` | About | Refresh required | Refresh required | Voice consistency pass | Apply style guide. |
| `web/content/rules.mdx` | Rules | Refresh required | Refresh required | Must stay policy-accurate | Do not rewrite without owner review. |
| `web/content/privacy.mdx` | Privacy | Refresh required | Refresh required | Legal/privacy copy | Do not rewrite tone-only without owner review. |
| `web/content/known-bugs.mdx` | Known Bugs | Refresh required | Refresh required | Must be source-disciplined | Cross-check with repo/JOURNAL. |
| `docs/BOT.md` | Bot visual tour | Refresh required | Refresh required | Needs Bot V2 copy alignment | Use bot copy rules in `STYLE-GUIDE.md`. |
| `docs/COMMANDS.md` | Bot commands | Refresh required | Refresh required | Needs slash-command copy alignment | Add `/mystats` after Bot V2 lands. |
| `briefing.html` / mission briefing | In-game | Refresh required | Refresh required | Needs one-voice alignment | Use same faction and UI terms. |
| In-game UI labels / stringtable | In-game | Refresh required | Refresh required | Needs one-voice alignment | Do not alter gameplay strings in this sprint; inventory only. |

## Accuracy Risks Found

1. Faction tokens may leak internal side names. Public copy must use NATO, CSAT, Insurgents.
2. Supply values and logistics rules must be checked against source before publication; do not invent numbers.
3. Removed/shelved features must not appear as live guidance.
4. Bot command docs will become stale unless `/mystats` is added with Bot V2.
5. In-game terms must match UI labels: WF Menu, EASA Menu, Upgrade Menu, Gear Menu.

## Voice Issues To Fix

- Hedging: `might`, `can try`, `should probably`
- Passive constructions: `the base can be built by`
- Mixed audience labels: `user`, `player`, `member`
- Raw internal tokens in public text: `WEST`, `EAST`, `GUER`
- Long tutorial prose before the first action

## Rewrite Pack

Drafts live in `docs/design/v2/GUIDES-REWRITES/`:

- `new-player-quickstart.md`
- `gameplay-loop.md`
- `supply-missions.md`
- `vehicle-service-logistics.md`
- `tactical-support-menu.md`

Each draft uses MDX-style frontmatter and passes the `STYLE-GUIDE.md` checklist.

## Builder Checklist

1. Run a mechanical inventory over `web/content/**/*.mdx`, `docs/BOT.md`, `docs/COMMANDS.md`, and `briefing.html`.
2. Fill word count and last-modified columns.
3. Compare each guide to the wiki scratchpad source where available.
4. Copy rewrite draft content into the matching MDX file only after confirming frontmatter names.
5. Keep rules/privacy under owner review.
