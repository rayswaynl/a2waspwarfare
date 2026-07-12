# WASP Performance Final-Pass Adjudication — 2026-07-12

Status: **FINAL ADJUDICATION** for Fleet card
`wasp-perf-ultra-adjudication-20260712`, checked against
`origin/master@bbab122f0eb40b1351d075d05a12da6960499a12`.

This record adjudicates `GROK-PERF-RESEARCH-BRIEF-20260712.md`,
`GROK45-FINAL-PASS-20260712.md`, and `GROK-DROP-REVIEW-20260712.md` against the
current repository and measured evidence. It changes no mission behavior and claims no
performance gain. Game-PC and box measurements remain separate, and HC values are excluded
from all statistical aggregates.

## Final verdict

1. **AI logic LOD is rejected permanently for this campaign.** Reducing AI work by player
   distance is distance-gating under another name. The owner explicitly rejected it, so the
   claimed 10–20% is irrelevant and no benchmark can reopen it.
2. **The route-precompute 15–25% claim is rejected.** An offline cache format is feasible in
   principle, but neither route frequency, cache hit rate, aggregate route cost, nor path parity
   has been measured. Current source makes general cache reuse unlikely: most inputs are live and
   lane offsets are continuous.
3. **Redis-ledger and external behavior-tree gains are rejected.** The supplied runtime
   file-drop sketches are not legal A2OA designs. A2OA SQF exposes no direct arbitrary
   file-write/network client API to such a service, while `callExtension` is synchronous, x86,
   and cannot repair the diagnosed network
   queue. The claimed 5–20% ranges have no executable evidence.
4. **`MaxMsgSend` 128-vs-256 remains deferred.** It becomes testable only after a two-HC
   net-pressure census proves the relevant queue pressure. No 384–512 arm is justified.
5. **The 550–600 AI ceiling is an estimate, not a result.** The evidence proves an armed box
   soak near 300 AI, a historical live collapse near 421 AI, and an idle delegated synthetic run
   at 503 AI. Those regimes cannot be pooled into a 550–600 full-combat claim.

## Claim-by-claim disposition

| Claim | Disposition | Evidence-based reason |
| --- | --- | --- |
| Offline route cache saves 15–25% pathing CPU at 400+ AI | **REJECT magnitude; HOLD any production integration** | `BuildRoadRoute` was measured at about 1 ms for 8 hops and about 3 ms for 24 hops. Burst cost, live call frequency, reusable-key coverage, and end-to-end FPS effect remain unproven. |
| Distant-AI logic LOD saves 10–20% | **REJECT — terminal** | Violates the owner’s absolute no-LOD/no-distance-gating ruling. |
| External Redis-style ledger saves 5–15% | **REJECT current architecture and gain** | No valid asynchronous A2OA IPC path or benchmark exists; the proposed file polling is invalid and blocking. |
| External BT/combat sidecar saves 10–20% | **REJECT synchronous design; native research remains owner-gated** | No binary or complete protocol exists. A 64-bit in-process extension is impossible; a sidecar still needs an approved x86 shim, bounded batching, fallback, and fault tests. |
| Creation-time routing + recovery + external node adds 150–200 AI | **ACCEPT native recovery direction; REJECT magnitude and external-node bundle** | Creation-time routing, adopt-on-disconnect, and cold-group recycle are the legal ownership repairs. They have not demonstrated an extra 150–200 full-combat AI, and the external node is unsupported. |
| `MaxMsgSend` 128 vs 256 | **DEFER** | Requires the missing net-pressure census, matched population, at least five ABBA pairs per arm, and abort gates for desync/pending-message regression. |
| 550–600 AI at 40 or more server FPS | **UNPROVEN** | The 503-AI delegated result used idle AI; the production workload collapsed near 421. HC and network ceilings remain unresolved. |
| Runtime file-drop path/combat proxies | **REJECT — infeasible sketch** | SQF cannot write the request file; `fileExists` is Arma-3-only and bare `break` is not the A2 SQF loop-control idiom; polling adds scheduler stalls. |
| Meshy/GLB “asset-enabled Arma offload” | **REJECT from WASP performance scope** | Godot/GLB assets cannot offload A2OA server simulation. |

## Current-source route audit

