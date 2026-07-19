#!/usr/bin/env python3
"""Source-contract checks for the owner-approved unified UAV upgrade level 2.

The OA 1.64 mission cannot be executed off-engine, so these tests pin the
authority, feature-gate, resource, and mirror invariants to the SQF constructs
which enforce them. They intentionally avoid asserting presentation wording.
"""

from __future__ import annotations

import re
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
COMMON_INIT = Path("Common/Init/Init_Common.sqf")
COMMON_GATE = Path("Common/Functions/Common_CanUseUAV2FOB.sqf")
UNIT_INIT = Path("Common/Init/Init_Unit.sqf")
PV_INIT = Path("Common/Init/Init_PublicVariables.sqf")
CLIENT_ACTION = Path("Client/Action/Action_BuildUAV2FOB.sqf")
CLIENT_HANDLE_SPECIAL = Path("Client/PVFunctions/HandleSpecial.sqf")
SERVER_REQUEST = Path("Server/PVFunctions/RequestUAV2FOB.sqf")
SERVER_INIT = Path("Server/Init/Init_Server.sqf")
SWARM = Path("Server/Functions/AICOM_UAV2_Swarm.sqf")
TACTICAL_MENU = Path("Client/GUI/GUI_Menu_Tactical.sqf")
UPGRADE_DIR = Path("Common/Config/Core_Upgrades")


def read(relative: Path, root: Path = MAINTAINED_ROOTS[0]) -> str:
    return (root / relative).read_text(encoding="utf-8-sig")


def code(relative: Path) -> str:
    return mask_comments(read(relative))


def a2_oa_array_subtract(left: list[object], right: list[object]) -> list[object]:
    """Model the OA 1.64 `-` behavior relevant to AI upgrade orders.

    OA only removes scalar direct members. A nested array such as
    `[WFBE_UP_UAV,2]` is not removed by `order - [[WFBE_UP_UAV,2]]`.
    """
    scalar_removals = [value for value in right if not isinstance(value, list)]
    return [value for value in left if value not in scalar_removals]


def dark_uav_order(text: str) -> list[list[str]]:
    """Evaluate the default UAV slice as constructed by an upgrade config."""
    old_order = [["WFBE_UP_UAV", "1"], ["WFBE_UP_UAV", "2"]]
    if "_uav2Order = _uav2Order - [[WFBE_UP_UAV,2]]" in text:
        return a2_oa_array_subtract(old_order, [["WFBE_UP_UAV", "2"]])

    append = re.search(
        r"if \(_uav2Enabled\) then \{\s*"
        r"(?P<variable>_uav2Order|_aiOrder)\s*=\s*"
        r"(?P=variable)\s*\+\s*\[\[WFBE_UP_UAV,2\]\];",
        text,
    )
    if append is None:
        raise AssertionError("AI order must be constructed without UAV L2 and append it only when enabled")
    construction = text[:append.start()]
    levels = re.findall(r"\[WFBE_UP_UAV,(\d)\]", construction)
    return [["WFBE_UP_UAV", level] for level in levels]


def enabled_ai_order(text: str) -> list[list[str]]:
    """Read the enabled AI order in the sequence its construction executes."""
    construction = re.search(r"(?:_uav2Order|_aiOrder)\s*=\s*\[", text)
    if construction is None:
        raise AssertionError("AI order construction was not found")
    published = text.find(
        'missionNamespace setVariable [Format["WFBE_C_UPGRADES_%1_AI_ORDER"',
        construction.start(),
    )
    if published < 0:
        raise AssertionError("AI order publication was not found")
    return [
        [upgrade, level]
        for upgrade, level in re.findall(
            r"\[(WFBE_UP_[A-Z0-9_]+),(\d+)\]",
            text[construction.start():published],
        )
    ]


