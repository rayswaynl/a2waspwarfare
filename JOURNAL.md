# JOURNAL — a2waspwarfare-experital

## 2026-08-05 — naval-HVT fallback guard (fable/naval-hvt-fallback-guard-20260805)

Task: adversarial-review follow-up to wave0805 fold `5ee41de464` (naval-HVT exclusion in the
V2 allocator scorer). Review finding: the "no ground force sent at the Khe Sanh carrier"
invariant is held by redundancy, not construction — the never-idle/last-resort fallbacks
(`AI_Commander_Allocate.sqf:312-321`, `AI_Commander_Strategy.sqf:107-114`) publish naval-HVT
towns into `wfbe_aicom_targets` when nothing else is capturable, and
Paratroops/CargoAirdrop/Wildcard W4/W6/W22 blind-read `wfbe_aicom_targets` slot 0.

Decision — do NOT filter the fallbacks: verified both only ever publish naval towns when ALL
capturable towns are naval (Allocate's main loop scores every non-naval town unconditionally,
so `_scored == 0` ⟺ all-naval; Strategy applies `_candLand` only when non-empty). Filtering
them would delete the designed endgame capture path. Implemented the review's second option:
gate the consumers with a uniform latched "first non-naval published target" pick, gated on
the existing armed flag `WFBE_C_AICOM_NAVAL_AIR_ONLY` (default 1, Init_CommonConstants.sqf:621;
no Parameters.hpp override). Flag 0 reproduces the old slot-0 read exactly.

Edits (Chernarus only, targeted python CRLF edits):
1. `Server/AI/Commander/AI_Commander_Paratroops.sqf` — offensive-primary pick
2. `Server/AI/Commander/AI_Commander_CargoAirdrop.sqf` — offensive-primary pick
3. `Server/Functions/AI_Commander_Wildcard.sqf` — W4, W6, W22 spearhead/anchor picks

Deliberately unchanged (documented in PR):
- W4/W22 `_cands` fallbacks keep naval eligibility — an air-delivered assault/loiter at the
  carrier is the NAVAL_AIR_ONLY doctrine's legal path and the endgame pressure.
- `AI_Commander_MHQReloc.sqf` — reviewed: slot 0 is only a front REFERENCE; the destination
  is a standoff behind the nearest OWN-held town (ring-validated), never the naval town.
- AssignTowns per-team air gates (`_teamAir`/`_bootAir`) remain the per-team authority.

Gates (actuals):
- Lint gate (CLAUDE.md verbatim incl. BAREEXIT/DBLBOM/TRAILCOMMA): 168 findings tree-wide
  = pre-existing baseline; 0 in the three edited files.
- Bracket delta vs origin/master: curly 0 / square 0 for all three files.
- pytest Tools/Lint: 806 passed, 2 skipped (the 2 pre-mirror three-terrain equality
  failures cleared after the LoadoutManager run).
- Mirror: `--check` zero drift for TK and ZG; version.sqf.template restored to
  origin/master; Test-WaspVersionTemplates.ps1 all PASS.

## 2026-08-04 — reconcile PR #2092 onto wave0805

- PR #2092 was stacked on #2060. The wave tip already contains the immobile-hull
  crew egress behavior, so that parent hunk was not duplicated.
- Ported the unique tier-2/3 `WFBE_C_AICOM_STUCK_REPAIR` correction into the Chernarus
  source: after the existing scalar reset, configured vehicle hitpoints are cleared with
  local-object `setHit` calls so a damaged wheel, track, or engine cannot leave the hull
  immobile.
- Added focused Chernarus regression coverage. TK/ZG mirror generation was intentionally
  deferred to the fold orchestrator per the reconcile task boundary.

## wave0804b hotfix — 2026-08-04 [update/wave-20260802]

Task: implement four fixes for three live regressions root-caused by a 6-agent triage
workflow with adversarial verification (results file `wamco7bqt.output`, not part of this
repo — the 'result' field's three lane entries carry the file:line evidence, verified fix
shapes, and verifier `corrections`/`fixRisk`). Worktree `C:\tmp\fixwt\update0802`, sole
writer, branch `update/wave-20260802`, tip at start `47364d446b` (the LIVE Arma 2 OA 1.64
build).

### FIX 1 — build-menu apostrophe/quote corruption (DONE — commit `eb7fa20752`)

BIS_fnc_createmenu (vanilla, `coin_interface.sqf:1038` `call compile '%3'`) formats each
category's WHOLE `_arrayParams` array into a SINGLE-quoted string. Any apostrophe/quote in
one item's resolved label corrupted every sibling's click handler in the same category —
this is why "LoS Screen (Tall)" (itself clean) read as broken: collateral damage from a
TKA/EAST sibling in the same Fortification category payload.

- `coin_interface.sqf` (~line 1008-1021): sanitize `_itemname` right after it's resolved
  and before it reaches `_arrayParams` (~line 1028) — strip ASCII 39 (`'`) and ASCII 34
  (`"`) via the A2-safe `toArray` → filter → `toString` idiom (precedent:
  `GUI_EndOfGameStats.sqf` HC-name strip). **Verifier-confirmed: `regexReplace` does NOT
  exist on A2 OA 1.64** (A3 2.06+ only) — never used.
- `Core_TKA.sqf` (lines 217-234): gave the six TKA empty-label Fortification items real,
  apostrophe-free labels (`Barrier Wall (5x)`, `Barrier Wall (10x)`, `Barrier Wall (10x
  Tall)`, `Camo Net`, `Camo Net (Var)`, `Camo Net (B)`) so the stock-displayName fallback
  never fires for them at all (defense in depth alongside the sanitize).
- Tests: `Tools/Lint/test_coin_menu_label_apostrophe_sanitize.py`,
  `Tools/Lint/test_tka_fortification_item_labels.py`.

### FIX 2 — tooltip `_itemname`/`_preview` undefined-variable RPT spam (DONE — commit `4ce0bf9b4a`)

PROVEN regression from today's commit `942bb614ef`. RPT: "Undefined variable in expression:
_itemname" at `coin_interface.sqf:873` and a matching `_preview` undefined at `:890`, every
preview tick.

- Line ~873: `(if (isNil "_itemname") then {""} else {_itemname})`. Deliberately fell back
  to `""`, **not** the pre-942bb614ef stock-CfgVehicles-displayName re-derivation — the
  existing pinned test `test_fortif_placement_preview_facing.py::
  test_tooltip_header_uses_itemname_not_type_displayname` asserts that expression must
  never reappear in the header `format[]` args (it would silently revert 942bb614ef's
  intent). Confirmed this test still passes.
- Line ~890: guarded the rotate-readout's `round (getDir _preview)` the same way —
  `&& {!(isNil "_preview")}`.
- Tests: `Tools/Lint/test_coin_tooltip_itemname_preview_guard.py`.

### FIX 3 — placement rejected inside HQ circle (DONE — commit `14e662d665`)

Arming `WFBE_C_DEF_PREVIEW_MAP` made `typeOf _preview` a REAL WDDM composition-child
classname, tripping the itemcategory==2 same-classname/DEFENSENAMES proximity checks
against any pre-existing composition nearby (HQ walls etc.) — rejecting placement well
inside the 200m HQ circle.

- `Init_CommonConstants.sqf`: added `WFBE_ANCHOR_PREVIEW_CLASSES` (flat list built via
  `forEach`, never A3 `apply`) right after `WFBE_ANCHOR_PREVIEW_MAP`.
- `Init_Client.sqf` (~1797-1839): wrapped ONLY the two same-classname/DEFENSENAMES checks
  (~1802-1805) in `if !((typeOf _preview) in WFBE_ANCHOR_PREVIEW_CLASSES) then {...}`. The
  factory-clearance ring check (~1808-1831) is intentionally left unconditional — comment
  documents that real density/spacing control stays server-side
  (`WFBE_C_WDDM_COMP_CAP`/fortification cap in `RequestDefense.sqf`).
- Tests: `Tools/Lint/test_fortif_preview_classes_proximity_exemption.py`.

### FIX 4 — whitelisted caster kicked after faction stint (HELD — NOT applied)

PROVEN dead code: `Server/PVFunctions/RequestJoin.sqf`'s CIV-caster always-allowed override
(`if (_side == civilian) then {_canJoin = true};`, ~line 88) sits inside
`if (WF_A2_Vanilla) then {...}` (~85-95), and `WF_A2_Vanilla` is a compile-time
`#ifdef VANILLA` flag (`initJIPCompatible.sqf`) that is FALSE on the deployed OA/CombinedOps
build, so the override never runs live — a caster who played a real faction earlier in the
session gets bounced to the lobby re-joining the CIV seat.

**Not applied, and deliberately excluded from this hotfix wave**, for two independent,
concrete reasons found while reading the repo before coding (as instructed):

1. `CLAUDE.md` "Owner constraints" (line 229): *"Never touch: HC architecture, player
   enrollment/JIP flow, deploy/box scripts."* `RequestJoin.sqf` is exactly player
   enrollment/JIP flow. No carve-out for correctness fixes exists in that section (the
   separate Flag Policy section's "correctness fixes ship unflagged" governs flag-gating
   only, not the file-touch ban — independent axes).
2. `Tools/Lint/test_commander_lease.py` already encodes a **dated, independent owner
   ruling** to the identical effect: *"Round 4 (owner ruling 2026-07-21): the side-change
   stand-down enqueue was relocated OFF RequestJoin.sqf - a JIP-flow file agents must never
   modify... RequestJoin.sqf is now pinned byte-identical to its pre-C1 base."* (see
   `test_07b_requestjoin_is_untouched_jip_flow_file`).

The triage workflow's own adversarial verifier reached the same conclusion independently
(lane 3 `fixRisk`): *"This fix must not be shipped/PR'd without explicit owner sign-off
overriding that constraint; the lane should escalate rather than proceed on 'correctness
fix' reasoning alone."*

**Action taken**: flagged the conflict, held the fix, and did not touch `RequestJoin.sqf`.
Added `Tools/Lint/test_requestjoin_civ_caster_override_unconditional.py` with both
assertions `@pytest.mark.skip`'d (reason references this journal entry) so CI stays green
while the intended contract is captured and re-runnable the moment this is authorized.

**Ready-to-apply patch (verified against current source, held pending owner sign-off)** —
apply via the standard targeted-Python CRLF-preserving edit workflow, mirror CH→TK/ZG, then
un-skip the two tests above:

```
--- Server/PVFunctions/RequestJoin.sqf (current, live-broken)
+++ Server/PVFunctions/RequestJoin.sqf (proposed)
@@ -83,11 +83,15 @@
 };

-if (WF_A2_Vanilla) then {
+//--- caster seat target: always allowed regardless of any check above (observer, not a
+//--- team). Hoisted OUT of the WF_A2_Vanilla conditional below: WF_A2_Vanilla is a
+//--- compile-time #ifdef VANILLA flag (initJIPCompatible.sqf) that is FALSE on the
+//--- deployed OA/CombinedOps build, so nesting this override inside `if (WF_A2_Vanilla)`
+//--- made it unreachable dead code on live - a caster with a stored prior-faction side
+//--- kept getting the raw (false) _canJoin from the teamswap-mismatch branch above and
+//--- was bounced to the lobby.
+if (_side == civilian) then {_canJoin = true};
+
+if (WF_A2_Vanilla) then {

-	//--- caster seat target: always allowed regardless of any check above (observer, not a team).
-	if (_side == civilian) then {_canJoin = true};
 	[_uid, "HandleSpecial", ["join-answer", _canJoin, _skillBLUFOR, _skillOPFOR]] Call WFBE_CO_FNC_SendToClients;

 } else {
```

Net bracket delta zero (pure statement relocation + comment). Byte-identical in the
`WF_A2_Vanilla == true` branch; only changes behavior for a civilian join target on the
live (`else`, `WF_A2_Vanilla == false`) path — exactly the branch that's currently broken.

**To ship**: get explicit fresh owner confirmation to override the standing "never touch
RequestJoin.sqf" ruling, apply the patch above with the mandatory Python CRLF-preserving
edit workflow, mirror, un-skip
`Tools/Lint/test_requestjoin_civ_caster_override_unconditional.py`, re-run all gates, amend
`test_07b_requestjoin_is_untouched_jip_flow_file`'s docstring/scope in
`test_commander_lease.py` if the owner ruling itself is being formally revised (or get a
second, narrower ruling that exempts this specific hoist), and commit separately.

### Gates (fixes 1-3 + tests)

- Mirror: `dotnet run -c RELEASE` (CH→TK/ZG) clean, `-- --check` reports zero drift on both.
  `version.sqf.template` restored to **branch HEAD** (not `origin/master` — this branch is
  ahead of master on the WF_MAXPLAYERS=34 bump) on TK/ZG; all three CH/TK/ZG templates
  confirmed `WF_MAXPLAYERS 34`.
- `python -m pytest Tools/ -q` → 864 passed, 2 skipped (the held FIX 4 contract), 0 failed.
- CLAUDE.md lint gate verbatim → 168 findings, all pre-existing `A3MARKER` (none in any file
  touched by this wave).
- Bracket delta zero (curly + square) per edited file vs `origin/master`: confirmed for all
  four hand-edited Chernarus files.

### Discovered Issues (off-scope, not fixed here)

- `Tools/Ops/Test-WaspVersionTemplates.ps1` is **stale**: it asserts
  `WF_MAXPLAYERS 32/31/33` (Chernarus/Takistan/Zargabad), last touched 2026-07-21. The
  actual branch HEAD (already true *before* this session touched anything, confirmed via
  `git show HEAD:.../version.sqf.template`) and CLAUDE.md's documented current values are
  all `34`. This script was already failing before this session started; it is not one of
  this task's required gates (which specify mirror `--check` clean + templates restored to
  branch HEAD with all three = 34, not this script), so left as-is and flagged here rather
  than silently "fixed" by rewriting someone else's stale ops guard mid-hotfix.

## Working State 2026-08-04 — fortification placement/preview/facing fix package [update/wave-20260802]

Task: owner complaint "The issue is placement, preview, facing direction indications" for
defense/fortification building. A prior 16-agent verification workflow confirmed root causes
with file:line evidence (results file: `wyb0vtw3u.output`, not part of this repo). Worktree
`C:\tmp\fixwt\update0802`, sole writer, branch `update/wave-20260802` (base commit
`c01352736c` at start). Implemented findings 2, 3, 5, 6 from that verification; explicitly
SKIPPED finding 1's collision-footprint rework (composition-vs-anchor collision checks) per
task scope — see "Discovered Issues / Follow-up" below.

### Root cause (confirmed by the verification workflow, re-verified here against source)

`Client/Module/CoIn/coin_interface.sqf` builds the WDDM placement ghost from a `ghostpreview`
CfgVehicles property (`getText (configFile >> "CfgVehicles" >> _itemclass >> "ghostpreview")`)
that NO class in this mission tree defines — confirmed via `git grep -i ghostpreview`, zero
`ghostpreview = "..."` definitions anywhere. The lookup always falls back to `_itemclass`
itself (the raw WDDM anchor placeholder classname), so every WDDM-composition item (walls,
HESCO, LoS screen, gate, hedgehog line, flak tower) previews as a cheap decoy prop (cargo
container / industrial tank / concrete slab) that looks nothing like what actually gets built,
and is near-symmetric so a facing (setDir) change is visually imperceptible. Separately, the
ROTATE=[Ctrl] hint (`str_coin_rotate`) was dead: `_ctrl` was computed every poll tick
(`BIS_CONTROL_CAM_keys`) and never read again — no `setDir` call in the file was gated on it.
The no-preview failure path (`isnull _preview`) only wrote an RPT `diag_log` line and silently
cleared the player's selection with zero on-screen feedback. The placement tooltip header
re-derived the anchor's stock CfgVehicles `displayName` instead of using the already-computed
WFBE buy-menu label (`_itemname`, set at the top of the same tick).

### Fix 2 — WFBE_ANCHOR_PREVIEW_MAP (classname->classname preview override)

New flag `WFBE_C_DEF_PREVIEW_MAP` (default 0) + new always-defined data array
`WFBE_ANCHOR_PREVIEW_MAP` in `Common/Init/Init_CommonConstants.sqf` (loads on both client and
server — `Init_Defenses.sqf`'s `WFBE_POSITION_TEMPLATE_MAP` is server-only, confirmed absent
from Client/Common via grep, so it could not be reused directly). Maps each of the 7 "decoy
prop" anchors (the ones the owner's complaint specifically names: cargo containers, industrial
tank, concrete slab) to ONE lightweight, already-spawned-elsewhere representative classname,
never the full multi-object composition (would churn 3-10 spawn/despawn pairs every
preview-refresh tick):

| Anchor (buy-menu item)         | Preview override          | Verified real host (Init_Defenses.sqf) |
|---------------------------------|----------------------------|------------------------------------------|
| Misc_cargo_cont_small (Hedgehog Line) | Hedgehog_EP1         | WFBE_NEURODEF_HEDGEHOGLINE child |
| Land_Ind_TankSmall (Flak Tower) | Land_Ind_IlluminantTower  | WFBE_C_DEF_FLAKTOWER_STRUCTURE default host |
| Misc_cargo_cont_net1 (Wall Row) | Concrete_Wall_EP1         | WFBE_NEURODEF_FORTIF_WALL_ROW child |
| Misc_cargo_cont_net2 (Wall Corner) | Land_HBarrier3          | WFBE_NEURODEF_WALL_CORNER hub piece |
| Misc_cargo_cont_net3 (LoS Screen) | Base_WarfareBBarrier10xTall | WFBE_NEURODEF_FORTIF_LOS_SCREEN child |
| Misc_cargo_cont_tiny (HESCO Line) | Land_HBarrier_large     | WFBE_NEURODEF_FORTIF_HESCO_LINE child |
| Misc_concrete_High (Gate Complex) | Land_BarGate2           | WFBE_NEURODEF_FORTIF_GATE_COMPLEX gate |

