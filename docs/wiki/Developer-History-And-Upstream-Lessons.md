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

## Deep History Addendum: 2018-2024

This second pass goes further back than the first snapshot. It shows that several "modern" risks are old recurring maintenance patterns, not new accidents.

| Lesson | Older evidence | Affected subsystem | What happened | Future rule | Confidence |
| --- | --- | --- | --- | --- | --- |
| Early imports are balance/config baselines, not design proof. | `558537c3` initial commit, `bb9cd85e` import Chernarus, `f7bc288c` import rest of maps, then 2018 balance edits such as `6e120ebf` ICBM enabled on all maps and `b66d2681` max supply limit. | repository baseline, map copies, balance constants | The earliest history is an import plus immediate balance/config changes by mixed authors. | Treat 2018 commits as provenance and baseline only; do not infer current intent without later current-source evidence. | confirmed |
| AntiStack/RequestJoin has been brittle since the 2022 rewrite. | `09131233` "Fix HORRIBLE typo in command", `841d16af` changed `CONNECTED_AT_LAUNCH` from bool to player side, `88a2ef49` "Fix RequestJoin logic/semantics", `8bf294ac` teamswap special-case variable fix. | AntiStack, join flow, teamswap | Join eligibility and launch-state variables needed repeated semantic fixes immediately after introduction. | Before touching AntiStack, map the exact variable type and lifecycle; add join-at-launch, late-join, teamswap and disabled-AntiStack tests. | confirmed |
| Database-backed skill/team logic needs type and load-shedding guards. | `a103b538` async queries, `448b1d85` string-to-integer database crash, `25cec171` limited retry attempts, `4f9c21d7` fixed double team-score requests taking a toll on the DB, `b32babc7` reverted `AntistackV6`. | AntiStack DB, Discord/status integration, player skill | Async DB and score logic repeatedly hit type, polling, retry and rollback issues. | Treat DB/extension responses as untrusted strings; clamp retries, parse types explicitly, and keep monitoring-only rollout paths. | confirmed |
| Public-variable payload shape mistakes are old and recurring. | `680f4191`/`8036db59` moved side-supply updates server-side, then `33143928` found publicVariable wrapping sent var into an array, `591a217f` fixed wrong PVEH array indices, `17b5fb6e` fixed flawed client PVEH logic. | side supply, PVEH/PVF, economy | Server migration was directionally right but still needed several payload-shape fixes. | Any server-authority migration must document exact PV/PVEH payload shape and test both sender and receiver parameter arrays. | confirmed |
| Arma 2 OA compatibility failures predate the current docs push. | `2a62eaa0` fixed A3 `createGroup` syntax, `c7b17c70` says "Replace name with typeOf (Arma 2 syntax :D)", later commits repeatedly fix `isNil`, syntax and missing semicolons. | SQF compatibility, construction, generated files | A3 syntax and modern assumptions have already broken mission scripts. | Keep OA 1.64 command/version checks in the review path; never copy A3 branch snippets without compatibility proof. | confirmed |
| Task system removal was intentional and propagated across terrains. | `b8c66b41`/`a3e56ca9` removed Warfare task system in 2023; `f61f7222` removed task system entirely in 2024; `4881e0d5` removed it from all terrains. | task UI, town-capture notifications, generated missions | The task system was not merely forgotten; it was removed repeatedly across mission copies. | Do not revive tasks as a small UI toggle. Rebuild as a fresh JIP-safe feature or keep it removed. | confirmed |
| Copy/paste and generated-map workflows repeatedly caused boot or syntax failures. | `62279d8e` ignored `version.sqf`; `081c1dc4` added copypasted untested modded terrain files; `c312b0ec` added missions with "copypaste method without running the python script"; `812e9596` removed Tasmania because it was bugged and broke clean-repo loads due to ignored `version.sqf`. | LoadoutManager, version.sqf, modded maps | Manual copy workflows and ignored generated files caused clean checkout and map-load failures. | Prefer LoadoutManager/generator paths; for every manual map copy, test a clean checkout and generated `version.sqf` presence. | confirmed |
| LLM/GPT output was useful but produced guesswork and syntax debt. | `da2fc886` "Add first iteration by GPT prompt", `e699cf30` "Add merged Skill_Init arrays with GPT (untested)", `a0b891f4` adds `Arma2Warfare_GPT` system prompt, `24bddb66` fixes "prompting failures/guess work by the LLM". | docs, generated guides, code snippets | Upstream used GPT for scaffolding, comments, prompts and guides, then had to fix guessed levels/syntax. | Use LLM output as a draft only; require source verification for levels, class names, syntax and mission semantics. | confirmed |
| Construction refactors can reintroduce duplication for safety. | `1ea99ebb` moved `HandleSpecial` away from construction-site execVM thread; `b6a12aec` refactored duplicate code away from small/medium construction scripts; `77a07bc0` reverted that duplicate-code refactor. | construction, RequestStructure, server threading | A neat dedupe was reverted, likely because construction-side effects needed local script context or timing. | Do not remove duplication in construction paths unless RequestStructure, small-site and medium-site execution context are all tested. | confirmed |
| Removed/bugged maps are negative knowledge. | Tasmania branch history includes boundary disable/fix attempts (`fb04d70a`, `3104a07f`, `72a86849`), skip-update commit `50443d75`, and final removal `812e9596`. | modded maps, terrain generation | Tasmania was tried, patched, skipped, then removed. | Treat removed map folders as hostile evidence, not dormant targets. Re-adding a map requires terrain-specific position/version generation and clean-load smoke. | confirmed |
| Map/UI helper messages need channel discipline. | `95a12305` used Marty's marker function to fix UAV marker messages appearing in global chat; `cbea9f36`, `358e9e6b`, `d71a9d5d` moved teamstack messages through group/command/cutText variants. | UAV markers, AntiStack messaging, chat/UI | Older history repeatedly adjusted who saw messages and where they appeared. | For any notification, specify channel, audience, locality and JIP behavior before implementation. | confirmed |
| FPS/view-distance helpers can fight map-open UI state. | `a388f073` added automatic view-distance by FPS target; `7e3b9f4c` fixed the script starting while the map was open, causing very low view distance and high FPS after closing map; `6eb1cbfa` fixed tooltip range values. | client FPS optimizer, map UI, view distance | A performance helper accidentally reacted to map-open state and left bad runtime settings. | FPS optimizer logic must ignore map/menu contexts or restore state after UI transitions. | confirmed |
| AntiStack is a generation of experiments, not one stable module. | Branches/commits include `upstream/DisableAntiStackByNumbers`, `upstream/AntistackV6`, `upstream/AntistackJustMonitoring`, `6f1d7af5` monitoring-only, `45cb5192` "Revert all the antistack stuff", `8e2d585b` "All the antistack remains gone, forever", and later `a201f58b` reintroduction. | AntiStack, RequestJoin, DB score balancing | Enforcement, monitoring, removal and reintroduction all happened in history. | Document AntiStack by generation and rollout mode; keep teamswap/session validation separate from skill balancing. | confirmed |
| Disabling AntiStack must not disable teamswap protection. | `2624e943` added an AntiStack disable mission parameter, then `6b34b46d` fixed teamswap protection when AntiStack was disabled. | lobby parameters, RequestJoin, teamswap | A broad disable switch bypassed more join validation than intended. | Name toggles narrowly and test disabled-AntiStack with teamswap, launch join and late join. | confirmed |
| Score persistence is part of AntiStack correctness. | `fc55456c` saved player score on disconnect; `b69b901e` set disconnected side to `NONE`; `8b1e220b` fixed disconnect-side logic; `8b8ea8e7` stopped score DB update loops when match ends; `b31539b4` and `c9a93263` moved score logic server-side. | score, DB persistence, AntiStack team totals | Stale side values, duplicate update loops and score authority all feed team-balance inputs. | Treat score mutation and disconnect cleanup as AntiStack dependencies, not separate chores. | confirmed |
| Client init flags are lifecycle contracts. | `3ff02aea` on `0=1_InitClientFix` moved `clientInitComplete = true` to the true end of `Client/Init/Init_Client.sqf` after a merge lost the fix. | JIP, client init, PV/UI setup | The flag could be set before the client had finished registering state. | Place init-complete flags after PV registration, UI release, player variables and town/map setup; diff generated maps for placement. | confirmed |
| UI globals and nil/null mistakes were recurring client bugs. | `c6d2539e` replaced global `MenuAction` with private `_menuAction`; `5b056013` added gear-template `isNil` guards; `5de4d1a2` changed CoIn preview checks from `isNull` to `isNil`. | buy units, gear templates, CoIn construction UI | Long-running UI loops reused global state and confused undefined variables with null objects. | Keep dialog action state private; validate list row data before namespace lookups; use `isNil` only for maybe-uninitialized values. | confirmed |
| Marker optimizations must not freeze or leak marker state. | `9795f317`/`a074319b` added marker helpers; `b7bdb70b` commented HQ wreck markers as heavily bugged; `6e5b3c50` marker caching was followed by `9c72a281` restoring marker movement; `95a12305` fixed UAV marker global-chat leakage. | markers, side visibility, AAR/team/HQ/UAV UI | Marker creation, side audience, moving-object updates and cache keys repeatedly regressed. | Centralize marker APIs; cache text/type separately from position; test JIP, side visibility, moved objects and disconnect. | confirmed |
| Branch names can be tombstones, not revival invitations. | `upstream/oldMasterBranch` tip `3a7972a2` says "Remove files from the master branch (use the Main branch)"; `upstream/RevertedTo2018Version` tip `44abda43` is only a test commit; A3 branches were later purged by `83298186`. | branch archaeology, release baselines | Some old refs are deleted snapshots, experiments or foreign-port imports. | Mine old branches for intent only; never treat tombstone/A3/debug branches as current source without revalidation. | confirmed |
| Merged work can still be negative knowledge. | PR #3 "Add increasing cost of repairing HQ" merged then `346e3be8` reverted it; PR #9 "Add endgame music" closed unmerged; `f10d5bd9` and `8d74c332` reverted bomb restriction/debug work; `31d8a06d` reverted cheaper nukes test pricing. | HQ repair, audio/endgame, bomb logic, nuke economy | Merge status alone did not mean a design survived. | Check later reverts and branch names like `Test`, `Debug`, `RevertLater` before reviving an idea. | confirmed |
| Removing a structure or system reaches AI/FSM/delegation code. | `16856ae7`, `8b7fab95`, `4e45acad` removed guerilla barracks across init, resistance FSM, HC delegation and buy-unit code; `f61f7222`/`4881e0d5` removed task code across terrains but later `e9685b04`/`1d017dec` still cleaned residue. | guerilla barracks, task system, HC AI, camera/spectator | Removals required follow-up outside the obvious init file. | Grep client, server, camera, FSM, HC delegation and generated map copies before declaring a feature removed. | confirmed |
| Supply performance fixes can accidentally switch authority context. | `7bc4b7ac` was reverted by `3c2efb8a`; `008ac5aa` was reverted by `33fb2676`; history notes server-side supply logic checking `getPos player` instead of the truck position. | supply missions, runtime performance, locality | Optimization attempts moved checks but used the wrong implicit object context. | Optimize around authoritative mission objects, not globals like `player`; dedicated-server and JIP tests are mandatory. | confirmed |

### Deep-History Follow-Ups

- Add AntiStack-specific smoke cases to future DB or team-balance PRs: launch join, late join, disabled AntiStack, teamswap, DB unavailable and double-request prevention.
- Treat `version.sqf` and generated mission files as a release gate, because older clean-repo failures were tied to ignored/generated mission metadata.
- Keep the Task System listed as intentionally removed unless a new owner writes a JIP-safe replacement design.
- When reviving old branch ideas, check whether they came from `A3_*`, GPT/LLM, copied terrain or reverted construction/map branches before trusting the snippet.
- Add clean-checkout bootstrap and generated-output validation to release notes before map or LoadoutManager changes.
- Treat marker, UI and client-init fixes as lifecycle/API contracts: do not optimize them without preserving audience, object position, JIP and init-complete semantics.
- For old branches, capture the branch family first (`A3_*`, `AntiStack*`, `Debug`, `Test`, `oldMasterBranch`, `RevertedTo2018Version`) before interpreting any commit as reusable.

## Continue Reading

Evidence index: [Upstream Miksuu commit intel](Upstream-Miksuu-Commit-Intel) | Risks: [Feature status register](Feature-Status-Register) | Runtime: [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas) | Supply: [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook)
