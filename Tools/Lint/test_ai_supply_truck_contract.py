#!/usr/bin/env python3
"""Static contract checks for the default-off server-owned AI supply convoy."""

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

CONSTANTS = Path("Common/Init/Init_CommonConstants.sqf")
INIT_SERVER = Path("Server/Init/Init_Server.sqf")
CLIENT_START = Path("Client/Module/supplyMission/supplyMissionStart.sqf")
SERVER_START = Path("Server/Module/supplyMission/supplyMissionStarted.sqf")
SERVER_COMPLETE = Path("Server/Module/supplyMission/supplyMissionCompleted.sqf")
ECONOMY_GUI = Path("Client/GUI/GUI_Menu_Economy.sqf")
HANDLE_SPECIAL = Path("Server/Functions/Server_HandleSpecial.sqf")
MIRRORED_FILES = (
    CONSTANTS,
    CLIENT_START,
    SERVER_START,
    SERVER_COMPLETE,
    ECONOMY_GUI,
    HANDLE_SPECIAL,
)


def read(root: Path, relative: Path) -> str:
    return (root / relative).read_text(encoding="utf-8-sig")


class AiSupplyTruckContractTests(unittest.TestCase):
    def test_feature_flag_is_default_off_in_every_maintained_mission(self) -> None:
        expected = (
            'if (isNil "WFBE_C_AI_SUPPLY_TRUCK_ENABLE") then '
            "{WFBE_C_AI_SUPPLY_TRUCK_ENABLE = 0};"
        )
        for root in MAINTAINED_ROOTS:
            code = mask_comments(read(root, CONSTANTS))
            with self.subTest(root=root.name):
                self.assertEqual(code.count(expected), 1)

    def test_flag_off_legacy_registry_baseline_remains_present(self) -> None:
        text = read(MAINTAINED_ROOTS[0], INIT_SERVER)
        code = mask_comments(text)
        self.assertIn(
            'if ((missionNamespace getVariable "WFBE_C_ECONOMY_SUPPLY_SYSTEM") == 0 '
            '&& (missionNamespace getVariable "WFBE_C_AI_COMMANDER_ENABLED") > 0)',
            code,
        )
        self.assertIn('_logik setVariable ["wfbe_ai_supplytrucks", []]', code)
        self.assertIn(
            "AI supply-truck logistics are disabled for [%1]; legacy "
            "UpdateSupplyTruck depends on missing Server\\FSM\\supplytruck.fsm.",
            text,
        )

    def test_client_rejects_the_broadcast_stamp_before_loading(self) -> None:
        for root in MAINTAINED_ROOTS:
            code = mask_comments(read(root, CLIENT_START))
            guard = code.find(
                '_cursorTarget getVariable ["wfbe_ai_supplytruck", false]'
            )
            mutation = code.find(
                'WFBE_CL_VAR_ASSOCIATED_SUPPLY_TRUCK setVariable ["SupplyLoading"'
            )
            with self.subTest(root=root.name):
                self.assertGreaterEqual(guard, 0)
                self.assertGreater(mutation, guard)

    def test_server_registry_helper_checks_both_sides_and_not_the_stamp(self) -> None:
        for root in MAINTAINED_ROOTS:
            code = mask_comments(read(root, SERVER_COMPLETE))
            helper_start = code.find("WFBE_SE_FNC_IsAISupplyTruck = {")
            handler_start = code.find("WFBE_SE_FNC_HandleSupplyMissionCompleted = {")
            helper = code[helper_start:handler_start]
            with self.subTest(root=root.name):
                self.assertGreaterEqual(helper_start, 0)
                self.assertGreater(handler_start, helper_start)
                self.assertIn("forEach [west,east]", helper)
                self.assertIn('getVariable "wfbe_ai_supplytrucks"', helper)
                self.assertIn("_candidate in _registry", helper)
                self.assertNotIn("wfbe_ai_supplytruck\"", helper)

    def test_server_start_rejects_registry_member_before_any_mutation(self) -> None:
        for root in MAINTAINED_ROOTS:
            code = mask_comments(read(root, SERVER_START))
            guard = code.find(
                "_associatedSupplyTruck Call WFBE_SE_FNC_IsAISupplyTruck"
            )
            cooldown = code.find("LastSupplyMissionRun")
            killed_handler = code.find("wfbe_supply_killed_eh_set")
            with self.subTest(root=root.name):
                self.assertGreaterEqual(guard, 0)
                self.assertGreater(cooldown, guard)
                self.assertGreater(killed_handler, guard)

    def test_central_completion_rejects_before_stats_economy_or_state(self) -> None:
        for root in MAINTAINED_ROOTS:
            code = mask_comments(read(root, SERVER_COMPLETE))
            handler = code[code.find("WFBE_SE_FNC_HandleSupplyMissionCompleted = {") :]
            guard = handler.find(
                "_associatedSupplyTruck Call WFBE_SE_FNC_IsAISupplyTruck"
            )
            with self.subTest(root=root.name):
                self.assertGreaterEqual(guard, 0)
                for token in (
                    "WFBE_SE_FNC_RecordStat",
                    "Call ChangeSideSupply",
                    'setVariable ["SupplyAmount"',
                    'publicVariable "WFBE_Server_PV_SupplyMissionCompletedMessage"',
                ):
                    self.assertGreater(handler.find(token), guard, token)

    def test_remote_respawn_request_is_dark_on_both_client_and_server(self) -> None:
        for root in MAINTAINED_ROOTS:
            gui = mask_comments(read(root, ECONOMY_GUI))
            action = gui[gui.find("if (MenuAction == 4)") :]
            action = action[: action.find("if (mouseButtonUp == 0)")]
            server = mask_comments(read(root, HANDLE_SPECIAL))
            case = server[server.find('case "RespawnST"') :]
            case = case[: case.find('case "uav"')]
            with self.subTest(root=root.name):
                self.assertIn(
                    'missionNamespace getVariable ["WFBE_C_AI_SUPPLY_TRUCK_ENABLE", 0]',
                    gui,
                )
                self.assertIn("if (!_aiSupplyTruckEnabled) then", action)
                self.assertIn(
                    '["RequestSpecial", ["RespawnST",sideJoined]] Call '
                    "WFBE_CO_FNC_SendToServer",
                    action,
                )
                self.assertLess(
                    action.find("if (!_aiSupplyTruckEnabled) then"),
                    action.find('["RequestSpecial", ["RespawnST",sideJoined]]'),
                )
                gate = case.find(
                    'missionNamespace getVariable ["WFBE_C_AI_SUPPLY_TRUCK_ENABLE", 0]'
                )
                destructive = case.find("setDammage 1")
                self.assertGreaterEqual(gate, 0)
                self.assertGreater(destructive, gate)

    def test_generated_mission_copies_match_canonical_source(self) -> None:
        for relative in MIRRORED_FILES:
            copies = [(root / relative).read_bytes() for root in MAINTAINED_ROOTS]
            with self.subTest(path=str(relative)):
                self.assertEqual(len(set(copies)), 1)


if __name__ == "__main__":
    unittest.main()
