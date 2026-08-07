# WASP Post-Match Report

Two reports come out of this directory, from the same telemetry:

| | **Video report** (`render_report.py`) | **In-depth report** (`deep_report.py`) |
|---|---|---|
| Output | 1080×1920 MP4, ~48 s | one self-contained HTML file (or Markdown) |
| Audience | TikTok / Shorts / Discord | anyone asking what actually happened |
| Reads | `WASPSTAT\|v1\|` | `WASPSTAT\|v1\|` **and** `MATCH\|v1\|` |
| Needs | numpy + Pillow + ffmpeg | **stdlib only** — runs on the server box |

Jump to [the in-depth report](#in-depth-report) for the second one.

---

## Video report

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

Each match render also writes `out.mp4.replay.json` unless `--no-replay-json` is
passed. That sidecar is built from finalized `MatchData` and contains replay-ready
kill timeline bins, SCUD/TEL support markers, per-side town-control area, and
capture-streak callouts. It never reads raw PLAYERSTATS directly, so HC / AI
controller names cannot leak into these stat surfaces.

## Data flow

```
Hetzner server RPT  ──WASPSTAT|v1|…──►  box.ps1 / poster.ps1  ──►  :3010 ingest (production host)
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

Replay sidecar fields:

- `killTimeline`: fixed-width kill bins by WEST/EAST/GUER/other for a timeline strip.
- `supportMarkers`: SCUD/TEL markers with absolute time and replay percentage.
- `townControlArea`: exact town-seconds and share per side.
- `captureStreaks`: consecutive same-side capture runs, suitable for callout cards.

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

## Known gaps -> production wiring

See `PRODUCTION.md` for the source-anchored gap trace. Current Build84 already emits
`t=<seconds>` on `CAPTURE` and `KILL`, and `matchdata.py` has full static town sets for
Chernarus, Takistan, and Zargabad. The remaining small gaps are: document the optional
`t=` fields in `docs/WASPSTAT-FORMAT.md`, wire a reliable UID-to-name TSV or confirm
embedded `~name` coverage, and decide whether the scheduled runner is sufficient or if
the `:3010` ingest should trigger it directly. Future terrains still need boot-harvested
coordinates before their control maps are trusted.

## Customisation knobs

Colours / fonts / scene timings live at the top of `render.py`; scene order and lengths
are the `scene(...)` calls at the bottom of `render()`. Re-renders in ~30 s.

---

## In-depth report

`deep_report.py` is the read-through companion to the video: same telemetry, opposite
goal. The video shows eight numbers to a scrolling audience; this shows **every number
the log carries**, to someone asking what actually happened in the round.

```bash
python deep_report.py --sample -o report.html        # deterministic demo, no data needed
python deep_report.py --rpt arma2oaserver.RPT -o report.html
grep -E "WASPSTAT\|v1\||MATCH\|v1\|" server.rpt | python deep_report.py --rpt - -o report.html
python deep_report.py --rpt match.log --format md    # Markdown/plain text to stdout
python deep_report.py --rpt match.log --names players.tsv -o report.html
```

**Stdlib only** — no numpy, no Pillow, no ffmpeg, no CDN, no build step. That is
deliberate: it runs on the box that already has the RPT, and the output is one
self-contained HTML file you can drop in Discord or open offline.

### What it adds over the video path

It reads the **`MATCH|v1|` family**, which `matchdata.parse_waspstat` ignores entirely —
so match configuration (`START`: build, town/slot counts, AI-commander and delegation
settings, GUER/naval/oilfield flags), the authoritative result (`END`: casualties,
vehicles lost, towns held, connected players) and the narrative beats (`MILESTONE`:
first town per side, HQ destroyed, oilfield and carrier flips) reach a report for the
first time. See `matchfacts.py`.

### Sections

**Result** (hero + how the win landed) · **Faction ledger** (every faction, including
zeroes) · **Momentum** (towns held over time) · **Territory** (share of contested
territory, per-town flip history, capture streaks) · **Combat** (kill tempo, target
class, engagement range, top weapons, longest kill) · **Operators** (MVP, superlatives,
the full 15-field PLAYERSTATS table) · **Head-to-head** (PvP duels) · **Match timeline**
(all three telemetry families merged chronologically) · **Telemetry coverage**.

### Two rules the report is built on

**Never invent a number.** Anything the log did not carry is reported as absent, not
estimated. Event times the emitter did not measure are marked `~` in the timeline and
counted in Telemetry coverage, so an interpolated capture is never presented as a
measured one. The coverage section exists so a thin report is never mistaken for a thin
match — it reports record counts, sequence gaps, timestamp and distance coverage,
unresolved UIDs and the count of excluded headless/AI rows.

**Headless clients and AI controllers are not operators.** They carry UIDs and stat rows
but are removed before any MVP, leaderboard or duel table is built (shared
`matchdata.is_excluded_name`), and surface only as a count in coverage.

### Charts

Inline SVG, no library. The faction hues are stepped from the brand tokens until the
categorical palette passes a colour-vision-deficiency and contrast audit on both
surfaces (the raw tokens do not — `guer↔east` collapse to ΔE 5.2 under deuteranopia);
the exact validated values and their surfaces are recorded in `PALETTE` at the top of
`deep_report.py`. CIV / CONTESTED stays neutral grey chrome rather than becoming a
fourth faction hue. Every chart ships a table-view twin, so no value is reachable by
colour or hover alone, and the page renders in both light and dark mode.

### Tests

```bash
python -m unittest -v test_deep_report.py
```

25 stdlib-only tests covering the `MATCH|v1|` parser (including absent families and
unknown milestone subtypes), territory-seconds and flip history, HC/AI exclusion,
distance and timestamp honesty, coverage warnings, DOM-id uniqueness, CSS-variable
definition, HTML escaping of operator names, and the no-external-requests guarantee.

---

## Layout and BrandKit verification

`BRANDKIT-ASSET-AUDIT.md` records the approved vehicle-blackout fallback assets,
their source-of-truth hashes, and the deliberate exclusion of mirror-only draft
art. The renderer uses these committed BrandKit files only when optional generated
silhouette assets are absent.

Run the focused verification from this directory:

```bash
python -m unittest -v test_matchdata.py test_render.py
```

The tests assert the complete Zargabad town set (including the airfield) receives
non-overlapping map labels, the report treatment always includes BLUFOR, OPFOR,
GUER, and CIV / CONTESTED, and each approved vehicle fallback loads successfully.
