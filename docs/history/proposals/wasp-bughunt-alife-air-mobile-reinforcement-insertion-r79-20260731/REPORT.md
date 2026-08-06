# WASP idle bughunt r79 — A-Life / air-mobile reinforcement insertion & transport return lifecycle

**Task:** `wasp-bughunt-alife-air-mobile-reinforcement-insertion-r79-20260731`  
**Agent:** `grok-main-07311829-night` (grok)  
**Date:** 2026-07-31  
**Scope:** VIDEO GAME (Arma 2 OA) mission scripting — fictional AI / A-Life / AICOM transport insertion.  
**Method:** Mandatory trap memories → open-PR anti-retread → source trace on `origin/master` (not dirty local branch) → adversarial residual check.  
**SQF edits:** none (grok probation forbids mission/SQF mutation; this card is research + close).  
**Draft PR:** none (0 NEW shippable bugs after anti-retread).

## Verdict

**CLEAN PASS — 0 NEW adversarially verified, shippable bugs.**

The lead-area failure modes named on the card are either:

1. Already fixed on `origin/master` (merged r60 unload integrity), or  
2. Already covered by an open draft PR (do not retread), or  
3. Working-as-designed under current flags/defaults, or  
4. Residual notes too weak / already-adjacent to ship without re-opening r60 surface.

Confidence: **high** on anti-retread and success-path unload lifecycle; **medium** on field frequency of residual abort-path notes (static source only; no live RPT window for this card).

## Mandatory first reads

- `a2-sqf-live-burned-traps.md` — unary-`Call` `_this` inheritance, flag-gated parse kills, BOOLCMP-in-lazy-`{}`, etc.  
- `a2-sqf-review-false-positives.md` — `orderGetIn false` / `moveOut` / group getVariable doctrine; do not invent A3 semantics.

## Anti-retread (open + merged neighbours)

| Ref | Status | Surface | Action |
|-----|--------|---------|--------|
| **#1736** `fix(aicom): transport unload integrity — sticky get-in + force moveOut (r60)` | **MERGED** 2026-07-31 | Cold/hot unload + board-timeout cancel in founding insert + `AICOMAirLeg`; capture dismount `moveOut` | **DO NOT RETREAD** — card explicitly lists `aicom-transport-unload-and-reembark` |
| **#1588** airlift LIFT at in-loop delivery (`WFBE_C_AICOM_AIRLIFT_V2` default 0) | OPEN draft | Requisition grant parks at factory; founding insert already ran | **DO NOT RETREAD** |
| **#1785** cancel undelivered airlift on order retarget/abort | OPEN draft | Clears/refunds `wfbe_aicom_airlift_grant` | **DO NOT RETREAD** |
| **#1757** paradrop tasking CD + objective rebind | OPEN draft | AICOM paradrop tasking (adjacent, not this lifecycle) | Avoid |
| **#1750** corpse/wreck reap + airlift requeue | OPEN draft | Trash/empty-vehicle airlift flags | Avoid |
| Neighbours named on card | prior cards | reinforcement call-for-help, convoy transit, vehicle crew, naval boat, paradrop tasking, troop-ferry, unload/reembark | Avoid |

