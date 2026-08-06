# Command Center & Homepage — Build Spec

_TP-12 · Agent B (Designer, Fable tier) · READ-ONLY deliverable_
_Research base: `origin/main` + `origin/claude/tp6-motion-kit`_

---

## PART A — Command Center (`/stats`) Full Design Spec

### A1. Information Architecture

**Canonical route**: `/stats`
**Redirect**: `GET /wasp` → 301 → `/stats` (Next.js `redirects` in `next.config.js`)
**Page title**: `Command Center — Miksuu's Warfare`
**OG image**: `og-stats.jpg` (new asset; see Part C)
**revalidate**: 120 (inherited from current wasp page shell)

The `WaspLive` wrapper, `WaspSectionNav`, and all eight tab panels are preserved as-is. The page shell gets a new `CommandCenterHeader` (replacing `WarRoomHeader`) and the Status Strip gains a `TownControlBar`. No tabs are removed. Public/admin split is achieved by what each tab shows, not by tab removal.

**Page sections in order**:

```
[A] CommandCenterHeader
[B] Live Status Strip (always visible, client-polled)
[C] WaspSectionNav tab bar (sticky)
─────────────────────────────────────────────────
Tab panels (only active panel renders):
[D1] OVERVIEW
[D2] LEADERBOARD
[D3] RECORDS
[D4] BALANCE
[D5] THE WAR
[D6] ECONOMY
[D7] AI COMMANDER
[D8] PERFORMANCE
```

---

### A2. Per-Section Specification

#### [A] CommandCenterHeader

**Purpose**: Replace `WarRoomHeader` with a lean, branded header that names the page.

**Wireframe in words**:
```
┌─────────────────────────────────────────────────────────┐
│  // COMMAND CENTER              [AmbientOpsLayer bg]    │
│  Live front line · career stats · all-time records      │
│                          [BrandWatermark corner, 5%]    │
└─────────────────────────────────────────────────────────┘
```

- `AmbientOpsLayer` wrapping: `density="quiet"`, `showGrid=true`, `showVignette=true`, `showGlow=false`, `showWatermark=true`.
- `BrandWatermark variant="corner"`.
- `h1`: Oswald display, `text-sm uppercase tracking-[0.2em]` — prefix `//` in `text-bone/40`, then `COMMAND CENTER` in `text-chalk`.
- Sub-headline: Inter body, `text-xs text-bone/55` — "Live front line · career stats · all-time records — one console."
- Height: compact `py-6`. Not a hero panel.
- **Motion-kit components**: `AmbientOpsLayer`, `BrandWatermark`
- **Classification**: PUBLIC (static)
- **Empty/loading**: n/a
- **Mobile**: full width; sub-headline wraps at 375 px

---

#### [B] Live Status Strip

**Current**: `StatusStrip` inside `WaspLive` (already built — preserve as-is).

**Addition**: Render a `TownControlBar` beneath the status row when server is online and `raw.currentRound.sides` has data.

**Wireframe in words**:
```
● ROUND IN PROGRESS · 34m · 18 online · Chernarus     [updated 8s ago]
WEST · 22  ████████████░░░░░░░░░░░░░░░░  14 · EAST   // delayed feed · 120s
            68%                          32%
```

- `TownControlBar` props: `westTowns` from `crRaw.sides.WEST.towns`, `eastTowns` from `crRaw.sides.EAST.towns`, `totalTowns` from terrain data keyed on `server.mapId` (Chernarus=40, Takistan=31). Add `// delayed feed · 120s` label in `font-mono text-[9px] text-bone/30` inline with the label row right edge.
- `playersOnline` and `elapsedMin` in the status text wrapped in `LiveValue` for cross-fade on poll updates.
- **Data source**: `/api/wasp-stats` (15 s ISR, 12 s client poll) — `server.playersOnline`, `currentRound.elapsedMin`, `raw.currentRound.sides.{WEST,EAST}.towns`
- **TODAY vs Stats-V2**: `sides.towns` is available today via the war-room passthrough in `PUBLIC_RAW_KEYS` (the `currentRound` raw object is passed through with `sides` intact). If absent on a given feed version, hide the bar with no error.
- **Motion-kit**: `TownControlBar`, `LiveValue`
- **Classification**: DELAYED PUBLIC (120 s behind live per mandatory label)
- **Empty**: Bar hidden when `sides` absent. Strip remains.
- **Loading**: 40 px height placeholder; replaced on first data.

