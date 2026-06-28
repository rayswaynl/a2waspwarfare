"""
Asset registry — the single source of truth for generated (diffusion) art used
by the report renderer.

The prompts below follow the community's canonical image-gen brief:
  miksuus-warfare/brand/IMAGE-GEN-BRIEF.md   (STYLE SUFFIX, palette, recipes)
  miksuus-warfare/brand/ASSET-WISHLIST.md
Keep STYLE / NEGATIVE in sync with that brief — it is the source of truth for the
whole Miksuu's Warfare image-gen-2 channel, not just this tool.

Workflow ("prompt pack + drop folder"):
  1. `python gen_prompts.py`  prints a ChatGPT-ready prompt for each asset, each
     stamped with the EXACT filename to save as.
  2. Generate each image (ChatGPT / image-gen-2) and save it under `assets/` using
     that exact filename — the filename IS the tracking key.
  3. Re-render: the renderer auto-detects whatever is present and composites it;
     anything missing falls back to the procedural look.

Naming: `<slot>[_<side>].png`, lower-case, no spaces. Sizes are exact. Emblems and
overlays MUST be transparent PNGs. Per the brief: NO rendered text/wordmarks.
"""

# ⭐ Canonical STYLE SUFFIX (verbatim from brand/IMAGE-GEN-BRIEF.md §8) — append to every prompt.
STYLE = ("— in a Cold-War military \"ops-console\" style: cold gunmetal #14171B and steel "
         "#2A2F36 base, olive-drab #5C6536 military tones, a single warm orange #D9763C accent "
         "used sparingly, bone #E7E3D6 linework, cinematic low-key lighting, fine film grain, "
         "subtle vignette, gritty tactical realism, muted desaturated grade, highly detailed and "
         "accurate, NOT cartoonish, NOT neon, NOT orange-and-teal, no text, no lettering, no "
         "watermark.")

# Negative prompt (if the tool supports one) — verbatim from the brief.
NEGATIVE = ("neon, RGB, cartoon, chibi, toy, low-poly, bright saturated colors, orange and teal, "
            "lens flare, text, letters, watermark, logo wordmark, cute, glossy plastic")

