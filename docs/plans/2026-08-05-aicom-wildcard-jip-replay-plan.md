# AICOM wildcard marker JIP replay

## Scope

Repair the confirmed late-join gap for active AICOM wildcard map markers. Keep live server/HC state read-only; change only the canonical Chernarus source, generated mirrors, the existing client marker receiver, and a static contract test.

## Design

1. When an AICOM wildcard marker is created, record its side, marker payload, and absolute expiry in a server-local missionNamespace ledger.
2. Keep the existing side-scoped broadcast and expiry delete. The expiry worker also removes its record from the ledger so replay cannot resurrect an expired marker.
3. Replay a snapshot of unexpired records from the existing `CLIENT_INIT_READY` server handler, after the joining client has installed the PVF receiver. Route each create directly to that player and space the writes by 0.5 seconds, matching the established FOB replay transport discipline.
4. Add an optional notification flag to `WildcardMarker.sqf`; normal live creates still notify, while JIP replay creates only restore the visual marker and label.

## Verification

- Red test before source edits, then green static contract and mirror-parity tests.
- SQF lint on the changed files and the project-required selected rule set.
- Generated CH/TK/ZG mirror parity, diff/line-ending review, and `git diff --check`.
- No engine, live-server, HC, deploy, merge, or monitor/HTML mutation.
