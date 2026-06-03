# Developer History And Upstream Lessons

This page turns upstream development history from `Miksuu/a2waspwarfare` into practical guidance for future Wasp Warfare developers and AI agents.

Evidence sources used for this pass: upstream `master` through `8bcc42b1` (2026-06-02), GitHub PRs #1-#12, branch list from the upstream repository, merge/revert commits, commit messages, and file-level deltas. Treat this as developer-intent evidence, not a substitute for current-source inspection before code changes.

## High-Signal Patterns

| Pattern | Evidence | Developer lesson | Confidence |
| --- | --- | --- | --- |
| Supply missions attract exploit fixes, UX follow-ups and JIP regressions. | PR #10 `Supply run remote activation glitch fix` / merge `97dfff26`, commit `65fa3332` "Fix remote supply truck glitch", PR #11 / `8164cc33`, PR #12 body: prevents the extra too-far notification during JIP. | Do supply changes as a server-owned state machine: validate requester, source town, vehicle range, cooldown and reward on the server, then test normal start, remote start, JIP join, reused vehicle and Takistan propagation. | confirmed |
| JIP bugs repeatedly appear after client-facing features. | PR #12, commits `b02782f1` "Move main logic of heavy attack mode to server to avoid JIP issues", `a9044821` "Refactor logic of JIP during heavy attack feature", `6eb09dc3` "Make JIP players spawn at HQ or factories only". | Any UI/action/state feature needs a JIP plan before merge: decide whether it is replayed state, pull-response, or event-only; add a late-join smoke path to the validation checklist. | confirmed |
| Debug logging is useful during archaeology but must not become shipped noise. | Attack-wave cluster on 2026-03-13 includes multiple "Add debug logging" commits followed by `32895cae` "Remove debug logging"; `891a70ea` later says "Remove all the logging"; supply and marker clusters also remove unnecessary logs. | Use `WF_Debug`-gated diagnostics and remove temporary broad logs before publish. If logs explain a fragile edge, preserve the lesson in docs instead of leaving unconditional runtime spam. | confirmed |
| Mission-copy divergence is a standing maintenance cost. | Many upstream commits are explicit Takistan copies: `994150da` "Add supply run upgrade to Takistan", `ba25ada0` "Add extra score bug fix to Takistan", `101e3452` "Remove unnecessary debug logging from Takistan too", repeated "update taki" commits during May/June 2026. | Patch source Chernarus first, then propagate generated Vanilla/Takistan deliberately. Review generated diffs; do not assume a feature is fixed everywhere because Chernarus changed. | confirmed |
| Performance work succeeded after instrumentation, not blind simplification. | `88e0749a` "Performance audit instrumentation for FPS diagnostics", `ff1ea838` "Extend performance audit logs with environment state", `62becdda` "performance audit analyzer and session-aware reports", then optimizations like `4aaa814a`, `6e5b3c50`, `6189f3c5`. | Measure first, then reduce scans/marker churn. Keep audit toggles cheap and optional; preserve counters that show whether an optimization starves gameplay. | confirmed |
| Town defense activation is fragile because performance and gameplay correctness compete. | `4aaa814a` reduced town/camp loops and AI activation spikes; `a20a5a0f` restored reliable activation from capture scans; `84b1b684` restored pre-capture town defense activation; `ea0bff2e` prevented defenders from activating enemy towns; `913ecdf6` added diagnostics. | Do not optimize town AI wakeups solely by reducing scans. Preserve capture-driven wake signals, defender-origin tagging, and diagnostics for false negatives/false positives. | confirmed |
| Client marker/UI loops are locality-sensitive and easy to over-optimize. | Marker cluster includes `9a550b7a` reverting "Do group leaders need actually global marker vars? Only few know.", `9c72a281` fixing marker tracking after cache optimization, `951e72cb` fixing stale squad markers after disconnect, `332874fd` fixing town SV visibility leaking to both teams. | Treat marker variables as client-local unless source proves a shared-state need. Validate disconnect, side visibility, cache invalidation and player-led AI labels after marker performance edits. | confirmed |
| Reverts mark negative knowledge: some plausible improvements were too risky or incomplete. | `97da2aeb` and `993e8ed5` reverted configurable accelerated day/night cycle; `9424f0c8` reverted `Marty_repair_camp_menu`; PR #9 "Add endgame music" was closed unmerged; PR #1/#2 merge-separated-codebase attempts were closed. | Before reviving reverted/closed work, inspect why it failed in current source and stage it as a small feature branch with smoke evidence. Do not resurrect old branch code wholesale. | confirmed |
| Branch names expose abandoned or risky experiments. | Upstream branches include `A3_*`, `Arma2Warfare_GPT`, `oldMasterBranch`, `0=1_*`, `remove_wasp_change_wheel_car_simulator`, `AntistackJustMonitoring`, `AntiStackV6`, many dated `dev_*`/`v*` branches. | Use branches as search leads only. Treat A3/dev/old branches as non-authoritative unless current `master` or a merged PR confirms behavior. | likely |
| Shared helper fixes often affect AI, players, HC/delegation and generated missions together. | `782c9b8a` fixed town vehicle crews by changing `Common_CreateTeam.sqf` in both Chernarus and Vanilla; `ea0bff2e` marked resistance town defenders across common creation, client delegation, server delegation and town-defense operation files. | When touching shared creation/delegation helpers, audit all call families: server-created town AI, client-delegated AI, static defenses, generated mission copies and player purchase analogues. | confirmed |

