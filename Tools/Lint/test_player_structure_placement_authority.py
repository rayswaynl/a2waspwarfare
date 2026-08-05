"""Regression contract for authoritative player factory placement validation.

The CoIn preview correctly marks water and blocked/steep factory positions red,
but RequestStructure previously trusted the submitted preview position.  This
test requires the server to validate that payload before it creates a pending
reservation or starts a construction worker, and keeps the maintained terrain
copies byte-identical.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
STRUCTURE_PATHS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/PVFunctions/RequestStructure.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/PVFunctions/RequestStructure.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/PVFunctions/RequestStructure.sqf"),
)


def test_server_revalidates_player_structure_placement_before_reservation():
    source_bytes = []
    for relative in STRUCTURE_PATHS:
        path = ROOT / relative
        text = path.read_text(encoding="utf-8-sig")
        source_bytes.append(path.read_bytes())

        requester_gate = text.index('if (!_reject && _index == 0) then {')
        placement_gate = text.index(
            '[_side, _structureType, _pos] Call WFBE_SE_FNC_ValidatePlayerStructurePlacement'
        )
        radar_pending_stamp = text.index('missionNamespace setVariable [_rrPendingKey, time];')
        build_line = text.index('ExecVM (Format["Server\\Construction\\Construction_%1.sqf",_script])')

        assert requester_gate < placement_gate < radar_pending_stamp < build_line
        assert 'StructurePlacementInvalid' in text[placement_gate:radar_pending_stamp]

    assert source_bytes[0] == source_bytes[1] == source_bytes[2]


def test_validator_rejects_water_and_uses_configured_factory_footprint():
    relative = Path(
        "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/Server_ValidatePlayerStructurePlacement.sqf"
    )
    text = (ROOT / relative).read_text(encoding="utf-8-sig")

    assert 'surfaceIsWater _position' in text
    assert 'WFBE_C_STRUCTURES_FLAT_CHECK' in text
    assert 'WFBE_C_STRUCTURES_FLAT_RADIUS' in text
    assert 'WFBE_%1STRUCTUREDISTANCES' in text
    assert 'isFlatEmpty' in text


if __name__ == "__main__":
    test_server_revalidates_player_structure_placement_before_reservation()
    test_validator_rejects_water_and_uses_configured_factory_footprint()
    print("Player structure placement authority contract: PASS")
