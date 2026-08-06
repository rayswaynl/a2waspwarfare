from pathlib import Path


ROOT = Path(__file__).resolve().parents[2] / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"
ASSIGN_TOWNS = ROOT / "Server" / "AI" / "Commander" / "AI_Commander_AssignTowns.sqf"


def test_dynamic_assault_timeout_floors_the_selected_speed_before_division():
    """A pre-set zero speed must not poison the dynamic assignment timeout."""
    source = ASSIGN_TOWNS.read_text(encoding="utf-8-sig")
    assert "_asltSpeed = _asltSpeed max 0.1;" in source
    assert source.index("_asltSpeed = _asltSpeed max 0.1;") < source.index("_asltDist / _asltSpeed")
