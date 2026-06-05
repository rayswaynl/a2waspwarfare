# Old WarfareBE Performance Comparison

This page compares the old BennyBoy WarfareBE source against current Wasp for FPS-relevant architecture. It is an archaeology report, not a gameplay patch.

## Short Answer

Old WarfareBE is useful as a baseline and as a sanity check, but it does not contain a magic town-AI architecture that Wasp should port wholesale. Old BE already has town `nearEntities` activation scans, town AI spawn/despawn, static-defense gunners, public-variable dispatch, cleanup collectors, AI teams, support systems and client marker loops.

The practical differences are more specific:

- Old BE's default player AI cap is lower, and it has no commander `+10` purchase bonus.
- Current Wasp has a broader runtime surface: HC routing, AntiStack, supply-mission traffic, Discord/extension stats, PerformanceAudit, server-FPS publishers, map cleaners/restorers, RHUD and richer marker logic.
- Current Wasp also has optimizations old BE did not have: global town loops with cooperative sleeps, town creation sleeps, delegated town AI avoiding global per-unit init, resistance-only static-defense spawning, HC delegation paths and client marker caches.
- The first FPS step should not be "set every player to 10 AI and call it done." Test a lower normal-role cap, keep Soldier/commander role identity deliberately, and pair that with active-town/static-defense cleanup and HC verification.

## Evidence Base

