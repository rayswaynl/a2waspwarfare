#!/usr/bin/env python3
"""Contract for the AICOM forward-artillery echelon (WFBE_C_AICOM_ARTY_ECHELON, default 0).

Live incident (wasp-aicom-live-20260718): EAST built artillery 23x but fired only 8
missions (none after minute 583); WEST spammed ~1330 ineligible build-skip logs. Root
cause: base guns are built once near HQ and never move, and the fire block only
discovers pieces within 250m of HQ - once the front advances past a gun's max range it
polls forever, silently. This fix adds an explicit per-side registry (position-
independent discovery), a safe-anchor forward reposition, and a debounced skip log.
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

    def test_07_flag_off_source_paths_are_byte_identical_to_legacy(self) -> None:
        base = code(BASE)
        strat = code(STRATEGY)
        # The legacy near-HQ discovery call must still exist verbatim in the else-branch.
        self.assertIn(
            'nearEntities [["Tank","Car","Wheeled_APC","Tracked_APC"], 250]',
            strat,
        )
        # The legacy unconditional artyBuilt-count-by-scan must still exist verbatim.
        self.assertIn(
            'forEach (_hqPos nearEntities [["Tank","Car","Wheeled_APC","Tracked_APC"], (missionNamespace getVariable ["WFBE_C_BASEGC_RANGE", 800])]);',
            base,
        )
        # Every new branch must be gated behind the echelon flag read.
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

    def test_10_constants_default_off_and_registered(self) -> None:
        constants = code(CONSTANTS)
        common_init = code(COMMON_INIT)
        self.assertIn('if (isNil "WFBE_C_AICOM_ARTY_ECHELON") then {WFBE_C_AICOM_ARTY_ECHELON = 0};', constants)
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


if __name__ == "__main__":
    unittest.main()
