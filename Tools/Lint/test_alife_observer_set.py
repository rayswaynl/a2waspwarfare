"""Regression contract for town-AI observer membership."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TOWN_AI = ROOT / (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/"
    "Server/FSM/server_town_ai.sqf"
)


def test_town_activation_excludes_dead_men_and_empty_hulls() -> None:
    """Only living bodies and live-crewed hulls may reach the hostile-side tally."""
    text = TOWN_AI.read_text(encoding="utf-8-sig")
    start = text.index("_detectedFiltered = [];")
    end = text.index("forEach _detected;", start)
    observer_filter = text[start:end]

    assert "if (_x isKindOf \"Man\") then {" in observer_filter
    assert "if (alive _x) then {_detectedFiltered = _detectedFiltered + [_x]};" in observer_filter
    assert "if (alive _x && {({alive _x} count (crew _x)) > 0}) then {_detectedFiltered = _detectedFiltered + [_x]};" in observer_filter


if __name__ == "__main__":
    test_town_activation_excludes_dead_men_and_empty_hulls()
    print("A-Life observer-set checks passed")
