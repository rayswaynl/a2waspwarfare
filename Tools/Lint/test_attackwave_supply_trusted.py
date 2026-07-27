"""Regression contract for the heavy-attack supply debit after PR #1402.

PR #1402 makes the side-supply handler reject untrusted in-process calls when
WFBE_C_SEC_HARDENING is armed.  The heavy-attack debit is a server-internal
call, so every maintained AttackWave copy must use the same ``true`` trust
argument already established by Common_ChangeSideSupply.sqf.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ATTACK_WAVE_PATHS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/PVFunctions/AttackWave.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/PVFunctions/AttackWave.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/PVFunctions/AttackWave.sqf"),
)
SUPPLY_PATHS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_ChangeSideSupply.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Functions/Common_ChangeSideSupply.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Common/Functions/Common_ChangeSideSupply.sqf"),
)

DEBIT_CALL = (
    '[[format ["wfbe_supply_temp_%1", _side], '
    '[_side, -(_side call GetSideSupply), "Heavy attack mode activated."]], '
    '_side, true] Call WFBE_SE_FNC_HandleSideSupplyChange;'
)
LEGACY_DEBIT_CALL = (
    '[[format ["wfbe_supply_temp_%1", _side], '
    '[_side, -(_side call GetSideSupply), "Heavy attack mode activated."]], '
    '_side] Call WFBE_SE_FNC_HandleSideSupplyChange;'
)
COMMON_TRUST_CALL = (
    '[[format ["wfbe_supply_temp_%1", _side], [_side, _amount, _reason]], '
    '_side, true] Call WFBE_SE_FNC_HandleSideSupplyChange;'
)


def read(relative: Path) -> str:
    return (ROOT / relative).read_text(encoding="utf-8-sig")


def test_heavy_attack_debit_is_trusted_in_all_maintained_terrains() -> None:
    for relative in ATTACK_WAVE_PATHS:
        text = read(relative)
        assert DEBIT_CALL in text
        assert LEGACY_DEBIT_CALL not in text


def test_common_supply_fix_keeps_the_established_trusted_call_shape() -> None:
    for relative in SUPPLY_PATHS:
        assert COMMON_TRUST_CALL in read(relative)


def test_attackwave_debit_does_not_add_a_flag_gate() -> None:
    for relative in ATTACK_WAVE_PATHS:
        text = read(relative)
        assert "WFBE_C_SEC_HARDENING" not in text
        assert "GetSideSupply" in text


def test_attackwave_mirrors_are_byte_identical() -> None:
    blobs = [(ROOT / relative).read_bytes() for relative in ATTACK_WAVE_PATHS]
    assert blobs[0] == blobs[1] == blobs[2]


if __name__ == "__main__":
    test_heavy_attack_debit_is_trusted_in_all_maintained_terrains()
    test_common_supply_fix_keeps_the_established_trusted_call_shape()
    test_attackwave_debit_does_not_add_a_flag_gate()
    test_attackwave_mirrors_are_byte_identical()
    print("AttackWave trusted supply debit contract: PASS")
