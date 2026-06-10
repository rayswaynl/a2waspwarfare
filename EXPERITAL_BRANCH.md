# WASP Warfare — `experital` branch

**Experimental feature branch** built on `release/2026-06-feature-bundle` (`a96fdda2`). Ships as a separate optional mission **"WASP Experital TEST"** for the Hetzner test server, alongside (not replacing) the PR8 default. Every feature is individually toggleable via a `WFBE_C_*` gate; all default ON in this mission, all byte-identical to baseline when gated off.

> Status: **All 21 work items complete (~84 commits) — feature-complete and DEPLOYED.** Live on the Hetzner test server (78.46.107.142) as the optional mission `WASP_Experital_TEST.Chernarus` since 2026-06-10, alongside the untouched PR8 default. Player-facing Discord changelog delivered.

---

## Features

### Economy & balance
- **Ammo-proportional rearm pricing** (`WFBE_C_SUPPORT_REARM_PROPORTIONAL`) — rearm now costs in proportion to ammo actually missing (10% floor of base); a near-full vehicle pays ~10%, empty pays full. Artillery exempt. Brings rearm in line with repair/refuel which already scale.
- **Per-factory production queue caps** (`WFBE_C_FACTORY_QUEUE_LIMITS`) — queue size scales with factory level: Barracks `lvl+2`, Light/Heavy/Aircraft `lvl+1`. Buy menu shows `N/CAP`.
- **Federal Reserve / Bank Rossii** (`WFBE_C_ECONOMY_BANK`) — 9,500-supply endgame structure, must be built >800 m outside your base, one per side, global map marker both sides (it's a raid objective). Drips a fixed **$5,000 pool split among living owning-side players** every 5 min while the side's HQ stands. Destruction reward: **+40,000 side supply + $7,500 to the killer** (post-balance — was a flat 150k-to-one-wallet whale mechanic).

### New structures (WDDM compositions)
- **Counter Battery Radar** (`WFBE_C_STRUCTURES_COUNTERBATTERY`) — 2,400-supply buildable that marks enemy artillery firing positions for 75 s. Requires your own Anti-Air Radar alive (mid-game gate). Detection is **event-driven** off the artillery `Fired` handler (no polling). Upgrade `WFBE_UP_CBRADAR` extends radius 750 → 1,500 → 2,000 m. Per-radar radius override (`wfbe_cbr_radius`) wired for the airfield CBR. Built as a multi-object composition, not a bare model.
- **Composition cost & cap** — WDDM commander compositions cost **cash** (2,500–5,000, registered in `Core_CIV.sqf`); now capped at **max 3 per base area, size-independent** (`WFBE_C_WDDM_COMP_CAP=3`), and exempt from the per-object defense budget. Cap-reject refunds the exact cash charged.

### Units
- **Medic Redeployment Truck** (`WFBE_C_UNITS_REDEPLOYTRUCK`) — a medic mobility tool, not a team spawn: only **medics** can respawn at it (violet buy-menu row, Light Factory). Activates when parked (engine off, stationary), with a cargo seat free, and ≥500 m from non-friendly towns.

### Commander tools
- **Site Clearance** (`WFBE_C_UNITS_BULLDOZER`) — commander-only build-menu action (the `Land_Pneu` anchor) that fells trees in a 25 m radius for 10 supply/tree. Commander-gated via a dedicated `RequestSiteClearance` PVF (real requester validation), excluded from the repair-truck menu.
- **Commander QoL cluster** — upgrade start/complete sounds + a drift-free RHUD upgrade countdown; production-queue **cancel** with price-at-order refund (capped at 50% for attack-wave-discounted orders); supply-mission timer + ready/delivered sound cues for the Support class; **class tags on the map** (SOL/SUP/MED/ENG/SNI) via a `wfbe_player_class` broadcast.

### Defensive AI
- **Per-base defense budgets + categorized threat gating** (`WFBE_C_DEFENSE_BUDGET`) — caps base defenses per category scaling with barracks level (statics `6+2·lvl`, fortifications `20+10·lvl`, mines `10+5·lvl`); statics & mines blocked while enemies are near base, fortifications not. Reject paths refund correctly.
- **Captured towns spawn AI gunners again** (`WFBE_C_TOWNS_GUNNERS_ON_CAPTURE`) — regression fix: WEST/EAST-captured towns now spawn + man their static defenses on capture (was resistance-only since a defense-rework regression). Gunners join the persistent side DefenseTeam — no per-gunner group creation. 103 defense slots across all 36 towns.

### Server stability
- **Group-cap (144/side) permanent fix** — A2's hard 144-groups-per-side ceiling caused silent AI-spawn failure / lockup in long sessions. Three changes make it structurally unreachable: delete patrol groups on death (the dominant leak), a **server-side empty-group garbage collector** (sweeps zero-unit non-persistent groups every 60 s), and orphan-DefenseTeam cleanup on base capture. Re-created defense teams re-flagged persistent so the GC can't catch them mid-population. *(This fixes a pre-existing production lockup, not just experital features.)*

### Aircraft
- **EASA weapon category tags** (`WFBE_C_EASA_CATEGORIES`) — the aircraft-loadout editor now prefixes each loadout with `[AA]` / `[AG]` / `[MR]` (multirole), auto-derived from weapon config with a per-class cache + manual-override table. Display-only.

### Airfield capture points
- **Airfield capture objectives** (`WFBE_C_AIRFIELDS`) — NWAF, NEAF and Balota Airfield are now live capture towns (50-supply, `PMCAirfield` garrison type). Defended by up to ~18 PMC infantry (Squad/Team/AT/Sniper) + Motorized and AA_Light vehicle groups across 6 spawn slots (70% infantry budget). Capturing an airfield spawns a **side-correct repair point** (`WFBE_RepairTruckServicePoint=true`, registered in side-logic structures, map marker via `Init_BaseStructure`) and an **exclusive hangar** on the matching `LocationLogicAirport` entity. The hangar's buy menu overrides to `WFBE_AIRFIELD_UNITS` — a curated cross-faction roster (`L39_TK_EP1`, `An2_TK_EP1`, `Mi17_Ins` on Chernarus) available **nowhere else**. Recapture deletes the previous owner's SP and hangar, cleans up the side-logic structures list, and re-spawns for the new side. The `Init_Airports.sqf` auto-hangar path is skipped for flagged airports so lifecycle is fully capture-event-driven.
- **Airfield built-in Counter Battery Radar** — every captured airfield also gives its owner a permanent, indestructible 2,000 m CBR (`Land_Antenna` core + dressing, `wfbe_cbr_radius=2000`, `HandleDamage`-immune). Ownership follows the airfield: explicit registry hand-off on recapture (the indestructible radar can't be pruned lazily, so removal is event-driven). Resistance captures get no radar (no GUER CBR registry). Gated on both `WFBE_C_AIRFIELDS` and `WFBE_C_STRUCTURES_COUNTERBATTERY`.

### Capture-to-unlock premium units
- **Capture-to-unlock** (`WFBE_C_CAPTURE_UNLOCKS`) — holding **Krasnostav** unlocks the **Czech T-72** (`T72M4CZ_ACR`, Heavy factory lvl 4, $7,000); holding **NW Airfield** unlocks the **RM-70** rocket-MLRS (`RM70_ACR`, Light factory lvl 4, $6,800, full artillery integration: map markers + fire-mission menu). Both newly registered ACR units, added to **both sides'** arrays — whichever team holds the trigger town can build them **at its own factories** (ownership + factory level gated, via a forEach/exitWith scan — A2OA has no findIf). Distinct from the airfield-exclusive aircraft. Takistan trigger names (Loy Manara AF → T-72, Rasman AF → RM-70) carried as data for the regenerated build. AI commanders may buy these unconditionally (accepted as AI privilege, documented).

### Telemetry
- **WASPSTAT** (`WFBE_C_STATLOG`) — extends the existing `WASPSTAT|v1` RPT line family with `KILL` / `CAPTURE` / `ROUNDEND` records (killer+victim, town ownership change, round winner+duration) for the future miksuu.com rankings pipeline. Format documented in `docs/WASPSTAT-FORMAT.md`.

---

## Cleanup, QoL & fixes
- **Wiki-verified fixes** — victory log was crediting the **loser** (poisoned win stats); PVF dispatcher `Call Compile`→`getVariable` (RCE-vector + perf); queue-token collision stall; JIP camp-marker colour; map-click busy-poll; service menu listing enemy vehicles.
- **Small-wins batch** — dead-code removal (Client_TaskSystem, UAV dev branch), malformed config-array fix, ungated log gated.
- **8-item QoL** — manual vehicle-flip action, earplugs toggle, service-point map marker, team-total on transfer menu, EASA `[DEFAULT]` loadout row, supply-delivered sound, empty-vehicle despawn 20→30 min, camp-repair warning sound.
- **Review-driven catches (fixed):** WDDM cap was a **money-loss** (cap-reject took cash, no refund); group-GC could delete a **re-created defense team** before population (persistent flag re-applied); EASA `[DEFAULT]` double-added factory weapons on a fresh vehicle.

## Infrastructure
- **Harness error-tracker wiring** (tools branch) — RPT scan patterns attribute errors from every new subsystem; live-watch counts CBR/bank/site-clearance/WASPSTAT activity; static smoke requires the new PVFs registered.

---

## Process
Subagent-driven: each feature implemented by a fresh agent, then **spec-reviewed and (for high-stakes changes) adversarially reviewed** before acceptance. **Full 7-dimension cross-feature review complete** — found & fixed 2 integration blockers that per-task review couldn't see: Site Clearance was a silent no-op (`Server_SiteClearance` never compiled into `Init_Server`), and EASA category tags always returned `[AG]` (a double-`select 0` iterated a string's characters). All feature gates declared, all new PVFs wired, gate-off paths inert, feature stacks compose cleanly. A second **6-dimension mission-compatibility audit** (each finding adversarially verified) cleared the airfield/CBR/unlock additions against the base mission. **Branch is feature-complete and deploy-ready.**

_Pre-existing, logged (not introduced here): `airRaid` nuke-warning sound in `NukeIncoming.sqf` has no CfgSound entry._

## Remaining
- ✅ **Airfield capture points** — implemented (Task 12), see Features section above.
- ✅ **Airfield built-in CBR** — implemented, see Features section above.
- ✅ **Capture-to-unlock premium units** — implemented (Tasks 21–22), see Features section above. *(Takistan trigger names — Loy Manara AF → T-72, Rasman AF → RM-70 — carried as data for the regenerated build.)*
- ✅ **Pack / smoke / deploy** — deployed 2026-06-10 as `MPMissions\WASP_Experital_TEST.Chernarus` (folder deploy, matching the box's existing convention; 800 files, generated `version.sqf` included). Static smoke 31/33 — the 2 fails are baseline drift (AARadar-wall removal + AFKkick module split exist only on `master`, post-date this branch's base; the AFK xor fix itself IS present in this branch's `updateclient.sqf`). One-shot `WFBE_CLASSCHECK` RPT probes wired into the deployed copy's `initJIPCompatible.sqf` (deploy-only, not in git). PR8 default mission and the running server untouched. **Known box limitation:** ACR DLC cannot decrypt on this headless server, so `T72M4CZ_ACR`/`RM70_ACR` are expected to fail the classcheck there — the unlock *gate logic* is what's testable on this box; the units themselves need a DLC-capable host.
- ✅ Player-facing Discord changelog — delivered 2026-06-10 (3 blocks, capture-unlocks included as shipped).

**Deferred (not blocking):** group-cap pre-warning log & zombie-disconnect cleanup; buy-tab array hoist (owner declined); hitpoint-aware paid repair (no A2 command precedent).
