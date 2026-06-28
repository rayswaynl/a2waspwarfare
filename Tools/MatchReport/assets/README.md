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
| `winner_bg_guer.png`   | 1080×1920 | victory background, GUERRILLA |
| `mvp_backdrop.png`     | 1080×1920 | MVP spotlight/soldier overlay (transparent) |
| `outro_bg.png`         | 1080×1920 | closing CTA background |
| `silhouette_hind.png`  | 1280×560  | Mi-24 Hind blackout (transparent) |
| `silhouette_tank.png`  | 1280×560  | T-72 blackout (transparent) |
| `silhouette_jet.png`   | 1280×560  | Su-25-style jet blackout (transparent) |
| `silhouette_apc.png`   | 1280×560  | BMP-style APC/IFV blackout (transparent) |
| `silhouette_artillery.png` | 1280×560 | BM-21/rocket-artillery blackout (transparent) |
| `silhouette_supply_truck.png` | 1280×560 | Ural/Kamaz supply truck blackout (transparent) |
| `bg_momentum.png`      | 1080×1920 | optional momentum/chart scene background |
| `overlay_contours.png` | 1080×1920 | reusable contour/MGRS overlay (transparent) |
| `overlay_stat_panel.png` | 1080×1920 | reusable stat-panel rails overlay (transparent) |
| `icon_longest.png`     | 128×128   | combat-card longest-kill icon (transparent) |
| `icon_weapon.png`      | 128×128   | combat-card top-weapon icon (transparent) |
| `icon_pvp.png`         | 128×128   | combat-card PvP icon (transparent) |
| `icon_captures.png`    | 128×128   | combat-card captures icon (transparent) |
| `icon_towns.png`       | 256×256   | towns/capture stat icon (transparent) |
| `icon_kills.png`       | 256×256   | kills/combat stat icon (transparent) |
| `icon_mvp.png`         | 256×256   | MVP/top-operator stat icon (transparent) |
| `icon_economy.png`     | 256×256   | economy/supply stat icon (transparent) |
| `icon_factory.png`     | 256×256   | factories/production stat icon (transparent) |
| `icon_duration.png`    | 256×256   | match-duration stat icon (transparent) |

PNG outputs are gitignored (binaries) — keep the source prompts in `assets.py`.
