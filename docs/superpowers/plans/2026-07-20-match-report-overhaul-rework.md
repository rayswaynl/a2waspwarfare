# Match-report overhaul rework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Execute inline with test-first checkpoints. This card has one active Fleet owner; do not create a parallel writer.

**Goal:** Complete the rejected PR #1195 rework with an all-faction vertical report treatment, collision-safe Zargabad labels, approved BrandKit vehicle fallbacks, and durable audit evidence.

**Architecture:** Keep `Tools/MatchReport/render.py` as the renderer boundary. Add small pure helpers for faction-ledger data and town-label placement so the visual changes have deterministic unit coverage. Copy only approved existing BrandKit vehicle blackouts into the report's `brand/veh/` mirror and document their provenance in a committed audit.

**Tech Stack:** Python 3, Pillow, `unittest`, imageio/ffmpeg, existing Fleet BrandKit PNG assets.

## Global Constraints

- Update draft PR #1195 only; never deploy, post to Discord, or post to TikTok.
- Use `W:\Mijn vualt\Fleet\BrandKit` as source of truth; never hand-draw vehicle or brand art.
- Use palette values already mirrored from `tokens.css`; faction colours are faction data only.
- Keep CIV as a neutral status label, not faction-coloured chrome.
- Preserve the existing 1080x1920 report pipeline and no-GPU rendering path.
- Make all renderer behavior changes test-first and run the focused suite before rendering evidence.

---

### Task 1: Deterministic faction and label layout helpers

**Files:**

- Create: `Tools/MatchReport/test_render.py`
- Modify: `Tools/MatchReport/render.py`

**Interfaces:**

- Produces `faction_ledger(owners) -> list[tuple[str, str, int]]`, always ordered BLUFOR, OPFOR, GUER, CIV / CONTESTED.
- Produces `layout_town_labels(draw, towns, world_size, x0, y0, size, font) -> dict[str, tuple[float, float]]`, returning one in-bounds non-overlapping label position for every town.

- [x] **Step 1: Write failing tests** for four faction rows and all eleven Zargabad labels, including non-overlap checks.
- [x] **Step 2: Run** `python -m unittest -v test_render.py` and confirm it fails because the helpers do not exist.
- [x] **Step 3: Implement** the two narrow helpers and replace the map's skip-on-collision branch with the label layout result.
- [x] **Step 4: Apply the faction ledger** to the battle, momentum, and winner views so GUER and CIV remain legible even at zero captures.
- [x] **Step 5: Re-run** `python -m unittest -v test_matchdata.py test_render.py` and confirm all tests pass.

### Task 2: Approved vehicle fallbacks and audit

**Files:**

- Create: `Tools/MatchReport/brand/veh/veh-hind.png`
- Create: `Tools/MatchReport/brand/veh/veh-t90.png`
- Create: `Tools/MatchReport/brand/veh/veh-a10.png`
- Create: `Tools/MatchReport/brand/veh/veh-bmp3.png`
- Create: `Tools/MatchReport/brand/veh/veh-grad.png`
- Create: `Tools/MatchReport/brand/veh/veh-technical.png`
- Create: `Tools/MatchReport/BRANDKIT-ASSET-AUDIT.md`
- Modify: `Tools/MatchReport/render.py`
- Modify: `Tools/MatchReport/test_render.py`

**Interfaces:**

- Produces `brand_vehicle(name) -> PIL.Image.Image | None` for approved report fallback art.
- `drift_silhouette` uses a committed BrandKit vehicle fallback only when optional generated silhouettes are absent.

- [x] **Step 1: Extend the failing renderer test** to expect the approved Hind fallback to load.
- [x] **Step 2: Run** `python -m unittest -v test_render.py` and confirm the missing helper fails.
- [x] **Step 3: Copy exactly the six listed BrandKit `veh-*.png` files** with source SHA-256 values recorded in the audit; do not generate or redraw any asset.
- [x] **Step 4: Implement** the fallback loader and vehicle-to-scene mapping.
- [x] **Step 5: Record** which vehicle slots are covered and whether any required slot is missing; post the same finding to `brandkit-vehicle-blackouts-missing-20260720` through Fleet tooling.
- [x] **Step 6: Re-run** the focused suite and inspect the tracked diff to confirm only the approved assets and renderer/audit files changed.

### Task 3: Render proof, draft PR update, and review handoff

**Files:**

- Modify: `Tools/MatchReport/README.md`
- Modify: task `wasp-match-report-overhaul-20260720` through `Fleet.ps1` only

- [x] **Step 1: Render** the sample report and a Zargabad smoke frame locally; verify vertical dimensions, all labels, four faction treatment, and no missing fallback asset errors.
- [x] **Step 2: Add durable README links** to the audit, behavior tests, and evidence command.
- [x] **Step 3: Copy evidence to Fleet Drop** with hashes; do not publish it.
- [ ] **Step 4: Commit and push a normal fast-forward** from the isolated rework branch to the existing PR #1195 head branch after rechecking the remote head.
- [ ] **Step 5: Submit a fresh Fleet review** citing the PR URL, committed audit path, tests, and absolute Drop path.
