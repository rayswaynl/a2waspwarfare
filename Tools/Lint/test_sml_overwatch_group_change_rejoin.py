#!/usr/bin/env python3
"""Regression checks for SML overwatch cleanup after launcher reassignment."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TERRAINS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)


def test_transferred_launcher_is_not_ordered_to_old_team_leader() -> None:
    for terrain in TERRAINS:
        source = (ROOT / terrain / "Common/Functions/Common_SMLOverwatch.sqf").read_text(encoding="utf-8")
        group_change_idx = source.index('_reason = "group_change"')
        rejoin_idx = source.index("//--- REJOIN.")
        follow_idx = source.index("_launcher doFollow (leader _team);")

        assert group_change_idx < rejoin_idx < follow_idx, (
            f"{terrain}: the group-change exit must be handled by rejoin cleanup"
        )
        assert "_launcher in (units _team)" in source[rejoin_idx:follow_idx], (
            f"{terrain}: a transferred launcher must not receive an order to follow its old team leader"
        )


if __name__ == "__main__":
    test_transferred_launcher_is_not_ordered_to_old_team_leader()
    print("SML overwatch group-change rejoin regression checks passed")
