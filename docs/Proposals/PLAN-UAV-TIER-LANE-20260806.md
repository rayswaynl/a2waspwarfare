# WASP UAV Tier Lane — Phased Implementation Plan
*Lane branch: `fable/uav-tier1-fob` (currently == `origin/master` @ `bc56cd8e1f`, clean, no divergent work yet — VERIFIED, `git rev-parse HEAD origin/master fable/uav-tier1-fob` all identical). Reference worktree: `C:/tmp/hcinvest`. All paths below are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/` unless stated otherwise; every edit propagates to the Takistan/Zargabad mirrors via `Tools/LoadoutManager` per the standard mirror step.*

**Legend**: VERIFIED = confirmed this pass by direct `git show`/`Read`/`Grep` against `origin/master@bc56cd8e1f`, either by me (marked "PLANNER-VERIFIED") or by one of the six investigator passes with file:line evidence I re-checked and trust. INFERRED = a reasonable reading or an external fact (native BIS config truth) not independently re-provable from this mission's script tree.

## 0. Provenance note — this lane is largely pre-designed; my job was to verify, reconcile, and re-scope it

Two docs already sit on `origin/master`, dated **2026-08-04** — the same day as the owner rulings — and their own "owner design rulings" sections are a near-verbatim match to the rulings given for this task:

- `docs/Proposals/SPEC-DRONE-TIERS-20260804.md` (752 lines, commit `e4aad4d74f`, 2026-08-04 09:22 — PLANNER-VERIFIED, read in full this pass)
- `docs/Proposals/SPEC-MQ9-ARMED-UAV-20260804.md` (401 lines, commit `04fc7a2de5` — PLANNER-VERIFIED, read in full this pass)
- `docs/design/v2/FPV-DRONE-FOB-GAP-SPEC-2026-07-24.md` (98 lines — PLANNER-VERIFIED, read in full this pass; this is the "earlier scope" ruling 2 names)

I treat SPEC-DRONE-TIERS as the base architecture and **re-verified its load-bearing claims directly** rather than transcribing it, because (a) the six investigator passes disagreed with each other and with the spec doc on at least one concrete fact, and (b) a plan this wide deserves primary-source checks before it drives real PRs. Net result: the spec's architecture holds up well; I'm adopting most of it, **correcting one factual error in its own text**, **tightening its flag scope for Tier 1** (smaller, more reviewable PR-1), and **resolving one genuine interpretive ambiguity** (what "slotted via the EASA system" means) that two investigators read two different, mutually exclusive ways.

## 1. Contradictions found and resolved this pass

### 1.1 Where is `WFBE_C_FPV_DRONE_COST_GUER` actually registered? (three-way disagreement, now settled)

- Investigator 3 said: Lobby param, `Rsc/Parameters.hpp:772-777`, default $5000.
- Investigator 7 said: "never formally registered — only exists as the getVariable fallback."
- SPEC-DRONE-TIERS §3.0 said: "correctly defaulted at `Init_CommonConstants.sqf` next to it."

**PLANNER-VERIFIED (direct grep, this pass):** all three are partially wrong except investigator 3. `Rsc/Parameters.hpp:772-776` has a genuine `class WFBE_C_FPV_DRONE_COST_GUER { title=...; values[]={2500,5000,7500,10000}; default=5000; }` lobby-param block. **It does NOT appear anywhere in `Init_CommonConstants.sqf`** (grep across the whole Chernarus tree for the constant found exactly 3 files — `Support_FPV.sqf`, `fpv.sqf`, `GUI_Menu_GuerDrones.sqf` — and `Init_CommonConstants.sqf` is not one of them). Every consumer read site uses `getVariable ["WFBE_C_FPV_DRONE_COST_GUER", 5000]`, and the fallback (5000) happens to match the lobby default (5000) — so there's no live/dead drift here, unlike the sibling `WFBE_C_FPV_DRONE_COST` case (`Init_CommonConstants.sqf:3020` sets 2500; the `7500` baked into read-site fallbacks at `fpv.sqf:26`, `Support_FPV.sqf:351` is genuinely dead code, per `wasp-getvariable-fallback-trap`). **Practical consequence for this plan:** the live GUER FPV price today is $5,000, sourced from a lobby param, not a mission constant — new tier constants must go in `Init_CommonConstants.sqf` per repo flag policy, and must NOT assume they can "sit next to" the GUER cost the way the spec doc's prose implied.

### 1.2 What does ruling 3 ("three tiers... slotted via the EASA system") actually mean?

Two non-overlapping readings surfaced:

- **Reading A** (one investigator): gate the tiers behind the existing `WFBE_UP_EASA` research-upgrade level.
- **Reading B** (two investigators, independently, and the spec doc): reuse **EASA's data-table *shape*** (`[price, label, payload]` rows, hand-tuned literal ints, the exact idiom the `#1901` SEAD-row marker-block already uses) as the tuning surface — not the literal `GUI_Menu_EASA.sqf` dialog, and not the `WFBE_UP_EASA` research gate.

**Resolved: Reading B.** Reasoning: (1) `GUI_Menu_EASA.sqf:4` keys its dialog off `typeOf (vehicle player)` — it only **re-equips a vehicle the player is already sitting in**; it never spawns one (PLANNER cross-checked this against both independent investigator write-ups, consistent). The FPV/loitering-munition drone is AI-piloted (an AI unit sits in the driver seat; the human spectates via a separate camera script) — the human is never `vehicle player` in it, so the literal EASA dialog structurally cannot host this purchase. (2) Reading A would create a second, unstated gating mechanism that competes with ruling 1's explicit, singular gate ("UAV upgrade LEVEL 2; ARMED drones lock behind it") — Reading B doesn't fight ruling 1. (3) `EASA_Init.sqf:674-697` (PLANNER-VERIFIED, read directly) already has a proven, marker-delimited insert pattern (`//LoadoutManagerSeadEasaInsert` … `_END`) for exactly this "add a tunable row without touching the generated combinatorial vehicle tables" need — this is the mechanism to mirror.

## 2. Architecture decisions carried into the phases below (with reasoning)

