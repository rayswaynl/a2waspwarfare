# WDDM composition designs — formats & how to review them

`*.wddm.json` files here are the **source of truth** for the `WFBE_NEURODEF_*`
composition arrays in `Server\Init\Init_Defenses.sqf`. Convert with
`python Tools/WddmToSqf/wddm_to_sqf.py` (`--check` to validate, `--name <VAR>` to emit
one block) — never hand-edit the generated SQF arrays.

## Current file families

| Family | Files | Status |
|---|---|---|
| AA / Artillery / Mixed positions | `aa_*`, `artillery_*`, `mixed_*` | LIVE (WFBE_C_DEFMENU_V2_POSITIONS, default 1) |
| Fortifications (cosmetic, side-neutral) | `fort_infantry_strongpoint`, `fort_roadblock_checkpoint`, `fort_observation_post` | LIVE (menu rows under WFBE_C_DEFMENU_V2_POSITIONS) |
| Fortifications (MANNED variants) | `fort_*_west` / `fort_*_east` | flag `WFBE_C_DEF_FORT_MANNED`, default 0 |
| Factory wall slabs v4 | `*_walls_v4` (barracks, light_factory, command_center, heavy_factory, aircraft_factory) | flag `WFBE_C_WALLS_V4`, default 0 (V3 slabs stay the live default; ServicePoint stays slab-free — deliberately no v4 file) |
| RETIRED v2 wall ladder | `_v2_reverted_*` | HISTORY ONLY — see below |

## Retired v2 wall-ladder drafts (`_v2_reverted_*`)

The cmdcon42-g wall-material ladder (bagfence/HESCO/concrete per tier) was **reverted
in Build 88** (cmdcon43-c; Ray: "revert the factory wall changes, and then just add
additional concrete slabs to them like the HQ has"). The six draft files are kept for
history under a `_v2_reverted_` prefix and are **not** wired to anything.

**Landmine defused:** these drafts used to claim LIVE variable names (e.g.
`aircraft_factory_high` claimed `WFBE_NEURODEF_AIRCRAFT_WALLS`), so a naive
`--emit-file` run would have overwritten live legacy arrays with reverted content.
Their `name` fields now carry a `_V2_REVERTED` suffix, making them inert to the
converter's output while still loadable in WDDM.

`PROPOSED_Init_Defenses_blocks.sqf` is the matching historical SQF draft set — also
reference only.

## Factory walls — which array is live?

- Flag `WFBE_C_WALLS_V3` (default **1**): legacy ring + v3 `Concrete_Wall_EP1` slabs
  (`WFBE_NEURODEF_*_WALLS_V3`, hand-authored concat arrays in `Init_Defenses.sqf`).
- Flag `WFBE_C_WALLS_V4` (default **0**): redesigned full arrays from the
  `*_walls_v4.wddm.json` files here — legacy ring verbatim + contiguous slab runs at
  the HQ 2.2 m overlap pitch, slab-layer gaps aligned with the legacy walking gaps,
  `Land_CncBlock_Stripes` accents at gap mouths, no lone single panels.
- Both flags 0: exact legacy `WFBE_NEURODEF_*_WALLS` arrays.

Selection lives in `Server\Construction\Construction_SmallSite.sqf` /
`Construction_MediumSite.sqf` (V4 preferred when its flag is on AND the `_V4` array
exists, else the V3 logic untouched).

## Reviewing in WDDM — two paths that actually work

> Earlier revision of this README said to *paste* the JSON into the editor — that was
> WRONG and is why the files "didn't load". WDDM has no paste field for project JSON;
> its loader is a **file picker** (`index.html` `$('loadJson')` handler: file input →
> `FileReader` → `JSON.parse` → `loadProject`). The JSON schema itself was verified
> field-for-field against `projectData()`/`loadProject()` and matches exactly.

**Path A — load the project file (recommended):**
1. Open <https://rayswaynl.github.io/WDDM/> (or the repo's `index.html`, offline).
2. Expand **Save / load project (JSON)** in the left Build panel.
3. Click the **Load .json** BUTTON — a file dialog opens.
4. Select the `*.wddm.json` file (they end in `.json`, so the picker accepts them).
   The parent building footprint, fort-only mode and all elements load as authored.

**Path B — manual rebuild via template import (fallback):**
1. Emit the block (`wddm_to_sqf.py --name WFBE_NEURODEF_...`) and copy ONLY the
   entries inside the outer `[ ... ]` (the `['class',[x,y,z],dir],` lines).
2. In WDDM expand **Import an existing template**, paste, click **Load into editor**.
3. Pick the building under **Structure footprint** manually (import doesn't set it).

Toggle **Preview** for the in-game-style render; **PNG ⬇** for a Discord snapshot.

## Coordinate model

`+Y` = building **front**, `+X` = building **right**, `dir` in degrees, Z flattened to
ground at spawn — identical math in WDDM and the mission (`modelToWorld`). Exception:
composition children with `z > 0.1` are lifted onto their host structure's deck by
`Server_ConstructPosition.sqf` (`setPosATL`, flak-tower idiom — used by the manned
Observation Post deck MG at the documented `Land_Fort_Watchtower_EP1` deck z = 5.4).
Vehicle factories (Light/Heavy/Aircraft) keep the **+X face fully open** — that's the
spawn-pad / fallback-egress side. No composition is a closed ring; every one has foot gaps.

See `../BASE-COMPOSITIONS-PROPOSAL.md` for rationale, sketches, and evidence tags.
