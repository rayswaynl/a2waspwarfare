# Generated assets drop folder

Drop ChatGPT (image-gen-2) outputs here using the **exact filenames** from
`python gen_prompts.py`. The renderer auto-detects whatever is present and
composites it; anything missing falls back to the procedural look, so the report
always renders.

Slots (see `../assets.py` for the registry + prompts):

| file | size | what |
|---|---|---|
| `intro_splash.png`     | 1080×1920 | opening title-card background |
| `frame_overlay.png`    | 1080×1920 | transparent HUD bezel (every frame) |
| `grain.png`            | 1080×1920 | transparent film-grain (every frame) |
| `emblem_blufor.png`    | 512×512   | BLUFOR crest (transparent) |
| `emblem_opfor.png`     | 512×512   | OPFOR crest (transparent) |
| `emblem_guer.png`      | 512×512   | GUERRILLA crest (transparent) |
| `winner_bg_blufor.png` | 1080×1920 | victory background, BLUFOR |
| `winner_bg_opfor.png`  | 1080×1920 | victory background, OPFOR |

PNG outputs are gitignored (binaries) — keep the source prompts in `assets.py`.
