# July 2026 Update — Roadmap (WIP)

> Tracking PR for the July update. The June bundle (PR #8) shipped the WDDM defenses,
> supply heli, upgrade queue, EASA/economy QoL and the finalize fixes. July is for the
> **big** items that are too large to fold into June.

**Branch:** `dev/july-2026-update` (based on the June release tip)
**Status:** planning / scaffold — no gameplay code yet.

## Flagship: Takistan captured-airfield FPV drone

Full design (owner-answered questionnaire) lives in the wiki:
`Takistan-Airfield-FPV-Drone-Design`. Summary of the agreed shape:

- Both Takistan airfields start **neutral**; capture via an owner-placed point at the
  runway **edge** (never blocking the runway) + a nearby bunker/camp gate before drones unlock.
- **Server-authoritative** spawn / purchase / caps / ownership / range — do **not** graft onto
  the current client-owned UAV spawn path.
- Player-funded, one active drone per player + a side-wide cap; losing the field disables new
  buys only (active drones persist).
- Tiers: T1 recon (no warhead) · T2 light HE · T3 AT. **No** anti-air role.
- Hard center-map boundary (drone destroyed/forced down past it); cannot damage HQ/base.
- AA / static-AA / radar are the counter (not small arms).
- Captured field grants extra income (`$50`/player/cycle — target account TBD).

### Implementation shape (from the design page)
1. Airfield objective metadata for the two existing `LocationLogicAirport` logics.
2. Server-owned airfield ownership state (separate from town victory state).
3. Runway-edge capture object + one bunker/camp per field.
4. Drone Bay client menu → request only (no trusted final state).
5. Server request handler re-derives player/side/funds/upgrades/ownership/caps/tier.
6. Server-side spawn, track owner/side/field/tier, publish minimal client state.
7. Server-enforced range + base-protection.
8. AA/radar counter behaviour after the basic lifecycle works.

LOC estimate: ~1000–1800 (Takistan-only, July-quality) + `mission.sqm` object edits.

### Open owner decisions (block start — need Steff)
- `$50/player/cycle` → side funds, team funds, or per-player payout?
- Side-wide active drone cap number.
- Recon/scout class id + discount.
- Drone classnames + weapon/magazine classnames per tier.
- Boundary geometry: strict center line / per-field polygon / radius-clipped.
- AA/radar counter behaviour: reveal marker / warning / auto-damage / lock-on / signal loss.
- Exact runway-edge capture placement + bunker/camp class & position (both fields).

### Validation gate (in-engine, before release-complete)
Takistan boot (both fields neutral) · capture (point + bunker) · JIP ownership/markers/Drone-Bay ·
economy ($50 grant, stops on loss) · upgrade gating (UAV gates all; EASA gates tiers) ·
purchase (debit once, 1/player + side cap) · authority (bad side/field/funds/tier/range fail
server-side) · range kill · base-protection · AA/radar counter (no global launch warning).

## Committed: PVF / public-variable sender authentication (DR-55) — LOW perf impact

**Locked in for July.** The whole PVF / PVEH / direct-publicVariable surface currently lacks
server-side sender authentication (`Server/Functions/Server_HandlePVF.sqf:14`,
`Common/Init/Init_PublicVariables.sqf:50` never forward the sender), so ~18 handlers are
client-forgeable by any connected client — set anyone's score, lock the enemy MHQ, drain a
side's supply, unlimited instant supply, force-assign commander, etc. (full list in the wiki
`Deep-Review-Findings` DR-55).

### Low-perf-impact design (hard requirement)
The fix must add **no per-frame and no measurable hot-path cost** — PVF requests are
discrete player actions (a few per second across the whole server at most), so authentication
is O(1) per request:

1. **Embed the caller once at send time.** `WFBE_CO_FNC_SendToServer` adds `getPlayerUID player`
   (and/or `owner player`) to the payload — a single cheap read, only when the player triggers
   the action.
2. **Authenticate once at dispatch.** `Server_HandlePVF` / the PVEH reads the sender from the
   event (`_this select 0/2`) and/or the embedded UID, resolves the player object **once**, and
   passes an authenticated `_sender` to the handler. One hashmap-free lookup per request.
3. **Re-derive, don't trust.** Each handler derives side / commander / funds **server-side from
   `_sender`**, ignoring payload-supplied side/score/amount fields. No new loops, timers, or
   broadcasts — pure validation, so the steady-state perf cost is zero.
