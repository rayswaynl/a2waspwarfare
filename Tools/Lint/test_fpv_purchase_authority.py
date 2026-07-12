#!/usr/bin/env python3
"""Regression checks for server-authoritative FPV purchases."""

from __future__ import annotations

import unittest
import re
from pathlib import Path

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
MAINTAINED_ROOTS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)

FPV_CLIENT = Path("Client/Module/FPV/fpv.sqf")
FPV_SERVER = Path("Server/Support/Support_FPV.sqf")
CLIENT_RESULT = Path("Client/PVFunctions/HandleSpecial.sqf")
GUER_MENU = Path("Client/GUI/GUI_Menu_GuerDrones.sqf")
TACTICAL_MENU = Path("Client/GUI/GUI_Menu_Tactical.sqf")
PV_INIT = Path("Common/Init/Init_PublicVariables.sqf")
FILE_ROOTS = {
    FPV_CLIENT: MAINTAINED_ROOTS,
    FPV_SERVER: MAINTAINED_ROOTS,
    CLIENT_RESULT: MAINTAINED_ROOTS,
    GUER_MENU: MAINTAINED_ROOTS,
    TACTICAL_MENU: MAINTAINED_ROOTS,
    PV_INIT: MAINTAINED_ROOTS,
}


def read(root: Path, relative: Path) -> str:
    return (root / relative).read_text(encoding="utf-8-sig")


