from pathlib import Path


MIRRORS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/AI/Commander/AI_Commander.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/AI/Commander/AI_Commander.sqf"),
)

TOWN_SCAN = '{ if ((_x getVariable "sideID") == _myID) then {_stipendTowns = _stipendTowns + 1} } forEach towns;'
STIPEND_GUARD = "if (time < _stipendMaxTime) then {"


def test_stipend_town_scan_is_cutoff_guarded_in_all_mirrors():
    repo_root = Path(__file__).parents[2]

    for relative_path in MIRRORS:
        source = (repo_root / relative_path).read_text(encoding="utf-8")
        scan_pos = source.index(TOWN_SCAN)
        towns_init_pos = source.rfind("_stipendTowns = 0;", 0, scan_pos)
        guard_pos = source.rfind(STIPEND_GUARD, 0, scan_pos + 1)
        active_pos = source.index("_stipendActive =", scan_pos)
        guard_close_pos = source.index("};", scan_pos)

        assert source.count(TOWN_SCAN) == 1
        assert towns_init_pos >= 0
        assert guard_pos > towns_init_pos
        assert guard_close_pos < active_pos
