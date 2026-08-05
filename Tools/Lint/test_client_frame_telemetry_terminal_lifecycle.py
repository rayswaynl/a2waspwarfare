#!/usr/bin/env python3
"""Regression contract for client frame telemetry stopping after mission end."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
MISSION_DIRS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)
FRAME_TELEMETRY = Path("Client/Functions/Client_FrameTelemetry.sqf")
ENDGAME_GUARD = "if (gameOver || {WFBE_GameOver}) exitWith {};"
LOOP_START = 'while {!(missionNamespace getVariable ["WFBE_GameOver", false])} do {'
REPORT_START = "if (_lastSample >= _nextReport) then {"


class ClientFrameTelemetryTerminalLifecycleTests(unittest.TestCase):
    def test_report_worker_checks_terminal_state_after_sampling_sleep(self) -> None:
        sources = []
        for mission_dir in MISSION_DIRS:
            source = (mission_dir / FRAME_TELEMETRY).read_text(encoding="utf-8-sig")
            sources.append(source.encode("utf-8"))

            loop = source[source.index(LOOP_START) :]
            self.assertIn(ENDGAME_GUARD, loop, mission_dir.name)
            sleep_pos = loop.index("sleep _sampleInterval;")
            guard_pos = loop.index(ENDGAME_GUARD)
            report_pos = loop.index(REPORT_START)

            self.assertEqual(source.count(ENDGAME_GUARD), 1, mission_dir.name)
            self.assertLess(sleep_pos, guard_pos, mission_dir.name)
            self.assertLess(guard_pos, report_pos, mission_dir.name)

        self.assertTrue(all(source == sources[0] for source in sources[1:]))


if __name__ == "__main__":
    unittest.main()
