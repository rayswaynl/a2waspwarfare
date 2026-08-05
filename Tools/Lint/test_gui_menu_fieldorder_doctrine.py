from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
COMMAND_MENU_PATHS = (
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/GUI/GUI_Menu_Command.sqf",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/GUI/GUI_Menu_Command.sqf",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Client/GUI/GUI_Menu_Command.sqf",
)
FIELDORDER_ACTION_ASSIGNMENT = 'private "_pb"; _pb = MenuAction; MenuAction = -1;'
FIELDORDER_DOCTRINE_SWITCH = '_deckDoctrine = switch (_pb) do {case 762:'
LATE_MAP_ORDER_SWITCH = '_deckDoctrine = switch (_b) do {case 762:'


class GuiMenuFieldorderDoctrineTests(unittest.TestCase):
    def test_fieldorder_deck_uses_action_captured_by_fieldorder_branch(self):
        for path in COMMAND_MENU_PATHS:
            source = path.read_text(encoding="utf-8-sig")
            with self.subTest(path=path):
                self.assertIn(FIELDORDER_ACTION_ASSIGNMENT, source)
                self.assertEqual(source.count(FIELDORDER_DOCTRINE_SWITCH), 1)
                self.assertNotIn(LATE_MAP_ORDER_SWITCH, source)


if __name__ == "__main__":
    unittest.main()
