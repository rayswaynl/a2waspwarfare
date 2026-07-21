# C3 consensus quick-wins

## Scope

Build only provider-overlap items that are correctness or telemetry class: split AICOM census telemetry and debounced founding-skip reasons; make the found-size constant honest; exclude dead HC husks from founding/side-AI accounting; and align the mounted classifier while adding capture-class telemetry. No HC protocol/driver architecture is changed. The census counts only live non-player bodies in founded/server-local groups; patrol bodies are counted once by their registered leader groups, and the `other` bucket is the remaining live non-player side population.

## Commit slices

1. Add split census and founding-skip telemetry.
2. Set the clamped AICOM found-size constant to its effective value.
3. Correct live-body accounting so dead founded teams and dead units do not satisfy target/cap math.
4. Require a mounted leader convoy signal and emit capture-class telemetry.
5. Retire a no-HC empty persistent reservation after 300 seconds when production never supplies a live body, so one failed reservation cannot permanently block founding.

The C3 telemetry flag is registered in the shared constants section for all three terrains and defaults to 0; it is not part of the Zargabad-only governor block. Founding census, side-cap, and founding-skip records are emitted by the server worker; capture-class records run on the existing owning driver (HC or server-local) and are not blanket server-authoritative. Each SQF slice is edited in the Chernarus source, mirrored by LoadoutManager to Takistan and Zargabad, and checked with the selected A2 linter, bracket counts, CRLF, and mirror hashes. Contested tuning, EAST allowlists, bootstrap/CapLock changes, refunds, HC refill/reconnect architecture, and unverified/provider-specific proposals remain out of scope.
