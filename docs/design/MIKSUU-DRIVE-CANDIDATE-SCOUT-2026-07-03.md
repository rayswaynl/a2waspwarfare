# Miksuu Drive Candidate Scout - Lane 22 Follow-up

Date: 2026-07-03

Scope: docs-only, list-first follow-up to `docs/design/ARCHIVE-MINING.md`. No archives were downloaded or extracted in this lane. No mission source, generated mirror, package artifact, or live server state changed.

Source checked: Ray's Google Drive embedded folder listing:
`https://drive.google.com/u/0/embeddedfolderview?id=1saZFKkhygT3DuG9lFkXzmcYC4rQ6lFNM&pli=1#list`

The listing was fetched successfully during this pass and still exposes 4,210 `*_WithPW.7z` archives. Existing `ARCHIVE-MINING.md` already owns the broad inventory and the first 12 pulled archives, so this page only records not-yet-pulled follow-up candidates.

## Duplicate Filter

Already covered or not useful to repeat here:

- The broad Drive inventory and extraction mechanics in `ARCHIVE-MINING.md`.
- Already pulled: Zeus AI, ASR AI 1.15.1, VFAI v26, crCTI missions, MCTI r9, DAC v3, GroupLink II Plus, RUG DSAI, TPW AI LOS, R3F Arty and Log, Oden Warfare Pack 1.05h, and GLT Dynamic AI.
- Already listed as optional-client candidates: PROPER FPS suite, IHUD, foldmap, FOV, crosshair tweaks, AircraftHUD.
- Already handled by bIdentify/Jerry scout: lane 21 archive candidates and the bIdentify IDs in `ARCHIVE-MINING.md` section 4.

## Shortlist

