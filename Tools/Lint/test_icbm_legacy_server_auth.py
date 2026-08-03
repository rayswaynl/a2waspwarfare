#!/usr/bin/env python3
"""Regression checks for the flag-gated legacy ICBM RequestSpecial server validation.

Fleet wasp-icbm-legacy-handler-unvalidated-20260724 / audit SEC-PVF-2:
Server_HandleSpecial.sqf case "ICBM" ran with zero validation, letting any client
fire a free, repeatable, unlimited-range area-wipe. The case is now gated behind
WFBE_C_ICBM_LEGACY_SERVER_AUTH (default 0, original block preserved) with a
server-authoritative branch: TEL-mode refuse, payload shape, module gate, playable
side, team-side match, commander-team binding, SCUD level >= 2, per-side cooldown
and a server-side fee charge. The classic client stops debiting at click while the
flag is armed so the commander is never double-charged.
"""

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

SERVER_SPECIAL = Path("Server/Functions/Server_HandleSpecial.sqf")
TACTICAL_MENU = Path("Client/GUI/GUI_Menu_Tactical.sqf")
COMMON_CONSTANTS = Path("Common/Init/Init_CommonConstants.sqf")


def read(root: Path, relative: Path) -> str:
    path = root / relative
    if not path.exists():
        return ""
    return path.read_text(encoding="utf-8-sig")


class IcbmLegacyServerAuthTests(unittest.TestCase):
    def test_case_icbm_is_flag_gated_with_original_preserved(self) -> None:
        for root in MAINTAINED_ROOTS:
            source = mask_comments(read(root, SERVER_SPECIAL))
            with self.subTest(root=root):
                self.assertIn('case "ICBM": {', source)
                self.assertIn(
                    'if ((missionNamespace getVariable ["WFBE_C_ICBM_LEGACY_SERVER_AUTH", 0]) <= 0) then {',
                    source,
                )
                # The original unvalidated flow survives inside the flag-0 branch.
                self.assertIn(
                    "!alive _target || {isNull _target} || {time > _cruiseDeadline}",
                    source,
                )
                self.assertEqual(source.count("[_base] Spawn NukeDammage;"), 2)

    def test_case_icbm_server_branch_validates_authority(self) -> None:
        for root in MAINTAINED_ROOTS:
            source = mask_comments(read(root, SERVER_SPECIAL))
            required = (
                'missionNamespace getVariable ["WFBE_C_ICBM_TEL", 1]',
                "if (count _args != 5) exitWith {",
                'typeName _side != "SIDE"',
                'typeName _base != "OBJECT"',
                'typeName _target != "OBJECT"',
                'typeName _playerTeam != "GROUP"',
                'missionNamespace getVariable ["WFBE_C_MODULE_WFBE_ICBM", 1]',
                "_side in [west, east, resistance]",
                "(side _playerTeam) != _side",
                "_playerTeam != (_side Call WFBE_CO_FNC_GetCommanderTeam)",
                "if (_lvl < 2) exitWith {",
                'missionNamespace getVariable ["WFBE_C_ICBM_LEGACY_COOLDOWN", 300]',
                'Format ["WFBE_ICBM_LEGACY_LASTFIRE_%1", str _side]',
                'missionNamespace getVariable ["WFBE_C_ICBM_COST", 75000]',
                '_funds = _playerTeam getVariable "wfbe_funds";',
                "if (_funds < _cost) exitWith {",
                '_playerTeam setVariable ["wfbe_funds", (_funds - _cost), true];',
                "[_playerTeam] Call WFBE_SE_FNC_SyncFundsRecord;",
                "missionNamespace setVariable [_cdKey, time];",
            )
            for token in required:
                with self.subTest(root=root, token=token):
                    self.assertIn(token, source)

    def test_classic_client_defers_the_fee_to_the_server_when_armed(self) -> None:
        for root in MAINTAINED_ROOTS:
            source = mask_comments(read(root, TACTICAL_MENU))
            with self.subTest(root=root):
                self.assertIn(
                    '_addToListFee = [0,(missionNamespace getVariable ["WFBE_C_ICBM_COST", 75000]),9500,3500,8500,0,12500,0,0];',
                    source,
                )
                self.assertIn(
                    'if ((missionNamespace getVariable ["WFBE_C_ICBM_LEGACY_SERVER_AUTH", 0]) <= 0) then {',
                    source,
                )
                self.assertIn("-_currentFee Call ChangePlayerFunds;", source)

    def test_flag_and_tunables_are_registered(self) -> None:
        for root in MAINTAINED_ROOTS:
            source = mask_comments(read(root, COMMON_CONSTANTS))
            required = (
                'if (isNil "WFBE_C_ICBM_LEGACY_SERVER_AUTH") then {WFBE_C_ICBM_LEGACY_SERVER_AUTH = 0};',
                'if (isNil "WFBE_C_ICBM_COST") then {WFBE_C_ICBM_COST = 75000};',
                'if (isNil "WFBE_C_ICBM_LEGACY_COOLDOWN") then {WFBE_C_ICBM_LEGACY_COOLDOWN = 300};',
            )
            for token in required:
                with self.subTest(root=root, token=token):
                    self.assertIn(token, source)


if __name__ == "__main__":
    unittest.main()
