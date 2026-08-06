"""Static contract checks for the opt-in territorial victory HUD chip."""

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus"


class TerritorialHudContractTests(unittest.TestCase):
    def test_feature_is_armed_and_server_publishes_one_snapshot(self):
        constants = (MISSION / "Common/Init/Init_CommonConstants.sqf").read_text(
            encoding="utf-8"
        )
        server = (MISSION / "Server/FSM/server_victory_threeway.sqf").read_text(
            encoding="utf-8"
        )

        self.assertIn(
            'isNil "WFBE_C_TERRITORIAL_HUD"',
            constants,
        )
        # The owner armed this already-merged opt-in in the current master wave;
        # 0 remains the documented rollback value, not the current contract.
        self.assertIn("WFBE_C_TERRITORIAL_HUD = 1", constants)
        self.assertIn('WFBE_TERRITORIAL_HUD', server)
        self.assertIn('publicVariable "WFBE_TERRITORIAL_HUD"', server)
        self.assertIn('WFBE_TERRITORIAL_CLOCK_', server)
        self.assertIn('WFBE_C_TERRITORIAL_HUD', server)

    def test_client_reads_snapshot_and_uses_reserved_rhud_pair(self):
        client = (MISSION / "Client/Client_UpdateRHUD.sqf").read_text(
            encoding="utf-8"
        )

        self.assertIn('WFBE_C_TERRITORIAL_HUD', client)
        self.assertIn('WFBE_TERRITORIAL_HUD', client)
        self.assertIn(
            'if !((missionNamespace getVariable ["WFBE_C_TERRITORIAL_HUD", 0]) > 0)',
            client,
        )
        self.assertNotIn('WFBE_TERRITORIAL_CLOCK_', client)
        self.assertIn('[27,', client)
        self.assertIn('[28,', client)
        self.assertIn('"Territory:"', client)

    def test_all_maintained_terrain_copies_have_identical_feature_files(self):
        relative_paths = (
            "Common/Init/Init_CommonConstants.sqf",
            "Server/FSM/server_victory_threeway.sqf",
            "Client/Client_UpdateRHUD.sqf",
        )
        roots = (
            "Missions/[55-2hc]warfarev2_073v48co.chernarus",
            "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
            "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
        )

        for relative_path in relative_paths:
            source = (ROOT / roots[0] / relative_path).read_bytes().replace(
                b"\r\n", b"\n"
            )
            for root in roots[1:]:
                mirror = (ROOT / root / relative_path).read_bytes().replace(
                    b"\r\n", b"\n"
                )
                self.assertEqual(source, mirror, relative_path)


if __name__ == "__main__":
    unittest.main()
