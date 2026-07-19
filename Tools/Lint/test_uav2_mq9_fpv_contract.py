#!/usr/bin/env python3
"""Regression contract for the optional UAV L2 MQ-9 FPV variants."""

from pathlib import Path
import unittest

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"


def code(relative: str) -> str:
    return mask_comments((MISSION / relative).read_text(encoding="utf-8-sig"))


class Uav2Mq9FpvContractTests(unittest.TestCase):
    def test_terminal_exposes_both_charges_only_behind_the_new_default_off_flag(self) -> None:
        text = code("Client/GUI/GUI_Menu_Tactical.sqf")
        self.assertIn('WFBE_C_UAV2_MQ9_FPV", 0]) > 0', text)
        self.assertIn('"MQ9_FPV_CLUSTER"', text)
        self.assertIn('"MQ9_FPV_AT"', text)

    def test_server_is_the_authority_for_l2_main_side_class_and_charge(self) -> None:
        text = code("Server/Support/Support_FPV.sqf")
        for required in (
            'WFBE_C_UAV2_MQ9_FPV", 0]) > 0',
            'WFBE_C_UAV2_LEVEL", 2]',
            'Format ["WFBE_%1UAV", str _side]',
            '"mq9-cluster"',
            '"mq9-at"',
            'wfbe_fpv_ammo',
        ):
            self.assertIn(required, text)

    def test_detonation_uses_only_the_server_stamped_charge(self) -> None:
        text = code("Server/Support/Support_FPV_Detonate.sqf")
        server = code("Server/Support/Support_FPV.sqf")
        self.assertIn('getVariable ["wfbe_fpv_ammo", ""]', text)
        self.assertIn('WFBE_C_UAV2_MQ9_FPV_CLUSTER_AMMO', server)
        self.assertIn('WFBE_C_UAV2_MQ9_FPV_AT_AMMO', server)


if __name__ == "__main__":
    unittest.main()
