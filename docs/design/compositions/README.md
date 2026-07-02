# Base composition drafts — formats & how to review them

**PRIMARY FORMAT: the SQF blocks** in `PROPOSED_Init_Defenses_blocks.sqf`. They are
paste-ready drop-in replacements for the matching `WFBE_NEURODEF_*` variables in
`Server\Init\Init_Defenses.sqf` — the exact element format (`['class',[x,y,z],dir]`)
consumed by `CreateDefenseTemplate` and `WFBE_SE_FNC_SpawnStructureDressing`.

Tier ladder (Ray spec 2026-07-02 — wall material only, nothing else):

| Tier | Buildings | Wall class | File |
|---|---|---|---|
| LOW | Barracks, Light Factory | `Land_fort_bagfence_long` | `barracks_low` (6 objs), `light_factory_low` (10) |
| MEDIUM | Heavy Factory, (Service opt.), Bank | `Base_WarfareBBarrier10x` / `Land_HBarrier_large` | `heavy_factory_medium` (3), `bank_medium` (7) |
| HIGH | Command Center, Aircraft Factory | `Concrete_Wall_EP1` — the HQ's exact wall class | `command_center_high` (11), `aircraft_factory_high` (16) |

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
1. Open the matching block in `PROPOSED_Init_Defenses_blocks.sqf` and copy ONLY the
   entries inside the outer `[ ... ]` (the `['class',[x,y,z],dir],` lines).
2. In WDDM expand **Import an existing template**, paste, click **Load into editor**.
3. Pick the building under **Structure footprint** manually (import doesn't set it):
   Barracks / Light Factory / Heavy Factory / Aircraft Factory / Command Center /
   Reserve (use Reserve for the Bank draft).

Toggle **Preview** for the in-game-style render; **PNG ⬇** for a Discord snapshot.

## Coordinate model

`+Y` = building **front**, `+X` = building **right**, `dir` in degrees, Z flattened to
ground at spawn — identical math in WDDM and the mission (`modelToWorld`). Vehicle
factories (Light/Heavy/Aircraft) keep the **+X face fully open** — that's the spawn-pad
/ fallback-egress side. No composition is a closed ring; every one has foot gaps.

See `../BASE-COMPOSITIONS-PROPOSAL.md` for rationale, sketches, and evidence tags.
