"""Regression tests for the server FPS publisher's terminal lifecycle."""

from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SERVER_FPS_PATHS = (
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/GUI/serverFpsGUI.sqf",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/GUI/serverFpsGUI.sqf",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/GUI/serverFpsGUI.sqf",
)


class ServerFpsGuiTerminalLifecycleTests(unittest.TestCase):
    """The telemetry publisher must not survive the round-ending signal."""

    def test_all_production_publishers_are_terminal_gated_before_publish(self) -> None:
        for path in SERVER_FPS_PATHS:
            with self.subTest(path=path):
                source = path.read_text(encoding="utf-8")

                loop = "while {!gameOver} do"
                publish = 'SERVER_FPS_GUI = round(diag_fps);'
                terminal_publish_guard = "if (_hasHuman && {!gameOver}) then {"

                self.assertEqual(source.count(loop), 1)
                self.assertEqual(source.count(publish), 1)
                self.assertEqual(source.count(terminal_publish_guard), 1)
                self.assertLess(source.index(loop), source.index(publish))
                self.assertLess(source.index(terminal_publish_guard), source.index(publish))

    def test_eight_second_live_update_interval_is_preserved(self) -> None:
        for path in SERVER_FPS_PATHS:
            with self.subTest(path=path):
                source = path.read_text(encoding="utf-8")
                self.assertIn("sleep 8; // Update frequency", source)


if __name__ == "__main__":
    unittest.main()
