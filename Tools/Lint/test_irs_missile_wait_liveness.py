from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RELATIVE_PATHS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Module/IRS/IRS_HandleMissile.sqf",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Module/IRS/IRS_HandleMissile.sqf",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Common/Module/IRS/IRS_HandleMissile.sqf",
)


def test_irs_pre_range_wait_exits_when_missile_or_vehicle_dies():
    expected_wait = "waitUntil {!alive _missile || {!alive _vehicle} || {_missile distance _vehicle < _missile_range}};"
    expected_exit = "if (!alive _missile || {!alive _vehicle}) exitWith {};"

    for relative_path in RELATIVE_PATHS:
        source = (ROOT / relative_path).read_text(encoding="utf-8-sig")
        assert expected_wait in source, relative_path
        assert expected_exit in source, relative_path
