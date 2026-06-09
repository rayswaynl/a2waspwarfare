# Design — ASR AI server-FPS tuning (June modpack) + waspwarfare-next roadmap entry

**Date:** 2026-06-09
**Status:** Design approved (awaiting spec review)
**Author:** Claude (with Steff)

## Problem

The WASP Warfare player modpack (`-mod=@CBA_CO;@JSRS1.5;@adwasp;@admkswf;@Blastcore_Visuals_R1.2`)
includes ASR AI 1.16.0.40 (bundled inside `@adwasp`). ASR AI is the only mod in the pack with a
meaningful *server/sim* FPS cost — its `asr_ai_sys_aiskill` FSMs (`danger.fsm`, `move.fsm`) and
functions run per-unit/per-group on whichever machine the AI is local to. In a Warfare CTI match
that is the **dedicated server + headless client**, so ASR AI directly governs server FPS, and
server FPS degradation desyncs/rubber-bands every player regardless of their GPU.

Everything else in the pack is either config-only with zero runtime cost (`wasp_wep`, `wasp_akm`,
`wasp_veh_fix`, `glt_opa_backpacks4all`, TGW zeroing, `@admkswf` Sidewinder fix) or a pure
client-render cost (`@JSRS1.5` audio, `@Blastcore` particles). They are out of scope here.

ASR AI reads **all** of its settings from a plaintext include:
`<Arma 2 OA>\userconfig\ASR_AI\asr_ai_settings.hpp`. The shipped `asr_ai_settings.pbo` is a
307-byte shell that only `#include`s that file and carries no embedded defaults. **Therefore
tuning ASR AI requires editing one text file — no PBO repack, no signature break.**

Current state of the live file: it is already lightly customised — `sys_airearming.feature = 0`
(rearming scan loop disabled) vs the stock `.bak`. All other values match stock.

Secondary problem: the tuned `asr_ai_settings.hpp` is **not version-controlled anywhere** — it
exists only as a loose file in the Steam install. This design also fixes that.

## Scope decisions (locked with user)

- **Target budget:** Server/sim FPS only (ASR AI). Client-render mods (Blastcore/JSRS) are not touched.
- **Tuning profile:** **A — Conservative.** Behavior-near-identical; smallest but safest gain.
- **Validation:** Reasoned settings + docs only. **No in-engine benchmark.** Validation is
  config-syntax sanity plus the owner's own playtests.

## Component 1 — The tuning change (Profile A)

Edit exactly two values in `asr_ai_settings.hpp` and add a dated provenance comment. The ASR AI
config-structure version (`version = 6`) is unrelated to our values and stays as-is.

```diff
- radiorange = 500;              // Maximum range for radios
+ radiorange = 300;              // [WASP perf 2026-06-09] 500->300: shrink radio-net fan-out (group-count-scaling cost)

- buildingSearching = 0.7;       // Chance the AI group will search nearby buildings when in combat mode
+ buildingSearching = 0.5;       // [WASP perf 2026-06-09] 0.7->0.5: reduce CQB building-search pathfinding
```

`sys_airearming.feature` stays `0`. The change is trivially revertible via the existing
`asr_ai_settings.hpp.bak`.

### Rationale (knob-by-knob)

- **`radiorange` 500 → 300** — `radionet` shares known enemy positions between AI groups; cost
  scales with the number of groups in range of each broadcaster. Dropping the range from 500 m to
  300 m cuts the per-broadcast fan-out (fewer groups per radio net) while keeping *local* squad
  coordination intact. Largest-scaling cost, smallest behavior impact.
- **`buildingSearching` 0.7 → 0.5** — chance an in-combat group runs CQB building-clearing
  (`fnc_searchHouse`/`searchNearby`), which is expensive position pathfinding. 0.5 still keeps
  town-clearing behaviour (core to CTI) while doing it less often.

### What must NOT be touched (the keep-list)

These either *help* FPS or are init-only; changing them would be net-neutral or net-negative:

- `serverdvd = 1` — dynamic dedicated-server view-distance **cap**; disabling raises server load.
- `join_loners = 1` — merges lone units into groups → fewer groups → *less* radionet/FSM overhead.
- `setskills = 1` — one-shot at unit spawn, zero ongoing cost.
- `sys_airearming.feature = 0` — already disabled; keep off.
- The `sets` (skill levels) and `factions` (coefficients) blocks — applied once at spawn; they
  change *difficulty*, not ongoing FPS. Out of scope.
- Debug flags (`radionet_debug`, `setskills_debug`, `gunshothearing_debug`) — all `0`; keep `0`
  (enabling them spams RPT = I/O cost).

## Component 2 — Version-control the file

Add a tracked canonical copy at:

```
a2waspwarfare/server-config/userconfig/ASR_AI/asr_ai_settings.hpp
```

This sits alongside the existing `BattlEyeFilter/` server config. Apply the same two-value edit to
the loose Steam-install copy so local playtests use the tuned file. From this point the tuned
config has a version-controlled home and a clear diff history.

(Branch is `master`. Files will be written but **not committed** until the owner asks — per global
rule "commit only when asked.")

## Component 3 — Deployment note (documented, not executed)

**The win lands only on the dedicated server + headless client**, because that is where CTI AI is
local. Shipping the file only in the player modpack zip changes almost nothing for server FPS; a
player's userconfig affects only AI in their own group.

The production Arma 2 server host is not known to this design. The deploy doc will be written
generically (copy the tuned `userconfig\ASR_AI\asr_ai_settings.hpp` to the server install and the
HC install, restart). **Open item:** owner to confirm the production host if a concrete deploy
procedure is wanted.

