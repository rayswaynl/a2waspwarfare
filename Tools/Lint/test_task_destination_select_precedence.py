#!/usr/bin/env python3
"""Regression check for the SetTask destination-X comparison grouping."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TERRAINS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)


def test_task_destination_x_is_selected_before_comparison() -> None:
    expected = "while {((taskDestination _task) select 0) == (_pos select 0) && !_succeed} do {"
    for terrain in TERRAINS:
        source = (ROOT / terrain / "Client/PVFunctions/SetTask.sqf").read_text(encoding="utf-8")
        assert expected in source, (
            f"{terrain}: taskDestination select must be grouped before the == comparison"
        )


if __name__ == "__main__":
    test_task_destination_x_is_selected_before_comparison()
    print("SetTask select precedence regression check passed")
