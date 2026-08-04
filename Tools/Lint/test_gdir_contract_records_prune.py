"""Regression coverage for the r126 GDIR contract-records prune (long-match state growth)."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DIRECTOR_PATHS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Server_GuerDirector.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/AI/Server_GuerDirector.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/AI/Server_GuerDirector.sqf"),
)

PRUNE_FILTER = (
    '{if ((_x select 7) == "armed") then '
    '{_liveContracts set [count _liveContracts, _x]}} forEach _updContracts;'
)
PRUNE_WRITEBACK = (
    'missionNamespace setVariable ["AICOMV2_GDIR_CONTRACT_RECORDS", _liveContracts];'
)
PRIVATE_DECLARATION = 'private ["_liveContracts"];'


def test_contract_records_writeback_prunes_non_armed_records() -> None:
    for relative_path in DIRECTOR_PATHS:
        text = (ROOT / relative_path).read_text(encoding="utf-8")

        assert PRIVATE_DECLARATION in text, f"prune local is not private in {relative_path}"
        assert PRUNE_FILTER in text, f"armed-only prune filter missing in {relative_path}"
        assert PRUNE_WRITEBACK in text, f"write-back does not use pruned array in {relative_path}"

        #--- The filter must run between the poll loop and the write-back.
        assert text.index(PRIVATE_DECLARATION) < text.index(PRUNE_FILTER)
        assert text.index(PRUNE_FILTER) < text.index(PRUNE_WRITEBACK)
