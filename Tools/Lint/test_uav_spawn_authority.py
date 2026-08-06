#!/usr/bin/env python3
"""Regression checks for server-authoritative UAV support spawning."""

from __future__ import annotations

import unittest
from pathlib import Path

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
MAINTAINED_ROOTS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)

UAV_CLIENT = Path("Client/Module/UAV/uav.sqf")
UAV_SERVER = Path("Server/Support/Support_UAV.sqf")
CLIENT_RECEIVER = Path("Client/PVFunctions/HandleSpecial.sqf")


def read(root: Path, relative: Path) -> str:
    return (root / relative).read_text(encoding="utf-8-sig")


class UavSpawnAuthorityTests(unittest.TestCase):
    def test_client_requests_a_uav_without_creating_or_charging_one(self) -> None:
        code = mask_comments(read(MAINTAINED_ROOTS[0], UAV_CLIENT))
        self.assertIn(
            '["RequestSpecial", ["uav",sideJoined,clientTeam,player]] Call WFBE_CO_FNC_SendToServer;',
            code,
        )
        self.assertNotIn("_uav = createVehicle", code)
        self.assertNotIn("Call ChangePlayerFunds", code)
        self.assertNotIn("processInitCommands", code)

    def test_server_validates_then_creates_and_returns_the_airframe(self) -> None:
        code = mask_comments(read(MAINTAINED_ROOTS[0], UAV_SERVER))
        for token in (
            "isServer",
            "_playerTeam getVariable \"wfbe_funds\"",
            "WFBE_C_PLAYERS_UAV_COST",
            "WFBE_C_PLAYERS_UAV_COOLDOWN",
            'Format ["WFBE_%1UAV", str _side]',
            "_uav = createVehicle",
            "[_playerTeam] Call WFBE_SE_FNC_SyncFundsRecord",
            "WFBE_CO_FNC_SendToClients",
            '"uav-created"',
        ):
            with self.subTest(token=token):
                self.assertIn(token, code)

        debit = code.find('_playerTeam setVariable ["wfbe_funds", (_funds - _cost), true]')
        spawn = code.find("_uav = createVehicle")
        self.assertGreaterEqual(debit, 0)
        self.assertGreaterEqual(spawn, 0)
        self.assertLess(debit, spawn)

    def test_client_accepts_only_its_authoritative_uav_handoff(self) -> None:
        code = mask_comments(read(MAINTAINED_ROOTS[0], CLIENT_RECEIVER))
        self.assertIn('case "uav-created"', code)
        self.assertIn("getPlayerUID player", code)
        self.assertIn("ExecVM \"Client\\Module\\UAV\\uav.sqf\"", code)

    def test_generated_copies_match_source(self) -> None:
        for relative in (UAV_CLIENT, UAV_SERVER, CLIENT_RECEIVER):
            copies = [(root / relative).read_bytes() for root in MAINTAINED_ROOTS]
            with self.subTest(path=str(relative)):
                self.assertEqual(len(set(copies)), 1)


if __name__ == "__main__":
    unittest.main()
