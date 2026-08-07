#!/usr/bin/env python3
"""Contracts for AICOM's commander-authority read during lease succession.

The commander lease is deliberately stable while an AI unit is promoted to
group leader, and during the short disconnect grace window.  AICOM must use the
lease's side/group binding for its human-command gate instead of observing only
the current group leader.
"""

from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CHERNARUS = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"
LEASE = CHERNARUS / "Common" / "Functions" / "Common_CommanderLease.sqf"

COMMANDER_WORKERS = (
    CHERNARUS / "Server" / "AI" / "Commander" / "AI_Commander.sqf",
    CHERNARUS / "Server" / "AI" / "Commander" / "AI_Commander_AssignTowns.sqf",
    CHERNARUS / "Server" / "AI" / "Commander" / "AI_Commander_Paratroops.sqf",
    CHERNARUS / "Server" / "AI" / "Commander" / "AI_Commander_CargoAirdrop.sqf",
    CHERNARUS / "Server" / "AI" / "Commander" / "AI_Commander_Produce.sqf",
    CHERNARUS / "Server" / "AI" / "Commander" / "AI_Commander_EndgameTeleport.sqf",
    CHERNARUS / "Server" / "Functions" / "AI_Commander_Wildcard.sqf",
)


def lease_authority_uid(
    *,
    lease_enabled: bool,
    lease_uid: str,
    lease_side: str,
    lease_group: str,
    side: str,
    group: str,
    leader_uid: str,
) -> str:
    """Small deterministic model of the source helper's authority choice."""

    if (
        lease_enabled
        and lease_uid
        and lease_side == side
        and lease_group == group
    ):
        return lease_uid
    return leader_uid


class CommanderAuthorityFixtures(unittest.TestCase):
    def test_ai_promotion_does_not_drop_the_human_lease(self) -> None:
        uid = lease_authority_uid(
            lease_enabled=True,
            lease_uid="uid-human",
            lease_side="west",
            lease_group="grp-1",
            side="west",
            group="grp-1",
            leader_uid="",
        )
        self.assertEqual(uid, "uid-human")

    def test_disconnect_grace_keeps_authority_until_executor_clears_lease(self) -> None:
        uid = lease_authority_uid(
            lease_enabled=True,
            lease_uid="uid-human",
            lease_side="west",
            lease_group="grp-1",
            side="west",
            group="grp-1",
            leader_uid="",
        )
        self.assertNotEqual(uid, "")
        self.assertEqual(
            lease_authority_uid(
                lease_enabled=True,
                lease_uid="",
                lease_side="",
                lease_group="",
                side="west",
                group="grp-1",
                leader_uid="",
            ),
            "",
        )

    def test_legacy_mode_still_uses_a_player_leader(self) -> None:
        self.assertEqual(
            lease_authority_uid(
                lease_enabled=False,
                lease_uid="",
                lease_side="",
                lease_group="",
                side="west",
                group="grp-1",
                leader_uid="uid-legacy",
            ),
            "uid-legacy",
        )

    def test_source_helper_binds_authority_to_current_side_and_group(self) -> None:
        code = LEASE.read_text(encoding="utf-8-sig")
        self.assertIn("WFBE_CO_FNC_GetCommanderAuthorityUID = {", code)
        self.assertIn('missionNamespace getVariable ["WFBE_C_CMD_LEASE", 0]', code)
        self.assertIn('(_lease select 1) == _side', code)
        self.assertIn('(_lease select 2) == (str _team)', code)
        self.assertIn('if (_uid == "") then', code)

    def test_all_commander_workers_use_the_shared_authority_read(self) -> None:
        for path in COMMANDER_WORKERS:
            code = path.read_text(encoding="utf-8-sig")
            self.assertIn(
                "WFBE_CO_FNC_GetCommanderAuthorityUID",
                code,
                path.name,
            )
            self.assertNotIn(
                "isPlayer (leader _cmdTeam)",
                code,
                path.name,
            )


if __name__ == "__main__":
    unittest.main()
