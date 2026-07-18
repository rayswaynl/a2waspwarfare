#!/usr/bin/env python3
"""Regression checks for bounded server-authoritative command-menu orders."""

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

CLIENT_MENU = Path("Client/GUI/GUI_Menu_Command.sqf")
SERVER_SPECIAL = Path("Server/Functions/Server_HandleSpecial.sqf")
SERVER_QUEUE = Path("Server/Functions/Server_CommandOrderQueue.sqf")
SERVER_INIT = Path("Server/Init/Init_Server.sqf")
MIRRORED_FILES = (CLIENT_MENU, SERVER_SPECIAL, SERVER_QUEUE)


def read(root: Path, relative: Path) -> str:
    return (root / relative).read_text(encoding="utf-8-sig")


class CommandOrderQueueTests(unittest.TestCase):
    def test_client_uses_one_server_order_envelope_not_direct_group_broadcasts(self) -> None:
        code = mask_comments(read(MAINTAINED_ROOTS[0], CLIENT_MENU))
        self.assertIn(
            '["RequestSpecial", ["aicom-team-order", sideJoined, _orderType, '
            '_orderIndex, _orderTarget, player]] Call WFBE_CO_FNC_SendToServer',
            code,
        )
        self.assertNotIn("Call SetTeamMovePos", code)
        self.assertNotIn("Call SetTeamMoveMode", code)
        self.assertNotIn("Call SetTeamAutonomous", code)
        self.assertNotIn('setVariable ["wfbe_aicom_manualpin"', code)

    def test_server_validates_and_coalesces_the_queue_by_team(self) -> None:
        special = mask_comments(read(MAINTAINED_ROOTS[0], SERVER_SPECIAL))
        required = (
            'case "aicom-team-order"',
            "count _args < 6",
            'typeName _coType != "STRING"',
            'typeName _coIndex != "SCALAR"',
            'typeName _coTarget != "ARRAY"',
            'typeName _coIssuer != "OBJECT"',
            'wfbe_aicom_cmd_order_queue',
            '{(_x select 0) != _qeTeam}',
            '_coQueue = _qeNew + [[_qeTeam, _qeType, _qeTarget, _coIssuer, _coSeq, time]]',
            'AICOM2|v1|ORDER|QUEUE|REJECT',
        )
        for token in required:
            with self.subTest(token=token):
                self.assertIn(token, special)

    def test_worker_applies_last_order_once_and_drops_stale_entries(self) -> None:
        worker = mask_comments(read(MAINTAINED_ROOTS[0], SERVER_QUEUE))
        required = (
            "while {true} do",
            '"wfbe_aicom_cmd_order_queue"',
            '"wfbe_aicom_cmd_order_last"',
            '"wfbe_aicom_cmd_order_seq"',
            '"wfbe_aicom_manualpin"',
            "Call SetTeamMovePos",
            "Call SetTeamMoveMode",
            "Call SetTeamAutonomous",
            "if ((time - _last) < _cool) then {_keep = _keep + [_entry]}",
            "AICOM2|v1|ORDER|QUEUE|APPLY",
            "AICOM2|v1|ORDER|QUEUE|DROP",
        )
        for token in required:
            with self.subTest(token=token):
                self.assertIn(token, worker)

    def test_worker_is_compiled_and_started_once(self) -> None:
        init = mask_comments(read(MAINTAINED_ROOTS[0], SERVER_INIT))
        self.assertIn(
            'WFBE_SE_FNC_CommandOrderQueue = Compile preprocessFileLineNumbers '
            '"Server\\Functions\\Server_CommandOrderQueue.sqf"',
            init,
        )
        self.assertIn("[] Spawn WFBE_SE_FNC_CommandOrderQueue", init)

    def test_all_generated_copies_match_source(self) -> None:
        for relative in MIRRORED_FILES:
            with self.subTest(path=str(relative)):
                copies = [(root / relative).read_bytes() for root in MAINTAINED_ROOTS]
                self.assertEqual(len(set(copies)), 1)


if __name__ == "__main__":
    unittest.main()
