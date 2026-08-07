#!/usr/bin/env python3
"""Regression contract for capture-time mop-up vehicle crew ownership."""

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / "Server" / "FSM" / "server_town.sqf"


def test_mopup_tags_vehicle_crews_as_town_defenders() -> None:
    source = SOURCE.read_text(encoding="utf-8")

    assert re.search(
        r'_squadCrews\s*=\s*if \(count _retVal > 3\) then \{_retVal select 3\} else \{\[\]\};',
        source,
    )
    assert '(_squadUnits + _squadCrews + _squadVehicles)' in source


if __name__ == "__main__":
    test_mopup_tags_vehicle_crews_as_town_defenders()
