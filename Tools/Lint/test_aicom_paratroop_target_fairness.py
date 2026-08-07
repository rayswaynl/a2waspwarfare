#!/usr/bin/env python3
"""Static contracts for fair AICOM air-support target selection."""

from pathlib import Path
import unittest

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
SOURCE = (
    ROOT
    / "Missions"
    / "[55-2hc]warfarev2_073v48co.chernarus"
    / "Server"
    / "AI"
    / "Commander"
    / "AI_Commander_Paratroops.sqf"
)
CARGO_SOURCE = SOURCE.with_name("AI_Commander_CargoAirdrop.sqf")


class AicomParatroopTargetFairnessTests(unittest.TestCase):
    def test_successful_drops_rotate_across_fixed_attacked_town_order(self) -> None:
        text = mask_comments(SOURCE.read_text(encoding="utf-8-sig"))

        cursor_read = '_paraCursor = _logik getVariable "wfbe_aicom_para_cursor";'
        cursor_select = "_target = _attacked select _paraCursor;"
        group_create = '_grp = [_side, "aicom_paradrop"] Call WFBE_CO_FNC_CreateGroup;'
        cursor_commit = (
            '_logik setVariable ["wfbe_aicom_para_cursor", '
            '(_paraCursor + 1) mod (count _attacked)];'
        )

        self.assertIn(cursor_read, text)
        self.assertIn('if (isNil "_paraCursor") then {_paraCursor = 0};', text)
        self.assertIn("_paraCursor = _paraCursor mod (count _attacked);", text)
        self.assertIn(cursor_select, text)
        self.assertNotIn("_target = _attacked select 0;", text)
        self.assertIn(cursor_commit, text)
        self.assertLess(text.index(cursor_read), text.index(cursor_select))
        self.assertLess(text.index(cursor_select), text.index(group_create))
        self.assertLess(text.index(group_create), text.index(cursor_commit))

    def test_successful_cargo_drops_rotate_across_fixed_attacked_town_order(self) -> None:
        text = mask_comments(CARGO_SOURCE.read_text(encoding="utf-8-sig"))

        cursor_read = '_cargoCursor = _logik getVariable "wfbe_aicom_cargo_cursor";'
        cursor_select = "_target = _attacked select _cargoCursor;"
        group_create = '_grp = [_side, "aicom_cargo_airdrop"] Call WFBE_CO_FNC_CreateGroup;'
        cursor_commit = (
            '_logik setVariable ["wfbe_aicom_cargo_cursor", '
            '(_cargoCursor + 1) mod (count _attacked)];'
        )

        self.assertIn(cursor_read, text)
        self.assertIn('if (isNil "_cargoCursor") then {_cargoCursor = 0};', text)
        self.assertIn("_cargoCursor = _cargoCursor mod (count _attacked);", text)
        self.assertIn(cursor_select, text)
        self.assertNotIn("_target = _attacked select 0;", text)
        self.assertIn(cursor_commit, text)
        self.assertLess(text.index(cursor_read), text.index(cursor_select))
        self.assertLess(text.index(cursor_select), text.index(group_create))
        self.assertLess(text.index(group_create), text.index(cursor_commit))


if __name__ == "__main__":
    unittest.main()
