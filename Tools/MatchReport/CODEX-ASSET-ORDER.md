# Codex image-gen work order — WASP Match-Report (Miksuu brand)

**Goal:** generate the report's art assets in ChatGPT (image-gen-2), on the Miksuu's Warfare brand.

**Save every output to:** `Tools/MatchReport/assets/<exact filename>`
*(if MatchReport isn't in your tree yet: `git fetch origin && git checkout claude/match-report-video` first, or just save the PNGs and the Game side composites them)*

**Rules**
- Use the **exact filename** below — it's the tracking key the renderer matches on.
- **Exact pixel size**; transparent PNG where noted; everything else opaque.
- **No text / lettering / wordmarks** (the generator garbles them; titles are added in code).
- **Append the STYLE SUFFIX to every prompt.**
- Full reference: `miksuus-warfare/brand/IMAGE-GEN-BRIEF.md`.

**STYLE SUFFIX** (append to each prompt):
> — in a Cold-War military "ops-console" style: cold gunmetal #14171B and steel #2A2F36 base, olive-drab #5C6536 military tones, a single warm orange #D9763C accent used sparingly, bone #E7E3D6 linework, cinematic low-key lighting, fine film grain, subtle vignette, gritty tactical realism, muted desaturated grade, highly detailed and accurate, NOT cartoonish, NOT neon, NOT orange-and-teal, no text, no lettering, no watermark.

**NEGATIVE** (if the tool supports one):
> neon, RGB, cartoon, chibi, toy, low-poly, bright saturated colors, orange and teal, lens flare, text, letters, watermark, logo wordmark, cute, glossy plastic

---

## TIER 1 — do first (biggest payoff)

**`intro_splash.png`** — 1080×1920, opaque
> A tall vertical cinematic background of a Cold-War battlefield at dusk on an Eastern-European plain — distant haze, a faint topographic / MGRS grid overlay, a drifting tank silhouette low on the horizon, heavy film grain and vignette, mostly empty dark negative space through the vertical center for a title.

**`winner_bg_blufor.png`** — 1080×1920, opaque
> A tall vertical victory background, sombre and tactical: a dark gunmetal #14171B field with a faint topographic grid, low haze, and a restrained COOL muted blue-grey faction hint rising from the bottom kept subordinate to the gunmetal/olive base, a single sparing orange #D9763C rim of light, film grain, heavy vignette, empty center for stats.

**`winner_bg_opfor.png`** — 1080×1920, opaque
> Same as winner_bg_blufor, but a restrained WARM muted brick-red faction hint rising from the bottom.

**`winner_bg_guer.png`** — 1080×1920, opaque
> Same as winner_bg_blufor, but a restrained muted olive-green faction hint rising from the bottom.

**`emblem_blufor.png`** — 512×512, transparent
> A stylized military stencil faction emblem, NATO-flavored (an angular eagle/star shield motif), muted olive-drab #5C6536 and bone #E7E3D6 with a single sparing orange #D9763C edge accent, transparent background, centered, no national text, no lettering.

**`emblem_opfor.png`** — 512×512, transparent
> A stylized military stencil faction emblem, Warsaw-Pact-flavored (a star-and-laurel shield motif), muted olive-drab #5C6536 and bone #E7E3D6 with a single sparing orange #D9763C edge accent, transparent background, centered, no text.

**`emblem_guer.png`** — 512×512, transparent
> A rough stencil insignia for an irregular partisan force (crossed rifles motif), worn olive-drab #5C6536 and bone #E7E3D6 with a sparing orange #D9763C accent, transparent background, centered, no text.

---

## TIER 2 — signature brand depth (also reusable for Discord/site)

**`silhouette_hind.png`** — 1280×560, transparent
> A military-accurate side-profile silhouette of a Mi-24 Hind gunship, solid dark gunmetal-to-steel gradient fill, a thin warm-orange #D9763C rim-light along the top edge, transparent background, backlit-at-dusk, sharp detailed outline (rotor, weapons pylons, landing gear), no interior detail.

**`silhouette_tank.png`** — 1280×560, transparent
> A military-accurate side-profile silhouette of a T-72 main battle tank, solid dark gunmetal-to-steel gradient fill, a thin warm-orange #D9763C rim-light along the top edge, transparent background, backlit-at-dusk, sharp detailed outline (gun barrel, turret, road wheels, tracks), no interior detail.

**`silhouette_jet.png`** — 1280×560, transparent
> A military-accurate side-profile silhouette of a Cold-War ground-attack jet (Su-25 style), solid dark gunmetal-to-steel gradient fill, a thin warm-orange #D9763C rim-light along the top edge, transparent background, backlit-at-dusk, sharp detailed outline (wings, pylons, tail), no interior detail.

**`mvp_backdrop.png`** — 1080×1920, transparent
> A single dim overhead spotlight cone and the faint backlit silhouette of a lone standing soldier with rifle, low in the frame, gunmetal and olive with a thin orange rim, heavy haze, mostly empty transparent space in the upper half. No text.

---

## TIER 3 — nice-to-have

**`outro_bg.png`** — 1080×1920, opaque
> A tall vertical closing call-to-action card background: dark gunmetal #14171B with a faint topographic grid and low dusk haze, a drifting Hind and tank silhouette bleeding off the bottom corners, a single warm orange #D9763C glow, film grain, heavy vignette, large empty calm center for a logo and a short call-to-action. No text.

**`frame_overlay.png`** — 1080×1920, transparent *(optional — we may keep this procedural; generate one and we'll A/B it)*
> A HUD overlay for a vertical tactical ops-console: thin corner brackets, faint range rings, a small compass rose, MGRS tick marks and registration crosses along the edges, very light scanlines, in bone #E7E3D6 at low opacity with a sparing orange #D9763C accent. The entire CENTER must be fully transparent — decoration only on the outer ~8% border. No text.

---

**Not needed from image-gen** (kept procedural in code): the match **map**, **grain.png**, and (likely) the HUD frame. Don't spend generations on those.

**When done:** drop the PNGs in `Tools/MatchReport/assets/`, then `python render_report.py --sample` — the report picks up each file by name; missing ones fall back to the procedural look. Where a procedural version also exists (intro splash, silhouettes), `python ab_compare.py` does the head-to-head.