## Lesson Records

### Supply Run Remote Activation Became A Three-Step Fix

- Source evidence: PR #10 body says the exploit allowed a player to keep a supply truck next to a remote command center and activate the mission remotely; merge `97dfff26`, commits `65fa3332` and `0542edf8`, file `Client/Module/supplyMission/supplyMissionStart.sqf`.
- Affected subsystem: supply missions, economy, command-center proximity, client action gating.
- What happened: the first fix blocked the remote activation exploit, then detection reliability was improved, then PR #11 added player feedback when the supply truck was too far away.
- Why it matters: local action checks were being used as gameplay authority for an economy reward path.
- Do differently: future supply work should make the server accept/reject mission start from trusted state and keep client checks as UX only.
- Confidence: confirmed.
- Follow-up: current wiki already tracks server-owned loaded/tracking state in [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook).

### JIP Must Be A First-Class Validation Gate

- Source evidence: PR #12 body says the too-far notification fired when a player spawned in-game; commit `b76f9645` changed the same supply start file in Chernarus and Vanilla. Heavy attack mode later moved main logic server-side in `b02782f1` explicitly "to avoid JIP issues".
- Affected subsystem: supply missions, attack wave/heavy attack, client init/update loops.
- What happened: features that looked correct for already-connected players needed follow-up patches for join-in-progress.
- Why it matters: OA mission state is a mix of PVEH events, missionNamespace state, local UI loops and server callbacks. New clients do not automatically replay intent.
- Do differently: every new public variable or action-driven feature should document JIP semantics and include a late-join test.
- Confidence: confirmed.
- Follow-up: add explicit JIP smoke rows to feature playbooks when implementation work starts.

### Performance Optimizations Need Diagnostics And Gameplay Counters

- Source evidence: `88e0749a`, `ff1ea838`, `62becdda`, `49aa1e53` created/expanded performance audit tooling; `4aaa814a` and `6189f3c5` optimized town/camp loops and scan budgeting while adding counters like scanned/skipped towns.
- Affected subsystem: server town loop, town AI activation, client markers/RHUD.
- What happened: upstream built measurement tools, then reduced scans, marker churn and activation spikes.
- Why it matters: blindly slowing loops can break capture responsiveness, town defense activation or markers.
- Do differently: keep an audit counter for any loop you throttle, and test quiet-map FPS plus active-town behavior.
- Confidence: confirmed.
- Follow-up: preserve performance audit parameter documentation and analyzer workflow in the runtime/performance pages.

### Town Defense Wakeups Are Not Just Proximity Scans

- Source evidence: `a20a5a0f` restored activation from capture scans; `84b1b684` restored pre-capture town defense activation; `ea0bff2e` ignored units/vehicles/groups marked as resistance town defenders so they do not wake enemy towns.
- Affected subsystem: town AI, static defenses, capture FSM, delegation.
- What happened: earlier scan-budget changes needed follow-up fixes so attacked towns still woke reliably and defender units did not create false activations.
- Why it matters: the town AI activation path balances CPU cost against visible fairness in PvE/TvT capture fights.
- Do differently: when optimizing town AI, keep separate tests for remote player-led attacks, pre-capture defenders, occupied-town vehicles, and defender bleed into nearby towns.
- Confidence: confirmed.
- Follow-up: add town-defense diagnostics to any future town AI smoke plan.

