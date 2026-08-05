#!/usr/bin/env python3
"""Static contract for SADARM target selection.

SADARM can legally receive an artillery firing side, so its seeker must apply
the live side relation before choosing a nearby vehicle or aircraft.  The
contract is mirrored across all three maintained terrains.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)
SADARM_RELATIVE = Path("Common") / "Module" / "Arty" / "ARTY_HandleSADARM.sqf"


def _selection_block(source: str) -> str:
    scan = source.index("_targets = []")
    selection = source.index("_targetToHit = _targets select", scan)
    return source[scan:selection]


def test_sadarm_selects_only_live_hostile_non_civilian_targets() -> None:
    for mission_root in MISSION_ROOTS:
        source = (mission_root / SADARM_RELATIVE).read_text(encoding="utf-8-sig")
        block = _selection_block(source)

        assert "getFriend" in block, f"{mission_root.name}: missing live relation gate"
        assert "(side _x) != civilian" in block, f"{mission_root.name}: missing civilian exclusion"
        assert "alive _x" in block, f"{mission_root.name}: missing live target gate"
        assert "nearEntities" in block, f"{mission_root.name}: missing SADARM proximity scan"
        assert "set [count _targets, _x]" in block, f"{mission_root.name}: candidates are not filtered before selection"