## Component 4 — Docs update (`miksuus-warfare` guides)

Add a short "ASR AI tuning" subsection to `web/content/guides/performance.mdx` and a pointer from
`web/content/guides/mods-and-modpack.mdx`, covering:

- The `userconfig\ASR_AI\asr_ai_settings.hpp` file exists and is tunable.
- What was changed (radiorange, buildingSearching) and why; rearming already off.
- The server-not-client deployment point (the headline).

## Component 5 — waspwarfare-next roadmap entry

Add one item to `a2waspwarfare-next/docs/codex-work-order.md` (the live themed backlog). It is
framed as **compatibility/integration**, not a mod dependency, to respect the rebuild's stated
policy ("Arma 2 OA 1.64 semantics only", "replicate before adding content", "keep architecture
moddable"). Proposed as a new Theme G so it doesn't crowd the deployment theme.

### Draft entry (for review)

```markdown
## Theme G — Modpack compatibility & integration

### G1. Officially support + integrate the current player modpack (MEDIUM)
**What:** Make the rebuild a first-class citizen of the live player modpack
(`@CBA_CO;@JSRS1.5;@adwasp;@admkswf;@Blastcore_Visuals_R1.2`) without taking a hard mod
dependency. Three sub-parts: (a) a compatibility matrix stating which mods are drop-in
(CBA/JSRS/Blastcore/admkswf) vs. content the legacy experience relied on (the `@adwasp`
WASP weapon/vehicle configs); (b) decide whether to absorb the zero-cost WASP content
vanilla-side (script/config) or keep it as an optional companion addon, so a vanilla server
still runs but a modded server gets the full experience; (c) ship sane ASR AI performance
defaults from the mission itself via a `description.ext` `class asr_ai` (or init.sqf globals),
so any server running ASR AI inherits the tuned values (see legacy server-FPS tuning,
a2waspwarfare/docs/superpowers/specs/2026-06-09-asr-ai-server-fps-tuning-design.md) without
relying on each operator's userconfig.
**Why:** The rebuild must still run vanilla (charter), but the community actually plays with the
modpack. ASR AI is the one mod with real server-FPS cost, and its settings can be driven from the
mission (the userconfig header documents that `asr_ai_*` globals can be set in init.sqf /
description.ext). Driving perf defaults mission-side makes the rebuild robust regardless of a
given server's userconfig. The WASP weapon content is config-only (zero runtime cost) so it is
safe to support.
**Approach:** Keep the mission vanilla-runnable (no addOns[] mod entries). Add an optional
`class asr_ai` block to description.ext guarded so it is a no-op without ASR AI loaded. Document
the modpack compatibility matrix in docs. Defer any actual content-absorption (WASP weapons) to a
follow-up — this item only establishes support + perf defaults + the matrix.
**Acceptance + validation:** Mission still loads and plays on vanilla Arma 2 OA 1.64 (no new hard
deps). With the modpack loaded, ASR AI reads the mission-provided perf defaults (verify a tuned
value resolves from the mission, e.g. via diag readout of the global). Compatibility matrix doc
committed. Validator: no new entries in mission.sqm addOns[].
**Status (2026-06-09):** PROPOSED — backlog only; not started.
```

## Out of scope

- Client-render FPS (Blastcore/JSRS) — separate budget, explicitly excluded by scope choice.
- ASR AI difficulty changes (skill levels / faction coefficients).
- Actually deploying to the production server (host unknown).
- Absorbing WASP weapon content into the rebuild (deferred inside G1).

## Validation summary

- ASR AI `version = 6` structure unchanged → file remains valid for ASR AI 1.16.0.40.
- Only two scalar values changed; both within documented valid ranges (`radiorange` metres,
  `buildingSearching` 0–1).
- No in-engine benchmark (per scope). Owner validates via normal playtests.
- Revert path: `asr_ai_settings.hpp.bak`.

## Post-deploy correction (2026-06-09)

Reality differed from two assumptions in this design; corrected after deploy:

1. **Install location.** The running game/server is **`F:\SteamLibrary\steamapps\common\Arma 2 Operation
   Arrowhead\`** (the machine has 3 Steam libraries: C:, D:, F:). The `C:\Program Files (x86)\Steam\…\Arma 2
   OA` folder used during authoring is a **stray** (mods + userconfig, no `.exe`) and is NOT what the game
   reads. The tune was deployed to **F:** (with `asr_ai_settings.hpp.bak` as the stock revert) and the stray
   C: edit was reverted. Server, HC, and client all launch from F: (`start_wasp_server.cmd`,
   `Launch_Miksuu_Warfare_BE.cmd`), so one deploy covers all roles — no SSH/remote step.
2. **Rearming.** The real F: install is true stock with `sys_airearming.feature = 1` (rearming ON). The `= 0`
   referenced earlier in this doc existed only on the stray C: folder. Per Steff's decision, rearming is
   **left ON**; the canonical `asr_ai_settings.hpp` and README were updated to `feature = 1` to match. Only the
   two reviewed knobs (`radiorange 300`, `buildingSearching 0.5`) constitute the tune.

Separately (not caused by this change — no PBOs were touched): `CA_CruiseMissile.pbo` is missing from the F:
install, producing a non-fatal `JSRS_2A14` "requires addon CA_CruiseMissile" startup popup. Fix via Steam →
Verify Integrity on Arma 2 and Arma 2 OA.
