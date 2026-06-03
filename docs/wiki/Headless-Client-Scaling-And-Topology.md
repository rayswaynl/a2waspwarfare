# Headless Client Scaling & Topology

How `a2waspwarfare` delegates AI to headless clients (HCs), whether **multiple** HCs work, and **where to place them**. Source-grounded; engine/network reasoning is generic Arma 2 OA, not tied to any specific host.

## TL;DR
- **Multiple HCs are supported by design.** The server keeps a *list* of connected HCs and **random-load-balances** AI groups across all of them.
- **Co-locate HCs with the server** (same host / same LAN / same datacenter). A headless client owns and simulates delegated units, while state traffic still has to flow through the multiplayer server; across a **WAN / residential link** that topology makes the AI it hosts laggier for everyone and leans on the remote uplink.
- **Fix two gaps before scaling:** DR-21 (an HC disconnect dumps its AI back on the server with no live re-delegation) and DR-42 (static-defence HC units aren't reported back).

## How delegation works (source)
- **Mode gate:** `WFBE_C_AI_DELEGATION == 2` enables HC delegation. `initJIPCompatible.sqf` downgrades it to `0` if the OA build predates headless-client support.
- **HC registration:** `Headless/Init/Init_HC.sqf` sends `["RequestSpecial", ["connected-hc", player]]`; `Server/Functions/Server_HandleSpecial.sqf:128` appends `group _hc` to `WFBE_HEADLESSCLIENTS_ID` — a **list**, initialised `[]` in `Server/Init/Init_Server.sqf:110`.
- **Selection (random per group):** for each AI group, the server picks a *random* HC from the list and sends it a create command —
  ```sqf
  // Server/Functions/Server_DelegateAITownHeadless.sqf:24-30
  _clients = missionNamespace getVariable "WFBE_HEADLESSCLIENTS_ID";
  [leader(_clients select floor(random count _clients)), "HandleSpecial", ['delegate-townai', ...]] call WFBE_CO_FNC_SendToClient;
  ```
  Same pattern for static defences (`Server_DelegateAIStaticDefenceHeadless.sqf:23`), town-defence units (`Server_OperateTownDefensesUnits.sqf`) and defence handling (`Server_HandleDefense.sqf`).
- **Creation model:** the AI is **created local to the chosen HC** (the HC runs `Client_DelegateTownAI` / `Client_DelegateAIStaticDefence`). **A2 OA has no `setGroupOwner`**, so groups are never *transferred* after creation — only created where they should live.

**Implication:** N HCs ⇒ delegated AI is spread ~evenly (randomly) across N machines, and the server hosts ~none of it.

## Where to put HCs (topology)
- An HC is a full game client that owns and simulates delegated units; networked state still has to reach the server and other clients. **Co-locate it:** an extra `-client` process on the **same host** (loopback, ~0 ms) or a machine on the **same LAN / same datacenter** (sub-ms). That delivers the CPU offload with minimal latency or bandwidth penalty.
- **Avoid a remote HC across a WAN / residential link.** Every delegated unit then round-trips over that link: latency makes its AI visibly laggier for *all* players (they see it via the server relay); the remote uplink — often asymmetric and limited — becomes the bottleneck; and because selection is **random**, a large share of AI lands on the slow link with no way to confine it.
- **Rule of thumb:** headless clients move CPU *within a fast network*; they are not a way to borrow CPU from a distant machine.

## Server sizing for a co-located 2nd HC (do you even need a new box?)
A2 OA is a 2010, 32-bit, **single-threaded** engine: the server and each HC are each ~one-core-bound, and the engine is far more sensitive to **per-core clock (GHz/IPC)** than to core count.

- **Cores:** ~1 for the server + 1 per HC + 1 for the OS → server + 2 HCs ⇒ **~4 fast cores** is comfortable. Cores beyond that buy little — A2 won't use them.
- **Clock first:** prioritise **high single-thread clock** over core count. A 4–5 GHz part beats a many-core, lower-clock one for this engine. The classic mistake is buying "more cores" — they sit idle while one slow core bottlenecks.
- **RAM:** trivial — each 32-bit process tops out ~2–3 GB; server + 2 HCs ≈ 6–8 GB. 8 GB is plenty.
- **Network (co-located):** HC↔server sync is loopback/LAN, so it adds ~no external bandwidth; only player traffic uses the uplink.

**First question: do you need another box at all?** A 2nd HC is just one more `-client` process. If the current dedicated host has spare high-clock cores (most modern Ryzen dedicated boxes do), **run the 2nd HC on the same host** — cheapest, and loopback-fast. Only size up if the host is core-starved or on an older low-clock CPU.

**If you do provision one** (example pricing tier, Hetzner): the **AX (Ryzen) dedicated line** is the sweet spot — a high-boost-clock Ryzen dedicated server (≈4-core class and up, e.g. AX42-tier) runs the game server + 2 HCs with headroom, and bare-metal clock suits the old engine better than shared cloud vCPUs. A **Hetzner Cloud CCX-line (dedicated-vCPU, e.g. CCX23 / 4 vCPU)** also works if you prefer cloud, but expect lower single-thread clock than a bare-metal Ryzen. Don't over-buy cores — GHz is king for A2 OA.

## What more HC capacity unlocks
- **Bigger simultaneous AI** — more active towns, larger garrisons, bigger attack waves — without the late-game server-FPS collapse (see [Performance gain simulation](Performance-Gain-Simulation)).
- **Richer, affordable AI** — more patrols, convoys, dynamic reinforcements, denser town fights, when the per-AI cost is distributed.
- **Role-partitioned HCs** — replace the random selector with a *category-based* one so (e.g.) one HC hosts town garrisons and another hosts mobile/assault AI. Cleaner perf isolation and easier debugging. (Small code change; today it is purely random.)
- **More humans + more AI together** — freed server cores serve player traffic while HCs carry the simulation.

## Specialising HCs — can HC #2 run *different* AI, or take load off HC #1?
Yes, with a small selector change — and one hard limit.

- **Pin categories/regions to specific HCs.** Delegation is already split by *kind* — town AI, static defences and town-defence units each flow through their own `Server_DelegateAI…Headless` function. Replace the per-call `random` pick with an **indexed/affinity** pick (e.g. `_clients select 0` for town garrisons, `_clients select 1` for static defences + patrols; or hash a town/region id to an HC). Result: stable, debuggable distribution instead of luck-of-the-draw. Small change at the 3–4 delegation call sites.
- **Host entirely new AI on the new HC.** Because AI is *created local to the chosen HC*, any new AI system you add (convoys, dynamic patrols, a new subsystem) simply sends its create-command to whichever HC you choose — HC #2 can carry workloads HC #1 never touches.
- **"Offload a bit from HC #1" — only at spawn time.** A2 OA has **no `setGroupOwner`**, so you cannot move already-running groups between HCs live. Rebalancing happens as AI **cycles** (town recapture → despawn → respawn): point the next spawns at the lighter HC and the split shifts over minutes, not instantly. There is no live "drain HC #1 onto HC #2" button.
- **Add a per-category fallback.** Today the code falls back to server-side creation when the HC list is empty. With category/affinity routing, add a presence check per category (missing specialist HC → next HC, else server) so one absent HC doesn't silently dump its whole category on the server (this compounds DR-21).

## Prerequisites before scaling (known gaps)
- **DR-21** — on HC disconnect, its AI migrates back to the server and is **not** re-delegated (no `setGroupOwner` in OA). With multiple HCs, losing one still dumps its share on the server. Realistic mitigation: point future spawns at a surviving HC and log it; full live transfer is not possible in OA.
- **DR-42** — static-defence HC delegation does not report created units back to the server (the update-back is commented out): an accounting/cleanup blind spot that worsens with more HCs.
- **No failover/affinity** — random selection means no graceful failover and no stable AI-to-HC affinity. Consider category/affinity selection before running multiple HCs in production.

## How to validate
The delegation path already emits `PerformanceAudit_Record` rows (`delegate_townai_headless`, logging `groups`/`delegated`/`headless` count). Baseline at a known load → add one **co-located** HC → re-measure at the **same** load → diff with [PerformanceAuditAnalyzer](Tools-And-Build-Workflow). Change one thing at a time.

## Continue Reading
AI/headless: [AI, headless and performance](AI-Headless-And-Performance) · Failover: [Headless delegation and failover playbook](Headless-Delegation-And-Failover-Playbook) · FPS impact: [Performance gain simulation](Performance-Gain-Simulation) · Findings: [Deep-review findings](Deep-Review-Findings) (DR-21 / DR-42)
