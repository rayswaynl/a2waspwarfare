"""Regression contract for the owned-factory founding gate terminal path."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)


def _teams_source(mission_root: Path) -> str:
    return (
        mission_root / "Server" / "AI" / "Commander" / "AI_Commander_Teams.sqf"
    ).read_text(encoding="utf-8-sig")


def test_owned_factory_rejection_is_terminal_and_mirrored():
    sources = [_teams_source(mission_root) for mission_root in MISSION_ROOTS]
    gate_start = "\t\t//--- STARVATION-SAFE: owning a Barracks"
    fallback = "\n\tif (isNull _facObj) then {_facObj = (_side) Call WFBE_CO_FNC_GetSideHQ};"

    for source in sources:
        start = source.index(gate_start)
        end = source.index(fallback, start)
        gate = source[start:end]

        assert "if (!_typeOK && _ownAny) then {" in gate
        assert "_factoryGateSkip = true;" in gate
        assert "if (!_typeOK && _ownAny) exitWith {" not in gate
        assert "\tif (_factoryGateSkip) exitWith {};" in gate

    assert sources[0].encode("utf-8") == sources[1].encode("utf-8") == sources[2].encode("utf-8")


if __name__ == "__main__":
    test_owned_factory_rejection_is_terminal_and_mirrored()
    print("AICOM owned-factory founding gate contract: PASS")