`Common/Functions/Common_BuildRoadRoute.sqf:24-61` performs one base-egress
`nearRoads` query and one query for every route hop. Current master has four canonical call
sites:

| Caller | Current inputs | Cache consequence |
| --- | --- | --- |
| `Server/AI/Commander/AI_Commander_AssignTowns.sqf:827-846` | Live leader origin, live target, 8–24 hops, persistent continuous lane jitter | Exact reusable keys are unlikely. |
| `Server/AI/Commander/AI_Commander_Execute.sqf:84-90` | Live leader origin, arbitrary human destination, continuous lane jitter | Not a finite precompute set. |
| `Server/AI/Commander/AI_Commander_Execute.sqf:105-112` | Same dynamic inputs for server-local vehicle teams | Not a finite precompute set. |
| `Server/AI/Orders/AI_Patrol.sqf:40-75` | Owned-town endpoints, but a newly random lane offset per call | First plausible cache consumer only if lane bucketing is separately approved and path parity is proven. |

No shared route cache or repository road graph exists. Terrain road objects are supplied by the
world data and queried through `nearRoads`; a repo-only Python graph builder cannot reproduce
current route output. A valid future lab must first harvest named, fixed inputs inside A2OA,
then generate deterministic map-specific SQF data offline. Its key/version must include world,
endpoints, lane bucket, hop count, snap radius, schema, and source SHA; every miss must retain the
native builder.

One supplied review claim is corrected here: `diag_tickTime` **is** legal in A2OA. The official
[Bohemia command reference](https://community.bohemia.net/wiki/diag_tickTime) lists it for Arma 2
and A2OA, so the existing Gate-0 timing design may use it. This correction does not rescue the
runtime file-drop sketch: [`fileExists`](https://community.bohemia.net/wiki/fileExists) is
introduced only in Arma 3 2.02, and SQF still lacks the required request-file write path.

That lab is deliberately **not** bundled here. Existing Gate-0 scheduler work owns the route-cost
premise and remains owner/rig gated, while this Fleet card authorizes adjudication. Production
callers, mirrors, constants, scheduler files, the rig, and the box remain untouched.

## Evidence-bounded ceiling

| Regime | Observed result | What it proves |
| --- | --- | --- |
| Armed two-HC box soak | About 47–48 server FPS approaching 300 AI | Current verified full-mission floor. |
| Historical production-box collapse | About 421 AI, roughly 1,000 pending-message lines, 48→18 FPS, both HCs bounced | Network/HC recovery is a real binding risk before 550 AI. |
| Delegated synthetic ceiling | 503 idle AI, 44.7–47.6 server FPS, 95.2% delegated | Server simulation has headroom when idle work is delegated; it does not prove a 503-AI combat ceiling. |
| Server-local synthetic knee | About 450–475 AI | Raw local ceiling for a different topology/workload, not a production target. |

The defensible current statement is therefore: **about 300 full-mission AI is verified; the
interval above 300 and below the 421-AI collapse is unresolved; 503 is an idle delegated bound,
not a sustained combat result.** The binding constraint may be the network/message layer, HC
processes, or their recovery interaction. Current evidence does not identify one architectural
change that adds 150–200 combat AI.

## Measurements that can change the ranking

1. **Net-pressure census:** the highest-value missing evidence, already owned by the gated A/B
   lane. Align server-only pending-message counts, PV bytes/calls by subsystem, population,
   connection events, and FPS. Do not aggregate HC rows.
2. **Immutable movement ledger:** rebuild c125/c150 from current master with immutable group IDs
   and terminal `moved` / `died` / `null` / `stalled` outcomes. The existing denominator is
   attrition-confounded and cannot establish a pathing stall.
3. **Gate-0 route scheduler probe:** prove whether repeated route calls occupy one frame before
   changing routing code. The owner authorization and remaining PR disposition are still open.
4. **HC bounce/rejoin recovery:** demonstrate that current creation-time routing and recovery
   leave no zombie teams/FSMs and restore delegation before assigning any ceiling gain.

## Non-negotiable exclusions

- No simulation gating, distance gating, logic LOD, despawn cache, or distance-driven `disableAI`.
- No antistack changes.
- No GUER population cap or nerf.
- No live deployment, rig/session `653a68da`, Steam, or UDP 2402 action.
- No HC values in aggregate statistics.
- No performance number from merged/source-verified code without a matched measurement.
