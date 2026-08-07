from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)


def _read(mission: str) -> str:
    return (ROOT / mission / "Server/FSM/server_town_ai.sqf").read_text(encoding="utf-8-sig")


def test_contested_sortie_stays_tracked_until_it_returns_to_its_town_post():
    for mission in MISSIONS:
        town_ai = _read(mission)
        contested = town_ai.index("if (_currentEnemies > 0) then {")
        no_contact = town_ai.index("} else {", contested)
        recall = town_ai.index('"wfbe_sortie_recalled", true', contested, no_contact)
        return_start = town_ai.index('"wfbe_sortie_rtb", true', no_contact)
        assert recall < no_contact < return_start
        assert '"wfbe_sortie_grp", grpNull, true' not in town_ai[contested:no_contact]
