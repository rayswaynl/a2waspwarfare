#!/usr/bin/env python3
"""Regression checks for Chernarus town-mode lists and editor bindings."""

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus/mission.sqm"
STALE_REMOVAL_NAMES = ("Pogorevka", "Orlovets", "Kozlovka")


def _town_removal_lists(source: str) -> list[tuple[str, list[str]]]:
    lists: list[tuple[str, list[str]]] = []
    pattern = re.compile(
        r'setVariable\s+\[""(?P<name>Towns_Removed[^"]+)"",\[(?P<body>[^\]]*)\]\]'
    )
    for match in pattern.finditer(source):
        names = re.findall(r'""([^""]+)""', match.group("body"))
        lists.append((match.group("name"), names))
    return lists


def test_town_removal_lists_do_not_name_unplaced_chernarus_towns() -> None:
    source = MISSION.read_text(encoding="utf-8")
    for town_name in STALE_REMOVAL_NAMES:
        assert town_name not in source, (
            f"{town_name} is not an Init_Town entity but is still counted in a Towns_Removed list"
        )


def test_town_removal_lists_have_unique_names() -> None:
    source = MISSION.read_text(encoding="utf-8")
    lists = _town_removal_lists(source)
    assert len(lists) == 7, f"expected seven Chernarus Towns_Removed lists, got {len(lists)}"
    for list_name, names in lists:
        assert len(names) == len(set(names)), (
            f"{list_name} contains duplicate town names: {names}"
        )


if __name__ == "__main__":
    test_town_removal_lists_do_not_name_unplaced_chernarus_towns()
    test_town_removal_lists_have_unique_names()
