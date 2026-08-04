from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCES = [
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / "Common" / "Functions" / "Common_RunSidePatrol.sqf",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan" / "Common" / "Functions" / "Common_RunSidePatrol.sqf",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad" / "Common" / "Functions" / "Common_RunSidePatrol.sqf",
]


def test_frontline_target_is_revalidated_before_arrival():
    invalidation = 'PATROL_TARGET_INVALIDATED'
    arrival = 'if ((leader _team) distance _target < 200) then {'

    for path in SOURCES:
        source = path.read_text(encoding="utf-8")
        assert invalidation in source
        assert source.index(invalidation) < source.index(arrival)


def test_rtb_home_is_revalidated_before_rtb_arrival_cleanup():
    retarget = 'PATROL_RTB_RETARGET'
    arrival_cleanup = 'if (!isNull _rtbHome && {(leader _team) distance _rtbHome < 100}) then {'

    for path in SOURCES:
        source = path.read_text(encoding="utf-8")
        assert retarget in source
        assert source.index(retarget) < source.index(arrival_cleanup)


def test_all_terrain_mirrors_remain_byte_identical():
    assert SOURCES[1].read_bytes() == SOURCES[0].read_bytes()
    assert SOURCES[2].read_bytes() == SOURCES[0].read_bytes()