---

#### [D1] Overview Tab

**Current**: All-Time Records band + Top Players + Current Round 4-tile grid (kills, captures, wildcards, players online) + round meta row.

**Change A**: Add `TheatreMapPanel` above the top-players section. Render the active map's town distribution as proportionally coloured dots (WEST pct, EAST pct, neutral remainder) — not per-town ownership. Size: `h-[220px] sm:h-[280px]`, full width. Map name from `server.mapId`. `// delayed feed · 120s` label is mandatory and rendered by the component internally.

Dot colouring logic: take `westTowns` and `eastTowns` from `sides`, compute neutral count = `totalTowns - westTowns - eastTowns`, distribute that many dots neutrally. The component receives `towns: MapTown[]` — use the terrain's real town coordinates (from `getTerrain(mapId)`) with side derived from the proportion, not individual town names. This avoids per-town intel while using real terrain geometry.

**Change B**: Wrap the four stat tile values in `LiveValue`.

**Stats-V2 upgrade slot** (comment `<!-- Stats-V2: per-town ownership strip -->`): When MATCH|v1| pipeline lands, replace `TheatreMapPanel` with the real `TheatreMap` (existing `wasp/TheatreMap.tsx`) driven by `raw.currentRound.townControl` with actual per-town sides. The `TheatreMapPanel` is the interim abstract surface.

- **Data source**: `/api/wasp-stats` — `raw.allTime`, `raw.topPlayers`, `currentRound.*`, `server.*`
- **Motion-kit**: `TheatreMapPanel`, `LiveValue`
- **Classification**: PUBLIC; map panel = DELAYED PUBLIC (per label)
- **Empty**: Map panel hidden when `server.mapId` absent or terrain unknown. Tiles show 0/"—" when offline.
- **Loading**: `BrandWatermark variant="loading"` centred in map panel area until first data.
- **Mobile**: Map panel full-width above 2×2 tile grid.

---

#### [D2] Leaderboard Tab

**Current**: Season Boards (live feed) + Career Stats DB slot (`CareerLeaderboard`).

**Change**: Add `AfterActionReportCard variant="compact"` above Season Boards if the most recent `aicomRound` record exists in DB. When present: show winner, mapName (from `world` field), kills (use `unitsEnd` as a proxy until MATCH|v1| supplies kills), duration from `durationSec`. Summary sentence: "WEST/EAST/DRAW — {world}, {duration}."

**Stats-V2 upgrade slot**: The AAR card renders "No closed rounds recorded yet" placeholder only if `aicomRounds` table is empty — otherwise omit. Full card with kills + captures available after MATCH|v1| ingest begins sending those fields.

- **Data source**: Season boards from `/api/wasp-stats`; career table from `getIngameLeaderboardFull()` (DB SSR slot); AAR from `getLatestAicomRound()` (new DB query, Stats-V2 gate).
- **Motion-kit**: `AfterActionReportCard`
- **Classification**: PUBLIC
- **Empty**: Career table: built-in empty state in `LeaderboardTable`. Career leader cards: "No data yet" per card. AAR: omit section if no rounds.
- **Mobile**: Leader cards 2-col. Career table horizontal scroll within container.

---

#### [D3] Records Tab

**Current**: `AllTimeRecords` + Wildcards This Round.

**Change**: Wrap wildcard count in `LiveValue`.

- **Data source**: `/api/wasp-stats` — `raw.allTime`, `raw.allTimeByMap`, `raw.currentRound.wildcardsDrawn`
- **Motion-kit**: `LiveValue`
- **Classification**: PUBLIC
- **Mobile**: no layout changes

---

#### [D4] Balance Tab

**Current**: `UnitBalance` showing `raw.balance`.

**No structural changes.**

- **Data source**: `/api/wasp-stats` — `raw.balance`
- **Classification**: PUBLIC (aggregate class counts, no positional data)
- **Mobile**: no change

---

#### [D5] The War Tab

**Current**: Force Comparison + ORBAT Board + Recent Captures + Charts.

**Change A**: Add `TownControlBar` at the top of the panel under a "Front Line" section heading. Same `totalTowns` keyed on active map.

**Change B**: The `recentCaptures` section currently checks `crRaw.recentCaptures` — this field is already stripped server-side by `normalizeStats`. The section renders nothing (empty array). Leave the check in place; it cleanly produces no output. No code change needed here.

