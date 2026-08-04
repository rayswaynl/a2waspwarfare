#!/usr/bin/env python3
"""Regression coverage for AICOM's tier-2/3 in-place stuck repair.

Arma 2 OA can retain per-part vehicle damage after the overall damage scalar
is reset. The Chernarus source block must therefore clear every configured
hitpoint before the repaired hull is reused.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus"
RELATIVE = Path("Common/Functions/Common_RunCommanderTeam.sqf")


def stuck_repair_block(source: str) -> str:
    start = source.index("//--- TP-15 STUCK-DRIVEN IN-PLACE REPAIR")
    end = source.index("//--- SML-5 surgical unstuck", start)
    return source[start:end]


def test_stuck_repair_restores_each_configured_hitpoint() -> None:
    source = (MISSION / RELATIVE).read_text(encoding="utf-8")
    block = stuck_repair_block(source)

    assert "_uVeh setDamage 0;" in block
    assert 'configFile >> "CfgVehicles" >> (typeOf _uVeh) >> "HitPoints"' in block
    assert "_uVeh setHit [_srHpName2, 0]" in block
    assert block.index("_uVeh setDamage 0;") < block.index("configFile >>")
    assert block.index("configFile >>") < block.index("_uVeh setHit [_srHpName2, 0]")
