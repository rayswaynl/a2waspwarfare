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
WORKER = Path("Server/AI/AI_UpdateSupplyTruck.sqf")
CLIENT_START = Path("Client/Module/supplyMission/supplyMissionStart.sqf")
SERVER_START = Path("Server/Module/supplyMission/supplyMissionStarted.sqf")
SERVER_COMPLETE = Path("Server/Module/supplyMission/supplyMissionCompleted.sqf")
TRASH_OBJECT = Path("Common/Functions/Common_TrashObject.sqf")
ECONOMY_GUI = Path("Client/GUI/GUI_Menu_Economy.sqf")
HANDLE_SPECIAL = Path("Server/Functions/Server_HandleSpecial.sqf")
MIRRORED_FILES = (
    CONSTANTS,
    WORKER,
    CLIENT_START,
    SERVER_START,
    SERVER_COMPLETE,
    TRASH_OBJECT,
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

    def test_generic_trash_defers_twice_to_server_registry_owner(self) -> None:
        call = "_object Call WFBE_SE_FNC_IsAISupplyTruck"
        for root in MAINTAINED_ROOTS:
            code = mask_comments(read(root, TRASH_OBJECT))
            first = code.find(call)
            second = code.find(call, first + len(call))
            exit_guard = "if (_isAISupplyTruck) exitWith {"
            server_guard = (
                'if (isServer && {!isNil "WFBE_SE_FNC_IsAISupplyTruck"})'
            )
            first_exit = code.find(exit_guard)
            second_exit = code.find(exit_guard, first_exit + len(exit_guard))
            handler_removal = code.find('removeAllEventHandlers "hit"')
            delay = code.find("sleep _delay;")
            deletion = code.find("deleteVehicle _object")
            with self.subTest(root=root.name):
                self.assertEqual(code.count(call), 2)
                self.assertGreaterEqual(first, 0)
                self.assertEqual(code.count(server_guard), 2)
                self.assertEqual(code.count(exit_guard), 2)
                self.assertGreater(first_exit, first)
                self.assertGreater(handler_removal, first_exit)
                self.assertGreater(second, delay)
                self.assertGreater(second_exit, second)
                self.assertGreater(deletion, second_exit)
                self.assertNotIn(
                    'getVariable ["wfbe_ai_supplytruck"', code
                )
                self.assertNotIn("WFBE_C_AI_SUPPLY_TRUCK_ENABLE", code)

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

    def test_worker_is_explicit_server_local_and_not_the_retired_fsm(self) -> None:
        for root in MAINTAINED_ROOTS:
            code = mask_comments(read(root, WORKER))
            with self.subTest(root=root.name):
                self.assertIn("if (!isServer) exitWith {}", code)
                self.assertIn("if (_side != west && {_side != east}) exitWith {}", code)
                self.assertIn('getVariable ["WFBE_C_AI_SUPPLY_TRUCK_ENABLE", 0]', code)
                self.assertIn('getVariable ["WFBE_C_ECONOMY_SUPPLY_SYSTEM", 1]', code)
                self.assertNotIn("ExecFSM", code)
                self.assertNotIn("supplytruck.fsm", code)
                self.assertNotIn("enableSimulation", code)
                self.assertNotIn("hideObject", code)
                self.assertNotIn("wfbe_teams", code)
                self.assertNotIn("wfbe_aicom_hc", code)

    def test_worker_owns_eight_units_and_registry_before_public_stamp(self) -> None:
        for root in MAINTAINED_ROOTS:
            code = mask_comments(read(root, WORKER))
            with self.subTest(root=root.name):
                self.assertIn('Call WFBE_CO_FNC_CreateGroup', code)
                self.assertIn('for "_i" from 0 to 7', code)
                self.assertIn('getDir _hq, true, true, true, "NONE"', code)
                self.assertIn("if (count _units < 8)", code)
                publication = code.find('_registry = _registry + [_truck]')
                registry = code.find(
                    '_logic setVariable ["wfbe_ai_supplytrucks", _registry]',
                    publication,
                )
                stamp = code.find('_truck setVariable ["wfbe_ai_supplytruck", true, true]')
                self.assertGreaterEqual(publication, 0)
                self.assertGreaterEqual(registry, 0)
                self.assertGreater(stamp, registry)
                self.assertIn('_truck setVariable ["wfbe_trashable", false]', code)
                self.assertIn('_group setVariable ["wfbe_persistent", true]', code)
                self.assertIn('_group setVariable ["wfbe_ai_supply_group", true]', code)

    def test_worker_clamps_truck_rate_and_latches_delivery(self) -> None:
        for root in MAINTAINED_ROOTS:
            code = mask_comments(read(root, WORKER))
            with self.subTest(root=root.name):
                self.assertIn('WFBE_C_TOWNS_SUPPLY_LEVELS_TRUCK', code)
                self.assertIn('if (_rateIndex < 0) then {_rateIndex = 0}', code)
                self.assertIn('if (_rateIndex >= count _rates)', code)
                self.assertIn('if (!_delivered) then', code)
                self.assertIn('setVariable ["supplyValue", _after, true]', code)
                self.assertIn('trip=%8', code)
                self.assertIn('typeName _sv == "SCALAR"', code)
                self.assertIn('surfaceIsWater (getPos _target)', code)
                self.assertIn('_targetOccupied', code)
                latch = code.find("_delivered = true;")
                mutation = code.find('setVariable ["supplyValue", _after, true]')
                self.assertGreaterEqual(latch, 0)
                self.assertGreater(mutation, latch)
                self.assertNotIn("ChangeSideSupply", code)
                self.assertNotIn("SupplyAmount", code)

    def test_worker_shutdown_contact_and_cleanup_fences_are_explicit(self) -> None:
        for root in MAINTAINED_ROOTS:
            code = mask_comments(read(root, WORKER))
            with self.subTest(root=root.name):
                self.assertIn('getVariable ["WFBE_C_AI_COMMANDER_ENABLED", 0]', code)
                self.assertIn("if (WFBE_GameOver", code)
                self.assertIn("alive _source", code)
                self.assertIn('action ["EJECT", _truck]', code)
                self.assertIn("moveInCargo _truck", code)
                self.assertIn("while {!isNull _truck", code)
                self.assertIn("hull-delete-unconfirmed", code)
                self.assertGreaterEqual(code.count("_target = objNull"), 2)
                self.assertGreaterEqual(
                    code.count('if (_phase == "RETURN" && {isNull _anchor || {!alive _anchor}}) then {'),
                    2,
                )
                self.assertIn("_routeTarget = _anchor;", code)
                outer_start = code.find("while {!_done} do {")
                inner_start = code.find("while {alive _truck", outer_start)
                self.assertGreaterEqual(outer_start, 0)
                self.assertGreater(inner_start, outer_start)
                self.assertNotIn("_contactUntil = 0;", code[outer_start:inner_start])

    def test_init_server_compiles_and_double_gates_both_sides(self) -> None:
        for root in MAINTAINED_ROOTS:
            code = mask_comments(read(root, INIT_SERVER))
            self.assertIn(
                'UpdateSupplyTruck = Compile preprocessFileLineNumbers '
                '"Server\\AI\\AI_UpdateSupplyTruck.sqf"',
                code,
            )
            launch = code[code.find("serverInitFull = true;") :]
            self.assertIn('getVariable ["WFBE_C_AI_SUPPLY_TRUCK_ENABLE", 0]', launch)
            self.assertIn('getVariable ["WFBE_C_ECONOMY_SUPPLY_SYSTEM", 1]', launch)
            self.assertIn("forEach [west,east]", launch)


if __name__ == "__main__":
    unittest.main()
