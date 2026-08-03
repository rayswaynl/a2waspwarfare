"""Regression coverage for batching ruins-cleaner cooperative sleeps."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PATHS = (
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/FSM/cleaners/ruins_cleaner.sqf",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/FSM/cleaners/ruins_cleaner.sqf",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/FSM/cleaners/ruins_cleaner.sqf",
)


def test_ruins_cleaner_batches_cooperative_sleeps() -> None:
    for path in PATHS:
        source = path.read_text(encoding="utf-8")
        assert '"_batchCount"' in source
        assert 'WFBE_C_RUINS_CLEANER_BATCH_SIZE", 8' in source
        assert "_batchCount = _batchCount + 1;" in source
        assert "if (_batchCount >= _batchSize) then {_batchCount = 0; sleep 0.5};" in source
        assert "_batchCount = 0;" in source
        assert "\n\t\tsleep 0.5;\n\t} forEach _clear;" not in source


def test_ruins_cleaner_mirrors_are_byte_identical() -> None:
    contents = [path.read_bytes() for path in PATHS]
    assert contents[0] == contents[1] == contents[2]
