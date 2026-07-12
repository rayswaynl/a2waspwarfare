#!/usr/bin/env python3
"""Regression coverage for Sniper spot-marker locality."""

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SNIPER_PATHS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Module/Skill/Skill_Sniper.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/Module/Skill/Skill_Sniper.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Client/Module/Skill/Skill_Sniper.sqf"),
    Path("Tools/PerfTest/missions/WASP_PerfOFF_TEST.Chernarus/Client/Module/Skill/Skill_Sniper.sqf"),
)
CONSTANT_PATHS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Init/Init_CommonConstants.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Common/Init/Init_CommonConstants.sqf"),
    Path("Tools/PerfTest/missions/WASP_PerfOFF_TEST.Chernarus/Common/Init/Init_CommonConstants.sqf"),
)
RECEIVER_PATHS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/PVFunctions/SpotterMarkContact.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/PVFunctions/SpotterMarkContact.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Client/PVFunctions/SpotterMarkContact.sqf"),
    Path("Tools/PerfTest/missions/WASP_PerfOFF_TEST.Chernarus/Client/PVFunctions/SpotterMarkContact.sqf"),
)
LOCAL_CREATE = "createMarkerLocal [_markerName,_screenPos];"
GLOBAL_TEXT = "_markerName setMarkerText Format ['SPOTTED: %1',_markertime];"
LOCAL_TEXT = "_markerName setMarkerTextLocal Format ['SPOTTED: %1',_markertime];"
TEAM_MARK_DEFAULT = 'if (isNil "WFBE_C_SPOTTER_TEAM_MARKS") then {WFBE_C_SPOTTER_TEAM_MARKS = 1};'
TEAM_MARK_SEND = '[sideJoined, "SpotterMarkContact", [_screenPos, time, _markerName]] Call WFBE_CO_FNC_SendToClients;'
RECEIVER_CREATE = "createMarkerLocal [_markerName, _pos];"


class SniperMarkerLocalityTests(unittest.TestCase):
    def test_initial_spot_marker_text_stays_local(self) -> None:
        for relative_path in SNIPER_PATHS:
            text = (ROOT / relative_path).read_text(encoding="utf-8")

            self.assertIn(LOCAL_CREATE, text, f"local marker creation is missing in {relative_path}")
            self.assertNotIn(GLOBAL_TEXT, text, f"local marker is globalized in {relative_path}")
            self.assertEqual(text.count(LOCAL_TEXT), 1, f"initial local text setter is wrong in {relative_path}")
            self.assertLess(text.index(LOCAL_CREATE), text.index(LOCAL_TEXT))

    def test_team_wide_spotting_remains_armed_and_side_scoped(self) -> None:
        for relative_path in CONSTANT_PATHS:
            text = (ROOT / relative_path).read_text(encoding="utf-8")
            self.assertEqual(text.count(TEAM_MARK_DEFAULT), 1, f"team spotting is not armed in {relative_path}")

        for sender_path, receiver_path in zip(SNIPER_PATHS, RECEIVER_PATHS):
            sender = (ROOT / sender_path).read_text(encoding="utf-8")
            receiver = (ROOT / receiver_path).read_text(encoding="utf-8")

            self.assertEqual(sender.count(TEAM_MARK_SEND), 1, f"team spot is not side-scoped in {sender_path}")
            self.assertEqual(receiver.count(RECEIVER_CREATE), 1, f"team spot is not recreated locally in {receiver_path}")


if __name__ == "__main__":
    unittest.main()
