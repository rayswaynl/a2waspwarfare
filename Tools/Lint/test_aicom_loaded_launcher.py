#!/usr/bin/env python3
"""Regression contracts for AICOM launcher capability after rockets are spent."""

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


def test_launcher_capability_requires_a_compatible_magazine() -> None:
    for terrain in TERRAINS:
        helper = code(terrain, "Common/Functions/Common_HasLoadedSecondaryWeapon.sqf")
        init = code(terrain, "Common/Init/Init_Common.sqf")

        assert "secondaryWeapon _unit" in helper
        assert 'CfgWeapons" >> _weapon >> "magazines"' in helper
        assert "magazines _unit" in helper
        assert "_mag in _unitMags" in helper
        assert 'WFBE_CO_FNC_HasLoadedSecondaryWeapon = Compile preprocessFileLineNumbers "Common\\Functions\\Common_HasLoadedSecondaryWeapon.sqf";' in init


def test_aicom_consumers_use_loaded_launcher_capability() -> None:
    for terrain in TERRAINS:
        strategy = code(terrain, "Server/AI/Commander/AI_Commander_Strategy.sqf")
        overwatch = code(terrain, "Common/Functions/Common_SMLOverwatch.sqf")

        assert "[_launcherUnit] Call WFBE_CO_FNC_HasLoadedSecondaryWeapon" in strategy
        assert "[_uX] Call WFBE_CO_FNC_HasLoadedSecondaryWeapon" in overwatch
        assert "secondaryWeapon _uX != \"\"" not in overwatch


if __name__ == "__main__":
    test_launcher_capability_requires_a_compatible_magazine()
    test_aicom_consumers_use_loaded_launcher_capability()
    print("AICOM loaded-launcher regression checks passed")
