#!/usr/bin/env python3
"""Regression checks for the SML overwatch NaN/zero-delta bearing guard."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TERRAINS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)


def test_overwatch_guards_invalid_geometry_before_atan2() -> None:
    for terrain in TERRAINS:
        source = (ROOT / terrain / "Common/Functions/Common_SMLOverwatch.sqf").read_text(encoding="utf-8")
        bearing = "_bearing = _dx atan2 _dy;"
        assert bearing in source, f"{terrain}: atan2 must receive validated delta variables"
        bearing_idx = source.index(bearing)
        nan_guard_idx = source.index("reason=nan_pos")
        zero_guard_idx = source.index("reason=zero_delta")

        assert "_armorPos = getPos _armorTank;" in source, f"{terrain}: armor position must be captured once"
        assert "(_armorPos select 0) == (_armorPos select 0)" in source, (
            f"{terrain}: armor X must use the A2 NaN self-equality guard"
        )
        assert "(_armorPos select 1) == (_armorPos select 1)" in source, (
            f"{terrain}: armor Y must use the A2 NaN self-equality guard"
        )
        assert "_dx = (_armorPos select 0) - (_dest select 0);" in source
        assert "_dy = (_armorPos select 1) - (_dest select 1);" in source
        assert "if (_dx == 0 && {_dy == 0}) exitWith" in source, (
            f"{terrain}: zero-length bearing delta must skip before atan2"
        )
        assert nan_guard_idx < bearing_idx, f"{terrain}: NaN guard must precede atan2"
        assert zero_guard_idx < bearing_idx, f"{terrain}: zero-delta guard must precede atan2"


if __name__ == "__main__":
    test_overwatch_guards_invalid_geometry_before_atan2()
    print("SML overwatch NaN guard regression checks passed")
