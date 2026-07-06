
## 2026-07-06 ~evening — LIVE INCIDENT: defenses unbuildable (cc46)
Owner report: "not allowing me to build any defenses/fortifications" — red ghost everywhere in base, no visible hint. Root cause (traced + verified):
1. Client `WFBE_C_STRUCTURES_PLACEMENT_METHOD` (Init_Client.sqf ~1287/1302): StaticWeapon force-green runs BEFORE the enemy-in-base red block (any 1 enemy within WFBE_C_BASE_AREA_RANGE=250m of base ⇒ all defense previews red) — ordering bug; hint renders top-right, easily missed.
2. Server RequestDefense gates (threat >=3 enemies, budget caps) armed FOR THE FIRST TIME in B89 by the wfbe_startpos fix (v88: `isNull objNull-default-array` bug made _isInsideBase always false ⇒ gates dead).
Net effect: under enemy pressure (WEST base pressed this round) defense building locks exactly when needed. AI commander defense path unaffected (confirmed in live RPT: "[WEST] placed base defense 4/4").
Ruled out: STRUCTURES_FLAT_CHECK (0 in live PBO, byte-verified), TOWNS_BUILD_PROTECTION_RANGE 100->450 (#764) is dead data (no consumer), avail budget (260, overwritten green for cat-2 anyway), TeamV2 parse error (dialog-local).
Hotfix in flight: branch fable/hotfix-defense-gates — (a) correctness reorder StaticWeapon override after enemy block, (b) flag WFBE_C_DEFENSE_CLIENT_GATE_ALIGN (default 0) aligning client gate to WFBE_C_DEFENSE_THREAT_MIN=3 to mirror server. Target: cc48.
Workaround told to owner: clear enemies within 250m of HQ or build >250m out.
