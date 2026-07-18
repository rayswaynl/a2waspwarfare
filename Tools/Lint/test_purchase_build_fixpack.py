#!/usr/bin/env python3
"""Regression checks for the purchase/build correctness fixpack."""

from __future__ import annotations

import unittest
from pathlib import Path

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
CHERNARUS = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"
GUI = CHERNARUS / "Client/GUI/GUI_Menu_BuyUnits.sqf"
BUILD = CHERNARUS / "Client/Functions/Client_BuildUnit.sqf"
SERVER = CHERNARUS / "Server/Functions/Server_BuyUnit.sqf"
ICBM = CHERNARUS / "Common/Functions/Common_RequestIcbmTelPurchase.sqf"


class PurchaseBuildFixpackTests(unittest.TestCase):
    def test_driver_toggle_is_initialized_only_when_missing(self) -> None:
        code = mask_comments(GUI.read_text(encoding="utf-8-sig"))
        self.assertIn(
            'if (isNil {profileNamespace getVariable "wfbe_c_driver_enabled_by_default"}) then {',
            code,
        )
        self.assertNotIn(
            'profileNamespace setVariable ["wfbe_c_driver_enabled_by_default", true];',
            code.split('if (isNil {profileNamespace getVariable "wfbe_c_driver_enabled_by_default"}) then {', 1)[0],
        )

    def test_unknown_classname_exits_before_queue_or_select_chain(self) -> None:
        code = mask_comments(BUILD.read_text(encoding="utf-8-sig"))
        guard = code.find('if (isNil "_currentUnit") exitWith {')
        queue = code.find('unitQueu = unitQueu + _cpt;')
        turrets = code.find('_turrets = _currentUnit select QUERYUNITTURRETS;')
        self.assertGreaterEqual(guard, 0)
        self.assertGreaterEqual(queue, 0)
        self.assertGreaterEqual(turrets, 0)
        self.assertLess(guard, queue)
        self.assertLess(guard, turrets)

    def test_air_spawn_uses_the_namespace_flag_consistently(self) -> None:
        code = mask_comments(BUILD.read_text(encoding="utf-8-sig"))
        self.assertIn(
            'if (_unit == "C130J_US_EP1" && {(missionNamespace getVariable ["WFBE_C_AIR_SPAWN_SAFETY", 0]) > 0}) then',
            code,
        )
        self.assertNotIn('&& {WFBE_C_AIR_SPAWN_SAFETY > 0}', code)

    def test_sead_jets_use_one_guidance_path_on_both_purchase_paths(self) -> None:
        for path in (BUILD, SERVER):
            code = mask_comments(path.read_text(encoding="utf-8-sig"))
            with self.subTest(path=path.name):
                self.assertIn('"F35B","Su34"', code)
                self.assertIn('["F35B","Su34"]})}) then', code)
                self.assertNotIn("'F35B','AV8B'", code)

    def test_carrier_plane_deck_height_requires_water(self) -> None:
        code = mask_comments(SERVER.read_text(encoding="utf-8-sig"))
        self.assertIn(
            '&& {surfaceIsWater _position}) then {',
            code,
        )

    def test_scud_purchase_keeps_the_server_hull_and_client_crew_split(self) -> None:
        purchase = mask_comments(ICBM.read_text(encoding="utf-8-sig"))
        self.assertIn('_params Spawn BuildUnit;', purchase)
        self.assertIn('if (_clientCost > 0) then {-(_clientCost) Call ChangePlayerFunds};', purchase)
        gui = mask_comments(GUI.read_text(encoding="utf-8-sig"))
        self.assertIn('_clientPaidCost = (_currentCost - _baseHullCost) max 0', gui)


if __name__ == "__main__":
    unittest.main()
