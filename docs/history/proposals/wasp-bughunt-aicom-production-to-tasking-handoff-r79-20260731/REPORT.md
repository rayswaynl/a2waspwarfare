# WASP idle bughunt r79 — AICOM production-to-tasking handoff

**Task id:** `wasp-bughunt-aicom-production-to-tasking-handoff-r79-20260731`  
**Agent:** `grok-main-07311829-night` (provider: grok)  
**Date (UTC):** 2026-07-31  
**Repo HEAD inspected:** `7e9fe1ba12d2abb4a12e47814ef66eea23b5ae18` (local checkout; analysis is source-static)  
**GUIDE-REV:** GR-2026-07-08a  

## Classification

| Field | Value |
|---|---|
| Scope | Read-only adversarial bughunt of **production → tasking handoff** (factory/barracks finish → unit joins requesting AICOM order / team ledger / usable group asset) |
| SQF edits | **NONE** — grok probation forbids SQF/mission edits (owner utilization 2026-07-13). Fixes are specified for a codex/kimi/claude SQF-eligible lane |
| Draft PR | **NOT OPENED** (would require SQF). This report is the deliverable |
| Runtime / RPT | **NOT verified on box** — static path analysis only. Confidence below is static unless noted |
| Verified bugs | **4** (adversarially checked; none retread open drafts below) |

## Mandatory first reads

- `a2-sqf-live-burned-traps.md` — applied (no A3-command false positives; GroupGetBool is type-generic default helper)
- `a2-sqf-review-false-positives.md` — applied (did not flag `_`-locals, case, or PV trust model)

## Anti-retread (open PRs checked)

`gh pr list --state open --limit 300` filtered for produce/buy/queue/topup/airlift/adopt/orphan/refund.

**Already covered — do not re-file:**

| PR | Topic | Why not retread |
|---|---|---|
| #1607 | nil-safe `wfbe_queue` release so abort refunds run | Same file (`Server_BuyUnit.sqf`); queue-release throw before refund |
| #1617 | type-safe factory queue tokens (AI SCALAR vs player STRING) | Factory FIFO token type |
| #1641 | BuyUnit PV authority / class/side/team envelope | Purchase PV surface, not handoff |
| #1785 | cancel undelivered **airlift grant** on order retarget/abort | Order-cancel path only (see BUG-3 residual) |
| #1694 (merged) | skip Produce topup charge while `topup_req` pending | Topup double-charge |
| #1251 / #1258 (merged) | treasury refund on abort + topup locality | Pre-charge refund class |
| #1618 | man QUERYUNITTURRETS in **Common_CreateTeam** | Founding path, not BuyUnit refill |
| #1726 | Produce retreat-cull null hygiene | Fail-clean cull, not delivery handoff |
| Neighbours in card | production-queue validation/stall, attrition topup, asset registry, idle reclaim, order-dispatch, composition selection | Different lead areas |

## Lead path map (what was read)

```
AI_Commander_Produce.sqf
  ├─ HC maintain: recycle / airlift grant / town topup_req (charge-first)
  └─ server-local refill: funds charge → wfbe_queue push → Spawn AIBuyUnit
        └─ Server_BuyUnit.sqf  (= AIBuyUnit compile)
              factory FIFO wait → CreateUnit/CreateVehicle + crew →
              optional factory rally commandMove → wfbe_queue release

HC / topup parallel:
  AI_Commander_HCTopUp.sqf → wfbe_aicom_topup_req
  Common_RunCommanderTeam.sqf → TOPUP consumer (TTL refund) + AIRLIFT grant consumer
  server_aicom_orphan_heal.sqf → stale topup only (not airlift grant)
  server_groupsGC.sqf → base re-adopt into wfbe_teams (ledger)
```

---

## Verified bugs

### BUG-1 — AI vehicle delivery skips `addVehicle` when leader is ≥200 m from spawn pad (HIGH)

**Sites**

- `Server/Functions/Server_BuyUnit.sqf` ~352  
  ```sqf
  if (_vehicle distance (leader _team) < 200) then {
    (units _team) allowGetIn true;
    _team addVehicle _vehicle
  };
  ```
- Contrast: `Client/Functions/Client_BuildUnit.sqf` ~1212 always does `_group addVehicle _vehicle` (no distance gate).

**Why it is real (adversarial)**

