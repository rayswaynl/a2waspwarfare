# WASP Warfare RC2 — Proposed Patch Changelog

Status: draft release candidate. No live deployment or master merge has occurred.

## AI Commander

- Rejects aircraft carriers as capture targets and clears stale carrier orders when no legal land target remains.
- Enforces structure limits through one server-owned reservation gate, preventing simultaneous build paths from exceeding per-type caps.
- Queues Command Console orders server-side with validation, rate limiting, stale rejection, and last-order-wins coalescing.
- Fixes assault teams losing their attack path when the cached side value is missing.
- Binds transport-helicopter refunds to the exact server-owned failed dispatch and permits one verified refund only.
- Preserves the exact charged amount on deferred reinforcement requests and refunds expired requests.
- Credits delegated CTL forces from each group's own wave stamp.
- Optionally preserves untouched AI orders during delegate handoff. Default: off.
- Optionally removes only the unwanted first-spawn buddy without touching purchased squads or reconnecting players. Default: off.
- Optionally replaces silent terminal-team deletion with a visible final lifecycle. Recovered teams clear their server-visible failure state; genuinely terminal teams dismount, their hulls cook off once, and the empty group is reaped after bounded cleanup. Default: off.

## A-Life and GUER

- Routes GUER QRF aircraft through the normal vehicle/unit creation hooks, including cleanup, markings, damage, bounty, countermeasure, and configuration handling.
- Fixes the GUER Director's first-cycle survivor blind spot.
- Counts only real GUER garrisons against the existing garrison cap.
- Scales GUER stipend from the highest live town count reached during the match.
- Makes GUER transfers debit once, travel through one directional ledger entry, and credit once after ETA.
- Reconciles town ownership changes with explicit transfer arrival, refund, or loss outcomes.
- Rejects paid GUER Director actions before debit when the selected town is no longer GUER-held.
- Adds focused RPT telemetry for QRF creation, survivor seeding, garrison accounting, stipend peaks, transfers, ownership reconciliation, and marker cleanup.
- Preserves A-Life volume and keeps CIV headless clients non-combat.

## UI and map

- Adds persistent player-local controls for friendly unit dots, team arrows, and artillery range rings; current visibility remains the default.
- Synchronizes name-tag settings with the live overlay and bounds candidate scans while keeping smooth projection updates.
- Hardens purchase/build UI paths against unknown classes, missing UAV gunners, conflicting jet guidance handlers, and invalid carrier deck-height use.
- Preserves the player's saved driver-default preference.
- Closes the elongated Khe Sanh deck seam with four correctly seated bridge sections and retains a rollback flag.
- Publishes authoritative permanent-day date state so remote and JIP clients correct clock drift without mission-uptime jumps.

## Reliability, economy, and configuration

- Makes legacy tactical UAV purchases server-authoritative for side, team, hull, crew, funds, expiry, and request capability.
- Adds independently gated UAV level-two consumers: Engineer/repair-truck Forward FOBs and an AI-commander-only bounded FPV swarm. Both default off; the level-two economy and UI remain absent while both gates are dark.
- Binds Forward FOB construction to a private, challenge-bound, short-lived, one-shot server capability and refunds/cleans every partial creation failure before registration.
- Repairs shared-class metadata, malformed faction tuples, missing enabled-weapon prices, and GUER counter-battery-radar buildability.
- Stops supply missions safely when no friendly town can be resolved.
- Hardens rolling-average persistence, server defaults, terrain-size lookup, CTL bookkeeping, and stale mission paths.
- Mirrors maintained mission changes across Chernarus, Takistan, and Zargabad.

## Pending final folds

- Complete removal of the custom Miksuu vehicle-radio system, Radio Tower, addon payload, BASS dependency, and extension handler. Native Arma chat and unrelated sounds remain.

## Explicit exclusions

- Mounted-passenger firing is not included.
- AI Commander headless clients remain commander-only and do not occupy gameplay roles.
- This proposal does not deploy, restart the server, or merge master.

## Release evidence

- Successor branch: `codex/wasp-approved-matrix-rc2-20260719`
- RC2 includes or supersedes the reviewed mission PR wave through #1148, with the #1142 reviewer follow-up folded at `cae4d99ea2` and independently approved UAV2 folded at `984581664a`.
- Final immutable head, package hashes, two-HC admission receipt, and full-match soak receipt will be appended after the remaining radio removal passes review.
