## AICOM Air-vs-Ground Response — historical design and current implementation

**Current-source refresh: 2026-07-12 · `origin/master@bbab122f0eb40b1351d075d05a12da6960499a12`**

Status: **IMPLEMENTED AND OWNER-ARMED**. The research and proposed mechanism
below are retained as design provenance; current-source facts in this status
block supersede the pre-implementation wording that follows.

Current source compiles AIRRESP at `Init_Server.sqf:85` and calls it after DECAP
at `AI_Commander.sqf:628-629`. `Init_CommonConstants.sqf:825-830` ships
`WFBE_C_AICOM2_AIRRESP_ENABLE = 1` per the 2026-07-08 owner directive, with
radius `2500` on Chernarus/Takistan and `1800` on Zargabad, sense interval `3`,
chance `0.5`, maximum air `2`, and loiter ceiling `240` seconds. Setting the
enable flag to `0` preserves shadow sensing/state/telemetry but prevents new
dispatch; already-spawned flights may remain until their lane goes cold or the
loiter ceiling expires, so a fresh-mission `0` is the clean rollback proof.

Owner intent (from assignment): ground teams stay town-first/road-following (the Allocator's concentrated fist, PR #715 lineage); helicopters and jets should respond **faster and more flexibly** to player pushes and threaten/support lanes **organically** — but must remain **NOT omniscient**. This doc records the pre-implementation inventory, the two known gates, and the bounded main-side (W/E) design later implemented beside the live DECAPITATE closer.

Unless a paragraph is explicitly labeled current, evidence below is historical and cited `file:line` against `origin/claude/build84-cmdcon36`, Chernarus tree (`Missions/[55-2hc]warfarev2_073v48co.chernarus/…`). Current AIRRESP constants and call-chain facts are in the status block above.

---

### 1. Historical inventory: what air response existed before AIRRESP

#### 1.1 Ground AICOM (W/E) — the town-first fist, for contrast

At the historical design snapshot, `AI_Commander.sqf:517-524` ran **Snapshot → Strategy → Allocate → Decapitate**. Current master runs **Snapshot → Strategy → Allocate → Decapitate → AirResp** at `AI_Commander.sqf:620-629`. The Allocator remains the single source of ground truth for where teams walk/drive; AIRRESP does not replace that town-first fist.

#### 1.2 `AI_Commander_Decapitate.sqf` — confirmed GROUND-ONLY

The M5 "kill-move" closer stamps `wfbe_aicom_decap` on teams already pressing near a sensed, dominant enemy HQ. Both eligibility passes — the **sensing** loop and the **commit/stamp** loop — carry an explicit hull-type exclusion:

```
if (_t != _garTeam && {!_isHolding} && {!isPlayer (leader _t)}
    && {({alive _x && {(vehicle _x) isKindOf "Air"}} count (units _t)) == 0}) then {
```
— `AI_Commander_Decapitate.sqf:98` (sensing eligibility) and `AI_Commander_Decapitate.sqf:178` (stamp eligibility), both tagged `//--- stack-pass: GROUND contract - a team with any live unit currently in an Air hull neither senses nor is stamped`.

So a team with even one live member currently in an `Air` hull is invisible to DECAP on both ends: it neither contributes to the proximity/dominance ARM streak nor can be stamped to press the HQ. DECAP's whole organic-sensing model is a **ground-only closer**. At the historical snapshot nothing symmetrical existed for air; AIRRESP now supplies the separate air path.

Current flag note: `Init_CommonConstants.sqf:796` ships `WFBE_C_AICOM2_DECAP_ENABLE = 1`, alongside Allocator default `1` at line 774. The default-0 wording at `Init_Server.sqf:84` and `Init_CommonConstants.sqf:794-795` is source-comment drift; executable DECAP behavior is armed by default.

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

**Historical assessment against the owner's ask:** W13's targeting was locally reactive, but gated behind a **30-minute per-side lottery slot shared with unrelated cards**, not a continuous bounded-interval sense loop. That gap motivated AIRRESP and is no longer a statement about current master.

#### 1.5 Adjacent prior art worth reusing

- **Snapshot already tracks players.** `WFBE_SNAP_PLAYERS=21; WFBE_SNAP_MYPLAYERS=22;` (`Init_CommonConstants.sqf:724`), refreshed every strategy tick by `AI_Commander_Snapshot.sqf` before `Allocate`/`Decapitate` run (`AI_Commander.sqf:517-522`). `WFBE_SNAP_TGTTOWNOBJS=25` (the Allocator's live front-town object list) is exactly what DECAP already walks to find the town nearest the enemy HQ (`AI_Commander_Decapitate.sqf` "`_tgtTowns = _snap select WFBE_SNAP_TGTTOWNOBJS`"). Any new mechanism gets a free, already-ticking "where is the fight / are there players there" signal without a new scan.
- **Air-transport teams are already special-cased for reach**, precedent for treating air differently within the existing town-first framework rather than bolting on a parallel system: `AI_Commander_AssignTowns.sqf:648` computes `_teamAir` (does this team carry a transport heli); `:699` and `:733` gate naval-HVT targeting to `_teamAir` teams only ("B756... naval-HVT targets are air-team-only (offshore decks) - a ground team skips them"). This is the one place in the codebase where AICOM already reasons "this team type can reach somewhere a ground team can't, so give it a different target set" — the shape any air-response spec should extend, not replace.
- **`wfbe_active_air` — a town-level "air-only contact" flag already exists**, but scoped to GUER Director (lane 800), not usable off-the-shelf for W/E maneuver: `server_town_ai.sqf:207-233` computes an altitude-banded dice roll (`AICOMV2_GDIR_AIR_CEILING_MIN_M`/`MAX_M`) that flips a town to "air-only activation" (spawns an AA-tier garrison instead of a full ground garrison) purely from **local** `nearEntities`-style detected-air-contact data, gated by `if ((missionNamespace getVariable ["AICOMV2_LANE_GUER_DIRECTOR", 0]) > 0 …)` (`:208`). It is a *defensive garrison* trigger, not an offensive maneuver trigger, and it is currently only reachable when the GUER Director lane is armed — but the altitude-banded-roll pattern ("close/low = certain, far/high = probabilistic, nothing beyond a ceiling") is a second organic-sensing template alongside DECAP's proximity+dice+latch, and is explicitly *not omniscient* by construction (it only sees what's near the town).

**Historical bottom line:** W/E had zero continuous, bounded-interval, player-push-reactive air maneuver mechanism. Current master closes that gap with `AI_Commander_AirResp.sqf`.

---

### 2. Historical proposed mechanism: bounded W/E air-response (`AICOM2 AIRRESP`)

Implemented name: **`AI_Commander_AirResp.sqf`** (M6, sibling to `AI_Commander_Decapitate.sqf` in the v2 chain), flag `WFBE_C_AICOM2_AIRRESP_ENABLE`. It now defaults to `1` per owner directive 2026-07-08. Setting it to `0` preserves shadow sensing/state/telemetry but prevents new dispatch.

#### 2.1 Trigger

Runs from the same v2 maneuver chain, immediately after DECAP (`AI_Commander.sqf:628-629`), and reads the already-fresh snapshot and Allocator targets. Its sense interval is independently tunable without a second `while{}` worker.

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
- Both closers are gated by independent `>0` flags and currently default to `1`. Either may be set to `0` for its scoped rollback behavior; AIRRESP at `0` retains shadow sensing/state/telemetry while blocking new dispatch.

#### 2.4 Current controls (`Init_CommonConstants.sqf:825-830`)

```
WFBE_C_AICOM2_AIRRESP_ENABLE       = 1     -- owner-armed default; 0 = shadow sensing/state/telemetry with no new dispatch
WFBE_C_AICOM2_AIRRESP_SENSE_RADIUS = 2500  -- town-to-player sense radius (m); mirror DECAP's DECAP_SENSE_RADIUS=3000 default, per-map tunable
WFBE_C_AICOM2_AIRRESP_SENSE_INTERVAL = 3   -- strategy ticks between dice rolls (3 ticks * 60s = ~3min cadence, faster than the 30min Wildcard slot)
WFBE_C_AICOM2_AIRRESP_SENSE_CHANCE = 0.5   -- roll chance on a due tick
WFBE_C_AICOM2_AIRRESP_MAX_AIR      = 2     -- global alive-cap on AICOM2-maneuver air per side, separate from Wildcard's one-shots and from GUER's WFBE_C_GUER_AIRDEF_MAX
WFBE_C_AICOM2_AIRRESP_LOITER_TIME  = 240   -- seconds a response flight stays on a lane before self-despawn/recycle if the lane goes cold
```

---

### 3. Historical owner questions

1. **Airframe pool** — should AIRRESP draw from the same `WFBE_<side>AIRCRAFTUNITS` pool + the W13 attack-classes allowlist (`AI_Commander_Wildcard.sqf:1000`), or does it need its own curated list (e.g. excluding heavy gunships reserved for the Wildcard "special occasion" feel)?
2. **HC delegation** — W6/W13 use `WFBE_CO_FNC_PickLeastLoadedHC` with a server-local fallback (`AI_Commander_Wildcard.sqf:872-880` pattern). Should AIRRESP teams be HC-delegated the same way, given they are meant to be more frequent/longer-lived than a Wildcard one-shot (more HC load)?
3. **Player-visibility cadence** — DECAP intentionally has no player-facing announcement (silent closer). Should AIRRESP be silent too, or does "flexible/organic air support" need a `LocalizeMessage` beat (as Wildcard cards get) so players actually notice the AI is contesting a lane by air, given that's the stated design goal?
4. **Relationship to the Wildcard air cards** — with AIRRESP live, should W6/W13/W19/W22 be retuned (lower weight, since a continuous mechanism now exists) or left as-is (occasional "big" air event layered on top of a steady baseline)? Risk of double-dipping the same `WFBE_C_AICOM2_AIRRESP_MAX_AIR`-style budget if not reconciled.
5. **GUER interaction** — AIRRESP is scoped W/E-only per the assignment. Does a W/E response flight need any awareness of `Server_GuerAirDef.sqf` defenders (e.g. avoid friendly-fire dogfighting a GUER Ka-137 that happens to be in the same airspace, since GUER can be hostile to both W and E), or is that left to native AI engagement rules?
6. **"Support lanes" beyond the Allocator's 2-town fist** — §2.2's definition ties AIRRESP strictly to `WFBE_SNAP_TGTTOWNOBJS`/active-town signals. Should it *also* cover a town under a player-led push that the Allocator hasn't yet targeted (i.e. genuinely proactive lane coverage, not just fist-following), and if so, what bounded signal justifies that without becoming the "global HQ knowledge" anti-pattern DECAP's owner Q1 explicitly rejected (`AI_Commander_Decapitate.sqf:10-12`)?
7. **DECAP/AIRRESP same-HQ overlap policy** (§2.3) — confirm the "AIRRESP supports, does not compete, caps to 1 team on a DECAP-committed HQ town" default, or specify different arbitration.
8. **Naval-HVT precedent reuse** — `AI_Commander_AssignTowns.sqf:648-733`'s `_teamAir` special-casing already exists for offshore targets. Should AIRRESP literally extend that eligibility list (offshore towns become AIRRESP-reachable lanes too), or stay landlocked/symmetric with ground lanes for the first cut?
9. **Rollback/soak plan — resolved for promotion:** the owner armed `WFBE_C_AICOM2_AIRRESP_ENABLE = 1` on 2026-07-08. Rollback remains `0`; validate it from a fresh mission because already-spawned flights can persist until lane-cold or the 240-second loiter ceiling. DECAP's executable default is also `1`; its remaining default-0 source comments are comment drift, not runtime truth.