1. Produce **allows** refill when the team is within `WFBE_C_AI_COMMANDER_REINFORCE_RANGE` (default **1200 m**) of HQ, or within forward-town range (`WFBE_C_AICOM_FWD_REINFORCE_RANGE`, default **500 m**) of an owned town factory (`AI_Commander_Produce.sqf` ~455–464, 561–568).
2. Factory is chosen nearest the leader, but “nearest” can still be **200–1200 m** (HQ reform / mid-move during long factory queue wait).
3. During `sleep _waitTime` + factory FIFO wait, the leader can move farther; the distance check is evaluated **only at delivery time**.
4. Crew is still created **into** `_team` (CreateUnit), so the hull is crewed and counts against side AI, but:
   - group vehicle list does not include the hull → AI cargo/logistics/`assignedVehicle` graph misses it  
   - `(units _team) allowGetIn true` is also skipped in the same branch  
   - other squad members never board the paid reinforcement  
   - matches the card’s “delivery while mid-move so reinforcement never merges / under-strength halves” shape for **vehicles**

**Not refuted by**

- Factory rally `commandMove` (driver-only, and only if `wfbe_aicom_factory_rally` is set) — does not replace `addVehicle`.
- HandleEmptyVehicle still tracks the hull; that only reaps when crew is empty, it does not adopt the hull into group logistics.

**Suggested fix (for SQF-eligible lane)**

- Always `_team addVehicle _vehicle` + `allowGetIn true` for AI path (mirror player), **or**
- Raise/remove the 200 m gate to at least reinforce range, and re-try addVehicle if leader later enters range (optional).
- Flag not required if treated as correctness (always-on). Prefer small gate `WFBE_C_AICOM_BUY_ADDVEHICLE_ALWAYS` default 1 only if owner wants roll-out control.

**Confidence:** HIGH (static). **Not live RPT-proven.**

---

### BUG-2 — Produce hardcodes full crew flags; ignores `QUERYUNITCREW` (HIGH)

**Sites**

- `AI_Commander_Produce.sqf` ~594  
  ```sqf
  _isVeh = if (_toBuild isKindOf "Man") then {[]} else {[true,true,true,true]};
  ```
- Consumer: `Server_BuyUnit.sqf` uses `_isVehicle select 1` (gunner), `select 2` (commander), `select 3` (extra turrets). Driver is always created.
- Player UI truth source: `GUI_Menu_BuyUnits.sqf` ~636–659 reads `QUERYUNITCREW` → `[hasCommander, hasGunner, …, turretCount]` and **disables** seats the vehicle does not have.
- Cap reservation at Produce ~543–545 always uses  
  `_capCost = 3 + count (_ud select QUERYUNITTURRETS)` for any non-Man — independent of real seats.

**Why it is real**

1. For light cars / trucks with driver-only (or driver+cargo, no gunner/commander), BuyUnit still CreateUnit’s gunner and commander, then `moveInGunner` / `moveInCommander`. On A2 OA those moveIn calls no-op when the seat is absent → **foot “crew” left on the pad** still members of `_team`.
2. Side-cap booking over-reserves by 2 bodies for every light-vehicle order in the Produce cycle (`_capRemaining -= 3+turrets` while often only 1 seat fills).
3. Paid hull may sit effectively under-used while extra infantry inflate the team count and block further real deficit fill (`_cur` optimistic + live count both climb on junk crew).
4. Distinct from open #1618 (CreateTeam founding turrets) — this is the **refill BuyUnit** path.

**Suggested fix**

- Resolve `_isVeh` from `_ud select QUERYUNITCREW` (map to BuyUnit’s [driver?, gunner, commander, turretsBool] contract carefully — note UI order is commander-first, BuyUnit is gunner-at-1 / commander-at-2).
- Set `_capCost` from actual seats to spawn (1 + optional gunner + optional commander + turret count), not hard `3+`.
- Guard moveIn* with empty-seat checks (or rely on corrected flags).

**Confidence:** HIGH static. Live impact largest on light-motorized templates / fill-to-floor vehicle pads.

---

### BUG-3 — Prepaid `wfbe_aicom_airlift_grant` has no TTL / wipe refund (MED–HIGH residual)

**Sites**

- Charge + stamp: `AI_Commander_Produce.sqf` ~171–175  
  `ChangeAICommanderFunds` debit, then  
  `wfbe_aicom_airlift_grant = [class, factoryPos, price, time]`.
- Consumer: `Common_RunCommanderTeam.sqf` ~3122–3154 — refunds only if CreateTeam returns zero vehicles; always clears grant after attempt.
- Topup contrast: same file ~3036–3065 + `WFBE_C_AICOM_TOPUP_REQ_TTL` (300 s) + `server_aicom_orphan_heal.sqf` stale topup refund.
- Open **#1785** refunds grant on **order retarget/abort only** — not team wipe, not dead driver, not never-consumed idle grant.

**Why residual is real**