| Decision | Resolution | Reasoning |
|---|---|---|
| Does UAV-Level-2 gate Tiers 1-3 too, or only Tier 4? | **Only Tier 4.** | Ruling 1 says "ARMED drones lock behind it" — ruling 2 separately and explicitly scopes Tiers 1-3 as "munitions" (loitering munitions, not a separate armed platform). The two rulings use different nouns for different things on purpose. This also matches the task brief's own framing that UAV-LVL2 "can ship alongside T1 if independent" — they're only independent if T1-3 don't need it. |
| GUER's bespoke acquisition-path candidate | **The B75 truck-built field factory (`RequestFOBStructure.sqf`'s Barracks/Light/Heavy), tracked via the live `WFBE_GUER_FOB_ACTIVE` ledger** — not the always-present town-center Depot. | The literal string "GUER FOB depot" doesn't exist in the repo (negative grep, cross-confirmed). Two real candidates exist; only the truck-built factory is *deployed* (matches ruling 4's own word), the Depot is permanent/non-deployed and already serves an unrelated purpose (GUER's base vehicle-buy pool). Ruling 4 explicitly grants designer latitude here — this is my recommendation, not a re-derivation of settled fact (see Open Decision #2). |
| T1's flag scope | **Tighter than the spec doc.** Only `WFBE_C_DRONE_TIERS` (master) + `WFBE_C_DRONE_FOB_RANGE` are new; T1 reuses the existing `WFBE_C_FPV_DRONE_COST_GUER` / `WFBE_C_FPV_DRONE_AMMO` / `WFBE_C_FPV_COOLDOWN` constants unchanged. | The spec doc front-loads `WFBE_C_DRONE_TIER1_COST`/`_AMMO` into PR-1 even though nothing in T1's actual scope reads them yet (Tier 1 *is* the existing FPV drone, unchanged price/warhead) — registering unused parallel constants just for symmetry is churn PR-3 would have to reconcile anyway. Smaller, self-explanatory diff; matches PR-1's own stated goal of being the "smallest reviewable unit." |
| Does the UAV-Level-2 array promotion itself need its own flag? | **Yes — new flag `WFBE_C_UAV_LEVEL2`, default 0; level-2 tuple only exists in the array when it's on.** | The repo's flag policy is about *any* new player-visible capability, and "a new research option appears in the upgrade menu" is player-visible even before Tier 4 (its consumer) ships. The spec doc's own sketch promotes the array unconditionally, relying only on Tier 4's *consumer*-side gate to keep it inert — workable, but ships a visible "research this for nothing yet" option in the window between PR-2a and PR-5. The **closed, owner-approved-at-the-time PR #1148** ("unify UAV upgrade level 2 FOB and AI swarm") independently made the identical judgment call — its own body states "while both are dark, UAV2 player max/cost/link/time data collapses to level 1" (PLANNER-VERIFIED, `gh pr view 1148`) — i.e. prior in-repo precedent already flag-gated this exact promotion. I follow that precedent. |

## 3. PHASE T1 — Tier 1 rework: GUER-only + FOB-purchase-only (ships first)

**Scope, exactly**: take the *existing*, already-shipped FPV strike drone (today: side-agnostic Tactical-menu row for WEST/EAST/CDF/INS/RU/USMC at $2,500, plus a GUER-only `GuerDrones` dialog card at $5,000, **neither FOB-gated**) and (a) retire the generic-menu row under a new master flag so the capability becomes GUER-exclusive, and (b) require GUER to be standing at a live, deployed GUER FOB structure to purchase it. **No new tiers, no EASA table, no UAV-Level-2, no WEST/EAST replacement shop yet** — those are later phases.

### 3.1 Flags (new, appended to `Common/Init/Init_CommonConstants.sqf` only — per repo policy, never touch existing defaults)

| Flag | Default | Purpose |
|---|---|---|
| `WFBE_C_DRONE_TIERS` | `0` | Master gate. `0` = mission byte-identical to HEAD — the `fable/fpv-strike-drone`-derived behavior already live on master (all-sides Tactical row, unconditional GUER field-launch) is untouched. `1` = GUER-exclusive + FOB-gated. |
| `WFBE_C_DRONE_FOB_RANGE` | `40` | Metres from a live GUER FOB structure (or, later, a WEST/EAST Forward FOB tent) required to purchase. |

Reused unchanged (no edit): `WFBE_C_FPV_DRONE_COST_GUER` (`Rsc/Parameters.hpp:772-776`, lobby default $5000), `WFBE_C_FPV_DRONE_AMMO` (`Init_CommonConstants.sqf:3022`, `"R_57mm_HE"`), `WFBE_C_FPV_COOLDOWN` (existing per-UID cooldown, `Support_FPV.sqf`).

### 3.2 Files to change (no new files needed for T1)

| File | Anchor (current) | Change | Status |
|---|---|---|---|
| `Common/Init/Init_CommonConstants.sqf` | append after the FPV block, `:3018-3022` | Register the two flags above (`if (isNil "X") then {X = v};` idiom) | PLANNER-VERIFIED anchor |
| `Client/GUI/GUI_Menu_Tactical.sqf` | `:137-141` (row-append), `:435-439` (enable), `:583-589` (dispatch) | Wrap the *existing* `if ((...getVariable ["WFBE_C_FPV_DRONE",0])>0) then {...}` row-append block in a new outer `if ((...getVariable ["WFBE_C_DRONE_TIERS",0]) <= 0) then {...}` — when the master flag is on, `"FPV_Strike"` is never added to the list; its `case` handlers become unreachable dead code, kept (not deleted) for flag-off byte-parity | PLANNER-VERIFIED (`:137-141` read directly this pass; `:126` row-list, `:425/429/432/435/571/575/582/586` case sites confirmed directly) |
| `Client/GUI/GUI_Menu_GuerDrones.sqf` | `:11` (side-gate exit), `:65-90` (state display), `:201-210` (LAUNCH branch, `MenuAction==1`) | LAUNCH branch gains a FOB-proximity check before allowing purchase (client-side, advisory-only — see §3.3); state-display block gets an inline "FOB in range?" hint so the button visibly disables when out of range, mirroring the file's existing `ctrlEnable [32013, ...]` idiom | PLANNER-VERIFIED (`:11`, `:67-68`, `:201-210` read directly this pass) |
| `Server/Support/Support_FPV.sqf` | validation chain (investigator-cited `:200-366`; PLANNER-VERIFIED `:351-355` cost-resolution directly) | Insert a new **authoritative** deny check, described in §3.3 below | PLANNER-VERIFIED anchor for insertion point |
| `Client/Module/FPV/fpv.sqf`, `Common/Config/Core_Root/Root_GUE.sqf` | `:20-22` (GUER CC-bypass), `:40` (FPVDRONE classname) | **No change** — T1 doesn't touch the flight model, hull, or the existing field-launch fallback logic; the FOB gate lives entirely in the purchase authorization step (GuerDrones.sqf client hint + Support_FPV.sqf server check), not in `fpv.sqf` itself | PLANNER-VERIFIED (both lines read directly) |

### 3.3 Client UI gate + server authoritative re-check (the actual FOB-gating mechanism)

**GUER-depot bespoke path.** The B75 GUER FOB system (`Client/Action/Action_BuildFOB.sqf` → `Server/PVFunctions/RequestFOBStructure.sqf`, unchanged by this plan) builds an ordinary Barracks/Light/Heavy factory in the field. Its "is a GUER FOB alive right now, and where" oracle already exists and is already live: `RequestFOBStructure.sqf:214` appends `[markerName, pos, facType]` to `WFBE_GUER_FOB_ACTIVE` on successful build; `Server_BuildingKilled.sqf:220-223` prunes the entry on destruction (both PLANNER-VERIFIED, read directly this pass). This ledger is a plain `missionNamespace` variable, broadcast and client-readable with zero new plumbing.

**Client gate (advisory only — UX, not security).** Add an inline check inside `GUI_Menu_GuerDrones.sqf`'s existing per-tick refresh block (near its current `:65-68` state display):

```sqf
//--- T1 (WFBE_C_DRONE_TIERS): FOB-proximity hint. Advisory only -- Support_FPV.sqf is authoritative.
_guerFobNear = false;
{
	if (!isNil "_x" && {(getPos player) distance (_x select 1) < (missionNamespace getVariable ["WFBE_C_DRONE_FOB_RANGE", 40])}) then {_guerFobNear = true};
} forEach (missionNamespace getVariable ["WFBE_GUER_FOB_ACTIVE", []]);
if ((missionNamespace getVariable ["WFBE_C_DRONE_TIERS", 0]) > 0 && {!_guerFobNear}) then {
	ctrlEnable [32013, false];
	ctrlSetText [32014, "No live FOB in range"];
};
```

**Server re-check (authoritative — the actual security boundary).** GUER's purchase already flows through the existing `["fpv","purchase",sideJoined,_drone,clientTeam,player,_driver,_token] Call _sendFpvToServer` → `Support_FPV.sqf` chain (PLANNER-VERIFIED, `fpv.sqf:185` read directly — the payload already carries the player-unit object reference server-side, so a server-side `distance` check against it is a normal, already-proven idiom, not new capability). Insert, before the existing funds/cost check:

```sqf
//--- T1 (WFBE_C_DRONE_TIERS): GUER purchases must originate near a live GUER FOB. Never trust
//--- client-reported distance -- re-derive from the server-held ledger + the payload's own player object.
if (_side == resistance && {(missionNamespace getVariable ["WFBE_C_DRONE_TIERS", 0]) > 0}) then {
	_guerFobNear = false;
	{
		if (!isNil "_x" && {(getPos _p) distance (_x select 1) < (missionNamespace getVariable ["WFBE_C_DRONE_FOB_RANGE", 40])}) then {_guerFobNear = true};
	} forEach (missionNamespace getVariable ["WFBE_GUER_FOB_ACTIVE", []]);
	if (!_guerFobNear) exitWith {_deny = "No live GUER FOB in range."};
};
```
(`_p` = whichever local already holds the received player-object argument in this file's existing `Private [...]` list — confirm the exact name at the real insertion point rather than assuming.)

**Defense in depth for the retired WEST/EAST path.** Also add, in the same validation chain: when `WFBE_C_DRONE_TIERS > 0` and `_side != resistance`, deny unconditionally — their menu row is gone, but a modified client could still fire the PVF directly. This matches the codebase's universal "the UI gate is never the security boundary" convention (same reasoning as the SCUD purchase's server-side re-validation, `Common_RequestIcbmTelPurchase.sqf`).

**Rollout note (owner-visible, not a code question):** once `WFBE_C_DRONE_TIERS` is flipped to `1`, WEST/EAST temporarily have **zero** FPV/loitering-munition access until PR-4 (§5.3) ships their replacement shop. If the owner wants to avoid that gap in practice, hold the flag at `0` until PR-4 also merges, or accept the interim gap — this is a sequencing choice for the owner, not an engineering one.

### 3.4 Base branch (`fable/fpv-strike-drone`) — what to cherry-pick vs rewrite

**PLANNER-VERIFIED this pass** (fetched into `C:/tmp/uavtier` without checkout): tip `312c8268b0`, merge-base `b2a198d698` (2026-07-06, **2,719 commits behind current master**), not an ancestor of `origin/master`, 12 unique Chernarus files / +100/-22 (×3 mirrors = 36 files / +300/-66, matching the earlier audit exactly). **Recommendation: do not merge, rebase, or patch from this branch at all.** Base the new work fresh on current `origin/master`.

| Piece | Verdict | Reasoning |
|---|---|---|
| 3-tier warhead-differentiation concept | **Re-derive fresh, don't patch the diff** | Same *structural* idea (N tiers → N warheads, one hull) but the branch's own prices ($4500/$7500/$12500) and ammo (OG-7/57mm/Hellfire) don't match this lane's approved pricing ($5000 Tier 1, unchanged) or later tiers' config-truth (§5). |
| Server-side warhead whitelist-and-bind pattern (`setVariable` tier on drone at spawn, read back at detonate, never trust client) | **Reuse the pattern in PR-3, rewrite the diff** | Sound, directly applicable to today's `Support_FPV.sqf`/`Support_FPV_Detonate.sqf` — but must be built on current master's capability-token architecture, not the branch's obsolete one (next row). |
| Client-side fund deduction + fire-and-forget `RequestSpecial` dispatch | **Discard — superseded** | Master's capability-token/async-poll purchase-authority rework (`f508d1bb55`, 2026-07-12, 5 days after this branch) fully replaces it; the branch was never rebased past it. |
| Row-append into `GUI_Menu_Tactical.sqf` (generic, all-sides Tactical Center) | **Discard entirely** | Wrong surface — the literal opposite of "GUER-only"; T1 retires this row rather than extending it. |
| `Root_*.sqf` hull reassignment (`AH6X_EP1` → `Ka137_PMC` for WEST/EAST) | **Discard entirely** | Unrelated to any ruling; this design deliberately keeps `AH6X_EP1` everywhere (§5.1) to avoid new-classname risk the owner never asked for. |
| Missing rearm-cooldown on the branch's new tier buttons | **Moot** | The row itself is retired under T1; the regression disappears with it. |
| Strobe-marker + sport-mode velocity-assist cosmetic (`312c8268b0`) | **Optional, separate, later PR — not in scope here** | Purely additive, no security surface, lint-clean; genuinely rebasable as its own tiny PR if the owner wants the visual polish, but it is not part of any owner ruling. |

### 3.5 Mirror + lint gates

- Lint: `python Tools/Lint/check_sqf.py --select A3CMD,A3HASH,A3MARKER,A3NUMGATE,A3PRIVATE,A3REVEAL,A3SELECT,A3SORT,A3STRING,BAREEXIT,BOOLCMP,BRACKET,DBLBOM,DEADNOQA,FLAGGATE,GROUPGETVAR,MILMARKER,NSSETVAR3,PUBVARSV,TRAILCOMMA --no-classname-index` — 0 new findings in the 4 touched files. No new classnames introduced in T1, so `--no-classname-index` stays appropriate.
- Bracket delta: net `{`/`}` and `[`/`]` = 0 per edited file (all edits are pure wraps/insertions, easy to eyeball).
- `dotnet run -c RELEASE` from `Tools/LoadoutManager`; restore TK/ZG `version.sqf.template` drift; verify TK (`WF_MAXPLAYERS 34`, `STARTING_DISTANCE 7500`) and ZG (`WF_MAXPLAYERS 34`, `STARTING_DISTANCE 5000`) per-map values per `CLAUDE.md`'s checklist.
- Flag-off byte-identical: diff the mission against HEAD with the flag at 0 — must be empty for every reachable code path.

### 3.6 Test plan

**Boot smoke:**
1. Flag off (`WFBE_C_DRONE_TIERS=0`): mission boots clean; WEST/EAST still see "FPV STRIKE DRONE" in the Tactical menu; GUER's GuerDrones FPV card still purchases with no FOB requirement — byte-for-byte parity with current HEAD.
2. Flag on: mission boots clean, no RPT errors; WEST/EAST's Tactical menu no longer offers the row at all; GUER's GuerDrones dialog still renders (state machine untouched).
3. Lint + bracket + mirror gates above all pass.

**In-game (single-machine editor preview is sufficient for menu-gating logic, insufficient for replication timing — see the last two rows):**
4. GUER player away from any FOB → Launch: denied with a visible hint, zero funds deducted.
5. Build a GUER FOB (truck → Barracks/Light/Heavy), stand within 40m → Launch: succeeds, funds deducted once, drone spawns.
6. Destroy that FOB, immediately retry → Launch: denied (ledger prune via `Server_BuildingKilled.sqf` already live).
7. WEST or EAST: confirm "FPV STRIKE DRONE" is entirely absent from the Tactical menu when the flag is on.
8. Existing per-UID `WFBE_C_FPV_COOLDOWN` still enforced unchanged (T1 doesn't touch it).
9. **Real dedicated-server session required** (not editor preview): confirm the server-side FOB-distance check uses live, network-replicated positions, not a stale single-machine snapshot.
10. Repeat 4-7 on Takistan and Zargabad mirrors post-regen — identical behavior.

## 4. PHASE UAV-LVL2 — upgrade-data promotion + opening standard UAV access to GUER

Two independent sub-lanes; both can ship alongside T1.

### 4.1 PR-2a — UAV upgrade Level 2 (gates Tier 4 only, per §2)

**New flag:** `WFBE_C_UAV_LEVEL2` (default `0`) — see §2's reasoning for why this promotion itself is flag-gated (repo policy + `#1148` precedent), a deliberate refinement over the spec doc's unconditional-literal sketch.

**Registry (PLANNER-VERIFIED, `Init_CommonConstants.sqf:37-60` read directly):** `WFBE_UP_UAV = 5` (line 42), one of 24 fixed slot indices; `WFBE_UP_AIR = 3` (line 40), `WFBE_UP_EASA = 15` (line 52).

**Which files, verified this pass (not assumed):** every side's `Upgrades_<SIDE>.sqf` carries the identical parallel-array shape at index 5. Two Root files branch on `WF_A2_CombinedOps` between a shared and a side-specific table (PLANNER-VERIFIED, `Root_USMC.sqf:118-151` read directly: `if (WF_A2_CombinedOps) then {...Upgrades_CO_US.sqf...} else {...Upgrades_USMC.sqf...}`; `Root_RU.sqf`/`Root_TKA.sqf` mirror this for `Upgrades_CO_RU.sqf`/`Upgrades_RU.sqf`). `version.sqf.template:14` sets `#define COMBINEDOPS 1`, which resolves `WF_A2_CombinedOps = true` — **so `Upgrades_CO_US.sqf` and `Upgrades_CO_RU.sqf` are the live tables under this build; `Upgrades_USMC.sqf`, `Upgrades_RU.sqf`, `Upgrades_OA_TKA.sqf` are dead branches today** — editing them would silently no-op. `Upgrades_CDF.sqf` and `Upgrades_INS.sqf` are single-call-site, unambiguous. `Upgrades_GUE.sqf`/`Upgrades_CO_GUE.sqf` stay untouched (no UAV classname exists for GUER — see §4.2). **Re-confirm this branch condition at implementation time** — it's a fact about the current build, not a permanent guarantee.

**The promotion**, per touched file, computed conditionally before the side's big arrays are assembled:

```sqf
_uavCosts = [[2000,0]]; _uavLevels = 1; _uavLinks = [[WFBE_UP_AIR,2]]; _uavTimes = [60];
if ((missionNamespace getVariable ["WFBE_C_UAV_LEVEL2", 0]) > 0) then {
	_uavCosts  = [[2000,0],[6000,0]];
	_uavLevels = 2;
	_uavLinks  = [[WFBE_UP_AIR,2],[WFBE_UP_UAV,1]]; //--- L2 requires L1 of the SAME upgrade.
	_uavTimes  = [60,90];
};
```
...splice `_uavCosts`/`_uavLevels`/`_uavLinks`/`_uavTimes` into the existing COSTS/LEVELS/LINKS/TIMES arrays at index 5. Verify tuple-count == `LEVELS[5]` after editing (an index-out-of-range purchase-time crash, not a load-time one, is the failure mode if these drift).

**Platform-aware enable predicate (Tier 4 only, not this PR):** RU/INS's tables get the same shape-consistency promotion (needed only so all ten side-tables stay parallel), but `Pchela1T` has no gunner turret — the Tier-4 shop's *own* enable check (PR-5) must test `typeOf playerUAV in WFBE_C_UAV_ARMED_CLASSES`, never a bare level check alone, or RU/INS would visibly "research" an armed tier that does nothing.

**AI-commander research handling:** reuse the existing **reactive one-shot** idiom (`AI_Commander.sqf`'s CBR-radar block: `!isNil` guard + `count _upgLvls > WFBE_UP_UAV` bounds guard + a live-condition check + a persisted one-shot latch), not the static doctrine-build-time append `[WFBE_UP_UAV,1]` already uses — because researching UAV Level 2 is worthless to the AI before it's actually built a Forward FOB (Tier 4's purchase gate). Live condition: `(_side) Call WFBE_CO_FNC_GetSideStructures` finds a `wfbe_structure_type == "ForwardFOB"` entry, or for GUER, `count (missionNamespace getVariable ["WFBE_GUER_FOB_ACTIVE", []]) > 0`.

**`Server_ProcessUpgrade.sqf` hook — verdict: not needed.** That file's completion-hook pattern (`:94-105`, gated on `_upgrade_id == WFBE_UP_ICBM`) exists because ICBM research fires a one-time reward (spawn a TEL truck) on completion. UAV Level 2 is a pure **threshold gate** (`>= 2`), read at purchase-time by the Tier-4 shop (PR-5) and by the Tactical-menu UAV row's own enable check — nothing needs to *react* to the level-up event itself. No new code in `Server_ProcessUpgrade.sqf`.

### 4.2 PR-2b — Open standard UAV rows to GUER (independent of 2a)

**PLANNER-VERIFIED this pass:** `Root_GUE.sqf` has **zero** `UAV`-pattern matches (no `WFBE_GUEUAV` registered — confirmed directly via grep, contrast the same file's confirmed `:40` FPVDRONE registration). `Support_UAV.sqf:20-25` has the exact same "no Command Center = deny" shape `fpv.sqf` had before its own GUER bypass (`:20` denies missing class; `:22-25` does `GetFactories`/nearest-CC lookup and denies if none found) — **GUER hits this deny unconditionally today, with no bypass patched in yet** (confirmed directly; `fpv.sqf`'s analogous bypass at `:20-22` has no counterpart in `Support_UAV.sqf`). Separately, `Server/Init/Init_Server.sqf:1045-1061` (read directly) shows GUER's `wfbe_upgrades` array is **permanently, deliberately seeded to all-zero** — an explicit 2026-07-28 comment explains this releases a client-init deadlock, and it's never incremented since GUER has no HQ/research flow (matching the Mobile-HQ "GUER has no HQ by design" constraint). This means registering a classname alone is insufficient — the existing `_currentLevel > 0` enable check at `GUI_Menu_Tactical.sqf:425-427` will *never* pass for GUER through the normal mechanism.

**The established precedent for exactly this situation already exists in the codebase**: `GUI_Menu_BuyUnits.sqf:507` (PLANNER-VERIFIED, read directly) — `[..., (if (sideJoined == resistance) then {999} else {_val})] Call UIFillListBuyUnits; //--- GUER: bypass upgrade-gate (funds + time-tier, no upgrades)`. GUER is unconditionally treated as "sufficiently upgraded" wherever the rest of the codebase gates on upgrade level, because its level track structurally never moves. This lane reuses that exact idiom rather than inventing a new one.

**New flag:** `WFBE_C_GUER_UAV_ACCESS` (default `0`).

| File | Change |
|---|---|
| `Common/Init/Init_CommonConstants.sqf` | register `WFBE_C_GUER_UAV_ACCESS = 0` |
| `Common/Config/Core_Root/Root_GUE.sqf` | conditionally register the classname, flag-gated: `if ((missionNamespace getVariable ["WFBE_C_GUER_UAV_ACCESS",0])>0) then {missionNamespace setVariable [Format["WFBE_%1UAV",_side], "Pchela1T"]};` (classname choice discussed below) |
| `Client/GUI/GUI_Menu_Tactical.sqf` `:425-427` | extend the `UAV` case's enable predicate with the same bypass idiom, flag-gated: `_currentLevel = if (sideJoined==resistance && {(missionNamespace getVariable ["WFBE_C_GUER_UAV_ACCESS",0])>0}) then {999} else {_currentUpgrades select WFBE_UP_UAV};` |
| `Server/Support/Support_UAV.sqf` `:20-25` | add a GUER field-spawn bypass mirroring `fpv.sqf:20-22` exactly, same flag gate: `if (_side==resistance && {(missionNamespace getVariable ["WFBE_C_GUER_UAV_ACCESS",0])>0}) then {_closest = player};` inserted before the `isNull _closest exitWith` deny |
| `UAV_Destroy` / `UAV_Remote_Control` cases | **no change** — both gate only on `alive playerUAV`, already side-agnostic; they work automatically once GUER can spawn a UAV at all |

**Classname choice — recommendation, owner-reviewable (Open Decision #4):** `Pchela1T`. It's already proven/registered (RU/INS use it today), needs zero new classname-proof work, and — usefully — it is **structurally excluded** from Tier 4/armed capability by `SPEC-MQ9`'s own allowlist (`WFBE_C_UAV_ARMED_CLASSES`, §6) since it has no gunner `MainTurret`. That's a defense-in-depth property, not just a cost-saving: GUER's plain UAV can never accidentally end up eligible for the armed-turret path later.

**Does GUER's standard UAV access need a FOB gate too?** Recommendation: **no** (Open Decision #3). Ruling 4's FOB-purchase constraint is stated in the numbered list under "Munitions" (rulings 2-5, the new drone-tier system); "open standard UAV rows to GUER" is a separate, unnumbered bullet about parity with WEST/EAST's *existing* UAV purchase, which itself only requires Command-Center proximity, not a FOB. Parity says GUER's version should mirror that (the base-less field-spawn bypass above), not invent a new FOB requirement nothing else in the standard-UAV feature has.

## 5. PHASE T2/T3 — loitering munitions via EASA-style tiering

### 5.1 EASA row recipe (mirrors the proven SEAD marker-block pattern exactly)

`Client/Module/EASA/EASA_Init.sqf` is **generated** by `Tools/LoadoutManager` (a C# tool) from per-airframe pylon/ammo data classes — hand-editing the combinatorial vehicle tables gets silently overwritten on the next `dotnet run`. But two hand-authored exception blocks are re-injected post-write via literal text markers (PLANNER-VERIFIED, `EASA_Init.sqf:674-697` read directly — the `//LoadoutManagerSeadEasaInsert` … `_END` pair). New tunable data that isn't part of the per-vehicle combinatorial model goes here, the same way the SEAD row does:

```sqf
//LoadoutManagerDroneTierEasaInsert
//--- Drone Tier price/label table (ruling 3). NOT wired into GUI_Menu_EASA.sqf's equip flow --
//--- EASA re-equips a vehicle the player is sitting in, it never spawns one. This block only
//--- publishes the tunable price/label rows; GUI_Menu_DroneShop.sqf / GuerDrones.sqf read
//--- WFBE_EASA_DRONE_TIERS directly instead of going through EASA_Equip.sqf.
if ((missionNamespace getVariable ["WFBE_C_DRONE_TIERS", 0]) > 0) then {
	WFBE_EASA_DRONE_TIERS = [
		[(missionNamespace getVariable ["WFBE_C_FPV_DRONE_COST_GUER", 5000]), "Tier 1 - Light Loitering Munition",  1],
		[(missionNamespace getVariable ["WFBE_C_DRONE_TIER2_COST", 9000]),    "Tier 2 - Medium Loitering Munition", 2],
		[(missionNamespace getVariable ["WFBE_C_DRONE_TIER3_COST", 15000]),   "Tier 3 - Heavy Loitering Munition",  3],
		[(missionNamespace getVariable ["WFBE_C_DRONE_TIER4_COST", 45000]),   "Tier 4 - GBU Strike Drone",          4]
	];
};
//LoadoutManagerDroneTierEasaInsert_END
```
`[price, label, tierNumber]` mirrors the existing `[price, label, [[weapons],[ammo]]]` shape structurally, substituting a tier number since the shop dialog consumes this directly rather than through `EASA_Equip.sqf`. Note Tier 1's row reads the *existing* `WFBE_C_FPV_DRONE_COST_GUER`, not a new constant — consistent with T1 not introducing a parallel Tier-1 constant.

### 5.2 PR-3 — Tiers 2-3 platform + tier-lookup threading

**New flags:** `WFBE_C_DRONE_TIER2`, `WFBE_C_DRONE_TIER3` (subflags, default `1`, meaningful only under the master), `WFBE_C_DRONE_TIER2_COST=9000`, `WFBE_C_DRONE_TIER3_COST=15000`, `WFBE_C_DRONE_TIER2_AMMO="Bo_FAB_250"`, `WFBE_C_DRONE_TIER3_AMMO="Bo_GBU12_LGB"`.

**Design choice (carried from the spec, sound): all tiers reuse the identical `AH6X_EP1` hull** — zero new airframe classname risk; tiers differ only by warhead and price.

**Mechanism proof (PLANNER cross-checked, not independently re-read line-by-line this pass but corroborated across two independent investigator write-ups and the file's own cited role): `Support_FPV_Detonate.sqf:164`** reads `_ammoClass = missionNamespace getVariable ["WFBE_C_FPV_DRONE_AMMO", "R_57mm_HE"]` and later `createVehicle`s that bare `CfgAmmo` class directly to detonate — this works for *any* valid ammo classname with no dependency on it ever being fired from a real weapon. Consequence: a new tier needs only a proven `CfgAmmo` classname, no new weapon/magazine/turret chain.

**Thread a `_tier` integer through the existing chain** (`fpv.sqf`'s `_sendFpvToServer` payload, PLANNER-VERIFIED at `:44-67,185,194` — already a generic `["fpv", mode, ...args] Call _sendFpvToServer` array, trivially extended with one more element) rather than forking three near-duplicate file sets:
- `fpv.sqf` / `fpv_interface.sqf`: add `_tier` to the purchase payload; flight/fire model itself is unchanged (ruling 2 scopes manual-fire/driver-operable to Tiers 1-3 only, and this is already how the drone works today).
- `Support_FPV.sqf`: re-derive cost from `WFBE_C_DRONE_TIER{N}_COST` server-side (never trust a client-supplied price or tier), `setVariable` the resolved tier onto the spawned drone hull.
- `Support_FPV_Detonate.sqf`: read the tier back off the drone (`getVariable`) instead of the single global `WFBE_C_FPV_DRONE_AMMO`, to select the ammo class.

**Blocking verification gap (not an owner decision — a mechanical task):** `Bo_FAB_250` (Tier 2's warhead) is corroborated only by an in-repo design comment (`Init_CommonConstants.sqf:108`, GUER VBIED blast-radius note) and the standard `NRnd_FAB_250`→`Bo_FAB_250` A2 OA naming convention — **not** a line-numbered external `CfgAmmo` dump citation the way `Bo_GBU12_LGB` has. **Must be confirmed against the `rayswaynl/arma2-co-config-reference` dump (or the `a2oa-verify-command` skill's ladder) before PR-3 merges** — ship on the in-repo corroboration alone at your own risk.

### 5.3 PR-4 — FOB-scoped shop (WEST/EAST) + GUER shop wiring for Tiers 2-4

**New files:**
- `Client/GUI/GUI_Menu_DroneShop.sqf` — new WEST/EAST dialog, lists `WFBE_EASA_DRONE_TIERS` rows, gated on the new `droneShopInRange` FSM boolean.
- `Server/PVFunctions/RequestDroneTier.sqf` — new server-authoritative PVF; validate-then-charge, mirroring `RequestForwardFOB.sqf`'s shape (**not** EASA/BuyUnits' client-computed-and-applied shape — a capped military asset shouldn't trust a client-supplied price, same reasoning `Action_BuildForwardFOB.sqf`'s own header already states, and the same "never trust client position" rule `FPV-DRONE-FOB-GAP-SPEC-2026-07-24.md`'s security notes already require for the FOB-launch gate design). Re-derives: cost from `WFBE_C_DRONE_TIER{N}_COST`, FOB proximity from the server-held tent/factory object's own position, `WFBE_UP_UAV` level (Tier 4 only), the per-UID cooldown, and bounds-checks the tier argument against `[1,2,3,4]` (reject, don't index-crash, on anything else).

**WEST/EAST FOB discoverability.** `RequestForwardFOB.sqf` (PLANNER-VERIFIED, read directly) tags its tent `wfbe_structure_type="ForwardFOB"` (`:148`), `wfbe_is_fob=true` (`:156`), builds it as a real `LocationLogicCamp` (`:106`) *specifically* so it's discoverable via `nearEntities [WFBE_Logic_Camp, r]` with no new plumbing — the same lookup `Client_GetClosestCamp.sqf` already uses for `gearInRange` (PLANNER-VERIFIED, `updateavailableactions.fsm:158-184` and `:248`'s `_usable` array read directly). Add `droneShopInRange` to the same FSM, same idiom, feeding the same `_usable` array, gating a new "Drone Shop" row exactly like `gearInRange` already gates "Buy Gear."

**Important risk, not yet resolved by anyone:** `RequestForwardFOB.sqf:187` (PLANNER-VERIFIED, read directly) contains a **self-check warning** — `"FOBCAMPPROBE|FAILED|... the runtime LocationLogicCamp is NOT returned by nearEntities - forward respawn and gear resupply WILL NOT WORK. Keep WFBE_C_STRUCTURES_FOB at 0 until this is redesigned."` The entire WEST/EAST FOB-shop design (and, by the same `nearEntities` mechanism, gear resupply and forward respawn today) depends on this probe passing on every client. Since `WFBE_C_STRUCTURES_FOB` already defaults to `1`/on in production without any open "gear resupply broken" complaint on record, this is likely fine — but **confirm via RPT (the `rpt-triage` skill) that this warning has never actually fired on a live/soak server before investing engineering time in the FSM approach**, rather than assuming.

**GUER shop wiring.** GUER's existing `GUI_Menu_GuerDrones.sqf` (from T1, already FOB-gated for Tier 1) is the recommended host for Tiers 2-4 too (Open Decision #2) — extend its state machine to route Tier 2-4 purchases through the new `RequestDroneTier.sqf` PVF (passing the clicked tier number) while Tier 1 keeps using the legacy `"fpv"/"purchase"` mode unchanged from T1, for minimal diff to already-shipped code:

```sqf
//--- GUER FOB proximity gate (mirrors the WEST/EAST droneShopInRange idiom, against the GUER ledger).
_guerFobNear = false;
{ if (!isNull _x && {alive _x} && {(player distance _x) < (missionNamespace getVariable ["WFBE_C_DRONE_FOB_RANGE", 40])}) then {_guerFobNear = true}; }
	forEach (missionNamespace getVariable ["WFBE_GUER_FOB_ACTIVE", []]);
```

**Cap/cooldown:** no new cap beyond the existing "one live FPV drone per player" / "one live UAV per player" rules. New shared `WFBE_C_DRONE_REARM_COOLDOWN` (default 90s, introduced *here*, not in T1 — see §2's scope-tightening note) replaces the single-tier `WFBE_C_FPV_COOLDOWN` for anything routed through the new shop, wider since it now gates four price points and should stop rapid tier-hopping.

**Test plan additions for this phase:** each tier's warhead detonates with a visibly different blast profile; the rearm cooldown blocks a Tier-1→Tier-3 hop attempt for the full window; `droneShopInRange` goes true/false within one FSM tick of standing near / leaving a live tent **on a real dedicated-server hop** (editor preview hides this); mirror parity on TK/ZG.

## 6. PHASE T4 — GBU-class strike drone / MQ-9 (scope + config-truth only — later lane, not built now)

**Reads literally per ruling 5** ("reuse the MQ-9 config-truth") — this is `SPEC-MQ9-ARMED-UAV-20260804.md`'s feature, reused wholesale, purchased through the new shop instead of riding the plain UAV-upgrade gate for free.

**Flags:** `WFBE_C_UAV_ARMED = 0` (master, name reused unchanged from SPEC-MQ9), `WFBE_C_UAV_ARMED_GBU12_MAGS = 2` (SPEC-DRONE-TIERS bumps SPEC-MQ9's non-binding default of 1 to 2, reflecting "expensive, very late-game"), `WFBE_C_DRONE_TIER4 = 1` (subflag), `WFBE_C_DRONE_TIER4_COST = 45000`. Plain (non-flag) scope allowlist: `WFBE_C_UAV_ARMED_CLASSES = ["MQ9PredatorB","MQ9PredatorB_US_EP1"]` — deliberately not overridable, a correctness boundary not a balance knob.

**Config-truth citations — INFERRED, not independently re-verified this pass** (native BIS `CfgVehicles`/`CfgWeapons`/`CfgMagazines`/`CfgAmmo` content, outside this mission's script tree, cited from the external `rayswaynl/arma2-co-config-reference` dump by SPEC-MQ9 §3):
- Airframe (unchanged, already live): `MQ9PredatorB` (CDF/USMC), `MQ9PredatorB_US_EP1` (US/US_Camo) — `Root_CDF.sqf:18`, `Root_USMC.sqf:18`, `Root_US.sqf:20`, `Root_US_Camo.sqf:21` (classname wiring PLANNER cross-checked as VERIFIED against multiple independent investigator citations).
- Native munition (unchanged): `HellfireLauncher`/`8Rnd_Hellfire` → `M_Hellfire_AT`.
- Injected #1: `BombLauncherA10`/`4Rnd_GBU12` → `Bo_GBU12_LGB` (`LaserBombCore`, `irLock=0,laserLock=1`) — proven turret-real on the vanilla A-10, same `weapons[]` array pattern.
- Injected #2 (optional, Open Decision #5): `MaverickLauncher`/`2Rnd_Maverick_A10` → `M_Maverick_AT` (`irLock=1`).
- Excluded, structurally: `Pchela1T` (RU/INS) — no gunner `MainTurret`; enforced by the classname allowlist, never a side check.

**Mechanism (from SPEC-MQ9, unmodified when this lane starts):** all munitions mount on the single `MainTurret` via path `[-1]` (hull/single-turret convention — **never** plain `addWeapon`/`addMagazine`, silent no-op on this hull), stacking onto the existing Hellfire, injected client-side in `uav.sqf`'s with-arg branch after `moveInDriver`, gated on a bounded `waitUntil {local _uav || {diag_tickTime-_start>5}}` before touching the turret (server-created objects are not guaranteed synchronously local). Player selects munitions via the **stock A2/OA turret weapon-select action** (zero new dialog) — `uav_interface.sqf`/`uav_interface_oa.sqf` need one defensive one-line fix so the interface still opens on Hellfire by default once `weapons _uav` has more than one entry. **Never** route an armed UAV through `Common_RearmVehicle.sqf` — it reads magazines straight from config and would silently wipe the injected runtime magazines back to Hellfire-only; use `Common_RearmVehicleOA.sqf`'s `setVehicleAmmo`/`reload` idiom instead, or no rearm at all (current design: none needed, each sortie expends its fixed count once).

**Gate:** `WFBE_UP_UAV` Level 2 (§4.1) **and** a live FOB (§5.3) **and** `WFBE_C_DRONE_TIER4 > 0`.

**Files this phase will touch (not edited now):** `Client/Module/UAV/uav.sqf`, `uav_interface.sqf`, `uav_interface_oa.sqf`, `Init_CommonConstants.sqf`, `Server/PVFunctions/RequestDroneTier.sqf` (extending PR-4's spawn branch for Tier 4).

**Before this phase starts coding** (not just before merge): independently re-verify the native MQ-9 `CfgVehicles`/`CfgWeapons` hardpoint truth above via the `a2oa-verify-command` skill's ladder or a live `configFile >> "CfgVehicles" >> "MQ9PredatorB"` probe — this pass could not access the external config dump or the binarized engine config, so the entire phase's feasibility currently rests on an inherited, not re-proven, citation.

## 7. Sequencing

```
PR-1 (T1)  ─────────────────────────────────────────────┐
PR-2a (UAV L2 data) ──────────────┐                      │
PR-2b (GUER UAV access) ──────────┼── all three fully   │
                                   │   independent of     │
                                   │   each other and T1  │
                                   ▼                      ▼
                            PR-3 (Tiers 2-3)  <───────────┘ (soft: sequence after
                                   │                          PR-1 to avoid both PRs
                                   ▼                          touching fpv.sqf's tier-
                            PR-4 (FOB shop, both sides)       lookup chain at once)
                                   │  (hard dep: needs PR-1's flag/GUER-gate +
                                   │   PR-3's Tier 2-3 constants + EASA table)
                                   ▼
                            PR-5 (Tier 4 / MQ-9)
                                   │  (hard dep: PR-2a's Level 2 must exist;
                                   │   PR-4's shop must exist to sell it from)
                                   ▼
                            PR-6 (contract tests + mirror-parity) — rides alongside
                            each feature PR, or sweeps remainder last.
```

PR-1, PR-2a, and PR-2b have **zero dependencies on each other** and can all start immediately, in any order, potentially in parallel by separate lanes. PR-3 has no *hard* dependency on PR-1 but should sequence after it to avoid two PRs editing `fpv.sqf`/`Support_FPV.sqf`'s tier-threading logic simultaneously. PR-4 and PR-5 are genuinely blocked as shown.

## 8. PR partitioning (all draft-only, `gh pr create --draft --base master`, per repo policy)

1. **PR-1** — Tier 1 rework: GUER-only + FOB purchase. `WFBE_C_DRONE_TIERS` + `WFBE_C_DRONE_FOB_RANGE` only. Wraps the WEST/EAST Tactical row; adds the GUER FOB-proximity gate (client hint + server authority) to `GuerDrones.sqf`. No UAV L2, no EASA table, no Tiers 2-4, no WEST/EAST shop.
2. **PR-2a** — UAV upgrade Level 2. New `WFBE_C_UAV_LEVEL2` flag; five-array promotion on the verified-live side files only (`Upgrades_CO_US.sqf`, `Upgrades_CO_RU.sqf`, `Upgrades_CDF.sqf`, `Upgrades_INS.sqf` — re-verify the CombinedOps branch at implementation time); reactive one-shot AI-commander research append. Gates Tier 4 only, nothing yet.
3. **PR-2b** — Open standard UAV/UAV_Destroy/UAV_Remote_Control rows to GUER. New `WFBE_C_GUER_UAV_ACCESS` flag; `Pchela1T` classname on `Root_GUE.sqf`; GUER upgrade-gate bypass (mirrors `GUI_Menu_BuyUnits.sqf:507`'s precedent); GUER CC-bypass on `Support_UAV.sqf` (mirrors `fpv.sqf`'s existing pattern).
4. **PR-3** — Tiers 2-3 platform + EASA price table. `WFBE_C_DRONE_TIER{2,3}*` constants; `WFBE_EASA_DRONE_TIERS` marker-block insert; tier-lookup threaded through `fpv.sqf`/`Support_FPV.sqf`/`Support_FPV_Detonate.sqf`. **Blocked on external confirmation of `Bo_FAB_250` before merge.**
5. **PR-4** — FOB-scoped Drone Shop (WEST/EAST) + GUER shop wiring for Tiers 2-4. New `droneShopInRange` FSM boolean, new `RequestDroneTier` PVF + `Server/PVFunctions/RequestDroneTier.sqf`, new `Client/GUI/GUI_Menu_DroneShop.sqf`, `GuerDrones.sqf` extension for Tiers 2-4. Depends on PR-1 and PR-3; Tier-4 rows added but stay inert without PR-5. **Before starting: re-check open PR #1641 ("factory/purchase PV authority — FOB envelope") — it touches `RequestFOBStructure.sqf` directly; confirm it's merged or diff against its branch before relying on the GUER FOB ledger's exact shape.**
6. **PR-5** — Tier 4 GBU strike drone. `WFBE_C_DRONE_TIER4*` + `WFBE_C_UAV_ARMED*` constants (reusing SPEC-MQ9 names), arming block in `uav.sqf`, weapon-select default fix, wired as the shop's Tier-4 row. Depends on PR-2a and PR-4. **Re-verify native MQ-9 config-truth before coding starts, not just before merge.**
7. **PR-6** — Contract tests (behavior/shape assertions, not literal-text pins — following `test_fpv_purchase_authority.py`'s established style) + mirror-parity checks not already folded into PR-1/3/5. Can ride alongside each feature PR or sweep last.

## 9. Risks

| Risk | Detail | Mitigation |
|---|---|---|
| Base-branch rot (`fable/fpv-strike-drone`) | 2,719 commits behind; a trial merge produces real conflicts on 5 of 12 unique files, and the branch's whole purchase-authority model was superseded 5 days after it was written | Do not merge/rebase it at all (§3.4); build fresh against current master, reusing only the two specifically-flagged patterns |
| Open PR #1641 (`fix(buyunit): factory/purchase PV authority — FOB envelope...`) | OPEN/draft, touches `Server/PVFunctions/RequestFOBStructure.sqf` directly (PLANNER-VERIFIED, `gh pr diff 1641 --name-only`) — the exact file whose `WFBE_GUER_FOB_ACTIVE` ledger this whole plan's GUER-FOB gate depends on | This plan only *reads* the ledger, doesn't edit that file, so direct conflict risk is low — but re-check #1641's status/diff before PR-4 lands, since it could change the ledger's shape |
| Round-end lifecycle PRs #2231 (`Support_FPV.sqf` watchdog → stop after round end) and #2202 (`uav_spotter.sqf` round-end guard) | Both OPEN/draft (PLANNER-VERIFIED), touch files this plan also edits | Sequence PR-3/PR-1 to rebase on these once merged, or coordinate; small, self-contained diffs, low actual conflict surface |
| Two closed, abandoned PRs (#1148, #1149) already tried "UAV upgrade Level 2 + FOB" under different flag names (`WFBE_C_UAV2_FOB`/`_SWARM`) | Confirmed CLOSED via `gh pr view` this pass; #1148's body confirms it flag-gated the exact same array-promotion this plan also flag-gates (independent precedent for §2's design choice) | Do not resurrect the old flag names or the AI-swarm scope (out of scope per ruling 2's manual/driver-fire-only framing); reuse only the judgment that the promotion itself should be flag-gated |
| `FOBCAMPPROBE` self-check warning in `RequestForwardFOB.sqf:187` | The entire WEST/EAST FOB-shop design depends on `nearEntities [WFBE_Logic_Camp, r]` reliably finding the runtime tent on every client; the code itself contains a "keep the flag at 0 until redesigned" warning for exactly this failure mode | Confirm via live RPT (rpt-triage skill) this warning has never fired before investing in the FSM approach — likely fine given `WFBE_C_STRUCTURES_FOB` has defaulted to 1 in production with no recorded "gear resupply broken" complaint, but not yet independently confirmed |
| `Bo_FAB_250` external config-proof gap | Only in-repo-comment corroboration exists; no line-numbered external `CfgAmmo` dump citation the way `Bo_GBU12_LGB` has | Hard blocker before PR-3 merges, not before it starts — resolvable via the `a2oa-verify-command` skill |
| Native MQ-9 turret/weapon config-truth (T4) | Entirely INFERRED from an external reference dump this pass couldn't access | Re-verify before PR-5 starts coding, not just before merge — the whole phase's feasibility rests on it |
| Interim WEST/EAST capability gap | Flipping `WFBE_C_DRONE_TIERS` to 1 after PR-1 alone removes WEST/EAST's FPV access with nothing yet to replace it until PR-4 | Owner sequencing choice, not an engineering defect — call it out explicitly before the flag is ever flipped on a live server |
| Which `Upgrades_<SIDE>.sqf` file is live | Re-confirmed this pass for the *current* build (`Upgrades_CO_US.sqf`/`Upgrades_CO_RU.sqf` live under `COMBINEDOPS=1`), but this is a fact about today's `version.sqf.template`, not a permanent guarantee | Re-verify the branch condition at PR-2a implementation time, per the spec's own caution |

## 10. Open owner decisions (genuinely unresolvable — designer/product judgment, not code archaeology)

1. **Tier 1 GUER-exclusivity, final form**: does WEST/EAST lose the Tactical-Center FPV row *entirely* under the master flag (recommended — matches the literal "GUER-ONLY" ruling language), or should they get their own FOB-gated version of Tier 1 too, routed through PR-4's shop instead of retired?
2. **GUER's Tiers 1-4 shop UI shape**: extend the existing `GuerDrones.sqf` dialog (recommended — lowest engineering cost, matches existing precedent) vs. extend the Depot/`BuyUnits` roster with a FOB-liveness gate vs. a hybrid. Ruling 4 explicitly grants designer latitude here.
3. **Does "open standard UAV rows to GUER" need the new FOB gate, or should it parity-match WEST/EAST's existing Command-Center-only gate (no FOB)?** Recommended: no FOB gate, parity only — but this rests on reading the ruling's FOB clause as scoped to "Munitions" specifically, which is an inference, not a verbatim statement.
4. **GUER's plain-UAV airframe classname**: `Pchela1T` (recommended — proven, and structurally excludes accidental Tier-4 eligibility) vs. a bespoke GUER-flavored hull.
5. **Tier 4 armament scope**: Hellfire + GBU-12 only (recommended, per SPEC-MQ9's own default) vs. also injecting Maverick — pure balance/flavor call, zero config-truth implication either way.
6. **Tier 3 / Tier 4 warhead overlap**: both currently spec'd to share `Bo_GBU12_LGB`, differentiated only by delivery mechanic (single-shot kamikaze vs. reusable multi-shot sortie) — keep shared (recommended, zero extra classname risk) vs. give Tier 3 a visually distinct warhead (e.g. a heavier `Bo_FAB_250` multiplier).
7. **Mid-flight drone behavior when its selling FOB is destroyed**: fly on unaffected (recommended — matches the existing FPV watchdog's philosophy that a flying drone's lifecycle is never tied to an external structure) vs. scuttle immediately.
