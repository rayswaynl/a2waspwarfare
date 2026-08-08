from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CONSTRUCTION_FILES = (
    (
        ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / "Server" / "Construction" / "Construction_MediumSite.sqf",
        3,
    ),
    (
        ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / "Server" / "Construction" / "Construction_SmallSite.sqf",
        2,
    ),
    (
        ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan" / "Server" / "Construction" / "Construction_MediumSite.sqf",
        3,
    ),
    (
        ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan" / "Server" / "Construction" / "Construction_SmallSite.sqf",
        2,
    ),
    (
        ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad" / "Server" / "Construction" / "Construction_MediumSite.sqf",
        3,
    ),
    (
        ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad" / "Server" / "Construction" / "Construction_SmallSite.sqf",
        2,
    ),
)

YIELDED_WAIT = "waitUntil {sleep 0.05; time >= _timeNextUpdate || {isNull _nearLogic}};"
LEGACY_WAIT = "waitUntil {time >= _timeNextUpdate || {isNull _nearLogic}};"


def test_time_mode_construction_waits_yield():
    for path, expected_count in CONSTRUCTION_FILES:
        source = path.read_text(encoding="utf-8-sig")
        assert source.count(YIELDED_WAIT) == expected_count
        assert source.count(LEGACY_WAIT) == 0
