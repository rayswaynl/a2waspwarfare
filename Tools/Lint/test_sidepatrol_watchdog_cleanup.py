"""Contracts for the side-patrol watchdog's terminal cleanup order and guards."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)
SERVER_RELATIVE = "Server/FSM/server_side_patrols.sqf"
CLIENT_RELATIVE = "Client/PVFunctions/HandleSpecial.sqf"


def _read(mission: str, relative: str) -> str:
    return (ROOT / mission / relative).read_text(encoding="utf-8-sig")


def _cleanup_block(source: str, start_marker: str, end_marker: str) -> str:
    start = source.index(start_marker)
    end = source.index(end_marker, start)
    return source[start:end]


def _assert_cleanup_contract(block: str, units_token: str, vehicles_token: str, group_token: str) -> None:
    delete_lines = block.splitlines()
    unit_line = next(
        line for line in delete_lines if "deleteVehicle" in line and f"forEach {units_token};" in line
    )
    vehicle_line = next(
        line for line in delete_lines if "deleteVehicle" in line and f"forEach {vehicles_token};" in line
    )
    group_line = next(line for line in delete_lines if f"deleteGroup {group_token}" in line)

    assert "!isPlayer _x" in unit_line
    assert "({isPlayer _x} count (crew _x)) == 0" in vehicle_line
    assert block.index(unit_line) < block.index(vehicle_line)
    assert f"({{isPlayer _x}} count (units {group_token})) == 0" in group_line


def test_server_watchdog_cleanup_is_unit_first_and_player_safe() -> None:
    for mission in MISSIONS:
        source = _read(mission, SERVER_RELATIVE)
        block = _cleanup_block(
            source,
            "//--- FINAL STRIKE: recycle the patrol",
            'diag_log ("AICOMSTAT|v1|EVENT|"',
        )
        _assert_cleanup_contract(block, "_pwUnits", "_pwVehicles", "_pwGrp")


def test_client_watchdog_cleanup_matches_server_contract() -> None:
    for mission in MISSIONS:
        source = _read(mission, CLIENT_RELATIVE)
        block = _cleanup_block(
            source,
            "if (_wTier == 4) then {",
            'diag_log Format ["WARNING sidepatrol-watchdog',
        )
        _assert_cleanup_contract(block, "_wUnits", "_wVehicles", "_wGrp")


def test_watchdog_mirrors_are_byte_identical() -> None:
    for relative in (SERVER_RELATIVE, CLIENT_RELATIVE):
        contents = [(ROOT / mission / relative).read_bytes() for mission in MISSIONS]
        assert contents[0] == contents[1] == contents[2]
