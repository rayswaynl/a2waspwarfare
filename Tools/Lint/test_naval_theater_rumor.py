#!/usr/bin/env python3
"""Static contract for default-off naval theatre rumor announcements."""

from pathlib import Path
import unittest

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"
CONSTANTS = MISSION / "Common" / "Init" / "Init_CommonConstants.sqf"
USV = MISSION / "Server" / "Server_USVFlotilla.sqf"
NAVAL_HVT = MISSION / "Server" / "Init" / "Init_NavalHVT.sqf"


def source(path: Path) -> str:
    return mask_comments(path.read_text(encoding="utf-8-sig"))


class NavalTheaterRumorContractTests(unittest.TestCase):
    def test_constants_are_default_off_with_explicit_interval(self) -> None:
        text = source(CONSTANTS)
        self.assertIn("WFBE_C_NAVAL_THEATER_RUMOR = 0", text)
        self.assertIn("WFBE_C_NAVAL_THEATER_RUMOR_INTERVAL = 120", text)

    def test_usv_gate_uses_latched_edge_and_dashboard_announce(self) -> None:
        text = source(USV)
        self.assertIn('missionNamespace getVariable ["WFBE_C_NAVAL_THEATER_RUMOR", 0]', text)
        self.assertIn('_gateActive && {!_gateWasActive}', text)
        self.assertIn('[nil, "DashboardAnnounce", ["Hostile small craft are active on the coast."]]', text)
        self.assertIn("_rumorLast", text)
        self.assertEqual(text.count('"DashboardAnnounce"'), 1)

    def test_cap_gate_uses_latched_edge_and_dashboard_announce(self) -> None:
        text = source(NAVAL_HVT)
        self.assertIn('missionNamespace getVariable ["WFBE_C_NAVAL_THEATER_RUMOR", 0]', text)
        self.assertIn("if (!_armed) then", text)
        self.assertIn('Carrier CAP airborne near %1.', text)
        self.assertIn('[nil, "DashboardAnnounce", [Format [', text)
        self.assertIn("_rumorLast", text)
        self.assertEqual(text.count('"DashboardAnnounce"'), 1)

    def test_existing_naval_map_exits_precede_new_hooks(self) -> None:
        for path in (USV, NAVAL_HVT):
            text = source(path)
            hook = text.find('WFBE_C_NAVAL_THEATER_RUMOR", 0')
            self.assertLess(
                text.index('IS_naval_map", false'),
                hook,
            )


if __name__ == "__main__":
    unittest.main()
