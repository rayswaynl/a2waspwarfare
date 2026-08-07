# Dropped-items sliced full-map scan design

## Evidence and problem

The authoritative Chernarus server RPT repeatedly attributes a single-frame hitch to the
empty `cleaner_droppeditems` full-map `nearestObjects` call. Five current-schema sessions
show first-sweep active time between 2.495 s and 2.756 s at the same ten-minute phase, even
though the server was healthy immediately before the call. A later empty sweep reached
12.699 s under heavier world load. Equivalent Zargabad sweeps were roughly 0.15 s, making
the cost map/world-size dependent rather than a transport or stale-RPT artifact.

Moving the sweep later cannot remove this cost: the current first sweep is already deferred
to ten minutes and begins after healthy ~45 FPS samples. Narrowing one query would silently
drop cleanup coverage. Replacing the engine-created weaponholder discovery with a registry
would not cover every locality/creation path and is therefore not behavior preserving.

## Design

Add an opt-in `WFBE_C_DROPPEDITEMS_CLEANER_SLICED_SCAN` path. When enabled, derive the
official square map extent from `WFBE_BOUNDARIESXY`, divide it into a 3 x 3 grid, and query
one circle around each cell centre. Each radius is the half-cell diagonal plus one metre, so
the nine circles cover every point in the map square. Deduplicate holders returned by
overlapping circles before applying the existing age, proximity, locality, deletion-cap,
and dispatch rules.

Yield for `WFBE_C_DROPPEDITEMS_CLEANER_SLICE_SLEEP` between queries. Measure each query plus
deduplication segment separately, excluding the cooperative yield, and expose `slices` and
`sliceMaxMs` in the existing audit row. Preserve `cycleMs` as wall time. Also place the
existing per-holder active-time cut before its unchanged 0.5 s pacing sleep so the audit's
documented active-time contract remains true for non-empty sweeps.

The flag defaults off. The legacy one-query path remains exact until a controlled test-server
A/B proves that the sliced path reduces maximum single-frame time without increasing total
active cost unacceptably. No live activation or deployment is part of this change.

## Verification

- A focused static regression test checks the opt-in defaults, exact legacy fallback,
  3 x 3 bounded query structure, overlap deduplication, cooperative-yield ordering, audit
  fields, and per-holder sleep accounting.
- The same test numerically samples supported square sizes to prove the encoded cell geometry
  covers map corners, edges, and interiors.
- LoadoutManager regenerates the Takistan and Zargabad mirrors from Chernarus source.
- Targeted pytest, SQF lint, mirror drift, and clean-diff checks gate the draft PR.