class Uav2ConfigurationTests(unittest.TestCase):
    def test_features_are_separate_and_armed_for_rc2(self) -> None:
        text = code(CONSTANTS)
        self.assertIn('WFBE_C_UAV2_FOB = 1', text)
        self.assertIn('WFBE_C_UAV2_SWARM = 1', text)
        self.assertIn('WFBE_C_UAV2_LEVEL = 2', text)
        for token in (
            "WFBE_C_UAV2_FOB_COST",
            "WFBE_C_UAV2_FOB_CAP",
            "WFBE_C_UAV2_FOB_TRUCK_RANGE",
            "WFBE_C_UAV2_FOB_BASE_EXCLUSION",
            "WFBE_C_UAV2_FOB_SPACING",
            "WFBE_C_UAV2_SWARM_COST",
            "WFBE_C_UAV2_SWARM_MAX_ACTIVE",
            "WFBE_C_UAV2_SWARM_MAX_PER_STRIKE",
            "WFBE_C_UAV2_SWARM_INTERVAL",
            "WFBE_C_UAV2_SWARM_COOLDOWN",
            "WFBE_C_UAV2_SWARM_TTL",
        ):
            with self.subTest(token=token):
                self.assertIn(token, text)

    def test_uav_slot_carries_level_two_data_in_every_faction(self) -> None:
        paths = sorted((MAINTAINED_ROOTS[0] / UPGRADE_DIR).glob("Upgrades_*.sqf"))
        paths = [path for path in paths if "WFBE_UP_UAV" in path.read_text(encoding="utf-8-sig")]
        self.assertEqual(len(paths), 10)
        for path in paths:
            text = path.read_text(encoding="utf-8-sig")
            with self.subTest(path=path.name):
                self.assertIn('if (_uav2Enabled) then {2} else {1}', text)
                self.assertIn('if (_uav2Enabled) then {[[2000,0],[6000,0]]} else {[[2000,0]]}', text)
                self.assertIn('if (_uav2Enabled) then {[60,120]} else {[60]}', text)
                self.assertIn('if (_uav2Enabled) then {[[WFBE_UP_AIR,2],[WFBE_UP_AIR,3]]} else {[[WFBE_UP_AIR,2]]}', text)
                self.assertIn("[WFBE_UP_UAV,1]", text)
                self.assertIn("[WFBE_UP_UAV,2]", text)
                self.assertIn('missionNamespace getVariable ["WFBE_C_UAV2_FOB", 0]', text)
                self.assertIn('missionNamespace getVariable ["WFBE_C_UAV2_SWARM", 0]', text)

    def test_dark_consumers_hide_level_two_from_player_upgrade_data(self) -> None:
        paths = sorted((MAINTAINED_ROOTS[0] / UPGRADE_DIR).glob("Upgrades_*.sqf"))
        paths = [path for path in paths if "WFBE_UP_UAV" in path.read_text(encoding="utf-8-sig")]
        for path in paths:
            text = mask_comments(path.read_text(encoding="utf-8-sig"))
            with self.subTest(path=path.name):
                self.assertIn(
                    '_uav2Enabled = ((missionNamespace getVariable ["WFBE_C_UAV2_FOB", 0]) > 0) || ((missionNamespace getVariable ["WFBE_C_UAV2_SWARM", 0]) > 0)',
                    text,
                )
                self.assertIn('if (_uav2Enabled) then {[[2000,0],[6000,0]]} else {[[2000,0]]}', text)
                self.assertIn('if (_uav2Enabled) then {2} else {1}', text)
                self.assertIn('if (_uav2Enabled) then {[[WFBE_UP_AIR,2],[WFBE_UP_AIR,3]]} else {[[WFBE_UP_AIR,2]]}', text)
                self.assertIn('if (_uav2Enabled) then {[60,120]} else {[60]}', text)

    def test_dark_ai_order_omits_level_two_under_oa_nested_array_semantics(self) -> None:
        paths = sorted((MAINTAINED_ROOTS[0] / UPGRADE_DIR).glob("Upgrades_*.sqf"))
        paths = [path for path in paths if "WFBE_UP_UAV" in path.read_text(encoding="utf-8-sig")]
        for path in paths:
            with self.subTest(path=path.name):
                order = dark_uav_order(mask_comments(path.read_text(encoding="utf-8-sig")))
                self.assertNotIn(
                    ["WFBE_UP_UAV", "2"],
                    order,
                    "OA 1.64 nested-array subtraction retains UAV L2 in the dark AI order",
                )

    def test_enabled_ai_order_keeps_level_two_immediately_after_level_one(self) -> None:
        paths = sorted((MAINTAINED_ROOTS[0] / UPGRADE_DIR).glob("Upgrades_*.sqf"))
        paths = [path for path in paths if "WFBE_UP_UAV" in path.read_text(encoding="utf-8-sig")]
        for path in paths:
            with self.subTest(path=path.name):
                order = enabled_ai_order(mask_comments(path.read_text(encoding="utf-8-sig")))
                level_one = order.index(["WFBE_UP_UAV", "1"])
                self.assertEqual(
                    order[level_one + 1],
                    ["WFBE_UP_UAV", "2"],
                    "enabled UAV2 must retain its legacy priority immediately after UAV L1",
                )

    def test_upgrade_files_match_all_maintained_terrains(self) -> None:
        names = [path.name for path in sorted((MAINTAINED_ROOTS[0] / UPGRADE_DIR).glob("Upgrades_*.sqf")) if "WFBE_UP_UAV" in path.read_text(encoding="utf-8-sig")]
        for name in names:
            copies = [(root / UPGRADE_DIR / name).read_bytes() for root in MAINTAINED_ROOTS]
            with self.subTest(path=name):
                self.assertEqual(len(set(copies)), 1)

    def test_level_one_player_uav_remains_available(self) -> None:
        self.assertRegex(code(TACTICAL_MENU), r"_currentLevel\s*>\s*0")


