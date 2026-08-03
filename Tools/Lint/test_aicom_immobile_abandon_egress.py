from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = [
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
]
RELATIVE = Path("Common/Functions/Common_RunCommanderTeam.sqf")


def immobile_abandon_block(text: str) -> str:
    start = text.index("//--- IMMOBILE-ABANDON")
    end = text.index("} forEach _vehicles;", start) + len("} forEach _vehicles;")
    return text[start:end]


def test_immobile_hull_egress_forces_survivors_out_before_retasking():
    block = immobile_abandon_block((MISSIONS[0] / RELATIVE).read_text(encoding="utf-8"))

    assert "unassignVehicle _x;" in block
    assert "[_x] orderGetIn false;" in block
    assert "if (vehicle _x != _x) then {moveOut _x};" in block
    assert block.index("unassignVehicle _x;") < block.index("moveOut _x") < block.index("_x doMove _dropPos;")


def test_immobile_hull_egress_is_mirrored_to_all_terrains():
    source = (MISSIONS[0] / RELATIVE).read_bytes()
    for mission in MISSIONS[1:]:
        assert (mission / RELATIVE).read_bytes() == source