### Marker Visibility And Locality Are Easy To Break

- Source evidence: `9a550b7a` reverted an experiment about global group-leader marker vars; `9c72a281` fixed marker tracking after marker cache optimization; `951e72cb` fixed stale markers after disconnect; `332874fd` fixed town SV marker visibility leaking to both teams.
- Affected subsystem: client map markers, player/unit labels, town supply-value marker visibility.
- What happened: marker work went through repeated attempts around scope, cache, side visibility and disconnect cleanup.
- Why it matters: marker bugs can leak side information or leave stale UI state without obvious server errors.
- Do differently: marker changes need side-specific visibility checks and reconnect/disconnect cleanup tests, not just FPS or UI appearance tests.
- Confidence: confirmed.
- Follow-up: keep marker loop changes routed through [Client UI/HUD/menus](Client-UI-HUD-And-Menus) and [Public variable channel index](Public-Variable-Channel-Index) where networked.

### Reverted Or Closed Work Is A Warning Label

- Source evidence: `97da2aeb` and `993e8ed5` reverted configurable accelerated day/night cycle; `9424f0c8` reverted `Marty_repair_camp_menu`; PR #9 "Add endgame music" closed unmerged; PR #1/#2 codebase-merge attempts closed unmerged.
- Affected subsystem: day/night runtime, repair camp actions, endgame media, repository merge strategy.
- What happened: some apparently useful features were backed out or abandoned.
- Why it matters: reverts often indicate runtime, UX, merge-shape or deployment problems not visible from current files alone.
- Do differently: if reviving reverted work, treat the old branch as a design sketch. Rebuild from current source with a small diff and include the missing validation that the original lacked.
- Confidence: confirmed for reverts/closures; speculative for exact failure cause when no PR comment explains it.
- Follow-up: inspect RPT/server notes or owner memory before reviving repair-camp or accelerated day/night variants.

### Old Branches Are Leads, Not Authority

- Source evidence: upstream branch list contains A3 branches (`A3_v20240123`, `A3_0=1_new`), experimental branches (`Arma2Warfare_GPT`, `AntistackJustMonitoring`, `AntiStackV6`), and many dated `dev_*`/`v*` snapshots.
- Affected subsystem: repository archaeology, mission-copy divergence, Arma 2 OA compatibility.
- What happened: upstream preserved many experiments and snapshots that are not merged into current protected `master`.
- Why it matters: an AI agent can easily cite or copy stale branch code that conflicts with OA 1.64 or current mission structure.
- Do differently: prefer current upstream `master`, merged PRs, and current rayswaynl source. Use unmerged branches only to generate questions or locate abandoned ideas.
- Confidence: likely.
- Follow-up: if a branch becomes implementation-relevant, compare it to current `master` with file-level diffs and note whether it is A3-only, old folder layout, or current OA-compatible SQF.

## Practical Rules For Future AI Agents

1. Start every upstream-history claim with evidence: PR number, commit hash, branch name, file path or a short quoted PR/commit phrase.
2. Separate `confirmed` from `likely`: commit messages and PR bodies prove developer intent; branch names only suggest it.
3. For supply/economy work, assume client-side action checks are UX until the server recomputes the final effect.
4. For JIP-sensitive work, write the late-join behavior before proposing code.
5. For town AI/performance work, preserve gameplay wakeup signals and diagnostics while reducing scan cost.
6. For marker/UI work, test side leakage, stale markers and disconnect/reconnect behavior.
7. For generated missions, document Chernarus and Vanilla/Takistan evidence separately.
8. For reverted or closed work, do not copy it forward without a fresh current-source design and smoke plan.

## Continue Reading

Evidence index: [Upstream Miksuu commit intel](Upstream-Miksuu-Commit-Intel) | Risks: [Feature status register](Feature-Status-Register) | Runtime: [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas) | Supply: [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook)
