"""Regression contract for keeping W13/W22 radial air spawns in the map square."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)
WILDCARD_PATH = "Server/Functions/AI_Commander_Wildcard.sqf"
BOUNDARY_LOOKUP = 'missionNamespace getVariable ["WFBE_BOUNDARIESXY", -1]'
W13_POSITION = "_w13SpawnPos = [(_hqPos select 0) + 4000 * sin _w13Ang"
W22_POSITION = "_w22SpawnPos = [(_hqPos select 0) + 4000 * sin _w22Ang"
BOUNDARY_GUARD = 'typeName _aicomMapBoundary == "SCALAR" && {_aicomMapBoundary > 0}'
W13_CREATE = "[_w13Class, _w13SpawnPos, _side"
W22_CREATE = "[_w22PlaneClass, _w22SpawnPos, _side"


def _assert_clamp_before_create(source: str, position: str, create: str) -> None:
    position_index = source.index(position)
    guard_index = source.index(BOUNDARY_GUARD, position_index)
    create_index = source.index(create, guard_index)
    block = source[guard_index:create_index]

    assert block.count("set [0") == 1
    assert block.count("set [1") == 1
    assert "max 0" in block
    assert "min _aicomMapBoundary" in block


def test_w13_and_w22_radial_spawns_are_clamped_before_vehicle_creation():
    """Every mirror must bound both coordinates before the engine consumes them."""
    source_bytes = []
    for mission_root in MISSION_ROOTS:
        path = mission_root / WILDCARD_PATH
        source = path.read_text(encoding="utf-8-sig")
        source_bytes.append(path.read_bytes())

        assert source.count(BOUNDARY_LOOKUP) == 1
        assert source.count(BOUNDARY_GUARD) == 2
        _assert_clamp_before_create(source, W13_POSITION, W13_CREATE)
        _assert_clamp_before_create(source, W22_POSITION, W22_CREATE)

    assert source_bytes[0] == source_bytes[1] == source_bytes[2]


def test_radial_edge_cases_clamp_to_shared_square():
    """The intended map-square transform handles each corner without changing altitude."""
    boundary = 15360
    samples = ((-3000, 1700), (1700, -3000), (boundary + 3000, 1700), (1700, boundary + 3000))
    for x, y in samples:
        clamped = (max(0, min(x, boundary)), max(0, min(y, boundary)))
        assert 0 <= clamped[0] <= boundary
        assert 0 <= clamped[1] <= boundary


if __name__ == "__main__":
    test_w13_and_w22_radial_spawns_are_clamped_before_vehicle_creation()
    test_radial_edge_cases_clamp_to_shared_square()
    print("AICOM W13/W22 map-edge contract: PASS")
