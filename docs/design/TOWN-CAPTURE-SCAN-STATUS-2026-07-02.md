# Lane 108 - town capture scan status

Date: 2026-07-02
Base: `origin/claude/build84-cmdcon36` at `b2dbab5f3070c2bc8cacc79c06b9ca5ac20a2493`
Scope: lane 108, `server_town.sqf` per-town capture scan cost

## Verdict

Lane 108 is still a real performance hotspot candidate, but it is not a safe blind-cache lane on the current
target. The live branch deliberately keeps the direct per-town capture `nearEntities` scan after a prior
one-scan/many-readers dedupe was reverted for capture-detection wedges. The current target already has a
`town_capture_scan` performance probe around the scan, a write-on-change contested-state trim, and a folded
airfield logic cache for the recapture path.

This PR does not change mission behavior. It records the current source truth so future work measures the
live scan first and does not re-open the reverted dedupe shape without in-engine proof.

## Current Source Evidence

| Area | Evidence | Current status |
| --- | --- | --- |
| Map counts | `mission.sqm` contains 46 `LocationLogicDepot` town logics on Chernarus and 33 on Takistan. | The capture manager does one scan per town per sweep. |
| Maintained-root parity | Chernarus and Takistan `Server/FSM/server_town.sqf` SHA-256 both equal `7EAFC3C5AAFFB3C3ED5BA3632F1ABA72776F063FEF56E8A07C6E0B7A165B8C84`. | The checked lane-108 source truth is mirrored between maintained terrains. |
| Direct capture scan | `server_town.sqf:47-51` says the perf dedupe was reverted, then scans `["Man","Car","Motorcycle","Tank","Air","Ship"]` with `_town_capture_range` and `unitsBelowHeight _capH`. | The prompt's per-capture `nearEntities` concern remains source-present. |
| Existing probe | `server_town.sqf:50,56` brackets the scan with `diag_tickTime` and records `PerformanceAudit_Record` as `town_capture_scan`; `Common_PerformanceAudit.sqf:160-167` exits when `PerformanceAuditEnabled` is disabled. | Measurement is already present and self-gated. |
| Loop cadence | `server_town.sqf:671,674` sleeps `0.05` after each town and `5` seconds after the sweep. | Cadence is approximately `5s + town_count * 0.05s + work time`, not a strict all-towns-at-once burst. |
| Reverted unsafe path | Commit `5f0bcfaf3` added the one-scan/many-readers dedupe; commit `8440d0525` reverted it with the message "wedged twice". | Do not revive that cache shape without runtime proof. |
| Folded airfield mitigation | PR #301 / merge `412989d72` includes `d2068e21c`, which caches `wfbe_airfield_logic_ref`; current code reuses that ref and only runs the `LocationLogicAirport` `nearEntities` scan when the cache is empty (`server_town.sqf:530-535`). | The airfield recapture lookup part of lane 108 is already mitigated. |
| Existing no-extra-scan trim | `server_town.sqf:68-88` computes contested state from the presence counts already in hand and writes `wfbe_contested` only when it flips. | The current branch already avoids extra `nearEntities` and repeated local no-op writes for dashboard contested counts. |
| Adjacent lanes | PR #327 moves lane-106 `server_town_ai.sqf` timing around `town_activation_scan`; PR #328 adds lane-30 probes in AICOM/GuerAirDef files. | Neither PR changes `server_town.sqf`, but future performance interpretation should keep the probe families distinct. |

Official command references for future implementation review:
Bohemia Interactive `nearEntities`: https://community.bistudio.com/wiki/nearEntities
Bohemia Interactive `unitsBelowHeight`: https://community.bistudio.com/wiki/unitsBelowHeight

## Why This Is Docs-Only

The direct capture scan feeds ownership, supply-value erosion, contested-state telemetry, town capture
messages, airfield recapture effects and the capture-side player stat writer. False negatives here are much
more dangerous than in a passive marker loop: they can stop capture progress, fail to detect mounted players
or let a town look quiet while it is actively contested.

The old dedupe attempt is especially important evidence. It was small and attractive, but it was reverted
because capture detection wedged twice. The current inline comment preserves that operator lesson, so a new
source patch should be driven by RPT/performance evidence and a different design, not by reintroducing the
same cache.

## Safe Follow-Up

Use the existing `town_capture_scan` metric in a PerformanceAudit-enabled soak before changing behavior.
Compare `town_capture_scan` totals, averages and spikes against `town_activation_scan` from lane 106 and the
new server probes from lane 30 so the next patch attacks the actual dominant cost.

Safer future experiments, one at a time:

1. Keep the direct scan but split measurement by context: normal town, naval HVT, airfield capture block.
2. Add a default-off cadence experiment that never skips `Man` detection and only defers low-risk vehicle
   classes after runtime proof they are not needed every sweep.
3. Cache only side-effect lookups that are not ownership presence, following the already-folded
   `wfbe_airfield_logic_ref` pattern.

Do not reintroduce the reverted one-scan/many-readers cache as a drive-by optimization. A valid source lane
needs dedicated smoke for infantry, mounted vehicles, aircraft over towns, naval-HVT deck captures, airfield
recapture, JIP marker/flag state and the no-enemy supply recovery path.
