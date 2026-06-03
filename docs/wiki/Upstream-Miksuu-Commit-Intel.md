# Upstream Miksuu Commit Intel

This page indexes source-backed upstream history from `Miksuu/a2waspwarfare` for documentation and future implementation planning. It is intentionally evidence-first: use it to find proven developer intent, then re-check current source before patching.

Research snapshot: upstream `master` at `8bcc42b1` (2026-06-02), GitHub PRs #1-#12, branch list from GitHub, and local fetched upstream refs.

## PR Ledger

| PR | State | Merge / head evidence | Developer-intent clue | Lesson |
| --- | --- | --- | --- | --- |
| #1 `Merge separated codebases` | Closed unmerged | head `MergeWithMiksuu`; body calls it a huge merge between separated codebases. | Large merge shape was not accepted. | Avoid wholesale branch imports; split current-source patches. |
| #2 `Merge separated codebases (with correct folder structure)` | Closed unmerged | head `MergeWithMiksuu`, base `MergeFromEzcoo`. | Folder-structure correction still did not land. | Repo layout and mission-copy shape matter as much as code content. |
| #3 `Add increasing cost of repairing HQ` | Merged | merge `fbf988ed` into `v25102023`. | Early economy/repair-cost tuning. | Repair/economy changes belong in balance + authority review. |
| #4 `Spawn new players on the latest built factory` | Merged | merge `e649beae`. | Spawn placement was feature-worthy enough to isolate. | Spawn/JIP behavior deserves dedicated tests. |
| #5 `Add supply runs (Support class)` | Merged | merge `26f9fa3e`; files include `Client/Module/supplyMission/*`, `Server/Module/supplyMission/*`, side-supply functions and town init. | Supply runs landed as a broad client/server/economy feature. | Treat supply as cross-cutting, not a client action only. |
| #6 `Buy Units menu improvements` | Merged | merge `4e248dff`; title mentions hints and disabling driver slot by default. | UI affordance and AI driver behavior were coupled. | Buy-menu UX changes can alter AI/runtime defaults. |
| #7 `Commander assist hint after vote` | Merged | merge `7b55e7b7` recorded by GitHub; files include commander/endgame UI and sound resources. | Commander UX needed post-vote guidance. | Commander flows need clear feedback, but authority remains server-side. |
| #8 `Merge countdown kick` | Merged | merge `657dbe44`; commit `deed0184` increases countdown kick to 2 minutes. | Intro/welcome timing affected kick behavior. | Timing constants should be tested with intro/JIP flow. |
| #9 `Add endgame music` | Closed unmerged | head `MergeToEzcooV3`; files include endgame music/sound changes. | Media/UI change was not merged as that PR. | Closed feature PRs are not current behavior. |
| #10 `Supply run remote activation glitch fix` | Merged | merge `97dfff26`; PR body names remote truck/remote CC exploit. | Supply run exploit was real and player-facing. | Server-side validation is required for economy-bearing supply actions. |
| #11 `Add "supply truck too far" notification` | Merged | merge `8164cc33`; commit `86c8f89c`; Chernarus + Vanilla file changed. | UX feedback followed exploit guard. | Add feedback, but check JIP and spawn contexts. |
| #12 `Fix "supply truck too far" notification being run during JIP` | Merged | merge `86ec28d6`; commit `b76f9645`; PR body calls the fix "a bit hacky". | The PR #11 UX guard regressed JIP spawn. | Any action-condition notification needs late-join smoke. |

## Commit Clusters

### Supply Missions And Economy

| Evidence | Files / area | Finding |
| --- | --- | --- |
| `d086863c` "Add supply mission (still missing mission.sqm class descriptions)" | supply mission client/server modules | Initial supply run work landed before all mission metadata was complete. |
| `65fa3332` "Fix remote supply truck glitch" and `0542edf8` "Improve reliability of supply truck detection" | `Client/Module/supplyMission/supplyMissionStart.sqf` in Chernarus and Vanilla | Client-side start detection was exploit-sensitive and needed follow-up reliability changes. |
| `b76f9645` "Fix 'supply truck too far' notification being run during JIP" | same start file | UX checks can accidentally fire during spawn/JIP lifecycle. |
| `db317706` "Player is not defined on server -> move reward fnc call to client" | supply completion message/server active file | Server/client identity assumptions caused a reward-flow correction. |
| `6861e310` "Add score for supply run only to the player having completed it" | `supplyMissionCompletedMessage.sqf` | Reward targeting needed correction to avoid broad awards. |
| `87cef74b`, `78d86810`, `994150da` | supply amount modifiers/upgrades/Takistan | Supply reward math changed over time and had to be propagated. |