class FpvPurchaseAuthorityTests(unittest.TestCase):
    def test_client_requests_authority_without_debiting_locally(self) -> None:
        text = read(MAINTAINED_ROOTS[0], FPV_CLIENT)
        code = mask_comments(text)
        self.assertNotIn("call changeplayerfunds", text.lower())
        self.assertNotIn("Call UpdateStatistics", text)
        self.assertIn(
            '["fpv","auth",player,_challenge] Call _sendFpvToServer', code
        )
        self.assertIn(
            '["fpv","purchase",sideJoined,_drone,clientTeam,player,_driver,_token] Call _sendFpvToServer',
            code,
        )
        self.assertIn('Format ["wfbe_fpv_next_%1", getPlayerUID player]', text)
        self.assertIn('Format ["wfbe_fpv_cap_client_%1", getPlayerUID player]', code)
        self.assertIn('publicVariableServer "WFBE_PVF_RequestSpecial"', code)
        self.assertIn("vehicle _driver != _drone", code)
        purchase = code.find(
            '["fpv","purchase",sideJoined,_drone,clientTeam,player,_driver,_token] Call _sendFpvToServer'
        )
        launch_log = code.find('fpv.sqf: FPV strike drone [%1] launched', purchase)
        self.assertGreaterEqual(purchase, 0)
        self.assertGreater(launch_log, purchase)
        pending_result = code[purchase:launch_log]
        self.assertIn("_purchaseStatus != 0", pending_result)
        self.assertIn(
            '["fpv","status",player,_drone,_driver,_token] Call _sendFpvToServer',
            pending_result,
        )
        self.assertNotIn("_purchaseDeadline", pending_result)
        self.assertNotIn("deleteVehicle", pending_result)
        self.assertNotIn('missionNamespace setVariable [_resultKey, ""]', pending_result)
        self.assertLess(
            code.find('["fpv","auth",player,_challenge] Call _sendFpvToServer'),
            code.find("_drone = createVehicle"),
        )

    def test_server_validates_wallet_and_per_uid_rearm_before_registering(self) -> None:
        text = read(MAINTAINED_ROOTS[0], FPV_SERVER)
        code = mask_comments(text)
        required = (
            "count _args < 2",
            '_mode == "auth"',
            "count _args < 8",
            '_mode == "status"',
            "_argPlayer = _args select 5",
            "_argDriver = _args select 6",
            "_argToken = _args select 7",
            "_player = _argPlayer",
            "_playerTeam != group _player",
            "_side = side (group _player)",
            "_side != _clientSide",
            "getPlayerUID _player",
            'Format ["wfbe_fpv_next_%1", _uid]',
            'Format ["wfbe_fpv_active_%1", _uid]',
            'Format ["wfbe_fpv_purchase_inflight_%1", _uid]',
            'Format ["wfbe_fpv_purchase_result_server_%1", _uid]',
            'missionNamespace getVariable [_nextKey, 0]',
            'missionNamespace getVariable ["WFBE_C_FPV_COOLDOWN", 60]',
            'missionNamespace getVariable ["WFBE_C_FPV_DRONE_COST", 7500]',
            'missionNamespace getVariable ["WFBE_C_FPV_DRONE_COST_GUER", 5000]',
            'missionNamespace getVariable ["WFBE_C_FPV_DRONE", 0]',
            'Format ["WFBE_%1FPVDRONE", str _side]',
            "typeOf _drone != _expectedClass",
            "owner _drone != _replyId",
            "owner _driver != _replyId",
            "isPlayer _driver",
            'if (_deny == "" && {!alive _drone})',
            'if (_deny == "" && {!alive _driver})',
            "driver _drone != _driver",
            'Format ["wfbe_fpv_cap_server_%1", _uid]',
            "_capExpires <= time",
            "_argToken != (_cap select 0)",
            "missionNamespace setVariable [_capKey, []]",
            '_id publicVariableClient "WFBE_PVF_FPVPrivate"',
            "missionNamespace setVariable [_activeKey, _drone]",
            '_playerTeam getVariable "wfbe_funds"',
            "[_playerTeam, -_cost] Call WFBE_CO_FNC_ChangeTeamFunds",
            "missionNamespace setVariable [_nextKey, _next]",
            "publicVariable _nextKey",
            '"fpv-purchase-result"',
        )
        for token in required:
            with self.subTest(token=token):
                self.assertIn(token, code)

        denial = code.find('if (_deny != "") exitWith')
        cap_expiry = code.find("_capExpires <= time")
        cap_match = code.find("_argToken != (_cap select 0)")
        cap_consume = code.find("missionNamespace setVariable [_capKey, []]")
        bound = code.find("_requestBound = true", cap_consume)
        inflight = code.find(
            "missionNamespace setVariable [_inflightKey, _argToken]", cap_consume
        )
        seat_check = code.find("driver _drone != _driver", bound)
        reserve = code.find("missionNamespace setVariable [_activeKey, _drone]")
        debit = code.find("[_playerTeam, -_cost] Call WFBE_CO_FNC_ChangeTeamFunds")
        register = code.find('_fpvKey = Format ["wfbe_fpv_det_arr_%1", str _side]')
        watchdog = code.find("while {true} do")
        rearm_calc = code.find("_next = time + _cooldown", watchdog)
        rearm_stamp = code.find(
            "missionNamespace setVariable [_nextKey, _next]", watchdog
        )
        publish = code.find("publicVariable _nextKey", rearm_stamp)
        self.assertGreaterEqual(debit, 0)
        self.assertGreaterEqual(denial, 0)
        self.assertGreaterEqual(cap_expiry, 0)
        self.assertGreaterEqual(cap_match, 0)
        self.assertGreaterEqual(cap_consume, 0)
        self.assertGreaterEqual(bound, 0)
        self.assertGreaterEqual(inflight, 0)
        self.assertGreaterEqual(seat_check, 0)
        self.assertGreaterEqual(reserve, 0)
        self.assertGreaterEqual(register, 0)
        self.assertGreaterEqual(watchdog, 0)
        self.assertGreaterEqual(rearm_calc, 0)
        self.assertGreaterEqual(rearm_stamp, 0)
        self.assertGreaterEqual(publish, 0)
        if min(
            cap_match,
            cap_expiry,
            cap_consume,
            inflight,
            bound,
            seat_check,
            denial,
            reserve,
            debit,
            register,
            watchdog,
            rearm_calc,
            rearm_stamp,
            publish,
        ) >= 0:
            self.assertLess(cap_match, cap_consume)
            self.assertLess(cap_consume, inflight)
            self.assertLess(inflight, bound)
            self.assertLess(cap_consume, bound)
            self.assertLess(bound, cap_expiry)
            self.assertLess(bound, seat_check)
            self.assertLess(seat_check, denial)
            self.assertLess(denial, reserve)
            self.assertLess(reserve, debit)
            self.assertLess(debit, register)
            self.assertLess(register, watchdog)
            self.assertLess(watchdog, rearm_calc)
            self.assertLess(rearm_calc, rearm_stamp)
            self.assertLess(rearm_stamp, publish)

    def test_server_denial_fails_closed_and_only_cleans_a_bound_request(self) -> None:
        text = read(MAINTAINED_ROOTS[0], FPV_SERVER)
        code = mask_comments(text)
        self.assertIn(
            'then {_deny = "FPV cost configuration is invalid."}', text
        )
        self.assertNotIn(
            'if (typeName _cost != "SCALAR" || {_cost < 0}) then {_cost = 0}',
            code,
        )
        self.assertIn(
            '["fpv-purchase-result", false, _next, _deny, _drone, _driver, _argToken]',
            code,
        )
        self.assertIn('if (_requestBound) then', code)
        denial = code[code.find('if (_deny != "") exitWith') :]
        denial = denial[: denial.find("missionNamespace setVariable [_activeKey")]
        self.assertNotIn("deleteVehicle", denial)
        self.assertNotIn('setVariable ["wfbe_fpv_armed"', denial)
        self.assertNotIn("WFBE_CO_FNC_SendToClients", code)

    def test_authenticated_precondition_denials_return_a_correlated_result(self) -> None:
        text = read(MAINTAINED_ROOTS[0], FPV_SERVER)
        code = mask_comments(text)
        cap_consume = code.find("missionNamespace setVariable [_capKey, []]")
        self.assertGreaterEqual(cap_consume, 0)
        deny_assignments = tuple(
            match
            for match in re.finditer(
                r'_deny\s*=\s*(?:"[^"]*"|Format\s*\[)', code
            )
            if match.group(0).replace(" ", "") != '_deny=""'
        )
        self.assertGreater(len(deny_assignments), 10)
        for match in deny_assignments:
            with self.subTest(assignment=match.group(0)):
                self.assertGreater(match.start(), cap_consume)

        self.assertIn("_replyId = owner _player", code)
        self.assertLess(code.find("_replyId = owner _player"), cap_consume)
        sender = code[code.find("_sendPrivate = {") : code.find("_args = _this")]
        self.assertIn("_id = _this select 2", sender)
        self.assertIn("_targetUID = _this select 3", sender)
        self.assertLess(sender.find("_id = _this select 2"), sender.find("_pvf = ["))
        self.assertLess(
            sender.find("_targetUID = _this select 3"), sender.find("_pvf = [")
        )
        atomic_targeted_send = (
            'isNil {WFBE_PVF_FPVPrivate = _pvf; '
            '_id publicVariableClient "WFBE_PVF_FPVPrivate"}'
        )
        self.assertEqual(sender.count(atomic_targeted_send), 2)
        self.assertEqual(sender.count('publicVariableClient "WFBE_PVF_FPVPrivate"'), 2)
        self.assertNotIn("WFBE_PVF_HandleSpecial", sender)
        self.assertIn(
            '_result = ["fpv-purchase-result", false, _next, _deny, _drone, _driver, _argToken]',
            code,
        )
        self.assertIn(
            '_result = ["fpv-purchase-result", true, _next, "", _drone, _driver, _argToken]',
            code,
        )
        self.assertIn(
            "[_player, _result, _replyId, _uid] Call _sendPrivate", code
        )
        denial = code[code.find('if (_deny != "") exitWith') :]
        denial = denial[: denial.find("missionNamespace setVariable [_activeKey")]
        self.assertNotIn("isPlayer _player", denial)

    def test_server_replays_or_recovers_ambiguous_purchase_results(self) -> None:
        text = read(MAINTAINED_ROOTS[0], FPV_SERVER)
        code = mask_comments(text)
        self.assertIn('if (_mode == "status") exitWith', code)
        self.assertIn(
            '["fpv","status",player,_drone,_driver,_token] Call _sendFpvToServer',
            mask_comments(read(MAINTAINED_ROOTS[0], FPV_CLIENT)),
        )
        self.assertIn("isNil {", code)
        self.assertIn(
            'missionNamespace setVariable [_resultKey, _result]', code
        )
        self.assertIn(
            'missionNamespace setVariable [_inflightKey, ""]', code
        )
        result_store = code.find(
            "missionNamespace setVariable [_resultKey, _result]"
        )
        result_send = code.find(
            "[_player, _result, _replyId, _uid] Call _sendPrivate", result_store
        )
        self.assertGreaterEqual(result_store, 0)
        self.assertGreater(result_send, result_store)

        status = code[code.find('if (_mode == "status") exitWith') :]
        status = status[: status.find('if (_mode != "purchase") exitWith')]
        authenticated_recovery = (
            'if (typeName _statusCap == "ARRAY" && {count _statusCap >= 1} '
            '&& {typeName (_statusCap select 0) == "STRING"} '
            '&& {(_statusCap select 0) == _statusToken}) then {\n'
            '\t\t\t\t\t\tmissionNamespace setVariable [_statusCapKey, []];\n'
            '\t\t\t\t\t\t_statusNext = missionNamespace getVariable '
            '[Format ["wfbe_fpv_next_%1", _statusUID], 0];\n'
            '\t\t\t\t\t\tif (typeName _statusNext != "SCALAR") then '
            '{_statusNext = 0};\n'
            '\t\t\t\t\t\t_statusResult = ["fpv-purchase-result", false, '
            '_statusNext, "FPV purchase was not completed. Try again.", '
            '_statusDrone, _statusDriver, _statusToken];\n'
            '\t\t\t\t\t\tmissionNamespace setVariable '
            '[_statusResultKey, _statusResult];\n'
            '\t\t\t\t\t\t_statusState = 1;\n'
            '\t\t\t\t\t};'
        )
        self.assertIn(authenticated_recovery, status)
        self.assertEqual(status.count("FPV purchase was not completed. Try again."), 1)

        success_start = code.find(
            '_result = ["fpv-purchase-result", true, _next, "", '
            '_drone, _driver, _argToken]'
        )
        success_end = code.find("_timeStart = time", success_start)
        self.assertGreaterEqual(success_start, 0)
        self.assertGreater(success_end, success_start)
        success = code[success_start:success_end]
        atomic = success.find("isNil {")
        debit = success.find(
            "[_playerTeam, -_cost] Call WFBE_CO_FNC_ChangeTeamFunds"
        )
        cache = success.find(
            "missionNamespace setVariable [_resultKey, _result]"
        )
        clear = success.find('missionNamespace setVariable [_inflightKey, ""]')
        send = success.find(
            "[_player, _result, _replyId, _uid] Call _sendPrivate"
        )
        for label, position in (
            ("atomic", atomic),
            ("debit", debit),
            ("cache", cache),
            ("clear", clear),
            ("send", send),
        ):
            with self.subTest(success_step=label):
                self.assertGreaterEqual(position, 0)
        if min(atomic, debit, cache, clear, send) >= 0:
            self.assertLess(atomic, debit)
            self.assertLess(debit, cache)
            self.assertLess(cache, clear)
            self.assertLess(clear, send)

    def test_private_result_transport_has_a_dedicated_client_receiver(self) -> None:
        text = read(MAINTAINED_ROOTS[0], PV_INIT)
        code = mask_comments(text)
        self.assertIn(
            '"WFBE_PVF_FPVPrivate" addPublicVariableEventHandler '
            '{(_this select 1) Spawn WFBE_CL_FNC_HandlePVF}',
            code,
        )

    def test_client_result_handles_denial_and_authoritative_stamp(self) -> None:
        text = read(MAINTAINED_ROOTS[0], CLIENT_RESULT)
        code = mask_comments(text)
        self.assertIn('case "fpv-auth-token"', code)
        self.assertIn('Format ["wfbe_fpv_cap_client_%1", getPlayerUID player]', code)
        self.assertIn(
            '_fpvAuthChallenge != (missionNamespace getVariable [_fpvChallengeKey, ""])',
            code,
        )
        self.assertIn('case "fpv-purchase-result"', code)
        self.assertIn('Format ["wfbe_fpv_next_%1", getPlayerUID player]', code)
        self.assertIn('playerFPV setVariable ["wfbe_fpv_armed", false]', code)
        self.assertIn("deleteVehicle _fpvDriver", code)
        self.assertIn("!isPlayer _fpvDriver", code)
        self.assertIn("deleteVehicle playerFPV", code)
        self.assertIn("playerFPV = objNull", code)
        self.assertIn("_fpvDrone == playerFPV", code)
        self.assertIn("_fpvToken == _fpvExpectedToken", code)
        self.assertIn("deleteGroup _fpvGroup", code)
        self.assertIn("_fpvTokenAccepted = false", code)
        atomic_consume = (
            'isNil {\n'
            '\t\t\t_fpvExpectedToken = missionNamespace getVariable '
            '[_fpvResultKey, ""];\n'
            '\t\t\tif (_fpvExpectedToken != "" && '
            '{_fpvToken == _fpvExpectedToken}) then {\n'
            '\t\t\t\tmissionNamespace setVariable [_fpvResultKey, ""];\n'
            '\t\t\t\t_fpvTokenAccepted = true;\n'
            '\t\t\t};\n'
            '\t\t};\n'
            '\t\tif (!_fpvTokenAccepted) exitWith {};'
        )
        self.assertIn(atomic_consume, code)

    def test_menus_read_only_the_server_owned_rearm_stamp(self) -> None:
        for relative in (GUER_MENU, TACTICAL_MENU):
            text = read(MAINTAINED_ROOTS[0], relative)
            with self.subTest(path=str(relative)):
                self.assertIn(
                    'Format ["wfbe_fpv_next_%1", getPlayerUID player]', text
                )
                self.assertNotIn('"wfbe_fpv_guer_cooldown"', text)
                self.assertNotIn('"wfbe_fpv_cooldown"', text)

    def test_all_generated_copies_match_source(self) -> None:
        for relative, roots in FILE_ROOTS.items():
            copies = [(root / relative).read_bytes() for root in roots]
            with self.subTest(path=str(relative)):
                self.assertEqual(len(set(copies)), 1)


if __name__ == "__main__":
    unittest.main()
