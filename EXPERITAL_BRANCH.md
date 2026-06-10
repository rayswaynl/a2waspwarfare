# WASP Warfare — `experital` branch

**Experimental feature branch** built on `release/2026-06-feature-bundle` (`a96fdda2`). Ships as a separate optional mission **"WASP Experital TEST"** for the Hetzner test server, alongside (not replacing) the PR8 default. Every feature is individually toggleable via a `WFBE_C_*` gate; all default ON in this mission, all byte-identical to baseline when gated off.

> Status: **18 / 21 work items complete (~68 commits)**. Living doc — updated as work lands. Player-facing Discord changelog is produced separately at deploy.

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
Subagent-driven: each feature implemented by a fresh agent, then **spec-reviewed and (for high-stakes changes) adversarially reviewed** before acceptance. **Full 7-dimension cross-feature review complete** — found & fixed 2 integration blockers that per-task review couldn't see: Site Clearance was a silent no-op (`Server_SiteClearance` never compiled into `Init_Server`), and EASA category tags always returned `[AG]` (a double-`select 0` iterated a string's characters). All 10 gates declared, all 4 new PVFs wired, gate-off paths inert, feature stacks compose cleanly. **Branch is deploy-ready pending the airfield feature.**

_Pre-existing, logged (not introduced here): `airRaid` nuke-warning sound in `NukeIncoming.sqf` has no CfgSound entry._

## Remaining
- ⏳ **Airfield capture points** — NWAF/NEAF/Balota as ~50-SV capture towns, **PMC garrison** (`Core_PMC.sqf` present), **repair point spawned on capture**, **`L39_TK_EP1`** buyable while you hold the airfield. *Minimal scope (owner): no hand-placed static-defense logics.*
- ⏳ **Airfield built-in CBR** — permanent 2,000 m radar following the airfield owner
- ⏳ **Pack / smoke / deploy** to Hetzner as the optional mission + RPT classname checks
- ⏳ Player-facing Discord changelog (at deploy)

**Deferred (not blocking):** group-cap pre-warning log & zombie-disconnect cleanup; buy-tab array hoist (owner declined); hitpoint-aware paid repair (no A2 command precedent).
