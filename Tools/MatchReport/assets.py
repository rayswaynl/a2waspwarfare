"""
Asset registry — the single source of truth for generated (diffusion) art used
by the report renderer.

Workflow ("prompt pack + drop folder"):
  1. `python gen_prompts.py`  prints a ChatGPT-ready prompt for each asset, each
     stamped with the EXACT filename to save as.
  2. Generate each image in ChatGPT (image-gen-2) and save it under `assets/`
     using that exact filename — nothing else. The filename IS the tracking key.
  3. Re-render: the renderer auto-detects whatever is present in `assets/` and
     composites it; anything missing falls back to the procedural look. So the
     report always renders, and improves as art is dropped in.

Naming convention: `<slot>[_<side>].png`, lower-case, no spaces. Sizes are exact —
generate at the listed pixel size (or larger, same aspect) so nothing is upscaled.
Transparency: emblems and overlays MUST be transparent PNGs (alpha).
"""

# Brand palette to keep generations consistent (hand these to the model):
PALETTE = {
    "bg":     "#0b0f15 near-black navy",
    "blufor": "#3e8eff (NATO blue)",
    "opfor":  "#ec4848 (red)",
    "guer":   "#60c870 (green)",
    "gold":   "#f0c45c (accent)",
}
STYLE = ("flat military-tactical UI aesthetic, dark navy background #0b0f15, crisp "
         "vector-clean shapes, subtle grain, high contrast, NO text, NO lettering, "
         "NO watermark, centered, vertical 9:16 unless noted")

ASSETS = {
 "intro_splash": {
    "file": "intro_splash.png", "size": (1080, 1920), "transparent": False,
    "role": "Full-bleed background for the opening title card.",
    "prompt": "Cinematic vertical key-art background for an Arma 2 'WASP WARFARE' "
              "military match-recap intro. Brooding dark navy #0b0f15 sky over a faint "
              "topographic contour map of a war-torn coastline, drifting smoke, distant "
              "muted blue and red front-line glows on left and right edges, heavy "
              "vignette, lots of empty dark space in the vertical center for a title to "
              "sit. " + STYLE + ". 9:16, 1080x1920."},
 "frame_overlay": {
    "file": "frame_overlay.png", "size": (1080, 1920), "transparent": True,
    "role": "Transparent HUD bezel composited over every frame.",
    "prompt": "Transparent PNG HUD frame overlay for a vertical tactical UI, 9:16 "
              "1080x1920. Thin corner brackets, faint tick marks along the edges, a "
              "few subtle reticle/registration marks, very light scanlines. Light steel "
              "grey #8a95a5 at low opacity. The entire CENTER must be fully transparent "
              "(empty) — decoration only on the outer ~8% border. " + STYLE},
 "grain": {
    "file": "grain.png", "size": (1080, 1920), "transparent": True,
    "role": "Low-opacity film-grain/noise overlay on every frame.",
    "prompt": "Transparent PNG fine film-grain / sensor-noise texture, neutral grey "
              "monochrome speckle, evenly distributed, subtle, 1080x1920. Just noise on "
              "transparency, no shapes, no gradient, no text."},
 "emblem_blufor": {
    "file": "emblem_blufor.png", "size": (512, 512), "transparent": True,
    "role": "BLUFOR faction crest (MVP/score/winner).",
    "prompt": "Transparent PNG faction crest emblem for 'BLUFOR', NATO-style. A clean "
              "heraldic shield with a stylized eagle/star motif, NATO blue #3e8eff with "
              "steel accents, flat vector insignia, centered, 512x512, no text. " + STYLE},
 "emblem_opfor": {
    "file": "emblem_opfor.png", "size": (512, 512), "transparent": True,
    "role": "OPFOR faction crest.",
    "prompt": "Transparent PNG faction crest emblem for 'OPFOR', Eastern-bloc style. A "
              "bold shield with a star and laurel motif, red #ec4848 with dark steel "
              "accents, flat vector insignia, centered, 512x512, no text. " + STYLE},
 "emblem_guer": {
    "file": "emblem_guer.png", "size": (512, 512), "transparent": True,
    "role": "Guerrilla faction crest.",
    "prompt": "Transparent PNG faction crest emblem for an irregular 'GUERRILLA' force. "
              "A rough shield with crossed rifles motif, green #60c870 with worn dark "
              "accents, flat vector insignia, centered, 512x512, no text. " + STYLE},
 "winner_bg_blufor": {
    "file": "winner_bg_blufor.png", "size": (1080, 1920), "transparent": False,
    "role": "Victory background when BLUFOR wins.",
    "prompt": "Vertical victory background, triumphant but dark and tactical. Deep navy "
              "#0b0f15 with a broad NATO-blue #3e8eff glow rising from the bottom, faint "
              "rays, subtle particle embers, heavy vignette, empty center for stats. "
              + STYLE + ". 9:16 1080x1920."},
 "winner_bg_opfor": {
    "file": "winner_bg_opfor.png", "size": (1080, 1920), "transparent": False,
    "role": "Victory background when OPFOR wins.",
    "prompt": "Vertical victory background, triumphant but dark and tactical. Deep navy "
              "#0b0f15 with a broad red #ec4848 glow rising from the bottom, faint rays, "
              "subtle particle embers, heavy vignette, empty center for stats. "
              + STYLE + ". 9:16 1080x1920."},
}

def emblem_id(side): return {"west": "emblem_blufor", "east": "emblem_opfor", "guer": "emblem_guer"}.get(side)
def winner_bg_id(side): return {"west": "winner_bg_blufor", "east": "winner_bg_opfor"}.get(side)
