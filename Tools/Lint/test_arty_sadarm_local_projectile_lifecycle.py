#!/usr/bin/env python3
"""Regression coverage for SADARM's local projectile lifetime."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)
SADARM_RELATIVE = Path("Common") / "Module" / "Arty" / "ARTY_HandleSADARM.sqf"


def _air_target_block(source: str) -> str:
    start_marker = 'if (_targetToHit isKindOf "Air") then {'
    end_marker = "\n\t} else {"
    start = source.index(start_marker)
    end = source.index(end_marker, start)
    return source[start:end]


def test_air_target_branch_does_not_orphan_a_local_projectile() -> None:
    for mission_root in MISSION_ROOTS:
        source = (mission_root / SADARM_RELATIVE).read_text(encoding="utf-8-sig")
        block = _air_target_block(source)

        assert '"ARTY_SADARM_PROJO" createVehicleLocal' not in block
        assert block.count('createVehicle ["ARTY_SADARM_PROJO"') == 1