Every representative classname was cross-checked (a) pairwise-distinct from every other entry
and from every anchor classname (preserves the existing `typeof _preview != _itemclass_preview`
respawn-on-switch check), and (b) already spawned somewhere in `Init_Defenses.sqf`'s
`WFBE_NEURODEF_*` arrays or `Server_ConstructPosition.sqf` (never an invented/unverified
classname) — both asserted by `test_anchor_preview_map_*` in the new test file. `coin_interface.sqf`
gets one small addition immediately after the existing `ghostpreview` getText + fallback (lines
524-525 pre-edit): when the flag is armed, a `forEach` over the map overrides
`_itemclass_preview` if the current `_itemclass` has an entry; flag-off, the two original lines
are untouched and behavior is byte-identical. The 9 non-decoy anchors (Paleta1/2,
Land_Ind_Timbers, RoadCone, Land_WoodenRamp, Land_Barrel_sand, Land_Ind_BoardsPack1/2,
Land_CncBlock_Stripes) are deliberately left unmapped — they already have plausible physical
shapes and are out of the owner's specific "decoy prop" complaint.

### Fix 3 — Tick-increment placement rotation + live heading readout

New flags `WFBE_C_DEF_PLACE_ROTATE` (default 0) and `WFBE_C_DEF_PLACE_ROTATE_DEG_SEC` (default
90, degrees/second tunable). In `coin_interface.sqf`'s existing-preview branch (the `} else {`
right before the "Check zone" comment — NOT the fresh-preview/`_new` branch, so a newly created
preview still cleanly inherits `BIS_COIN_lastdir` first), while the preview flag is armed AND
`_ctrl` is held, `_preview setDir ((getDir _preview) + (WFBE_C_DEF_PLACE_ROTATE_DEG_SEC *
_pollSleep))` — a TICK-INCREMENT rotation scaled by the poll interval, not mouse-delta (this
poll loop hardcodes `_mode = "mousemoving"` as a literal string and has no per-frame mouse-move
delta available at this call site — confirmed by the verification workflow and re-checked here
by reading the whole 1039-line file). The same block sets `WF_RequestUpdate = true` so the
tooltip's own change-detection cache (`(_tooltipType+_tooltip) != _oldTooltip || ... ||
WF_RequestUpdate`) rebuilds THAT tick — without this, the rotate-hint text (`_text1`) would go
stale while Ctrl is held, since the cache key (`_tooltipType + _tooltip`, both fixed classname
strings) never itself changes as the player rotates. `_text1` now appends
`round (getDir _preview)` in degrees next to the existing "ROTATE = Ctrl" hint whenever the flag
is armed and `_tooltipType == "preview"` (a genuine preview exists this tick — guards against
reading a stale/deleted `_preview` on a tick where the whole `count _params > 0` block never
ran). Used plain ASCII "deg" instead of the "°" glyph to avoid any SQF-string/codepage risk.

### Fix 5 — Visible feedback on preview-creation failure

Inside the existing `if (isnull _preview) then {...}` block (the `createVehicleLocal` failure
path — a genuine, reproducible A2 OA failure mode per the pre-existing `diag_log
COINPLACE|v1|no-preview|...` line added 2026-07-28), added one `hintSilent Format ["Cannot
place %1 - no preview available.", _itemname];` immediately after the existing `diag_log` and
before the existing selection reset (`BIS_COIN_preview`/`BIS_COIN_params` cleared). Unflagged,
direct fix — this is a correctness/UX fix (surfacing an already-silent failure with zero
behavior change), not a new feature, matching this repo's flag policy
("Correctness fixes... ship directly, no flag required"). Reset/cleanup flow is completely
unchanged; only the missing player notice was added.

### Fix 6 — Placement tooltip label uses the WFBE buy-menu name

`_textHeader`'s `format [...]` call (inside `if (_tooltipType != "empty") then {...}`) used
`getText (configFile >> "cfgvehicles" >> _type >> "displayname")` — the anchor's raw stock
CfgVehicles name (e.g. a generic cargo-container prop name) — instead of `_itemname`, already
computed earlier in the same tick (line 523) as the WFBE buy-menu label, and already correctly
used for the menu button text elsewhere in the same file. Swapped the one argument. Icon/picture
resolution (`_fileIcon`/`_filePicture`, keyed off `_type`) is deliberately untouched — separate,
out-of-scope concern per the verification workflow's own note. Unflagged, direct correctness fix
(same reasoning as Fix 5).

### Flags summary

| Flag | Default | Armed this session? |
|---|---|---|
| `WFBE_C_DEF_PREVIEW_MAP` | 0 | Yes, final commit "ARMED 2026-08-04 owner fortification complaint" |
| `WFBE_C_DEF_PLACE_ROTATE` | 0 | Yes, same commit |
| `WFBE_C_DEF_PLACE_ROTATE_DEG_SEC` | 90 | n/a (tunable, not a boolean gate) |

Fixes 5 and 6 are unflagged correctness fixes (see above), so there was nothing to arm for them.

### Commits (this session, oldest first)

- `b49ed0e793` fix(coin): WDDM placement-ghost preview map [flag WFBE_C_DEF_PREVIEW_MAP default 0]
- `8621fd433f` fix(coin): tick-increment placement rotation + live heading readout [flag WFBE_C_DEF_PLACE_ROTATE default 0]
- `4a6869ed76` fix(coin): visible feedback when the placement ghost fails to spawn (unflagged)
- `942bb614ef` fix(coin): placement tooltip header shows the WFBE buy-menu label (unflagged)
- `6cd6c00759` test: behavior contract for fortification placement/preview/facing fixes
- `db2a57fc8a` feat(coin): arm WFBE_C_DEF_PREVIEW_MAP and WFBE_C_DEF_PLACE_ROTATE

Each commit was independently mirror-regenerated (Tools/LoadoutManager) and bracket-delta-
verified before the next was applied, so any of the 6 can be reverted individually without
corrupting the sequence. No `Co-Authored-By` trailer in any commit. Not pushed.

### Verification

- `python -m pytest Tools/ -q`: 840 passed, 0 failed (baseline before this session's edits: 827
  passed after mirror regen; +13 new tests in `Tools/Lint/test_fortif_placement_preview_facing.py`).
  Caught and fixed one self-inflicted regression along the way: a code comment in
  `Init_CommonConstants.sqf` literally contained the word "deleteVehicle" (in
  "createVehicleLocal/deleteVehicle pairs"), which bumped `Tools/Lint/vehdel_inventory.json`'s
  tracked count for that file from 4 to 5 and failed `test_veh_delete_probe.py`'s ratchet
  manifest test — reworded the comment ("spawn/despawn (createVehicleLocal) pairs") rather than
  regenerating the manifest, since the change was comment-only, not a real delete call site.
- Lint gate (verbatim CLAUDE.md selector list, `--no-classname-index`): 168 findings, all
  pre-existing (matches the documented baseline exactly) — 0 new findings in either edited file.
- Net bracket (`{}`/`[]`) delta: 0 on every edited file, all three terrains (6 files total).
- `dotnet run -c RELEASE -- --check` (Tools/LoadoutManager): Takistan and Zargabad both report
  "drift: none". `version.sqf.template` untouched by this session's edits; confirmed all three
  still read `WF_MAXPLAYERS 34` (this branch's established 34/34/34 convention — NOT the
  31/33 values the wiki mirror-regen doc or `Test-WaspVersionTemplates.ps1` still expect for
  TK/ZG; that script is known-stale for this branch per a prior gate-repair session's journal
  entry and CLAUDE.md itself — its 3 FAILs on max-player values are expected noise, not a real
  regression, and were NOT "fixed" by reverting to the older per-map values).
- New tests assert BEHAVIOR (structural invariants: pairwise distinctness, flag-gating,
  tick-scaling, code ordering, cross-references into `Init_Defenses.sqf` for classname
  verification) rather than pasting implementation-literal diff text.

### Discovered Issues / Follow-up (not done this session)

- **Collision-footprint rework (finding 1, explicitly out of scope per task instructions).**
  `Client/Init/Init_Client.sqf`'s `_itemcategory == 2` placement-validity block (~line 1780+)
  measures anti-stack/defense-proximity/entity checks from the decoy anchor's own tiny
  bounding box, never the real multi-object composition's true footprint (LoS Screen ~43 m,
  HESCO Line ~39 m, Wall Row ~22 m — all live by default, `WFBE_C_DEF_FORTIF_PACK = 1`). The
  verification workflow's finalFix (a `WFBE_FORTIF_FOOTPRINT_RADIUS` table + scanning for the
  `WFBE_WDDMPositionAnchor` tag instead of a classname) is a separate, larger change — left
  for a dedicated follow-up PR, not touched here.
- The verification workflow also flagged a separate `relDir` facing-offset bug (composition
  children silently rotate away from the anchor ghost's authored facing for non-zero-relDir
  hosts, e.g. the Gate Complex's `Land_BarGate2` at relDir 90) and a full per-child ghost
  preview (spawning every composition child as its own oriented ghost, not just the anchor).
  Both are larger changes explicitly out of this session's scope (fix 2 here only swaps WHICH
  single classname previews, not a multi-object preview or a facing-offset correction) — noted
  for the same follow-up as the collision-footprint rework.
- Did NOT re-add the pre-fix facing-arrow (commit 25357c0dfe) — the verification workflow
  confirmed a literal re-add would resurrect an already-fixed crash/leak (the arrow-creation
  call sat in a spot that regresses on every no-preview failure, and only 1 of 6 original
  cleanup sites survived the revert). Chose the live text degree-readout (Fix 3) instead of a
  3D facing indicator, which sidesteps that whole class of spawn/cleanup risk entirely.
- No live/box runtime smoke test performed this session (static validation only, matching this
  repo's evidence-wording convention) — an in-engine check that `getDir`/`setDir` on a
  `createVehicleLocal`-spawned preview object behave as expected mid-placement is still owed
  before the owner treats rotation as fully verified, though both commands are already used
  elsewhere in this same file on the same object (lines ~616, ~629, ~693), so this is low-risk.

## Working State 2026-08-04 — wave0804 gate repair (73 PR-fold merges) [update/wave-20260802]

Task: after 73 "fold #NNNN into wave0804" merge commits landed on this branch (base
42d0191ea8, HEAD 3af93fe675), all three gates (LoadoutManager mirror check, pytest,
lint) were failing. Goal: make every gate pass without weakening any test, no push.

### 1. LoadoutManager mirror drift

`dotnet run -c RELEASE -- --check` reported 4-file drift on BOTH Takistan and Zargabad
(Common_CommanderLease.sqf, Server_OnPlayerDisconnected.sqf, Server_VoteForCommander.sqf,
RequestCommanderVote.sqf) — folds had touched the Chernarus source without the mirror
generator having run since. Fix: `A2WASP_SKIP_ZIP=1 dotnet run -c RELEASE` from
Tools/LoadoutManager, twice (once before the pytest-driven CH edits below, once after,
to also propagate those). `--check` now reports zero drift on both mirrors.

WF_MAXPLAYERS: verified all three `version.sqf.template` files (CH/TK/ZG) read 34 both
before and after each generator run — no drift occurred this run, matching branch HEAD
and this branch's own CLAUDE.md ("TK: WF_MAXPLAYERS 34 ... ZG: WF_MAXPLAYERS 34" — the
34/34/34 normalization is this branch's intentional, owner-approved state, NOT the older
31/33 values documented in the repo wiki's mirror-regen skill doc, which is stale for
this branch). No revert was needed.

### 2. pytest — 5 failures, root causes and resolutions

- **test_fpv_purchase_authority.py::test_server_validates_wallet_and_per_uid_rearm_before_registering**
  — fold #1636 (fix commit 713e830ce3, "object/missionNamespace var pollution — CBR
  registry, FPV PV, disconnect keys") deliberately replaced `publicVariable _nextKey`
  (a real bug: broadcasting a per-UID rearm-cooldown variable to every connected client)
  with a private targeted send via the file's existing `_sendPrivate` helper
  (`["fpv-rearm-cooldown", _next], _replyId, _uid] Call _sendPrivate`), fully mirrored to
  TK/ZG and consumed by a matching new `case "fpv-rearm-cooldown"` handler in
  Client/PVFunctions/HandleSpecial.sqf. Legitimate improvement — realigned the test to
  assert the new private-send behavior instead of the old broadcast literal, and added a
  regression guard (`assertNotIn("publicVariable _nextKey", code)`) so the bug can't
  silently come back.

- **test_overrun_razer_reachability.py::test_engagegate_patch_alive_filters_before_ranging**
  — NOT a test-vs-behavior mismatch. Fold #1738 (fix commit 461de7d48b, "rally regroup
  hold + live dest revalidation (r61)") introduced a genuine SQF syntax bug in
  Common_RunCommanderTeam.sqf: an unterminated string literal —
  `[_stB,_stC,"WEDGE","NORMAL]]]] Spawn WFBE_CO_FNC_WaypointsAdd;` — missing the closing
  `"` after NORMAL (compare the two correct sibling call sites a few lines below/above
  using the identical idiom `"WEDGE","NORMAL"]]]]`). The runaway string swallowed the
  rest of the file for `mask_comments`'s state machine, which is why the FIRST occurrence
  of the FLAG token the test searched for landed inside an unmasked comment instead of
  the real gate condition. **Fixed the bug directly** (added the missing `"`) rather than
  reverting the whole fold — the feature (defensive SAD hold on rally arrival) is sound,
  it was a single-character typo. Test needed no changes; it passes once the source
  bug is fixed. Mirrored to TK/ZG via the LoadoutManager regen.

- **test_settownattackpath_nilside.py::test_deleted_dispatch_inputs_exit_before_dereference**
  — fold #1781 (fix commit b177657b36, "town attack pathfind fail-clean (r78b)") added a
  null-leader guard in Server_AI_SetTownAttackPath.sqf: `leader _team` is now captured
  into `_fallbackLeader`, null-checked with its own `exitWith` (logged), and only then
  dereferenced via `getPos _fallbackLeader` — replacing the old unguarded
  `_wp_origin = getPos (leader _team);` that could throw on an empty/culled group.
  Legitimate defensive fix (part of a 5-bug integrity pass, CH→TK/ZG mirrored,
  byte-identical across all three). Realigned the test to assert the new capture/guard/
  read sequence and disambiguated the two `_fallbackLeader = leader _team` occurrences in
  the file (the new r78b guard near the top, and the pre-existing #1209 side-recovery
  block further down) by anchoring each `.index()` search from the correct offset.

- **test_supply_completion_authority.py::test_client_completion_rederives_sender_side_and_validates_delivery_state**
  — fold #1619 (fix commit 49a565ca4f, "cargo transfer world revalidation + deliverer +
  exitWith latch") changed `_sidePlayer = side _playerObject;` to
  `_sidePlayer = side group _playerObject;` with an inline comment explaining why
  (`side group` is more stable than bare `side unit` when the unit is mid-state-change).
  Legitimate hardening, consistent with the rest of that fold's "never trust the
  client-provided side slot" theme. Realigned the test's expected token.

- **test_veh_delete_probe.py::test_ratchet_manifest_matches_the_entire_tree** — folds
  added/changed deleteVehicle call sites in 6 files (Common_RunSidePatrol.sqf,
  Server_GuerDirector.sqf, server_town.sqf, Server_ManageTownDefenses.sqf,
  Server_OnPlayerDisconnected.sqf, Server_TownGarrisonDressing.sqf) without regenerating
  vehdel_inventory.json. Wrote a regen script mirroring the test's own computation
  (`text.count("deleteVehicle")` / `text.count("WFBE_CO_FNC_LogVehDelete")` per file,
  same JSON style: 1-space indent, CRLF, no BOM) — but did NOT blindly overwrite first.
  Diffed old-vs-fresh manifest and found fold #1631 (fix commit 19d4703805, "reclaim
  town-AI budget on capture") had added 2 NEW deleteVehicle sites to server_town.sqf
  (town-capture-unit/hull teardown) WITH proper adjacent probes for those 2 sites, but
  this pushed the file's `probed` count from 0 to 2 — which would newly subject the
  file's other 10 pre-existing, never-probed deleteVehicle sites (hangar/navsp/defense-
  gunner/defense-structure/mop-up-squad/garrison-unit/SP/dressing-props/radar teardown)
  to `test_every_code_delete_in_probed_files_is_probe_adjacent`'s all-or-nothing
  per-file policy, which is enforced on purpose ("no curated subset left to argue
  about"). Added matching `[<reason>, _obj, ""] Call WFBE_CO_FNC_LogVehDelete;` probe
  calls (telemetry-only, gated behind WFBE_C_VEH_DELETE_PROBE, no behavior change) to
  all 10 remaining sites, following the exact same-line convention already used
  elsewhere in this file and in Server_TownGarrisonDressing.sqf. Verified 0/0 bracket
  delta on both edited files. Regenerated the manifest after — all 5 veh_delete_probe
  tests pass, including the adjacency check.

No fold was reverted. All 5 failures traced to either (a) a stale test pinned to
superseded literal behavior that the fold legitimately and deliberately changed, or
(b) one real syntax bug (fold #1738) that was fixed at the source instead of reverting
the whole feature.

### 3. Lint gate

Ran the verbatim gate command from this repo's CLAUDE.md (A3CMD..TRAILCOMMA incl.
BAREEXIT, `--no-classname-index`). See gate-output tail in the final report / PR body.

### Files touched (source)

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_RunCommanderTeam.sqf`
  — 1-byte string-terminator fix (missing `"`), mirrored to TK/ZG.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/FSM/server_town.sqf` — 10 new
  probe-call insertions (telemetry only), mirrored to TK/ZG.
- `Tools/Lint/test_fpv_purchase_authority.py`, `test_settownattackpath_nilside.py`,
  `test_supply_completion_authority.py` — realigned to current (post-fold) behavior.
- `Tools/Lint/vehdel_inventory.json` — regenerated ratchet manifest.
- Mirror propagation touched the corresponding TK/ZG copies of the two edited CH files
  plus the 4 previously-drifted files (Common_CommanderLease.sqf,
  Server_OnPlayerDisconnected.sqf, Server_VoteForCommander.sqf,
  RequestCommanderVote.sqf) on both Takistan and Zargabad.



Task: owner live bug report (m0801h-era, Takistan, mid-match 2026-08-02 16:47) - two AICOM
production-placement defects. Worktree C:/tmp/claudewt/founding-fix, branch
fable/founding-placement-20260802, base master (6ea2bcf17b at clone time).

### Symptom 1: infantry founding/reinforcing at an owned airfield with no Barracks

Root cause found: NOT the B74/cmdcon41 airfield-runway relocation (that only fires for a real
isKindOf "Air" template, gated on _hasAirfield, and only relocates a team that IS an air team).
The actual defect is in AI_Commander_Produce.sqf's always-on "(4) TOWN-CENTER TOP-UP DISPATCHER"
(cmdcon41-w2, unconditional - not behind any flag). Its "parked" test (~line 195-198 pre-fix)
accepted ANY owned town within 400m of the team leader (sideID match only), with NO check that the
town hosts a Barracks or any production structure. An infantry team resting/rallying near a
captured airfield-only town (no Barracks ever built there) still satisfied "parked", so the
topup_req dispatch conjured fresh infantry bodies directly at the leader's exact rally position -
the same "magic infantry" anti-pattern WFBE_C_AICOM_FOUND_REQUIRE_FACTORY was armed (2026-07-10) to
stop for founding, just never wired into this reinforcement path. (Confirmed towns[] includes
airfields uniformly with city/village markers - AI_Commander_Teams.sqf:526 does the identical
wfbe_is_airfield scan over the same towns array.) The separate AI_Commander_HCTopUp.sqf file has
the identical unstructured-town defect but is inert by default (WFBE_C_AICOM_HC_TOPUP_ENABLE=0),
so it is not the live cause.

Fix: new flag WFBE_C_AICOM_TOPUP_REQUIRE_BARRACKS (default 0, byte-identical at 0). When armed,
the town-proximity "parked" grant is replaced with "an alive owned Barracks within the same 400m
range" (HQ-parked branch untouched). One always-on INFORMATION line logs the withheld case.

### Symptom 2: AI commander refuses to build/found units at forward factories

Root cause found: WFBE_C_AICOM_FACTORY_TARGET_ENABLE (default 0) governs ONLY the deficit-fill
refill loop in AI_Commander_Produce.sqf, which per the B57/Build83 comments in
AI_Commander_Teams.sqf only serves SERVER-LOCAL, NON-HC teams - "100% of the live army" is now
HC-founded and explicitly SKIPPED by Produce.sqf's _canProduce gate (line ~297: excludes
wfbe_aicom_hc teams). So that flag's own effect is nearly moot for the live game; it is NOT purely
the dark flag "working as designed" causing the report - a separate, bigger defect sits upstream.

