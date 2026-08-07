#!/usr/bin/env python3
"""Regression for the server-authorized UAV fee path."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / "Server" / "Support" / "Support_UAV.sqf"


class SupportUavSingleDebitTests(unittest.TestCase):
    def test_server_authorized_path_skips_its_legacy_second_debit(self):
        text = SOURCE.read_text(encoding="utf-8")
        auth_gate = '_serverAuth = (missionNamespace getVariable ["WFBE_C_SUPPORT_SERVER_AUTH", 0]) > 0;'
        legacy_gate = 'if (!_serverAuth) then {'
        debit = '_playerTeam setVariable ["wfbe_funds", (_funds - _cost), true];'
        cooldown = 'missionNamespace setVariable [_cooldownKey, time];'

        self.assertIn(auth_gate, text)
        self.assertIn(legacy_gate, text)
        legacy_block = text[text.index(legacy_gate) : text.index('_uav = createVehicle', text.index(legacy_gate))]
        self.assertIn(debit, legacy_block)
        self.assertIn(cooldown, legacy_block)


if __name__ == "__main__":
    unittest.main()
