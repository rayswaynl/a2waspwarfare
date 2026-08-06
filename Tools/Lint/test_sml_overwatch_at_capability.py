#!/usr/bin/env python3
"""Regression contract for SML-4 choosing an anti-armour launcher."""

from pathlib import Path

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
TERRAINS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)


def code(terrain: str, relative: str) -> str:
    return mask_comments((ROOT / terrain / relative).read_text(encoding="utf-8-sig"))


def test_overwatch_rejects_loaded_manpads_for_ground_armour() -> None:
    for terrain in TERRAINS:
        overwatch = code(terrain, "Common/Functions/Common_SMLOverwatch.sqf")
        strategy = code(terrain, "Server/AI/Commander/AI_Commander_Strategy.sqf")
        aa_classifier = code(terrain, "Common/Functions/Common_SmallArmsEffAntiAir.sqf")

        assert "[_uX] Call WFBE_CO_FNC_HasLoadedSecondaryWeapon" in overwatch
        assert "WFBE_CO_FNC_SmallArmsEffAntiAir" in overwatch
        assert "WFBE_CO_FNC_SmallArmsEffAntiAir" in strategy
        assert 'if (_sw in ["Stinger", "Igla", "Strela"]) then {_isAA = true};' in aa_classifier


if __name__ == "__main__":
    test_overwatch_rejects_loaded_manpads_for_ground_armour()
    print("SML overwatch anti-armour capability regression checks passed")
