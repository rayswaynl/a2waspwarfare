#!/usr/bin/env python3
"""Regression contract for crew-authoritative captured-vehicle mop-up contact scans."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
SERVER_TOWN = ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/FSM/server_town.sqf"


class CapturedVehicleMopupTests(unittest.TestCase):
    def test_mopup_counts_only_living_resistance_men_or_living_resistance_crew(self) -> None:
        source = SERVER_TOWN.read_text(encoding="utf-8-sig")
        start = source.index("_detected = (_loc nearEntities")
        end = source.index("if (_guerCount == 0)", start)
        scan = source[start:end]

        self.assertIn("if (_x isKindOf \"Man\") then {", scan)
        self.assertIn("if (alive _x && {side _x == resistance}) then", scan)
        self.assertIn("forEach (crew _x);", scan)
        self.assertNotIn("if (side _x == resistance) then {_guerCount", scan)


if __name__ == "__main__":
    unittest.main()