The actual bug: AI_Commander_Teams.sqf's HC-team FOUNDING factory pick (the "doctrine factory"
scan, and the OWNED-FACTORY-GATE re-anchor scan) both resolve the spawn structure via a bare
forEach+exitWith over wfbe_structures - which is APPEND-ONLY build order (new structures are
always `+ [_site]`, confirmed in Construction_SmallSite.sqf/_MediumSite.sqf), never distance-sorted.
So the AI commander ALWAYS spawns founded units from the FIRST factory of the matching type it ever
built (the original rear base), and a later player-built FORWARD factory of the same type is never
reached no matter how close to the front it stands, or how depleted/far the rear one is.

Fix: new Common function WFBE_CO_FNC_PickForwardFactory (Common/Functions/Common_PickForwardFactory.sqf)
scans all alive matching-type structures and picks the one nearest an unowned/enemy town (the most
forward one). Wired behind new flag WFBE_C_AICOM_FOUND_FACTORY_FORWARD (default 0, byte-identical at
0) at both factory-selection call sites in AI_Commander_Teams.sqf. One always-on INFORMATION line
logs each forward pick.

### Owner judgment needed

Both new flags default 0 (mission byte-identical to HEAD until armed) per repo flag policy - these
are behavior changes, not crash/nil-deref fixes, so neither is armed in this PR. See PR body /
final report for the arm recommendation.

### Gates run

- Lint gate (full select list, --no-classname-index): 0 new findings in any edited/created file
  across all 3 terrains (168 pre-existing findings unchanged).
- Bracket delta (git diff origin/master, curly+square): 0 on every edited file, all 3 terrains.
- Mirror regen (dotnet run -c RELEASE, A2WASP_SKIP_ZIP=1): CH/TK/ZG all DONE; --check reports zero
  drift; version.sqf.template needed no restore (untouched by this change).
- Test-WaspVersionTemplates.ps1: all PASS (CH/TK/ZG).
- pytest Tools/Lint: 15 failed / 480 passed on THIS branch - identical 15 failing test IDs and
  identical count confirmed on origin/master baseline (stash-and-rerun). Zero new failures.

## Working State 2026-08-02 — endgame leaderboard + awards [fable/endgame-awards-20260802]

Task: owner ruling 2026-08-02 17:17 authorized SPEC-SCENARIO-POLISH-20260802.md lane 1 ONLY - a
per-player end-of-round leaderboard + named awards bolted onto the existing `GUI_EndOfGameStats.sqf`
screen. All other lanes from that spec run are out of scope. Worktree `C:\tmp\claudewt\endgame-awards`,
branch `fable/endgame-awards-20260802` from `origin/update/wave-20260802`.

**Scope discipline honored**: no new networking, no new persistent state, no server-side changes.
The leaderboard is built entirely client-local inside `GUI_EndOfGameStats.sqf` from `allPlayers` +
the engine's own native `score`/`side`/`name` commands (the same `score player` already displayed
per-client at line 96 pre-existing) - not the spec's original server-side
`WFBE_CO_FNC_CollectRoundScores` + `publicVariable` recommendation, which would have been new
networking. Deviation noted in the PR body.

**Flags**: `WFBE_C_ENDGAME_LEADERBOARD` (default 0) and `WFBE_C_ENDGAME_AWARDS` (default 0, dependent
on leaderboard). Both registered in `Common/Init/Init_CommonConstants.sqf`.

**Files touched (CH source only; TK/ZG are LoadoutManager mirror output, byte-identical to CH)**:
- `Client/GUI/GUI_EndOfGameStats.sqf` - flag reads near `_guerPanel`; new `if (_leaderboardFlag)`
  block (collect `allPlayers` scores, insertion-sort descending, render Top 5 + awards as
  structured text) inserted after the existing guer-vehicle-lost-bar block, before the counter
  animation loop starts.
- `Rsc/Titles.hpp` - two new controls in `class EndOfGameStats`: `LeaderboardBackground` (idc 90409)
  and `LeaderboardPanel` (idc 90410, `RscStructuredText`). Both default positioned OFF-SCREEN
  (y=2), mirroring the existing off-screen-by-default `Guer*` control idiom already in this class -
  SQF only repositions them onscreen (y=0.92/0.925) when the leaderboard flag is on. This keeps
  flag-off byte-identical without needing any `#ifdef`/preprocessor branching in the static config.
- `Common/Init/Init_CommonConstants.sqf` - the two flag registrations, appended at file end (after
  the existing `WFBE_C_STATS_ROUNDEND_FLUSH` block, before the `INITIALIZATION` log line).

**Layout decision**: did NOT try to reflow the existing tightly-packed East/West/Guer bar columns
(measured: default gap between East/West bars is only ~0.10 screen-width; with the Guer panel on,
two ~0.065 gaps) - reflowing those would have meant repositioning 8-24 existing controls and real
regression risk to a screen other PRs may also touch. Instead the new panel lives in genuinely free
space BELOW the existing stats panel (y 0.92-0.99), fully additive, zero risk to existing controls.
Renders regardless of `WFBE_C_FIX_GUER_ENDGAME_STATS_PANEL` state (no collision to design around).

**Deviations from spec** (spec wins where explicitly owner-approved; code reality wins otherwise):
1. Leaderboard built client-local (see above) instead of server-side + publicVariable.
2. "GUER MVP" implemented as "Top Killer (GUER)" from the same per-player score rows, NOT from the
   cumulative `WFBE_GUER_PLAYER_KILLS` counter the spec named - that counter is side-wide, not
   attributable to one player; a true per-player version needs a new counter, which is out of scope
   per the owner's "no new persistent state" constraint. The spec's own text flagged this same gap.
3. "Most Vehicles Lost" implemented as a side-level award (West/East/GUER), not a named individual -
   no per-player vehicle-loss counter exists (only the WF_Logic side aggregates already displayed).
4. Does not depend on/reference `WFBE_C_STATS_ROUNDEND_FLUSH` or `WFBE_CO_CURRENT_SCORE_PLAYER_*` at
   all - native `score` already reflects the full round live, independent of that persistence flush.

**Gates run**: lint gate (168 findings before and after - 0 new, none in touched files); bracket
delta 0 on all 3 CH files; mirror ran (`A2WASP_SKIP_ZIP=1`), `--check` clean, TK/ZG
`version.sqf.template` untouched by the run (no restore needed), `Test-WaspVersionTemplates.ps1`
all PASS; TK/ZG mirror output diffed byte-identical to CH source for both touched files.

**Not yet done / open items**: no runtime (box) smoke test - static validation only, per repo
evidence-wording rules. Draft PR not yet opened as of this note (see PR section once created).

