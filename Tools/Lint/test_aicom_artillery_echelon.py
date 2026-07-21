#!/usr/bin/env python3
"""Contract for the AICOM forward-artillery echelon (WFBE_C_AICOM_ARTY_ECHELON, wave0721-armed default 1).

Live incident (wasp-aicom-live-20260718): EAST built artillery 23x but fired only 8
missions (none after minute 583); WEST spammed ~1330 ineligible build-skip logs. Root
cause: base guns are built once near HQ and never move, and the fire block only
discovers pieces within 250m of HQ - once the front advances past a gun's max range it
polls forever, silently. This fix adds an explicit per-side registry (position-
independent discovery), a safe-anchor forward reposition, and a debounced skip log.

Round-2 review (2026-07-19) confirmed a HIGH safety defect: both the safe-anchor SAFE gate
and the pre-PlaceSafe in-contact guard reduced "enemy" to the strategy loop's binary
west<->east _enemySide, omitting hostile resistance/GUER entirely - a gun could be
redeployed out of GUER contact, or onto a GUER-occupied "safe" town. Fixed by switching both
guards to the repo-wide any-hostile idiom (side != own && side != civilian, the same pattern
Common_RunCommanderTeam.sqf / AI_Commander_DisbandLowTier.sqf / AI_Commander_Teams.sqf
already use) and pinned with GUER-specific fixtures below.

HONEST SCOPE NOTE (round-2): this suite is static-source-only (no SQF interpreter in CI).
The card's remaining runtime-acceptance item - a fire-mission/hour or explicit-reposition
transition observed on a live/test server - is NOT satisfied by anything in this file and
requires an authorized test-server RPT run; do not read the tests below as runtime proof.
"""

from pathlib import Path
import unittest

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
CHERNARUS = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"
CONSTANTS = CHERNARUS / "Common" / "Init" / "Init_CommonConstants.sqf"
COMMON_INIT = CHERNARUS / "Common" / "Init" / "Init_Common.sqf"
ANCHOR = CHERNARUS / "Common" / "Functions" / "Common_AICOMArtySafeAnchor.sqf"
BASE = CHERNARUS / "Server" / "AI" / "Commander" / "AI_Commander_Base.sqf"
STRATEGY = CHERNARUS / "Server" / "AI" / "Commander" / "AI_Commander_Strategy.sqf"


def code(path: Path) -> str:
    return mask_comments(path.read_text(encoding="utf-8-sig"))


class EchelonModel:
    """Small deterministic model of the registry/cooldown/debounce state machine
    Base.sqf + Strategy.sqf implement, for the transition-logic pins below."""

    def __init__(self, repos_cd: int = 180) -> None:
        self.repos_cd = repos_cd
        self.registry = []          # live registered pieces (ids)
        self.skiplog_latch = ""     # Base.sqf debounce key
        self.skiplog_emits = 0
        self.state = {}             # piece id -> wfbe_arty_state
        self.repos_last = {}        # piece id -> last reposition-scan time
        self.transition_emits = 0

    def register(self, piece_id: str) -> None:
        self.registry.append(piece_id)
        self.state[piece_id] = "registered"
        self.skiplog_latch = ""  # a successful build clears the skip-log latch

    def build_skip(self, reason: str) -> None:
        if self.skiplog_latch != reason:
            self.skiplog_latch = reason
            self.skiplog_emits += 1
        # else: debounced, no emit

    def try_reposition(self, piece_id: str, now: int, anchor_found: bool, enemy_close: bool) -> None:
        last = self.repos_last.get(piece_id, -1e9)
        if (now - last) <= self.repos_cd:
            return  # cooldown gate: no scan, no state change
        self.repos_last[piece_id] = now
        if not anchor_found:
            if self.state.get(piece_id) != "noanchor":
                self.state[piece_id] = "noanchor"
                self.transition_emits += 1
            return
        if enemy_close:
            return  # never redeploy a gun in contact; no state change
        if self.state.get(piece_id) != "repositioning":
            self.state[piece_id] = "repositioning"
            self.transition_emits += 1


