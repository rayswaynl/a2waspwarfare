"""Regression coverage for the client-visible GUER contract indicator snapshot."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DIRECTOR_PATHS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Server_GuerDirector.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/AI/Server_GuerDirector.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/AI/Server_GuerDirector.sqf"),
)
COMMISSAR_PATHS = (
    Path(
        "Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/GUI/GUI_Menu_GuerCommissar.sqf"
    ),
    Path(
        "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/GUI/GUI_Menu_GuerCommissar.sqf"
    ),
    Path(
        "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Client/GUI/GUI_Menu_GuerCommissar.sqf"
    ),
)


def test_director_jip_snapshot_carries_sanitized_armed_contract_pairs() -> None:
    for relative_path in DIRECTOR_PATHS:
        text = (ROOT / relative_path).read_text(encoding="utf-8")

        assert "_snapContracts" in text, f"contract snapshot local missing in {relative_path}"
        assert "(_ctrSnap select 7) == \"armed\"" in text, (
            f"snapshot is not restricted to armed contracts in {relative_path}"
        )
        assert "[_ctrSnap select 2, _ctrSnap select 1]" in text, (
            f"snapshot would expose more than town/kind in {relative_path}"
        )
        assert "_snapTransit, _snapContracts]" in text, (
            f"contract snapshot is not appended to the JIP payload in {relative_path}"
        )


def test_commissar_indicator_reads_public_snapshot_not_server_contract_store() -> None:
    for relative_path in COMMISSAR_PATHS:
        text = (ROOT / relative_path).read_text(encoding="utf-8")

        assert "AICOMV2_GDIR_CONTRACT_RECORDS" not in text
        assert "WFBE_COMM_GDIR_SNAP" in text
        assert "_snapContracts" in text
        assert "select 6" in text
        assert "_cTownR = _ctrR select 0" in text
        assert "_cKindR = _ctrR select 1" in text