4. **Stage it.** Land the CRITICAL economy/authority channels first (RequestChangeScore,
   RequestVehicleLock, SupplyMissionCompleted, ATTACK_WAVE_DETAILS, RequestMHQRepair,
   RequestNewCommander), then the rest. Read/cosmetic server-originated channels are already
   clean and need no change.

Validation gate: each hardened channel — legitimate use still works; a forged request from the
wrong side/role is rejected server-side; no RPT spam; **server FPS unchanged** before/after
(the explicit perf check).

## Already handled in June (not July)
- Hosted/listen server-FPS busy-loop fix (DR-19) — shipped in PR #8.
- Propagation-queue items (paratrooper markers, skill-init idempotency, supply-scan narrowing,
  commander-artillery ownership) — present in the June release, pending in-engine smoke.

## MASH revamp (July)

The June bundle **removed** the old MASH respawn/officer-skill system (officer "Deploy MASH"
ability, MASH mobile-respawn, lobby parameter, dead marker modules, unused composition
template). July re-introduces MASH as a **better** system rather than the old half-baked one.

Goals / open design (needs owner input):
- **What MASH should be:** a commander- or officer-deployed forward aid/respawn point, or a
  buildable medical structure — pick one coherent model (the old one mixed an officer-tent
  respawn with a never-rendered map marker).
- **Server-authoritative:** deploy/limit/respawn validated server-side (the old path was
  client-driven and the marker PV chain was broken — no publisher).
- **One per side / cooldown / lifetime** caps; clear HUD + map marker that actually renders.
- **Respawn rules:** default-gear vs custom-gear, range, and interaction with the existing
  mobile/leader/camp respawn options.
- Decide whether to reuse the leftover dead `'MASH'`/`WFBE_<side>DEFENSES_MASH` registry
  entries (still in `Core_CIV`/`Structures_*.sqf`) or scrub and rebuild clean.

Validation gate: deploy/undeploy, one-per-side cap, JIP marker visibility, respawn at MASH,
default-gear enforcement, and no RPT spam (the old marker EH chain).

## Town/static defender classification (July)

Claude's PR8-side exploration found a useful AI correctness lane that is too risky to slip into
the June release after final testing: town-spawned defender AI and static-defense crews should be
explicitly classified so nearby town activation scans do not treat them like roaming enemy
attackers.

Problem shape:
- Static defenders and resistance town defenders can bleed into nearby detection radii.
- Without a clear marker, town activation can count those defenders as live attackers and wake or
  sustain the wrong town lifecycle.
- Delegated town AI can also start unnecessary client marker/action setup, adding noise during
  heavy AI runs.

Planned shape:
1. Tag defender town groups, units, crews, vehicles, and static gunners with a locality-safe
   `WFBE_IsTownDefenderAI` variable.
2. Teach `server_town_ai.sqf` activation scans to ignore those tagged defenders while still
   detecting real players, player-led AI, and attacking combat groups.
3. Keep town AI creation on the safer post-June code path: preserve null-group / failed-unit /
   empty-vehicle guards from PR8 final hardening.
4. Let delegated town AI opt out of extra global client marker/action init where that is not
   needed.
5. Add performance/audit logging around town activation, despawn, and delegated town AI creation
   so the harness can prove the change did not create new server-FPS or HC locality problems.

Validation gate: two nearby hostile/neutral towns, defender static crews active, HC delegation on,
player enters/leaves detection radius, town wakes only for real enemies, tagged defenders do not
wake adjacent towns, town despawns cleanly, no stuck empty groups, no marker/action spam, and
server FPS remains unchanged under the stress harness.

## Smaller July candidates (could fold into a future release)
- Recon UAV / drone-saturation-strike (separate feature branches `feat/recon-uav`, `feat/drone-saturation-strike`).
- Player stats Phase 1 (`feat/player-stats`) — a guarded stats hook already exists in `RequestOnUnitKilled.sqf`.
- Hardening backlog items (PVF dispatch allowlist, ICBM/economy authority) — owner-gated.

---
*Source: wiki `Takistan-Airfield-FPV-Drone-Design`, `Source-Fix-Propagation-Queue`, `agent-hardening-backlog.jsonl`.*