| Rank | Archive(s) | Drive ID(s) | Why it is worth a selective pull | First verification step |
|---:|---|---|---|---|
| 1 | `@Proman_WithPW.7z` | `1ALMOGW1ADN0dX0cRPtPOQgQcWWb5Qkys` | Proman is an evolved crCTI/CTI-24 branch. The existing doc names Proman from bIdentify, but this Drive copy was not pulled. It is likely the best next CTI source after BE 2.073 and Oden for economy, commander ordering, and upgrade/purchase flow contrasts. | Pull only this archive, hash it, extract to scratch, then locate mission source and read upgrade/order/economy files before proposing any port. |
| 2 | `RYD_FAW11_WithPW.7z`, `RYD_FAW12hotfix_WithPW.7z`, `RYD_FAWver11Beta_WithPW.7z` | `1Em6VvcBv10NPmsfRzYHxOTfdI7u-7tpS`, `1EYLLaRwF9k2hLxBqIf4tPloiLc9kRH_6`, `1ErvE_sTQnl5A7s5DI1VkcOUET9syn_Al` | Drive-side Fire At Will copies are useful because the bIdentify `RYD_FAW1.31.zip` row was metadata-only. FAW is the clearest candidate for mining AI-led artillery target selection without adopting a whole mod. | Pull the newest/hotfix first, confirm readable SQF and license/readme, then compare targeting cadence and safety checks against WASP's artillery-disabled AI boundary. |
| 3 | `HAC 1.1_WithPW.7z`, `HAC+demo_WithPW.7z` | `1wuFQjotb5EwALCKTsY5CSCV9UsO7mXWQ`, `1wluVJsQHZCWDKUWts0sHLPOG8mcLp8JP` | Drive-side HETMAN/HAC copies give a possible local source for commander-AI heuristics, complementing the bIdentify HAC note. Mine for target scoring, reserve logic, and force allocation only; do not run alongside WASP AICOM. | Pull the demo package first, confirm script readability and version, then extract only heuristic notes into a design doc. |
| 4 | `mcti_r6_40vs40.Chernarus_WithPW.7z`, `mcti_r7_40vs40.Chernarus_WithPW.7z`, `mcti_r8_40vs40.Chernarus_WithPW.7z` | `1PrA9MO1gxAARGvCUpWFt3VXf8B_tD10J`, `1Pt0r0Z2V1ys4IxxL2agC9tTCBG0GIDxc`, `1PpW0AuEOElgUXmKs0L6AkvBzP-HIWT5T` | MCTI r9 was already pulled. The r6-r8 sequence can expose the small CTI design deltas that led to r9's compact commander and 40v40 shape. This is a low-risk diff target if future work needs a second CTI lineage view. | Pull only adjacent versions needed for a diff, unpack PBOs to scratch, and produce a version-delta note rather than porting code directly. |
| 5 | `cti_doolittle_b22_WithPW.7z` | `1GimbxKk0Nf37PRZNlZXvKFu-_9ayy-rf` | `ARCHIVE-MINING.md` already flags this as a future pull. It is still not duplicated elsewhere and may be small enough to inspect for one-off CTI mechanics or UI/order patterns. | Pull after Proman/MCTI only if they do not answer the current CTI question. Verify license/readme and avoid content/classname imports. |
| 6 | `script_mando_hitching_v1_5_mandoble_WithPW.7z` | `1Km9Er4GsgDy3gnpfInFSem32KJMIMWrL` | Mando hitching is distinct from the already-pulled R3F logistics bundle. It may contain a smaller lift/tow implementation to mine for airlift or cargo-action ergonomics without GPL baggage from R3F. | Pull for source shape and license only. Compare with WASP's current airlift/cargo surfaces before any code proposal. |
| 7 | `FSM_Support_Systems_1.0_WithPW.7z` | `1l2AcDrRkFmS1FRCcZ-DAb00DabxESgD0` | The name suggests a support-call framework, which could feed player-facing support UX or AICOM support triggers. Unknown content, but the archive name is aligned with WASP's support/paradrop/scud surfaces. | Metadata-only until pulled. First extraction should classify whether this is mission script, addon, or demo-only. |
| 8 | `MLV_Support_17mar10_WithPW.7z` | `1TMpzD4jGjBAgDKUI6hw9-QPE_zeT0u-6` | Another support-system candidate from the live Drive listing. Keep behind `FSM_Support_Systems` in priority because the name is less specific, but it may still contain reusable support request patterns. | Pull only if a support-lane owner wants a second source. Reject quickly if it is content-only or addon-only. |
| 9 | `Cargolifter_and_medevac_v1.1_WithPW.7z` | `1ykiupnrCD_HfT-BHfzZjW24e3XGjACMF` | Potentially useful for medevac/cargo-lift ergonomics and player-facing action flow. This should stay concept-only unless a future support or logistics lane asks for it. | Pull only for readme/source inspection. Do not import assets or medical systems. |

## Recommended Pull Order

1. `@Proman_WithPW.7z` for the highest-value CTI lineage contrast.
2. `RYD_FAW12hotfix_WithPW.7z` for AI artillery source availability.
3. `HAC+demo_WithPW.7z` for commander-AI heuristics.
4. MCTI r6-r8 only if a version-delta question is active.
5. Mando hitching or support-system archives only when a support/logistics lane is explicitly open.

## Explicit Non-goals

- No bulk Drive mirror, no recursive downloading, and no extraction into the repository.
- No direct code port from metadata alone.
- No sim-gating, ACR content, HC-architecture changes, or live deployment.
- No mission-source changes until a future owner pulls exactly one archive, verifies provenance/license, reads the source, and writes a narrow implementation plan.

## Reproduction

The listing was parsed from the embedded folder HTML by matching each `flip-entry` file row to its Drive file ID and `flip-entry-title`. The filter excluded any exact filename already present in `docs/design/ARCHIVE-MINING.md`, then searched the remaining list for CTI/Warfare, commander AI, artillery/support, airlift/heli, revive/medical, and client-FPS terms.

Representative command shape:

```powershell
node -e "<fetch embeddedfolderview, regex flip-entry rows, filter against docs/design/ARCHIVE-MINING.md>"
```

For any future selective pull, keep using the existing archive-mining process: download one archive to scratch, hash it, extract the outer `.7z` with password `armedassault`, extract the inner archive separately, and unpack PBOs outside the repo.
