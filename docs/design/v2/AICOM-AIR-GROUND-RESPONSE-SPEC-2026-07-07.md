## AICOM Air-vs-Ground Response Split — Research Spec

**V2 §10.7 · research-first · read-only recon · repo `a2waspwarfare` · branch `origin/claude/build84-cmdcon36`**

Owner intent (from assignment): ground teams stay town-first/road-following (the Allocator's concentrated fist, PR #715 lineage); helicopters and jets should respond **faster and more flexibly** to player pushes and threaten/support lanes **organically** — but must remain **NOT omniscient**. This doc inventories what air response exists today, confirms the two known gates, and specs a bounded main-side (W/E) air-response mechanism designed to slot in beside the live DECAPITATE closer without disturbing it.

All evidence below is cited `file:line` against `origin/claude/build84-cmdcon36`, Chernarus tree (`Missions/[55-2hc]warfarev2_073v48co.chernarus/…`, the source of truth per `wasp-borrow-shortlist`/LoadoutManager convention — Takistan/Zargabad under `Missions_Vanilla/` mirror it byte-for-byte at the cited paths).

---

### 1. Inventory: what air response exists today

#### 1.1 Ground AICOM (W/E) — the town-first fist, for contrast

`AI_Commander.sqf:517-524` runs the v2 maneuver chain every `WFBE_C_AI_COMMANDER_STRATEGY_INTERVAL` (default 60s, `AI_Commander.sqf:507`) tick: **Snapshot → Strategy → Allocate → Decapitate**. The Allocator (`AI_Commander_Allocate.sqf`) concentrates the side's offensive fist on `WFBE_C_AICOM2_FIST_TOWNS` (default 2, `Init_CommonConstants.sqf:735`) nearest-front towns and writes `wfbe_aicom_targets` — the single source of ground truth for where teams walk/drive. This is the "town-first, road-following" fist the assignment says must stay untouched.

#### 1.2 `AI_Commander_Decapitate.sqf` — confirmed GROUND-ONLY

The M5 "kill-move" closer stamps `wfbe_aicom_decap` on teams already pressing near a sensed, dominant enemy HQ. Both eligibility passes — the **sensing** loop and the **commit/stamp** loop — carry an explicit hull-type exclusion:

```
if (_t != _garTeam && {!_isHolding} && {!isPlayer (leader _t)}
    && {({alive _x && {(vehicle _x) isKindOf "Air"}} count (units _t)) == 0}) then {
```
— `AI_Commander_Decapitate.sqf:98` (sensing eligibility) and `AI_Commander_Decapitate.sqf:178` (stamp eligibility), both tagged `//--- stack-pass: GROUND contract - a team with any live unit currently in an Air hull neither senses nor is stamped`.

So a team with even one live member currently in an `Air` hull is invisible to DECAP on both ends: it neither contributes to the proximity/dominance ARM streak nor can be stamped to press the HQ. DECAP's whole organic-sensing model (proximity + periodic dice roll + latch + dominance ratio, `AI_Commander_Decapitate.sqf:1-24` header) is a **ground-only closer**; nothing symmetrical exists for air.

Flag note (documentation drift found in recon, not part of this spec's ask but relevant to §3): `Init_Server.sqf:83` comments the compile as `flag WFBE_C_AICOM2_DECAP_ENABLE, default 0`, but `Init_CommonConstants.sqf:740` actually ships `WFBE_C_AICOM2_DECAP_ENABLE = 1` (armed live, per the `//--- v2try (Ray 2026-06-27): brain ON for the live try-out` convention used on the sibling `ALLOCATE_ENABLE` flag at `Init_CommonConstants.sqf:734`). **DECAP is live by default today**, not shadow-mode — any new air mechanism that reads/writes near `wfbe_aicom_decap` must be built and tested against that fact, not the stale comment.

#### 1.3 `Server_GuerAirDef.sqf` — confirmed GUER-ONLY

Header: *"GUER has NO AI commander (so no wildcard deck) — any GUER air must be a STANDALONE server loop."* (`Server_GuerAirDef.sqf:4`). Gate: `if ((missionNamespace getVariable ["WFBE_C_GUER_AIRDEF_ENABLE", 1]) < 1) exitWith {};` (`Server_GuerAirDef.sqf:46`) — keyed purely off town `sideID==WFBE_C_GUER_ID` + `wfbe_active`; the B62 comment explicitly says this must run "regardless of whether GUER is the playable side" (`Server_GuerAirDef.sqf:44-45`).

This is a tight **~120s** (`WFBE_C_GUER_AIRDEF_INTERVAL`, `Server_GuerAirDef.sqf:50`) maintain loop, per-GUER-town, spawning at most one Ka-137/Mi-24 defender per active GUER town under a global alive cap (`WFBE_C_GUER_AIRDEF_MAX`, default 4). Priority order is genuinely reactive and locally-sensed (no global knowledge): enemy air present → counter-air Igla loadout (`Server_GuerAirDef.sqf:332`); else ground attack near the town → 18% paradrop roll (`:336-341`); else large town under attack → 25% Mi-24 roll (`:342`); else 20% AT-5 roll (`:343`); else default recon-MG Ka-137. Sensing is a bounded `nearEntities` scan around each town (`:304`, `:309`), not global. This is a strong **shape reference** for "organic, locally-triggered" air behaviour, but it is architecturally standalone (no `AICOM`, no snapshot, no team registry) and hard-scoped to `resistance`. It cannot be reused verbatim for W/E, which do have a commander/team/snapshot stack.

#### 1.4 What W/E air response DOES exist today: the Wildcard deck (thin, non-organic)

`AI_Commander_Wildcard.sqf` is the *only* current W/E path to AI-directed offensive air action. It is a **per-side lottery**, one card drawn every `WFBE_C_AI_COMMANDER_WILDCARD_INTERVAL` (default **1800s = 30 min**, `AI_Commander_Wildcard.sqf:75,92`), weighted over a ~15-card deck (total weight 123, header `:8-33`). Air-relevant cards and their weights:

| Card | Weight/123 | Behaviour | Evidence |
|---|---|---|---|
| W6 Air Cavalry | 8 | Founds one elite air-assault team at the spearhead front town (reuses `Common_RunCommanderTeam` air-insertion) | `AI_Commander_Wildcard.sqf:15-17, 323-360` |
| W13 Gunship Strike | 6 | One attack heli, single pass on the **largest enemy cluster** (by `allUnits` side-filtered count within 300m of a candidate town), self-despawns after 90s | `AI_Commander_Wildcard.sqf:26, 997-1044` |
| W19 Heliborne QRF | 5 | Air-inserts a QRF squad to the friendly town most under threat (reuses W6's resolved air template) | `AI_Commander_Wildcard.sqf:32, 471-478` |
| W22 Top Gun | 6 | Fixed-wing air-superiority fighter loiters the front ~180s hunting enemy aircraft, self-despawns | `AI_Commander_Wildcard.sqf:49, 499-511` |

**Assessment against the owner's ask:** W13's targeting *is* locally reactive — it counts real units (which includes players; `allUnits` is not AI-only) clustered near a candidate town — so there is a kernel of "responds to where the fight actually is." But the whole mechanism is gated behind a **30-minute per-side lottery slot shared with 11 unrelated economy/reinforcement cards**, not a continuous or bounded-interval sense loop. A player push that starts and resolves inside a 30-min window has a real chance of drawing *zero* air response. There is no "helicopters/jets respond faster and more flexibly to a developing push" behaviour today for W/E — only "maybe once every half hour, if the dice pick the right one of fifteen cards, one aircraft makes a single pass."

#### 1.5 Adjacent prior art worth reusing

- **Snapshot already tracks players.** `WFBE_SNAP_PLAYERS=21; WFBE_SNAP_MYPLAYERS=22;` (`Init_CommonConstants.sqf:724`), refreshed every strategy tick by `AI_Commander_Snapshot.sqf` before `Allocate`/`Decapitate` run (`AI_Commander.sqf:517-522`). `WFBE_SNAP_TGTTOWNOBJS=25` (the Allocator's live front-town object list) is exactly what DECAP already walks to find the town nearest the enemy HQ (`AI_Commander_Decapitate.sqf` "`_tgtTowns = _snap select WFBE_SNAP_TGTTOWNOBJS`"). Any new mechanism gets a free, already-ticking "where is the fight / are there players there" signal without a new scan.
- **Air-transport teams are already special-cased for reach**, precedent for treating air differently within the existing town-first framework rather than bolting on a parallel system: `AI_Commander_AssignTowns.sqf:648` computes `_teamAir` (does this team carry a transport heli); `:699` and `:733` gate naval-HVT targeting to `_teamAir` teams only ("B756... naval-HVT targets are air-team-only (offshore decks) - a ground team skips them"). This is the one place in the codebase where AICOM already reasons "this team type can reach somewhere a ground team can't, so give it a different target set" — the shape any air-response spec should extend, not replace.
- **`wfbe_active_air` — a town-level "air-only contact" flag already exists**, but scoped to GUER Director (lane 800), not usable off-the-shelf for W/E maneuver: `server_town_ai.sqf:207-233` computes an altitude-banded dice roll (`AICOMV2_GDIR_AIR_CEILING_MIN_M`/`MAX_M`) that flips a town to "air-only activation" (spawns an AA-tier garrison instead of a full ground garrison) purely from **local** `nearEntities`-style detected-air-contact data, gated by `if ((missionNamespace getVariable ["AICOMV2_LANE_GUER_DIRECTOR", 0]) > 0 …)` (`:208`). It is a *defensive garrison* trigger, not an offensive maneuver trigger, and it is currently only reachable when the GUER Director lane is armed — but the altitude-banded-roll pattern ("close/low = certain, far/high = probabilistic, nothing beyond a ceiling") is a second organic-sensing template alongside DECAP's proximity+dice+latch, and is explicitly *not omniscient* by construction (it only sees what's near the town).

**Bottom line of the inventory:** W/E has zero continuous, bounded-interval, player-push-reactive air maneuver mechanism. It has (a) a slow lottery card that occasionally sends one aircraft somewhere locally-relevant, (b) a hard GROUND-only closer that structurally cannot see or use air units, and (c) two pieces of borrowable machinery (GUER's tight sense-loop shape, and the DECAP/GDIR organic-sensing templates) neither of which is wired for main-side air today.

---

### 2. Proposed mechanism: bounded W/E air-response (`AICOM2 AIRRESP`)

Working name: **`AI_Commander_AirResp.sqf`** (M6, sibling to `AI_Commander_Decapitate.sqf` in the v2 chain), flag `WFBE_C_AICOM2_AIRRESP_ENABLE` (**default 0** — shadow/inert, matching the DECAP-header convention of "byte-identical to HEAD" until armed, and unlike DECAP's *current* live-1 default, this ships genuinely dark per the assignment's "flag + default-off" instruction).

#### 2.1 Trigger

Runs from the same v2 maneuver chain, immediately after DECAP (`AI_Commander.sqf:524`), so it reads the same already-fresh `wfbe_aicom2_snap` and the Allocator's `wfbe_aicom_targets`/`WFBE_SNAP_TGTTOWNOBJS` — no new scan cost, same 60s (`WFBE_C_AI_COMMANDER_STRATEGY_INTERVAL`) cadence as the rest of the maneuver brain. A tighter internal cadence is available cheaply: like DECAP's own `_senseInterval`/dice-roll pattern (`AI_Commander_Decapitate.sqf:96-135`), AIRRESP can re-roll every N strategy ticks rather than every strategy tick, so its reaction time is tunable independent of the 60s tick without a second `while{}` worker.

Trigger conditions to ARM a response (all must hold, mirroring DECAP's arm-then-commit shape so review/soak tooling that already understands DECAP's telemetry vocabulary generalizes):

1. **PROXIMITY-OF-PLAYERS-TO-A-LANE** — at least one enemy-side player (from `WFBE_SNAP_PLAYERS`/a bounded `nearEntities` pass around the current front towns, *not* a global player list scan) is within `AIRRESP_SENSE_RADIUS` of a town that is either (a) one of the side's own `WFBE_SNAP_OWNTOWNOBJS` under threat, or (b) one of the Allocator's `WFBE_SNAP_TGTTOWNOBJS` (a town this side is already assaulting). Both cases are "a lane the ground fist already cares about," per owner intent (§2.2).
2. **DICE ROLL, LATCHED** — same shape as DECAP: every `AIRRESP_SENSE_INTERVAL` ticks, roll `AIRRESP_SENSE_CHANCE`; success latches "sensed" until contact is lost (`_inRange == 0` → decay, mirroring `AI_Commander_Decapitate.sqf:114-116`). This is what keeps the mechanism non-omniscient: it does not fire the instant a player logs a push, it fires only after a sensed-and-sustained local contact, same as DECAP's HQ sensing.
3. **AIRFRAME AVAILABLE** — side has researched air (`_upgrades select WFBE_UP_AIR > 0`, the same gate W6/W13/W22 already use, `AI_Commander_Wildcard.sqf:397,504`) and a live/producible airframe exists in `WFBE_<side>AIRCRAFTUNITS`.
4. **BUDGET** — a global alive-cap on AICOM2 maneuver air (own counter, `AIRRESP_MAX_AIR`, separate from Wildcard's one-shot spawns and separate from `WFBE_C_GUER_AIRDEF_MAX` — the GUER cap is a different side's economy and must not be shared) so this cannot stack with W6/W13/W19/W22 into an air-spam ceiling breach.

On ARM, unlike DECAP's binary COMMIT/HOLD, AIRRESP dispatches a **response flight** (existing team-founding path, `Common_RunCommanderTeam`/`WFBE_CO_FNC_PickLeastLoadedHC`, same idiom W6/W13 already use) tasked to loiter/patrol the sensed lane rather than a single scripted pass — this is the "more flexible" half of the ask: an AICOM-founded team with `wfbe_teammode`/`wfbe_teamgoto` (the same order vocabulary `AI_Commander_Execute.sqf:26-30` already drives) set to a patrol/defense mode over the contested town, re-orderable on the next tick if the sensed lane shifts, instead of a Wildcard one-shot that cannot retarget mid-flight.

#### 2.2 "Organically relevant" — definition

Reuse and extend the Allocator's own definition of relevance rather than inventing a new one: a lane is organically relevant to AIRRESP if and only if it intersects either (a) an entry in `WFBE_SNAP_TGTTOWNOBJS` (the ground fist's current 1-2 target towns — where the Allocator has already decided the war is happening) or (b) an `WFBE_SNAP_OWNTOWNOBJS` town currently `wfbe_active`/`wfbe_active_air` (i.e. the existing town-activation FSM has *already, independently* detected enemy presence there via `server_town_ai.sqf`'s own nearEntities sweep — reusing that flag means AIRRESP never runs its own second detection pass over the whole map). This deliberately **excludes** rear towns, the enemy capital in isolation (that is DECAP's job, gated separately, §2.3), and anywhere no ground fist or town-activation signal already exists — i.e. AIRRESP can only ever react to a lane the rest of AICOM has *already, locally* noticed, which is the concrete mechanical definition of "not omniscient" for this spec: it has no sensor of its own, only a consumer of the two sensors (Allocator fist selection, town-activation FSM) that already exist and are already local/bounded.

#### 2.3 Interaction with the live DECAP ground gate

DECAP and AIRRESP must never write the same variable. DECAP owns `wfbe_aicom_decap` / `wfbe_aicom_alloc_target` on **ground** teams only (enforced by its own `!isKindOf "Air"` guard, §1.2) and its scope is exclusively "commit the fist onto a sensed, dominant enemy HQ." AIRRESP's scope is exclusively "cover/harass a sensed live front lane." Concretely:

- AIRRESP **never** touches `wfbe_aicom_decap`, `wfbe_aicom_targets`, or any ground team's `wfbe_aicom_alloc_target` — the Allocator's fist stays the single ground authority, unmodified, exactly as DECAP's own header promises for its relationship to the Allocator (`AI_Commander_Decapitate.sqf:5-7`: "Runs AFTER the M0 snapshot + the M1 Allocator … it NEVER writes wfbe_aicom_targets").
- AIRRESP teams are founded/tasked with **their own** team-var pair, e.g. `wfbe_aicom_airresp_lane` (a town object) + `wfbe_aicom_airresp_t0`, kept off the `wfbe_aicom_decap` sentinel/broadcast idiom DECAP already uses (`AI_Commander_Decapitate.sqf` sentinel-clear pattern, `[]`-array clear, `setVariable [..., true]` broadcast) so the two closers' telemetry (`AICOM2|v1|DECAP|…` vs a new `AICOM2|v1|AIRRESP|…` diag_log line) never collide in the same soak-log grep.
- **DECAP takes priority when both would fire on the same enemy HQ town.** If AIRRESP's sensed lane happens to be the same town DECAP has just COMMITTED against (i.e. `_committed && wfbe_aicom_decap` is live for this side this tick), AIRRESP should treat that as a signal to *support*, not compete: cap its own team count on that specific town to a small number (e.g. 1) rather than double-dispatching, and never override `flyInHeight`/engage posture that would pull ground-team eyes off the HQ press. This is a policy choice for the owner (Q7 below), not a hard architecture requirement, since the two systems write disjoint variables and cannot literally clobber each other.
- Both closers are gated by independent `>0` flags (`WFBE_C_AICOM2_DECAP_ENABLE` already live-1 today, `WFBE_C_AICOM2_AIRRESP_ENABLE` proposed default 0) so AIRRESP ships fully inert against the *current* live DECAP behaviour and can be armed/tested in isolation on a soak box before any interaction question in the paragraph above becomes observable.

#### 2.4 Flags (proposed, all `Init_CommonConstants.sqf`, all default-off except tunables that are inert while `_ENABLE=0`)

```
WFBE_C_AICOM2_AIRRESP_ENABLE       = 0     -- master switch; 0 = shadow (sensing+telemetry only, no dispatch), matches DECAP's documented (if not actual) shadow convention
WFBE_C_AICOM2_AIRRESP_SENSE_RADIUS = 2500  -- town-to-player sense radius (m); mirror DECAP's DECAP_SENSE_RADIUS=3000 default, per-map tunable
WFBE_C_AICOM2_AIRRESP_SENSE_INTERVAL = 3   -- strategy ticks between dice rolls (3 ticks * 60s = ~3min cadence, faster than the 30min Wildcard slot)
WFBE_C_AICOM2_AIRRESP_SENSE_CHANCE = 0.5   -- roll chance on a due tick
WFBE_C_AICOM2_AIRRESP_MAX_AIR      = 2     -- global alive-cap on AICOM2-maneuver air per side, separate from Wildcard's one-shots and from GUER's WFBE_C_GUER_AIRDEF_MAX
WFBE_C_AICOM2_AIRRESP_LOITER_TIME  = 240   -- seconds a response flight stays on a lane before self-despawn/recycle if the lane goes cold
```

---

### 3. Open owner questions

1. **Airframe pool** — should AIRRESP draw from the same `WFBE_<side>AIRCRAFTUNITS` pool + the W13 attack-classes allowlist (`AI_Commander_Wildcard.sqf:1000`), or does it need its own curated list (e.g. excluding heavy gunships reserved for the Wildcard "special occasion" feel)?
2. **HC delegation** — W6/W13 use `WFBE_CO_FNC_PickLeastLoadedHC` with a server-local fallback (`AI_Commander_Wildcard.sqf:872-880` pattern). Should AIRRESP teams be HC-delegated the same way, given they are meant to be more frequent/longer-lived than a Wildcard one-shot (more HC load)?
3. **Player-visibility cadence** — DECAP intentionally has no player-facing announcement (silent closer). Should AIRRESP be silent too, or does "flexible/organic air support" need a `LocalizeMessage` beat (as Wildcard cards get) so players actually notice the AI is contesting a lane by air, given that's the stated design goal?
4. **Relationship to the Wildcard air cards** — with AIRRESP live, should W6/W13/W19/W22 be retuned (lower weight, since a continuous mechanism now exists) or left as-is (occasional "big" air event layered on top of a steady baseline)? Risk of double-dipping the same `WFBE_C_AICOM2_AIRRESP_MAX_AIR`-style budget if not reconciled.
5. **GUER interaction** — AIRRESP is scoped W/E-only per the assignment. Does a W/E response flight need any awareness of `Server_GuerAirDef.sqf` defenders (e.g. avoid friendly-fire dogfighting a GUER Ka-137 that happens to be in the same airspace, since GUER can be hostile to both W and E), or is that left to native AI engagement rules?
6. **"Support lanes" beyond the Allocator's 2-town fist** — §2.2's definition ties AIRRESP strictly to `WFBE_SNAP_TGTTOWNOBJS`/active-town signals. Should it *also* cover a town under a player-led push that the Allocator hasn't yet targeted (i.e. genuinely proactive lane coverage, not just fist-following), and if so, what bounded signal justifies that without becoming the "global HQ knowledge" anti-pattern DECAP's owner Q1 explicitly rejected (`AI_Commander_Decapitate.sqf:10-12`)?
7. **DECAP/AIRRESP same-HQ overlap policy** (§2.3) — confirm the "AIRRESP supports, does not compete, caps to 1 team on a DECAP-committed HQ town" default, or specify different arbitration.
8. **Naval-HVT precedent reuse** — `AI_Commander_AssignTowns.sqf:648-733`'s `_teamAir` special-casing already exists for offshore targets. Should AIRRESP literally extend that eligibility list (offshore towns become AIRRESP-reachable lanes too), or stay landlocked/symmetric with ground lanes for the first cut?
9. **Rollback/soak plan** — given the DECAP flag-default drift found in §1.2 (comment says 0, ships 1), what's the intended promotion path for `WFBE_C_AICOM2_AIRRESP_ENABLE` (shadow-log-only soak window length, who flips it live, and should the Init_Server.sqf compile-line comment be corrected for DECAP in the same PR that adds AIRRESP, to stop the drift from repeating)?
