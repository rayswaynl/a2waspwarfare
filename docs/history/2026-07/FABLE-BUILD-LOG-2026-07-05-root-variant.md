
## 2026-07-06 ~evening — LIVE INCIDENT: defenses unbuildable (cc46)
Owner report: "not allowing me to build any defenses/fortifications" — red ghost everywhere in base, no visible hint. Root cause (traced + verified):
1. Client `WFBE_C_STRUCTURES_PLACEMENT_METHOD` (Init_Client.sqf ~1287/1302): StaticWeapon force-green runs BEFORE the enemy-in-base red block (any 1 enemy within WFBE_C_BASE_AREA_RANGE=250m of base ⇒ all defense previews red) — ordering bug; hint renders top-right, easily missed.
2. Server RequestDefense gates (threat >=3 enemies, budget caps) armed FOR THE FIRST TIME in B89 by the wfbe_startpos fix (v88: `isNull objNull-default-array` bug made _isInsideBase always false ⇒ gates dead).
Net effect: under enemy pressure (WEST base pressed this round) defense building locks exactly when needed. AI commander defense path unaffected (confirmed in live RPT: "[WEST] placed base defense 4/4").
Ruled out: STRUCTURES_FLAT_CHECK (0 in live PBO, byte-verified), TOWNS_BUILD_PROTECTION_RANGE 100->450 (#764) is dead data (no consumer), avail budget (260, overwritten green for cat-2 anyway), TeamV2 parse error (dialog-local).
Hotfix in flight: branch fable/hotfix-defense-gates — (a) correctness reorder StaticWeapon override after enemy block, (b) flag WFBE_C_DEFENSE_CLIENT_GATE_ALIGN (default 0) aligning client gate to WFBE_C_DEFENSE_THREAT_MIN=3 to mirror server. Target: cc48.
Workaround told to owner: clear enemies within 250m of HQ or build >250m out.

## 2026-07-06 — owner reports #2/#3: AI builds on dirt roads + teams vanish
- ROADS: TP-19 gate block has no road check (and the tree gate was DEAD on cc46 — nearestTerrainObjects A3-only, fixed in #777). Building `fable/aicom-road-clear` (flag WFBE_C_AICOM_BUILD_ROAD_CLEAR default 0, stacked on #777).
- VANISHING TEAMS: investigation CONFIRMED tier-3 recovery teleports (6 this session, whole-team setPos snap to road node). ROOT BUG: player-proximity guard comment says 300m, code implements 100m (Common_RunCommanderTeam.sqf ~1068/~1127; the ~1113 velocity-hop 100m is intentional). Also STUCK_REPAIR averted 0 teleports — tier ladder never resets after successful repair. Ruled out: group GC (0 aicom deletions), SML (12/12 clean rejoins), despawn/cache (n/a). Building `fable/hotfix-teleport-guard`: guard param WFBE_C_AICOM_RECOVERY_PLAYER_GUARD_R default 300 (correctness) + WFBE_C_AICOM_STUCK_REPAIR_RESETS_TIER (flag, default 0).
- Defense-gate hotfix #778 built; refuter running (key attack: does the StaticWeapon reorder now override the town-restriction red?).

## 2026-07-06 ~18:50 — cc48 DEPLOYED LIVE (v89-cmdcon48, master 169eb16fa)
All 11 PRs merged+verified (refuter caught real blockers on #778/#780/#774 pre-merge; all fixed+re-verified): #776 TeamV2 remount, #777 RPT trio (revives dead tree/road gates), #778 defense gates (_restricted), #779 road-clear dial (dark), #780 teleport guard 300m + repair tier reset (dark), #769 aircraft (dark), #771 garrison (dark), #772 HC CIV slots, #773 daytime (dark), #774 SML-3/4/5 (dark), #770 deploy-v2 (docs/ops).
Build: build_cc48.ps1 (fixed stale cmdcon45 prefix bug from cc47 script); 16/16 fix markers byte-verified in CH PBO. Deploy: deploy48.ps1, DONE procs=3/3 MISSINIT=4 active=ch.
#772 CIV boot test: PARTIAL — HC1 seated CIV directly (magnet works); HC2 engine-preseated EAST, one reseat -> CIV. Both final CIV. Investigate slot-order for HC2 later.
Boot errors: 2-line pre-existing wf_maxplayers undefined (MATCH telemetry Init_Server:191 — WF_MAXPLAYERS define never included; NOT a cc48 regression, dates to e6ab52ce6/cc46) -> hotfix branch fable/hotfix-match-maxplayers dispatched.
Old known error trio: FIXED (no AI_Commander_Base:244 error in cc48 boot window).
Flag menu still owed to owner for the dark set: SML-3/4/5, daytime, garrison, aircraft safety, road-clear dial, repair-tier-reset, defense client-gate align.

## 2026-07-06 ~19:50 — cc48a DEPLOYED LIVE (v89-cmdcon48a, master a3851b3dc)
Owner flag menu applied: PERMANENT_DAY=1 (via Parameters.hpp x3 — params trap respected), SML_RETREAT/AT_OVERWATCH/SURGICAL_UNSTUCK=1, GARRISON_DRESSING=1, AIR_SPAWN_SAFETY=1, AICOM_STUCK_REPAIR_RESETS_TIER=1. Kept dark: SML_DISMOUNTS (fresh fix, wants one live round of SML evidence), DEFENSE_CLIENT_GATE_ALIGN (owner), ROAD_CLEAR dial (redundant w/ primary 14m gate).
SML-2 #787 merged after refuter FAIL->fix->PASS cycle (B1 flag-flip reversion via stale branch; B2 orderGetIn-false = seated-eject NO-OP -> moveOut; honest telemetry seated_still=). maxPlayers fix #782 live (boot error GONE). V2 cutover reconciled soak-ready as PR #788 (zero conflicts, invariants verified).
Boot: PBO active, HCs CIV (HC2 one reseat again), 1 NEW live error: Server_TownGarrisonDressing.sqf:187 `disableMove` = NONEXISTENT command (not A3 — invented; lint blind spot) -> hotfix fable/hotfix-garrison-disablemove dispatched + linter addition. permDay FPSREPORT confirmation pending next window.
NEW TRAP CLASS for taxonomy: invented commands that are neither A2 nor A3 pass the A3CMD lint; only live RPT catches them. Counter: a2oa-verify-command skill on every uncertain command + grow linter list reactively (moveInAny, disableMove).

## 2026-07-06 late — 1.0 CODE GATES CLOSED
#768 content landed via fable/hunt-batch-landing (6361be7f5): ground-supply pay-out fixed (server direct call, heli path verified no-double), DR-55 guards real (top-scope exitWith; SEC_HARDENING stays 0 = owner arm decision at 1.0 build), air-def/kill-assist/rearm/nil-freeze batch. Conflict w/ #637 resolved (aicomFlushResetOrder kept in private, PR's GroupGetBool inline form kept). Lint 234->219 (net negative!). Cutover #788 re-verified: still merges clean (0 conflicts).
Blocker audit CLOSED: RCE/confused-deputy/SEND_MESSAGE injection all confirmed fixed on master. BE posture for 1.0: OFF (box has no beserver.cfg; A2 BE master server down; bridge+filters post-release). #791 airfield gate PARKED (refuter: sideID never set on airport logics - phantom signal; needs design).
1.0 remaining: soak 1 (armed, auto-fires) -> soak 2/3 -> owner DECAP call -> cutover build -> dark-flag round-2 menu (incl SEC_HARDENING arm, SML_DISMOUNTS) -> announce (draft ready, "WASP Warfare 1.0 is here").