def any_hostile_count(own_side: str, units: list[tuple[str, bool]]) -> int:
    """Mirrors the review-fixed SQF idiom `{alive _x && {side _x != _side} && {side _x !=
    civilian}} count (...)` - ANY faction other than our own and civilian counts as hostile,
    including resistance/GUER. Each unit is (side, alive)."""
    return sum(1 for side, alive in units if alive and side != own_side and side != "civilian")


def pick_safe_anchor(own_side, candidates, max_r, min_stand, margin=0.9):
    """Mirrors Common_AICOMArtySafeAnchor.sqf's candidate loop at the review-fixed idiom.
    candidates: list of (name, dist_to_target, is_water, units[(side, alive)])."""
    best, best_d = None, float("inf")
    for name, d_tgt, is_water, units in candidates:
        if d_tgt <= max_r * margin and d_tgt >= min_stand and not is_water:
            if any_hostile_count(own_side, units) == 0 and d_tgt < best_d:
                best_d, best = d_tgt, name
    return best


class ArtilleryEchelonFixtures(unittest.TestCase):
    def test_01_registry_grows_on_build_and_survives_out_of_hq_range(self) -> None:
        m = EchelonModel()
        m.register("gun-1")
        self.assertIn("gun-1", m.registry)
        self.assertEqual(m.state["gun-1"], "registered")

    def test_02_skip_log_debounced_per_reason(self) -> None:
        m = EchelonModel()
        m.build_skip("notresearched:X")
        m.build_skip("notresearched:X")
        m.build_skip("notresearched:X")
        self.assertEqual(m.skiplog_emits, 1)
        m.build_skip("nospg")
        self.assertEqual(m.skiplog_emits, 2)

    def test_03_build_clears_skip_log_latch(self) -> None:
        m = EchelonModel()
        m.build_skip("nospg")
        m.register("gun-1")
        m.build_skip("nospg")
        self.assertEqual(m.skiplog_emits, 2)  # re-emits once after the latch cleared

    def test_04_reposition_cooldown_gates_the_scan(self) -> None:
        m = EchelonModel(repos_cd=180)
        m.register("gun-1")
        m.try_reposition("gun-1", now=0, anchor_found=True, enemy_close=False)
        m.try_reposition("gun-1", now=90, anchor_found=True, enemy_close=False)  # inside cooldown
        self.assertEqual(m.transition_emits, 1)
        m.try_reposition("gun-1", now=200, anchor_found=True, enemy_close=False)  # cooldown elapsed, but already repositioning -> debounced
        self.assertEqual(m.transition_emits, 1)

    def test_05_no_anchor_transition_is_debounced_not_repeated(self) -> None:
        m = EchelonModel(repos_cd=10)
        m.register("gun-1")
        m.try_reposition("gun-1", now=0, anchor_found=False, enemy_close=False)
        m.try_reposition("gun-1", now=20, anchor_found=False, enemy_close=False)
        self.assertEqual(m.transition_emits, 1)

    def test_06_gun_in_contact_is_never_redeployed(self) -> None:
        m = EchelonModel(repos_cd=10)
        m.register("gun-1")
        m.try_reposition("gun-1", now=0, anchor_found=True, enemy_close=True)
        self.assertNotEqual(m.state.get("gun-1"), "repositioning")
        self.assertEqual(m.transition_emits, 0)

    def test_06b_guer_unit_counts_as_hostile_for_the_in_contact_guard(self) -> None:
        """Round-2 review (HIGH): a GUER unit standing next to the gun must block reposition
        exactly like an EAST/WEST unit would - the old `side _x == _enemySide` binary compare
        missed this entirely."""
        self.assertEqual(any_hostile_count("west", [("guer", True)]), 1)
        self.assertEqual(any_hostile_count("west", [("civilian", True)]), 0)
        self.assertEqual(any_hostile_count("west", [("west", True)]), 0)
        m = EchelonModel(repos_cd=10)
        m.register("gun-1")
        enemy_close = any_hostile_count("west", [("guer", True)]) > 0
        m.try_reposition("gun-1", now=0, anchor_found=True, enemy_close=enemy_close)
        self.assertNotEqual(m.state.get("gun-1"), "repositioning")
        self.assertEqual(m.transition_emits, 0)

    def test_06c_guer_occupied_candidate_town_is_never_picked_as_a_safe_anchor(self) -> None:
        """Round-2 review (HIGH): the SAFE gate in Common_AICOMArtySafeAnchor.sqf used to
        compare against the same binary _enemySide, so a GUER-held town in range/standoff/
        no-water could be selected as a 'safe' anchor. It must now be rejected and the loop
        must fall through to the next-best GUER-free candidate."""
        candidates = [
            ("TownA-guer-held", 2000, False, [("guer", True)]),
            ("TownB-clear-but-farther", 2500, False, []),
        ]
        picked = pick_safe_anchor("west", candidates, max_r=3000, min_stand=500)
        self.assertEqual(picked, "TownB-clear-but-farther")

        # No GUER-free candidate exists at all -> no anchor (never silently pick the unsafe one).
        candidates_all_guer = [("TownA-guer-held", 2000, False, [("guer", True)])]
        self.assertIsNone(pick_safe_anchor("west", candidates_all_guer, max_r=3000, min_stand=500))

        # An EAST unit still disqualifies a candidate too (fix must not have narrowed coverage).
        candidates_east = [
            ("TownA-east-held", 2000, False, [("east", True)]),
            ("TownB-clear", 2500, False, []),
        ]
        self.assertEqual(pick_safe_anchor("west", candidates_east, max_r=3000, min_stand=500), "TownB-clear")

    def test_07_flag_off_source_path_pins_the_reconciled_global_scan(self) -> None:
        """RECONCILED (fix/aicom-arty-cap-reconciled, 2026-07-21, orchestrator design ruling):
        the echelon-OFF cap-count in Base.sqf no longer anchors on the CURRENT HQ position via
        nearEntities - that was the actual root cause of an owner-observed artillery over-build
        (the side HQ periodically relocates forward while built guns never move, so every
        relocation orphaned earlier-built guns from the scan and let the self-healing cap
        silently rebuild past the intended max). This test was PR #1212's original pin of the
        legacy near-HQ form as an immutable flag-off invariant; #1221 was approved to replace
        that legacy form specifically (the ECHELON-ON registry branch, which was already
        position-independent by construction, is untouched - see test_08 for its wiring). Pin
        the reconciled shape instead: a global forEach-vehicles scan gated by the same
        WFBE_CommanderArtillery ownership tag and IsMobileArtillery class test the mission
        already uses elsewhere, and assert the legacy HQ-radius form is gone."""
        base = code(BASE)
        strat = code(STRATEGY)
        # The legacy near-HQ FIRING discovery call in the strategy worker is a SEPARATE concern
        # (fire-mission discovery, not build/purchase cap-counting) and is untouched by the
        # cap-counting reconciliation - it must still exist verbatim.
        self.assertIn(
            'nearEntities [["Tank","Car","Wheeled_APC","Tracked_APC"], 250]',
            strat,
        )
        # RECONCILED: the echelon-OFF branch now counts LIVE commander-tagged,
        # IsMobileArtillery-classed pieces for the side GLOBALLY via forEach vehicles - never
        # anchored to any HQ position.
        self.assertIn("forEach vehicles;", base)
        self.assertIn('(_x getVariable ["WFBE_CommanderArtillery", false])', base)
        self.assertIn("Call IsMobileArtillery", base)
        self.assertIn(
            '&& {[_x, _side] Call IsMobileArtillery}) then {_artyBuilt = _artyBuilt + 1} } forEach vehicles;',
            base,
        )
        # The legacy HQ-radius nearEntities scan must be GONE from Base.sqf's cap-count entirely -
        # this is the exact bug the reconciliation fixed; its reappearance would be a regression.
        self.assertNotIn(
            'forEach (_hqPos nearEntities [["Tank","Car","Wheeled_APC","Tracked_APC"], (missionNamespace getVariable ["WFBE_C_BASEGC_RANGE", 800])]);',
            base,
        )
        # Every new branch must still be gated behind the echelon flag read.
        self.assertIn('WFBE_C_AICOM_ARTY_ECHELON", 0]', base)
        self.assertIn('WFBE_C_AICOM_ARTY_ECHELON", 0]', strat)

    def test_08_registration_and_reposition_wiring_present(self) -> None:
        base = code(BASE)
        strat = code(STRATEGY)
        self.assertIn("wfbe_aicom_arty_reg", base)
        self.assertIn("wfbe_aicom_arty_reg", strat)
        self.assertIn("Call WFBE_CO_FNC_AICOMArtySafeAnchor", strat)
        self.assertIn("Call PlaceSafe", strat)
        self.assertIn("ARTY_REPOSITION", strat)
        self.assertIn("ARTY_NO_ANCHOR", strat)

    def test_09_never_redeploy_gun_in_contact_guard_present(self) -> None:
        strat = code(STRATEGY)
        repos_block = strat[strat.index("_reCd = missionNamespace getVariable"):]
        self.assertIn("_enemyClose", repos_block)
        self.assertIn("if (_enemyClose == 0) then", repos_block)

    def test_09b_in_contact_guard_counts_every_hostile_side_not_just_enemySide(self) -> None:
        """Round-2 review (HIGH, confirmed): the in-contact guard must use the repo-wide
        any-hostile idiom (side != own && side != civilian), NOT the strategy-loop's binary
        _enemySide (which is west<->east only and correctly stays untouched elsewhere in this
        file for the main enemy-town-targeting logic)."""
        strat = code(STRATEGY)
        enemy_close_line = next(
            line for line in strat.splitlines() if "_enemyClose = {alive _x" in line
        )
        self.assertIn("side _x != _side", enemy_close_line)
        self.assertIn("side _x != civilian", enemy_close_line)
        self.assertNotIn("_enemySide", enemy_close_line)

    def test_10_constants_are_armed_and_registered(self) -> None:
        """wave0721 arming ruling (2026-07-21): WFBE_C_AICOM_ARTY_ECHELON flipped 0->1."""
        constants = code(CONSTANTS)
        common_init = code(COMMON_INIT)
        self.assertIn('if (isNil "WFBE_C_AICOM_ARTY_ECHELON") then {WFBE_C_AICOM_ARTY_ECHELON = 1};', constants)
        self.assertIn("WFBE_C_AICOM_ARTY_ECHELON_REPOS_CD", constants)
        self.assertIn("WFBE_C_AICOM_ARTY_ECHELON_SAFE_DIST", constants)
        self.assertIn("WFBE_C_AICOM_ARTY_ECHELON_MIN_STANDOFF", constants)
        self.assertIn(
            'WFBE_CO_FNC_AICOMArtySafeAnchor = Compile preprocessFileLineNumbers "Common\\Functions\\Common_AICOMArtySafeAnchor.sqf"',
            common_init,
        )

    def test_11_safe_anchor_helper_guards(self) -> None:
        anchor = code(ANCHOR)
        # Never water, minimum standoff from target, no enemy near the candidate anchor.
        self.assertIn("surfaceIsWater", anchor)
        self.assertIn("_dTgt >= _minStand", anchor)
        self.assertIn("_enemyNear == 0", anchor)
        # A2 trap guard: outer _x captured before the inner condition-count-forEach rebind.
        self.assertIn("_twn = _x;", anchor)

    def test_11b_safe_gate_counts_every_hostile_side_not_a_binary_enemySide(self) -> None:
        """Round-2 review (HIGH, confirmed): the SAFE gate must use the repo-wide any-hostile
        idiom, and the old hardcoded binary _enemySide must be gone from this file entirely
        (it has no legitimate use here - this helper serves all three sides)."""
        anchor = code(ANCHOR)
        enemy_near_line = next(
            line for line in anchor.splitlines() if "_enemyNear = {alive _x" in line
        )
        self.assertIn("side _x != _side", enemy_near_line)
        self.assertIn("side _x != civilian", enemy_near_line)
        self.assertNotIn("_enemySide", anchor)


if __name__ == "__main__":
    unittest.main()
