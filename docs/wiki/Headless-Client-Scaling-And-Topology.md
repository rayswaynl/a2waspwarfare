# Headless Client Scaling & Topology

How `a2waspwarfare` delegates AI, **what can and cannot be offloaded**, whether **multiple HCs** work, where to place them, and what hardware a second box needs. Source-grounded against the Chernarus mission; engine/network/ops reasoning is generic Arma 2 OA (no host-specific details).

## TL;DR
- **Three delegation modes** (`WFBE_C_AI_DELEGATION`): `0` = server does all AI · `1` = delegate to **player clients** (FPS-gated) · `2` = delegate to **headless clients**. Default is **2**.
- **The offload ceiling is ~40–60%.** Only **town defence infantry** and **town/base static-defence gunners** are HC-delegatable. **Patrols, support airdrops, every factory-purchased unit, AI respawn and supply-truck AI are structurally server-pinned** — no HC can take them.
- **Multiple HCs are supported by the delegation code** (it keeps a *list* and random-picks per group) — **but `mission.sqm` defines only ONE HC slot today**, so a 2nd HC needs a 2nd `forceHeadlessClient` slot added first.
- **Co-locate HCs with the server** (same host / same LAN / same datacenter). A remote HC over a WAN/residential link is the wrong topology.
- **Two robustness gaps to fix before scaling:** DR-21 (HC disconnect orphans its AI, no live re-delegation — no `setGroupOwner` in OA) and DR-42 (static-defence HC units aren't reported back). Mode 2 also lacks the load-balancing/tracking/fallback that Mode 1 has.

## The three delegation modes
`WFBE_C_AI_DELEGATION` (mission parameter; `Rsc/Parameters.hpp:50-54`, **default 2**; the `isNil` guard in `Init_CommonConstants.sqf:93` falls back to 0 only outside MP; `WF_Debug` forces 2 at `initJIPCompatible.sqf:155`):

| Mode | Meaning | Selection | Load-balancing / fallback |
| --- | --- | --- | --- |
| **0** | Server creates all AI | — | n/a |
| **1** | **Player-client** delegation — town AI is offloaded onto *human players'* machines | players with FPS ≥ `WFBE_C_AI_DELEGATION_FPS_MIN` (25) and < `WFBE_C_AI_DELEGATION_GROUPS_MAX` (1) group, **progressive fill** (`Server_FNC_Delegation.sqf:139-178`) | **Yes** — excess groups fall back to the server; per-group `DelegationTracker` decrements on death; clients report FPS every `…FPS_INTERVAL` (180 s) |
| **2** | **Headless-client** delegation (default) | **least-loaded HC per town** via `WFBE_CO_FNC_PickLeastLoadedHC` (tallies `allUnits` per HC owner once), then distributes this town's groups across all live HCs via a **local round-robin anchored at the lightest HC** (`_live select ((_seedIdx + _rr) mod _hcCount)`, `Server_DelegateAITownHeadless.sqf:29-56`) | **Partial** — no FPS check, no per-HC group tracking; but round-robin distribution IS present and a per-group drop/log fallback fires when no live HC is found (`Server_DelegateAITownHeadless.sqf:47-49`) |

**Version gate:** HC delegation functions are only compiled on Arma 2 OA **1.62.101334+** (`Init_Server.sqf:98-101`); otherwise `initJIPCompatible.sqf:165-171` downgrades mode 2 → 0. There is **no** dynamic fall-through from mode 2 to mode 1 — it's HC or server, never players-as-backup.

## How HC delegation works, end-to-end (source)
1. **Detection** — `Headless/Functions/HC_IsHeadlessClient.sqf` = `!(hasInterface || isDedicated)`; sets `isHeadLessClient` (`initJIPCompatible.sqf:56`). The HC runs `Init_Common` + `Init_Towns` + `Headless/Init/Init_HC.sqf`, **not** the full client or server init.
2. **Registration handshake** — `Init_HC.sqf` compiles the `Client_Delegate*` functions, **sleeps 20 s**, then sends `["RequestSpecial",["connected-hc", player]]`. `Server_HandleSpecial.sqf:117-131` checks `owner _hc != 0`, stores the HC group under `WFBE_HEADLESS_<uid>`, and appends `group _hc` to the **list** `WFBE_HEADLESSCLIENTS_ID` (init `[]`, mode-2-only, `Init_Server.sqf:109-111`).
3. **Selection** — when a town activates, `server_town_ai.sqf:157-181` switches on the mode; case 2 checks `count(WFBE_HEADLESSCLIENTS_ID) > 0` then calls `WFBE_CO_FNC_DelegateAITownHeadless`, which sends `delegate-townai` to the **leader of a randomly chosen HC group**.
4. **Create-local on the HC** — `Client/PVFunctions/HandleSpecial.sqf` routes `delegate-townai` → `Client_DelegateTownAI.sqf` → `CreateTownUnits(_global=false)` → `createGroup`/`createUnit`/`createVehicle` **on the HC**. The town **patrol FSM also runs on the HC** (`Common_CreateTownUnits.sqf:49`, no `isServer` guard), so the HC carries the behaviour loop, not just the spawn.
5. **Report-back** — town AI hands its vehicles back: `update-town-delegation` → `Server_HandleSpecial.sqf:86-96` adds them to `wfbe_active_vehicles` + runs `HandleEmptyVehicle`. **Static-defence report-back is commented out (DR-42)** (`Client_DelegateAIStaticDefence.sqf:28`) — the server learns nothing about those units. Follow-up source check: the static-defense helper returns only `[_teams]` (`Common_CreateUnitForStaticDefence.sqf:69`), so restoring this needs a deliberate static-defense payload/receiver, not an uncomment-only patch. Mode 2 keeps **no group/load tracking** at all.
6. **Cleanup** — each `Client_Delegate*` spawns per-group watchers (`while {count units _team > 0} do {sleep 1}; deleteGroup _team`) on the HC.

**Why "create-local, not transfer":** A2 OA has **no `setGroupOwner`** (Arma 3 only). You can't move an existing server group to an HC — the HC must *create* it. Hence delegation only happens **at spawn time**, and anything created on the server stays there.

## What can actually be offloaded — the ceiling
| AI category | Offloadable to HC? | Notes / source |
| --- | --- | --- |
| **Town defence infantry** | ✅ Yes (mode 2) | The single largest AI population; spawns per contested town. `server_town_ai.sqf:157-181` |
| **Town static-defence gunners** | ✅ Yes — **all sides** | no side gate; delegation fires for any town side when mode == 2 and at least one HC is registered (`Server_OperateTownDefensesUnits.sqf:56-67`) |
| **Base static-defence gunners** | ✅ Yes — **always tries HC** | direct `count WFBE_HEADLESSCLIENTS_ID > 0` check, *bypasses* the mode param (`Server_HandleDefense.sqf:19-33`) |
| **Patrols v2 side patrols** | ✅ Partial | Current `cf2a6d6a` side patrols can run on a live HC through `server_side_patrols.sqf:49-56` and `Client/PVFunctions/HandleSpecial.sqf:16`; fallback is server-local `Common_RunSidePatrol.sqf`. Smoke HC dispatch and slot release before treating this as a proven FPS win. |
| **Support airdrops** (paratroopers, para-vehicles, para-ammo) | ❌ Server-pinned | `Server/Support/Support_*` |
| **All factory-purchased units** | ❌ Server-pinned | `Server_BuyUnit.sqf` — *2nd-largest AI source*, no delegation |
| **AI squad/advanced respawn** | ❌ Server-pinned | `Server/AI/AI_*Respawn.sqf` |
| **Supply-truck AI** | ❌ Server-pinned | `AI_UpdateSupplyTruck.sqf` + `supplytruck.fsm` |
| **UAV crews** | n/a — already player-local | `Client/Module/UAV/uav.sqf` |

**Net: ~40–60% of in-game AI compute is offloadable** (estimate — town AI vs purchases ratio is game-state dependent), and it's the *most performance-critical* slice (active combat zones). The rest (purchases, patrols, airdrops, respawn) has **no delegation path** and would need real refactoring (not a wrapper) to move — there's no `setGroupOwner` shortcut.

## Topology — where to put HCs
- An HC is a full game client that **streams its units' state to the server every tick**. **Co-locate it:** an extra `-client` process on the **same host** (loopback, ~0 ms) or a machine on the **same LAN / same datacenter** (sub-ms). That delivers the CPU offload with no meaningful latency/bandwidth penalty.
- **Avoid a remote HC over a WAN / residential link.** Every delegated unit then round-trips over that link: latency makes its AI laggier for *all* players; the remote uplink (often asymmetric, limited) becomes the bottleneck; and because selection is **random**, ~half the delegated AI lands on the slow link with no way to confine it.
- **Rule of thumb:** HCs move CPU *within a fast network* — they are not a way to borrow CPU from a distant machine.

## Running a 2nd HC — what it actually takes
1. **Add a 2nd HC slot to the mission.** `mission.sqm` currently defines **one** `forceHeadlessClient=1` slot (a CIV `Functionary1`). Each HC needs its own slot, so a 2nd HC requires adding a second `forceHeadlessClient` CIV unit and repacking the PBO. The delegation *code* already handles a list of N HCs — only the slot is missing.
2. **Launch it as a separate client process** (generic): `arma2oaserver -client -connect=<host> -port=<port> [-password=<pw>] -mod=<exact same modset> -profiles=<dir> -name=<hcProfile>`. Co-locate per the topology rule.
3. **It auto-registers** via the `connected-hc` handshake (~20 s after connect) and immediately enters the random-selection pool — town AI then splits ~evenly (randomly) across both HCs.
4. **Expect random, un-tracked distribution** (Mode 2). If you want predictable splits, see *Specialisation* below.

## Server sizing for a co-located HC (do you even need a new box?)
A2 OA is a 2010, 32-bit, **single-threaded** engine: the server and each HC are each ~one-core-bound, and the engine cares far more about **per-core clock (GHz/IPC)** than core count.
- **Cores:** ~1 server + 1 per HC + 1 OS → server + 2 HCs ⇒ **~4 fast cores**. More cores buy little.
- **Clock first:** a 4–5 GHz part beats a many-core, lower-clock one. The classic mistake is buying "more cores" — they idle while one slow core bottlenecks.
- **RAM:** trivial — each 32-bit process tops ~2–3 GB; server + 2 HCs ≈ 6–8 GB.
- **Network (co-located):** HC↔server is loopback/LAN → ~no external bandwidth; only player traffic uses the uplink.

**First question — do you need another box at all?** A 2nd HC is just one more `-client` process; if the current dedicated host has spare high-clock cores (most modern Ryzen boxes do), **run it on the same host** — cheapest and loopback-fast. Only size up if the host is core-starved or on an old low-clock CPU.

**If you do provision one** (example tiers, Hetzner): the **AX (Ryzen) dedicated line** is the sweet spot for pure HC AI-hosting — a high-boost-clock Ryzen (≈AX42-tier, ~4 cores+) runs the server + 2 HCs with headroom, and bare-metal clock suits the old engine better than shared cloud vCPUs. Don't over-buy cores — GHz is king.

## What an extra Hetzner Cloud CCX23 could do for the server
A **CCX23** (≈4 dedicated vCPU / 16 GB) is a flexible *utility* box rather than a peak-clock AI host. Its dedicated-vCPU clock is lower than a bare-metal Ryzen, so for **pure AI-hosting an AX-Ryzen is the better fit** — but a CCX23 earns its keep doing several jobs at once:
- **1–2 co-located HCs** — *only if* it sits in the **same Hetzner location as the game server, joined via a private vSwitch network* (near-LAN latency). Cross-region/over-public-internet reintroduces the WAN penalty above.
- **Move the non-game processes off the game box** — host the Discord bot + the AntiStack/stats DB backend on the CCX23, freeing the game host's cores for the sim (+ any local HC).
- **A staging / test server** — stand up a low-pop A2 OA server to validate LoadoutManager output and mission changes *before* prod (high value: there is no CI/test environment today).
- **Build + monitoring runner** — a self-hosted CI runner (dotnet builds, BattlEye-filter completeness checks) and the `PerformanceAuditAnalyzer` pipeline turning RPT/`PerformanceAudit` logs into a server-health view.

**Match the box to the goal:** "squeeze more combat AI" → a co-located **AX-Ryzen** HC host (clock). "A do-everything 2nd box that also helps a bit" → a **CCX23** on a same-DC private network (flexibility). Buying cores you can't clock-feed helps neither.

## Specialising HCs — can HC #2 run *different* AI, or take load off HC #1?
Yes, with a small selector change — and one hard limit.
- **Pin categories/regions to specific HCs.** Delegation is already split by *kind* (town AI, town static defence, base static defence each have their own function). Replace the current **least-loaded round-robin** pick with an **indexed/affinity** pick (e.g. HC[0] = town garrisons, HC[1] = static defences; or hash a town/region id → HC). Stable, debuggable distribution instead of luck-of-the-draw. Small change at ~3 call sites. (The earlier per-call `random` pick has already been replaced by the least-loaded + round-robin algorithm in `Server_DelegateAITownHeadless.sqf`.)
- **Host entirely new AI on the new HC.** Because AI is *created local to the chosen HC*, any new AI system you add (convoys, dynamic patrols, a new subsystem) just sends its create-command to whichever HC you choose.
- **"Offload from HC #1" only at spawn time.** No `setGroupOwner`, so you can't move running groups; rebalancing happens as AI **cycles** (town recapture → despawn → respawn). No live "drain HC #1 onto HC #2".
- **Add per-category fallback.** With affinity routing, add a presence check per category (missing specialist HC → next HC, else server) so one absent HC doesn't silently dump its category on the server (compounds DR-21).

## What more HC capacity unlocks (ideation)
- **Bigger wars** within the offloadable slice — more contested towns at once, larger garrisons, denser town fights — without the late-game server-FPS collapse (see [Performance gain simulation](Performance-Gain-Simulation)).
- **Port Mode 1's smarts to Mode 2.** The player-delegation path (`Server_FNC_Delegation.sqf`) already has FPS-aware, load-balanced, tracked, fallback-safe selection. Reusing that logic for HC selection (instead of `random`) would give multi-HC load-balancing, per-HC accounting, and graceful fallback — closing most of Mode 2's robustness gap for free.
- **Per-HC observability** — Mode 2 keeps no tracking today; the `delegate_townai_headless` `PerformanceAudit_Record` rows already log `groups`/`delegated`/`headless` count, so a per-HC load panel is a small addition.
- **Move server-pinned load off the box another way** — since patrols/purchases/airdrops can't be HC-delegated, a second box is better spent on the bot/DB/test/CI duties (above) than on trying to host AI it isn't allowed to host.

## Known gaps / robustness (fix before scaling)
- **DR-21** — on HC disconnect, the engine migrates its units' locality back to the server but **nothing re-registers them**; they're orphaned, and there's no live re-delegation (no `setGroupOwner`). With 2 HCs, losing one still dumps its share on the server.
- **DR-42** — static-defence HC report-back is commented out (`Client_DelegateAIStaticDefence.sqf:28`): the server can't track or clean up those units.
- **Mode 2 is cruder than Mode 1** — random selection, no FPS check, no load-balancing, no `DelegationTracker`, no per-function server fallback, no vehicle hand-back. A mid-activation HC drop can silently skip groups (the only fallback is the call-site `count > 0` check).
- **Dead path** — the `delegate-ai` handler (`Client_DelegateAI.sqf`, resource-base units) is registered but **never sent** from the server.
- **Town static defence is guerilla-only** — occupied west/east town defences are never HC-manned (`Server_OperateTownDefensesUnits.sqf:24`).

## Improving the current HC — prioritised roadmap
Concrete fixes to make the **existing single HC** more reliable and offload more, ordered by value-per-effort, each with a **feasibility** read. Suggestions only — no patches applied. Most are prerequisites that make a 2nd HC actually worthwhile.

> **Feasibility constraints (apply to all items):** these are SQF **mission** changes → each needs LoadoutManager propagation, a PBO repack, and validation on a **private server** (there is no CI today). And A2 OA's missing `setGroupOwner` / `remoteExec` / `params` caps the design space: anything needing **live group transfer** is impossible — every fix must work within the existing *create-local-via-PVF* model. Effort ratings are relative SQF-edit size, not wall-clock.

### Tier 1 — reliability (make the one HC trustworthy)
| # | Improvement | Why (current state) | Fix sketch | Feasibility | Source |
| --- | --- | --- | --- | --- | --- |
| 1 | **Per-function server fallback for Mode 2** | If the HC drops *between* the call-site `count > 0` check and the inner loop, groups are silently skipped — never created anywhere. | When `count _clients == 0` (or a send fails) inside the delegate function, create the group on the **server** instead of skipping — mirror Mode 1's fallback. | **Easy / low-risk** — small else-branch reusing the existing server-create (`CreateTownUnits`). | `Server_DelegateAITownHeadless.sqf:24-29` |
| 2 | **Fix DR-42 — static-defence report-back** | HC-created static-defence units are invisible to the server: no `HandleEmptyVehicle`, no cleanup, no accounting. | Un-comment + complete `update-delegation-static_defence` and add the matching `Server_HandleSpecial` case (parity with town AI's `update-town-delegation`). | **Easy–Medium** — the town-AI report-back pattern already exists to copy; needs one new server case + cleanup parity. | `Client_DelegateAIStaticDefence.sqf:28` |
| 3 | **DR-21 — graceful HC disconnect** | On disconnect the HC's AI orphans on the server with no re-registration and no re-delegation. | Re-register the orphaned groups into the server's town-team/cleanup tracking and **re-point future spawns** to the server / a surviving HC, with a log line. | **Medium — partial only.** Redirect-future-spawns + log + cleanup is doable; **full live re-delegation is impossible in OA** (no `setGroupOwner`). It bounds the damage, it doesn't recover the AI. | `Server_OnPlayerDisconnected.sqf:23-29` |
| 4 | **Robustify the registration handshake** | `Init_HC.sqf` blindly `sleep 20` before announcing — racy if server init runs long, and it never re-registers on reconnect. | Wait on a server-ready flag + a small retry/ack loop instead of a fixed sleep; re-send `connected-hc` on reconnect. | **Easy / low-risk** — local change to `Init_HC.sqf` + a server-ready PV. | `Headless/Init/Init_HC.sqf:13` |

### Tier 2 — effectiveness (offload more, smarter)
| # | Improvement | Why | Fix sketch | Feasibility | Source |
| --- | --- | --- | --- | --- | --- |
| 5 | **Replace random selection with load-balanced + tracked** | Mode 2 now picks the **least-loaded** HC per town (via `WFBE_CO_FNC_PickLeastLoadedHC`, scanning allUnits by owner across all live HCs), then round-robins that town's groups across all live HCs starting from the lightest one. Load IS tracked live at delegation time (allUnits re-read on every call, self-correcting as groups die off); there is no per-group decrement-on-death counter, but the unit-count is accurate the instant a unit is created. The old blind random pick (`_clients select floor(random count _clients)`) was replaced precisely because it had high variance and never self-corrected on 2 HCs. **This improvement is already shipped on master** — the remaining gap is that there is still no per-function server fallback (item #1) and no per-HC group-death tracking. | Reuse Mode 1's `GetDelegators` / `DelegationTracker`: least-loaded pick + per-HC group count + decrement on group death. | **Medium — best payoff.** The logic already exists in Mode 1; adapt the selector + bolt tracking onto the HC path. Test so the working single-HC case doesn't regress. | `Server_DelegateAITownHeadless.sqf:23-28` vs `Server_FNC_Delegation.sqf:139-178` |
| 6 | **Widen the offloadable set** | Town static-defence delegation is **guerilla-only**; occupied west/east town statics are always server-manned. | Extend the delegate path to west/east town defences (gameplay call). | **Split:** the static-defence side-gate is **Medium** (adjust one guard + verify gameplay). The big server-pinned categories (**purchases / patrols / support**) are **Low / large** — each needs a full *create-on-HC* refactor of its spawn path; no `setGroupOwner` shortcut. | `Server_OperateTownDefensesUnits.sqf:24` |
| 7 | **Harden group-handle delegation** | Group handles passed via PVF may not transfer reliably across machines in OA; `CreateTeam` silently makes a fresh local group if null — which can mask a double-create. | Confirm the delegated handle is valid HC-side; standardise on HC-local group creation and report the handle back if the server needs it. | **Medium — investigate first.** Verify the handle is *actually* unreliable (finding is medium-confidence) before changing; risk of double-create if done blindly. | `Common_CreateTeam.sqf:22`, `Server_DelegateAITownHeadless.sqf:27` |

### Tier 3 — hygiene & observability
| # | Improvement | Why | Feasibility | Source |
| --- | --- | --- | --- | --- |
| 8 | **Per-HC load panel** | Mode 2 keeps no tracking, but the perf rows already log the data — surface `groups`/`delegated`/`headless` per HC. | **Easy** — data already emitted; aggregate/display (pairs with #5). | `delegate_townai_headless` `PerformanceAudit_Record` |
| 9 | **Remove or wire the dead `delegate-ai` path** | `Client_DelegateAI` is compiled but never sent from the server — dead code or an unfinished feature. | **Easy to remove; larger to wire up.** | `Client/PVFunctions/HandleSpecial.sqf:14` |

**Biggest single win:** #5 (load-balanced selection) + #1 (server fallback) — both **feasible without any engine workaround** — together turn Mode 2 from *random, untracked, drop-on-race* into *balanced, accounted, safe*, and they are the prerequisite that makes adding a 2nd HC pay off rather than just scatter AI. **Lowest feasibility:** delegating purchases/patrols/support (item 6, second half) — blocked by the missing `setGroupOwner`, a per-category rewrite.

## Implementation Guidance

Items #1 and #5 both touch `Server_DelegateAITownHeadless.sqf`, so they should be designed and tested together: replace random HC selection with tracked least-loaded selection, and add a server fallback when no HC is available at the moment of delegation. Keep the implementation in the HC failover owner pages rather than this topology overview.

Patch owner rules:

- Preserve OA constraints: no `setGroupOwner`, no `remoteExec`, no `params`, no Arma 3 locality helpers and no live transfer of already-created groups.
- Keep vehicle bookkeeping intact. If fallback creation happens on the server, preserve the existing `CreateTownUnits` return handling, `wfbe_active_vehicles` registration and `HandleEmptyVehicle` path.
- Do not merely uncomment static-defence report-back. DR-42 needs a deliberate static-defence payload and server receiver because the current helper returns only `[_teams]`.
- Prefer source Chernarus first, then propagate maintained Vanilla through LoadoutManager and run private dedicated/HC smoke.

Detailed source anchors and patch-readiness evidence live in [AI runtime/HC loop map](AI-Runtime-HC-Loop-Map), [Headless delegation/failover](Headless-Delegation-And-Failover-Playbook), [Feature status](Feature-Status-Register) and [Deep-review findings](Deep-Review-Findings) DR-21 / DR-42.

## Observability & validation
The delegation path emits `PerformanceAudit_Record` rows (e.g. `delegate_townai_headless`, logging `town`/`side`/`groups`/`delegated`/`headless` count). To validate any HC change: baseline at a known load → add one **co-located** HC → re-measure at the **same** load → diff with [PerformanceAuditAnalyzer](Tools-And-Build-Workflow). Change one thing at a time; never bundle.

## Continue Reading
AI/headless: [AI, headless and performance](AI-Headless-And-Performance) · Failover: [Headless delegation and failover playbook](Headless-Delegation-And-Failover-Playbook) · FPS impact: [Performance gain simulation](Performance-Gain-Simulation) · Findings: [Deep-review findings](Deep-Review-Findings) (DR-21 / DR-42) · Networking: [Networking and public variables](Networking-And-Public-Variables)
