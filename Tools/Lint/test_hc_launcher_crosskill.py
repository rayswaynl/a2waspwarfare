#!/usr/bin/env python3
"""Contract for the HC1 launcher teardown scope."""

from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[2]
LAUNCHER = ROOT / "server-config" / "hc_launch.cmd"
HC1_COMMANDLINE_TOKEN = re.compile(
    r"(^|\s)-name=(?:HC-AI-Control-1|\"HC-AI-Control-1\")(\s|$)",
    re.IGNORECASE,
)


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
        self.assertIn(
            "$hc1token = '-name=(?:hc-ai-control-1|\\x22hc-ai-control-1\\x22)'",
            normalized,
        )
        self.assertIn(
            "[string]$_.commandline -match ('(^|\\s)' + $hc1token + '(\\s|$)')",
            normalized,
        )
        self.assertIn("stop-process -id $_.processid -force", normalized)
        self.assertIn("if errorlevel 1 exit /b 1", normalized)
        self.assertNotIn("taskkill /f /im arma2oa.exe", normalized)
        self.assertNotIn('/fi "commandline', normalized)
        self.assertNotIn("-like '*hc-ai-control-1*'", normalized)
        self.assertNotIn("[regex]::escape('-name=hc-ai-control-1')", normalized)

    def test_hc1_token_does_not_match_hc2_or_hc10(self) -> None:
        self.assertIsNotNone(HC1_COMMANDLINE_TOKEN.search("-name=HC-AI-Control-1 -client"))
        self.assertIsNotNone(HC1_COMMANDLINE_TOKEN.search('-name="HC-AI-Control-1" -client'))
        self.assertIsNone(HC1_COMMANDLINE_TOKEN.search("-name=HC-AI-Control-2 -client"))
        self.assertIsNone(HC1_COMMANDLINE_TOKEN.search('-name="HC-AI-Control-2" -client'))
        self.assertIsNone(HC1_COMMANDLINE_TOKEN.search("-name=HC-AI-Control-10 -client"))
        self.assertIsNone(HC1_COMMANDLINE_TOKEN.search('-name="HC-AI-Control-10" -client'))


if __name__ == "__main__":
    unittest.main()
