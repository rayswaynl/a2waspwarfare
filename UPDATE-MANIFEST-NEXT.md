# Wave-next integration manifest

Branch: `update/wave-next`
Base: `origin/master` (`b411d70004`)

## Pending items

- Chat-relay rework
- PR #1158 rebase and teambar telemetry fold-in
- WF menu P1+P2
- Units-per-group follow-ups
- Recycle residue

## Folded items

- PR #1158: rebased over current master, preserved the merged skin-swap fix without duplication, and merged no-ff into wave-next as `81e42f2a5414c6574fb8b0c7331869ba0034a7da`.
- PR #1195: reviewed as report-tooling-only after isolating its stacked wave history; rebased head `e09027b48a` was merged directly to master as `e1be2c69818b006fa20e2f3a62052905ec565725`, not folded into wave-next.
- PR #1202: autorun built + Sol-reviewed 2 rounds (3 blockers + 1 follow-up fixed); lint gained `stance` in A3CMD; merged no-ff into wave-next as `f5d3b97d1b96f8bb00de5dbb786578aff586909f` (feature head `67b1892793`).
- PR #1207: council quick-wins: 8 groups, including the confirmed dead-camp gate residual fix; merged no-ff as `4562e2879fe17dc5512672c5f69654ed31a9abe1` (feature head `2b1e105848`).
- PR #1206: WF menu P1+P2: hub polish + consistency + IDD collisions 24100/10202, in-engine visual smoke owner-gated; merged no-ff as `22ff5c5a09e8b07ac1b65e026435616efd959e82` (feature head `d003c453a7`).
- PR #1204: server-events one-way chat relay, flag-dark (`WFBE_C_CHAT_RELAY=0`), reviewed in 3 rounds; merged no-ff into wave-next as `b845fbb86ed4c0a09efed5118dea46aef360ba52` (approved head `9f323f77bc`).
- PR #1210: always-offense review blockers fixed (flag-0 relief, staging watchdog, truthful funds telemetry, and FOOT_STAGE FLAGGATE guard); merged no-ff into wave-next as `a6a7662ff85f4ee54778637af5761dad05c72de5` (approved head `1432dd851f`).
- PR #1205: roster phase-2: 3 flag-dark features (E3 GUER ground QRF, E5 late Huey QRF, and per-town airfield/high-SV garrison overlays), Sol-approved after 2 review rounds; merged no-ff into wave-next (approved head `ec68ecf014`).
