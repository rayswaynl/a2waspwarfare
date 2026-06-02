# Performance Gain Simulation (estimate, not measured)

> **This is a reasoned projection, not a benchmark.** No server was run; numbers are order-of-magnitude estimates from the Arma 2 OA engine cost model + the identified [performance opportunities](Performance-Opportunity-Sweep). Treat them as a hypothesis to validate with the real tool ([PerformanceAuditAnalyzer](Tools-And-Build-Workflow)), not as guarantees. Author: Claude, lane `external-a2-docs-editorial-compression`, 2026-06-02.

## Baseline (reported)
| Metric | Now | Reading |
| --- | --- | --- |
| Client FPS | ~100 | Healthy. The client is **not** the bottleneck in Warfare. |
| Server FPS | ~45 | At **10 light players / early game**, this is healthy headroom, not a problem yet. |
| Players | ~10 | Light. AI/town/economy load is what grows server cost, not human count. |

**Key fact:** Arma 2 OA runs the mission as **single-threaded SQF + server-side AI simulation**. Server FPS is dominated by *per-frame simulation cost*; it does not have a big idle ceiling to push past — it **degrades as AI count, scripts and objects grow**. So the right question is not "45 → what idle number?" but **"how far does FPS collapse at full late-game load, and how much do the fixes raise that floor?"**

## Where server frame-time actually goes (cost model)
1. **AI simulation** (dominant) — town AI, patrols, commander AI, attack-wave units, bought AI vehicles/crews. Every group local to the server costs the server every frame.
2. **SQF scheduler** — spawned scripts, `while`/`waitUntil` loops, per-tick FSMs. Cheap individually, death-by-a-thousand-cuts at scale.
3. **Networking** — `publicVariable` broadcasts (queue churn, supply, markers) and per-message `compile`.
4. **Object count / GC** — wrecks, empty vehicles, construction logic, cleaner cadence.

## Which improvements actually move FPS
**Most of the 20-item review is security/correctness (RCE, economy authority, victory bugs) with ≈0 FPS effect** — a few authority checks even add *negligible* overhead. The performance-relevant subset is small:

| Fix | Mechanism | When it bites | Est. server-FPS effect | Confidence |
| --- | --- | --- | --- | --- |
| **Headless-client AI offload** (DR-21 / AI-headless) | Moves town/patrol AI simulation onto a connected **headless client**, off the server | Mid–late game, AI-heavy | **Largest lever.** Can shift a big fraction of AI cost off the server **if an HC is connected and delegation runs**. | Med |
| **Hosted/listen FPS busy-loop** (DR-19) | `serverFpsGUI`/`monitorServerFPS` `sleep` is inside `if (isDedicated)` → on a **listen/hosted** server the `while {true}` spins a core | Always, **listen/hosted only** | On listen: could recover ~a full core. **On a dedicated server (your 144.76.x box): N/A — no gain.** | High |
| **Double `Skill_Init`** (perf sweep) | Soldier AI cap inflated ×2.25 (→36) instead of ×1.5 (→24) | When players max out AI buys | Caps AI lower → less AI to simulate under heavy buy. Indirect. | Med |
| **PVF dispatcher `call compile`→lookup** (DR-1/38) | Removes a per-message string recompile | Scales with PVF traffic (players × actions) | Small %, grows with activity | Med |
| **Supply scan narrowing** (DR-39) | `nearestObjects [pos, [], 80]` (all classes) every ~3 s → one class | Per active supply mission | Small, situational | Med |
| **Construction-site polling** (perf sweep) | `while {true}` polls a completion var → `waitUntil` | During active builds | Small scheduler relief | Low-Med |
| **Factory queue broadcast churn** (DR-33b) | Re-broadcasts queue array every ~4 s per factory | Many active factories | Small network relief | Low-Med |
| **WASP marker frame-poll** (DR-40) | Frame-rate `findDisplay` for 2 s | Client only | Tiny **client** blip; ~0 server | High |

## Scenario simulation (dedicated server, no HC vs HC; estimates)
Sustained **server** FPS at matched load. Ranges are estimates with wide error bars.

| Load | No fixes | + SQF micro-opts only | + Headless-client offload (the big lever) |
| --- | --- | --- | --- |
| **Now** (10 players, early) | ~45 | ~45 (≈0 visible) | ~45 |
| **Mid** (15–20 players, towns contested, patrols + some waves) | ~25–35 (sagging) | ~28–38 (+~10%) | ~38–45 (holds near baseline) |
| **Late / max** (full server, many towns, multiple attack waves, lots of bought AI, GC pressure) | ~12–20 (laggy) | ~14–24 (+~10–15%) | ~22–34 (playable vs not) |

**How to read it:** the SQF micro-optimizations (compile, polling, churn, scan) collectively buy on the order of **~5–15% headroom under load** — real but incremental. The step-change comes from **headless-client AI offload**, which is what keeps late-game FPS *playable* instead of collapsing. Client FPS stays ~100 throughout (client fixes are micro).

## The honest bottom line
- **At your current 10-player load, "implementing all the features" will not visibly change your ~45 / ~100** — you're not loaded enough for it to matter, and on a dedicated box the one instant-win (DR-19 busy-loop) doesn't apply to you.
- **The gain is insurance for scale:** it's the difference between a full late-game server staying ~25–35 FPS (playable) vs collapsing to ~12–20 (rubber-banding AI, laggy commands).
- **~80–90% of that gain is one lever: a working headless client.** If you want server-FPS ROI, *that* is the investment — confirm an HC is connected and delegation (`WFBE_C_AI_DELEGATION=2`) is actually offloading AI. The SQF micro-opts are worthwhile cleanup but individually marginal.
- **Caveat on HC for A2 OA:** there is **no `setGroupOwner`** in OA, so AI can only be *created* local to an HC, not transferred. An HC that disconnects dumps its AI back on the server with no live re-delegation (DR-21) — so HC gains assume the HC stays connected.

## Measure it for real (don't trust this page)
A simulation is a guess; the repo ships the truth-teller: **`Tools/PerformanceAuditAnalyzer/`** parses server RPT `PerformanceAudit_Record` rows into FPS/timing reports. To validate:
1. Capture a baseline RPT at a known player/AI/town count.
2. Apply one lever (start with HC), recapture at the **same** load.
3. Diff with the analyzer. Repeat per lever — never bundle, or you can't attribute the gain.

## Continue Reading
Opportunities: [Performance opportunity sweep](Performance-Opportunity-Sweep) · AI/headless: [AI, headless and performance](AI-Headless-And-Performance) · Findings: [Deep-review findings](Deep-Review-Findings) (DR-19/21/33/38/39/40) · Tooling: [Tools and build workflow](Tools-And-Build-Workflow)

> Numbers are estimates for planning only. Validate with `PerformanceAuditAnalyzer` before quoting any figure as fact.
