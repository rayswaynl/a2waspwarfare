# Request authority status - 2026-07-03

Lane 79 asks for DR-6 authority validation on the direct build/repair PVFunctions:

- `RequestStructure.sqf`
- `RequestDefense.sqf`
- `RequestMHQRepair.sqf`

Status: the exact DR-6 structural authority layer is not source-present on the current target. PR #278 is the open source path for those guards.

## Current Target

The current target already has several local validity checks, but they are not sender/authority validation.

`RequestStructure.sqf`:

- `RequestStructure.sqf:3-6` trusts `_this select 0..3` immediately.
- `RequestStructure.sqf:10-11` ignores unknown structure names to avoid the old `find -> -1` failure mode.
- `RequestStructure.sqf:20-83` uses `_reject` for CBRadar prerequisite and Bank duplicate/base-distance checks.
- It does not first validate payload shape, side type, side logic, human commander presence, or deployed-HQ state.

`RequestDefense.sqf`:

- `RequestDefense.sqf:2-8` trusts `_this select 0..4`, optional repair-truck flag, and optional requester object.
- `RequestDefense.sqf:242-306` uses `_reqPlayer` for reject messages, refunds, and built-stat credit.
- It does not first validate payload shape, side type, defense type, requester type, requester player-ness, or requester side binding.

`RequestMHQRepair.sqf`:

- The current file is exactly `[_this] Spawn MHQRepair;` in Chernarus, Takistan, and Zargabad.
- It does not validate side type, side eligibility, side logic, HQ alive/dead state, in-progress repair state, or repair count before spawning the repair worker.

This means the current target has useful local build gates, but still lacks the DR-6 authority boundary described by lane 79.

## PR #278 Routing

Open draft PR #278 (`fable/pvf-build-repair-authority`) adds always-on structural guards for:

- malformed or wrong-type payloads;
- invalid side values;
- missing side logic;
- missing human commander or undeployed HQ for `RequestStructure`;
- invalid `RequestDefense` requester objects;
- live-HQ, double-repair, and over-cap MHQ repair attempts.

The PR explicitly notes a residual limitation: without a trusted sender identity in the PVEH payload, a state-aware forge during a valid game-state window still needs a later requester/funds-binding patch. That residual should stay visible during review; PR #278 is a structural guard layer, not the whole server-authority migration.

Propagation note: PR #278 currently reports six changed files, covering Chernarus and Takistan copies of the three PVFunctions. The current target also maintains Zargabad copies, so lane 79 should not be called fully propagated until Zargabad is reviewed or intentionally scoped out.

## Recommendation

Do not open a second source patch for this lane. Review, rebase, and propagation should happen on PR #278 or its successor. A future owner should keep three follow-ups separate:

- structural guards in the three PVFunctions;
- trusted requester/funds binding for builds that still rely on client-side payment;
- broader PVF dispatcher/sender-auth architecture.

## Boundary

This page is a status audit only. It changes no SQF/SQM/HPP/EXT mission behavior, constants, PVF handlers, generated mirrors, packages, deploy scripts, or live server settings.
