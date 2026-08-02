"""Regression contract for side-supply logging without a commander team."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)

SUPPLY_LOG = Path("Server/Functions/Server_ChangeSideSupply.sqf")


def test_side_supply_log_guards_missing_commander_before_leader_name_lookup():
    sources = [(root / SUPPLY_LOG).read_text(encoding="utf-8-sig") for root in MISSION_ROOTS]

    for source in sources:
        assert "_commanderTeam" in source
        assert "_commanderName" in source
        assert "typeName _commanderTeam == \"GROUP\"" in source
        assert "_commanderName = \"No commander\"" in source
        assert "_commanderName" in source[source.index("[\"INFORMATION\""):]
        assert "name leader ((_side) call WFBE_CO_FNC_GetCommanderTeam)" not in source

    assert sources[0] == sources[1] == sources[2]


if __name__ == "__main__":
    test_side_supply_log_guards_missing_commander_before_leader_name_lookup()
    print("side-supply commander logging contract: PASS")
