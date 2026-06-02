# Mixed Saturation Strike — Design Spec

- **Date:** 2026-06-02
- **Status:** Draft for review (design locked, pre-implementation)
- **Branch:** `feat/drone-saturation-strike` (worktree `a2waspwarfare-drone`)
- **Scope:** `Missions/[55-2hc]warfarev2_073v48co.chernarus` (source-of-truth Chernarus mission; Takistan regenerated via LoadoutManager afterwards)
- **Relationship to prior work:** This is **System B** from the 2026-06-01 Combat Systems Pitch. System A (Air Logistics / supply helis) is the separate `feat/supply-helicopter` line. This feature is independent of System A.

---

## 1. One-liner

A commander-tier "powerup," called like the ICBM: paint a point on the map and a **5-drone package** (2 flare/decoy + 3 loitering munitions) streaks in from the map edge and saturates the area, hard-killing enemy **ground vehicles** while taxing — not deleting — a camped air-defense position. AI-free, server-authoritative, near-zero server cost.

## 2. Problem & goals

**Problem.** A single patient player on an AA emplacement can deny the entire sky for a round, farming expensive, slow-to-grind aircraft with no real counter. Pilots stop flying; the air war dies.

**Goal.** Give the air side a cheap, expendable, asymmetric tool that makes camping *cost* something — position, missiles, or a hole in the ground — without nerfing AA and without becoming a "win button."

**Design principles (inherited from the pitch, non-negotiable):**

1. **Cheap to run** — scripted objects, no AI pilot/FSM, coarse tick, capped, self-cleaning.
2. **Never 100% decisive** — scatter + hit-roll; a defended position survives; only an *under-defended* one is punished.
3. **Config-driven** — every balance value is a constant an admin can tune without a repack.
4. **Cheap vs. grind** — the package costs a fraction of the aircraft/missiles it threatens.

## 3. Player-facing design

### 3.1 Trigger & designation