**Wave reconcile 2026-08-03** (worktree `C:\tmp\reconwt\pr1915`, branch `recon/pr1915-20260803`):
merged cleanly onto `origin/update/wave-20260802`. Only conflicts were pure-addition collisions in
`Init_CommonConstants.sqf` (all 3 terrains, both PR #1912's barracks/forward-factory flags and this
PR's two flags appended at the same anchor point - combined, no logic change to either) and this
JOURNAL.md file. `GUI_EndOfGameStats.sqf` and `Rsc/Titles.hpp` merged with zero conflicts on all 3
terrains - nothing else in the wave touches those files at this branch point (confirmed via `git log`
on the merge-base..wave range). #1777 (separate open draft, null-guard fixes to the same file) is
NOT yet merged into the wave, so there was no overlap to resolve against it.

## Working State 2026-08-03 — SQF utility library adoption [claude/sqf-util-lib]

**Card**: #25 in the FLEET-20260802 mining-review batch ("CBA-derived SQF utility adoption:
hash/dict store + 3D vector math + delayless dispatch"). Effort S / Risk low / "Clear to build".

**Delivered** (5 commits, all three maps mirrored via LoadoutManager):
1. `Common_HashCreate/Get/Set/HasKey/Rem.sqf` - parallel-array key/value store, documented
   as an honest linear scan, not a perf win over `Server_CmdTownLedger.sqf`'s existing idiom.
   `HashSet` mutates in place; `HashRem` returns a new handle (no `deleteAt` on A2 OA).
2. `Common_VectDot/Cross/Magnitude/ElevationSolve/LeadAngle/SurfaceNormal.sqf` - manual-
   arithmetic vector math (not wrapping any native `vect*` command).
3. `Common_DelaylessCall.sqf` + `Common/FSM/delayless.fsm` - execFSM-based zero-scheduler-
   delay dispatch for hot-path one-shot calls, as an alternative to `spawn`.
4. `Common_UtilLibSelfTest.sqf`, registration in `Init_Common.sqf`, flag
   `WFBE_C_UTIL_LIB_SELFTEST` (default 0, boot smoke-test only) in `Init_CommonConstants.sqf`.
5. `docs/design/SQF-UTIL-LIB.md` - API reference.

Pure additive, no call-site migrations (card names no explicit demonstrative adoption target -
future consumers are #1/#12/#14, all separate flag-gated PRs). Lint gate clean (zero findings
in any touched/new file), bracket delta zero per file, mirrors identical across CH/TK/ZG,
`Test-WaspVersionTemplates.ps1` all PASS.

**Discovered issue / unresolved blocker (soft, matches the card's own note)**: this session ran
with no network access (role-locked), so the `a2oa-verify-command` skill's rungs 1-2 (repo wiki,
BI wiki) could not be climbed for two claims:
- whether A2 OA 1.64 natively exposes any vector command equivalent to
  `VectDot`/`VectCross`/`VectMagnitude` (if so, the manual-arithmetic versions here are
  functionally fine but partially redundant);
- whether an FSM's `Init` state genuinely executes its `init` code in the same frame
  `execFSM` is called, with the `execFSM` argument bound to `_this` inside that state (the
  premise `Common_DelaylessCall.sqf` is built on).

Mitigated by writing both as clean-room implementations that don't call any commands whose
existence is in question, and by having `Common_UtilLibSelfTest.sqf` (flag-gated, default off)
empirically MEASURE the delayless same-frame behavior via global marker variables rather than
asserting it, logging the result to RPT. **Next agent/owner should**: arm
`WFBE_C_UTIL_LIB_SELFTEST=1` on a real server once, read the RPT for the
`DELAYLESS same-frame=...` line, and only then treat `Common_DelaylessCall` as safe to adopt on
a real hot path in a follow-up PR. See `docs/design/SQF-UTIL-LIB.md` for the full writeup.

### Review-fix pass (same day, before PR)

A second reviewer flagged two issues against the above; both verified against A2 SQF semantics
and fixed:

1. **MAJOR, confirmed — `Common_VectElevationSolve.sqf` sentinel collision.** The original `-1`
   failure sentinel is itself an ordinary, in-range low-arc angle (e.g. `[200, -23.117, 100]`
   solves to `theta ~ -1.000`), so a caller checking `_theta > -1` per the documented contract
   would wrongly treat a real solution as "unreachable." Fixed by moving the sentinel to `-999`,
   which sits outside `atan`'s valid `(-90,90)` output range and can never collide with a real
   result. Updated the function header, `docs/design/SQF-UTIL-LIB.md`, and the one self-test
   assertion that referenced the old sentinel (`Common_UtilLibSelfTest.sqf`).
2. **minor, confirmed — `Common_VectLeadAngle.sqf` under-length `_targetVel`.** If a caller ever
   passes a `_targetVel` with fewer dimensions than `_targetPos`, the old loop's
   `_targetVel select _i` goes out of range on the last axis; per this repo's own verified A2
   trap (a failed statement doesn't abort the script, it's skipped — see
   `a2-failed-statement-continues.md`), that silently left a hole in the returned `_aimPoint`
   instead of erroring loudly. Currently unreachable (zero call sites) but cheap to harden: the
   loop now defaults any missing `_targetVel` component to `0` instead of indexing out of range,
   and the header documents the same-dimensionality expectation.

Both fixes are additive/defensive only — behavior for well-formed same-dimensionality inputs is
unchanged. Re-verified after the fix: lint gate clean (zero findings in touched files), net
bracket delta zero per file, LoadoutManager mirror re-run clean across CH/TK/ZG (byte-identical
diffs across all three terrains), `version.sqf.template` untouched by the regen this time,
`Test-WaspVersionTemplates.ps1` all PASS.

Rejected: none — both review findings were confirmed against source and fixed.

**Wave reconcile 2026-08-03** (worktree `C:\tmp\reconwt3\pr2033`, branch `recon3/pr2033-20260803`,
supersedes PR #2033): merged cleanly onto `origin/update/wave-20260802`. Collision check requested
by the reconcile task — searched the wave for any existing `WFBE_CO_FNC_Hash*`, `WFBE_CO_FNC_Vect*`,
`WFBE_CO_FNC_DelaylessCall`, `Common_UtilLibSelfTest`, or `WFBE_C_UTIL_LIB_SELFTEST` symbols and any
`Common_Hash*`/`Common_Vect*`/`Common_Delayless*`/`delayless.fsm` files already in the wave: none
found, so no rename-collision to resolve. All new function/FSM files (all 3 terrains) applied with
zero conflicts. `Init_Common.sqf` (all 3 terrains) auto-merged cleanly — the wave has not touched
that registration region since this PR's base commit. Only conflicts were the same append-only
collision shape as the #1912/#1915 reconcile above: `Init_CommonConstants.sqf` (all 3 terrains, this
PR's `WFBE_C_UTIL_LIB_SELFTEST` flag registration landing at the same end-of-file anchor as several
other wave PRs' flag blocks — combined, no logic change to any of them) and this JOURNAL.md file.
Note for the owner: this PR's own PR body/header comments assert "A2 OA has no native `surfaceNormal`"
as the reason for `Common_VectSurfaceNormal.sqf`'s manual `getTerrainHeightASL`-sampling
reimplementation — that claim does not hold up against this repo's own code: `surfaceNormal` is
called natively and extensively elsewhere in the wave (`Common_RunCommanderTeam.sqf`,
`Client_BuildUnit.sqf`, `AI_Commander_Base.sqf`, `Server_Oilfields.sqf`, `Init_CommonConstants.sqf`
comments). Not a naming collision (no function shares the `surfaceNormal` name) and not fixed in this
reconcile since `Common_VectSurfaceNormal` has zero call sites (inert, additive-only) — flagged here
so a future adopting PR reaches for the native command instead of this library function.

---

## Working State 2026-08-01 — crash 014EFCF4 crew-delete sweep [fix/014e-crew-delete-sweep-20260801]

Task: sweep the remaining direct crew-delete sites for crash 014EFCF4 (deleteVehicle on a Man still
seated in a live/crewed hull, racing the engine's own seat-array move-out math — register-level
proven, memory `wasp-crash-014efcf4-mechanism.md`, 2026-07-31). Shipped mitigations before this task:
seated-corpse defer in `Common_TrashObject.sqf` and the inline `{deleteVehicle _x; sleep 0} forEach
(crew _h)` fix in `AI_Commander_AirResp.sqf` (left untouched — already correct, out of this task's scope).

**New helper**: `Common/Functions/Common_SafeCrewDelete.sqf`, registered as `WFBE_CO_FNC_SafeCrewDelete`
in `Common/Init/Init_Common.sqf`. Called `[_hull, _alsoDeleteHull] Spawn WFBE_CO_FNC_SafeCrewDelete`.
Spawn always creates a fresh SCHEDULED thread, so `sleep` is legal even when the call site itself is
unscheduled (Compile-Call'd function, or an FSM-adjacent .sqf) — lets one helper serve every caller
without duplicating the fix. Diag_log telemetry tagged `WASPCRASH014E|SWEEP` mirrors the seat-state
shape already proven in `Common_TrashObject.sqf`'s `WASPCRASH014E|TRASH` line.

**Classification used per site** (`grep -rn -i "forEach (crew"` across the CH mission, plus a second
pass for the no-parens `forEach crew` idiom): (a) skipped if the block doesn't actually deleteVehicle
a crew Man (several matches were doMove/reveal/dismount/counting only — not touched); (b) FIRE-AND-
FORGET (nothing downstream depends on the crew/hull already being gone) → replaced with the Spawn
helper; (c) ORDER-DEPENDENT (an immediately-following `deleteGroup`, or a `units _grp` sweep, assumes
the crew is already removed from the group) → kept the existing synchronous shape and inserted inline
`sleep 0` between deletes (matches the already-shipped AirResp pattern) rather than deferring async,
since deferring would let a later `units`-based delete in the SAME routine hit the crash again via a
different code path; (d) all Client/* sites skipped untouched (crash is server-side only).

**Fire-and-forget → Spawn helper (3 sites)**: `AI_Commander_BaseSell.sqf:143`, `Support_ScudStrike.sqf:218`,
`server_town_ai.sqf:194` (FSM-adjacent/unscheduled — Spawn is what makes this one safe at all).

**Order-dependent → inline `sleep 0` (27 sites)**: `AI_Commander_Wildcard.sqf` (941, 1186),
`AI_Commander_Wildcard_GUER.sqf` (174, 540, 544, 555, 560, 683), `Server_PatrolAirPass.sqf:106`,
`Init_NavalHVT.sqf` (154, 1207, 1208, 1211, 1212, 1213, 1215, 1216), `Server_AicomSupplySquad.sqf:95`,
`Server_GuerAirDef.sqf` (346, 392, 400), `Server_USVFlotilla.sqf` (243, 244),
`Support_GuerHeliDrop.sqf:280`, `Support_CargoAirdrop.sqf` (344, 351), `Support_Paratroopers.sqf:213`.

**Not a delete (skipped)**: `Common_AICOMAirLeg.sqf` (doMove only), `Common_FireArtillery.sqf` (getOut
action only), `Common_LogVehDelete.sqf` (string building only), `Common_RunCommanderTeam.sqf:3098,3133`
(unassignVehicle/doMove dismount only, no delete), `AI_Commander_AirStrike.sqf:308` (reveal/doTarget/
doFire only), `AI_Commander_MHQReloc.sqf:250` (isPlayer read-only), `Server_CmdSupportAir.sqf:131`
(reveal only), `server_town.sqf:889` and `Server_Oilfields.sqf:728` (counting only).

**Verification done**: lint gate (`Tools/Lint/check_sqf.py` full --select list) — zero new findings in
any edited/new file. Net bracket delta (`{}`/`[]`/`()`) verified zero per edited file against HEAD.
Correctness fix, no flag gate needed per repo convention. LoadoutManager mirror run clean (`dotnet run
-c RELEASE`), TK/ZG version.sqf.template restored + spot-verified (WF_MAXPLAYERS/STARTING_DISTANCE/
IS_CHERNARUS_MAP_DEPENDENT/IS_NAVAL_MAP all correct per-map). TK/ZG mirrors of `Common_SafeCrewDelete.sqf`
byte-diffed identical to CH source, CRLF-clean.

**Discovered issue (not part of this sweep)**: another concurrent session briefly ran a bulk inline-
`sleep 0` pass over the same 8 files in this shared (non-worktree) checkout before standing down in
my favor — no data was lost (it self-reverted before I re-applied), but it's a live reminder this repo
root is shared by multiple concurrent agents; worktree isolation is safer for any future sweep like this.

## Working State 2026-07-28 ~12:15 — m0728e CUTOVER IN FLIGHT (owner GO "deploy autonomously", changelog DM'd first per order)

- **Deploy**: 26-PR update packed from tip `2d1c6a3263` (3 PBOs, read_pbo 939/939 byte-identical), staged to box `C:\WASP\staging-m0728e`, one-shot schtask `WaspCutoverM0728e` FIRED ~12:10 CEST. Cutover script = m0728c clone MINUS bounce2hc (it re-broke HC1 seating) + allocator check at end. Server+HC launchers now `-malloc=system` (owner order; server was mimalloc, HCs tbb — both switched, .pre-sysmalloc.bak backups on box).
- **Owner live report during boot**: "HC 1 = in blufor slot..." → after CUTOVER DONE: probe seating (`hcreg-probe.ps1`), if bad → run `bounce2hc.ps1` ON-DEMAND via schtask /IT, re-probe. Monitor log: `C:\WASP\cutover-m0728e.log`, watcher `watch-cutover.ps1`.
- **C9 picker results (owner)**: GO+quick-wins (SHIPPED #1574: S22 Reserve Guard armed, S21 4th gun, R1 17-obj checkpoint default-ON). Approved for NEXT cycle: wall V5 pass S1-S9, GUER Flaktower 3-way skin parity, rigid-pin flag-off, tower split (S12/S14/S19 first, S17 first-cut). PARKED (not approved): S23 earn-back, R4-R6 GUER cards.
- **Verification owed post-boot**: build=m0728e in RPT, 2 HCs seated right, alloc-modcheck shows NO malloc module (=system heap), then first-hour watch: PATROLAIR|, AICOMSUPPLY|, USVFLOTILLA|GATE, RESERVEGUARD|v1, dispatched: counts in cleaner_droppeditems, carrier seam -252, gear charges. Verification DM after.

## Working State 2026-07-28 morning (superseded — update shipped as m0728e)

- **Branch:** `release/wasp-aicom-recovery-20260727`, tip after PR #1570 (`fcf588d0e8`). LIVE = m0728c; pending update = **22 PRs** since. Standing rule (owner 08:14): keep building, no server update.
- **Shipped this stretch:** #1567 gear money fix (post-cap charge inside changed-gate + GUER depot target parity), #1568 Ka-137 threat-only spawns + variant re-weight (MI24 .40 / DROP .25 / SWARM .25), #1569 USV player-audience gate (PLAYER_GATE=1, 1500m), #1570 carrier INLINE_GAP -265→-252 (**previous TWIN_GAP 42→32→26 tunes were a DEAD knob — INLINE_HULLS=1 skips the lateral path**) + deck respawn +2→+0.5.
- **Owner queue (open):** (1) AICOM small supply squad once truck/heli unlock gates reached — supply-mechanics scout running; **note: "AI supply trucks" do-not-re-propose entry SUPERSEDED by explicit owner order 2026-07-28**. (2) Patrol tiers reimagine: REMOVE money+SV rewards (definite), T3-4 air-unit idea incl. off-map entry (design options) — ground-truth scout running. (3) PVF-drop-class hunt scout running. (4) C9: 8 decision points DM'd to owner (SYNTHESIS.md in `_council_overnight\c9-defense-compositions\`), awaiting sign-off. (5) C10 wildcard council queued — GT-DRONE-SWARM.md archived in `_council_overnight\c10-wildcard-overhaul\` (verdict: no AICOM drone-swarm exists; KA-137 swarm was cap-starved, unblocked by #1568; wildcard COST=8000+HUMAN_BUY=0 means human-commanded sides get NO draws).
- **Peach DM sender:** `C:\Users\Game\send-peach-dm.ps1` VANISHED again; rebuilt 2026-07-28 from memory recipe (port 5001, X-Ops-Key from bot .env, UTF-8 bytes). Local copy in session scratchpad.
- **Runtime re-tests owed next build:** carrier seam at -252 + no spawn drop, gear overcharge/no-op charge, GUER depot gear target, Ka-137 threat-only + variant mix + KA137_SWARM lines, USV gate open/close, FOB scroll, VBIED reward, twin seam markers, air store after flip, runway spawn, lockpick, town air rearm, Towns button, deck/T4 UIs.

## 2026-07-07 — RC29 doubled player-arrow dedupe [fable/rc29-doubled-arrow]

Task: FIX doubled player arrow on the map (two mil_arrow2 markers track the player).

Root-cause confirmed by reading `Client/FSM/updateteamsmarkers.sqf` in full: two markers draw at
the player's position when the player leads a team —
(A) the per-team leader marker `%1AdvancedSquad%2Marker` (isPlayer branch, `player == _leader` ->
ColorOrange, alpha 1), and (B) the cmdcon26 own-arrow `%1AdvancedSquadOWNMarker` (always drawn from
the local `player` handle). Both are `mil_arrow2`. While `WFBE_C_TEAMMARKER_DEST_DIR` was 0, both
used plain `getDir` facing and silently overlapped. Once flipped to 1 (live), (A)'s destination
bearing comes from `expectedDestination _leader` only, while (B)'s comes from a 3-source priority
(stored map order -> group waypoint -> expectedDestination) — different computed bearing -> the two
arrows visibly split.

Fix: suppress (A) for the exact team the player leads by forcing `_markerAlpha = 0` right after it
is set to 1 in the isPlayer branch (`if (player == _leader) then {_markerAlpha = 0};`), leaving (B)
OWNMarker as the single visible self-arrow. Chose to keep (B) because it is the more robust source
(cmdcon26 fixed OWNMarker specifically to survive broken/late-JIP `clientTeams` group refs, and its
destination-bearing has richer priority). Other teams (AI-led or led by OTHER human players) are
untouched — the `player == _leader` guard only matches the local player's own led team; a
non-leading player never trips it either.

Discovered issue (documented, not fixed — out of scope, flag-gated and off by default): the combat
"blink icon red on fire" feature (`WFBE_C_MAP_ICON_BLINKING_ENABLED`, default 0) points
`unitMarkerBlink` at marker (A) for team leaders. If a player who leads a team fires while that flag
is ever turned on, the existing blink-on-fire indicator for their own marker becomes invisible (still
functions correctly for AI-led and other-player-led teams). Flagging for owner review; a follow-up
would redirect `unitMarkerBlink` to the OWNMarker when `_leader == player`.

Verification: targeted Python byte-edit (CRLF preserved, no BOM, single exact match, net `{}`/`[]`
delta 0 in all three terrains vs `origin/claude/build84-cmdcon36`), `check_sqf.py` lint gate run with
the full selector list — zero findings in `updateteamsmarkers.sqf` across CH/TK/ZG (repo-wide finding
count identical before/after: 204), LoadoutManager mirror run (`A2WASP_SKIP_ZIP=1`) then
`--check` reported zero drift, `version.sqf.template` restored to merge-base for TK/ZG (no drift to
restore — already clean), `Test-WaspVersionTemplates.ps1` all PASS, per-map spot-check confirmed
(TK `WF_MAXPLAYERS 61`/`STARTING_DISTANCE 7500`, ZG `WF_MAXPLAYERS 61`/`STARTING_DISTANCE 5000`), no
`_MISSIONS.7z`/`nul`/line-ending-churn staged. Static validation only — no live/box runtime test
performed (owner constraint: never deploy/restart/pack the live server or HCs).

## 2026-07-03 — Fleet lane 376: AICOM top-up request TTL

Added a default-on stale-request guard for `wfbe_aicom_topup_req` across Chernarus plus maintained
Takistan/Zargabad mirrors. Producers now publish `[count, pos, classes, issuedTime]`, the commander
team driver stamps legacy 3-slot requests once, and deferred requests older than
`WFBE_C_AICOM_TOPUP_REQ_TTL` (default 300s) are cleared so the server can re-evaluate instead of
keeping a player-proximity-deferred request forever.

Also cleaned an inherited two-argument group `getVariable` in the same driver file while it was in
scope, using the repo's plain-get plus `isNil` pattern. Verification: LoadoutManager mirror with
`A2WASP_SKIP_ZIP=1`, focused SQF lint zero findings, `git diff --check` clean except CRLF warnings,
NUL/backtick-zero scan clean, delimiter deltas paired, no `_MISSIONS.7z` artifact, and SHA256 parity
matched for the four touched SQF paths across Chernarus, Takistan and Zargabad.

## 2026-07-02 — Lane 180 ambient skirmish cells [codex/180-ambient-skirmish-cells]

Added a default-off server worker, `Server_AmbientSkirmish.sqf`, mirrored to Chernarus,
Takistan, and Zargabad. Gate: `WFBE_C_AMBIENT_SKIRMISH = 0` by default. When enabled, it waits
for towns, requires at least one human player, finds a water-free position outside configured
player/town radii, spawns one small WEST/EAST foot clash through `WFBE_CO_FNC_CreateGroup` and
`WFBE_CO_FNC_CreateUnit`, and self-cleans the groups after `WFBE_C_AMBIENT_SKIRMISH_LIFETIME`.

Scope deliberately stays out of AICOM, town, supply, score, and victory systems. Verification:
LoadoutManager mirror with `A2WASP_SKIP_ZIP=1`, identical worker hashes across all three maintained
roots, focused SQF lint zero findings, cached diff checks clean, and no `_MISSIONS.7z` artifact.

## 2026-07-02 — Lane 49 client RPT error-family audit [codex/lane49-client-rpt-error-family-audit]

Audited the current client RPT sample at `C:\Users\Game\wasp-rpt-reap\client-main.rpt` plus the
brain/wiki RPT routing notes. Most raw error volume is optional-addon noise (`JSRS_Distance` and
`warfxpe`), while several scary mission families in the sample are already fixed in current source
by cmdcon42 skin-selector and respawn-menu guards.

Shipped three tiny source guards that still mapped to maintained source: `Client_TipRotation.sqf`
now type-checks tip master/cadence values and feature gates before numeric compares;
`Init_TownMode.sqf` waits for `WFBE_Parameters_Ready` to exist before reading it; and `CM_Set.sqf`
accepts the object payload used by the current `(_unit) execVM` call sites instead of assuming an
array payload. Chernarus was edited first and mirrored to maintained Takistan through
`Tools\LoadoutManager`.

Verification: `A2WASP_SKIP_ZIP=1 dotnet run -c Release`, `A2WASP_SKIP_ZIP=1 dotnet run -c Release -- --check`,
`git diff --check`, `git diff --cached --check`, and an A3-command scan over the touched files.

## 2026-07-03 — Lane 138 RequestCommanderVote shape guard [codex/lane138-request-commander-vote-shape-guard]

Added a narrow server-side malformed-payload guard for `RequestCommanderVote.sqf`: reject non-array payloads, short arrays, non-side side fields, sides outside `WFBE_PRESENTSIDES`, non-string names and null side logic before the existing vote restart code indexes or broadcasts. Honest `[sideJoined, name player]` vote-restart behavior is unchanged; vote-resolution semantics and requester authority migration remain separate commander-owner work.

## 2026-07-02 — GUER naked spawn on Takistan + rifle-less GUER buy menu [claude/guer-gear-fixes]

Two GUER player-side gear bugs, fixed in two commits:

**Naked spawn (no gear, no ItemMap = black map), Takistan.** Both maps' `mission.sqm` use the SAME
Chernarus classnames for the playable GUER slots (`GUE_Soldier_Medic` / `GUE_Soldier_Sab` x2 /
`GUE_Soldier_Sniper`), but `Skill_Init.sqf`'s worldName branch registered only `TK_GUE_*_EP1` on
Takistan, so `playerType` matched no `WFBE_SK_V_*` list -> `WFBE_SK_V_Type=""` -> empty role loadout
-> `EquipUnit` stripped the player. Same failure shape as the 2026-06-18 GUER-MAPFIX, other map.
Fix: register BOTH class sets on both maps (membership lookups, extras harmless), plus defense in
depth in `Init_Client.sqf` / `Client_OnRespawnHandler.sqf`: nil/empty role gear now falls back to the
faction-wide `WFBE_%1_DefaultGear` with an always-on RPT WARNING instead of equipping from nothing.

**Rifles missing from the GUER gear buy menu (both maps).** GUER has no upgrade system —
`GetSideUpgrades` returns a zero array — so `Client_UI_Gear_FillList.sqf`'s
`(_get select 3) <= _upgrade_level` filter permanently hid everything above gear tier 0. Weapon
metadata is first-wins per classname (`Config_Weapons.sqf`) and Gear_US/Gear_TKA load before
Gear_GUE, so even the rifles Gear_GUE prices at tier 0 (AK_47_M etc.) carry TKA's tier >= 1: at
level 0 GUER saw only RPG18/Makarov/revolver/binocs/items — zero rifles. Fix: for the playable GUER
side (resistance + `WFBE_C_GUER_PLAYERSIDE > 0`) treat the gear tier as unlocked in FillList,
FillTemplates, AddTemplate and SaveTemplateProfile — the curated Loadout_GUE/TKGUE list and prices
remain the actual gate. WEST/EAST behavior unchanged.

Verification: static SQF review (A2-OA-safe constructs only) + `dotnet run` in `Tools/LoadoutManager`
regenerated the Takistan mirror both commits (7-Zip absent -> packing skipped, mirror OK). RPT
confirmables: the new WARNING lines fire if any role gear is still missing; GUER gear menu should now
list rifles on both maps.

## 2026-06-28 — PR #119 low-id CIV HC slot magnet [PR]

PR #119 now layers the static lobby-slot experiment on top of the runtime HC CIV hardening. The two
plain CIV HC slots were moved to the lowest object ids (`0`, `1`) and `forceHeadlessClient=1` was
removed so A2-OA's `-client` auto-seat has normal playable CIV slots to choose before WEST id `229`.
The displaced non-playable LOGIC objects formerly using ids `0` and `1` were moved to unused high ids
`9007` and `9008`; they had no `synchronizations[]` back-references.

Smoke verdict still needs the live engine: success is both HCs logging `HCSIDE|v1|preseat|...|engineSide=CIV`.
If preseat remains WEST, the static lobby-label fix is refuted, but the runtime reseat/owner-keyed
registration from PR #118 still protects gameplay-side behavior.

## 2026-06-28 — HC CIV slotting hardening [PR]

Root cause is no longer "missing CIV HC slots": `origin/master` already has two CIV `forceHeadlessClient=1`
slots plus the B761/B762/B763 enrollment/vote fixes. The remaining failure surface is boot/restart timing:
HC-local reseat used mission `time`/`sleep`, server registration gave owner resolution only 3 seconds, and
the HC registry was keyed by UID even though A2 HCs may report empty/colliding UIDs.

Patch on `codex/hc-civ-slotting-live`:
- `Headless/Init/Init_HC.sqf`: use `diag_tickTime`/`uiSleep` for reseat deadlines, mark the pre-reseat
  magnet group, and briefly reannounce `connected-hc` after cold start.
- `Server/Functions/Server_HandleSpecial.sqf`: wait longer for owner, require server-observed CIV before
  registry capture, key/de-dupe HCs by owner ID, and prune HC magnet groups even when UID is empty.
- `Server/Functions/Server_OnPlayerDisconnected.sqf`: clean HC registry by owner for UID-empty HCs before
  the human disconnect path.

Verification: `dotnet run` in `Tools/LoadoutManager` regenerated Takistan and packed `_MISSIONS.7z`;
the touched Chernarus/Takistan files hash-match; `git diff --check` has no whitespace errors beyond the
repo's existing CRLF warnings.

## 2026-06-20 — JOIN SAGA: definitive root causes + fixes (B54/B56) [INCIDENT / POSTMORTEM — CORRECTS THE B49 ENTRY BELOW]

**READ THIS FIRST — it supersedes the 2026-06-19 B49 entry below.** The 2026-06-19 postmortem credited
a "45s fade watchdog" (B49) with fixing the join. **It did not.** That watchdog SILENTLY FAILED, and the
all-day black-screen-on-join was actually a **STACK of four distinct bugs**, each of which had to be peeled
off in order. The de-slot (#1 below) was necessary but not sufficient; the build kept failing the join
even after it. Here is the full, corrected record.

### The bug stack (fixed in order)

1. **Null-player "shell" slots in `mission.sqm` (the trap the B49 entry found).** The GUER 27→14 de-slot
   left 26 dead slots (13 WEST + 13 EAST) — `deleteVehicle this` leftovers — still listed in the
   `LocationLogicOwnerWest` / `LocationLogicOwnerEast` (ids 255/256) `synchronizations[]` rosters. In
   Warfare the units synced to the Owner logic *are* the side's playable roster, so the lobby kept offering
   all 27 slots/side. A JIP client that landed on a shell slot ran `deleteVehicle this` → **`player == objNull`**
   → stuck. **Fix:** de-slot them (drop the 26 ids from the two Owner-logic `synchronizations[]` lists and
   clear the shells' own back-reference sync). NECESSARY but NOT SUFFICIENT — the join still failed after this.

2. **JIP network DELIVERY stall — `basic.cfg` `MaxSizeGuaranteed`.** `MaxSizeGuaranteed=1024` fragmented
   guaranteed JIP messages above the MTU → the join state never landed; the server reported **199,511
   "pending" messages**. **Fix:** lower `MaxSizeGuaranteed` to **512** so guaranteed JIP messages fit a
   single datagram. CRITICAL: `basic.cfg` is **box-only and unversioned** — it lives on the server, not in
   the repo. *This is why every git rollback "never helped":* the network-delivery half of the failure was
   not in source control and no commit could touch it.

3. **The `sleep`-vs-`uiSleep` trap (why the B49/B52/B53 watchdogs silently failed).** The B49 "45s fade
   watchdog" and the B52/B53 fade-clear retries all gated on `sleep` / `waitUntil` / mission-`time`. **All
   three are PAUSED while a client sits on the loading screen** (the sim clock does not advance for a client
   still receiving the mission), so the watchdog's gate never opened and the screen-clear **never ran — with
   no error, hence "silently failed."** The B49 entry below credited a fix that physically could not execute
   on the stuck client. **Fix (B54):** clear the black fade layer **12452** with an **ungated `uiSleep`**
   loop — `uiSleep` runs on real wall-clock time and ticks even while the sim is paused. Necessary, still
   not sufficient on its own.

4. **THE definitive cause — un-timed `waitUntil` on JIP-synced team data in client bootstrap (B56).** Found
   only by reading the **joining player's CLIENT RPT** (not the server RPT). `initJIPCompatible.sqf` client-init
   Part II ran, for **every** side in `WFBE_PRESENTSIDES`, an **un-timed**
   `waitUntil {!isNil {_logik getVariable "wfbe_teams"}}` **BEFORE** `execVM "Client\Init\Init_Client.sqf"`
   (which holds the fade-clear). With GUER playable, the harass-only resistance side's logic **never resolves
   `wfbe_teams` on a JIP client**: `Init_Server` registers teams only for `[east, west]`; GUER is a separate
   gated block keyed on `WFBE_L_GUE`, and the rest of the codebase already excludes resistance everywhere via
   the `WFBE_PRESENTSIDES - [resistance]` idiom. So once GUER was a present side, **every JIP joiner blocked
   on that `waitUntil` forever** → `Init_Client.sqf` (and its fade-clear) **never ran** → permanent black.
   This is why #1–#3 each looked like progress but the join still died. **Fix (B56):** bound those waits with
   `uiSleep`-counter timeouts so client init **always** reaches `Init_Client` even if a side's teams never
   resolve. In `Missions\[55-2hc]warfarev2_073v48co.chernarus\initJIPCompatible.sqf` (~lines 265–287):
   - `while {(isNil "WFBE_PRESENTSIDES") && (_w < 80)} do { uiSleep 0.25; _w = _w + 1; };` (≤20s)
   - per-side `while {(isNil {_logik getVariable "wfbe_teams"}) && (_ws < 120)} do { uiSleep 0.25; _ws = _ws + 1; };` (≤30s)
   - falls through to `execVM "Client\Init\Init_Client.sqf";` unconditionally, with a `[WFBE][B56 JIP-FIX]`
     diag_log if `WFBE_PRESENTSIDES` was never set in time.

### Delivery
Shipped as a **fresh-named single `.pbo`** — both a cache-bust (returning players re-download cleanly instead
of reusing a stale local copy) and a clean transfer to the box.

### Lessons (the expensive ones)
- **Server boot-smoke is structurally BLIND to the JIP client path.** HCs are box-local with no real network
  hop, so they don't exercise guaranteed-message fragmentation or the client-side `waitUntil`. The server RPT
  looked healthy the whole time. **Only the joining player's CLIENT RPT revealed bug #4.** Always pull the
  failing client's RPT for a join failure — the server's is not enough.
- **A2 LESSON (permanent-black landmine):** *any* un-timed `waitUntil` on JIP-synced data in the client
  bootstrap is a permanent-black trap. **Bound it with a `uiSleep` counter.** `sleep` / `waitUntil` /
  mission-`time` are **paused on the loading screen**; only `uiSleep` (real wall-clock) ticks while the sim
  is paused — so any "rescue/watchdog" timer in the client bootstrap MUST use `uiSleep`, never `sleep`/`time`.
- **Part of the failure lived OUTSIDE git** (`basic.cfg`, box-only). When git rollbacks "do nothing,"
  suspect unversioned box-side config, not just stale source.
- The 2026-06-19 entry's lesson "roll FORWARD to the fix" was directionally right, but the specific fix it
  named (B49 watchdog) was a no-op on the stuck client. The real fixes were B54 (`uiSleep` fade-clear) and
  **B56** (bounded client-bootstrap waits) plus the box-side `basic.cfg` change.

Touched/relevant files: `Missions\[55-2hc]warfarev2_073v48co.chernarus\initJIPCompatible.sqf` (B56 bounded
waits, ~265–287), `...\Client\Init\Init_Client.sqf` + the 12452 layer (B54 `uiSleep` fade-clear),
`...\mission.sqm` (#1 de-slot of the 26 shell slots), and the **box-only** `basic.cfg` (`MaxSizeGuaranteed
1024→512`, not in repo).

---

## 2026-06-20 — B57 — AICOM massive update [WORKING STATE / DEPLOYED]

**Deployed as `[55-2hc]warfarev2_073v48co_b57.chernarus` (Chernarus).** Boot-smoke clean; runtime-confirmed:
founding-pad logs *"B57 padded infantry team to floor (8 units)"*, **0 runtime errors**, **FPS 47 @ AI=84**.
Server-side only; A2-OA-1.64-safe throughout (no `pushBack`/`isEqualType`/`isEqualTo`; `+_template` copies,
`getDir`, `typeName ==`). Towns kept HARD by design — the AI overcomes them via **bigger + more concentrated
teams**, not softened garrison/capture rates.

### Centrepiece: LARGER AI-commander groups (the "thin team" fix)
- **Root cause.** Live teams are HC-founded at raw template size (3–6) and **never refilled**:
  `AI_Commander_Produce.sqf` (~line 63) skips `wfbe_aicom_hc` teams — which are **100% of live teams**
  (`CMDRSTAT srvTeams=0`). So the `WFBE_C_AICOM_TEAM_SIZE_MIN=8` floor and the deficit-fill logic inside
  Produce are on a **DEAD path** (they only fire for server-local teams, of which there are none in this build).
- **Fix.** Pad infantry/mixed templates up to the floor (8–12) **AT FOUNDING**, in
  `AI_Commander_Teams.sqf` (~lines 279–306, right after the template pick): find the team's `"Man"` class,
  `_template = +_template` (copy so the shared template isn't mutated), then append that class until
  `count _template >= WFBE_C_AICOM_TEAM_SIZE_MIN`. **Skips MBT and attack-heli templates** (the vehicle is the
  punch; no infantry floor). Logs `B57 padded infantry team to floor (N units)`.

### Constants (`Common\Init\Init_CommonConstants.sqf`)
- `WFBE_C_AICOM_TEAMS_PC_LOW` **5 → 10** (line ~139) — max HQ teams/side at low pop; pairs with the
  founding-pad so ~10 teams found at 8–12 each. ~10×8=80/side, under `TOTAL_AI_MAX` 130 (watch server FPS).
- `WFBE_C_AICOM_CONCENTRATION` **4 → 6** (line ~198) — more teams massed on the primary spearhead.
- `WFBE_C_AICOM_ASSAULT_REACH_FOOT` **3500 → 3000** (line ~335) — keeps thin foot teams on adjacent reachable
  towns; cuts long death-marches, tighter contiguous front.
- `WFBE_C_ECONOMY_SUPPLY_INCOME_MULT = 0.35` (line ~364) — throttles long-term town SUPPLY income (buildings/
  upgrades pace). Applied at `Server\FSM\updateresources.sqf` line ~76 (only when `_currency_system == 0`).
  **Cash/funds and the starting-supply seed are UNCHANGED** (Ray's split: cash = units, supply = buildings+upgrades).
- (Note: the inline rationale comment on `TEAMS_PC_LOW` references "CONCENTRATION=4" in its prose — stale
  comment text; the **active** value is 6.)

### Adopted from `feat/aicom-fleet-improvements` (commit `cc5090be`), graded for legacy-fit + A2-safe
- **Retreat-and-Reform** — `AI_Commander_Produce.sqf`.
- **Last-Stand + HQ-strike → 8-towns gate + persisted `wfbe_aicom_strat_mode`** — `AI_Commander_Strategy.sqf`.
  **DELETED** the branch's call to the non-existent `WFBE_CO_FNC_RadioMessage` (would have errored on legacy).
- **HC cold-start retry** — `Server_HandleSpecial`.
- **Town-defender skill spread** — `Common_CreateTownUnits`.
- **Snappier team loop** — `Common_RunCommanderTeam`: arrival = capture-range; poll **20s → 8s**.
- **Dead-patrol-marker scrub** — `server_side_patrols`.
- **`[AICOM BOOT]` / `[BRIEF]` telemetry** — `AI_Commander.sqf`.

### Deliberately SKIPPED from that branch (would regress legacy)
- Its `initJIPCompatible` + `Init_Towns` (carry the `sleep`-trap — see the join saga above; legacy already
  has the `uiSleep`-bounded B56 version).
- `Client_HandlePVF` / `Server_HandlePVF` (deployed already has the CODE-guarded version).
- `Init_CommonConstants` color change (would clobber the GUER 3-branch colors).

### Other B57 changes
- **Player map-marker direction fix** — `Client\FSM\updateteamsmarkers.sqf` (~line 208): the team marker used
  the **velocity vector** (direction of *travel*), so the arrow pointed wrong when a unit strafed/slid. Now
  `_dir = getDir _leaderVehicle` (`vehicle _leader`), correct on foot **and** mounted; matches the patrol/AICOM
  arrow loops. A2-OA-safe.
- **Lobby slot reorder** — grouped by **real role** per side. Classnames are misleading (`*_TL`/`*_CO` are
  Engineers/Support per the slot *description*, not team-leaders/commanders). New order:
  **Medic → Engineer → Support → Rifleman → Sniper**. Verified a **pure permutation** (ids, syncs, items,
  braces all unchanged); the HC-parking CIV slots stay pinned.
- **HQ start-variety** — `WFBE_C_BASE_STARTING_MODE` is already `2` (random) (line ~287), but A2's `random`
  is **deterministic on a fresh dedicated-server process** → the same start every match. Fixed with a
  per-match RNG perturbation in `Init_Server` (inside the `_use_random` block), seeded by a
  `profileNamespace` counter so each match seeds differently.

### Touched files
`Server\AI\Commander\AI_Commander_Teams.sqf` (founding-pad), `...\AI_Commander_Produce.sqf` (Retreat-and-Reform),
`...\AI_Commander_Strategy.sqf` (Last-Stand / HQ-strike / strat_mode), `...\AI_Commander.sqf` (telemetry),
`Common\Init\Init_CommonConstants.sqf` (constants), `Server\FSM\updateresources.sqf` (supply mult),
`Client\FSM\updateteamsmarkers.sqf` (marker dir), `Server\Init\Init_Server.sqf` (start-variety RNG),
`Server_HandleSpecial` / `Common_CreateTownUnits` / `Common_RunCommanderTeam` / `server_side_patrols`
(adopted helpers), `mission.sqm` (slot reorder).

---

## 2026-06-19 — Join failure ("Receiving mission") — root cause + fixes [INCIDENT / POSTMORTEM]
> **SUPERSEDED — see the 2026-06-20 "JOIN SAGA" entry above.** This entry's central claim (that the B49
> "45s fade watchdog" fixed the join) is WRONG: that watchdog gated on `sleep`/`time`, which are paused on
> the loading screen, so it silently never ran. The de-slot below was necessary but not sufficient; the
> definitive fixes were B54 (`uiSleep` fade-clear), B56 (bounded client-bootstrap `waitUntil`s), and a
> box-only `basic.cfg` `MaxSizeGuaranteed` 1024→512. Kept verbatim below for the historical record.

**SYMPTOM.** Multiple players could not join the live Chernarus server: clients hung on
"Receiving mission" / a permanent black screen and never finished loading. **Not load-related** —
the server had been running fine under heavy AI (had soaked at ~600 AI without trouble). The failure
was state/slot/timing dependent (it got more likely as lobby slots churned over a session), not
correlated with player count or AI count.

**ROOT CAUSE (high confidence — multi-agent RCA, confirmed in code + git).** Two things combined:

1. **The deployed build was PRE-B49** and therefore lacked the join-robustness null-guard.
2. **The Chernarus `mission.sqm` still offered ~26 dead "shell" lobby slots** (13 WEST + 13 EAST) —
   leftovers of the GUER 27→14 de-slot (`sqm_cut.py`). That script removed `player="PLAY CDG"` from
   13 units/side and appended `removeAllWeapons this; deleteVehicle this` to each, **but left all 27
   ids/side synchronized to `LocationLogicOwnerWest/East`.** In Warfare, the units synced to the Owner
   logic *are* the side's playable roster, so the lobby kept offering all 27 slots/side.

   A JIP client that landed on one of these shell slots ran `deleteVehicle this` → **`player == objNull`**.
   In the pre-B49 `Init_Client.sqf`, the very first real statement (`sideJoined = side player;`) on a
   null player silently broke the entire client init. That meant the **BLACK FADED fade** opened in
   `initJIPCompatible.sqf` (`12452 cutText [..., "BLACK FADED", 50000];`, ~50000s ≈ 13.9h) was **never
   cleared** by the normal "BLACK IN" at the end of `Init_Client` → permanent black / stuck on
   "Receiving mission."

**FIX (shipped).** Two layers, both now on `claude/deslot-shellslots` (HEAD `b27c5c9e`):

- **Roll FORWARD to the B49 join-robustness** (commit `f4308e6d`), which the bad build predated:
  - `Client/Init/Init_Client.sqf`: a **45s fade watchdog** — `waitUntil { clientInitComplete ||
    (time - _t0 > 45) }`, then `12452 cutText ["", "BLACK IN", 1]` so a stalled client clears the
    screen instead of staring at black; **plus** `if (isNull player) exitWith {...}` *before* the
    `side player` call, so a null-player join bails gracefully instead of breaking init.
  - `Server/Functions/Server_OnPlayerConnected.sqf`: `!isNull _x` guard in the team-lookup loop.
  - **Deployed commit `1e023fa0`** (`Revert "feat(B50): server-ready gate…"`) as the live HEAD —
    it contains the B49 robustness without the B50 gate (see lessons).
- **Proper hardening — remove the trap at the source** (commit `b27c5c9e`): drop the 26 shell ids
  (13W+13E) from the two Owner LOGIC `synchronizations[]` lists (27→14 ids each) and clear the shells'
  own back-reference sync. The empty self-deleting groups are left in place (no Unit class removed, no
  `items=` recount → low-risk, no renumber), but the engine no longer enumerates them as side slots,
  so **the lobby never offers a null-player trap again.**

**WRONG TURNS / REFUTED HYPOTHESES (the "other stuff found").** Before the real cause was nailed,
several theories were chased and then **disproven**:
- mission name / cache collision,
- heavy-AI JIP overload,
- a ~10× server restart loop,
- object-ID exhaustion,
- convoy-truck (vehicle) leaks,
- the B50 server-ready gate.

Several of these came from a **stale / secondhand server log that did not match the live RPT** — the
live RPT was actually healthy. Time was lost analyzing the wrong window.

**LESSONS (read before debugging the next join failure):**
1. **Triage on the failing-window RPT, not a stale or secondhand one.** A healthy live RPT next to a
   scary old log = the old log is the red herring. Confirm the timestamps match the incident window.
2. **When the failure is a recently-FIXED regression, roll FORWARD to the fix — do NOT roll back to an
   older "known-good" that predates it.** Repeatedly restoring pre-B49 builds *made it worse* (each
   restore re-introduced the missing null-guard).
3. **Deploy a single coherent commit, not ad-hoc overlays onto stale on-disk files.** The live HEAD is
   `1e023fa0`; know exactly what commit is running.
4. **Don't hold client init behind a server-ready gate.** The B50 server-ready gate (`ede75180`)
   caused deadspawn deaths and was reverted (`1e023fa0`). Client init must not block on server state.
5. **Don't rename the live public mission.** Renaming invalidates the local cache of every returning
   player (they re-download → look like new "Receiving mission" stalls). Keep the public mission name stable.
6. **The box has scheduled tasks that can auto-redeploy / rename the mission** — these were disabled
   during the incident so they couldn't silently overwrite the fix or churn the mission name. Re-check
   them before declaring the box stable.

Touched/relevant files: `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Init/Init_Client.sqf`,
`.../initJIPCompatible.sqf`, `.../Server/Functions/Server_OnPlayerConnected.sqf`, `.../mission.sqm`.
Key commits: `f4308e6d` (B49 robustness), `ede75180`→`1e023fa0` (B50 gate added then reverted, = deployed HEAD),
`b27c5c9e` (de-slot the 26 shell slots).

---

## 2026-06-15 — Group-budget hygiene: 3 code extras (slot cut CANCELLED) [WORKING STATE]

**Decision (Steff, 2026-06-15): SKIP the 27→21 editor player-slot cut.** Reason: the deep research
concluded the cut buys **zero FPS** (empty persistent slot-groups cost nothing on the hot path) and
only frees headroom on WEST/EAST — which sit at ~42-45/144 even at full pop and are nowhere near the
cap. The real budget pressure is GUER's dynamic groups, which the slot cut does not touch. The
mission.sqm surgery (delete + renumber 100+ items across Chernarus AND Takistan) is high-risk for no
gain. **mission.sqm left UNTOUCHED** (Chernarus Groups.items stays 129; HEAD `80e38a423`).

Proceeding with the 3 genuinely-useful code extras (Chernarus source; Takistan inherits via the
`SERVER_DEBUG` regen at deploy time — do NOT hand-edit Takistan):

1. **[~] Cap aicom extra teams at 2** — `Common/Init/Init_CommonConstants.sqf` add
   `WFBE_C_AI_COMMANDER_TEAMS_MAX_EXTRA = 2;` after line 122. Confirmed `AI_Commander_Teams.sqf:60`
   reads this var with an inline fallback of 4; the constant did not exist in Init_CommonConstants.
   Caps late-game dynamic AI teams at base+2 (=6) instead of base+4 (=8) → saves up to 2 groups/side.
2. **[~] GUER group monitor** — `Server/FSM/server_groupsGC.sqf`. GUER's real ceiling is the SOFT cap
   `WFBE_C_GUER_GROUPS_MAX` (=60, recently 90→60), NOT 144 — at the soft cap `server_town_ai.sqf:62`
   DEFERS garrisons (town defense degrades). Add (a) a `GUERCAP|v1|count|max|pct` telemetry line at
   the 60s GCSTAT cadence for the dashboard gauge, and (b) a debounced (5-min) WARNING when
   `_cntGuer >= 90% of WFBE_C_GUER_GROUPS_MAX`. Distinct from the existing 130/144 engine-cap warning.
3. **[~] Untagged-leak diagnostic** — `server_groupsGC.sqf` audit loop. Now that editor slots are
   tagged `editor-player-slot` and all wrapper spawns are tagged, a NON-empty `untagged` group =
   a raw createGroup that bypassed the wrapper = real leak. Fold into the existing forEach allGroups
   audit loop (no extra pass): count non-empty untagged groups per side where side != sideEmpty,
   emit `UNTAGLEAK|v1|west|east|guer|samples` + debounced WARNING (warmup >600s).

**Also (Steff 2026-06-15): GUER soft cap raised 60 → 80** (`WFBE_C_GUER_GROUPS_MAX`) — more garrison
headroom above the ~73 peak, still well under 144; the new monitor watches it.

**STATUS: all 4 changes implemented + verified.** The three `[~]` above are DONE plus the GUER-cap bump.
- **Lint-A2Compat: PASS** (0 FAIL; the 4 REVIEWs are pre-existing find-quote in `AI_Commander_Base.sqf`).
- **Adversarial review (3 lenses: A2-runtime / logic+false-positive / integration): PASS** — 0 runtime
  blockers, 0 logic blockers. Two non-blocking fixes applied: (a) `server_groupsGC.sqf:304` dropped a
  redundant `str` (samples already strings — was double-quoting); (b) `SkinSelector_Apply.sqf:83` tag
  now broadcasts (`,true`) so the server audit can actually see `skin-swap`. The lone "blocker" was the
  known Takistan regen step (`dotnet run` syncs the stale Takistan copies), already in the deploy checklist.
- Touched files: `Init_CommonConstants.sqf` (2 lines), `server_groupsGC.sqf`, `SkinSelector_Apply.sqf`.

Remaining: commit to `deploy/2026-06-12-aicom-experital` (**hold push for Steff's consent**).

### Discovered issues (off-scope) — Workstream B (dashboard, box-side)
- **EMPTYGRP telemetry is silently dead in the dashboard.** `server_groupsGC.sqf` emits `EMPTYGRP|v1|`
  but `C:\WASP\Update-PublicStats.ps1` parses for `GRPEMPTY|v1|` (prefix mismatch). Pre-existing, not
  from this diff. One-line regex fix on the box. Same pass could teach the parser the new `GUERCAP|v1|`
  (GUER soft-cap gauge) and `UNTAGLEAK|v1|` (leak counter) lines — the "deeper per-faction info" Steff asked for.

---

## 2026-06-15 — Staged-deployment items (Discord deploy thread)

Source: OCD deploy-planning thread (Marty / Zwanon / Net_2). Scope = 4 items + a Miksuu-site dashboard view.

### Findings (verified 2026-06-15)
- **Group GC suite ALREADY on this branch** and committed: `server_groupsGC.sqf` (full + throttled),
  `Client/Functions/Client_GroupsGC.sqf` per-HC sweep wired at `Headless/Init/Init_HC.sqf:139`,
  `Common/Functions/Common_CreateGroup.sqf` registered at `Common/Init/Init_Common.sqf:111`.
- **Deploy branch is NEWER than Marty's live box** (`a2wasp-grpleak/_boxlive`): branch adds `GCSTAT|v1`
  per-pass line + D2 audit-every-N server-FPS throttle (`WFBE_C_GROUPAUDIT_EVERY`) + persistent-empty
  tracking. Box has a `dgEmpty` (defense-gunners) sub-metric the branch lacks. → DO NOT overwrite with
  box (would drop the throttle). Optional: graft the `dgEmpty` sub-metric only.
- **logcontent**: `LOG_CONTENT_STATE` is driven by `#define WF_LOG_CONTENT` in `version.sqf`
  (`initJIPCompatible.sqf:4-13`). `version.sqf` is absent from source (build-generated) → currently
  "NOT ACTIVATED" for server/clients; HCs force ACTIVATED at runtime (`initJIPCompatible.sqf:60`).
- **No client→server FPS telemetry** exists. `Common_PerformanceAudit.sqf` logs each machine's own
  `diag_fps` to its own RPT only (gated by `WFBE_C_PERFORMANCE_AUDIT_ENABLED`).

### Plan / progress
- [x] **FPS telemetry** (Chernarus). New `Client/Functions/Client_FpsReport.sqf` (player-only sampler,
      avg+min over 5×1s, staggered, self-gated on `WFBE_C_CLIENT_FPS_REPORT`); spawned from
      `Client/Init/Init_Client.sqf` tail; server PV receiver `WFBE_FPS_REPORT` in `Server/Init/Init_Server.sqf`
      (after Group-GC spawn) → `diag_log "FPSREPORT|v1|uid|fps|fpsMin|players|dnMode|daytime|sun|srvFps|t|name"`;
      two lobby params in `Rsc/Parameters.hpp` (`WFBE_C_CLIENT_FPS_REPORT` 0/1 def 0, `..._INTERVAL` def 60s).
      Lint-A2Compat: **PASS, 0 FAIL** (4 pre-existing REVIEWs in AI_Commander_Base, not mine).
- [x] **logcontent (#4)** = BUILD CONFIG, not a source edit. `version.sqf` is gitignored + generated by
      LoadoutManager; `BaseTerrain.cs:386` emits active `#define WF_LOG_CONTENT` for `SERVER_DEBUG`/
      `AIRWAR_SERVER_DEBUG`. → **Pack the staged release with `dotnet run -c SERVER_DEBUG`** (from
      `Tools/LoadoutManager`) and logcontent is ON for every map. No committable file. (Marty's own note
      at `BaseTerrain.cs:343`: changing the value alone does nothing — the line must be uncommented, which
      the SERVER_DEBUG config does.)
- [x] **Group GC (#1/#2)** already on branch + AHEAD of Marty's box (server throttle). Per-HC reaper present.
      Did NOT re-port (would regress). Optional `dgEmpty` graft: SKIPPED (don't destabilise throttled audit).
- [~] **Takistan / modded maps**: DEFERRED to deploy build. Takistan on this branch is STALE vs Chernarus
      (missing per-HC GC exec, deadspawn-safety, PickLeastLoadedHC, egress gate, restart/dashboard/playerstat
      emitters, FPS-profiling, empty-veh-timeout tune — all unrelated to this work). `SERVER_DEBUG` regen
      reproduces ALL of it from Chernarus at build time. Do NOT hand-mirror; do NOT sweep a catch-up regen
      into this feature commit.
- [ ] Commit Chernarus on `deploy/2026-06-12-aicom-experital` — **hold push for Steff's consent**.

### Discovered issues (off-scope)
- Takistan (`Missions_Vanilla/[61-2hc]...takistan`) is well behind Chernarus on this branch — needs a full
  `SERVER_DEBUG` regen before any release cut, independent of the FPS work.

### Workstream B (Hetzner live-stats dashboard) — CORRECTED TARGET + ACCESS
- **NOT the Miksuu Next.js site, NOT dashboard-v4.** It's the bespoke live-stats SPA at
  **http://78.46.107.142:8080/** ("Miksuu's Warfare — Live Server Stats"), served from the **Hetzner box**.
- **Access**: box = Windows, SSH/RDP as `Administrator` (Posh-SSH password auth from Main PC; key auth NOT
  set up). Scratch = `C:\WASP`. (pw in [[miksuu-hetzner-test-server]] memory.)
- **Source (box-only, NOT in any repo)** — pulled to `C:\Users\Steff\miksuu-dashboard-work\`:
  - `Serve-PublicStats.ps1` — HttpListener :8080 (http.sys → PID 4 System); serves whitelist from `C:\WASP\web`:
    index.html, stats.json, next-stats.json, next-changelog.json. Scheduled task `WaspStatsWeb` (ONSTART, SYSTEM).
  - `Update-PublicStats.ps1` (85 KB) — RPT parser + `stats.json` generator (parses AICOMSTAT/ORBATSTAT/DELEGSTAT/
    `group audit`/WASPSTAT). `-MissionLabel WASP|NEXT`.
  - `C:\WASP\web\index.html` (80 KB) — the front-end (tabs + JS), fed by `stats.json` (135 KB aggregate).
- **"the NEXT page" = the `NEXT / V2` tab** (dev diagnostic for the V2 branch; currently DOWN/NaN).
  index.html anchors: nav btn L185, panel `#tab-nextv2` L364-448, JS L1061-1229, `renderTab` L1254,
  fetches `/next-stats.json` + `/next-changelog.json`.
- **Plan (FULL, approved)**:
  1. Remove NEXT/V2 tab (nav+panel+JS+polling); drop `renderTab` nextv2 branch.
  2. Add "Force & Group Health" to Overview (after Order of Battle L255): per-side W/E/G group **n/144**
     cap gauge (amber≥130 red≥144) + empty/leaked groups (`GRPEMPTY`) + delegation% — the group-limitation
     analysis made public. Data already partly present (`c.groups.west/east/guer`, L843); add a
     `groupHealth` object to `Update-PublicStats.ps1` from `group audit [SIDE] N/144` + `GRPEMPTY|` parsing.
  3. Visuals/perf: favicon 404 fix; faction-gauge styling; audit Benchmarks/Balance/Top Players tabs.
  4. Later: surface client `FPSREPORT` (Workstream A) as a day-vs-night panel once it deploys.
- **Deploy**: zero game impact (web task only); back up index.html + Update-PublicStats.ps1 on box (.bak),
  push, restart `WaspStatsWeb`, verify live via browser. Respect [[hetzner-deploy-consent-policy]].
- **DEPLOYED & LIVE 2026-06-15** on the box (`C:\WASP\web\index.html` + `C:\WASP\Update-PublicStats.ps1`,
  `.bak-claude-*`/`.bak-v2pre-*` kept). NEXT/V2 tab removed; "Force & Group Health" live with real data
  (W/E/G n/144 gauges + GC footer reaped/emptyFound from `GCSTAT|v1|` 60s). Generator parse-checked +
  unit-tested; front-end validated headless (0 console errors). NOTE the ~2-min publish-delay buffer:
  a freshly-deployed field reads null for ~2-3 min before the buffer catches up (not a bug). Source +
  access documented in [[miksuu-live-stats-dashboard]] memory. Local working copy: `miksuu-dashboard-work/`.
- **STILL OPEN (part of "full plan")**: visuals/perf pass on the Benchmarks / Balance / Top Players tabs
  (only Overview + favicon done so far); and surfacing the Workstream-A client `FPSREPORT` as a
  day-vs-night panel once that mission build deploys to the live server.

---

## 2026-06-12 — Artillery Radar + Reserve buildable structures (WDDM integration)

Two new commander-buildable structures, mirroring the CBR/Bank pattern (cfc1fb93):

- **ArtilleryRadar** — `USMC_/RU_WarfareBArtilleryRadar` (CO) / `US_/TK_..._EP1` (OA).
  Cost 2400, MediumSite, dis 21, dir 90. Gate `WFBE_C_STRUCTURES_ARTILLERYRADAR = 1`.
- **Reserve** — `Land_Mil_Barracks_i` (CO) / `Land_Mil_Barracks_i_EP1` (OA — intact model
  inferred safe from the `Land_Mil_Barracks_i_ruins_EP1` WFBE_C_STRUCTURES_RUINS precedent).
  Cost 2000, MediumSite, dis 30 (walls reach ±24 m). Gate `WFBE_C_STRUCTURES_RESERVE = 1`.

Both use **MediumSite** → the standard phased construction animation path
(LocationLogicStart / WFBE_B_Completion), same as the factories — NOT preplaced.
Auto-walls fire from Construction_MediumSite (exclusion list untouched), pulling the
CHOSEN WDDM designs added to Init_Defenses.sqf:

- `WFBE_NEURODEF_ARTILLERYRADAR_WALLS` — "walled boom-gate checkpoint": HESCO 5x ring,
  3 m front gap, cones + danger sign; boom gate `Land_BarGate2` on A2/CO, jersey-block
  chicane fallback on OA standalone (BarGate is A2 content).
- `WFBE_NEURODEF_RESERVE_WALLS` — "floodlit walled yard": HESCO 10x yard, corner
  watchtowers (`Land_Fort_Watchtower[_EP1]` per content set), `Land_Ind_IlluminantTower`
  over the bays (confirmed both content sets via Core_CIV/Core_TKCIV).

Plumbing: RequestStructure allowed-list +2, marker labels ("AR"/"RES"),
Client_FNC_Special build-started cases, stringtable `RB_Artillery_Radar`/`RB_Reserve`,
shorthand vars `<side>ARTRAD`/`<side>RES`. Per-design intent: the Artillery Radar takes
fortifications only (walls, no gun defenses) — its template contains zero crewed weapons.

LoadoutManager run synced Takistan (7za pack step fails — documented-ignorable). NOTE:
the generator clobbers owner hand-edits in `EASA_Init.sqf` (re-adds stripped defaults,
54ad0732) and `Sounds\description.ext` (volumes 1→7) on the CHERNARUS side — those four
generated-file changes were reverted before commit; Takistan committed state already
matches generator output. Needs an in-engine build test of both structures.

---

## Task 28 — Port Patrols v2 at upgrade index 23 (2026-06-10)

WFBE_UP_PATROLS = 23 (CBR = 22 stays). All faction arrays grow to 24 entries.

PR #25 dependency check: server_side_patrols.sqf only needs WFBE_HEADLESSCLIENTS_ID
and HandleSpecial/RequestSpecial — both already present in experital pre-#25. No PR #25
symbols needed.

Old system retired: Init_Towns random flagging + server_town_ai spawn gate removed.
server_patrols.sqf / Server_GetTownPatrol.sqf left as dead code (same as master).

Group A (21 entries→24): RU, USMC, CDF, INS, OA_TKGUE, OA_US — add UNITCOST+CBR+Patrols padding
Group B (22 entries→24): OA_TKA — add CBR+Patrols padding
Group C (23 entries→24): CO_GUE, GUE, CO_RU, CO_US — add Patrols only

---

## 2026-06-10 — Investigation: BuyUnits dropdown forEach over `[objNull]` (GUI_Menu_BuyUnits.sqf)

**Question:** Did commit `c8071eeb` (airfield capture / Task 12) introduce a regression where the
factory-dropdown `forEach _sorted` at ~line 282 iterates `[objNull]` when no depot/airport is in range?

**Verdict: pre-existing since the original WFBE import — NO new regression.**

Evidence:
- `git log -L 250,290` on the file: the `_sorted = [[...] Call WFBE_CL_FNC_GetClosestDepot];`
  wrapping is unchanged context in `c8071eeb`; the commit only ADDED `_closest = _sorted select 0;`.
- Initial import `96809ac3` already has the identical wrap + the same `forEach _sorted`, and the
  Depot/Airport branches never set `_closest` (file-top init `_closest = objNull;`, line 8).
- `_sorted` was never carried over from the `default` factory branch — every switch branch always
  assigned it, including in the original code.
- `Client_GetClosestDepot.sqf` / `Client_GetClosestAirport.sqf` always return objNull-or-entity
  (init `_closest = objNull`, returned as last expression) — never nil, so the wrap is always a
  1-element array and `select 0` is safe.
- With `_x = objNull`: `Common_GetClosestEntity.sqf` returns objNull harmlessly (`distance` vs a
  null object = 1e10, never `< 100000`), then `objNull getVariable 'name'` → nil → the `_txt`
  concatenation on line 280 errors → broken/missing dropdown entry + RPT "Undefined variable"
  spam. Same behavior before and after `c8071eeb`.
- `c8071eeb` actually FIXED a real carry-over bug: before it, on Depot/Airport tabs `_closest`
  kept its stale value (objNull init, last factory from the `default` branch, or the dropdown
  handler at line 191), so the queue display at line 290 could read the wrong object's "queu".
  Downstream is objNull-tolerant (`isNil '_queu'` guard, `getVariable` on objNull → nil).

### Discovered Issues (off-scope, optional hardening)
- Cosmetic, since 2010: opening the Depot/Airport tab with none in purchase range puts one broken
  entry / RPT error in the 12018 dropdown. Cheap fix if ever wanted:
  `if !(isNull (_sorted select 0)) then { ...forEach _sorted... }` around the lbClear/forEach
  block (or `lbAdd [12018, localize 'STR_...none-in-range']` in the else).

---

## 2026-07-02 — Fleet lane 157: end-of-round player summary

Claimed `fleet-lane-157-end-of-round-screen-2026-07-02` as `Codex-Fleet-11-loop`.

Scope kept to the endgame title and its client fill script:
- `Client/GUI/GUI_EndOfGameStats.sqf` now fills a local player summary row with score, funds, and income using existing client-visible values only.
- `Rsc/Titles.hpp` adds that summary row plus a small Close button that closes the current cut display.
- Takistan was mirrored through `Tools/LoadoutManager` with `A2WASP_SKIP_ZIP=1`.

Validation:
- `dotnet run -c Release` from `Tools/LoadoutManager` completed with packaging skipped.
- `git diff --check` clean except existing CRLF warnings.
- `check_sqf.py --select BRACKET` and `--select A3CMD` reported zero findings on the four touched files.
- Added-line A3/boolean trap scan found no matches.
- Chernarus/Takistan touched file pairs match after mirroring.

---

## 2026-07-03 - Fleet lane 338: skip top-up for disbanding HC teams

Claimed `fleet-lane-338-topup-skip-disbanding-teams-2026-07-03` as `Codex-Fleet-9`.

Scope:
- `AI_Commander_Produce.sqf` now reads `wfbe_aicom_disband` with the existing A2-safe group-var idiom before dispatching a town-center top-up request.
- Teams already queued for disband no longer receive replacement infantry and refit charges immediately before the HC driver deletes them.
- Vanilla mission roots are expected to be mirrored through `Tools/LoadoutManager` with packaging skipped.

---

## 2026-07-03 — Fleet lane 356: bootstrap stipend windfall telemetry

Claimed `fleet-lane-356-bootstrap-stipend-windfall-telemetry-2026-07-03` as `Codex-Fleet-9`.

Scope:
- Keep bootstrap stipend behavior unchanged while aligning the first-grant sentinel and guard in `AI_Commander.sqf`.
- Add `AICOMSTAT|v2|EVENT|...|BOOTSTRAP_STIPEND_WINDFALL` telemetry when a delayed stipend tick grants more than two minutes of catch-up income.
- Mirror maintained Vanilla Takistan/Zargabad through `Tools\LoadoutManager` after the Chernarus source edit.

---

## 2026-07-03 - Fleet lane 248: AICOM spectator RHUD row

Claimed `fleet-lane-248-aicom-intent-spectator-rhud-2026-07-03` as `Codex-Fleet-9-loop` on current Build84 `4910fc3f5`.

Scope:
- `Client_UpdateRHUD.sqf` now keeps the AI commander name + intent row visible for dead/spectator clients whose live player/group side is null or transient civilian, using the stable `WFBE_Client_SideID`.
- Added `WFBE_C_AICOM_INTENT_SPECTATOR` default 1; setting it to 0 restores the legacy spectator fallback while leaving normal WEST/EAST RHUD behavior unchanged.
- Mirrored maintained Takistan/Zargabad through `Tools\LoadoutManager` with `A2WASP_SKIP_ZIP=1`; no package artifact, no deploy, no AICOM behavior change.

Validation:
- Focused SQF lint over the six touched files reported 0 findings.
- Full repo SQF trap gate still reports pre-existing unrelated findings outside this lane.
- Diff checks, delimiter deltas, conflict-marker/NUL/backtick-zero scans, added-line trap scan, HUD SHA256 mirror parity, and constant flag presence checks passed.

---

## 2026-07-02 — Codex fleet lane 30: performance-audit probe extensions

Claimed `fleet-lane-30-performance-audit-probe-extensions-2026-07-02` from the game-PC brain.

Scope stayed observation-only and complementary to the older side-patrol probe work:
- `AI_Commander_Teams.sqf`: add `aicom_teams_found` `PerformanceAudit_Record` row after a successful HC/server-local founding pass with team/pending/target/template/cost/world-count context.
- `AI_Commander_Strategy.sqf`: add `aicom_strategy` row after a full strategy pass with town, target, posture, strike, strength, garrison-body, and front-state context.
- `Server_GuerAirDef.sqf`: add `guer_airdef_cycle` row per maintain cycle with before/after air/drop registry sizes and marker/cap context.

Chernarus source was edited first, then mirrored to vanilla Takistan with `A2WASP_SKIP_ZIP=1 dotnet run -c Release`.
Validation so far: LoadoutManager mirror completed and packaging was skipped; `dotnet run -c Release -- --check` reported no generated drift; `git diff --check` only emitted expected CRLF warnings; SQF lint `BRACKET` and `A3CMD` found 0 issues on the six touched mission files; added-line A3/Boolean trap scan had no matches; Chernarus/Takistan touched file pairs matched after newline normalization; no `_MISSIONS.7z` artifact was created.

---

## 2026-07-17 — wasp-tonight-fix-20260717: pre-playtest bughunt fixes

Fleet card `wasp-tonight-fix-20260717`, agent `claude-wasp-tonightfix-20260717`. Worktree
`C:\Users\Steff\wasp-tonight-fix-20260717` (branch `wasp-tonight-fix-20260717`, off
`origin/master` 8092c6b80f). Public playtest tonight on build `v2armed-20260717`. Draft PR +
staged PBO only, no deploy.

### Confirmed bughunt fixes (5)

1. **HIGH — wildcard cost unaffordable.** `Init_CommonConstants.sqf:616`
   `WFBE_C_AI_COMMANDER_WILDCARD_COST` 150000 -> 8000 (matches the inline comment's own
   "Intended live value 8000 (Ray 2026-07-07)"; AI commander funds pool runs ~30-60k so 150k
   silently disabled all 17 wildcard cards).
2. **HIGH — GUER player kills double-paid bounty.** `RequestOnUnitKilled.sqf` ~173: added
   `&& {!(isPlayer (leader _killer_group))}` to the GUER-bounty block so a player-led GUER kill
   pays only the normal player-bounty path (~line 393-400), not both.
3. **HIGH — vehicle kill-assist double/triple-paid.** `RequestOnUnitKilled.sqf` ~402-413: added
   an `_assistCreditedGroups` de-dup array so a same-squad vehicle crew (one wallet, multiple
   crewmates) is credited once per group, not once per surviving crewmate.
4. **HIGH — HC merge/topup flags are inert no-ops.** `Init_CommonConstants.sqf:1362-1363`:
   `WFBE_C_AICOM_HC_MERGE_ENABLE` and `WFBE_C_AICOM_HC_TOPUP_ENABLE` reverted 1->0. Both only
   ever call `WFBE_SE_FNC_AI_Com_HCTopUp` (`AI_Commander.sqf:572`, nil-guarded), which is never
   compiled/registered anywhere in the tree (`grep` confirmed only the 3 mirrored call sites,
   no `= Compile ...` registration). Arming either flag does nothing; not safe to implement the
   missing worker tonight, so reverted to the actually-inert default.
5. **MEDIUM — GUER group-cap stale count.** `server_town_ai.sqf` ~331 (right after the town
   ACTIVATED log line): added `if (_side == resistance) then { _guerGroupCount = _guerGroupCount
   + (count _groups) };`, mirroring the existing `_activeTownCount = _activeTownCount + 1`
   live-increment pattern at ~line 279 so groups spawned earlier in the same sweep count against
   the cap for towns processed later in that same sweep.

### Owner live-observation diagnoses

- **B — deadspawn at team HQ instead of offshore (CONFIRMED + FIXED).** `Client/Init/Init_Client.sqf`
  ~70-76 called `[] call WFBE_CO_FNC_DeadspawnPenPos`, a function registered by `Init_Common.sqf`
  which is `ExecVM`'d asynchronously at `initJIPCompatible.sqf:350`, ~36 lines before
  `Init_Client.sqf` is *also* `ExecVM`'d at line 386 — two independent async threads with no
  ordering guarantee. When `Init_Client.sqf` reaches the positioning line before `Init_Common.sqf`
  has registered the function, `WFBE_CO_FNC_DeadspawnPenPos` is still nil, `call` on it throws an
  Undefined-variable error, `setPos` gets no argument, and the player is left at the default MP
  join position (team HQ area) — exactly the report. Fixed by compiling
  `Common_DeadspawnPenPos.sqf` inline (`[] call Compile preprocessFile
  "Common\Functions\Common_DeadspawnPenPos.sqf"`) instead of depending on the async registration,
  matching the race-safe idiom the ELSE branch one line below already uses for the legacy marker
  path (its own comment: "Common is not yet init'd so we call is straight away").
- **A — second unit joins player's group on spawn** and **C — orange dots / missing HQ TEAM
  marker** — delegated to a read-only Explore subagent for independent investigation; see its
  findings folded into the PR body / final report (not duplicated here to avoid drift between two
  written copies of the same conclusion).

### Coordinator-added scope: FPV drone regression (SAFE FALLBACK applied, not root-caused)

Owner report mid-task: FPV drone spawns mid-air, player cannot take control, drone falls and
self-detonates. Traced the control-handoff path: `fpv_interface.sqf` (which does the actual
`player remoteControl _driver`) only runs if `fpv.sqf`'s purchase-status poll resolves to
`_purchaseStatus == 1`. `Support_FPV.sqf:308-318` has a 1-second `_seatDeadline` waitUntil for
server-side pilot-seating replication to confirm — under real multi-player network conditions
(vs. solo dev testing) this can plausibly deny with "FPV pilot seating did not replicate to the
server." Separately, PR #1096 (`3b60ffceb9`, merged 2026-07-16 18:43) tightened the drone's
`Killed` EH to require a capability-token match before requesting server detonation. The drone
stays `wfbe_fpv_armed = true` for its entire uncontrolled fall (that flag is only cleared inside
`fpv_interface.sqf`, which never launched), so the crash still detonates it. This spans a
multi-file purchase-authority race that predates today's PR interacting with today's tightened
detonation binding — not confidently isolated to one low-risk line change under tonight's time
pressure. Applied the instructed SAFE FALLBACK instead: flipped `WFBE_C_FPV_DRONE` default 1->0
in both `Rsc/Parameters.hpp` (lobby param, which wins live) and `Init_CommonConstants.sqf` (was
already drifted 1 vs. its own "0=off (default)" comment — fixed the drift in the same edit).
Feature off restores pre-#1096 player experience for tonight; full diagnosis is an open item for
the owner.

### Gates

- `python Tools/Lint/check_sqf.py --select ... --no-classname-index`: only pre-existing baseline
  findings in touched files (6 `A3MARKER` hits in `Init_Client.sqf`, line-shifted by +11 from my
  insertion, verified identical against the `origin/master` baseline at the pre-shift line
  numbers — zero new findings).
- Bracket delta: all 5 Chernarus files (+ matching TK/ZG mirrors) net curly/square delta = 0
  vs. `origin/master`.
- Mirror: `A2WASP_SKIP_ZIP=1 dotnet run -c RELEASE` completed for CH/TK/ZG; `-- --check` reports
  "drift: none" for both TK and ZG; `version.sqf.template` restored to merge-base on both;
  `Test-WaspVersionTemplates.ps1` all PASS.
- `git status`: exactly 5 Chernarus source files + their TK/ZG mirror counterparts (15 files
  total), no `_MISSIONS.7z`, no `nul` artifact, no line-ending-churn files.

### Discovered issues (out of scope, flagged not fixed)

- `Support_FPV.sqf:308-318`'s 1-second pilot-seating replication deadline is a pre-existing
  hazard independent of tonight's safe-fallback flag flip; may need a longer timeout or a retry
  instead of an outright deny under live network conditions. Left for a dedicated follow-up.
- Stray unmerged branch `codex/wildcard-deck-doc-reconcile` (no open PR attached) sets
  `WFBE_C_AI_COMMANDER_WILDCARD_COST` to `0` — conflicts with this PR's `150000 -> 8000` value if
  that branch is ever revived. Flagged in the PR body as a merge-collision risk; not blocking
  since it carries no open PR claim.

## 2026-07-25 - classgaps lane: GUER classname-list repairs

- Branch `codex/guer-classname-gaps-20260725` is based on the contested-file stack
  #1429 -> #1440 -> #1447 (`07756d4e23`).
- Confirmed and fixed G3 (GUER ambulances in the 2x empty-vehicle exemption), G4
  (map-specific `WFBE_GUERAMMOTRUCKS` registration), and G5 (Takistan oilfield
  engineer class). No audit item was skipped; dormant-root-only classes stayed out.
- Mirrors regenerated and checked clean; version-template invariants passed
  (CH 32, TK 31, ZG 33). `RESULT.md` is intentionally untracked.

## Working State — 2026-07-28 21:15 (burn window)
- LIVE: m0728h on Takistan (rotation TK>CH, Veteran). Release branch = m0728h + merged #1585 (deck header both-states + FPV tested-z), #1586+mirrors (board wait 30->12 WFBE_C_AICOM_BOARD_WAIT), #1587 (COIN diagnostics; placement-method default-case was DORMANT, real placement root cause still unknown - COINPLACE|v1 logs will name it).
- DRAFT awaiting owner: #1584 WEST jets (WFBE_C_AICOM_WEST_JETS=0).
- Lanes IN FLIGHT (worktrees wt-*): airlift-v2 (draft, AIRLIFT2|v1, flag WFBE_C_AICOM_AIRLIFT_V2=0), cmd-clipping (legacy bottom-row out-of-bounds fix), quickstart-v2 (HC-safe first order, draft, flag WFBE_C_AICOM_AIR_QUICKSTART=0; naive shape rejected - AssignTowns server-only + side-wide), bomb-stage-a (Server_BombProbe + runbook, WFBE_C_BOMB_PROBE=0), fpv-causation (FPVCAUSE|v1 log-only ledger), build-defense-audit (read-only, owner order "commander build menu, base defenses").
- Secondary box: WaspHcSlotTest schtask RUNNING as SYSTEM (the /IT interactive-only trap silently no-ran it twice - box has no interactive session; /RU SYSTEM fixed).
- Adversarial review verdicts already fixed: deck header dual-membership, FPV z discard. Deferred into airlift-v2: REQ diag_log outside gate.
- After lanes land: merge order = cmd-clipping, fpv-causation (non-draft) then mirror pass; drafts stay for owner/soak. Next build cut = m0728i on owner word or 06:00 restart.


## 2026-07-30 — Release/master reconciliation receipt

- The release-side journal above is retained in full. The `origin/master` journal was
  already the same prior history after omitting only two release-only 2026-07-28
  working-state blocks; no master-only journal entries were dropped by the merge.
- Master history source retained: `origin/master` at `a1f97cfdbb` (spectator recut merge).
- This receipt is the appended master-side reconciliation section for the
  `reconcile/release-plus-master-20260730` merge.

## 2026-07-30 — m0730g live: HC topology 2 CIV slots + spectator regression fixed

**Working state:** deploy lineage = worktree `.worktrees/grand-reconcile`, branch
`reconcile/release-plus-master-20260730` (pushed). Live CH rotation entry = m0730g.
Takistan m0730g staged + waiter task `WaspTkSwapM0730g` armed on the box (swaps the
rotation entry at the next stop window; log `C:\WASP	k-swap-m0730g.log`).

- HC lobby slots 4 -> 2 on all three terrains, CIV only. Takistan had four slots
  *labelled* "Headless Client" with `forceHeadlessClient` on **none** of them - that is
  the mechanism behind HCs appearing as BLUFOR/OPFOR (1.64 seats a connecting client into
  the lowest-id free playable slot, side-blind, honouring the flag only for a JIP into an
  already-live mission). `WFBE_C_HC_SLOTS` 4 -> 2; HC *name* exclusion list intentionally
  left as a 1..4 superset. `WaspHC3`/`WaspHC4` box tasks disabled.
  Verified live: `who="HC-AI-Control-1"` and `-2` both reporting, 45-46 fps.
- Spectator dead-on-m0730f root cause: **my own `disableSerialization`**. On OA 1.64 a
  script that calls it does not survive its first suspension (opposite of A3), so handler
  attach, movement loop and HUD never ran. Fixed by holding no Display in a local at all.
  Mouse model rewritten (steer every event, warp only near the UI edge), sens 45 -> 25.
- Spectator v3 director mode built on `fable/spectator-v3-director-20260730` (commit
  aa5a4fea03), flag `WFBE_C_SPECTATOR_DIRECTOR` default 0. Not in m0730g.

**Discovered issues:** Zargabad is not in the live rotation and was left unpacked (its
tree carries the 2-slot fix). `server-config/provision/Start-Wasp-4HC.ps1` documents an
`-HcCount` parameter it does not actually declare, and hardcodes `1..4` - would fail if
invoked as the README instructs.

---

## 2026-08-01 — Deadspawn AI holding relocated to underwater pen (draft PR #1807)

Owner ruling 2026-08-01: DEADSPAWNS AI holding too close to action, accumulates visible items/gear.

**Consumer audit result**: only `Server/AI/AI_SquadRespawn.sqf:31` + `Server/AI/AI_AdvancedRespawn.sqf:30`
park dead AI at `%1TempRespawnMarker` (NE hills, next to the DEADSPAWNS label at ~[15439,15237]).
Human joins already pen-parked (WFBE_C_DEADSPAWN_REDESIGN=1 live); HC bodies sea-park (ParkSeaHC).
DEADSPAWNS / "DEADSPAWNS, DO NOT ENTER!" label markers: ZERO script refs on CH/TK/ZG (verified per map;
TK/ZG each have the 3 TempRespawnMarkers too — earlier truncated grep suggested otherwise, wrong).

**Change** (branch `fable/deadspawn-ai-pen-20260801`, worktree C:/tmp/claudewt/deadspawn-ai-pen-20260801,
draft PR #1807): flag `WFBE_C_DEADSPAWN_AI_PEN` default 1 (Init_CommonConstants.sqf). Pen path parks via
`WFBE_CO_FNC_DeadspawnPenPos` (isNil-guarded fallback to legacy marker); captive+allowDamage hold FORCED
independent of WFBE_C_DEADSPAWN_GUARD (drowning = engine damage, blocked by allowDamage false); body
surfaced to z=0 on EVERY release path (normal/handoff/skip/null-respawnLoc) before damage returns.
Offmap force-kill (Client_HandleOnMap) is player-only AND pen is in-bounds by construction (same
WFBE_BOUNDARIESXY square as Client_IsOnMap).

**Deliberate non-change**: NO new litter janitor — `Server/FSM/cleaners/droppeditems_cleaner.sqf`
already sweeps weapon holders island-wide every ~10 min with locality-aware dispatch (non-local
deleteVehicle silently no-ops in A2; a naive janitor would re-hit that trap). Labels + markers stay
in mission.sqm (flag-0 fallback + engine respawn_* markers + DeadspawnWall).

**Gates**: lint 168→168 (0 new, 0 in edited files); bracket deltas balanced (asserted by patcher);
LoadoutManager mirrored CH→TK/ZG; TK/ZG version.sqf.template restored (31/7500, 33/5000). Peach+ DM sent.

**Discovered (not fixed, out of scope)**: GUER playable slots editor-start ON GuerTempRespawnMarker
(mission.sqm ~4990-5075) — transient at boot only. `_loadout` missing from AI_AdvancedRespawn.sqf
Private list (pre-existing).

**Update 2026-08-01 11:05**: owner order - #1807 marked READY (undrafted) + queued for next merge wave: appended to mission-core-r-series in WAVE-QUEUES.md (Fleet drop 20260801-035117-grok-main-07311829-night, n=26->27), PR comment posted, GitHub MERGEABLE. Peach+ DM sent.

---

## 2026-08-01 13:55 — m0801h6 fast lane COMPLETE: all 4 Codex-audited spectator/pen findings staged

Worktree C:/tmp/wasp-h, branch deploy/m0801h-20260801, tip 5fe1e4e300 (pushed).
Findings 1/2/4 were already in ca012abeaf (earlier session: CIV caster init repair, Labels_Upgrades
nil guards, POI-only auto director). This pass added finding 3 + director belt-and-braces
(commit 5fe1e4e300, rebased over fleet's 4e34650c8a arty-ring default-OFF which is included in the build):

- **AI_SquadRespawn.sqf / AI_AdvancedRespawn.sqf**: per-side pen ALWAYS (+200m/side ID, surfaceIsWater
  re-verified; dry/landlocked -> own side's TempRespawnMarker — kills the ZG sandhill mixed-side park);
  loadout stored on unit (`wfbe_penWeapons`/`wfbe_penMagazines`) + removeAllWeapons at guard park;
  restored on every release path (handoff restores before body handover; normal path restores before
  EquipUnit); null-respawnLoc routes to own side marker, never re-armed at the pen.
  AdvancedRespawn uses `((_side) Call GetSideID)` deliberately (_sideID there is pre-civilian-remap).
- **Client_SpectatorDirector.sqf**: DirectorContactCount = non-captive + armed + belligerent side only;
  fight-cluster collector excludes captive units.

**Gates**: lint 168->168 (0 new, 0 in edited files); per-patch brace/bracket deltas balanced;
mirrors CH->TK/ZG byte-identical; TK/ZG version.sqf.template restored (31/7500, 33/5000);
pack self-check OK all 3 maps.
**Staged** C:\WASP\staging-m0801h (via h6tmp + Copy-Item -LiteralPath), byte-verified:
CH 14,749,610 / TK 16,821,414 / ZG 16,770,056. Marker candidate=m0801h6-20260801|git=5fe1e4e300.
Live server NOT touched; owner fires WaspCutoverM0801h. Peach+ DM delivered (dm:8344...).

**Discovered (out of scope, NOT fixed)**: Common_DeadspawnPenPos.sqf boundary guard falls back to the
SEED it just rejected (lines 79-82) — on ZG the seed [10000,400] is beyond the ~6.4km terrain, so the
HUMAN join pen (WFBE_C_DEADSPAWN_REDESIGN) still resolves off-map/dry there (AI no longer goes there
after this fix; offmap force-kill is player-scoped with a 50s timeout — worth a per-terrain seed or an
in-terrain clamp in the v6 rework lane).


---

## 2026-08-01 ~16:00 - LIVE CRASH 15:37:23 root-caused + m0801i-crashfix staged (this session)

**Verdict: CONFIRMED recurrence of crash 014EFCF4 (register-proven). The h6 pen commit
5fe1e4e300 is EXONERATED - its code never executed in the crashed session.**

Evidence (arma2oaserver.RPT on the 4-HC box, crashed session = Takistan m0801h6,
t=0..5991s = 13:56 cutover -> 15:37 crash):
- Fault: `ACCESS_VIOLATION at 014EFCF4`, fault bytes `F3 0F 10 09 F3 0F 5C 08` - identical
  to the proven 07-31 mechanism. Registers: **ESI=41D16260 = tk_crew corpse 461863**.
- That corpse: 4x `Getting out while IsMoveOutInProgress` (t~5941-5988), then
  `GetOutAny ... already in landscape` ~8s before its GC delete at t=5991.56
  ("not server-local; dispatching the delete to its owner") - the last mission action
  before the fault block. Its two crew-mates (461860/461861) deleted seconds earlier.
- Pen commit: ZERO lines from AI_AdvancedRespawn / AI_SquadRespawn / DEADSPAWN_GUARD /
  DEADSPAWN_AI_PEN|park in the whole captured session (t=2451-5991). The crashed h6 build
  ALSO already contained the morning 23-site sweep (283c246495) - crash came through the
  one unswept path.

**Mechanism gap:** corpse was queued for trash while SEATED in its dead hull;
Common_TrashObject sleeps 60s; engine ejected the corpse during that sleep; post-sleep
seat check saw `vehicle == self` so the m0730n seated-corpse defer passed it to
deleteVehicle ~8s post-eject, while engine move-out bookkeeping still held the pointer.

**Fix (commit b3c0b14374 on deploy/m0801h-20260801, pushed):** Common_TrashObject.sqf -
stamp `wfbe_seatSeen` at queue time (pre-sleep) + at the seated-defer; if a stamped corpse
is UNSEATED at delete time, release it to the collector for one more cycle (>=60s) so the
delete clears the eject window; stamp cleared, next pass deletes normally. Unstamped
(infantry) corpses byte-identical path. Diag line gains `seatSeen=%7`.
Pen constant NOT flipped - task condition was "guilty or unclear"; it is neither.

Gates: lint 168->168 (0 in edited files), brackets 0-delta, mirrors byte-identical,
TK/ZG templates restored (31/7500, 33/5000).

**Staged (verified byte-identical local vs box C:\WASP\staging-m0801h):**
- [55-2hc]warfarev2_073v48co_m0801h.chernarus.pbo | 14742532
- [61-2hc]warfarev2_073v48co_m0801h.takistan.pbo  | 16814336
- [61-2hc]warfarev2_073v48co_m0801h.zargabad.pbo  | 16762978
Marker: `WASPRELEASE|v1|candidate=m0801i-crashfix-20260801|git=b3c0b14374`. Filenames stay
*_m0801h. Owner triggers the cutover (server auto-healed, currently re-running h6 -
same crash window re-arms ~100min into AI-heavy sessions until cutover).

Residual (not this crash, watch seatSeen diag): cold-wreck SEATED corpse deletes keep
today's behaviour; HC-side executor unchanged.


## 2026-08-02 22:30 NL - wave0802 DEPLOYED to the live box (176.9.104.115)

Owner instruction: "deploy + Play Zargabad > Chernarus > Takistan". Done and verified live.

VERIFIED LIVE at 22:47 NL (13:47 box, UTC-7):
  RPT: WASPRELEASE|v1|candidate=wave0802|git=update/wave-20260802|terrain=zargabad
  RPT: MISSINIT: missionName=[61] Miksuu's Warfare Zargabad
  A2S: map=zargabad  players=1/37   server fps ~45.5
  Rotation in effect: Zargabad -> Chernarus -> Takistan (owner order)

Build inputs:
  branch update/wave-20260802 @ 5f32327cdd, gates 605 pass / 13 fail (zero new vs master)
  PBO sha256 - ch 772ceed6..., tk 76438e98..., zg d204f4bf... (hash-matched on box)

THREE BLOCKERS HIT AND FIXED (all worth remembering):

1. pack_pbo.py WF_MAXPLAYERS guard aborted all three terrains. Cause: the untracked,
   generated version.sqf files carried FOLDER-LABEL numbers (55/61/61) while the guard
   computes human = total - headless - caster = 32/31/33, which is exactly what the
   tracked version.sqf.template files already said. Fix: regenerate version.sqf from
   version.sqf.template, as the template's own header instructs ("Copy to version.sqf
   at deploy time"), and stamp a fresh WF_RELEASE_MARKER. The stale marker had read
   candidate=build89-cmdcon44t-20260704 since July.

2. EDITED THE WRONG CFG - cost a live restart and one player's match.
   C:\WASP\server-pr8.cfg (root) is a STALE DECOY: it still read wave0722g / single
   Takistan / maxPlayers=56. The server reads ONLY the path in its own command line,
   -config=C:\WASP\profiles-pr8\server-pr8.cfg, which was already a 3-map m0801h
   rotation at 58. There is NO propagation between the copies, contrary to the repo
   header (now corrected in server-config/server-pr8.cfg). Always read the -config=
   path out of the RPT boot banner first.

3. The cfg is file-locked while arma2oaserver.exe runs. Correct order is: build and
   validate the new text while the server is still UP (fail fast, nothing touched) ->
   stop the chain -> write -> restart. Same as Deploy-Wasp.ps1 "BUG 1".

TOOLING HAZARD (not fixed, documented): Tools/Ops/Set-MissionTemplate.ps1 rewrites
EVERY matching `template = "...";` line to one mission name and only Write-Warnings on
>1 match (Set-MissionTemplate.ps1:89-98). Against a 3-map rotation cfg it collapses all
three entries into the same map. Deploy-Wasp.ps1 -Apply would therefore have destroyed
the rotation. The cfg was written as a whole block instead.

Also corrected a wrong belief of mine: the box DOES init the mission unattended. The
"empty box never starts the mission" note is wrong for this box - Start-Wasp-4HC.ps1
documents a measured 540-601s cold boot to MATCH|v1|START|, and the HC launch waits on
that marker (900s timeout, then a legacy 45s settle). That wait is why a restart looks
wedged for ~16 min with hc=0. It is not wedged.

Rollback ready if the 01:00 allocator bench turns up trouble:
  m0801h PBOs for all 3 terrains retained in MPMissions
  C:\WASP\profiles-pr8\server-pr8.cfg.bak-20260802-132922 (pre-deploy effective cfg)

RESOLVED 22:48 NL: HC2 seated - A2S players=2/37, both HCs connected. HC1 seated
clean too (HCSIDE|v1|reseat|result=done|sideNow=CIV). Full 2-HC topology restored; the
~17 min hc=0 window was the documented MATCH|v1|START| wait, not a failure.


## 2026-08-04 - Serial fold of 12 resolved wave0804 branches (worktree C:\tmp\fixwt\update0802)

Sole writer in this worktree. Folded exactly 12 `resolved/wave0804-NNNN` branches (each a
merge of old-wave-tip + PR head, pre-resolved and adversarially verified) into
`update/wave-20260802` with `git merge --no-ff`, in the deliberate dependency-safe order:
1607, 2082, 1615, 2097, 2061, 2071, 2078, 2084, 2093, 2098, 2100, 2101.
2060 and 2066 were explicitly excluded (superseded - their fixes already on tip).

### Per-branch merge result

| # | Result |
|---|---|
| 1607 | clean |
| 2082 | auto-merged clean (git's ort resolved Server_BuyUnit.sqf on its own); verified both #1607's `_tq` nil/array queue-release guard AND #2082's r127 wrong-victim-token fix survive at every queue-release site, CH+TK+ZG |
| 1615 | clean |
| 2097 | auto-merged clean (git's ort resolved server_town_ai.sqf on its own); verified #1615's hysteresis comment + `WFBE_C_TOWNS_DETECTION_RANGE_ACTIVE_COEF=1.25` AND #2097's GARRISON_CAP_DEFER/TOWN_AI_GROUP_CAP_DEFER activation-deferral both present, nil-safe `getVariable ["wfbe_active", false]` reads intact |
| 2061 | clean |
| 2071 | **hand-resolved** - real conflict in Init_CommonConstants.sqf (CH+TK+ZG): both HEAD (fortification placement/preview/facing constants block) and #2071 (bughunt r124 dead-guard constants block) appended new content at the same anchor. First byte-surgery attempt at C:\tmp\resolve_2071.py had a bug - naive `"=======\r\n"` search matched inside HEAD's own 86-`=`-char divider comment line instead of the real conflict separator, gluing the blocks together wrong. Caught before commit by reading the resolved region back; reset via `git checkout -m` to regenerate clean markers, rewrote the script to anchor the mid-marker search on `"\r\n=======\r\n"` (only matches a standalone marker line), re-ran, verified both blocks intact in order, bracket delta zero (pre-existing 203/202 `[`/`]` imbalance unchanged by the edit) |
| 2078 | clean |
| 2084 | auto-merged clean |
| 2093 | clean |
| 2098 | clean |
| 2100 | clean |
| 2101 | clean |

No real 7-char conflict markers anywhere post-fold (`git grep -nP "^<{7}(?!<)|^={7}(?!=)|^>{7}(?!>)" -- "*.sqf"` empty). The 13 pre-existing 8-char decorative banner files under Modded_Missions (AntiStackPreparation legacy merge artifacts) are unchanged and untouched by any of the 12 folds.

### Gate suite (all run after all 12 merges)

1. **LoadoutManager --check**: `Takistan drift: none`, `Zargabad drift: none`, exit 0. No drift despite the resolved branches predating the fortification mirror-state commits - the mirrors were already in sync going in.
2. **pytest Tools/**: first run 848 passed / 2 failed. Both diagnosed as gate-engineer calls, not merge breakage:
   - `test_town_defer_sideeffects.py::test_deferred_activation_skips_all_creation_side_effects` asserted `_activationDeferred = true;` count == 2 (implementation literal). Git-archaeology confirmed count was 2 immediately before #2097's merge and 4 immediately after (fold #2097 legitimately adds two new deferral gates, GARRISON_CAP_DEFER and TOWN_AI_GROUP_CAP_DEFER, ahead of the two pre-existing budget-defer sites) - all four still gate the same guard block with all required side effects intact. Realigned the assertion to 4 with an explanatory comment.
   - `test_veh_delete_probe.py::test_ratchet_manifest_matches_the_entire_tree` - the deleteVehicle inventory ratchet drifted on 2 files: `Server_OperateTownDefensesUnits.sqf` (5->6, #2084 adds an "operator" cleanup site mirroring the existing "gunner" cleanup, AI-only) and `Init_NavalHVT.sqf` (26->34, #2100 adds unmanned-aircraft CAP pilot-fallback deletes, AI-only). Both new sites keep `probed=0` consistent with the pre-existing convention in those files (probe is for player-vehicle-usage tracking only). Regenerated `vehdel_inventory.json` via a script matching the test's own computation; diffed to confirm only those two entries changed.
   Re-run after both fixes: **850 passed, 0 failed.**
3. **check_sqf.py lint gate** (exact command from CLAUDE.md, `--select A3CMD,A3HASH,A3MARKER,A3NUMGATE,A3PRIVATE,A3REVEAL,A3SELECT,A3SORT,A3STRING,BAREEXIT,BOOLCMP,BRACKET,DBLBOM,DEADNOQA,FLAGGATE,GROUPGETVAR,MILMARKER,NSSETVAR3,PUBVARSV,TRAILCOMMA --no-classname-index`): **168 findings, all A3MARKER, zero new** - cross-referenced the 168 finding files against the full list of 90 `.sqf` files touched across all 12 folds: zero overlap.
4. WF_MAXPLAYERS spot-check: all three `version.sqf.template` (CH/TK/ZG) still read `34`, untouched by any fold - matches this branch's own CLAUDE.md convention.
5. No `Co-Authored-By` trailer in any of the 14 new commits (12 merges + this gate-fix + journal commit).

### Commits added (old-wave-tip `c0135273` -> tip)

12 merge commits (`fold #NNNN into wave0804 (conflict-resolved)`), one gate-fix commit
(`b37f7008cf`, realigns the two contract tests above), this journal commit.

Pushed to `origin/update/wave-20260802`.
