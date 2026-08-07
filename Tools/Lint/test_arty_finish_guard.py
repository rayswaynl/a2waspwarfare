#!/usr/bin/env python3
"""Static contract for fail-clean mobile-artillery teardown.

Common_FireArtillery.sqf calls ARTY_Finish after the gunner-death branch while
the hull may still exist without a live gunner.  The helper must therefore
guard both the hull and the gunner before issuing engine commands or lookAt.
"""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]

FINISH_FILES = (
    ROOT
    / "Missions"
    / "[55-2hc]warfarev2_073v48co.chernarus"
    / "Common"
    / "Module"
    / "Arty"
    / "ARTY_mobileMissionFinish.sqf",
    ROOT
    / "Missions_Vanilla"
    / "[61-2hc]warfarev2_073v48co.takistan"
    / "Common"
    / "Module"
    / "Arty"
    / "ARTY_mobileMissionFinish.sqf",
    ROOT
    / "Missions_Vanilla"
    / "[61-2hc]warfarev2_073v48co.zargabad"
    / "Common"
    / "Module"
    / "Arty"
    / "ARTY_mobileMissionFinish.sqf",
)


class ArtyFinishGuardTests(unittest.TestCase):
    def test_finish_skips_invalid_hull_and_missing_gunner(self) -> None:
        for path in FINISH_FILES:
            source = path.read_text(encoding="utf-8-sig")
            with self.subTest(path=path):
                self.assertIn(
                    "if (isNull _vehicle || {!alive _vehicle}) exitWith {};",
                    source,
                )
                self.assertIn("_gunner = gunner _vehicle;", source)
                self.assertIn(
                    "if (!isNull _gunner && {alive _gunner}) then {",
                    source,
                )
                self.assertNotIn("(gunner _vehicle) lookAt _lookPos;", source)


if __name__ == "__main__":
    unittest.main()
