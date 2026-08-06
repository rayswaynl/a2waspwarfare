"""Regression contract for the AI supply squad startup gate.

The supply worker is launched before server-side town initialization finishes.
Its startup gate must yield and terminate after a bounded real-time window
instead of leaving a scheduled VM parked forever when town setup fails.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SUPPLY_PATHS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Server_AicomSupplySquad.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/Server_AicomSupplySquad.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/Server_AicomSupplySquad.sqf"),
)


def read(relative: Path) -> str:
    return (ROOT / relative).read_text(encoding="utf-8-sig")


def test_supply_startup_gate_is_bounded_and_fail_closed() -> None:
    for relative in SUPPLY_PATHS:
        text = read(relative)

        assert 'waitUntil { !isNil "townInit" && townInit };' not in text
        assert 'waitUntil { !isNil "towns" };' not in text
        assert "_supplyTownDeadline = diag_tickTime + 90;" in text
        assert "while {!_supplyTownReady && {diag_tickTime < _supplyTownDeadline}" in text
        assert 'missionNamespace getVariable ["townInit", false]' in text
        assert "_supplyTownsReady = !isNil \"towns\" && {count towns > 0};" in text
        assert "sleep 0.25;" in text
        assert "AICOMSUPPLY|STARTUP_TIMEOUT" in text
        assert "if (!_supplyTownReady) exitWith" in text


def test_supply_startup_gate_mirrors_are_byte_identical() -> None:
    blobs = [(ROOT / relative).read_bytes() for relative in SUPPLY_PATHS]
    assert blobs[0] == blobs[1] == blobs[2]


if __name__ == "__main__":
    test_supply_startup_gate_is_bounded_and_fail_closed()
    test_supply_startup_gate_mirrors_are_byte_identical()
    print("AICOM supply startup readiness contract: PASS")
