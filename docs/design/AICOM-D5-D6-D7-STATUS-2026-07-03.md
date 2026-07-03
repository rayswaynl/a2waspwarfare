# AICOM D5/D6/D7 status - 2026-07-03

Lane 103 bundles three ALIFE-v2 ideas:

- D5: convoy/MHQ escorts, where relocations and supply runs get a shadow escort team.
- D6: recon screen, where one cheap scout car per side roams the front and gives target choice a visible in-world reason.
- D7: feints, where a small loud team attacks town A while the main force masses on town B.

Status: the full bundled lane is not source-present on the current target. D7 has an open draft source PR, while D5 and D6 remain status-only backlog work.

## Proposal Anchor

`docs/design/ALIFE-V2-AND-DOCTRINES.md:62-65` is the current design anchor:

- convoy/MHQ escorts should reuse the relief picker;
- recon screen should put a visible scout car near the front;
- feints should send a visible side action away from the main effort.

## Current Source

The current target already has adjacent AICOM allocation primitives:

- `AI_Commander_Allocate.sqf:176-215` picks an M2 rear-harass target as the enemy's deepest capturable town outside the fist.
- `AI_Commander_Allocate.sqf:232-268` assigns the first reachable mounted offensive teams to that harass target.
- `AI_Commander_Allocate.sqf:319-348` has the command-center reinforce hook, which can override one eligible team toward a player-selected town.
- `AI_Commander_Strategy.sqf:421-533` has the relief picker: it finds owned towns under attack, diverts a qualifying team, and releases it back to offense after the hold window.
- `Init_CommonConstants.sqf:660`, `:681`, `:690`, and `:996` seed harass, reinforce, nudge-harass, and relief-hold controls.

Those are useful building blocks, but they are not D5/D6/D7 as requested:

- D5 escort shadowing is not wired to AI MHQ relocation or supply-run flow.
- D6 has no persistent scout-car screen, no per-side scout state, and no scout-fed target-choice hook.
- D7 has no current-target `WFBE_C_AICOM_FEINT_*` constants, no `wfbe_aicom_feint_*` group state, and no `AICOM2|v1|FEINT|...` RPT tokens.

The current target does include F5 near-band target scoring:

- `Init_CommonConstants.sqf:533-538` seeds `WFBE_C_AICOM_NEAR_BAND`, `WFBE_C_AICOM_NEAR_BAND_DIST`, and `WFBE_C_AICOM_NEAR_BAND_BONUS`.
- `AI_Commander_Allocate.sqf:135-144` applies the near-band bonus.

That matters because PR #307 previously deferred D6 scout-car work until the F5 scorer lane landed. PR #286 is now merged and the current target has the F5 near-band code, so D6 is still absent but its old Allocate.sqf collision blocker is no longer the reason.

## Open PR Routing

- PR #363 (`fable/aicom-feints`) is the D7 source PR. It adds default-off `WFBE_C_AICOM_FEINT_*` flags, dispatch/recall logic, `wfbe_aicom_feint_expiry`, and `AICOM2|v1|FEINT|DISPATCH` / `RECALL` tokens.
- PR #307 (`fable/aicom-d4-target-aware-comp`) is D4 target-aware compositions, not lane 103. Its body explicitly says D6 scout-car code was excluded.
- PR #286 (`fable/aicom-f5-near-band-bonus`) is merged; current source carries the near-band scoring it introduced.

## Recommendation

Do not pile all three sublanes into one hot-file patch. The safer split is:

- Treat D7 as the PR #363 review/rebase path.
- Treat D6 as a new scout-screen source lane now that F5 is present; it should define ownership, lifecycle, cleanup, and whether scout sightings affect scoring or only telemetry.
- Treat D5 as a separate escort lane that reuses relief-style team picking but hooks to explicit MHQ relocation and/or supply-run events, with strong guards against stealing active assault/relief/strike teams.

## Boundary

This page is a status audit only. It changes no SQF/SQM/HPP/EXT mission behavior, constants, route generation, AICOM allocation, generated mirrors, packages, deploy scripts, or live server settings.