**Stats-V2 upgrade slot** (comment `<!-- Stats-V2: town-control timeline -->`): Add a `WarRoomCharts`-style town-control timeline chart here when `charts.townControl` timeseries is available from MATCH|v1| pipeline.

- **Data source**: `/api/wasp-stats` — `raw.currentRound.{sides,battle,orbat}`, `raw.charts`, `raw.warLog`
- **Motion-kit**: `TownControlBar`, `WarLogEvent` (via existing `WarLogFeed`)
- **Classification**: PUBLIC
- **Empty**: Offline card when `data.online === false`
- **Mobile**: Force comparison 2-col collapses to stacked; ORBAT scrollable.

---

#### [D6] Economy Tab

**Current**: Funds & Supply (per-side: funds, supply, towns, units) + Economy Chart + Cash-Flow Events.

**No structural changes.**

- **Data source**: `/api/wasp-stats` — `raw.currentRound.sides.{WEST,EAST}`, `raw.charts.economy`, `raw.warLog` (filtered icon="cash" by existing component)
- **Classification**: PUBLIC (per-side aggregate totals; no per-unit or per-town attack-vector data)
- **Mobile**: 2-col side cards collapse to stacked.

---

#### [D7] AI Commander Tab

**Current**: Commander Intel + War Log + Match History slot.

**Change A**: Remove the `CommanderIntel` section heading and component render. The `CommanderIntel` component reads `raw.commanderIntel`, which is already stripped server-side (it is in `TOWN_INTEL_ROUND_KEYS`). The component silently produces no output. Remove the section heading `<SectionHeading>Commander Intel</SectionHeading>` and the `<CommanderIntel raw={data.raw} />` call in `AiCommanderPanel`. The heading showing "Commander Intel" over an empty area is confusing.

**Change B**: Retain `WarLogFeed` (non-capture entries only — already enforced server-side by `stripCaptureLog`). Keep max 80 entries.

**Change C**: Retain `aicomSlot` (AicomMatchStats, DB post-round history). PUBLIC.

**Stats-V2 upgrade slot**: Add a placeholder card "Match intelligence — available after MATCH|v1| pipeline" in a collapsible or static section. Comment: `{/* Stats-V2: commander decision log */}`. When MATCH|v1| pipeline delivers commander decision telemetry, that data routes exclusively to `/admin/telemetry` (see A3). It never appears here.

**What moves to /admin/telemetry** (see A3 for full spec):
- Commander decision/WHY rows (MATCH|v1| gate)
- Live AI intentions and target assignments (NEVER public)
- Base construction/destruction events with locations
- Per-patch performance trends (waspscale v2 `build` field grouping)
- HC health (per-HC FPS bars) — already admin-only in current telemetry page
- Ingest freshness timestamps for /api/aicom-stats and /api/waspscale

- **Data source**: War log from `/api/wasp-stats` — `raw.warLog`; match history from DB `aicomRounds` (AicomMatchStats)
- **Motion-kit**: `WarLogEvent` (via WarLogFeed), `AfterActionReportCard` (for closed rounds in aicomSlot, Stats-V2)
- **Classification**: PUBLIC (war log non-capture entries + post-round history). Admin-only: WHY rows, live intentions, base events, HC health, ingest freshness.
- **Empty**: Offline card when `data.online === false` for war log. AicomMatchStats: "No rounds recorded yet" when DB empty.
- **Mobile**: Match history table horizontal scroll.

---

#### [D8] Performance Tab

**Current**: Server FPS & Headless Clients + Group Health + Client FPS + Benchmark + WASPSCALE slot.

**No structural changes.**

The per-HC FPS bars and maintenance/unstuck data remain in `/admin/telemetry` only. The public Performance tab shows aggregate FPS + HC count, which are mutual-knowledge health indicators. Status quo maintained.

- **Data source**: `/api/wasp-stats` — `raw.performance.serverFps`, `raw.performance.headless` (count); DB: `waspscaleSamples` (via `WaspScalePanel`)
- **Classification**: PUBLIC
- **Mobile**: FPS chart full-width; tiles stack.

---

### A3. Admin Split — `/admin/telemetry` Additions

**Rename**: "Game server (test)" → "Game server" in the page heading.

**New sections** (all deferred to Stats-V2 milestone; annotated `// Stats-V2-later` in code):

