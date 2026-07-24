"""Regression contract for optional target-aware AICOM factory selection."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)


def test_target_aware_factory_selection_is_opt_in_and_mirrored():
    sources = []
    constants = []
    for mission_root in MISSION_ROOTS:
        produce = (mission_root / "Server" / "AI" / "Commander" / "AI_Commander_Produce.sqf").read_text(encoding="utf-8-sig")
        common_constants = (mission_root / "Common" / "Init" / "Init_CommonConstants.sqf").read_text(encoding="utf-8-sig")
        sources.append(produce.encode("utf-8"))
        constants.append(common_constants.encode("utf-8"))

        assert 'WFBE_C_AICOM_FACTORY_TARGET_ENABLE = 0' in common_constants
        assert 'missionNamespace getVariable ["WFBE_C_AICOM_FACTORY_TARGET_ENABLE", 0]' in produce
        assert '_factoryOrder = _team getVariable "wfbe_aicom_order";' in produce
        assert '_factoryAnchor = _factoryOrder select 2;' in produce

    assert sources[0] == sources[1] == sources[2]
    assert constants[0] == constants[1] == constants[2]


if __name__ == "__main__":
    test_target_aware_factory_selection_is_opt_in_and_mirrored()
    print("AICOM target-aware factory selection contract: PASS")
