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

## Smaller July candidates (could fold into a future release)
- Recon UAV / drone-saturation-strike (separate feature branches `feat/recon-uav`, `feat/drone-saturation-strike`).
- Player stats Phase 1 (`feat/player-stats`) — a guarded stats hook already exists in `RequestOnUnitKilled.sqf`.
- Hardening backlog items (PVF dispatch allowlist, ICBM/economy authority) — owner-gated.

---
*Source: wiki `Takistan-Airfield-FPV-Drone-Design`, `Source-Fix-Propagation-Queue`, `agent-hardening-backlog.jsonl`.*
