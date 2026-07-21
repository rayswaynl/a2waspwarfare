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

- PR #1162: approved CIV HC slots-only mission.sqm change; merged no-ff as `de7475e9d9` (rebased feature head `5d9ca7c052`).
- PR #1208: approved C3 consensus quick-wins (HC census/no-HC accounting and flag-dark telemetry); merged no-ff as `8cddb617cc` (feature head `dc6b9afd59`).
- PR #1161: approved Zargabad small-map tune; merged no-ff as `7d857f06d9` (final reviewed head `d4ffe51adf`).
- PR #1160: approved AICOM air founding telemetry; merged no-ff as `8a81ab3392` (final reviewed head `b7733e82e5`).
- PR #1155: approved B76 funds-resend zero-wallet fix (never invent a zero wallet on CIV-drift, authority-safe resolution, no side-adoption); merged no-ff into wave-next as `c53cef8019` (drain head `ff631ee434`).
- PR #1157: VEHDEL probe proper - duplicate gc-zombie emission dropped, FLAGGATE-conform probe guard, truthful default-0 header; replaces the wave0720c shim path; merged no-ff into wave-next as `dfb9cd98e0` (drain head `fefacf451b`).
- PR #1159: mobile-artillery echelon reposition decoupled from the single-fire gate - gun #2 no longer starved of repositioning; single-fire-per-cycle preserved; merged no-ff into wave-next as `a9d166c137` (drain head `81db315180`).
- PR #1156: aicom-town-nudge _x rebinding fix w/ nil-guard-first capture; merged no-ff into wave-next as `526eacce65` (drain head `57461d1510`).
- PR #1211: GUER client startup (wfbe_commander marker on GUER logic - client loop/AFK/chat now start) + Barrel-Bomb/SCUD designation cancel with default map-click handler restore; merged no-ff into wave-next as `377cb2b667` (feature head `fc53d364f7`).
- PR #1151: client name-tag overlay candidate caching + TAGSTAT telemetry; test collection fixed; merged no-ff into wave-next as `7bbd762d4d` (feature head `98442f67bf`).
- PR #1212: STOPPED - not folded. Approved head `28cb4e0ae9` conflicts non-trivially with the #1159 echelon fold already on this branch: both rewrite the same base-artillery counting block in `AI_Commander_Base.sqf` (CH/TK/ZG) with incompatible logic (echelon-registry branch vs global vehicles-scan replacement). Needs owner/reviewer reconciliation, not a textual merge. NOTE: the `fix/aicom-arty-cap` branch tip has also moved to `7a12a0e0a5` (husk-reaping/map-label follow-up) which is NOT covered by this approval - re-verify head before any retry.
- wallet: RequestAIComDonate derives donor team server-side (arbitrary-group drain closed) + authority regression test; PV-sender residual owner-accepted, token infra carded next wave; merged no-ff into wave-next as `af840699b0` (drain head `794de3b476`).
- PR #1216: wrecks no longer hold/contest towns (alive+crewed filter in the capture tally) + town statics locked and salvage-proof (keepAlive at creation) - owner rulings; merged no-ff into wave-next as `c761d0e5c7` (feature head `9aab2e5097`).
- PR #1218: quartermaster passive top-up free under a human commander (WFBE_C_AICOM_TOPUP_HUMAN_COST default 0); AI-commanded sides unchanged - owner ruling; merged no-ff into wave-next as `64e20db2b9` (feature head `314ceb4e39`).
- PR #1154: commander-lease stand-down relocated OFF the JIP flow (owner constraint) into the connect handler, reachability-fixed above the duplicate-connect latch, order-asserted by test; dedicated-server-scoped (documented); merged no-ff into wave-next as `a1474fe84c` (drain head `c0a1109ec6`).