1. Grant carries `time` (element 3) but **no consumer ages it out**.
2. Consumer is gated on `_alive` — wiped / empty team never refunds; group GC then drops the var with funds already spent.
3. Produce treats any non-empty grant array as `_alGrantPending` and will not re-grant → permanent stuck prepaid if consumer never runs and order-cancel path never fires.
4. Orphan-heal comments explicitly list **topup** refund only.

**Suggested fix**

- Mirror topup: TTL (reuse or add `WFBE_C_AICOM_AIRLIFT_GRANT_TTL`), refund charge element, clear grant; extend orphan-heal the same way.
- On team wipe / disband / recycle paths: clear + refund if charge > 0.
- Coordinate with #1785 (stack or fold) so cancel + TTL + wipe are one contract.

**Confidence:** HIGH for missing path; severity depends on how often airlift requisitions fire without delivery. **Not** claiming #1785 is wrong — this is the residual surface.

---

### BUG-4 — Fresh factory infantry/vehicles get no rejoin order when factory rally is unset (MED)

**Sites**

- Man: `Server_BuyUnit.sqf` ~248–256 — `commandMove _aiRally` only if `wfbe_aicom_factory_rally` is a ≥2-element array on the factory.
- Vehicle: ~452–458 — same gate for `driver commandMove`.
- Rally is stamped by AI base builder (`AI_Commander_Base`); **starting / player-built / unstamped factories never get it** (merged #1346 fixed AI-build clobber cases, not missing stamp on non-AI factories).

**Why it is real**

1. Unit is CreateUnit’d into the requesting team (ledger membership OK) but receives **no movement order** when rally is nil.
2. Card shape: “unit never reaches the order that paid for it / idles at spawn pad forever”.
3. Server-local teams rely on later AssignTowns/Execute AIMoveTo of the **leader**; newly added units do not reliably inherit mid-order waypoints on A2 OA until the order is re-issued — so pad-idle can persist for a full order cycle or longer.
4. Stacks with BUG-1: distant vehicle delivery without addVehicle + without rally = dual orphan (no group vehicle, no egress).

**Suggested fix**

- Fallback destination chain: factory rally → team leader position → HQ position → skip only if all null.
- Optional: after spawn, if leader > N m, `commandMove (getPosATL leader)` or assign to existing group vehicle.
- Ensure `wfbe_queue` release still runs (already does at tail).

**Confidence:** MED–HIGH static. Mitigated somewhat when AI stamps rally on every factory it builds.

---

## Clean / not-bugs after adversarial pass

| Hypothesis from card | Result |
|---|---|
| Two pending requests claim same finished unit | Factory FIFO is per-token spawn; each AIBuyUnit creates its own unit. No shared “finished unit” object. |
| Delivery to destroyed structure → nil spawn | Post-wait `!alive _building` aborts + refunds (`Server_BuyUnit` ~230–238). |
| Adoption timer before crew assignment (empty hull) | Base-GC re-adopt keys on **groups with units**, not empty hulls; idle crewed hull pass is delete, not adopt. Empty-vehicle reaper waits for crew empty. |
| Paid unit counts against cap with no refund on abort | Largely fixed class (#1251 lineage + open #1607 for nil queue throw). In-flight **side-cap overshoot** (allUnits only, no durable reservation for queued buys) is a softer design smell — not filed as a separate HIGH without live overshoot evidence. |
| New group never registered in AICOM ledger | Produce only refills existing `_logik wfbe_teams` entries; founding is Teams.sqf. GC re-adopt does append to `wfbe_teams` with `wfbe_aicom_founded`. No new orphan-create path found in Produce. |

## What was NOT verified

- Live soak / RPT for `BUYFAIL`, `UNIT_PRODUCED`, `AIRMOBILE_REQUISITION_*`, pad-idle counts  
- Whether nested `wfbe_queue` array-token subtraction is identity-safe on A2 OA (live refill continues → likely OK; not claimed as bug)  
- Exact QUERYUNITCREW tuples for every light vehicle class in Core_US/RU  
- Box evidence that airlift grants commonly die unconsumed  

## Deliverable / next action for SQF lane

1. Worktree off `origin/master`.  
2. Implement BUG-1 + BUG-2 first (highest handoff impact, same BuyUnit/Produce surface).  
3. Stack BUG-3 on #1785.  
4. BUG-4 fallback destination in same BuyUnit patch as BUG-1.  
5. Lint gate + CH→TK/ZG LoadoutManager + draft PR only.  

## Milestone / close notes (this agent)

- **No SQF PR** (grok probation).  
- Owner-facing artifact: this report.  
- Independent runtime confirmation remains OPEN.

---

*End of report — r79 production-to-tasking handoff bughunt (research-only).*
