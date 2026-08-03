#!/usr/bin/env python3
"""Contract for the HC1 launcher teardown scope."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
LAUNCHER = ROOT / "server-config" / "hc_launch.cmd"


class HcLauncherCrossKillTests(unittest.TestCase):
    def test_hc1_restart_only_targets_hc1_command_line(self) -> None:
        text = LAUNCHER.read_text(encoding="utf-8-sig")
        normalized = text.lower()

        self.assertIn(
            'taskkill /f /fi "commandline eq *hc-ai-control-1*"',
            normalized,
        )
        self.assertNotIn("taskkill /f /im arma2oa.exe", normalized)


if __name__ == "__main__":
    unittest.main()
