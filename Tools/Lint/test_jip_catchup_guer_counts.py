#!/usr/bin/env python3
"""Regression checks for the GUER late-join town summary."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad"),
)
RELATIVE = "Client/Functions/Client_JIPCatchupBriefing.sqf"


def _read(mission: Path) -> str:
    return (ROOT / mission / RELATIVE).read_text(encoding="utf-8-sig")


class JipCatchupGuerCountTests(unittest.TestCase):
    def test_guer_joiners_get_one_own_count_and_no_duplicate_guer_column(self) -> None:
        for mission in MISSIONS:
            source = _read(mission)
            self.assertIn("if (_myID == WFBE_C_GUER_ID) then {", source)
            self.assertIn(
                '"<t color=\'#9aa7b0\'>Towns  </t><t color=\'#b8c4cc\'>Own %1</t>  <t color=\'#b8b8b8\'>Free %2</t><br/>"',
                source,
            )

    def test_west_and_east_joiners_keep_the_separate_guer_count(self) -> None:
        for mission in MISSIONS:
            source = _read(mission)
            self.assertIn(
                '"<t color=\'#9aa7b0\'>Towns  </t><t color=\'#b8c4cc\'>Own %1</t>  <t color=\'#7ed37e\'>GUER %2</t>  <t color=\'#b8b8b8\'>Free %3</t><br/>"',
                source,
            )


if __name__ == "__main__":
    unittest.main()
