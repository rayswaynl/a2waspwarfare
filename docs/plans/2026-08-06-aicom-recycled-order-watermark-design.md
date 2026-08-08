# AICOM recycled-order watermark design

## Problem

`wfbe_aicom_order` is the HC commander-team plan record: `[sequence, mode, destination, ...]`. Arma 2 can recycle a deleted group slot while its custom variables remain attached. `Common_RunCommanderTeam.sqf` already resets several unrelated recycled-slot variables, but its local consumed-order watermark always starts at `-1`. If the recycled slot still contains an old valid order, the replacement driver accepts that payload as fresh before the server's next `AssignTowns` pass and can route the new squad toward the previous occupant's destination.

The order record must not simply be cleared. Every order publisher derives the next sequence from the record currently stored on the group. Clearing it would restart at sequence `0`, introducing actual identifier reuse and weakening the existing stale-writer guards.

## Chosen approach

Immediately after founding-time recycled-slot cleanup, capture the existing order's sequence when the record is a non-empty array with a scalar first element. Default the captured value to `-1` when no valid record exists. This snapshot happens before `aicom-team-created` registration because that callback can publish a legitimate quick-start order.

Initialize the long-lived driver's `_lastSeq` watermark from the captured sequence. The old payload is therefore already consumed and cannot move the replacement team. A legitimate post-registration publisher reads the same stored sequence, increments it, and the driver accepts that newer generation normally. A genuinely fresh group still begins at `-1` and accepts its first sequence `0` order exactly as before.

Alternatives rejected:

- Clearing `wfbe_aicom_order` restarts numbering and creates sequence collisions.
- Replacing the record with a synthetic hold order changes shared plan state and adds behavior before the commander has assigned the team.
- Adding a new incarnation token to every asynchronous producer and consumer is broader than this defect and requires separate engine/runtime validation.

## Verification

A source-contract regression covers the Chernarus, Takistan, and Zargabad mirrors. It requires the inherited sequence snapshot to precede registration, requires `_lastSeq` to use the captured watermark, rejects the old constant `-1` initialization, and verifies byte-for-byte mirror parity. The regular SQF linter and focused AICOM regression suite remain required before the draft PR.
