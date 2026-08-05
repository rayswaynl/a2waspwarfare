"""Regression contract for player-facing Zeta cargo vehicle discovery."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = (
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)
HOOK = Path("Client/Module/ZetaCargo/Zeta_Hook.sqf")
INIT = Path("Client/Module/ZetaCargo/Zeta_Init.sqf")


def test_zeta_hook_discovers_declared_land_and_ship_cargo_families() -> None:
    hook_sources = [(root / HOOK).read_text(encoding="utf-8-sig") for root in MISSION_ROOTS]
    init_sources = [(root / INIT).read_text(encoding="utf-8-sig") for root in MISSION_ROOTS]

    for source, init in zip(hook_sources, init_sources):
        vehicle_assignment = source.index("_vehicle = [_lifter,_vehicles]")
        assert '_lifter nearObjects ["LandVehicle", 10]' in source
        assert '_lifter nearObjects ["Ship", 10]' in source
        assert source.index('_lifter nearObjects ["LandVehicle", 10]') < vehicle_assignment
        assert source.index('_lifter nearObjects ["Ship", 10]') < vehicle_assignment
        assert 'Zeta_Types = ["Car","Motorcycle","Tank","Ship"];' in init

    normalized = [source.replace("\r\n", "\n") for source in hook_sources]
    assert normalized[0] == normalized[1] == normalized[2]
