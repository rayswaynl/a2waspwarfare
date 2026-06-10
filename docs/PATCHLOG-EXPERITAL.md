# WASP Warfare — Experital Branch Patchlog

**Branch:** `experital` | **Base:** `release/2026-06-feature-bundle` (a96fdda2)
**Deployed:** 2026-06-10 as `WASP_Experital_TEST.Chernarus` on Hetzner test server (78.46.107.142)
**Status:** Feature-complete. Live alongside the unmodified PR8 default mission.

---

## Session 2 — 2026-06-10 (play-test fix batch 2)

- **Patrols v2 ported at upgrade index 23.** Full 4-level upgrade (300 / 1,600 / 2,400 / 3,200 supply). Caps at 3 active patrols per side. Level 2 requires Light Factory 1; levels 3–4 require Heavy Factory 2. AI commander may buy unconditionally. HC-delegated. Yellow leader map markers. Player max-AI −1 per active patrol. Old random-town patrol system retired.
- **Upgrade and build sounds −64%.** Structure build/complete sounds dropped from volume 7 to 2.5. Upgrade-start cue uses a dedicated alias (`upgradeStartedSound`) so the shared `commanderNotification` sound is unaffected.
- **Class info on join.** Non-invasive `hintSilent` showing class and abilities on join and class change (repeat-guarded), plus a "Class Info" action-menu entry to re-read at any time.
- **Engineer crews.** Bought tanks and wheeled APCs (LAV-25, BTR-90, Pandur) are crewed by engineers on delivery.

---

## Session 1 (cont.) — 2026-06-10 (play-test fix batch)

- **Defense threat gate live-tune.** Gate now requires 3+ west/east ground units inside base range (aircraft and GUER no longer trigger it). Reject classname passed to client so WDDM cash refunds correctly.
- **PR #23 upgrade-queue stacking ported.** Same-upgrade level stacking + `[Q1,3]` queue marks in the upgrade menu.
- **Factory queue minimum floors.** Barracks 10, Light Factory 5, Heavy/Aircraft 3 (replaces the scaling-only `lvl+2`/`lvl+1` formula that was too small at low levels).
- **Earplugs in vehicles.** Toggle mirrors onto the player's current vehicle; hardened against death-loop exit and cross-object action-id collisions.

---

## Initial deployment — 2026-06-10

### Economy & Balance
- **Ammo-proportional rearm pricing.** Rearm cost scales with ammo actually missing (10% floor). Artillery exempt.
- **Per-factory production queue caps.** Queue depth shown as N/CAP in buy menu. Minimum floors: Barracks 10, Light 5, Heavy 3, Aircraft 3.
- **Doubled + compensated starting economy.** Both sides start with $11,600 cash and 7,400 supply (baseline was $800/$1,200; doubled then +$10k cash/$5k supply as session-restart compensation).

### New Structures
- **Federal Reserve / Bank Rossii.** 9,500 supply. Must be placed >800 m from HQ; one per side; marked on map for both sides. pays $6,000 per 5 min split among living players while HQ stands. Destruction reward: +$40,000 side supply + $25,000 to the killer.
- **Counter Battery Radar (CBR).** 2,400 supply. Marks enemy artillery firing positions for 75 s. Requires own AAR to be alive. CBR Radar upgrade extends radius: 750 m → 1,500 m → 2,000 m.

### Airfields
- **Airfield capture objectives.** NWAF, NEAF and Balota Airfield are live capture towns (50 SV, PMC garrison of ~18 infantry + Motorized + AA_Light). Capturing spawns a repair point and an exclusive hangar (unique aircraft: L-39, An-2, Mi-17 variants on Chernarus).
- **Airfield built-in CBR.** Each captured airfield gives its owner a permanent indestructible 2,000 m CBR. Ownership transfers on recapture. Resistance captures get no CBR.

### Capture-to-Unlock Premium Units
- Holding **Krasnostav** → Czech T-72 (`T72M4CZ_ACR`) at Heavy Factory level 4, $7,000.
- Holding **NW Airfield** → RM-70 rocket artillery (`RM70_ACR`) at Light Factory level 4, $6,800 (full fire-mission menu integration).
- Both available to whichever side holds the trigger town; AI commanders may buy unconditionally.

### Units
- **Medic Redeployment Truck.** Medic-only forward spawn. Activates when parked (engine off, free cargo seat, ≥500 m from non-friendly towns). Purchasable at Light Factory (violet row).
- **Captured towns spawn AI gunners again.** Regression fix — WEST/EAST-captured towns now man their static defenses on capture.

### Commander Tools
- **Site Clearance.** Commander-only action that fells trees in a 25 m radius (10 supply/tree). Excluded from repair-truck menu.
- **Commander QoL cluster.** Upgrade start/complete sounds; drift-free RHUD upgrade countdown; production-queue cancel with price-at-order refund (50% cap for discounted orders); supply-mission timer + ready/delivered sound cues; class tags on map (SOL/SUP/MED/ENG/SNI).
- **WDDM composition cap.** Maximum 3 commander compositions per base area (size-independent). Over-cap attempts refund the exact cash charged (2,500–5,000 depending on composition).

### Defensive AI
- **Per-base defense budgets.** Statics, fortifications and mines capped per category scaling with barracks level. Statics and mines blocked while 3+ enemy ground units are inside base range; fortifications are not.

### Aircraft
- **EASA weapon category tags.** Loadout editor prefixes each entry with `[AA]`, `[AG]` or `[MR]` (multirole) derived from weapon config.

### Server Stability
- **Group-cap (144/side) permanent fix.** Patrol groups deleted on death; server-side empty-group GC (60 s sweep); orphan DefenseTeam cleanup on base capture.

### QoL and Fixes
- Manual vehicle-flip action; earplugs toggle (fades radio/voice, works while mounted); service-point map marker; team-total on transfer menu; EASA `[DEFAULT]` loadout row; supply-delivered sound; empty-vehicle despawn 20→30 min; camp-repair warning sound.
- Victory log fix (was crediting the loser); PVF dispatcher security fix (Call Compile → getVariable); queue-token collision stall fixed; JIP camp-marker colour fixed; map-click busy-poll fixed; service menu no longer lists enemy vehicles.
- WASPSTAT telemetry: `KILL`, `CAPTURE`, `ROUNDEND` RPT records for the miksuu.com rankings pipeline.
- Second HC slot ported from PR #24: both headless clients now seat in CIV correctly.
