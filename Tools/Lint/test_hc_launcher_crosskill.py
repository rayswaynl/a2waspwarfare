#!/usr/bin/env python3
"""Contract for the HC1 launcher teardown scope."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
LAUNCHER = ROOT / "server-config" / "hc_launch.cmd"


class HcLauncherCrossKillTests(unittest.TestCase):
    def test_hc1_restart_uses_supported_hc1_process_query(self) -> None:
        text = LAUNCHER.read_text(encoding="utf-8-sig")
        normalized = text.lower()

        self.assertIn(
            "powershell -noprofile -executionpolicy bypass -command",
            normalized,
        )
        self.assertIn("$erroractionpreference = 'stop'", normalized)
        self.assertIn("get-ciminstance -classname win32_process", normalized)
        self.assertIn("$_.name -eq 'arma2oa.exe'", normalized)
        self.assertIn("$_.commandline -like '*hc-ai-control-1*'", normalized)
        self.assertIn("stop-process -id $_.processid -force", normalized)
        self.assertIn("if errorlevel 1 exit /b 1", normalized)
        self.assertNotIn("taskkill /f /im arma2oa.exe", normalized)
        self.assertNotIn('/fi "commandline', normalized)


if __name__ == "__main__":
    unittest.main()
