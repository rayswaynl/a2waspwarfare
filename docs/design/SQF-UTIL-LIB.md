# SQF Utility Library — hash/dict store, vector math, delayless dispatch

**Card:** #25 (mining-review batch, GR-2026-07-08a) · **Status:** pure scaffolding, no gameplay
consumer in this PR. Everything below is unconditionally registered in `Init_Common.sqf` (like
the existing `Common_Handle*` family) and produces zero behavior until a future PR calls into it.

**Flag:** `WFBE_C_UTIL_LIB_SELFTEST` (default `0`) gates only the optional boot smoke-test
(`Common_UtilLibSelfTest.sqf`). It does not gate the library functions themselves.

## Open verification item (read before adopting on a real hot path)

This PR's review pass could not complete a network engine-verification round (no network
access in the implementing session) for two specific claims:

1. Whether A2 OA 1.64 natively provides any of the vector primitives reimplemented here as
   manual arithmetic (`VectDot`/`VectCross`/`VectMagnitude`). If it does, nothing here breaks,
   but the reimplementation may be partially redundant with an engine command.
2. Whether an FSM's first state genuinely runs its `init` code in the SAME execution frame
   `execFSM` is called, with `execFSM`'s argument bound to `_this` inside that state (the
   "delayless dispatch" claim behind `Common_DelaylessCall.sqf`).

Arm `WFBE_C_UTIL_LIB_SELFTEST=1` and read the server RPT once before relying on either claim in
a follow-up PR that adopts this library on a real hot path — the self-test measures both rather
than asserting them.

## Hash / dict store

Two-parallel-array key/value store (`[_keys, _values]`) — A2 OA has no native map type. All
lookups are a **linear scan** via the array `find` command; this is documented honestly as *not*
a hash table and *not* faster than the existing manual-scan idiom already used in
`Server_CmdTownLedger.sqf`. It exists to give callers one reusable, documented API instead of
hand-rolling parallel-array scans at each call site.

| Function | Params | Returns |
|---|---|---|
| `WFBE_CO_FNC_HashCreate` | none | new empty handle `[[],[]]` |
| `WFBE_CO_FNC_HashSet` | `[_hash, _key, _value]` | `_hash`, mutated **in place** |
| `WFBE_CO_FNC_HashGet` | `[_hash, _key]` or `[_hash, _key, _default]` | stored value, or `_default` (nil if omitted) |
| `WFBE_CO_FNC_HashHasKey` | `[_hash, _key]` | BOOLEAN |
| `WFBE_CO_FNC_HashRem` | `[_hash, _key]` | a **new** handle — A2 OA has no `deleteAt` to shrink an array in place, so callers MUST reassign: `_h = [_h, "key"] call WFBE_CO_FNC_HashRem;` |

Nested arrays are held by reference in SQF, which is why `HashSet` can mutate `_hash` in place
via `set` while `HashRem` cannot shrink it the same way.

## Vector math

Manual index arithmetic, not wrappers around any native `vect*` command (see the open
verification item above).

| Function | Params | Returns |
|---|---|---|
| `WFBE_CO_FNC_VectDot` | `[_a, _b]` (each `[x,y,z]` or `[x,y]`) | dot product, NUMBER |
| `WFBE_CO_FNC_VectCross` | `[_a, _b]` | cross product, `[x,y,z]` |
| `WFBE_CO_FNC_VectMagnitude` | `[_a]` | length, NUMBER >= 0 |
| `WFBE_CO_FNC_VectElevationSolve` | `[_dist, _dz, _speed]` or `[_dist, _dz, _speed, _g]` | low-arc ballistic elevation angle in **degrees** (SQF trig is degree-based), or `-999` sentinel if unreachable (deliberately outside the valid `atan` range of `(-90,90)` so it never collides with a real result — a plain `-1` would, since `-1` degrees is itself an ordinary low-arc angle) |
| `WFBE_CO_FNC_VectLeadAngle` | `[_shooterPos, _targetPos, _targetVel, _speed]` | `[_aimPoint, _t]` on success, `[]` if no positive-time solution exists |
| `WFBE_CO_FNC_VectSurfaceNormal` | `[_pos]` or `[_pos, _radius]` | unit-length `[x,y,z]` terrain normal, sampled via `getTerrainHeightASL` (A2 OA has no native `surfaceNormal`) |

No gameplay consumer in this PR — cited as reusable by future card #12 (CIWS) and #14 (JTAC)
work, which wire these up in their own flag-gated PRs.

## Delayless dispatch

`WFBE_CO_FNC_DelaylessCall` — `[_args, _code] call WFBE_CO_FNC_DelaylessCall;` dispatches `_code`
(with `_args` as its `_this`) via `Common\FSM\delayless.fsm` instead of `spawn`. `spawn` always
queues onto the scheduler and only starts on a later slot; the FSM route is intended to start
executing in the same frame the call is made, while still giving the dispatched code its own
suspendable scope (it can `sleep`/`waitUntil` without blocking the caller). See the open
verification item above — this is the second unverified claim the self-test measures.

No gameplay consumer in this PR — reusable by future hot-path work referenced against cards
#1/#12/#14 in the mining-review process.
