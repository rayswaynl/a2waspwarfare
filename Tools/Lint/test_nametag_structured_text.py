from pathlib import Path
import re
import unittest


class NameTagStructuredTextTests(unittest.TestCase):
    def test_player_names_do_not_enter_parse_text_markup(self):
        source = Path(
            "Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Init/Init_Client.sqf"
        ).read_text(encoding="utf-8")

        raw_player_markup = re.findall(
            r"ctrlSetStructuredText \(parseText \(Format \[\"<t align='center' shadow='1' size='%2' color='#d6ecff'>%1</t>\", name _x, _sz\]\)\)",
            source,
        )
        self.assertEqual(
            raw_player_markup,
            [],
            "profile-controlled player names must not be injected into parsed <t> markup",
        )

        safe_player_labels = re.findall(
            r"_tagText = text \(name _x\);\s+"
            r"_tagText setAttributes \[\"align\", \"center\", \"shadow\", \"1\", \"size\", str _sz, \"color\", \"#d6ecff\"\];\s+"
            r"_ctrl ctrlSetStructuredText \(composeText \[_tagText\]\);",
            source,
        )
        self.assertEqual(
            len(safe_player_labels),
            2,
            "both on-foot and mounted-player labels must use a plain text structured-text element",
        )

    def test_transfer_confirmation_escapes_selected_player_name(self):
        source = Path(
            "Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/GUI/GUI_TransferMenu.sqf"
        ).read_text(encoding="utf-8")

        self.assertNotIn(
            'hint parseText format [localize "STR_WF_INFO_Funds_Sent", _funds_transfering, name leader _selected];',
            source,
            "the selected player's profile name must not enter the localised parsed markup directly",
        )
        self.assertIn("_charCode == 38", source)
        self.assertIn('"&amp;"', source)
        self.assertIn("_charCode == 60", source)
        self.assertIn('"&lt;"', source)
        self.assertIn("_charCode == 62", source)
        self.assertIn('"&gt;"', source)
        self.assertIn(
            'hint parseText format [localize "STR_WF_INFO_Funds_Sent", _funds_transfering, _safeName];',
            source,
        )


if __name__ == "__main__":
    unittest.main()
