# Approved-wave integration manifest — wave-20260725

Branch: `update/wave-20260725`
Base: `origin/master` @ `e7fc469420` (merge PR #1333)
Integration worktree: `C:\Users\Steff\wave-0725`
Build tag: `wave0725a`

Context: owner-directed full update day 2026-07-25 (this deploy explicitly authorized by owner in-session; repo agent-deploy prohibition overridden by direct owner instruction for this wave).
Note: base already contains #1328–#1336 (merged to master 08:28 CET today, NOT yet deployed — live box runs wave0724b). Those nine ship with this wave and are listed in the changelog; they are not re-folded here.

Review gate: per-PR Opus review + adversarial verify (workflow wf_0fd902f6-586), Codex gpt-5.6-sol/high second opinion on the 12 highest-risk, Kimi independent second opinion on the 12-PR aicom batch.

## Integrated PRs
- #1365 — reject stale wildcard targets; head `1243e34bb2`; Opus: MERGE (verify upheld); Kimi: MERGE; merged no-ff as `b5874ba10a`.
- #1363 — normalise heading-delta modulo before 180 fold; head `41f71f51ea`; Opus: MERGE (verify upheld); Kimi: MERGE (math re-derived); merged no-ff as `26b6a2f402`.
- #1359 — preserve command roster selection and release stale orders; head `a5bcd05c62`; Opus: MERGE (verify upheld); Kimi: MERGE; merged no-ff as `ee7e641c5d`.
- #1356 — reserve per-tick AI cap across refills; head `a3d23ba79d`; Opus: MERGE (verify upheld); Kimi: MERGE; merged no-ff as `657dbc181c`.
- #1347 — reach depot-assault waypoints on far-town ARC approach; head `f9750a1639`; Opus: MERGE (verify upheld); Kimi: MERGE; merged no-ff as `a912822546`.
- #1338 — gate retreat distance-cap cull behind a first retreat order; head `7ab7e5bcce`; Opus: MERGE (verify upheld); Kimi: MERGE; merged no-ff as `e9992fb5da`.
- #1364 — require acting commander identity for disband/rally/refit/hold; head `58cd8c8ed5`; Opus: MERGE (verify upheld); Codex: HOLD overturned (pre-PR had ZERO sender check; PR strictly narrows; object-ref forgery residual carded); merged no-ff as `72610b372a`.
- #1361 — server-side authority, alive and reentrancy guards on HQ repair; head `d43196d5e1`; Opus: MERGE (verify upheld); Codex: HOLD overturned (pre-PR was one-line unvalidated spawn; PR adds full validation chain; residual sender-spoof = accepted repo trust model, carded); merged no-ff as `a11b49cdff`.
- #1353 — require full init before boot guards; head `b194fe82da`; Opus: MERGE (verify upheld); Codex: HOLD falsified (serverInitFull defined at initJIPCompatible:100 before all touched sites); merged no-ff as `ae28a48aa1`.
- #1341 — server-authoritative validation for legacy ICBM RequestSpecial [flag default 0]; head `c4ac7ed7d2`; Opus: MERGE (verify upheld); Codex: HOLD overturned by evidence adjudication (pre-existing hole strictly narrowed; ships dark, residual _base/_target trust gap carded for update #2); merged no-ff as `9f0affa96d`.
- #1370 — reap untracked GUER static gunners; head `85d1d5b07f`; Opus: MERGE (verify upheld); merged no-ff as `9db2679570`.
- #1369 — restore VEHDEL ratchet gate + mask block comments; head `928751a5f6`; Opus: MERGE (verify upheld); merged no-ff as `7b015611ab`.
- #1368 — remove counter-battery Fired EH before FEH (EH re-indexing); head `e1747c04de`; Opus: MERGE (verify upheld); merged no-ff as `6146c10d76`.
- #1367 — resync WFBE_Client_Team before respawn guards; head `c6345bdea2`; Opus: MERGE (verify upheld); merged no-ff as `3a016e808a`.
- #1366 — apply rainy lobby rain on clients; head `cafff67e22`; Opus: MERGE (verify upheld); merged no-ff as `e44eb2ae79`.
- #1360 — anchor water retry samples to requested center; head `6d83e0dcc3`; Opus: MERGE (verify upheld); merged no-ff as `18445e7ca0`.
- #1358 — walk full AA missile config lineage; head `d65258b456`; Opus: MERGE (verify upheld); merged no-ff as `532fba60fb`.
- #1357 — buymenu cursorTarget (A2 OA) queue-cancel condition; head `0ce72d3efc`; Opus: MERGE (verify upheld); merged no-ff as `f9c74def2d`.
- #1355 — preserve wildcard commander funds on recovery; head `c8d58544ba`; Opus: MERGE (verify upheld); Codex: MERGE; merged no-ff as `f9c85bc3b3`.
- #1354 — delete server-created RADZONE markers globally + de-collide fee marker; head `41468c0928`; Opus: MERGE (verify upheld); merged no-ff as `842e790e46`.
- #1352 — HTML/Markdown match report reading WASPSTAT + MATCH families; head `6b4929cda6`; Opus: MERGE (verify upheld); merged no-ff as `48241170ff`.
- #1348 — persist FPV first-flight acknowledgement; head `0661795734`; Opus: MERGE (verify upheld); merged no-ff as `062a797dff`.
- #1346 — base build walk clobbered _x order type-key fix; head `42b852cdd9`; Opus: MERGE (verify upheld); Codex: MERGE; merged no-ff as `155eca0f62`.
- #1340 — arm HC-local trash cleanup by default; head `9305af8887`; Opus: MERGE (verify upheld); Codex: MERGE; merged no-ff as `af3105f25e`.
- #1319 — stagger per-town capture scan [flag default 1]; head `445cf10376`; Opus: MERGE (verify upheld); merged no-ff as `e16360918a`.
- #1310 — guard REFIT_END telemetry read against unassigned _refitWas; head `242da97c31`; Opus: MERGE (verify upheld); merged no-ff as `9417c02686`.
- #1246 — rebuild playable slots to 14/14/4/2 (CH full, TK/ZG partial); head `8ca594ebee`; Opus: MERGE (verify upheld); Codex: MERGE; merged no-ff as `15cbd28141`.

## Merge commits
- #1365 merge: `b5874ba10ae52c91458bc149e86a85a34cb0930f`
- #1363 merge: `26b6a2f402052e0edf0653901ba5b7730b6e7f04`
- #1359 merge: `ee7e641c5da261e943e67b24903d2141cfb7862a`
- #1356 merge: `657dbc181c2bdefe0251619273091494c931abf0`
- #1347 merge: `a912822546fe764a091586f70bd48cbe2347854e`
- #1338 merge: `e9992fb5da3e3bc1a05bcea775ff2aa7a9f8488e`
- #1364 merge: `72610b372a26a1b25b0ba5d2a2ca753e04eacaf5`
- #1361 merge: `a11b49cdfffcd1a97abccefacfe341e7299f07b6`
- #1353 merge: `ae28a48aa1e8071f3861e2877f704835addb69f1`
- #1341 merge: `9f0affa96d2a658045d69ac0636c4e8a38ef3fa9`
- #1370 merge: `9db2679570627f072fd232cce05089bbda1f1cbd`
- #1369 merge: `7b015611abb14c9e8339300544fca57bdea857df`
- #1368 merge: `6146c10d76c91d38d83f9ba268e2b094ef6cfc95`
- #1367 merge: `3a016e808a6c892f4bc72223c9a9f00513f2825b`
- #1366 merge: `e44eb2ae7971a040faa7195aaf1891aa6e0279e4`
- #1360 merge: `18445e7ca0c511f2e8396059c051873a625bfb51`
- #1358 merge: `532fba60fb168233e1fb26d37c70f80b30618f3c`
- #1357 merge: `f9c74def2d1ddc7a0be0de04c90f8a682309fa5d`
- #1355 merge: `f9c85bc3b34096803f773b33fa642176cc3eae26`
- #1354 merge: `842e790e468480a3158885ff787937ee8b1b0926`
- #1352 merge: `48241170ff95a2cebc656a4c4a04645242486865`
- #1348 merge: `062a797dff6c8f0808b6ec6b15e3090c4c9dadcb`
- #1346 merge: `155eca0f62b78a61d646193c913ae8b8c35dd228`
- #1340 merge: `af3105f25ef5036a547a9517546661666dc5d464`
- #1319 merge: `e16360918a84199879b36afc7c989188c8cab172`
- #1310 merge: `9417c02686f17a6de3b5f522d4d2c2d1904132d1`
- #1246 merge: `15cbd28141c69c8cadfd4f588f31de641c21f21d`

## Unfolded

- #1370 — folded as `9db2679570`, then REVERTED: Kimi review established the fix is a placebo in the live 2-HC topology (server-side `deleteVehicle` on an HC-local gunner silently no-ops in A2 OA, per in-repo doctrine at server_groupsGC.sqf:242-244/405-410). Proper fix (route delete via owning machine / SendToClient) carded for update #2.

## Held for update #2 (17)

- Demoted by adversarial verify: #1249 (stale/CONFLICTING + camp-gate regression), #1260 (`_clientBody` undefined ref), #1261 (server-side deleteVehicle locality violation), #1262 (120s fail-closed deadline races legit slow boots), #1286 (CONFLICTING vs master).
- Held by review: #1339 (BLOCKER: `_built` never initialized — bricks AI production per buy; one-line fix carded), #1342/#1343 (shared mode-1 delegation break; epoch not sent by Server_FNC_Delegation), #1344 (CONFLICTING + carries #1260's unmerged rework), #1345 (ground-vehicle path bypasses new heli checks; stat-credit before validation), #1349 (un-flagged hold-semantics change — owner call in picker), #1350 (BLOCKER: ATTACK_WAVE_ACTIVE_* latch never resets — kills attack waves permanently), #1351 (carries #1262's un-gated fail-closed init abort), #1362 (misses 4 other queue-counter key sites; stacked on unmerged #1261).
- Merge conflicts with current master (need rebase): #1272, #1278, #1293.

## Verification

- SQF lint selector (A3CMD…TRAILCOMMA, --no-classname-index): wave = 168 findings == base e7fc469420 = 168 → ZERO new findings.
- pytest Tools/Lint + Tools/Soak/test_analyze_soak.py + Tools/Pack/test_pack_pbo.py: 379 passed; 4 failures all REPRODUCED ON BASE (pre-existing, disclosed in #1369): test_commander_lease×2, test_handlespecial floor (54 < floor 56 — live wave0724b also runs exactly 54 cases, zero set-difference vs wave branch → stale fixture, no functional loss; fixture update carded), VEHDEL ratchet (pre-existing manifest drift, deliberately regenerated this wave → 5/5 pass).
- Live-provenance regression check: live wave0724b PBO = pure ancestor state of master (19/19 differing files byte-match historical master blobs) → this wave regresses nothing.
- Review provenance: 80-agent Opus review+adversarial-verify workflow; Codex gpt-5.6-sol/high second opinion (12 riskiest); Kimi independent second opinion (12 aicom batch, found the #1370 placebo + confirmed #1339 blocker); 4 Opus-vs-Codex conflicts settled by evidence adjudication (all 4 → merge; residual hardening gaps carded).
