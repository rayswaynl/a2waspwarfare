"""Regression coverage for the scheduled mobile-artillery GetIn waiter."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
HANDLERS = (
    ROOT
    / "Missions"
    / "[55-2hc]warfarev2_073v48co.chernarus"
    / "Common"
    / "Functions"
    / "Common_HandleArty.sqf",
    ROOT
    / "Missions_Vanilla"
    / "[61-2hc]warfarev2_073v48co.takistan"
    / "Common"
    / "Functions"
    / "Common_HandleArty.sqf",
    ROOT
    / "Missions_Vanilla"
    / "[61-2hc]warfarev2_073v48co.zargabad"
    / "Common"
    / "Functions"
    / "Common_HandleArty.sqf",
)


class HandleArtyWaitYieldTests(unittest.TestCase):
    def test_waiter_suspends_between_vehicle_state_polls(self) -> None:
        for handler in HANDLERS:
            source = handler.read_text(encoding="utf-8-sig")
            wait_start = source.lower().index("waituntil")
            body_start = source.index("{", wait_start)
            self.assertTrue(
                source[body_start + 1 :].lstrip().startswith("sleep 0.05;"),
                f"{handler} must yield before rechecking the long-lived GetIn waiter",
            )


if __name__ == "__main__":
    unittest.main()
