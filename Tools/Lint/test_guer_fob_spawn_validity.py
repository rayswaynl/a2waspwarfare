from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT
    / "Missions_Vanilla"
    / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT
    / "Missions_Vanilla"
    / "[61-2hc]warfarev2_073v48co.zargabad",
)


def test_only_guer_owned_fob_trucks_are_tagged_and_offered_for_respawn():
    """Shared donor classes and enemy-crewed trucks must not become GUER spawns."""
    for mission in MISSIONS:
        build = (mission / "Client" / "Functions" / "Client_BuildUnit.sqf").read_text(
            encoding="utf-8-sig"
        )
        available = (
            mission / "Client" / "Functions" / "Client_GetRespawnAvailable.sqf"
        ).read_text(encoding="utf-8-sig")
        handler = (
            mission / "Client" / "Functions" / "Client_OnRespawnHandler.sqf"
        ).read_text(encoding="utf-8-sig")

        assert "{sideID == WFBE_C_GUER_ID}" in build, mission
        assert (
            '_veh getVariable ["wfbe_side_id", -1]) == WFBE_C_GUER_ID'
            in available
        ), mission
        assert (
            '({(side (group _x)) == resistance} count (crew _veh)) '
            '== count (crew _veh)'
            in available
        ), mission
        assert (
            '_spawn getVariable ["wfbe_side_id", -1]) == WFBE_C_GUER_ID'
            in handler
        ), mission
        assert (
            '({(side (group _x)) == resistance} count (crew _spawn)) '
            '== count (crew _spawn)'
            in handler
        ), mission
