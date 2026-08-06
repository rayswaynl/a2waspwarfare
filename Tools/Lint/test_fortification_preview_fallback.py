#!/usr/bin/env python3
"""Regression contract for category-2 CoIn fortification previews."""

from pathlib import Path

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
COIN_INIT = ROOT / (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/"
    "Client/Init/Init_Client.sqf"
)


def placement_method_code() -> str:
    return mask_comments(COIN_INIT.read_text(encoding="utf-8-sig"))


def test_fortification_preview_keeps_a_color_without_a_nearby_factory() -> None:
    code = placement_method_code()

    assert "if (count _factories == 0) exitWith {};" not in code
    assert "if (count _factories > 0) then {" in code


if __name__ == "__main__":
    test_fortification_preview_keeps_a_color_without_a_nearby_factory()
