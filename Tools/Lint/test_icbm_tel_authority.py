#!/usr/bin/env python3
"""Regression checks for sender-bound ICBM/TEL fire and SCUD purchase proof."""

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
TEL_PURCHASE = Path("Common/Functions/Common_RequestIcbmTelPurchase.sqf")
TEL_REGISTER = Path("Common/Functions/Common_RequestIcbmTelRegister.sqf")
COMMON_INIT = Path("Common/Init/Init_Common.sqf")
PV_INIT = Path("Common/Init/Init_PublicVariables.sqf")
CLIENT_RESULT = Path("Client/PVFunctions/HandleSpecial.sqf")
TACTICAL_MENU = Path("Client/GUI/GUI_Menu_Tactical.sqf")
BUY_MENU = Path("Client/GUI/GUI_Menu_BuyUnits.sqf")
BUILD_UNIT = Path("Client/Functions/Client_BuildUnit.sqf")
SERVER_SPECIAL = Path("Server/Functions/Server_HandleSpecial.sqf")
TEL_SERVER = Path("Server/Init/Init_IcbmTel.sqf")
MIRRORED_FILES = (
    TEL_CLIENT,
    TEL_PURCHASE,
    TEL_REGISTER,
    COMMON_INIT,
    PV_INIT,
    CLIENT_RESULT,
    TACTICAL_MENU,
    BUY_MENU,
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
    def test_fire_client_uses_private_challenge_capability(self) -> None:
        source = mask_comments(read(MAINTAINED_ROOTS[0], TEL_CLIENT))
        required = (
            'Format ["wfbe_icbm_tel_cap_client_%1", getPlayerUID player]',
            'Format ["wfbe_icbm_tel_auth_challenge_%1", getPlayerUID player]',
            '["icbm-tel-auth",player,_challenge] Call _sendTelToServer',
            '"icbm-tel-fire",_side,_target,_muni,_team,_fee,_platform,player,_token',
            'publicVariableServer "WFBE_PVF_RequestSpecial"',
        )
        for token in required:
            with self.subTest(token=token):
                self.assertIn(token, source)
        self.assertNotIn("WFBE_CO_FNC_SendToServer", source)

    def test_scud_purchase_and_registration_use_server_proof(self) -> None:
        purchase = mask_comments(read(MAINTAINED_ROOTS[0], TEL_PURCHASE))
        registration = mask_comments(read(MAINTAINED_ROOTS[0], TEL_REGISTER))
        required_purchase = (
            'Format ["wfbe_icbm_tel_purchase_challenge_%1", _uid]',
            '["icbm-tel-purchase-auth",player,_challenge,_factory,_unit] Call _sendTelToServer',
            '_params set [6, _token]',
            '_params Spawn BuildUnit',
            'publicVariableServer "WFBE_PVF_RequestSpecial"',
        )
        for token in required_purchase:
            with self.subTest(purchase_token=token):
                self.assertIn(token, purchase)
        required_registration = (
            'if (typeName _this != "ARRAY" || {count _this != 5}) exitWith {}',
            '["icbm-tel-register",_vehicle,_side,_team,_player,_token] Call _sendTelToServer',
            'publicVariableServer "WFBE_PVF_RequestSpecial"',
        )
        for token in required_registration:
            with self.subTest(registration_token=token):
                self.assertIn(token, registration)
        self.assertNotIn("WFBE_CO_FNC_SendToServer", purchase + registration)

        common_init = mask_comments(read(MAINTAINED_ROOTS[0], COMMON_INIT))
        for function, filename in (
            ("WFBE_CO_FNC_RequestIcbmTelFire", "Common_RequestIcbmTelFire.sqf"),
            ("WFBE_CO_FNC_RequestIcbmTelPurchase", "Common_RequestIcbmTelPurchase.sqf"),
            ("WFBE_CO_FNC_RequestIcbmTelRegister", "Common_RequestIcbmTelRegister.sqf"),
        ):
            with self.subTest(function=function):
                self.assertIn(function, common_init)
                self.assertIn(filename, common_init)

    def test_private_responses_are_challenge_bound(self) -> None:
        pv_init = mask_comments(read(MAINTAINED_ROOTS[0], PV_INIT))
        self.assertIn(
            '"WFBE_PVF_IcbmTelPrivate" addPublicVariableEventHandler '
            '{(_this select 1) Spawn WFBE_CL_FNC_HandlePVF}',
            pv_init,
        )

        result = mask_comments(read(MAINTAINED_ROOTS[0], CLIENT_RESULT))
        required = (
            'case "icbm-tel-auth-token"',
            '_telChallenge != (missionNamespace getVariable [_telChallengeKey, ""])',
            'case "icbm-tel-purchase-token"',
            'Format ["wfbe_icbm_tel_purchase_challenge_%1", getPlayerUID player]',
            '_buyChallenge != (missionNamespace getVariable [_buyChallengeKey, ""])',
            'Format ["wfbe_icbm_tel_purchase_cap_client_%1", getPlayerUID player]',
        )
        for token in required:
            with self.subTest(token=token):
                self.assertIn(token, result)

    def test_server_binds_and_consumes_fire_capability_before_side_effects(self) -> None:
        server = mask_comments(read(MAINTAINED_ROOTS[0], TEL_SERVER))
        start = server.find("WFBE_SE_FNC_IcbmTelFire = {")
        end = server.find("WFBE_SE_FNC_IcbmTelSteelRain = {", start)
        self.assertGreaterEqual(start, 0)
        self.assertGreaterEqual(end, 0)
        fire = server[start:end]
        required = (
            "_authPlayer != leader _playerTeam",
            "group _authPlayer != _playerTeam",
            "side (group _authPlayer) != _side",
            "getPlayerUID _authPlayer",
            'Format ["wfbe_icbm_tel_cap_server_%1", _authUID]',
            "_authToken != (_authCap select 0)",
            "missionNamespace setVariable [_authCapKey, []]",
            "_commanderTeam = _side Call WFBE_CO_FNC_GetCommanderTeam",
            "!(_authPlayer in crew _platformHint)",
            'Format ["WFBE_TK_SCUD_PLATFORMS_%1", str _side]',
            'typeOf _platformHint != (missionNamespace getVariable ["WFBE_C_TK_SCUD_HF_TYPE", "MAZ_543_SCUD_TK_EP1"])',
            'typeName (_target select 0) != "SCALAR"',
            'typeName (_target select 1) != "SCALAR"',
            "_caller = _authPlayer",
        )
        for token in required:
            with self.subTest(token=token):
                self.assertIn(token, fire)

        consume = fire.find("missionNamespace setVariable [_authCapKey, []]")
        platform = fire.find('_telKey = Format ["WFBE_ICBM_TEL_%1", _sideText]')
        debit = fire.find("WFBE_CO_FNC_ChangeTeamFunds")
        self.assertGreaterEqual(consume, 0)
        self.assertLess(consume, platform)
        self.assertLess(consume, debit)

    def test_handlers_enforce_exact_payload_shapes(self) -> None:
        handler = mask_comments(read(MAINTAINED_ROOTS[0], SERVER_SPECIAL))
        required = (
            'case "icbm-tel-auth"',
            "if (count _args != 3) exitWith",
            "if (count _args != 9) exitWith",
            "[_tSide, _tTarget, _tMuni, _tTeam, _tFee, _tPlat, sideUnknown, _tPlayer, _tToken] Spawn WFBE_SE_FNC_IcbmTelFire",
            'case "icbm-tel-purchase-auth"',
            "if (count _args != 5) exitWith",
            'case "icbm-tel-register"',
            "if (count _args != 6) exitWith",
        )
        for token in required:
            with self.subTest(token=token):
                self.assertIn(token, handler)
        self.assertNotIn('case "tk-scud-register"', handler)

    def test_purchase_proof_binds_authoritative_inputs(self) -> None:
        server = mask_comments(read(MAINTAINED_ROOTS[0], TEL_SERVER))
        start = server.find("WFBE_SE_FNC_IcbmTelPurchaseAuth = {")
        end = server.find("WFBE_SE_FNC_TkScudAllPlatforms = {", start)
        self.assertGreaterEqual(start, 0)
        self.assertGreaterEqual(end, 0)
        purchase = server[start:end]
        required = (
            "getPlayerUID _authPlayer",
            "_authPlayer != leader _team",
            "_factory in (_side Call WFBE_CO_FNC_GetSideStructures)",
            '(_factoryTypes select _factoryIndex) != "Heavy"',
            '_unitType != (missionNamespace getVariable ["WFBE_C_TK_SCUD_HF_TYPE", "MAZ_543_SCUD_TK_EP1"])',
            "_unitData select QUERYUNITPRICE",
            "_unitData select QUERYUNITTIME",
            "_unitData select QUERYUNITUPGRADE",
            "_unitData select QUERYUNITFACTORY",
            "_team Call WFBE_CO_FNC_GetTeamFunds",
            'Format ["wfbe_icbm_tel_purchase_cap_server_%1", _authUID]',
            "[_token,_expires,_notBefore,_factory,_unitType,_team,_side,_cost,_authUID]",
            '_replyId publicVariableClient "WFBE_PVF_IcbmTelPrivate"',
        )
        for token in required:
            with self.subTest(token=token):
                self.assertIn(token, purchase)

    def test_registration_consumes_proof_before_debit_registry_or_deletion(self) -> None:
        server = mask_comments(read(MAINTAINED_ROOTS[0], TEL_SERVER))
        start = server.find("WFBE_SE_FNC_TkScudRegister = {")
        end = server.find("WFBE_SE_FNC_IcbmTelPurchaseAuth = {", start)
        self.assertGreaterEqual(start, 0)
        self.assertGreaterEqual(end, 0)
        register = server[start:end]
        required = (
            'Format ["wfbe_icbm_tel_purchase_cap_server_%1", _authUID]',
            "missionNamespace setVariable [_proofKey, []]",
            "_proofClass != typeOf _veh",
            "_proofTeam != _team",
            "_proofSide != _side",
            "_proofUID != _authUID",
            "owner _veh != owner _authPlayer",
            "_veh distance _proofFactory",
            'typeOf _veh != (missionNamespace getVariable ["WFBE_C_TK_SCUD_HF_TYPE", "MAZ_543_SCUD_TK_EP1"])',
            "[_team, -_cost] Call WFBE_CO_FNC_ChangeTeamFunds",
        )
        for token in required:
            with self.subTest(token=token):
                self.assertIn(token, register)
        self.assertNotIn("_refund", register)

        consume = register.find("missionNamespace setVariable [_proofKey, []]")
        registry = register.find('Format ["WFBE_TK_SCUD_PLATFORMS_%1", str _side]')
        debit = register.find("WFBE_CO_FNC_ChangeTeamFunds")
        deletion = register.find("deleteVehicle _veh")
        for position in (consume, registry, debit, deletion):
            self.assertGreaterEqual(position, 0)
        self.assertLess(consume, registry)
        self.assertLess(consume, debit)
        self.assertLess(consume, deletion)

    def test_all_human_call_sites_use_authorized_helpers(self) -> None:
        tactical = mask_comments(read(MAINTAINED_ROOTS[0], TACTICAL_MENU))
        buy = mask_comments(read(MAINTAINED_ROOTS[0], BUY_MENU))
        build = mask_comments(read(MAINTAINED_ROOTS[0], BUILD_UNIT))
        self.assertEqual(tactical.count("Spawn WFBE_CO_FNC_RequestIcbmTelFire"), 6)
        self.assertEqual(build.count("Spawn WFBE_CO_FNC_RequestIcbmTelFire"), 1)
        self.assertEqual(buy.count("Spawn WFBE_CO_FNC_RequestIcbmTelPurchase"), 1)
        self.assertEqual(build.count("Spawn WFBE_CO_FNC_RequestIcbmTelRegister"), 1)
        self.assertNotIn('["RequestSpecial", ["icbm-tel-fire"', tactical + build)
        self.assertNotIn('["RequestSpecial", ["tk-scud-register"', build)
        self.assertIn("_currentCost - _baseHullCost", buy)
        self.assertIn('_closest getVariable ["queu", []]', buy)
        self.assertIn("count _scudQueue > 0", buy)
        self.assertIn("_scudProof = if (count _this > 6)", build)

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
