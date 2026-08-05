"""Regression contract for SCUD worker teardown at round end."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)

SCUD = Path("Server/Support/Support_ScudStrike.sqf")
ROUND_END_GUARD = "if (gameOver || {WFBE_GameOver}) exitWith {"
LOOP_ROUND_END_GUARD = "if (gameOver || {WFBE_GameOver}) exitWith {};"
SAFE_CLEANUP = "Spawn WFBE_CO_FNC_SafeCrewDelete"


class ScudRoundEndGuardTests(unittest.TestCase):
    def test_worker_cancels_before_scan_and_each_barrage_phase(self) -> None:
        for mission in MISSIONS:
            source = (mission / SCUD).read_text(encoding="utf-8-sig")
            worker_start = source.index("_travelTime = _this select 8;")
            travel_sleep = source.index("sleep _travelTime;", worker_start)
            first_guard = source.index(ROUND_END_GUARD, travel_sleep)
            first_scan = source.index("_armour = [];", worker_start)

            self.assertLess(travel_sleep, first_guard, mission.name)
            self.assertLess(first_guard, first_scan, mission.name)
            self.assertGreaterEqual(
                source[worker_start:].count(ROUND_END_GUARD),
                4,
                mission.name,
            )
            self.assertGreaterEqual(
                source[worker_start:].count(LOOP_ROUND_END_GUARD),
                3,
                mission.name,
            )
            self.assertGreaterEqual(
                source[worker_start:].count(SAFE_CLEANUP),
                4,
                mission.name,
            )


if __name__ == "__main__":
    unittest.main()
