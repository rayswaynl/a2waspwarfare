#!/usr/bin/env python3
"""Regression contracts for the default-off AICOM research-gap tail."""

from pathlib import Path
import unittest

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
MISSION_PATHS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)


def source(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig")


class ResearchGapTailContract(unittest.TestCase):
    def test_maintained_mirrors_are_identical_and_guarded(self) -> None:
        paths = tuple(path / "Common" / "Config" / "Core_Upgrades" / "Check_Upgrades.sqf" for path in MISSION_PATHS)
        contents = tuple(source(path) for path in paths)
        self.assertEqual(contents[1:], contents[:1] * 2)

        code = mask_comments(contents[0])
        self.assertIn('"_researchGapFix"', code)
        self.assertIn('_researchGapFix = (missionNamespace getVariable ["WFBE_C_AICOM_RESEARCH_GAP_FIX", 0]) > 0;', code)
        self.assertIn('if (_researchGapFix || {!(_i in [WFBE_UP_UNITCOST, WFBE_UP_AMMOCOIN])}) then {', code)
        self.assertEqual(code.count('[_add, [_i, _j]] Call WFBE_CO_FNC_ArrayPush;'), 1)

    def test_research_gap_is_opt_in_in_both_co_orders(self) -> None:
        for side in ("RU", "US"):
            path = MISSION_PATHS[0] / "Common" / "Config" / "Core_Upgrades" / f"Upgrades_CO_{side}.sqf"
            code = source(path)
            self.assertIn('if ((missionNamespace getVariable ["WFBE_C_AICOM_RESEARCH_GAP_FIX", 0]) > 0) then {', code)
            self.assertIn('_aiOrder set [count _aiOrder, [WFBE_UP_UNITCOST,1]];', code)
            self.assertIn('_aiOrder set [count _aiOrder, [WFBE_UP_UNITCOST,2]];', code)
            self.assertIn('_aiOrder set [count _aiOrder, [WFBE_UP_AMMOCOIN,1]];', code)


if __name__ == "__main__":
    unittest.main()
