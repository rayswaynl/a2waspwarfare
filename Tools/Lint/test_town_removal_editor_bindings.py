#!/usr/bin/env python3
"""Regression checks for Chernarus town-mode lists and editor bindings."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus/mission.sqm"
STALE_REMOVAL_NAMES = ("Pogorevka", "Orlovets", "Kozlovka")


def test_town_removal_lists_do_not_name_unplaced_chernarus_towns() -> None:
    source = MISSION.read_text(encoding="utf-8")
    for town_name in STALE_REMOVAL_NAMES:
        assert town_name not in source, (
            f"{town_name} is not an Init_Town entity but is still counted in a Towns_Removed list"
        )


if __name__ == "__main__":
    test_town_removal_lists_do_not_name_unplaced_chernarus_towns()
