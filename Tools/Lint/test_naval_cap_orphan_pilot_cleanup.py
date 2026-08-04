#!/usr/bin/env python3
"""Regression coverage for naval-CAP pilots surviving a hull loss."""

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad"),
)
CAP_GROUP_CLEANUP = re.compile(
    r"if \(!isNull _capGrp\) then \{\s*"
    r"\{if \(!\(isPlayer _x\)\) then \{deleteVehicle _x; sleep 0\}\} forEach \(units _capGrp\);\s*"
    r"deleteGroup _capGrp;\s*\};"
)


def test_naval_cap_shutdown_reaps_ejected_pilots_before_deleting_group() -> None:
    """Capture and inactivity shutdowns must not leave a pilot after hull loss."""
    for mission_root in MISSION_ROOTS:
        naval_path = mission_root / "Server/Init/Init_NavalHVT.sqf"
        text = (ROOT / naval_path).read_text(encoding="utf-8")

        assert len(CAP_GROUP_CLEANUP.findall(text)) == 2, (
            f"both CAP shutdowns must reap surviving pilots before deleteGroup in {naval_path}"
        )


if __name__ == "__main__":
    test_naval_cap_shutdown_reaps_ejected_pilots_before_deleting_group()
