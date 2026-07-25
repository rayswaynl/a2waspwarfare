#!/usr/bin/env python3
"""Static contract for command-console roster selection identity."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
MENU = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / "Client" / "GUI" / "GUI_Menu_Command.sqf"


class CommandMenuRosterFixtures(unittest.TestCase):
    def test_refresh_captures_selection_from_prior_roster_identity(self) -> None:
        code = MENU.read_text(encoding="utf-8-sig")
        start = code.index("//--- Repaint only on a content change")
        end = code.index("//--- Resolve the currently selected team", start)
        refresh = code[start:end]
        self.assertIn("_lastCmdTeams select _oldSel", refresh)
        self.assertIn("_lastCmdTeams = +_cmdTeams", refresh)
        self.assertLess(
            refresh.index("_lastCmdTeams select _oldSel"),
            refresh.index("lbClear 14661"),
        )
        self.assertGreater(
            refresh.index("_lastCmdTeams = +_cmdTeams"),
            refresh.index("lbClear 14661"),
        )


if __name__ == "__main__":
    unittest.main()
