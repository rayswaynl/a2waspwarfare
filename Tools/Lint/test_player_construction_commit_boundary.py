"""Regression contracts for player construction at its server commit boundary."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION = Path("Missions/[55-2hc]warfarev2_073v48co.chernarus")


def read(relative: str) -> str:
    return (ROOT / MISSION / relative).read_text(encoding="utf-8-sig")


def test_player_structure_workers_revalidate_after_staged_wait_before_creation():
    for worker in ("Construction_SmallSite.sqf", "Construction_MediumSite.sqf"):
        text = read(f"Server/Construction/{worker}")
        final_create = text.index("_site = createVehicle [_type, _position, [], 0, \"NONE\"];")
        revalidate = text.index("[_side, _type, _position] Call WFBE_SE_FNC_ValidatePlayerStructurePlacement")
        abort_reason = text.index("post-wait player placement invalid")
        final_stages_removed = text.rindex("_constructed;", 0, final_create)
        assert final_stages_removed < revalidate < abort_reason < final_create
        assert "Call _onConstructionAbort;" in text[revalidate:final_create]


def test_forward_fob_server_rejects_water_before_charging():
    text = read("Server/PVFunctions/RequestForwardFOB.sqf")
    water_check = text.index("surfaceIsWater _pos")
    water_reject = text.index("Forward FOB water placement rejected")
    charge = text.index("[_group, -_cost] Call WFBE_CO_FNC_ChangeTeamFunds;")
    assert water_check < water_reject < charge


if __name__ == "__main__":
    test_player_structure_workers_revalidate_after_staged_wait_before_creation()
    test_forward_fob_server_rejects_water_before_charging()
    print("Player construction commit-boundary contracts: PASS")