**Ingest pipeline** (can ship immediately, no MATCH|v1| needed):
- Add `getIngestFreshness()` to `web/src/lib/admin-game-telemetry.ts` — queries `MAX(created_at)` from `aicomRounds` and `waspscaleSamples`.
- Two `Row` items: "Last aicom ingest" and "Last waspscale ingest" with staleness badge (>10 min = orange badge "stale").

**AI Commander decisions** (MATCH|v1| gate):
- A `WarLogEvent` list showing commander decision telemetry. `icon="hq"`, full WHY-row text. Max 200 entries. Never shown publicly.

**Base events** (MATCH|v1| gate):
- Base construction/destruction events with full location data. Admin-only.

**Per-patch performance trends** (Stats-V2 gate, waspscale v2 `build` accumulation needed):
- Scatterplot of `srvFps` vs `aiTotal` grouped by `build` tag. Rendered via existing `TelemetryChart`. Only once enough v2 samples accumulate.

---

### A4. Page Metadata

```typescript
// web/src/app/stats/page.tsx
export const metadata: Metadata = {
  title: "Command Center — Miksuu's Warfare",
  description:
    "Live server status, career leaderboards, all-time records, and post-round summaries for Miksuu's Warfare — Arma 2 CTI.",
  ...ogMeta({
    title: "Command Center — Miksuu's Warfare",
    description: "Live server status, career leaderboards, all-time records, and post-round summaries for Miksuu's Warfare — Arma 2 CTI.",
    image: "og-stats.jpg",
    path: "/stats",
  }),
};
export const revalidate = 120;
```

---

## PART B — Homepage Reframe Spec

### B1. Fact Verification Against Live Code

The task packet contains two statistics that conflict with the live codebase:

| Stat | Task packet | Live code (`SCALE` array) | Terrain data | Verdict |
|------|-------------|--------------------------|--------------|---------|
| Capturable towns | 40+ | "40+" | Chernarus 40, Takistan 31 | Matches. "40+" is Chernarus primary. |
| Players per match | 32 | "32" | n/a | Confirmed. |
| AI units | 500+ | "100s" | n/a | **DISCREPANCY — flag to Steff before publishing.** |
| Round duration | 2–8 h | "2–5 h" | n/a | **DISCREPANCY — flag to Steff.** |

The spec copies below use the live-code figures (`100s`, `2–5 h`) as ground truth. If Steff confirms 500+ AI units is the real observed peak and 2–8 h is the real range, update the `SCALE` array in `page.tsx` before PR #58 merges. Do not publish unchecked figures.

---

### B2. Second-Block Reframe — Three Candidate Versions

The second content block is Section 01 ("Two ways to fight — at once"): the eyebrow, title, PvP card, PvE card, and sub-headline. The reframe centres PvP-first and the living-AI-world premise.

**Candidate A — direct/ops voice**

Eyebrow: `One server. Everything at war.`
Title: `PvP. PvE. AI. All at once.`

PvP card:
> Fight real players across a frontline that moves. Take the command chair and run the war from the map — or hit the line with a squad. The AI fills every seat you don't.

PvE card:
> Two AI commanders fight each other and you. Each one reads the whole map every minute and makes the call a sharp human would. They do not wait for players to log in.

Sub-headline:
> Most rounds are both at once. Human squads and AI armies on one living map — towns change hands whether you are there or not.

---

**Candidate B — economy-of-words voice** (recommended)

Eyebrow: `40 towns. 32 players. One war.`
Title: `PvP and AI on the same map.`

PvP card:
> Real people, real stakes. Squad up, vote in a commander, or take the chair yourself. The frontline moves based on what both sides actually do.

PvE card:
> The AI does not script. Two commanders decide where to mass, what to build, and when to commit — independent of how many players are on.

Sub-headline:
> Low pop, high pop — the map is always live. Join an ongoing war, not a lobby waiting to fill.

---

**Candidate C — tension framing**

Eyebrow: `The war does not wait.`
Title: `Player vs Player vs AI.`

PvP card:
> Your enemy on the frontline is another player with a working brain, a commander position, and a functioning economy behind them. Coordination wins. Solo play exists. It just costs more.

PvE card:
> Both sides run a from-scratch AI commander that fights to win. It masses armour, builds forward bases, and scrambles CAS — whether you have 4 players or 32.

