"""Regression coverage for the Chernarus GUER contract indicator snapshot."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DIRECTOR_PATH = Path(
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Server_GuerDirector.sqf"
)
COMMISSAR_PATH = Path(
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/GUI/GUI_Menu_GuerCommissar.sqf"
)


def test_chernarus_director_publishes_sanitized_armed_contract_pairs() -> None:
    text = (ROOT / DIRECTOR_PATH).read_text(encoding="utf-8")

    assert "_snapContracts" in text
    assert '(_ctrSnap select 7) == "armed"' in text
    assert "[_ctrSnap select 2, _ctrSnap select 1]" in text
    assert "_snapTransit, _snapContracts]" in text


def test_chernarus_commissar_reads_public_snapshot_not_server_store() -> None:
    text = (ROOT / COMMISSAR_PATH).read_text(encoding="utf-8")

    assert "AICOMV2_GDIR_CONTRACT_RECORDS" not in text
    assert "WFBE_COMM_GDIR_SNAP" in text
    assert "_snapContracts" in text
    assert "select 6" in text
    assert "_cTownR = _ctrR select 0" in text
    assert "_cKindR = _ctrR select 1" in text
