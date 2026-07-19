#!/usr/bin/env python3
"""Regression checks for C5's selective DIRECT-to-AI handoff reset."""

from __future__ import annotations

import unittest
from dataclasses import dataclass
from pathlib import Path

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
MAINTAINED_ROOTS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)

COMMANDER = Path("Server/AI/Commander/AI_Commander.sqf")
QUEUE = Path("Server/Functions/Server_CommandOrderQueue.sqf")
SPECIAL = Path("Server/Functions/Server_HandleSpecial.sqf")
CONSTANTS = Path("Common/Init/Init_CommonConstants.sqf")
MIRRORED_FILES = (COMMANDER, QUEUE, SPECIAL, CONSTANTS)


def read(root: Path, relative: Path) -> str:
    return (root / relative).read_text(encoding="utf-8-sig")


@dataclass
class Team:
    sequence: int
    direct_owned: bool = False
    reset_count: int = 0


def selective_handoff(teams: list[Team]) -> None:
    """Model C5: only a stamped DIRECT team is neutralised at an edge."""
    for team in teams:
        if team.direct_owned:
            team.sequence += 1
            team.reset_count += 1
            team.direct_owned = False


class AicomCommandHandoffPreserveTests(unittest.TestCase):
    def test_direct_order_stamp_is_enabled_only_while_delegate_is_off(self) -> None:
        queue = mask_comments(read(MAINTAINED_ROOTS[0], QUEUE))
        special = mask_comments(read(MAINTAINED_ROOTS[0], SPECIAL))
        self.assertIn('"WFBE_C_CMD_HANDOFF_PRESERVE", 0', queue)
        self.assertIn('private ["_coSide","_coType","_coIndex","_coTarget","_coIssuer","_coLogik","_coCmd","_coTeams","_coQueue","_coSeq","_coReject","_coTeam","_coQueued","_coPush","_coEnqueue","_coDirect"]', special)
        self.assertIn('_coDirect = !(_coLogik getVariable ["wfbe_aicom_player_delegate", true])', special)
        self.assertIn('[_qeTeam, _qeType, _qeTarget, _coIssuer, _coSeq, time, _coDirect]', special)
        self.assertIn('_directAtEnqueue = _entry select 6', queue)
        self.assertIn('"wfbe_direct_owned", true, true', queue)

    def test_delegate_edge_resets_only_stamped_teams_when_flag_enabled(self) -> None:
        commander = mask_comments(read(MAINTAINED_ROOTS[0], COMMANDER))
        self.assertIn('"WFBE_C_CMD_HANDOFF_PRESERVE", 0', commander)
        self.assertIn('"wfbe_direct_owned", false', commander)
        self.assertIn('"wfbe_direct_owned", nil, true', commander)

    def test_race_fixture_preserves_five_ai_orders_and_clears_the_direct_stamp(self) -> None:
        teams = [Team(sequence=20 + index) for index in range(5)] + [Team(sequence=99, direct_owned=True)]

        selective_handoff(teams)

        self.assertEqual([team.sequence for team in teams[:5]], [20, 21, 22, 23, 24])
        self.assertEqual(teams[5].sequence, 100)
        self.assertEqual([team.reset_count for team in teams], [0, 0, 0, 0, 0, 1])
        self.assertFalse(teams[5].direct_owned)

        selective_handoff(teams)

        self.assertEqual([team.reset_count for team in teams], [0, 0, 0, 0, 0, 1])
        self.assertEqual([team.sequence for team in teams], [20, 21, 22, 23, 24, 100])

    def test_flag_is_armed_and_all_generated_copies_match_source(self) -> None:
        constants = mask_comments(read(MAINTAINED_ROOTS[0], CONSTANTS))
        self.assertIn('if (isNil "WFBE_C_CMD_HANDOFF_PRESERVE") then {WFBE_C_CMD_HANDOFF_PRESERVE = 1}', constants)
        for relative in MIRRORED_FILES:
            with self.subTest(path=str(relative)):
                copies = [(root / relative).read_bytes() for root in MAINTAINED_ROOTS]
                self.assertEqual(len(set(copies)), 1)


if __name__ == "__main__":
    unittest.main()
