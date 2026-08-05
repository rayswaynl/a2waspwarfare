from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)


def _read(mission: str, relative: str) -> str:
    return (ROOT / mission / relative).read_text(encoding="utf-8-sig")


def test_garrison_sortie_tag_bypasses_global_road_bias_scan():
    for mission in MISSIONS:
        patrol = _read(mission, "Server/AI/Orders/AI_Patrol.sqf")
        assert '"wfbe_garrison_sortie"' in patrol
        assert 'WFBE_CO_FNC_GroupGetBool' in patrol
        assert '&& {!([_team, "wfbe_garrison_sortie", false] Call WFBE_CO_FNC_GroupGetBool)}' in patrol


def test_garrison_sortie_sets_tag_before_patrol_order():
    for mission in MISSIONS:
        sortie = _read(mission, "Server/Server_GarrisonSortie.sqf")
        tag = sortie.index('_grp setVariable ["wfbe_garrison_sortie", true, false];')
        patrol = sortie.index('Call AIPatrol;', tag)
        assert tag < patrol
