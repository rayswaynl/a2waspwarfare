from pathlib import Path


MISSION_ROOTS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad"),
)


def _read(root: Path, relative: str) -> str:
    return (root / relative).read_text(encoding="utf-8")


def test_server_buyunit_accepts_the_existing_array_contract_for_all_mirrors():
    root = Path(__file__).resolve().parents[2]
    sources = [
        _read(root / mission_root, "Server/Functions/Server_BuyUnit.sqf")
        for mission_root in MISSION_ROOTS
    ]

    assert len({source for source in sources}) == 1
    source = sources[0]
    assert "_isVehicle = [];" in source
    assert 'typeName _isVehicle != "ARRAY"' in source
    assert "count _isVehicle != 4" in source
    assert "typeName (_isVehicle select 0) != \"BOOL\"" in source
    assert "typeName (_isVehicle select 3) != \"BOOL\"" in source
    assert "count _isVehicle > 0" in source
    assert "count _isVehicle == 0" in source


def test_aicom_producer_passes_empty_or_four_boolean_flags_to_buyunit():
    root = Path(__file__).resolve().parents[2]
    sources = [
        _read(root / mission_root, "Server/AI/Commander/AI_Commander_Produce.sqf")
        for mission_root in MISSION_ROOTS
    ]

    assert len({source for source in sources}) == 1
    source = sources[0]
    assert '_isVeh = if (_toBuild isKindOf "Man") then {[]} else {[true,true,true,true]};' in source
