# WASP Warfare — Release Plan (owner-declared 2026-07-06)

## ⭐ PIVOT 2026-07-06 late (owner: "you pick, get V1 going"): 1.0 SHIPS ON V1 NOW.
The V2 cutover soaks were blocked by the box being in live use. Owner directed shipping 1.0 on the
current proven V1 commander immediately; V2 (#793) becomes the FIRST POST-1.0 UPDATE, validated by the
already-staged soak program (soaks 1-3 run as post-release V2 validation, no longer the 1.0 gate).
**1.0 = current build84 (cc48a lineage + all fixes + dark features) on V1. DECAP dark (0).**
RC being built (release-1.0-rc1) + staged; deploy on owner go / empty window (NOT auto — box occupied).
C-130 #786 = Option 1 (WEST-scoring accepted, dark) — Claude's pick, merging.
Remaining owner steps for 1.0: (a) deploy go, (b) round-2 flag menu (which dark features on at/after launch),
(c) announcement sign-off. DECAP-default + V2-cutover deferred to the post-1.0 V2 update.


**VERSION NAME (owner, 2026-07-06): 1.0** — public name for the release. Engineering lineage keeps the
cmdcon tags (release build marker: release-1.0 + cmdcon lineage in git tag, e.g. v100-release-1.0).
Announcement, news post, wiki, and Discord all say **1.0**.

**Definition (owner):** Release = the V2 era, publicly announced. AI Commander V2 cut over (V1 shelved,
rollback flag live), all owner-picked features settled, no known release-blocking defects.
**Timeline:** ASAP, quality-gated — no calendar date; gates decide.

## Critical path (serial)
1. **Soak 1** — V2 shadow (DECAP=0), 2h, empty window. STAGED; watcher fires automatically (owner pre-auth).
2. **Soak 2** — DECAP=1 full V2. Fires after soak 1 grades PASS/WATCH.
3. **Soak 3** — confirmatory DECAP=1. Any FAIL resets the counter (runbook: docs/testing/V2-CUTOVER-SOAK-PROGRAM.md).
4. **Owner call:** DECAP_ENABLE default at cutover (flag menu after soak 2 evidence).
5. **Cutover merge** — #788 (fable/v2-cutover-r2) → build84 → master; release build; deploy.
6. **Stabilization window** — heavy monitoring on the release build; hotfix bar = same-day.
7. **Announce** — news post + Discord (materials lane below).
8. **Post-release:** V1 shelve→remove (per ruling, AFTER N clean rounds with rollback flag live), anti-cheat arm, dark-flag round 2.

## Parallel lanes (non-blocking unless they find blockers)
- **Blocker audit** (RUNNING): old RR blockers (scanner dead-assertions, PVF confused-deputy), the audit-v2
  RCE finding (Server_HandlePVF Call Compile) vs current master, anti-cheat v1 disposition. A public release
  must not ship a known RCE — this lane CAN block.
- **cc48b patch** (staged): garrison disableMove fix + SML-2 flip (gate: one round of SML-3/4/5 live evidence).
- **Release materials** (RUNNING): rescue uncommitted V2 news drafts, release-announcement skeleton.
- **Guides refresh** (RUNNING): B89 content pass, owner review.
- **Dark-flag disposition** (before release): each remaining dark flag → ship-on / ship-dark / cut:
  SML_DISMOUNTS, DEFENSE_CLIENT_GATE_ALIGN, AICOM_BUILD_ROAD_CLEAR dial, WALLS_V4, DEF_FORTIF_PACK,
  NAVAL HVT flags, GUER Director V2 lane (post-release per spec), airfield-ownership gate (building).
- **Watching:** permDay FPSREPORT confirm, first MATCH|v1|END → match-report embed verify.

## Release gates (all must be green)
- [ ] 3 clean soaks (runbook criteria) 
- [~] Blocker audit DONE 2026-07-06: RCE + confused-deputy + SEND_MESSAGE injection CONFIRMED FIXED on master
  (commits 7d60b02b4 + 4f2c506b5; allow-list + CODE-type checks verified via git cat-file). Remaining:
  (1) PR #768 (supply pay-out no-op + DR-55 guard no-ops) — refuter running, merge on PASS;
  (2) BattlEye posture: box has NO beserver.cfg (BE unarmed) — DECISION: ship 1.0 with BE OFF (A2 BE master
  server down; enabling risks locking players out). BE filters + chat bridge = post-release, gated on BE ecosystem.
- [ ] Cutover build boots clean on all 3 terrains (marker + error budget)
- [ ] Rollback proven: DECAP_ENABLE=0 flip restores V1 behavior on the release build (soak 1 doubles as evidence)
- [x] Version name: 1.0 (owner) — [ ] announcement sign-off pending