class Uav2FobGateTests(unittest.TestCase):
    def test_common_gate_is_registered(self) -> None:
        self.assertIn(
            'WFBE_CO_FNC_CanUseUAV2FOB = Compile preprocessFileLineNumbers "Common\\Functions\\Common_CanUseUAV2FOB.sqf"',
            code(COMMON_INIT),
        )

    def test_gate_derives_side_role_truck_range_and_upgrade(self) -> None:
        text = code(COMMON_GATE)
        for token in (
            "alive _player",
            "_side != west && {_side != east}",
            "typeOf _player",
            'missionNamespace getVariable ["WFBE_C_UAV2_FOB_ENGINEERS"',
            'Format ["WFBE_%1REPAIRTRUCKS", str _side]',
            "typeOf _truck",
            "side _truck != _side",
            "_player distance _truck",
            "WFBE_CO_FNC_GetSideUpgrades",
            "WFBE_UP_UAV",
            'missionNamespace getVariable ["WFBE_C_UAV2_LEVEL", 2]',
        ):
            with self.subTest(token=token):
                self.assertIn(token, text)

    def test_repair_truck_action_uses_shared_gate(self) -> None:
        text = code(UNIT_INIT)
        self.assertIn("Build UAV2 Forward FOB", text)
        self.assertIn("WFBE_CO_FNC_CanUseUAV2FOB", text)
        self.assertIn("Client\\Action\\Action_BuildUAV2FOB.sqf", text)

    def test_client_only_submits_request(self) -> None:
        text = code(CLIENT_ACTION)
        self.assertIn("WFBE_CO_FNC_CanUseUAV2FOB", text)
        self.assertIn('["RequestUAV2FOB", ["auth", _player, _truck, _challenge]] Call WFBE_CO_FNC_SendToServer', text)
        self.assertIn('["RequestUAV2FOB", ["build", _uid, _token, _pos]] Call WFBE_CO_FNC_SendToServer', text)
        self.assertNotIn('["RequestUAV2FOB", [_player, _truck', text)
        self.assertNotIn("ChangeTeamFunds", text)
        self.assertNotIn("createVehicle", text)

    def test_private_capability_response_is_registered_and_challenge_bound(self) -> None:
        pv = code(PV_INIT)
        client = code(CLIENT_HANDLE_SPECIAL)
        self.assertIn('"WFBE_PVF_UAV2FOBPrivate" addPublicVariableEventHandler', pv)
        self.assertIn('case "uav2-fob-auth-token"', client)
        self.assertIn('wfbe_uav2_fob_auth_challenge_', client)
        self.assertIn('wfbe_uav2_fob_cap_client_', client)


