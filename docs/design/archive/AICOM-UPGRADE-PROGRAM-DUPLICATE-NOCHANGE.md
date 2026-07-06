# AICOM Upgrade Program Duplicate No-Change Verification

Lane: 355 - AICOM upgrade-program duplicate entries produce redundant `wfbe_upgrading` spin cycles

Guide: GR-2026-07-03a

Target base: `claude/build84-cmdcon36` at `873c7f7af25070bbf690d27cc4c006d45a00155f`

## Verdict

No mission source change is recommended for Build84.

The lane premise is partly true but the failure mode does not reproduce on the current target. `AI_Commander.sqf` can build a research path with duplicate `[upgrade, level]` tuples, but `Server_AI_Com_Upgrade.sqf` scans the whole path in one call and ignores already-met tuples inside that same `forEach _path` pass. A duplicate tail entry does not consume a separate `WFBE_C_AI_COMMANDER_UPGRADE_INTERVAL` tick by itself.

## Evidence

`AI_Commander.sqf` explicitly expects this shape:

- `Server/AI/Commander/AI_Commander.sqf:72` says duplicate tail entries are harmless because the worker skips reached levels.
- `Server/AI/Commander/AI_Commander.sqf:73-111` reads the faction `WFBE_C_UPGRADES_%1_AI_ORDER`, builds the doctrine `_program`, and stores `_program + _order`.
- `Server/AI/Commander/AI_Commander.sqf:120-121` can append `[[WFBE_UP_PATROLS,4]]` later when the level array supports it.

The default faction orders really do overlap with the doctrine program:

- Every maintained Chernarus `Common/Config/Core_Upgrades/Upgrades_*.sqf` file starts the AI order with `[WFBE_UP_BARRACKS,1]` and `[WFBE_UP_GEAR,1]` at or near lines 153-155.
- Several faction orders also contain `[WFBE_UP_PATROLS,4]` near the tail, so the later Convoys append can duplicate that tuple when enabled.

The worker behavior is the deciding part:

- `Server/Functions/Server_AI_Com_Upgrade.sqf:26` reads the final `_path`.
- `Server_AI_Com_Upgrade.sqf:51-54` resets `_headUpgrade` and `_chosen` for the current call.
- `Server_AI_Com_Upgrade.sqf:63` only enters the candidate body if `_upgrades select _upgrade < _level`.
- `Server_AI_Com_Upgrade.sqf:70-87` records the first unmet head item and the first affordable choice.
- `Server_AI_Com_Upgrade.sqf:92` closes the same `forEach _path` pass.
- `Server_AI_Com_Upgrade.sqf:95-113` starts one chosen upgrade and sets `wfbe_upgrading`.
- `Server_AI_Com_Upgrade.sqf:116-136` logs exhausted or unaffordable state only after the same full-path scan finds no chosen upgrade.

That means a duplicate tuple whose level is already reached fails the line-63 unmet check and does not become `_headUpgrade`, `_chosen`, or an exhausted-program event. It is only a cheap in-pass array iteration.

## What Was Not Changed

No SQF files were edited.

No dedupe helper was added to `AI_Commander.sqf`, because that file is already hot under open PR #571 and a code change would not fix the claimed full-interval burn on current Build84.

No `Init_CommonConstants.sqf`, upgrade config, mirror output, package artifact, deploy step, or live runtime setting was touched.

## Future Tripwire

Revisit this only if a future worker regresses to a head-only scan, exits early on met entries, or logs exhausted state before scanning the whole path. In that shape, a one-time path compaction after `_program + _order` would be reasonable. On current Build84, the safer action is to leave the runtime alone and preserve the source evidence here.
