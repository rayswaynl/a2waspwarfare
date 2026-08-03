#!/usr/bin/env python3
"""Regression coverage for AICOM's tier-2/3 in-place stuck repair.

`setDamage 0` resets the hull scalar but does not restore per-part damage in
Arma 2 OA.  A destroyed wheel, track, engine, or rotor can therefore leave an
otherwise "repaired" hull immobile and force the recovery ladder to escalate.
The normal AICOM self-repair block already enumerates config hitpoints; the
stuck-repair branch must do the same, using its existing local-object guard.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TERRAINS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)
RELATIVE = "Common/Functions/Common_RunCommanderTeam.sqf"


def stuck_repair_block(source: str) -> str:
    start = source.index("//--- TP-15 STUCK-DRIVEN IN-PLACE REPAIR")
    end = source.index("//--- SML-5 surgical unstuck", start)
    return source[start:end]


def test_stuck_repair_restores_each_configured_hitpoint_on_all_terrains() -> None:
    for terrain in TERRAINS:
        source = (ROOT / terrain / RELATIVE).read_text(encoding="utf-8")
        block = stuck_repair_block(source)
        assert "_uVeh setDamage 0;" in block
        assert 'configFile >> "CfgVehicles" >> (typeOf _uVeh) >> "HitPoints"' in block, (
            f"{terrain}: stuck repair does not enumerate the lead hull's configured hitpoints"
        )
        assert "_uVeh setHit [_srHpName2, 0]" in block, (
            f"{terrain}: stuck repair resets only scalar damage, leaving broken mobility hitpoints"
        )
