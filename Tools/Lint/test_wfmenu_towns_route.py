#!/usr/bin/env python3
"""Regression checks for the WF-menu Towns footer route."""

from pathlib import Path
import xml.etree.ElementTree as ET
import unittest


REPO_ROOT = Path(__file__).resolve().parents[2]
MISSION = REPO_ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"
DIALOGS = MISSION / "Rsc" / "Dialogs.hpp"
MENU = MISSION / "Client" / "GUI" / "GUI_Menu.sqf"
STRINGTABLE = MISSION / "stringtable.xml"

LANGUAGES = {"English", "French", "German", "Italian", "Russian", "Spanish"}


class WFMenuTownsRouteTests(unittest.TestCase):
    def test_footer_towns_button_opens_existing_town_actions_dialog(self) -> None:
        dialogs = DIALOGS.read_text(encoding="utf-8")
        menu = MENU.read_text(encoding="utf-8")
        stringtable = ET.parse(STRINGTABLE)
        strings = {
            key.attrib["ID"]: {child.tag: (child.text or "").strip() for child in key}
            for key in stringtable.findall(".//Key")
        }

        self.assertIn("class CA_Towns_Button", dialogs)
        self.assertIn("text = $STR_WF_MAIN_TownsMenu;", dialogs)
        self.assertIn('action = "MenuAction = 26";', dialogs)
        self.assertIn("tooltip = $STR_WF_TOOLTIP_MainMenu_Towns;", dialogs)
        self.assertNotIn("class CA_Radio_Button", dialogs)
        self.assertNotIn('text = "RADIO";', dialogs)
        self.assertIn("if (MenuAction == 26) exitWith {", menu)
        self.assertIn('createDialog "WFBE_GDirCommissarMenu";', menu)
        self.assertNotIn('execVM "WASP\\Radio\\Radio_Menu.sqf";', menu)
        # Regression guard (#1271 night-fold bounce): the Towns route must side-gate so WEST/EAST
        # players do not dead-end in the GUER-only commissar panel (its onLoad hard-guards
        # sideJoined==resistance and self-closes). The GUER dialog must open only inside that gate.
        towns_block = menu[menu.index("if (MenuAction == 26) exitWith {"):][:500]
        self.assertIn("if (sideJoined == resistance) then {", towns_block)
        self.assertIn('createDialog "WFBE_GDirCommissarMenu";', towns_block)
        for key in ("STR_WF_MAIN_TownsMenu", "STR_WF_TOOLTIP_MainMenu_Towns"):
            self.assertIn(key, strings)
            self.assertEqual(LANGUAGES, set(strings[key]))
            self.assertTrue(all(strings[key][language] for language in LANGUAGES))

    def test_flagged_towns_route_uses_side_neutral_panel_and_safe_data_path(self) -> None:
        constants = (MISSION / "Common" / "Init" / "Init_CommonConstants.sqf").read_text(encoding="utf-8")
        menu = MENU.read_text(encoding="utf-8")
        panel = (MISSION / "Client" / "GUI" / "GUI_Menu_TownsGarrison.sqf").read_text(encoding="utf-8")
        dialogs = DIALOGS.read_text(encoding="utf-8")

        self.assertIn('WFBE_C_TOWNS_TAB_GARRISON = 0', constants)
        self.assertIn('class WFBE_TownsGarrisonMenu', dialogs)
        self.assertIn("GUI_Menu_TownsGarrison.sqf", dialogs)

        towns_block = menu[menu.index("if (MenuAction == 26) exitWith {"):][:700]
        self.assertIn('WFBE_C_TOWNS_TAB_GARRISON', towns_block)
        self.assertIn('createDialog "WFBE_TownsGarrisonMenu";', towns_block)
        self.assertIn('createDialog "WFBE_GDirCommissarMenu";', towns_block)

        self.assertIn('(_town getVariable ["sideID", -1]) == _ownSideID', panel)
        self.assertIn('WFBE_IsTownDefenderAI', panel)
        self.assertIn('side _unit == sideJoined', panel)
        self.assertNotIn('publicVariable', panel)
        self.assertNotIn('remoteExec', panel)
        self.assertNotIn('pushBack', panel)


if __name__ == "__main__":
    unittest.main()
