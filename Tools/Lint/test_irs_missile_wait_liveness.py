from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RELATIVE_PATHS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Module/IRS/IRS_HandleMissile.sqf",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Module/IRS/IRS_HandleMissile.sqf",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Common/Module/IRS/IRS_HandleMissile.sqf",
)


def test_irs_pre_range_wait_exits_when_missile_or_vehicle_dies():
    wait_guards = (
        "isNull _missile",
        "isNull _vehicle",
        "!alive _missile",
        "!alive _vehicle",
        "_missile distance _vehicle < _missile_range",
    )
    exit_guards = ("isNull _missile", "isNull _vehicle", "!alive _missile", "!alive _vehicle")
    source_bytes = []

    for relative_path in RELATIVE_PATHS:
        path = ROOT / relative_path
        source = path.read_text(encoding="utf-8-sig")
        source_bytes.append(path.read_bytes())

        # The wait contract may grow additional fail-clean guards. Assert the
        # safety behavior, not one historical spelling of the whole expression.
        wait_line = next(line.strip() for line in source.splitlines() if line.strip().startswith("waitUntil {"))
        exit_line = next(
            line.strip()
            for line in source.splitlines()
            if line.strip().startswith("if (isNull _missile") and "exitWith {}" in line
        )
        for guard in wait_guards:
            assert guard in wait_line, relative_path
        for guard in exit_guards:
            assert guard in exit_line, relative_path

        wait_offset = source.index(wait_line)
        exit_offset = source.index(exit_line)
        smoke_offset = source.index("_smokeshells =")
        assert wait_offset < exit_offset < smoke_offset, relative_path

    assert source_bytes[0] == source_bytes[1] == source_bytes[2]
