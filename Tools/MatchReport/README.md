# WASP Post-Match Report

Generates a vertical (1080×1920) **post-match report video** for TikTok / Shorts /
Discord — entirely from the telemetry the mission already emits. **No game capture,
no GPU, no OBS, no Arma client.** It's a batch job: feed it a finished match's
WASPSTAT lines, get an MP4.

![scenes](docs-not-committed) <!-- run --sample to see it; binaries are gitignored -->

## Why this approach

The WASP game server runs **headless on Hetzner** — a dedicated Arma 2 OA server
renders no 3D view, so there is nothing to screen-capture there. Rather than stand up
a fragile "caster client + OBS" rig on a GPU box (always-on, auto-reconnect across the
4 h map rotation, breaks on a locked session), this **reconstructs the match as an
animated report from data**. It runs anywhere Python runs, is deterministic, and
slots straight onto the existing telemetry pipeline.

> This is the TikTok artifact. It's **separate from** the in-game winner-cam
> (`Client/Client_EndGame.sqf`, PR #114), which is for players watching the round end live.

## Scenes

intro → **battle** (animated territory-control map) → **momentum** (towns-held line
chart) → **MVP** → **top operators** leaderboard → **combat breakdown** (kill-category
donut, longest kill, top weapon, PvP, captures) → **decisive blow** → **winner card**
with SCUD/TEL support-event counts when the RPT includes those markers. ~48 s by
default.

## Install

```
pip install -r requirements.txt
```
`imageio-ffmpeg` bundles its own ffmpeg, so nothing else is needed.

## Run

```bash
# built-in demo match (no data needed) — good for previewing the look
python render_report.py --sample

# from real telemetry: raw WASPSTAT lines (file or stdin)
python render_report.py --waspstat match.log -o out.mp4
grep WASPSTAT server.rpt | python render_report.py --waspstat -

# label players with real names (UID<TAB>name); without it, names fall back to Op-XXXX
python render_report.py --waspstat match.log --names players.tsv
```

## Data flow

```
Hetzner server RPT  ──WASPSTAT|v1|…──►  box.ps1 / poster.ps1  ──►  :3010 ingest (gaming PC)
                                                                        │
                                              ROUNDEND detected ────────┘
                                                                        ▼
                                          render_report.py  ──►  wasp_report_<map>.mp4
                                                                        ▼
                                                          drop in folder / Discord → post
```

## Architecture

- **`matchdata.py`** — `MatchData`, the single input boundary the renderer reads from;
  the **WASPSTAT parser** (`parse_waspstat`); static town coordinates; side-ID mapping.
- **`sample_match.py`** — `build_sample()`, a realistic placeholder match in the same
  shape the parser produces (so the renderer can't tell sample from live).
- **`render.py`** — `render(MatchData, out)`; all scene drawing (Pillow → frames → mp4).
- **`render_report.py`** — CLI.
- **`assets.py` / `gen_prompts.py` / `assets/`** — optional generated art (below).
- **`brand/`** — Miksuu's Warfare branding: the palette + Oswald/Inter/JetBrains-Mono
  fonts and the logo mark/lockup drive the report's look (tokens mirror
  `miksuus-warfare/brand/tokens.css`). Fonts fall back to Arial if absent.

Telemetry contract: see `docs/WASPSTAT-FORMAT.md` in the repo (PLAYERSTATS `d0..d14`,
`KILL`, `CAPTURE`, `ROUNDEND`).

SCUD/TEL support markers are parsed opportunistically from the same raw RPT stream,
even when they are not `WASPSTAT` records. Lines containing `SCUD`, `ICBMTEL`, or a
standalone `TEL` token are summarized as support events; `t=<seconds>` is used when
present, otherwise the parser spreads them across the match like untimed kills/captures.

## Generated art (optional — "prompt pack + drop folder")

The report renders fully procedurally out of the box. To dress it up with generated
art (intro splash, faction crests, HUD frame, grain, victory backgrounds):

```
python gen_prompts.py            # prints a ChatGPT prompt for each asset slot
```

Each block is stamped with an exact **`SAVE AS`** filename. Generate the image
(image-gen-2 / ChatGPT), **save it under `assets/` using that exact name**, and
re-render — the renderer auto-detects whatever is present and composites it; missing
slots fall back to the procedural look. The filename is the tracking key, so naming
must match `assets.py` exactly. `assets.py` is the registry (slots, sizes, prompts);
the drop-folder PNGs are gitignored (binaries). The map is **not** an asset slot — an
accurate procedural map beats a hallucinated generated one.

## Known gaps → production wiring (all small, mostly mission-side)

1. **Event timestamps.** `CAPTURE`/`KILL` lines carry **no match-time** today, so the
   parser spreads events evenly across `[0, duration]` by sequence order — fine for the
   look, not frame-accurate. Two clean fixes (pick one):
   - add `round(time)` as a field to the `CAPTURE`/`KILL` emitters
     (`Server/FSM/server_town.sqf`, `Server/PVFunctions/RequestOnUnitKilled.sqf`) and bump
     the WASPSTAT format doc, **or**
   - have the ingest stamp each line's arrival time and pass it via `parse_waspstat(line_times=…)`.
2. **Town coordinates.** `TOWN_COORDS["chernarus"]` is hand-approximated and
   `["takistan"]` is empty (unknown towns auto-place on a ring). Real fix: log each
   town's `getPos` once at boot (one line in mission init) and paste the values in —
   that makes both maps exact.
3. **Player names.** WASPSTAT carries UID, not name. Pass `--names` (join from the
   leaderboard `players` table) for real handles; otherwise `Op-<last4>`.
4. **Trigger.** Wire a watcher on the `:3010` ingest: on a `ROUNDEND`, collect that
   match's lines and invoke `render_report.py`. (≈30 lines, mirrors the existing RPT
   reporters.) Output is already native-vertical; auto-posting to TikTok is deferred
   (post manually first).

## Customisation knobs

Colours / fonts / scene timings live at the top of `render.py`; scene order and lengths
are the `scene(...)` calls at the bottom of `render()`. Re-renders in ~30 s.