| Source | Ref |
| --- | --- |
| Old BennyBoy repository | [`BennyBoy-/ArmA2_WarfareBE`](https://github.com/BennyBoy-/ArmA2_WarfareBE), local clone at commit `aeb71bb` (`Updated nfo`) with initial upload `2fcd64d`. |
| Old mission scope | `readme.nfo` and `version.sqf:18-19` identify the main branch as `Warfare Benny Edition V2.073 Lite OA - Takistan`, `WF_MAXPLAYERS 32`. Treat findings as Takistan Lite OA scope unless another release package is checked. |
| Current Wasp source | `rayswaynl/a2waspwarfare` local branch `docs/developer-wiki-index` at commit `a2affb7d`; source mission path `Missions/[55-2hc]warfarev2_073v48co.chernarus`. |
| Current upstream context | [`Miksuu/a2waspwarfare`](https://github.com/Miksuu/a2waspwarfare) documents the modern mission as a Warfare derivative with added modules such as Discord integration. |
| Engine claim used here | BI wiki [`setViewDistance`](https://community.bohemia.net/wiki/setViewDistance), which describes scripted view distance and includes Arma 2 OA notes. Arma 3-only command assumptions are not used as OA authority. |

Uncertainty notes:

- This is static source comparison. It ranks test candidates; it does not prove live FPS without RPT/server/client measurements.
- Old BE main branch is Takistan. Chernarus town layout, town count and Wasp custom content can change runtime cost even when SQF shape looks similar.
- Some current docs contain branch-era findings from other agents; this page cites concrete current source lines where making a direct claim.

## Lag Taxonomy

| Category | What to separate during testing |
| --- | --- |
| Server FPS | AI simulation, active town count, town/static gunners, cleanup bursts, AntiStack/DB loops, supply scans, HC fallback, PerformanceAudit/logging overhead. |
| Client FPS | Rendered AI/vehicles near the player, view distance, local delegated AI, RHUD, map/GPS marker loops, effects/projectiles and open UI dialogs. |
| Network traffic | PVF calls, direct public variables, marker/message broadcasts, client supply queries, combat marker state writes, server-FPS broadcasts. |
| AI simulation | Player followers, AI teams, town occupation/defenders, town patrols, static-defense gunners, supports and purchased vehicles. |
| Perceived lag | Delayed buy-menu/UI response, desync, late markers/messages, hosted-server hitches and network bursts can feel like FPS loss but need separate evidence. |

## Discord Summary Table

| Area | Old behavior | Current Wasp behavior | Expected FPS impact | Evidence | Recommendation |
| --- | --- | --- | --- | --- | --- |
| Player AI caps | Lobby default player cap `12`; fallback `14`; Soldier gets fixed `+6`; no commander `+10`. | Lobby default `15`; fallback `16`; Soldier uses `ceil(1.5 * cap)`; commander team gets `+10`. | High when many players fill squads. | Old `Rsc/Parameters.hpp:16-20`, `Common/Init/Init_CommonConstants.sqf:163,183`, `Client/Module/Skill/Skill_Init.sqf:43-44`, `Client/GUI/GUI_Menu_BuyUnits.sqf:108-124`; current `Rsc/Parameters.hpp:62-67`, `Common/Init/Init_CommonConstants.sqf:243,263`, `Client/Module/Skill/Skill_Init.sqf:48-49`, `Client/GUI/GUI_Menu_BuyUnits.sqf:118-132`. | Test normal-role cap `8-10`, Soldier cap/bonus separately, commander bonus reduced or role-aware. |
| AI teams | Default enabled; AI group size default `10`; JIP preserve default off. | AI teams lobby default off; AI group size default `4`; fallback still enables AI teams if params are missing. | Medium, depends on lobby params and AI team usage. | Old `Rsc/Parameters.hpp:10-14,22-32`; current `Rsc/Parameters.hpp:56-60,68-78`, fallback `Common/Init/Init_CommonConstants.sqf:92-95`. | Do not blame only player AI; log AI teams separately in tests. |
| HC delegation | Client delegation only, default disabled. No HC init split. | HC detection/init and AI delegation mode `2`; town/static paths can use HC, otherwise server fallback. | High upside if HC works, high server cost if it silently falls back. | Old `Rsc/Parameters.hpp:4-8`, `initJIPCompatible.sqf:26-42`; current `Rsc/Parameters.hpp:50-55`, `initJIPCompatible.sqf:52-78,164-171,214-238`, `Headless/Init/Init_HC.sqf:4-15`, `Server/FSM/server_town_ai.sqf:157-180`. | Test with HC present and absent; record HC connection, active HC-owned town/static AI and server FPS. |
| Town activation | Per-town FSMs start from each town; scans include `Air`; inactive timeout `300`. | Global town loops start once; town AI scans ignore aircraft; inactive timeout `90`; audit counters. | High during active-town bursts; current has better loop shape but richer content. | Old `Common/Init/Init_Town.sqf:127-131`, `Server/FSM/server_town_ai.fsm:122-142,614-615`; current `Common/Init/Init_Town.sqf:141-145`, `Server/Init/Init_Server.sqf:509-515`, `Server/FSM/server_town_ai.sqf:1-19,84-93,191-251`. | Tune active-town budgets and low-SV group counts before rewriting loops. |
| Town group counts | Occupation groups by supply value: `1` at SV `<10`, `2` at `10-20`, up to `8`; defender groups by supply value. | Occupation groups are upgrade-aware and often heavier at low SV: `2` at `<10`, `4` at `10-20`; defenders are town-type based. | Medium to high, especially early-town activations. | Old `Server_GetTownGroups.sqf:23-73`, `Server_GetTownGroupsDefender.sqf:23-73`; current `Server_GetTownGroups.sqf:22-47,140-143`, `Server_GetTownGroupsDefender.sqf:22-79`. | Test tiny/small-town activation with reduced low-SV groups and compare capture feel. |
| Static defenses | Spawns static objects for any side with configured kinds; mans mortars and defenses server-side. | Static objects and gunner operation exit unless side is guer/resistance; HC delegation and sleeps/audit exist for static gunners. | Medium; current already avoids occupied-town static spam. | Old `Server_SpawnTownDefense.sqf:17-45`, `Server_OperateTownDefensesUnits.sqf:16-58`; current `Server_SpawnTownDefense.sqf:17-45`, `Server_OperateTownDefensesUnits.sqf:24,37-78,115-118`. | Preserve resistance-only gate; add measurements for stale gunners/statics and safe despawn. |
| Cleanup | Garbage collector every 30 seconds; empty vehicle collector checks every second; bodies/vehicles use timeout. | Garbage/empty collectors run with 0.5 sleeps and audit; extra dropped item, crater, ruin, mine and building restorer loops. | Mixed: extra loops cost time, but stale-object deletion can help. | Old `Server/Init/Init_Server.sqf:434-457`, `Server_TrashObject.sqf:19-23`; current `Server/Init/Init_Server.sqf:535-562`, `server_collector_garbage.sqf:4-32`, `emptyvehiclescollector.sqf:4-30`, cleaners/restorers. | Treat cleaners as measurement-first; do not disable cleanup without object-count evidence. |
| Public variables | Same dynamic PVF family: compile `CLTFNC/SRVFNC`, add PVEHs, `Call Compile Format` send wrappers. | Same PVF family plus more commands and direct PV channels. | Medium network/perceived-lag risk under load. | Old `Common/Init/Init_PublicVariables.sqf:9-48`, `Common_SendToServer.sqf:14-18`; current `Init_PublicVariables.sqf:9-54`, `Common_SendMessage.sqf:37-38`, `Common_CreateMarker.sqf:80-83`, `Init_Client.sqf:759-768,960-962`. | Keep PVF dispatcher hardening; measure direct broadcast rates during busy fights. |
| Client markers/HUD | Old town marker loop writes every 5 seconds; team marker loop every 1 second without current map/GPS gating. | Town/team marker loops are cached/gated; RHUD loop runs every second and audits. | Low to medium client FPS/UI cost; likely below nearby AI/render load unless markers flood. | Old `updatetownmarkers.fsm:38,56-57,80`, `updateteamsmarkers.fsm:49,63-75,100`; current `updatetownmarkers.sqf:14-30,103-134`, `updateteamsmarkers.sqf:45-56,158-224`, `Client_UpdateRHUD.sqf:181-201,367-369`. | Do not port old marker loops back. Keep current caches; test RHUD/map open states separately. |
| View distance | Initial `setViewDistance 1000`; lobby max/default `5000/4000`. | Initial `setViewDistance 3500`; lobby max/default `6000/6000`. | Mostly client/render, but BI notes view distance also affects how far units can know about other units. | Old `initJIPCompatible.sqf:42`, `Rsc/Parameters.hpp:367-371`; current `initJIPCompatible.sqf:78`, `Rsc/Parameters.hpp:363-367`; BI [`setViewDistance`](https://community.bohemia.net/wiki/setViewDistance). | Include view distance in client/server test matrix; do not treat it as a substitute for AI/town budgets. |
| Integrations/support modules | Old has NEURO, UPSMON and optional secondary missions. | Current adds GlobalGameStats extension, AntiStack, AFK, supply mission queries, PerformanceAudit and server-FPS broadcasts. | Usually low cadence individually, but additive. | Old `Server/Init/Init_Server.sqf:66-70,473-480`; current `Server/Init/Init_Server.sqf:66-95,298,577-608`, `GlobalGameStats.sqf:5-24`, `serverFpsGUI.sqf:1-9`, `monitorServerFPS.sqf:1-8`. | Test ON/OFF where parameters exist; remove duplicate low-value broadcasts after consumer mapping. |

## What Old BE Did Differently

### AI Counts And Squad Caps

Old BE's default values are friendlier to FPS in normal play:

- `WFBE_C_PLAYERS_AI_MAX` lobby default is `12` and fallback is `14`.
- Soldier gets `WFBE_C_PLAYERS_SKILL_SOLDIER_UNITS_MAX = 6` added to the player cap.
- The buy menu scales the cap by barracks upgrade but does not add a commander bonus.

Current Wasp:

- `WFBE_C_PLAYERS_AI_MAX` lobby default is `15`, with a fallback of `16`.
- Soldier changes the cap to `ceil(1.5 * base)`.
- The buy menu adds `10` if `commanderTeam == group player`.

This makes the community "AI cap 10" question real, but incomplete. A flat cap of `10` lowers a major cost driver, yet it also flattens Soldier identity and does not touch town defenders, static-defense gunners, AI teams, support spawns, or stale vehicles. Better first test: normal roles at `8-10`, Soldier around `16-20`, commander bonus reduced or conditional.

### AI Delegation And HC

Old BE has AI delegation values `{0,1}` and defaults to disabled. Current Wasp adds mode `2` for HC, detects headless clients with `!(hasInterface || isDedicated)`, runs `Headless/Init/Init_HC.sqf`, and lets town/static AI delegate to HC when connected.

That is both a benefit and a risk. If HC is healthy, Wasp can outperform old BE on server FPS despite more systems. If HC is absent, overloaded, or not receiving delegated groups, Wasp falls back to server-side creation in the same paths. Every test should log "HC present, HC active, HC carrying town/static AI" rather than only "HC enabled in lobby."

### Town Activation

Old BE starts a separate `server_town.fsm` and `server_town_ai.fsm` per town. Current Wasp comments those per-town starts out and launches one global `server_town.sqf` and one global `server_town_ai.sqf` from server init.

Current Wasp's global loop is not obviously worse. It sleeps per town, sleeps between full cycles, ignores aircraft in the AI activation scan, records PerformanceAudit counters, and spreads town unit creation with `sleep 0.5`. Delegated town creation also calls `CreateTownUnits` without global per-unit init (`Client/Functions/Client_DelegateTownAI.sqf:25-27`; `Common/Functions/Common_CreateTownUnits.sqf:11-20,40-43`), while the old delegated path always passed global init through its embedded client special handler. Old BE's architecture is simpler, but it can still spawn bursts and has no audit.

The stronger current risk is content budget:

- Current occupation groups can be heavier at low supply values.
- Current defender groups are town-type authored rather than just supply-value based.
- Current fallback constants set defender and occupation to medium if missing, while current lobby occupation default remains light.

Practical candidate: test low-SV group counts and active-town concurrency before considering any town-loop rewrite.

### Static Defenses

Old BE spawns town static defenses for any side with a configured defense kind and mans both mortars and defenses. Current Wasp exits static-defense spawning and operation unless the side is `WFBE_C_GUER_ID`. That means Wasp already avoids a major "every occupied town has statics" cost.

The remaining opportunity is not "remove all statics." It is:

- count active static gunners separately from town groups;
- verify stale gunner/static cleanup after town deactivation or side changes;
- keep HC static-defense delegation tested;
- avoid deleting player-occupied vehicles or player-owned groups during despawn.

### Cleanup

Old BE has fewer cleanup/restorer loops, but that does not automatically make it better. Current Wasp adds dropped item, crater, ruin, mine and building restorer loops with long timers and audit counters. They may cost scan time, but they can also prevent stale-object buildup over long public sessions.

Use audit labels and object counts. If a cleaner shows high cycle time with low benefit, tune it. If object counts grow and FPS degrades, cleanup is part of the fix.

### Network And Public Variables

Old BE and current Wasp share the same basic dynamic PVF shape:

- register PVF function names as `CLTFNC*` and `SRVFNC*`;
- add public variable event handlers;
- send by rewriting the function name and using `Call Compile Format`.

Current Wasp has more PV commands and extra direct public variables: marker creation, side messages, supply mission active queries for each town on client init, client init readiness, server FPS and extension/stat systems. That makes "old PV code was cleaner" false, but "current network surface is broader" true. The routing comparison is nuanced: current has more registered and direct channels, but its OA server-request wrapper uses `publicVariableServer` (`Common/Functions/Common_SendToServerOptimized.sqf:1-17`), while old `Common_SendToServer.sqf:14-18` broadcast with `publicVariable`.

PVF dispatcher hardening remains a good performance and trust-boundary candidate because both old and current share the dynamic dispatch pattern, and current has more channels to exercise it.

### Client FPS And UI

Old BE is not free of client loops: town markers update every 5 seconds and team markers every 1 second. Current Wasp's marker loops are actually more careful:

- town marker text is cached and closed-map heavy refresh is deferred;
- team marker refresh is gated by map/GPS/Warfare-dialog visibility;
- RHUD runs every second, caches controls/text and emits audit labels.

Client FPS should therefore be tested around:

- nearby AI/vehicles and active towns;
- view distance and terrain settings;
- open map/GPS/WF menus;
- RHUD on/off;
- delegated client AI load;
- effects/projectiles during supports and heavy fights.

View distance is not pure myth. BI documents `setViewDistance` as rendering distance and notes that higher values can increase AI simulation/knowledge work. But view distance tuning is not the same as solving server-side AI count or town activation budgets.

## Current Wasp Systems That Add Server Cost

| System | Why it may cost server FPS | Evidence |
| --- | --- | --- |
| HC delegation/fallback | Extra routing and server fallback when HC unavailable. | `initJIPCompatible.sqf:52-78,164-171,214-238`; `server_town_ai.sqf:157-180`; `Server_OperateTownDefensesUnits.sqf:37-78`. |
| Town AI global loops | Scans all towns every cycle, spawns/despawns groups/statics. | `server_town_ai.sqf:35-57,84-93,191-251`. |
| Town capture/supply loop | Scans all towns for capture entities, network writes, supply/capture work. | `server_town.sqf:34-60,258-270`. |
| Supply missions | Compiled server module plus per-client town active queries on init. | `Server/Init/Init_Server.sqf:66-71,81,91`; `Client/Init/Init_Client.sqf:762-770`. |
| AntiStack | Optional DB/score/session loops. | `Server/Init/Init_Server.sqf:597-608`; parameter `Rsc/Parameters.hpp:546-552`. |
| Discord/extension stats | Calls extension every 60 seconds and logs. | `Server/CallExtensions/GlobalGameStats.sqf:5-24`. |
| Server FPS publishers | Two public variables every 8 seconds if both scripts run. | `Server/GUI/serverFpsGUI.sqf:1-9`; `Server/Module/serverFPS/monitorServerFPS.sqf:1-8`. |
| PerformanceAudit | Helpful RPT metrics, but every instrumented path still executes counters/logging. | `Server/Init/Init_Server.sqf:585-589`; `Common/Functions/Common_PerformanceAudit.sqf`. |
| Cleaners/restorers | World scans on timers; can be cost or benefit depending on object buildup. | `Server/Init/Init_Server.sqf:540-562`; cleaner files under `Server/FSM/cleaners`. |

## Current Wasp Systems That Add Client Cost

| System | Why it may cost client FPS | Evidence |
| --- | --- | --- |
| Many AI near client | Rendering, animation and local simulation cost; especially if client delegation is used. | Compare player/town/static AI counts with client FPS. |
| View distance | Higher default and max than old; BI notes rendering and AI knowledge/simulation implications. | Old `initJIPCompatible.sqf:42`, current `initJIPCompatible.sqf:78`, BI `setViewDistance`. |
| RHUD | Runs every second, reads stats/FPS and writes cached controls. | `Client_UpdateRHUD.sqf:181-201,205-369`. |
| Map/GPS marker loops | Cached and gated, but still do work when map/GPS/dialogs are open. | `updatetownmarkers.sqf:14-30,103-134`; `updateteamsmarkers.sqf:45-56,158-224`. |
| Direct marker/message PV events | Broadcast marker/message events can create local UI work. | `Common_CreateMarker.sqf:80-83`; `Common_SendMessage.sqf:37-38`; client marker handlers. |
| Effects/supports | Paratroops, arty, ICBM/nuke/radiation and projectile effects can hit client perception. | Support and module paths under `Client/Module`, `Server/Support`. Test by scenario. |

## FPS Opportunity Backlog

### Safe Docs/Config

| Priority | Candidate | Expected value | Notes |
| --- | --- | --- | --- |
| P0 | Publish test matrix and RPT capture checklist. | High | Needed before community claims converge on one cause. |
| P0 | Run a normal-role player AI cap pilot at `8-10`. | High | Use lobby/config first if possible; keep Soldier/commander identity explicit. |
| P0 | Document HC health checks for public tests. | High | "HC enabled" is not the same as "HC carrying AI." |
| P1 | Add view-distance guidance to community FPS docs. | Medium | Separate client FPS guidance from server AI fixes. |
| P1 | Document AntiStack and PerformanceAudit ON/OFF test presets. | Medium | Current params already exist for controlled comparisons. |
| P1 | Publish "count AI by source" scoreboard: player followers, AI teams, town groups, static gunners, supports. | High | Prevents "only bot count" and "only bandwidth" arguments. |

### Low-Risk Code Candidates

These are candidates only. This report does not make gameplay code changes.

| Priority | Candidate | Why low risk | Evidence/owner |
| --- | --- | --- | --- |
| P0 | PVF dispatcher lookup/hardening from dynamic compile to table dispatch. | Same behavior target, better trust/perf shape. | See [PVF dispatch implementation playbook](PVF-Dispatch-Implementation-Playbook). |
| P1 | Reduce duplicate server-FPS publishers after consumer mapping. | Low cadence but easy to verify. | `serverFpsGUI.sqf` and `monitorServerFPS.sqf` both publish every 8 seconds. |
| P1 | Low-SV town occupation group cap experiment behind parameter/branch. | Isolated tables; test on tiny/small towns. | Current `Server_GetTownGroups.sqf:31-47`; old baseline `Server_GetTownGroups.sqf:23-33`. |
| P1 | Static-defense stale gunner reconciliation. | Correctness plus FPS/object cleanup, if player-owned checks are safe. | `Server_OperateTownDefensesUnits.sqf:87-118`; current despawn path `server_town_ai.sqf:211-216`. |
| P2 | Supply mission init traffic throttle/cache. | Startup network reduction without changing gameplay. | `Client/Init/Init_Client.sqf:762-770`. |
| P2 | Cleaner/restorer cadence tuning only after audit evidence. | Parameterized loops; behavior preserved if values adjusted. | `Rsc/Parameters.hpp:515-543`; cleaner audit labels. |

### Risky Design Changes

| Candidate | Risk |
| --- | --- |
| Flat cap of `10` for every role and commander. | Easy FPS relief, but damages Soldier/commander role balance and does not address town/static/support AI. |
| Disable town defenders/occupation broadly. | Large FPS upside, but removes Warfare identity and changes capture pacing. |
| Remove static defenses entirely. | May improve FPS in defense-heavy matches, but current Wasp already gates town statics to resistance. |
| Rewrite global town loops back to old per-town FSMs. | Source evidence does not justify it; current loop has sleeps/audit and old still scanned/spawned. |
| HC ownership/live migration assumptions. | Must be validated against Arma 2 OA commands before using Arma 3-era locality patterns. |

### Test-Only Experiments

| Experiment | What it proves |
| --- | --- |
| Old default vs current default. | Real community experience delta, not root cause. |
| Old and current both at player AI cap `10`. | Whether player followers dominate. |
| Current cap `10` normal roles, Soldier high-AI. | Whether role-aware cap gives FPS without flattening gameplay. |
| Current HC present vs absent. | Whether HC delegation is actually reducing server load. |
| Current town defender/occupation light vs medium with same player cap. | Town-AI contribution. |
| Current low-SV group-table branch vs stock. | Town activation burst cost. |
| Static-defense active/inactive stress test. | Stale gunner/static cost and cleanup correctness. |
| View distance 1000/3500/6000 with same AI and active towns. | Client and server-side sensitivity to view distance. |
| PerformanceAudit ON/OFF and AntiStack ON/OFF. | Instrumentation/support-system overhead. |

## Comparison Test Plan

### Test Setup

Record this for every run:

- mission build/commit or PBO hash;
- old/current mission source and island;
- server hardware, dedicated vs hosted, CPU clock mode and OS;
- client hardware for each FPS sample;
- Arma 2 OA build/version and mods;
- player count and whether players are real clients, local clients, or headless clients;
- HC connected/absent, HC machine specs and RPT evidence of connection;
- lobby parameters: player AI cap, AI teams, town defender, occupation, patrols, cleanup timers, view distance, AntiStack, PerformanceAudit;
- weather/time/terrain settings and any mod loadout differences.

### Runtime Measurements

Capture at start and then every 5-10 minutes:

- server FPS (`diag_fps` source, server RPT and current Wasp server-FPS variables);
- average and low client FPS from at least three client locations;
- total AI count, split by player followers, AI teams, town groups, static-defense gunners and support/special units;
- total vehicles and empty/stale vehicles;
- active towns and active camps;
- active town static defenses and gunners;
- network symptoms: delayed messages, marker floods, JIP delay, buy-menu response, public-variable spam in RPT;
- RPT PerformanceAudit labels for `server_town`, `server_town_ai`, `createtownunits`, `town_defenses_units`, cleaners, markers and RHUD;
- view distance and whether map/GPS/RHUD is open on client samples.

### Run Matrix

| Run | Old BE | Current Wasp | Purpose |
| --- | --- | --- | --- |
| A | Default old settings | Default current settings | Community-feel comparison. |
| B | Player AI cap `10`, matched view distance | Player AI cap `10`, matched view distance | Normalize player followers. |
| C | AI teams on/off if available | AI teams on/off | Isolate non-player squad AI. |
| D | Light town defender/occupation | Light town defender/occupation | Normalize town budget. |
| E | Not applicable | HC present vs absent | Validate delegation. |
| F | Not applicable | AntiStack/audit ON/OFF | Support-system overhead. |
| G | Not applicable | Low-SV group-table test branch | Town activation burst cost. |
| H | Matched low/high view distance | Matched low/high view distance | Render/AI-awareness sensitivity. |

### Interpreting Results

- If server FPS improves dramatically when player AI is capped but active town/static counts stay high, player followers are the first lever but not the only lever.
- If server FPS remains poor at cap `10` with many active towns/statics, town/static budgets and cleanup are next.
- If client FPS improves with view distance but server FPS does not, treat view distance as client guidance.
- If server FPS improves with view distance too, document the exact AI/town state and repeat, because view distance can alter AI awareness/simulation but can be confounded by render/client load.
- If HC present beats HC absent, keep HC topology work prioritized. If not, inspect delegation paths and HC RPT before changing gameplay.

## Community Answer: Is Player AI 10 The Best First Step?

It is a reasonable first experiment, not the best final policy.

Why it helps:

- Player followers scale with player count.
- Current Wasp default is higher than old BE's default.
- Current Wasp adds Soldier and commander multipliers on top of the base cap.

Why it is incomplete:

- It does not cap AI teams, town defenders, occupation groups, static gunners, supports or stale cleanup.
- A flat `10` removes the Soldier role's "large squad leader" identity.
- Commander already has extra strategic load; commander AI should be balanced deliberately, not accidentally.
- If HC is unhealthy, town/static work can still fall back to the server regardless of player cap.

Recommended first step:

1. Test normal-role cap `8-10`.
2. Keep Soldier as a higher-AI role, for example `16-20` at full barracks or a smaller fixed bonus instead of an aggressive multiplier.
3. Reduce or condition the commander `+10` bonus, for example `+5` or Soldier commander only.
4. Pair the cap test with town/static AI counts, active-town counts and cleanup evidence.
5. Publish the RPT/PerformanceAudit results before making the cap permanent.

## Patterns Worth Porting

Worth copying or testing:

- Old default-cap conservatism as a configuration baseline.
- Old fixed Soldier bonus concept, because it is easier to reason about than a multiplier when the base cap changes.
- Old group tables as a baseline for low-SV town group experiments.
- Old mission as a regression/test PBO for measuring "classic BE feel" against Wasp.

Not worth porting blindly:

- Per-town FSM architecture. Current global loops are not obviously worse and are easier to instrument.
- Old PVF dynamic dispatch. Current shares the same pattern and needs hardening, not old-code restoration.
- Old marker loops. Current marker loops are more cache/gate aware.
- Old static-defense behavior for every side. Current resistance-only gate likely saves AI.

## Continue Reading

Previous: [Performance opportunity sweep](Performance-Opportunity-Sweep) | Next: [Player AI caps and role balance](Player-AI-Caps-And-Role-Balance)

Related: [AI, headless and performance](AI-Headless-And-Performance) | [AI runtime/HC loop map](AI-Runtime-HC-Loop-Map) | [Networking and public variables](Networking-And-Public-Variables) | [PerformanceAuditAnalyzer](PerformanceAuditAnalyzer)

Main map: [Home](Home) | Live status: [Progress dashboard](Progress-Dashboard)