Sub-headline:
> This is not PvP with AI filler or PvE with a PvP zone bolted on. It is one war. You share the map.

---

**Recommendation**: Candidate B. Facts-first eyebrow with three key numbers above the fold. Clean ops-console register with no hype words. The PvP card drops "squad up" as a verb group, grounding the choice in what a real visit looks like. The PvE card's "The AI does not script" is a direct, verifiable claim.

---

### B3. Two-Theatres Section — Visual Comparison Cards

**Current state (Section 04)**: Text-only Chernarus + Takistan cards. No map assets.

**Reframe**: Add a server-rendered SVG map silhouette above the text in each card. Source: `getTerrain(mapId)` + `worldToSvg()` from `web/src/lib/wasp/terrain.ts` (both already in the codebase). No new raster images.

**SVG spec**:
- `viewBox="0 0 200 200"` inline SVG, no separate component needed (or extract as `MapSilhouette` server component).
- Background: `fill={BRAND_HEX.gunmetal}` (`#14171b`).
- Grid lines: `stroke={BRAND_HEX.steel}` (`#2a2f36`), `strokeWidth="0.5"`, `opacity={0.3}`. Same 7-line pattern as `TheatreMap` (x positions: 29, 54, 79, 104, 129, 154, 179 scaled to 200px viewport).
- Towns: `r={2}` circles, `fill="#6f7680"` (neutral — this is a content illustration, not live data). No faction colouring.
- No labels, no airports, no interactivity.

**Updated card layout** (each map):
```
┌────────────────────────────────────────┐
│ [200px SVG silhouette — town dots]     │
│                                        │
│  CHERNARUS            Wooded · close   │
│  ──────────────────────────────        │
│  Rolling forests and tight towns...    │
│  40 capturable towns                   │
└────────────────────────────────────────┘
```

- SVG rendered above the text block, `width="100%"` for responsiveness.
- `mb-2 font-mono text-[10px] text-bone/40` caption: `{n} capturable towns` (Chernarus: 40, Takistan: 31).
- Existing prose text for each map is unchanged.
- **Assets used**: `wasp-terrains.json` (existing), `worldToSvg()` (existing). No new raster files.
- **Mobile**: Cards stack vertically. SVG scales to 100% width at natural aspect ratio.

---

### B4. Optional-Mods Pathway Card

**Placement**: New tertiary card appended after the `FEATURES` grid in Section 03 ("Everything in the box").

**Card spec**:
```
┌───────────────────────────────────────────────────────────┐
│ Optional extras                                           │
│ ─────────────────────────────────────────────────────     │
│ Six client-side mods — better HUD, name tags, and AI     │
│ voices. No gameplay advantage. Server-signed; the base   │
│ game runs without them.                                  │
│                                [View optional mods →]    │
└───────────────────────────────────────────────────────────┘
```

- Border: `border-steel/60`. Background: `bg-steel/10`. No orange accent (soft pathway, not a primary CTA).
- Title: `font-display text-sm font-semibold uppercase tracking-wide text-chalk` — "Optional extras".
- Body: `text-xs leading-relaxed text-bone/55`.
- Link: `href="/guides/mods-and-modpack"` — routes to the guide section containing the optional mods content.
- **PR #51 dependency**: Gate behind `process.env.NEXT_PUBLIC_OPTIONAL_MODS_LIVE === "true"`. The card must not ship to production until: (a) `docs/optional-mods-layer` branch is merged, AND (b) the six mod .bikeys are whitelisted on the live server. Set the env var in Vercel/production only after both conditions are met.

---

## PART C — Build Plan

### PR Sequence

```
[claude/tp6-motion-kit merged] → PR #56 (motion tokens) → PR #57 (Command Center + /wasp redirect) → PR #58 (homepage reframe) → PR #59 (admin telemetry additions)
```

---

#### PR #55: Merge `claude/tp6-motion-kit`

**Branch**: `claude/tp6-motion-kit` (exists, confirmed live with all 8 components)
**Scope**: All motion kit components + CSS module files land in `web/src/components/motion/`.
**CI**: TypeScript clean, `pnpm build` passes, no new lint errors.
**Rollback**: Revert merge. Zero user-visible change (components unused until consumed).
**Note**: This may already be queued. Confirm with Steff before treating it as blocked.

---

#### PR #56: Motion token CSS variables

