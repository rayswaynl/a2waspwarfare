#!/usr/bin/env python3
"""Regression contract for wildcard W1 human-commander wallet credits."""

from pathlib import Path
import unittest

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
WILDCARD = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / "Server" / "Functions" / "AI_Commander_Wildcard.sqf"


class WildcardHumanWarchestFundsRecordTests(unittest.TestCase):
    def test_human_warchest_credit_syncs_the_jip_funds_record(self) -> None:
        text = mask_comments(WILDCARD.read_text(encoding="utf-8-sig"))
        credit = text.index('_cmdTeam setVariable ["wfbe_funds", _curFunds + _bonus, true]')
        detail = text.index('_detail = Format ["human_cmd_team_funds_bonus=%1 funds_before=%2"', credit)
        credit_window = text[credit:detail]
        self.assertIn('[_cmdTeam] Call WFBE_SE_FNC_SyncFundsRecord', credit_window)


if __name__ == "__main__":
    unittest.main()
