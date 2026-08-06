"""Regression contract for the Init_Town startup boundary telemetry."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = [
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
]
TOWN_INIT = Path("Common/Init/Init_Town.sqf")


def read_town_init(root: Path) -> str:
    return (root / TOWN_INIT).read_text(encoding="utf-8-sig")


def test_town_startup_markers_are_present_and_ordered() -> None:
    source = read_town_init(MISSION_ROOTS[0])

    entry = 'diag_log format ["TOWNENTRY|v1|START|name=%1|modeNil=%2|paramsNil=%3|templateNil=%4", _townName, isNil "townModeSet", isNil "WFBE_Parameters_Ready", isNil "TownTemplate"];'
    gate = 'diag_log format ["TOWNGATE|v1|AFTER|name=%1|waitTicks=%2|mode=%3|params=%4|templateNil=%5", _townName, _wTownMode, townModeSet, WFBE_Parameters_Ready, isNil "TownTemplate"];'

    lines = [line.strip() for line in source.splitlines()]
    entry_line = lines.index(entry)
    gate_line = lines.index(gate)
    wait_line = next(index for index, line in enumerate(lines) if line.startswith("while {(!townModeSet"))
    timeout_line = lines.index('if (!townModeSet || !WFBE_Parameters_Ready || isNil "TownTemplate") then {')
    timeout_close = next(index for index in range(timeout_line + 1, len(lines)) if lines[index] == "};")
    prevent_simulation = lines.index("//--- Prevent the isServer bug on the client.")

    assert entry_line < lines.index('if(isNil "townModeSet")then{')
    assert wait_line < timeout_line < timeout_close < gate_line < prevent_simulation


def test_town_startup_markers_are_mirrored_to_all_maintained_maps() -> None:
    source = (MISSION_ROOTS[0] / TOWN_INIT).read_bytes()

    for mission_root in MISSION_ROOTS[1:]:
        assert (mission_root / TOWN_INIT).read_bytes() == source, mission_root


if __name__ == "__main__":
    test_town_startup_markers_are_present_and_ordered()
    test_town_startup_markers_are_mirrored_to_all_maintained_maps()
