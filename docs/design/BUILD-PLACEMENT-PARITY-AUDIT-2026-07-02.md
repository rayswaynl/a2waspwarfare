# Build Placement Parity Audit

Date: 2026-07-02
Lane: 46 - player build-placement parity
Branch: `codex/lane46-build-placement-parity-audit`
Base: `claude/build84-cmdcon36`

## Verdict

Lane 46 is partially implemented but intentionally default-disabled on the current target. No source
change is made in this audit.

The prompt row says the player CoIn build path lacks the water and `isFlatEmpty` slope validation used
by the AI path. Current source now contains that player-side validation hook and the CoIn placement
click is gated on a green preview. However, the shared `WFBE_C_STRUCTURES_FLAT_CHECK` flag defaults to
`0` because the earlier player flat-gate over-blocked placement on mountainous Takistan. Re-enabling
the gate should be an owner/test decision, not a blind docs-lane default flip.

## Evidence

- Chernarus/Takistan `Client/Init/Init_Client.sqf:1167-1178` define `WFBE_C_STRUCTURES_PLACEMENT_METHOD` and mark the preview red when `surfaceIsWater(position _preview)` is true.
- Chernarus/Takistan `Client/Init/Init_Client.sqf:1178` also runs an `isFlatEmpty` check for base structures when `WFBE_C_STRUCTURES_FLAT_CHECK > 0`, excluding the unfolded HQ preview.
- Chernarus/Takistan `Client/Module/CoIn/coin_interface.sqf:621-624` applies the placement method's returned color to the local preview and stores it as `BIS_COIN_color`.
- Chernarus/Takistan `Client/Module/CoIn/coin_interface.sqf:641` only places a structure when `_color == _colorGreen`, so red/gray preview states block the click path.
- Chernarus/Takistan `Common/Init/Init_CommonConstants.sqf:168` has the same flat-check primitive in the shared placement-block helper.
- Chernarus/Takistan `Common/Init/Init_CommonConstants.sqf:1472-1474` define `WFBE_C_STRUCTURES_FLAT_CHECK = 0`, radius `10`, and gradient `2`, with comments explaining the Takistan over-blocking rollback.
- `git diff --no-index` shows the Chernarus and Takistan copies of `Client/Init/Init_Client.sqf`, `Client/Module/CoIn/coin_interface.sqf`, and `Common/Init/Init_CommonConstants.sqf` match for this lane's relevant files.

## Scope Notes

- No mission source was changed.
- This does not re-run lane 62's broader construction-system QA.
- This does not enable `WFBE_C_STRUCTURES_FLAT_CHECK`; the current default remains `0`.
- The later placement method contains additional red/green checks that can overwrite earlier colors. A live UI smoke should still verify the final preview state before any future source change or default flip.
- No LoadoutManager run was needed because this is docs-only.

## Suggested Smoke

Owner/operator smoke before enabling the flag:

- Set `WFBE_C_STRUCTURES_FLAT_CHECK = 1` in a test build.
- On Chernarus, try placing barracks/light/heavy/air structures on flat ground, steep ground, and water-adjacent positions; confirm invalid previews stay red and cannot be placed.
- Repeat on Takistan ridge/valley bases with gradient `2`; confirm valid base starts are not over-blocked.
- Specifically test a steep position near a house/object to catch any later red-to-green overwrite in the placement method.
