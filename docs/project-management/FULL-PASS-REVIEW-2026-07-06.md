# Full-Pass Review — 2026-07-06 (Fable, 5 lenses over the whole overnight changeset)

Cross-PR review the per-PR verifiers structurally couldn't do. 4/5 lenses returned first pass (integration died on an API error, re-running). Fixes for the 2 actionable findings dispatched.

## Verdicts
| Lens | Verdict | Key finding |
|---|---|---|
| AICOM stack (#724+#726) | PASS-WITH-NOTES | **1 MAJOR** — UNSTUCK ladder fights pressing teams → fix dispatched |
| Client batch (#719/721/730/723/727) | PASS-WITH-NOTES | 1 NOTE — marker Source-2 missing [0,0,0] guard → fix dispatched |
| Miksuu chain (#60/61/62) | PASS-WITH-NOTES | merges clean, full CI green (213/213, build 82pp); minor brand-token gaps |
| Flag census | PASS-WITH-NOTES | **1 MAJOR** — KILL_TALLY_DECAL default drift (see below) |
| Integration merge test | (re-running) | — |

## MAJOR 1 — AICOM UNSTUCK vs press (CONFIRMED, stack-level)
While a team presses the HQ (#726), AssignTowns still sees it as "stuck" on its `alloc_target` town and escalates UNSTUCK tiers; the UNSTUCK Spawn reads the real server order (fist town) and steps/teleports the team **away from the HQ**. Live conflict once flag=1. Inert at flag 0 (no stamps). **Fix:** one guard before the `if (_usTier > 0)` block — `if (!isNil {_team getVariable "wfbe_aicom_decap"}) then {_usTier = 0}`. Dispatched → stacked PR on #726. **This was the gating blocker for enabling flag 1** — after it lands + the targeted sensing test, the stack is enable-ready.

## MAJOR 2 — WFBE_C_KILL_TALLY_DECAL default drift (CONFIRMED, merge-safety)
7 overnight branch snapshots carry `default=0` for this constant, but `master`/base (merged after those branches' branch-point) holds `default=1`. A careless merge of the constants file could regress the live default 1→0. **Mitigation:** the re-run integration test now explicitly verifies the integrated value stays `1`; the merge runbook must note "when resolving Init_CommonConstants.sqf conflicts, keep base default=1 for KILL_TALLY_DECAL." Not a code fix — a merge-discipline note. NO overnight PR intends to change it (they're stale branch-point snapshots).

## Client NOTE — marker Source 2 zero-guard
`updateteamsmarkers.sqf` Sources 1 & 3 reject `[0,0,0]`; Source 2 (waypointPosition) doesn't → SW-corner arrow edge case. Fix dispatched → updates #730. Flag-0 inert regardless.

## Miksuu MINORs (brand-token consistency, non-blocking)
- `DiscordEmbedPreview.tsx` uses bare Discord-palette hex in Tailwind JIT classes (intentional — it's mimicking Discord chrome — acceptable, but flag).
- Several `--mw-*` tokens (steel/olive/orange/west/east) are referenced by CSS modules but only `--mw-gunmetal`/`--mw-bone` are defined in `globals.css` (others live in `brand/tokens.css`/tailwind config) — the components fall back via the `var(--x, #hex)` inline defaults so they render correctly, but consolidating the token source would be cleaner. `globals.css:69` focus-outline uses bare `#d9763c`. Homepage hero SVG raw hex = pre-existing from main, not tp21.
- None block the chain merge.

## Net
Two real bugs the per-PR passes couldn't see (both cross-file/cross-PR), both flag-0-inert so zero live risk today, both fix-dispatched. Merge-world integrity otherwise sound; final integration verdict pending re-run.