- **Who:** commander-tier, gated behind the **existing UAV/Air upgrade** (reuse — no new upgrade node). *Locked 2026-06-02.*
- **How:** the existing **Tactical menu** (`Client/GUI/GUI_Menu_Tactical.sqf`). The drone strike is added as a **new `MenuAction` entry** alongside the six that already share that dialog's map (artillery, paratroopers, fast-travel, ICBM, vehicle drop, ammo drop).
- **Designation = map-click point (Option A).** Click a grid; the swarm flies there and auto-acquires ground vehicles in a radius. No operator piloting in v1.
- **Cost + cooldown + concurrent cap** enforced (see §6, §7.4). Server validates the request (do **not** inherit the legacy UAV's client-only authority gap).

### 3.2 The package (defaults, all tunable)

| Role | Count | Job |
|---|---|---|
| **Flare / CM drone** | 2 | Orbit the killers as a screen. Auto-pop flares to spoof incoming AA **missiles**, trail smoke to clutter the camper's view. Survivable bait. |
| **Loitering munition** | 3 | The real threat. Acquire a ground vehicle, top-attack dive, hard-kill warhead. |

All 5 use the **same airframe model per side** (cosmetic only — preserves the "which one is the killer?" dilemma). Count and mix are constants, not hardcoded.

### 3.3 Lifecycle

1. **Spawn** — 5 crewless airframes at a random map-edge corner (paratrooper-style ingress origin).
2. **Ingress** — scripted flight to the painted point (`setPosATL`/`setVelocity`, coarse tick), in a wedge formation, slots ≥15–20 m apart.
3. **Screen & search** — flare drones orbit and dispense CM/smoke; loiterers orbit and scan via `nearestObjects` every ~2 s.
4. **Acquire — or time out** — on a valid lock *or* after the loiter-endurance timer, commit. Acquisition can fail; it is never guaranteed.
5. **Strike (staggered)** — loiterers dive top-attack and detonate via `createVehicle` warhead at `targetPos ± scatter`. Dives are staggered (chain of explosions, not one blast).
6. **Despawn** — `deleteVehicle` on impact/timeout; nothing lingers; concurrent count capped.

### 3.4 Targeting rules

- **HIT:** enemy **ground vehicles** — light → heavy + **static AA** (AA prioritised in the target sort).
- **SKIP:** aircraft (this is a ground-strike, not a dogfighter) and infantry (no anti-personnel grief).
- **Selection:** `nearestObjects [zone, ["LandVehicle","StaticWeapon"], radius]` → filter to enemy side, exclude air/man, sort AA-first then by value.

### 3.5 Lethality model

- **Hard-kill, but *package*-lethal — not per-drone.** A single loiterer damages but does not reliably one-shot a hardened target; **three coordinated hits clear a position.** Light AA (ZU-23, MANPADS teams) likely dies to one; a hardened SPAAG may survive a single hit and need a second.
- **Scatter + hit-roll** guarantee it is never an auto-delete: a partial swarm (some drones shot down) leaves survivors.

### 3.6 Survivability & counterplay

Survivability is a **scripted HP model** via `HandleDamage` (see §7.5), *not* the airframe's native armor — so it is identical per faction and fully tunable.

- **Damage threshold: .50 cal (12.7 mm) and up.** Sub-.50 fire (5.56/7.62 rifles and LMGs) plinks below the line and does not meaningfully hurt them; .50/DShK and heavier cross the threshold and chip real HP.
- **Tier table (starting point, tune in playtest):**

| Weapon | Effect | Rationale |
|---|---|---|
| Dedicated AA missile | Fast kill (1–2), but **flare-spoofable** | The camper's tool — still works, just taxed |
| Autocannon / SPAAG / IFV cannon | Fast, **ignores flares** | Gun-AA is the skilful hard counter |
| Mounted / heavy MG (.50, DShK, KORD) | Effective with concentrated fire | A tracking crew-served gun should matter |
| Handheld LMG / rifle (<.50) | Negligible | A small moving drone is a hard target for a rifleman |

- **Key emergent dynamic — flares spoof missiles, not bullets.** The flare screen protects against the classic *missile*-AA camper, but a **gun**-based defender shreds the swarm because countermeasures do nothing against ballistic rounds. This is intentional rock-paper-scissors: the swarm is strongest against exactly the lazy SAM camper it is meant to punish, and a defender with a gun already has real counterplay.
- **Numbers game.** With 5 drones, a lone gunner *thins* but rarely *stops* the swarm before the loiterers commit; a layered defense (gun + AA + a second player) clears it. Under-defended → punished; defended → fine.

## 4. Faction balance — Pchela vs MQ9 (the explicit plan)

**Models (already declared in `Common/Config/Core_Root/Root_*.sqf` via `WFBE_%1UAV`):**

| Faction | Airframe | Source |
|---|---|---|
| USMC / CDF | `MQ9PredatorB` (Reaper) | `Root_USMC.sqf:18`, `Root_CDF.sqf:18` |
| US (Arrowhead) | `MQ9PredatorB_US_EP1` | `Root_US_Camo.sqf:19` |
| RU / INS / Takistani | `Pchela1T` (small recon drone) | `Root_RU.sqf:17`, `Root_INS.sqf:17`, `Core_TKA.sqf:245` |

**Decision: MIRROR balance.** The model is cosmetic; *all* mechanics come from a single faction-agnostic `WFBE_C_DRONE_*` constant block. Predator and Pchela are the same machine wearing different skins.

**Why this is the right call here.** The mission's *existing* UAV is **accidentally asymmetric** because it inherits the airframe's weapons — the Commander Guide literally notes *"BLUFOR uav is very useful… it gets hellfires. OPFOR uav, not so much."* Because our strike is script-driven (movement = `setPosATL`, kill = `createVehicle` warhead, flares = script), we *choose* symmetry instead of inheriting that imbalance.

**The two places the airframe could still leak into balance, and how we neutralize them:**

| Leak | Why it matters | Fix |
|---|---|---|
| **Native armor / HP** | A Reaper and a Pchela have different default damage thresholds → "hits-to-down" would differ by faction by accident. | Survivability is scripted (`HandleDamage` against `WFBE_C_DRONE_HP`) and we normalize the airframe (e.g. `setObjectArmor`/our own accounting), so the .50-cal threshold and hits-to-down are identical on both. |
| **Hitbox / visual size** | The MQ9 is physically bigger → a slightly easier target to hit; the small Pchela is naturally sneakier. | **Accept as cosmetic flavor** by default (a big Reaper *should* read as easier to spot than a tiny recon drone). If playtest shows the Reaper measurably dies faster, compensate with a single per-side `WFBE_%1DRONE_HP` override. |

**What is shared vs. per-side:**

- **Shared (default):** count/mix, ingress & loiter speed, loiter endurance, acquisition radius, warhead class, scatter, `.50` damage threshold, scripted HP, cost, cooldown, concurrent cap, dive stagger.
- **Per-side override path (built, unused by default):** the `WFBE_%1DRONE…` namespace pattern (mirrors `WFBE_%1UAV`) lets an admin diverge any single value later — e.g. give Pchela a hair more speed and the Reaper a touch more HP — *without code changes*. Picking mirror now does not lock the door to asymmetric flavor later.

**Tuning protocol:** ship symmetric → playtest both sides → only diverge a per-side constant if data shows a real gap. No speculative asymmetry (YAGNI).

## 5. Spectacle — how to make it look cool (cheaply)

**Rule (load-bearing): the server owns truth + movement; clients own the juice.** All audio/visual FX run client-side off a broadcast event, so they never cost the server.

### 5.1 v1 scope (locked 2026-06-02) — flares + a Stuka dive siren

Deliberately minimal for the first ship:

- **Flares** — the 2 flare drones pop flare/illum rounds on ingress and whenever the AA fires (the spoof moment). This is *both* mechanic (missile spoof) and spectacle. Cheap (a handful of objects).
- **Stuka dive siren** — when a loitering munition commits to its dive, play a Ju-87 "Jericho trumpet" siren as a 3D sound at the drone (`playSound3D`/`say3D`). Staggered dives (`WFBE_C_DRONE_DIVE_STAGGER`) chain the sirens into a rising, dread-inducing sequence. Requires a sound asset + `CfgSounds` entry (see §12).
- **Staggered converging dives** are kept (a near-free movement pattern that makes the siren chain land); the top-attack silhouette is a natural consequence.

That's the whole v1 juice: **no** smoke trails, **no** buzz loop, **no** announcer radio, **no** FPV cam.

### 5.2 Deferred to the juice pass (architecture leaves room)

Held for a fast-follow once v1 is proven in-engine: **smoke contrails**, a looped **drone buzz**, **announcer/radio** calls, **impact-chain** secondary FX, and the **FPV "money-shot" camera** on the lead drone. All client-side, capped, short-lived.

### 5.3 Emergent cinematics (free)

Defenders' tracers arcing up at the swarm (from the .50-cal counterplay) and night flares + chained explosions are dramatic with zero extra code.

## 6. Balance constants (proposed defaults — tune in playtest)

Defined in `Common/Init/Init_CommonConstants.sqf` as `WFBE_C_DRONE_*`. Values are starting points.

| Constant | Default | Meaning |
|---|---|---|
| `WFBE_C_DRONE_FLARE_COUNT` | 2 | Flare/decoy drones |
| `WFBE_C_DRONE_MUNITION_COUNT` | 3 | Loitering munitions |
| `WFBE_C_DRONE_INGRESS_SPEED` | ~55 m/s | Scripted transit speed |
| `WFBE_C_DRONE_LOITER_SPEED` | ~35 m/s | Scripted orbit speed |
| `WFBE_C_DRONE_LOITER_TIME` | ~90 s | Endurance before forced commit |
| `WFBE_C_DRONE_ZONE_RADIUS` | ~250 m | Acquisition radius around the painted point |
| `WFBE_C_DRONE_WARHEAD` | `"Sh_125_HE"` | **Locked.** Survivable tank-HE warhead (not instant-GBU) — hard-kill as a package, not per-drone |
| `WFBE_C_DRONE_SCATTER` | ~12 m | Impact scatter radius |
| `WFBE_C_DRONE_HP` | ~6 | Scripted hit-points ≈ number of .50-cal hits to down one drone |
| `WFBE_C_DRONE_MIN_HIT` | ~0.08 | Min normalized `HandleDamage` delta that counts; below this = sub-.50 plink, ignored |
| `WFBE_C_DRONE_COST` | ~22,000 | Commander funds cost (**mid-tier**) |
| `WFBE_C_DRONE_COOLDOWN` | ~360 s | Reuse cooldown (**mid-tier**) |
| `WFBE_C_DRONE_CONCURRENT_CAP` | 1 | Max packages in flight per side |
| `WFBE_C_DRONE_DIVE_STAGGER` | ~1.5 s | Gap between loiterer dives (chains the siren) |
| `WFBE_C_DRONE_DIVE_SOUND` | `"drone_stuka"` | `CfgSounds` key for the Ju-87 dive siren played on commit |

## 7. Technical architecture

### 7.1 Authority model

**Server-authoritative.** The orchestrator (movement, sensing, strike, lifecycle, HP) runs server-side so the package survives the launching player disconnecting and there is a single source of truth — exactly how `Server/Support/Support_UAV.sqf` already manages the UAV. **Clients only render FX** (smoke/flares/sound/cam) off broadcast events.

### 7.2 Reuse map

| Need | Reuse | File |
|---|---|---|
| Launch UI + map-click + funding + gate + markers | Clone the **ICBM** `MenuAction` block | `Client/GUI/GUI_Menu_Tactical.sqf` (~lines 464–506) |
| Server entry point | New `case "DroneStrike":` | `Server/Functions/Server_HandleSpecial.sqf` |
| Edge-spawn → fly-to-point ingress | Model on **paratrooper** support | `Server/Support/Support_Paratroopers.sqf` |
| Crewless airframe + cleanup | UAV module patterns | `Client/Module/UAV/uav.sqf`, `Server/Support/Support_UAV.sqf` |
| Flares / incoming-missile reaction | IRS / CM module | `Client/Functions/Client_BuildUnit.sqf` (`incomingMissile` EH) |
| Damage classification precedent | Reaktiv ERA `HandleDamage` | Reaktiv module |
| Per-side model var | Mirror `WFBE_%1UAV` | `Common/Config/Core_Root/Root_*.sqf` |

### 7.3 Files touched

**New:**
- `Server/Support/Support_DroneStrike.sqf` — the orchestrator (spawn, formation flight, flare screen, acquire, staggered dive, scripted HP, cap, despawn). ~160–220 LOC. The only substantial new code.
- `Client/Module/DroneStrike/dronestrike_fx.sqf` — client FX (flares + Stuka dive siren) off broadcast events. ~40 LOC.
- A Stuka dive-siren sound asset (e.g. `Sounds/drone_stuka.ogg`).

**Edited:**
- `Client/GUI/GUI_Menu_Tactical.sqf` — new listbox entry + `MenuAction` enable/disable case + map-click block (clone ICBM); gate check **reuses the UAV/Air upgrade**.
- `Server/Functions/Server_HandleSpecial.sqf` — `case "DroneStrike"`.
- `Common/Init/Init_CommonConstants.sqf` — `WFBE_C_DRONE_*` constants.
- `Common/Config/Core_Root/Root_*.sqf` — `WFBE_%1DRONE` model var (defaults to `WFBE_%1UAV`).
- `description.ext` — `CfgSounds` entry for `drone_stuka`.
- `stringtable.xml` — localized strings.

### 7.4 Server validation

The `RequestSpecial`→`Server_HandleSpecial` path must validate: side, upgrade level, funds ≥ cost, cooldown elapsed, concurrent cap not exceeded — **server-side**, before spawning. Reject otherwise. (Deliberately *not* replicating the UAV's client-authoritative buy.)

### 7.5 Crewless-airframe flight & survivability — known gotchas

- **Empty aircraft will be simulated** (pitch/roll/fall). The orchestrator overrides with `setPosATL`/`setVelocity`/`setVectorDirAndUp` each tick; evaluate `enableSimulation false` + pure positional drive vs. gentle velocity during the spike (§9).
- **Collision:** formation slots ≥15–20 m apart so `setPosATL`'d airframes don't collide-and-explode. Pchela (smaller) is more forgiving.
- **Damage read:** confirm at build time the cleanest way to classify a hit as ≥.50 in Arma 2 OA — raw `HandleDamage` magnitude threshold vs. a `HitPart`/`incomingMissile`-style classify. Both the IRS and Reaktiv modules prove the engine exposes enough; this is a known-solvable detail, not a risk.

## 8. Server-cost guardrails

- No AI pilots/FSMs anywhere; one server loop iterates the array of dumb objects.
- Coarse tick (0.5–2 s) for sense/move, not per-frame.
- Hard concurrent cap (`WFBE_C_DRONE_CONCURRENT_CAP`) — reject launches over it.
- Hard lifetime — auto-despawn on impact/timeout; no orphans.
- FX client-side, capped, short-lived.

## 9. Risks & mitigations

| Risk | Level | Mitigation |
|---|---|---|
| **MP locality / authority** | Med–High | Run the whole loop server-side (`Support_DroneStrike.sqf`); clients only render FX. ½-day spike first. |
| **`setVelocity` vs flight model** | Med | Spike one crewless airframe loitering a clean circle before building the swarm; choose `enableSimulation false` + positional drive vs. velocity drive. |
| **AA target sensing reliability** | Med | Curated per-side enemy-AA/vehicle classname filter; AA-first sort. |
| **Damage classification (≥.50)** | Low–Med | Threshold on normalized `HandleDamage` magnitude; fall back to IRS/Reaktiv pattern. |
| **Balance / "win button"** | Low | Scatter + hit-roll + `.50` counterplay + caps; every value a constant. |
| **Server performance** | Low | Scripted, no AI, coarse tick, capped, self-cleaning, client-side FX. |
| **Maintainer acceptance / content compat** | Low | Isolated module, vanilla already-loaded airframes, follows existing patterns, server-validated. |

## 10. LOC estimate

| Part | LOC | Nature |
|---|---|---|
| Tactical-menu entry (clone ICBM block) | ~50 | edit, mostly copy |
| `Server_HandleSpecial` case | ~10 | edit |
| `Support_DroneStrike.sqf` orchestrator | ~160–220 | **new** — the real work |
| Client FX script (smoke/flare/sound) | ~40–70 | new (can start minimal) |
| Constants + model var + upgrade gate | ~25 | new/edit |
| `stringtable.xml` | ~8 | new |
| **Total** | **~300–380 new / ~60 edited, ~6 files** | almost entirely reuse |

## 11. Phasing

1. **Spike** (½ day) — prove one crewless airframe loiters a clean circle server-side. De-risks everything.
2. **v1 core** — map-click launch + 5-ship package + flare screen + acquire + staggered hard-kill dives (`Sh_125_HE`) + Stuka dive siren + `.50` survivability + cap/despawn. Reuse UAV/Air gate. Mirror balance. Mid-tier cost. **Shippable.**
3. **Juice pass** — smoke contrails, looped drone buzz, announcer/radio calls, impact-chain FX, FPV money-shot cam.
4. **Follow-ups** (separate PRs): reveal-on-bait (paint the AA on the team map when it fires), laser-designate (Option C — `LaserTarget` homing), operator FPV cam (Option 2 money-shot).

## 12. To confirm at build time

- Exact Arma 2 OA mechanism to classify a hit as ≥.50 (`HandleDamage` magnitude vs `HitPart`).
- `setPosATL` vs `setVelocity` vs `enableSimulation false` for clean scripted flight (spike outcome).
- **Source the Stuka dive-siren sound** (.ogg) + add the `CfgSounds` entry in `description.ext` keyed `drone_stuka`.
- Final scatter value that delivers "hard-kill package, not per-drone one-shot."

*Decided 2026-06-02:* gate = reuse UAV/Air upgrade · warhead = `Sh_125_HE` · rarity = mid-tier · v1 juice = flares + dive siren only.

## 13. Out of scope (YAGNI for v1)

- Operator piloting / free-flight control (FPV *watch* only, and deferred).
- AI-AA reveal/targeting manipulation (campers are human; not needed).
- Stats/leaderboard integration (a later meta-layer phase).
- Per-side asymmetric tuning (architecture supports it; not used at ship).