### JIP / Client Lifecycle

| Evidence | Files / area | Finding |
| --- | --- | --- |
| `b02782f1` "Move main logic of heavy attack mode to server to avoid JIP issues" | `Common_AttackWaveActivate.sqf`, `Server_AttackWave.sqf`, `updateclient.sqf` | Server-owned main logic was chosen after JIP complexity emerged. |
| `a9044821` "Refactor logic of JIP during heavy attack feature" | `Init_Client.sqf`, `Server_OnPlayerConnected.sqf`, `AttackWave.sqf` | Join flow needed explicit wiring for active attack waves. |
| `6eb09dc3` "Make JIP players spawn at HQ or factories only" | client lifecycle/spawn paths | Spawn behavior was tightened for late joiners. |

### Performance And Town AI

| Evidence | Files / area | Finding |
| --- | --- | --- |
| `88e0749a`, `ff1ea838`, `62becdda`, `49aa1e53` | performance audit/analyzer | Diagnostics preceded major performance work. |
| `4aaa814a` | `server_town_camp.sqf`, `server_town_ai.sqf`, town-unit creation/delegation | Server loop and town-AI optimizations intentionally reduced scans and marker work. |
| `6189f3c5` | `server_town_ai.sqf` | Scan budgeting added per-cycle and per-town cadence. |
| `a20a5a0f`, `84b1b684`, `ea0bff2e`, `913ecdf6` | `server_town.sqf`, `server_town_ai.sqf`, delegation/static-defense helpers | Town defense activation needed restoration, defender filtering and diagnostics after performance changes. |

### UI, Markers And Locality

| Evidence | Files / area | Finding |
| --- | --- | --- |
| `9a550b7a` reverts `1b23132d` "Do group leaders need actually global marker vars? Only few know." | `Client/FSM/updateteamsmarkers.sqf` | Marker variable scope is fragile and was reverted quickly. |
| `9c72a281` | marker cache optimization | Cache changes broke unit marker tracking. |
| `951e72cb` | player squad markers | Disconnect cleanup needed explicit repair. |
| `332874fd` and `9a963c19` | town SV marker visibility | Side-specific marker visibility leaked and needed fixes. |
| `a5fc24f4` | WF menu action refresh | Vehicle transitions could hide menu actions until explicitly refreshed. |

### Negative Knowledge

| Evidence | Affected area | What not to assume |
| --- | --- | --- |
| `97da2aeb`, `993e8ed5` revert accelerated day/night cycle | day/night runtime, parameters, server init | Configurable acceleration was not safe as first merged. |
| `9424f0c8` reverts `Marty_repair_camp_menu` | repair camp actions, unit init, skill apply | Repair-camp menu revival needs new validation. |
| PR #9 closed unmerged | endgame music and sound changes | Closed media/UI PR is not baseline behavior. |
| Branch families `A3_*`, `dev_*`, `0=1_*`, `oldMasterBranch` | broad repo archaeology | Branch presence is not authority; use current `master` and merged PRs first. |

## Current Documentation Impact

- [Developer history and upstream lessons](Developer-History-And-Upstream-Lessons) is the narrative lesson page built from this evidence.
- [Feature status register](Feature-Status-Register) should keep supply/JIP/town-AI/marker/reverted-feature risks visible when they are still broken, partial or risky in the rayswaynl source.
- [AI Assistant Guide](AI-Assistant-Guide) should route future agents here before they revive old branches or copy unmerged upstream work.

## Follow-Up Investigation

- Compare reverted accelerated day/night commits with the later hybrid day/night synchronization line to capture the exact failure mode.
- Inspect RPT/server notes, if available, for why `Marty_repair_camp_menu` was reverted.
- Build a branch-family index for high-value unmerged branches only after an owner asks to revive one.