class Uav2FobAuthorityTests(unittest.TestCase):
    def test_server_pvf_is_registered_and_dispatched(self) -> None:
        text = code(PV_INIT)
        self.assertIn('"RequestUAV2FOB"', text)
        self.assertIn("Format['WFBE_PVF_%1',_x] addPublicVariableEventHandler", text)

    def test_server_revalidates_before_reserve_debit_and_spawn(self) -> None:
        text = code(SERVER_REQUEST)
        required = (
            "if (!isServer) exitWith {}",
            'typeName _request != "ARRAY"',
            "WFBE_CO_FNC_CanUseUAV2FOB",
            "_serverPos = _truck modelToWorld",
            "surfaceIsWater _serverPos",
            'missionNamespace getVariable ["WFBE_C_UAV2_FOB_CAP"',
            'missionNamespace getVariable ["WFBE_C_UAV2_FOB_BASE_EXCLUSION"',
            'missionNamespace getVariable ["WFBE_C_UAV2_FOB_SPACING"',
            '_team getVariable "wfbe_funds"',
            "WFBE_CO_FNC_ChangeTeamFunds",
            "createVehicle",
            'createUnit ["LocationLogicCamp"',
        )
        for token in required:
            with self.subTest(token=token):
                self.assertIn(token, text)
        reserve = text.find('missionNamespace setVariable [_reserveKey, time + 10]')
        debit = text.find("WFBE_CO_FNC_ChangeTeamFunds")
        spawn = text.find("createVehicle", debit)
        self.assertGreaterEqual(reserve, 0)
        self.assertGreater(debit, reserve)
        self.assertGreater(spawn, debit)

    def test_server_derives_player_and_truck_from_one_shot_capability(self) -> None:
        text = code(SERVER_REQUEST)
        self.assertIn('if (_mode == "auth") exitWith', text)
        self.assertIn('[_token, _expires, _authPlayer, _authTruck]', text)
        self.assertIn('WFBE_PVF_UAV2FOBPrivate', text)
        self.assertIn('_uid = _request select 1', text)
        self.assertIn('_token = _request select 2', text)
        self.assertIn('_player = _cap select 2', text)
        self.assertIn('_truck = _cap select 3', text)
        consume = text.find('missionNamespace setVariable [_capKey, []]')
        gate = text.find('WFBE_CO_FNC_CanUseUAV2FOB', consume)
        debit = text.find('WFBE_CO_FNC_ChangeTeamFunds', gate)
        self.assertGreaterEqual(consume, 0)
        self.assertGreater(gate, consume)
        self.assertGreater(debit, gate)

    def test_post_debit_spawn_failure_rolls_back_before_registration(self) -> None:
        text = code(SERVER_REQUEST)
        for guard in (
            "if (isNull _tent) then {_spawnOK = false}",
            "if (isNull _mast) then {_spawnOK = false}",
            "if (isNull _campGroup) then {_spawnOK = false}",
            "if (isNull _campLogic) then {_spawnOK = false}",
        ):
            self.assertIn(guard, text)
        debit = text.find('[_team, -_cost] Call WFBE_CO_FNC_ChangeTeamFunds')
        failure = text.find('if (!_spawnOK) exitWith', debit)
        cleanup_tent = text.find('deleteVehicle _tent', failure)
        cleanup_mast = text.find('deleteVehicle _mast', failure)
        cleanup_logic = text.find('deleteVehicle _campLogic', failure)
        cleanup_group = text.find('deleteGroup _campGroup', failure)
        refund = text.find('[_team, _cost] Call WFBE_CO_FNC_ChangeTeamFunds', failure)
        registration = text.find('missionNamespace setVariable [_sideKey, _registry]', refund)
        for offset in (debit, failure, cleanup_tent, cleanup_mast, cleanup_logic, cleanup_group, refund, registration):
            self.assertGreaterEqual(offset, 0)
        self.assertLess(debit, failure)
        self.assertLess(failure, refund)
        self.assertLess(cleanup_tent, refund)
        self.assertLess(cleanup_mast, refund)
        self.assertLess(cleanup_logic, refund)
        self.assertLess(cleanup_group, refund)
        self.assertLess(refund, registration)
        rollback = text[failure:registration]
        self.assertEqual(rollback.count('[_team, _cost] Call WFBE_CO_FNC_ChangeTeamFunds'), 1)
        self.assertEqual(rollback.count('deleteVehicle _tent'), 1)
        self.assertEqual(rollback.count('deleteVehicle _mast'), 1)
        self.assertEqual(rollback.count('deleteVehicle _campLogic'), 1)
        self.assertEqual(rollback.count('deleteGroup _campGroup'), 1)

    def test_server_builds_discoverable_bounded_fob(self) -> None:
        text = code(SERVER_REQUEST)
        for token in (
            'Format ["WFBE_%1FARP", str _side]',
            '"Land_Vysilac_FM"',
            'setVariable ["sideID"',
            'setVariable ["wfbe_camp_bunker"',
            'setVariable ["town", _campLogic, true]',
            "FOBCAMPPROBE",
            'missionNamespace getVariable ["WFBE_C_UAV2_FOB_REPAIR_RADIUS"',
            'missionNamespace getVariable ["WFBE_C_UAV2_FOB_WORKER_INTERVAL"',
            "deleteVehicle _campLogic",
        ):
            with self.subTest(token=token):
                self.assertIn(token, text)