ASSETS = {
 "intro_splash": {
    "file": "intro_splash.png", "size": (1080, 1920), "transparent": False,
    "role": "Full-bleed background for the opening title card.",
    "prompt": "A tall vertical cinematic background of a Cold-War battlefield at dusk on an "
              "Eastern-European plain — distant haze, a faint topographic / MGRS grid overlay, a "
              "drifting tank silhouette low on the horizon, heavy film grain and vignette, mostly "
              "empty dark negative space through the vertical center for a title. 9:16 1080x1920. "
              + STYLE},
 "frame_overlay": {
    "file": "frame_overlay.png", "size": (1080, 1920), "transparent": True,
    "role": "Transparent HUD bezel composited over every frame.",
    "prompt": "Transparent PNG HUD overlay for a vertical tactical ops-console, 9:16 1080x1920. "
              "Thin corner brackets, faint range rings, a small compass rose, MGRS tick marks and "
              "registration crosses along the edges, very light scanlines, in bone #E7E3D6 at low "
              "opacity with a sparing orange #D9763C accent. The entire CENTER must be fully "
              "transparent — decoration only on the outer ~8% border. No text. " + STYLE},
 "grain": {
    "file": "grain.png", "size": (1080, 1920), "transparent": True,
    "role": "Low-opacity film-grain/noise overlay on every frame.",
    "prompt": "Transparent PNG fine film-grain / sensor-noise texture, neutral grey monochrome "
              "speckle, evenly distributed, subtle, 1080x1920. Just noise on transparency — no "
              "shapes, no gradient, no text."},
 "emblem_blufor": {
    "file": "emblem_blufor.png", "size": (512, 512), "transparent": True,
    "role": "Western/NATO faction crest (sits on the blue faction card).",
    "prompt": "A stylized military stencil faction emblem, NATO-flavored (an angular eagle/star "
              "shield motif), muted olive-drab #5C6536 and bone #E7E3D6 with a single sparing "
              "orange #D9763C edge accent, transparent background, centered, 512x512, no national "
              "text, no lettering. " + STYLE},
 "emblem_opfor": {
    "file": "emblem_opfor.png", "size": (512, 512), "transparent": True,
    "role": "Eastern/Warsaw-Pact faction crest (sits on the red faction card).",
    "prompt": "A stylized military stencil faction emblem, Warsaw-Pact-flavored (a star-and-laurel "
              "shield motif), muted olive-drab #5C6536 and bone #E7E3D6 with a single sparing "
              "orange #D9763C edge accent, transparent background, centered, 512x512, no text, no "
              "lettering. " + STYLE},
 "emblem_guer": {
    "file": "emblem_guer.png", "size": (512, 512), "transparent": True,
    "role": "Irregular/guerrilla faction crest.",
    "prompt": "A rough stencil insignia for an irregular partisan force (crossed rifles motif), "
              "worn olive-drab #5C6536 and bone #E7E3D6 with a sparing orange #D9763C accent, "
              "transparent background, centered, 512x512, no text. " + STYLE},
 "winner_bg_blufor": {
    "file": "winner_bg_blufor.png", "size": (1080, 1920), "transparent": False,
    "role": "Victory background when the western faction wins.",
    "prompt": "A tall vertical victory background, sombre and tactical: a dark gunmetal #14171B "
              "field with a faint topographic grid, low haze, and a restrained COOL muted blue-grey "
              "faction hint rising from the bottom kept subordinate to the gunmetal/olive base, a "
              "single sparing orange #D9763C rim of light, film grain, heavy vignette, empty center "
              "for stats. 9:16 1080x1920. " + STYLE},
 "winner_bg_opfor": {
    "file": "winner_bg_opfor.png", "size": (1080, 1920), "transparent": False,
    "role": "Victory background when the eastern faction wins.",
    "prompt": "A tall vertical victory background, sombre and tactical: a dark gunmetal #14171B "
              "field with a faint topographic grid, low haze, and a restrained WARM muted brick-red "
              "faction hint rising from the bottom kept subordinate to the gunmetal/olive base, a "
              "single sparing orange #D9763C rim of light, film grain, heavy vignette, empty center "
              "for stats. 9:16 1080x1920. " + STYLE},
 "winner_bg_guer": {
    "file": "winner_bg_guer.png", "size": (1080, 1920), "transparent": False,
    "role": "Victory background when the guerrilla faction wins.",
    "prompt": "A tall vertical victory background, sombre and tactical: dark gunmetal #14171B field, "
              "faint topographic grid, low haze, a restrained muted olive-green faction hint rising "
              "from the bottom subordinate to the gunmetal base, a single sparing orange #D9763C rim "
              "of light, film grain, heavy vignette, empty center for stats. 9:16 1080x1920. " + STYLE},
 "mvp_backdrop": {
    "file": "mvp_backdrop.png", "size": (1080, 1920), "transparent": True,
    "role": "Faint spotlight backdrop behind the MVP card.",
    "prompt": "Transparent PNG backdrop: a single dim overhead spotlight cone and the faint backlit "
              "silhouette of a lone standing soldier with rifle, low in the frame, gunmetal and olive "
              "with a thin orange rim, heavy haze, mostly empty transparent space in the upper half. "
              "9:16 1080x1920. No text. " + STYLE},
 # --- vehicle "blackouts" (brief §6): drifting transparent side-profile silhouettes ---
 "silhouette_hind": {
    "file": "silhouette_hind.png", "size": (1280, 560), "transparent": True,
    "role": "Drifting background layer / scene accent (Mi-24 Hind).",
    "prompt": "A military-accurate side-profile silhouette of a Mi-24 Hind gunship, solid dark "
              "gunmetal-to-steel gradient fill, a thin warm-orange #D9763C rim-light along the top "
              "edge, transparent background, backlit-at-dusk, sharp detailed outline (rotor, weapons "
              "pylons, landing gear), no interior detail. " + STYLE},
 "silhouette_tank": {
    "file": "silhouette_tank.png", "size": (1280, 560), "transparent": True,
    "role": "Drifting background layer / scene accent (T-72 MBT).",
    "prompt": "A military-accurate side-profile silhouette of a T-72 main battle tank, solid dark "
              "gunmetal-to-steel gradient fill, a thin warm-orange #D9763C rim-light along the top "
              "edge, transparent background, backlit-at-dusk, sharp detailed outline (gun barrel, "
              "turret, road wheels, tracks), no interior detail. " + STYLE},
 "silhouette_jet": {
    "file": "silhouette_jet.png", "size": (1280, 560), "transparent": True,
    "role": "Drifting background layer / scene accent (fast jet).",
    "prompt": "A military-accurate side-profile silhouette of a Cold-War ground-attack jet (Su-25 "
              "style), solid dark gunmetal-to-steel gradient fill, a thin warm-orange #D9763C "
              "rim-light along the top edge, transparent background, backlit-at-dusk, sharp detailed "
              "outline (wings, pylons, tail), no interior detail. " + STYLE},
 "outro_bg": {
    "file": "outro_bg.png", "size": (1080, 1920), "transparent": False,
    "role": "Closing call-to-action card background (join / play).",
    "prompt": "A tall vertical closing card background for a community CTA: dark gunmetal #14171B "
              "with a faint topographic grid and a low dusk haze, a drifting Hind and tank silhouette "
              "bleeding off the bottom corners, a single warm orange #D9763C glow, film grain, heavy "
              "vignette, large empty calm center for a logo and a short call-to-action. 9:16 "
              "1080x1920. No text. " + STYLE},
 # --- stat icons (brief §9 'emoji/small icon' recipe). 128x128 transparent, readable small. ---
 # Dual-use: these double as the Discord custom-emoji set on ASSET-WISHLIST.md.
 "icon_longest": {"file":"icon_longest.png","size":(128,128),"transparent":True,
    "role":"Combat card: longest kill (crosshair).",
    "prompt":"A simple bold emoji-scale icon of a sniper crosshair / reticle, readable at 32px, "
             "flat-ish with a subtle orange #D9763C edge light, transparent background, olive and "
             "gunmetal, thick clean shapes, no text. " + STYLE},
 "icon_weapon": {"file":"icon_weapon.png","size":(128,128),"transparent":True,
    "role":"Combat card: top weapon (rifle).",
    "prompt":"A simple bold emoji-scale icon of a side-profile assault rifle, readable at 32px, "
             "flat-ish with a subtle orange #D9763C edge light, transparent background, olive and "
             "gunmetal, thick clean shapes, no text. " + STYLE},
 "icon_pvp": {"file":"icon_pvp.png","size":(128,128),"transparent":True,
    "role":"Combat card: PvP kills (crossed blades / duel).",
    "prompt":"A simple bold emoji-scale icon of two crossed combat knives, readable at 32px, "
             "flat-ish with a subtle orange #D9763C edge light, transparent background, olive and "
             "gunmetal, thick clean shapes, no text. " + STYLE},
 "icon_captures": {"file":"icon_captures.png","size":(128,128),"transparent":True,
    "role":"Combat card: town captures (flag).",
    "prompt":"A simple bold emoji-scale icon of a planted capture flag, readable at 32px, flat-ish "
             "with a subtle orange #D9763C edge light, transparent background, olive and gunmetal, "
             "thick clean shapes, no text. " + STYLE},
 "icon_mvp": {"file":"icon_mvp.png","size":(128,128),"transparent":True,
    "role":"Leaderboard #1 / MVP (medal).",
    "prompt":"A simple bold emoji-scale icon of a military medal / star award, readable at 32px, "
             "flat-ish with a subtle orange #D9763C edge light, transparent background, olive, "
             "gunmetal and bone, thick clean shapes, no text. " + STYLE},
}

# silhouettes available as drifting background layers (renderer picks per scene if present)
SILHOUETTES = ["silhouette_hind", "silhouette_tank", "silhouette_jet"]

def emblem_id(side): return {"west": "emblem_blufor", "east": "emblem_opfor", "guer": "emblem_guer"}.get(side)
def winner_bg_id(side): return {"west": "winner_bg_blufor", "east": "winner_bg_opfor", "guer": "winner_bg_guer"}.get(side)