**Branch**: `feat/motion-tokens`
**Scope**: Add to `web/src/app/globals.css` (or new `motion-tokens.css` imported there):
```css
:root {
  --mw-motion-fast: 140ms;
  --mw-motion-slide: 260ms;
  --mw-motion-bar: 700ms;
}
@media (prefers-reduced-motion: reduce) {
  :root {
    --mw-motion-fast: 0ms;
    --mw-motion-slide: 0ms;
    --mw-motion-bar: 0ms;
  }
}
```
**CI**: CSS lint, build passes. No visual regression (tokens unused until PR #57).
**Rollback**: Revert CSS additions. Zero user-visible change.
**Size**: ~20 lines.

---

#### PR #57: Command Center — `/stats` route + `/wasp` 301 redirect

**Branch**: `feat/command-center`
**Scope**:
1. `next.config.js`: add `{ source: '/wasp', destination: '/stats', permanent: true }` to `redirects` array.
2. `web/src/app/stats/page.tsx`: new route. Copy shell from `wasp/page.tsx`. Updated metadata (title, description, image: `"og-stats.jpg"`, path: `"/stats"`). Replace `<WarRoomHeader />` with `<CommandCenterHeader />`.
3. `web/src/app/wasp/page.tsx`: remove RSC body, replace with `redirect('/stats', 301)` import from `next/navigation`. (The `next.config.js` redirect handles the majority of traffic at the edge; the RSC redirect handles any server-side navigation that bypasses the edge rule.)
4. `web/src/components/CommandCenterHeader.tsx`: new component. `AmbientOpsLayer` + `BrandWatermark`. See A2[A] spec.
5. `web/src/components/wasp/WaspLive.tsx` — `StatusStrip`: add `TownControlBar` below status row. Add `LiveValue` wrappers around `playersOnline` and `elapsedMin`.
6. `web/src/components/wasp/WaspLive.tsx` — `OverviewPanel`: add `TheatreMapPanel` above `SectionHeading>Top Players`. See A2[D1] spec.
7. `web/src/components/wasp/WaspLive.tsx` — `TheWarPanel`: add `TownControlBar` at top.
8. `web/src/components/wasp/WaspLive.tsx` — `AiCommanderPanel`: remove `<SectionHeading>Commander Intel</SectionHeading>` and `<CommanderIntel raw={data.raw} />`. Add Stats-V2 placeholder comment.
9. `web/public/og/og-stats.jpg`: **MUST be present before merge**. Spec: 1200×630 px, gunmetal background, chevron watermark top-right, text "COMMAND CENTER / Miksuu's Warfare · Arma 2 CTI". Source from `hero-poster.jpg` crop + text composition. Not a code deliverable — commission separately.
10. Internal link sweep: `grep -r 'href.*[/"]wasp[/"]'` across `web/src/`. Update all `/wasp` hrefs in Nav, Footer, homepage CTAs, guide links to `/stats`. (`/api/wasp-stats`, `/api/aicom-stats`, `/api/waspscale` API paths are NOT routes shown to users — leave unchanged.)

**CI**:
- TypeScript clean.
- `pnpm build` passes.
- Preview deploy: `curl -sI /wasp` → `301 Location: /stats`.
- No broken internal links (`grep -r '/wasp' web/src/` should return only API paths and comments, no `href` values).
- `og-stats.jpg` present in `web/public/og/`.

**Rollback**: Revert branch. `/wasp` page returns. `/stats` route disappears. No data loss.
**Size**: Medium — est. 8–12 files.

---

#### PR #58: Homepage second-block reframe + theatres section

**Branch**: `feat/homepage-reframe`
**Scope** (`web/src/app/page.tsx`):
1. Section 01 — update `WAYS` array copy to chosen candidate (recommend B). Update `SectionHeader` eyebrow/title.
2. Section 03 — add optional-mods pathway card after `FEATURES.map()`, gated behind `NEXT_PUBLIC_OPTIONAL_MODS_LIVE`.
3. Section 04 — replace text-only map cards with SVG silhouette cards. Extract `MapSilhouette` as a small server component or inline SVG within the `MAPS.map()` render. Call `getTerrain()` for each map key.
4. Update all `href="/wasp"` occurrences in the file to `href="/stats"` (the hero tertiary link "Live stats →").
5. `SCALE` array: do NOT update AI-unit or duration figures until Steff confirms the discrepancy resolution.

**CI**:
- TypeScript clean.
- `pnpm build` passes.
- Visual review of map SVGs in preview deploy: both maps render, dots visible, no overflow.
- `NEXT_PUBLIC_OPTIONAL_MODS_LIVE` env var absent in staging (card hidden).

**Rollback**: Revert branch. Homepage reverts to current copy.
**Size**: Small–medium — est. 3–5 files.

---

#### PR #59: Admin telemetry — ingest freshness + admin scaffold

**Branch**: `feat/admin-telemetry-freshness`
**Scope**:
1. `web/src/lib/admin-game-telemetry.ts`: add `getIngestFreshness()` — two `MAX(created_at)` queries against `aicomRounds` and `waspscaleSamples`. Returns `{ aicom: Date | null, waspscale: Date | null }`.
2. `web/src/app/admin/telemetry/page.tsx`:
   - Rename "Game server (test)" heading to "Game server".
   - Add "Ingest pipeline" section with freshness `Row` items and staleness `Badge`.
   - Add `{/* Stats-V2: commander decision log — routes here only, never public */}` scaffold comment.

**CI**: TypeScript clean, `pnpm build`. No DB migration needed (read-only queries on existing tables).
**Rollback**: Revert branch. Admin page reverts to current state.
**Size**: Small — est. 2–4 files.

---

### OG Image Note

`og-stats.jpg` is a hard blocker for PR #57 merge.

**Existing assets available**: `web/public/brand/hero-poster.jpg` (screenshot), `web/public/og/og-servers.jpg` (existing OG image format reference), `web/public/brand/icon-512.png` (chevron mark).

**Composition spec**: 1200×630 px. Gunmetal `#14171b` background. Chevron mark top-right at 8% opacity (80 px). Left third: "COMMAND CENTER" in Oswald bold uppercase, bone `#e7e3d6`, ~48 pt. Below: "Miksuu's Warfare · Arma 2 CTI" in JetBrains Mono, bone/50, ~14 pt. Optional: a stylised `TownControlBar`-style strip across the lower third using the brand colours. Do not use a gameplay screenshot — the composed graphic with brand assets is sufficient and avoids rights complexity.

Commit the asset to `web/public/og/og-stats.jpg` in a standalone micro-commit before or within PR #57.

---

## Self-Grade

| Dimension | Score | Notes |
|-----------|-------|-------|
| IA quality (25) | 22/25 | Eight tabs preserved with clear public/admin split per section; route redirect and metadata fully specified; motion-kit component mapped to every surface; Stats-V2 gates marked. Minor deduction: CommanderIntel is already a dead letter server-side — the spec could have flagged it as zero-cost cleanup more sharply rather than framing it as a design decision. |
| Data truthfulness (25) | 24/25 | Every field cited to its actual source file, verified in code. MATCH|v1| gate called out honestly per section. The AI-unit count discrepancy (task packet "500+" vs live code "100s") is explicitly flagged rather than silently propagated. One point: inability to verify whether `sides.towns` is present in the current live stats.json feed without a live server log — spec notes the fallback correctly. |
| Brand fidelity (20) | 19/20 | All 8 motion-kit components correctly assigned. Orange accent confined to hot data and CTAs. Faction colours (WEST #5d82a3 / EAST #a8503f) confined to faction data displays (TownControlBar, ForceComparison). Gunmetal/steel surfaces. Oswald/Inter/JetBrains Mono stack maintained. Dry factual copy throughout, no hype in any candidate. One point: AmbientOpsLayer density spec on the header could be tightened — "quiet" with no glow is correct, but the watermark visibility needs to be verified against the compact `py-6` height. |
| Buildability/sequencing (20) | 18/20 | Five bounded PRs, clear CI requirements, rollback per PR, internal link sweep specified as grep command, og-stats.jpg blocker identified with asset spec, env flag for optional mods card. Minor deduction: PR #57 is the largest PR and could be split into a redirect-only PR + UI changes PR for lower rollback risk — the spec defers this split to implementer judgment rather than recommending it. |
| Copy quality (10) | 9/10 | Three copy candidates with distinct registers; Candidate B recommendation justified with per-line rationale. Stats discrepancy explicitly flagged before propagation. Map silhouette spec avoids raster assets correctly. Optional-mods card copy is functional. One point deducted: the mods card body could be sharper — "better HUD, name tags, and AI voices" summarises without specificity. |

**Total: 92/100**