class Uav2SwarmTests(unittest.TestCase):
    def test_server_starts_only_main_side_workers(self) -> None:
        text = code(SERVER_INIT)
        self.assertIn("AICOM_UAV2_Swarm.sqf", text)
        self.assertIn("[west] Spawn WFBE_SE_FNC_AICOM_UAV2_Swarm", text)
        self.assertIn("[east] Spawn WFBE_SE_FNC_AICOM_UAV2_Swarm", text)
        self.assertNotIn("[resistance] Spawn WFBE_SE_FNC_AICOM_UAV2_Swarm", text)

    def test_human_commander_and_upgrade_hard_gates(self) -> None:
        text = code(SWARM)
        self.assertIn("if (!isServer) exitWith {}", text)
        self.assertIn("_side != west && {_side != east}", text)
        self.assertIn("isPlayer (leader _cmdTeam)", text)
        human = text.find("isPlayer (leader _cmdTeam)")
        spawn = text.find("createVehicle")
        self.assertGreater(spawn, human)
        self.assertIn("WFBE_CO_FNC_GetSideUpgrades", text)
        self.assertIn("WFBE_UP_UAV", text)
        self.assertIn('missionNamespace getVariable ["WFBE_C_UAV2_LEVEL", 2]', text)

    def test_budget_frequency_and_lifetime_are_bounded(self) -> None:
        text = code(SWARM)
        for token in (
            'missionNamespace getVariable ["WFBE_C_UAV2_SWARM", 0]',
            'missionNamespace getVariable ["WFBE_C_UAV2_SWARM_INTERVAL"',
            'missionNamespace getVariable ["WFBE_C_UAV2_SWARM_COOLDOWN"',
            'missionNamespace getVariable ["WFBE_C_UAV2_SWARM_MAX_ACTIVE"',
            'missionNamespace getVariable ["WFBE_C_UAV2_SWARM_MAX_PER_STRIKE"',
            'missionNamespace getVariable ["WFBE_C_UAV2_SWARM_COST"',
            'missionNamespace getVariable ["WFBE_C_UAV2_SWARM_TTL"',
            "GetAICommanderFunds",
            "ChangeAICommanderFunds",
        ):
            with self.subTest(token=token):
                self.assertIn(token, text)
        debit = text.find("ChangeAICommanderFunds")
        spawn = text.find("createVehicle", debit)
        self.assertGreater(spawn, debit)
        self.assertIn("UAV2_SWARM_REFUND", read(SWARM))
        self.assertIn("[_side, _refund] Call ChangeAICommanderFunds", text)

    def test_low_frequency_targeting_and_guidance_are_present(self) -> None:
        text = code(SWARM)
        self.assertEqual(text.count("nearEntities"), 1)
        self.assertIn("doMove", text)
        self.assertIn("flyInHeight", text)
        self.assertIn("setVelocity", text)
        self.assertIn("AICOMSTAT|v2|EVENT", read(SWARM))

    def test_swarm_has_no_guer_ka137_state(self) -> None:
        text = code(SWARM).lower()
        for forbidden in ("ka137", "guerairdef", "resistance", "server_guer"):
            with self.subTest(forbidden=forbidden):
                self.assertNotIn(forbidden, text)


class Uav2MirrorAndA2SafetyTests(unittest.TestCase):
    TOUCHED = (
        CONSTANTS,
        COMMON_INIT,
        COMMON_GATE,
        UNIT_INIT,
        PV_INIT,
        CLIENT_ACTION,
        SERVER_REQUEST,
        SWARM,
    )

    def test_touched_files_match_all_maintained_terrains(self) -> None:
        for relative in self.TOUCHED:
            copies = [(root / relative).read_bytes() for root in MAINTAINED_ROOTS]
            with self.subTest(path=str(relative)):
                self.assertEqual(len(set(copies)), 1)

    def test_server_init_uav2_hooks_match_all_terrains(self) -> None:
        tokens = (
            'WFBE_SE_FNC_AICOM_UAV2_Swarm = Compile preprocessFileLineNumbers "Server\\Functions\\AICOM_UAV2_Swarm.sqf"',
            '[west] Spawn WFBE_SE_FNC_AICOM_UAV2_Swarm',
            '[east] Spawn WFBE_SE_FNC_AICOM_UAV2_Swarm',
        )
        for root in MAINTAINED_ROOTS:
            text = mask_comments(read(SERVER_INIT, root))
            for token in tokens:
                with self.subTest(root=root.name, token=token):
                    self.assertIn(token, text)

    def test_new_scripts_avoid_a3_only_commands(self) -> None:
        banned = (
            "isEqualType", "isEqualTo", "pushBack", "findIf", "apply ",
            "remoteExec", "distance2D", "getPosVisual", "selectRandom",
            "params ", "worldSize", "joinGroup", "setGroupOwner",
            "getOrDefault", "deleteAt",
        )
        for relative in (COMMON_GATE, CLIENT_ACTION, SERVER_REQUEST, SWARM):
            text = code(relative)
            for token in banned:
                with self.subTest(path=str(relative), token=token):
                    self.assertNotIn(token, text)


if __name__ == "__main__":
    unittest.main()
