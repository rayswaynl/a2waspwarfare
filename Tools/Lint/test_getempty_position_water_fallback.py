"""Contracts for dry fallback positions from the ground-placement helper."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)
EMPTY = "Common/Functions/Common_GetEmptyPosition.sqf"


def test_empty_position_never_promotes_a_water_probe_to_the_fallback() -> None:
    for mission in MISSIONS:
        source = (ROOT / mission / EMPTY).read_text(encoding="utf-8-sig")
        assert "_lastDry = +_object" in source
        assert "if (!(surfaceIsWater _tpos)) then {_lastDry = +_tpos}" in source
        assert "if (!(surfaceIsWater _tpos) && {count (_tpos isFlatEmpty" in source
        assert "if (!_found) then {" in source
        assert "_position = _lastDry;" in source


def test_empty_position_water_fallback_contract_is_mirrored() -> None:
    contents = [(ROOT / mission / EMPTY).read_bytes() for mission in MISSIONS]
    assert contents[0] == contents[1] == contents[2]
