#!/usr/bin/env python3
"""Regression checks for the SML-2 leader-death watchdog."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TERRAINS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)


def test_dismount_watchdog_tracks_the_leader_that_started_the_detach() -> None:
    for terrain in TERRAINS:
        source = (ROOT / terrain / "Common/Functions/Common_SMLDismounts.sqf").read_text(encoding="utf-8")

        assert "_leaderAtDetach = leader _team;" in source, (
            f"{terrain}: capture the detachment leader before the watchdog starts"
        )
        assert "_aliveCheck = !isNull _leaderAtDetach;" in source, (
            f"{terrain}: the leader-death guard must inspect the captured leader"
        )
        assert "if (_aliveCheck) then {_aliveCheck = alive _leaderAtDetach};" in source, (
            f"{terrain}: a dead captured leader must end the detachment"
        )


if __name__ == "__main__":
    test_dismount_watchdog_tracks_the_leader_that_started_the_detach()
    print("SML dismount leader-watchdog regression checks passed")
