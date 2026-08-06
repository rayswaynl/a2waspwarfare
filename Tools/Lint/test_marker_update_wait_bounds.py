import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MIRRORS = (
    ROOT
    / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Common_MarkerUpdate.sqf",
    ROOT
    / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Common_MarkerUpdate.sqf",
    ROOT
    / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Common/Common_MarkerUpdate.sqf",
)


class MarkerUpdateWaitBoundTests(unittest.TestCase):
    def test_all_maintained_mirrors_match(self):
        texts = [path.read_text(encoding="utf-8") for path in MIRRORS]
        self.assertEqual(len(set(texts)), 1)

    def test_common_init_gate_is_bounded_and_fail_closed(self):
        text = MIRRORS[0].read_text(encoding="utf-8")
        self.assertNotIn("waitUntil {commonInitComplete};", text)
        self.assertIn("_markerInitDeadline = diag_tickTime + 90;", text)
        self.assertIn("uiSleep 0.25", text)
        self.assertIn(
            'if (isNil "commonInitComplete" || {!commonInitComplete}) exitWith {',
            text,
        )
        self.assertIn(
            "HANGGUARD| Common_MarkerUpdate.sqf: common initialization was not complete",
            text,
        )


if __name__ == "__main__":
    unittest.main()
