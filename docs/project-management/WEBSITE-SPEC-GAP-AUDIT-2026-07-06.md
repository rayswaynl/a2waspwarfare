# miksuu.com Visual/Motion Spec Gap Audit
**Date:** 2026-07-06  
**Spec:** `miksuus_warfare_claude_visual_motion_brief.txt` (found at `C:/Users/Steff/Downloads/`)  
**Audited PRs:** #56 (brand tokens), #61 (visual/motion kit), #62 (homepage reframe), #63 (Command Center /stats)  
**Branch audited:** `origin/main` of `rayswaynl/miksuus-website-discord-bot`

---

## Summary

The spec called for a comprehensive visual/motion kit: motion tokens, SVG overlay/mask/icon library, asset inventory, brand-lab demo, and 8 named components. What shipped covers roughly 20% of the spec surface. Brand color tokens landed correctly. The AmbientHero (ambient CSS + video hero) partially satisfies `AmbientOpsLayer`. Everything else — motion tokens, folder structure, SVG asset library, and 5 of 8 components — is absent.

**Gaps total: 27**  
**SHIPPED: 7 | PARTIAL: 3 | MISSING: 17**

---

## Gap Table

| # | Spec Requirement | Status | Evidence | Fix Size |
|---|---|---|---|---|
| 1 | `brand/assets-inventory.md` — audit all existing assets before implementing | MISSING | File does not exist anywhere in repo | S |
| 2 | `brand/motion/` directory with `README.md`, `motion-tokens.css`, `examples.html` | MISSING | Directory does not exist | S |
| 3 | Motion tokens: `--mw-motion-fast: 140ms`, `--mw-motion-med: 260ms`, `--mw-motion-slow: 700ms`, `--mw-motion-ambient: 45s` | MISSING | Zero `--mw-motion` occurrences in all of `web/src/` and `brand/tokens.css` | S |
| 4 | Easing tokens: `--mw-ease-standard: cubic-bezier(.2,.8,.2,1)`, `--mw-ease-out: cubic-bezier(.16,1,.3,1)` | MISSING | Not in tokens.css or globals.css | S |
| 5 | Opacity tokens: `--mw-opacity-ghost: .06`, `--mw-opacity-shadow: .12`, `--mw-opacity-grid: .14` | MISSING | Not defined anywhere | S |
| 6 | `brand/overlays/` — grid.svg, grain.svg, vignette.svg, scanline.svg, contours.svg | MISSING | Directory and all SVGs absent | M |
| 7 | `brand/masks/` — chevron-watermark.svg, report-frame-mask.svg, map-fade-mask.svg | MISSING | Directory and all SVGs absent | M |
| 8 | `brand/icons/` — capture.svg, hq.svg, artillery.svg, aircraft.svg, armor.svg, factory.svg, supply.svg, wildcard.svg, server.svg, round-ended.svg | MISSING | Directory and all SVGs absent | M |
| 9 | `brand/examples/` — ambient-hero.html, war-room-map-panel.html, after-action-report.html, discord-embed-preview.html, motion-primitives.html | MISSING | Directory absent | M |
| 10 | `web/src/app/brand-lab/page.tsx` — in-app brand-lab/demo route | MISSING | Route does not exist | M |
| 11 | **Component: AmbientOpsLayer** — density prop (`quiet`/`standard`), showGrid, showVignette, showGlow, showWatermark, watermarkAsset | PARTIAL | `AmbientHero.tsx` does ambient CSS video hero but is hardcoded (no density/prop API); ships as a specific page hero, not a reusable layer component with the spec's prop surface | M |
| 12 | **Component: BrandWatermark** — 5 variants: corner, center-faint, report, discord, loading | MISSING | No such component exists | S |
| 13 | **Component: LiveValue** — fade/translate only, no slot-machine effects, reduced-motion support | MISSING | No such component exists; stat values in WaspLive render static | M |
| 14 | **Component: TownControlBar** — WEST/EAST control bar, smooth width update, faction colors inside only, static fallback | MISSING | No such component exists; no control bar visible anywhere in wasp/ components | M |
| 15 | **Component: TheatreMapPanel** — map/frontline state display using existing map assets or abstract CSS/SVG | PARTIAL | `TheatreMap.tsx` exists and uses abstract SVG (town dots, computed positions) — approach matches spec. But no branded overlay assets (grid, vignette, contours), no ambient layer, no "// delayed feed · 120s" label, no contested pulse ring | M |
| 16 | **Component: WarLogEvent** — compact event row, one-color SVG icons, no emoji, slide-in animation for new entries | MISSING/DEVIATED | `WarLogFeed.tsx` uses emoji glyphs (`⚔ $ ♠ ⌂ ⚑ ✦ ↑ ·`) instead of SVG icons. No separate `WarLogEvent` sub-component. No slide-in animation on new rows. Spec explicitly says "no emoji dependency" | M |
| 17 | **Component: AfterActionReportCard** — 4 variants (compact/wide/share/discord), chevron watermark, orange accent, operational text style | MISSING | No such component exists | L |
| 18 | **Component: DiscordEmbedPreview** — preview Discord embeds, orange accent, existing Discord/logo asset | MISSING | No such component exists | M |
| 19 | Motion tokens referenced in `brand/tokens.css` (spec §Motion Direction) | MISSING | `brand/tokens.css` has only color/semantic tokens — no motion or opacity tokens | S |
| 20 | `mw-ops-surface` CSS pattern — radial gradients + grid pseudo-element (spec §CSS-only atmosphere) | MISSING | Not defined in globals.css or any component CSS | S |
| 21 | Ambient layer: glow orbs (olive + orange) in non-video mode | PARTIAL | `ambient.css` defines `.mw-ambient__orb` keyframes and classes; `AmbientHero` correctly omits them in video mode (correct per spec). Orbs would only appear in a future static-mode ambient — neither used nor exposed as a standalone component. | S |
| 22 | Ambient grain opacity: spec says 0.09 (brand source `ambient.css`) | DEVIATED | Deployed `web/src/components/ambient.css` uses `0.05` — intentional "Scope 2" override per inline comment. Spec value is 0.09; shipped value is 0.05. | S |
| 23 | `prefers-reduced-motion` support across all motion elements | PARTIAL | `ambient.css` has `@media (prefers-reduced-motion: reduce)` which freezes ambient animations. `AmbientHero.tsx` correctly handles reduced motion. No other components have motion to reduce (since they don't exist yet). Formally satisfied for what shipped. | — |
| 24 | Report style: "field report / command summary / stamped card / tactical printout" feel | MISSING | No AfterActionReportCard component exists; no report design has been implemented | L |
| 25 | War Room: "// delayed feed · 120s" and "// live" operational labels | MISSING | `WarRoomHeader` shows `// live · career · records` label (close to spec intent) but the delayed-feed label pattern is absent from the stats panels themselves | S |
| 26 | WarLogFeed: new entry reveal (slide 4–8px, orange marker, NEW label fades out) | MISSING | WarLogFeed renders rows statically with no entry animation | M |
| 27 | Copy discipline: no "epic", "domination", "legendary", "insane" language | SHIPPED | Homepage copy reviewed — restrained, factual; no hype language detected | — |

---

## SHIPPED (fully met)

| Spec Requirement | Evidence |
|---|---|
| Brand color tokens: gunmetal `#14171b`, steel `#2a2f36`, olive `#5c6536`, bone `#e7e3d6`, orange `#d9763c`, chalk `#f2efe8` | `brand/tokens.css` exact match |
| Faction colors `--mw-west` / `--mw-east` defined but semantic-aliased to data only | tokens.css + Tailwind config |
| Typography: Oswald (display), Inter (body), JetBrains Mono (data) | `brand/fonts.css`, `globals.css` |
| WEST/EAST colors trapped inside data components (CommanderIntel, CareerLeaderboard) | Code review of wasp/ components |
| Ambient CSS animations: `mw-fly` 42s, `mw-roll` 64s, `mw-float` 28s/32s | `web/src/components/ambient.css` |
| `prefers-reduced-motion` freeze on ambient animations | `ambient.css` @media block |
| Copy tone: factual, operational, no hype language | Homepage + wasp page content |

---

## Top 5 Most Likely "Not Followed" Items

These are the gaps the owner is most likely to have noticed — either visible on the live site, or clearly promised by the spec's "components to build" section.

**1. Motion tokens completely absent (MISSING)**  
The spec's most concrete deliverable was a set of CSS custom properties (`--mw-motion-fast`, `--mw-motion-med`, `--mw-motion-slow`, `--mw-motion-ambient`, `--mw-ease-standard`, `--mw-ease-out`, opacity tokens). None exist anywhere. These were the foundation for everything else. Without them no downstream component can be spec-compliant.

**2. Five of eight named components were never built (MISSING)**  
`LiveValue`, `TownControlBar`, `AfterActionReportCard`, `DiscordEmbedPreview`, and `BrandWatermark` are completely absent. The spec listed them explicitly in the "Components To Build" section with detailed rules. The War Room stat panels show static numbers, there is no faction control bar, and no report card exists.

**3. WarLogFeed uses emoji instead of SVG icons (DEVIATED)**  
The spec says "use one-color SVG icons" and "no emoji dependency" for `WarLogEvent`. The live `WarLogFeed.tsx` returns Unicode emoji (`⚔ $ ♠ ⌂ ⚑ ✦`) from `iconGlyph()`. This is a visible, hard-specified deviation — the owner can see it on `/wasp`.

**4. Entire SVG asset library missing (brand/overlays, brand/masks, brand/icons) (MISSING)**  
The spec's folder structure called for ~20 SVG files across three directories. None of these directories or files exist. The `TheatreMap` has no branded grid overlay, the ambient hero has no mask primitives, and no operational icons exist to replace the emoji in WarLogFeed.

**5. `brand/assets-inventory.md` never created (MISSING)**  
The spec explicitly said: "Do not start creating new visuals until the inventory exists." This was the mandatory first step — audit what art assets the repo already has before designing anything. It was never done. This procedural gap means subsequent work wasn't grounded in the asset-first workflow the spec mandated.

---

## Notes on AmbientHero / AmbientOpsLayer

`AmbientHero.tsx` is a solid implementation of the ambient video-hero concept and matches the spec's intent for the hero section. The grain opacity deviation (`0.05` vs `0.09`) is self-documented in an inline comment and is a judgment call, not a mistake. However, `AmbientHero` is not the same as `AmbientOpsLayer` — the spec asked for a reusable layer component with a prop API (`density`, `showGrid`, `showGlow`, etc.) that could be applied to hero/report/map sections alike. What shipped is a hardcoded hero section component for the homepage only.

---

## Fix Sizing Key

- **S (Small):** CSS/token additions, no new component surface — 1–2h
- **M (Medium):** New component or SVG asset set — 2–8h per item  
- **L (Large):** Multi-variant component with animation, real data, multiple states — 1–2 days
