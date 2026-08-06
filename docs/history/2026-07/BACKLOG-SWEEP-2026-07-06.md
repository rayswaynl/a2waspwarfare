# Backlog Sweep — 2026-07-06 (post Build-89 release)

Compiled for owner discussion after Build 89 (cc46) went fully live. Grouped by what
it needs from you. Nothing here is blocking the live server — it's healthy.

## A. Needs your decision (gates the most work)

1. **V2 AICOM cutover** — PR #760 is BUILT and dual-audited (the sensing/press stack +
   telemetry reconciliation + V1 removal). It's the single biggest remaining feature.
   Before it can go live it needs: (a) N clean T3 parity soaks on the box with the
   rollback flag live, (b) your flag menu — mainly `WFBE_C_AICOM2_DECAP_ENABLE`'s default
   at cutover. **Decision: schedule the cutover soaks now, or hold?**

2. **HC slot seating** (#763, built by the other session) — finding: HCs *already* land in
   the same slots deterministically on an empty boot (engine seats them into the lowest
   WEST ids 229/230). The guard in #763 only cleans misleading log noise; it does not
   change the slot. The analysis doc lists 6 candidate mechanisms to *force* a named slot,
   one untested (a CIV-low-id angle). **Decision: try the untested angle on a test boot,
   accept deterministic-on-empty as good enough, or merge just the log-noise guard?**

3. **wddm manned forts** (#756) — new gameplay (flag default 0), but the PR self-acknowledges
   box-smoke gaps (building-mounted MG physics on A2). **Decision: fix the smoke gaps and
   ship to test, or shelve until the cutover is done?**

## B. Queued build work (I can proceed without you)

4. **WF_MAXPLAYERS telemetry hotfix** — the MATCH-START emitter references a preprocessor
   define out of scope (nil field, telemetry only). Fix in progress; batches into cc47.
5. **Squad Micro Layer SML-2..5** — dismounts, graceful retreats, AT overwatch, surgical
   unstuck. SML-1 is live; these are the follow-on features on the V2 lane.
6. **Flag-1 sensing test** — cc44v is still staged; the plan is intact. Now that cc46 is
   live, the sensing test's revert target should be cc46. Or fold it into the cutover soaks.
7. **After-match reports** (#64, merged, gated off) — flip `MATCH_REPORT_ENABLED=1` + set a
   test-channel ID to activate. (Depends on #4 for a clean maxPlayers field.)

## C. Not-done from the original master instructions

8. **Aircraft spawn safety** — helis at owned airfields spawning safely (unbuilt, low priority).
9. **Website guides content** — the in-repo guide text update (distinct from the homepage
   reframe that shipped; the guides themselves weren't rewritten).
10. **Discord guild production migration** — owner-manual (the runbook exists; only you can
    run the production guild steps).

## D. Housekeeping

11. **Promote + cc47** — claude/build84-cmdcon36 now carries the 3 merged fixes (#758/759/761)
    plus the WF_MAXPLAYERS hotfix; promote to master and cut cc47 to get them live.
12. **Cat-C branches** — ~31 stale branches with no PR need manual keep/delete review.
13. **Napf conflict markers** — pre-existing `<<<<<<<` markers in the unmaintained
    `Modded_Missions/…Napf/*` event tree (not a live terrain). Clean or leave.
14. **miksuu gated PRs** — #51 (needs 4 .bikey keys from you), #57 (needs your 2 manual
    Discord steps).

## Recommended next moves (my read)
1. Do #4 (telemetry hotfix) + #11 (promote → cc47) as one clean batch — gets the folded
   fixes live and the last telemetry bug gone.
2. Answer A1 (cutover schedule) — it's the critical path for the whole V2 program.
3. Answer A2 (HC seating) — cheap to try the untested angle if you want it.
Everything else can wait for your steer.
