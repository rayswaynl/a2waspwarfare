#!/usr/bin/env python3
"""Regression checks for sender-bound ICBM TEL requests."""

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

TEL_CLIENT = Path("Common/Functions/Common_RequestIcbmTelFire.sqf")
COMMON_INIT = Path("Common/Init/Init_Common.sqf")
PV_INIT = Path("Common/Init/Init_PublicVariables.sqf")
CLIENT_RESULT = Path("Client/PVFunctions/HandleSpecial.sqf")
TACTICAL_MENU = Path("Client/GUI/GUI_Menu_Tactical.sqf")
BUILD_UNIT = Path("Client/Functions/Client_BuildUnit.sqf")
SERVER_SPECIAL = Path("Server/Functions/Server_HandleSpecial.sqf")
TEL_SERVER = Path("Server/Init/Init_IcbmTel.sqf")
MIRRORED_FILES = (
    TEL_CLIENT,
    COMMON_INIT,
    PV_INIT,
    CLIENT_RESULT,
    TACTICAL_MENU,
    BUILD_UNIT,
    SERVER_SPECIAL,
    TEL_SERVER,
)


def read(root: Path, relative: Path) -> str:
    path = root / relative
    if not path.exists():
        return ""
    return path.read_text(encoding="utf-8-sig")


class IcbmTelAuthorityTests(unittest.TestCase):
    def test_client_uses_private_challenge_capability(self) -> None:
        source = read(MAINTAINED_ROOTS[0], TEL_CLIENT)
        code = mask_comments(source)
        self.assertTrue(source, f"missing {TEL_CLIENT}")
        required = (
            'Format ["wfbe_icbm_tel_cap_client_%1", getPlayerUID player]',
            'Format ["wfbe_icbm_tel_auth_challenge_%1", getPlayerUID player]',
            '["icbm-tel-auth",player,_challenge] Call _sendTelToServer',
            '"icbm-tel-fire",_side,_target,_muni,_team,_fee,_platform,player,_token',
            'publicVariableServer "WFBE_PVF_RequestSpecial"',
        )
        for token in required:
            with self.subTest(token=token):
                self.assertIn(token, code)
        self.assertNotIn("WFBE_CO_FNC_SendToServer", code)

        common_init = mask_comments(read(MAINTAINED_ROOTS[0], COMMON_INIT))
        self.assertIn(
            'WFBE_CO_FNC_RequestIcbmTelFire = Compile preprocessFileLineNumbers '
            '"Common\\Functions\\Common_RequestIcbmTelFire.sqf"',
            common_init,
        )

    def test_private_response_is_challenge_bound(self) -> None:
        pv_init = mask_comments(read(MAINTAINED_ROOTS[0], PV_INIT))
        self.assertIn(
            '"WFBE_PVF_IcbmTelPrivate" addPublicVariableEventHandler '
            '{(_this select 1) Spawn WFBE_CL_FNC_HandlePVF}',
            pv_init,
        )

        result = mask_comments(read(MAINTAINED_ROOTS[0], CLIENT_RESULT))
        required = (
            'case "icbm-tel-auth-token"',
            'Format ["wfbe_icbm_tel_auth_challenge_%1", getPlayerUID player]',
            '_telChallenge != (missionNamespace getVariable [_telChallengeKey, ""])',
            'Format ["wfbe_icbm_tel_cap_client_%1", getPlayerUID player]',
        )
        for token in required:
            with self.subTest(token=token):
                self.assertIn(token, result)

    def test_server_binds_and_consumes_capability_before_side_effects(self) -> None:
        server = mask_comments(read(MAINTAINED_ROOTS[0], TEL_SERVER))
        start = server.find("WFBE_SE_FNC_IcbmTelFire = {")
        self.assertGreaterEqual(start, 0, "missing ICBM TEL fire function")
        end = server.find("WFBE_SE_FNC_IcbmTelSteelRain = {", start)
        self.assertGreaterEqual(end, 0, "missing STEELRAIN function boundary")
        fire = server[start:end]
        required = (
            "_authPlayer = if (count _this > 7)",
            "_authToken = if (count _this > 8)",
            "_authPlayer != leader _playerTeam",
            "group _authPlayer != _playerTeam",
            "side (group _authPlayer) != _side",
            "getPlayerUID _authPlayer",
            'Format ["wfbe_icbm_tel_cap_server_%1", _authUID]',
            "_authToken != (_authCap select 0)",
            "missionNamespace setVariable [_authCapKey, []]",
            "_commanderTeam = _side Call WFBE_CO_FNC_GetCommanderTeam",
            "_playerTeam != _commanderTeam",
            "!(_authPlayer in crew _platformHint)",
            'Format ["WFBE_TK_SCUD_PLATFORMS_%1", str _side]',
            '_platformHint getVariable ["wfbe_tk_scud_side", sideUnknown]',
            "_caller = _authPlayer",
        )
        for token in required:
            with self.subTest(token=token):
                self.assertIn(token, fire)

        consume = fire.find("missionNamespace setVariable [_authCapKey, []]")
        platform = fire.find('_telKey = Format ["WFBE_ICBM_TEL_%1", _sideText]')
        debit = fire.find("WFBE_CO_FNC_ChangeTeamFunds")
        caller = fire.find("_caller = _authPlayer")
        for name, position in (
            ("capability consumption", consume),
            ("platform selection", platform),
            ("fund debit", debit),
            ("caller binding", caller),
        ):
            with self.subTest(ordering_marker=name):
                self.assertGreaterEqual(position, 0)
        self.assertLess(consume, platform)
        self.assertLess(consume, debit)
        self.assertLess(consume, caller)

    def test_request_handler_forwards_player_and_token(self) -> None:
        handler = mask_comments(read(MAINTAINED_ROOTS[0], SERVER_SPECIAL))
        required = (
            'case "icbm-tel-auth"',
            "if (count _args != 3) exitWith",
            "[_tAuthPlayer, _tChallenge] Call WFBE_SE_FNC_IcbmTelAuth",
            "if (count _args != 9) exitWith",
            "_tPlayer = if (count _args > 7)",
            "_tToken = if (count _args > 8)",
            "[_tSide, _tTarget, _tMuni, _tTeam, _tFee, _tPlat, sideUnknown, _tPlayer, _tToken] Spawn WFBE_SE_FNC_IcbmTelFire",
        )
        for token in required:
            with self.subTest(token=token):
                self.assertIn(token, handler)

    def test_all_human_call_sites_use_the_authorized_helper(self) -> None:
        tactical = mask_comments(read(MAINTAINED_ROOTS[0], TACTICAL_MENU))
        build = mask_comments(read(MAINTAINED_ROOTS[0], BUILD_UNIT))
        self.assertNotIn('["RequestSpecial", ["icbm-tel-fire"', tactical)
        self.assertNotIn('["RequestSpecial", ["icbm-tel-fire"', build)
        self.assertEqual(
            tactical.count("Spawn WFBE_CO_FNC_RequestIcbmTelFire"), 6
        )
        self.assertEqual(build.count("Spawn WFBE_CO_FNC_RequestIcbmTelFire"), 1)

    def test_all_generated_copies_match_source(self) -> None:
        for relative in MIRRORED_FILES:
            with self.subTest(path=str(relative)):
                paths = [root / relative for root in MAINTAINED_ROOTS]
                for path in paths:
                    self.assertTrue(path.exists(), f"missing {path}")
                copies = [path.read_bytes() for path in paths]
                self.assertEqual(len(set(copies)), 1)


if __name__ == "__main__":
    unittest.main()