Open PR count checked via `gh pr list --state open --limit 300` (through #1795).

## Lead-area source map (`origin/master`)

| Lifecycle stage | Primary file(s) | Notes |
|-----------------|-----------------|-------|
| Founding air-insert (once, pre-order-loop) | `Common_RunCommanderTeam.sqf` ~L632–920 | Own-heli board → hot/cold LZ → unload → `AIR_RETAIN` return **or** legacy edge fly-off+refund |
| Ordered air-mobile legs | `Common_AICOMAirLeg.sqf` | Same hot/cold decision; VEHLIFT deep-drop optional; always `AICOMAirReturn` |
| Shared return-to-base hold | `Common_AICOMAirReturn.sqf` | HQ else owned-town fallback; land `"LAND"`; clears `wfbe_aicom_airborne_until` |
| Order gate | `Common_RunCommanderTeam.sqf` ~L1555–1624 | `WFBE_C_AICOM_AIRMOBILE` + min dist; requisition stamp if no heli |
| Grant consumer | `Common_RunCommanderTeam.sqf` ~L3316–3356 | Delivers factory transport; telemetry `liftedHere=0-by-design-see-airlift-parking-lot` |
| Stuck exemption | `AI_Commander_AssignTowns.sqf` ~L490–516 | `wfbe_aicom_airborne_until` **or** leader in Air |
| Uncrewed hull reap | `Common_RunCommanderTeam.sqf` ~L1084–1096 | `WFBE_C_AICOM_AIR_REAP_UNCREWED` default 1, grace 45s |
| GUER GDIR “QRF insert” | `Server_GuerDirector.sqf` ~L496–690 | Spawns Ka-137 / gunship + pilot; **no cargo infantry** (air presence, not troop ferry) |
| W19 Heliborne QRF | `AI_Commander_Wildcard.sqf` | Founds air-assault template; insert is `RunCommanderTeam` path above |

Defaults (source): `WFBE_C_AICOM_AIRMOBILE=1`, `AIR_RETAIN=1`, `AIR_PARADROP=1`, `VEHLIFT=1`, `AIRLIFT_REQ=0` (explicitly off after live parking-lot evidence).

## Card hypotheses vs current master

| # | Hypothesis | Result | Why |
|---|------------|--------|-----|
| 1 | Transport half of lifecycle never closed | **Mitigated** | Success path always ends in `AICOMAirReturn` (retain) or edge refund (legacy). Idle RTB path exists flag-gated (`AIR_IDLE_RTB` default 0). |
| 2 | Unload waits on state landing never sets | **Fixed r60 / timed** | Cold: `land "GET OUT"` + 40s alt timeout, then **force `moveOut`**. Hot: EJECT + sticky cancel. |
| 3 | Disembarked infantry re-board / follow transport home | **Fixed r60** | Full-pax `unassign` + `orderGetIn false` + residual `moveOut` + `doMove` objective before RTB. |
| 4 | Transport deleted while cargo still aboard | **Mostly mitigated** | Empty-vehicle timer resets with alive crew; `AIR_REAP_UNCREWED` only when **no** alive crew. Success unload empties cargo first. |
| 5 | Empty transport never returns (FPS park) | **Mitigated by design** | `AICOMAirReturn` + optional idle RTB; attack-heli base reap excludes `transportSoldier>0`. |
| 6 | Shot-down transport never re-issues/refunds wave | **WAD / partial** | Retain mode intentionally forgoes refund. Survivors get ground `doMove`. Full wave re-issue is not in this architecture (team already founded). Requisition cancel = **#1785**. |
| 7 | LZ without slope check → infinite hover | **Bounded** | Decision-time `isFlatEmpty`; land hold max 40s then force unload; not infinite. |
| 8 | Two waves race same LZ | **Not a verified defect** | No shared LZ mutex; teams use own transport + own dest. No source crash/hang proven. |
| 9 | Population budget double-count cargo+ground | **Not verified** | No second count site found in this pass that double-registers the same insert group for air cargo vs ground. |

## What r60 (#1736) closed (do not re-ship)

On `origin/master` after merge commit family of #1736:

- Board-timeout: cancel sticky get-in for non-boarders before takeoff.  
- Cold LZ: all-pax sticky clear + `moveOut` residual cargo (SML-2: `orderGetIn false` is a silent no-op on seated units).  
- Hot LZ: `orderGetIn false` before `EJECT`.  
- Capture dismount: `moveOut` for cargo/crew.

Local dirty branch `fix/alife-camp-capture-sv-heal-r69-*` was **behind** master on these files; analysis used `git show origin/master:…`.

## Residual notes (NOT claimed as shippable bugs this round)

These are **explicitly not** elevated to draft-PR bugs under this card’s stop condition (anti-retread + adversarial bar + grok no-SQF). Future SQF-capable lane may re-open:

### R1 — Abort-path unload still soft-only (founding + AirLeg)

**Where:** mid-lift / mid-runin `exitWith` survivors cleanup in `Common_AICOMAirLeg.sqf` and founding insert Spawn in `Common_RunCommanderTeam.sqf` (still `unassign` + `orderGetIn false` only; no `moveOut`).  
**Why it might matter:** r60’s own doctrine (SML-2) says soft unassign is a no-op on seated units. If the hull stays **alive** with a **dead/null driver**, survivors can remain cargo; `AIR_REAP_UNCREWED` will not fire while any alive crew/pax remain.  
**Why not shipped here:** Adjacent to merged r60 surface; no live RPT confirmation this match; risk of churn on just-merged unload code without engine proof. Prefer a focused residual card with soak evidence (pilot KIA mid-insert, survivors still `vehicle != unit`).

### R2 — Empty-transport RTB keeps team `airborne_until` warm

**Where:** `Common_AICOMAirReturn.sqf` refreshes `wfbe_aicom_airborne_until` every 3s while the **empty** hull flies home (up to ~300s + home resolve).  
**Effect:** `AI_Commander_AssignTowns` treats the whole team as airborne, so ground stuck recovery is suppressed for the return window even when the infantry leader is already on foot.  
**Why not shipped:** Explicit design comment (prevent teleport of flying leader). Narrower fix would be “refresh only while leader is in Air” — policy/design, not a clear crash/lifecycle break.

### R3 — Requisition parking lot

Documented in-source (`AIRLIFT_REQ` default 0 + `liftedHere=0-by-design` telemetry). Fix path is open **#1588**. Do not duplicate.

## What was NOT verified

- Live `MISSINIT` RPT window for `AIRMOBILE_LEG` / `AIR_RETAIN` / `AIR_REAP` / stuck exemptions.  
- Engine confirmation of mid-air `moveOut` vs wreck locality on OA 1.64.  
- GDIR Ka-137 “qrfInsert” troop capacity (treated as air **presence**, not troop ferry).  
- Population ledger double-count under HC despawn budget (1631 adjacent).

## Deliverables

| Path | Purpose |
|------|---------|
| `docs/Proposals/wasp-bughunt-alife-air-mobile-reinforcement-insertion-r79-20260731/REPORT.md` | This report |

## Close recommendation

- **No draft PR** (clean result).  
- **MILESTONE:** owner-facing report artifact via Fleet-Drop.  
- Next idle card may pick residual R1 with soak evidence, or leave to SQF lane after #1736 has soak time.

GUIDE-REV reference for any future PR from residuals: `GR-2026-07-08a`.
