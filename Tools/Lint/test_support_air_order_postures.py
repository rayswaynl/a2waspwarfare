"""Regression contracts for support-air command posture isolation."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SUPPORT = ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Support"


def test_cargo_escort_uses_a_separate_group_from_its_transport() -> None:
    """An escort's combat posture must not overwrite the transport's group orders."""
    text = (SUPPORT / "Support_CargoAirdrop.sqf").read_text(encoding="utf-8-sig")

    assert '[_side, "aicom_cargo_transport"] Call WFBE_CO_FNC_CreateGroup;' in text
    assert '[_side, "aicom_cargo_escort"] Call WFBE_CO_FNC_CreateGroup;' in text
    assert '[_pilotClass, _escortGroup, [100,12000,0], _sideID]' in text
    assert '_escortGroup setBehaviour "COMBAT";' in text
    assert '_escortGroup setCombatMode "RED";' in text
    assert '_transportGroup setBehaviour "CARELESS";' in text
    assert '_transportGroup setCombatMode "BLUE";' in text


def test_support_transports_use_valid_non_engaging_combat_mode() -> None:
    """STEALTH is a behavior token; BLUE is the intended OA combat-mode token."""
    sources = (
        "Support_CargoAirdrop.sqf",
        "Support_GuerHeliDrop.sqf",
        "Support_ParaAmmo.sqf",
        "Support_Paratroopers.sqf",
        "Support_ParaVehicles.sqf",
    )

    for name in sources:
        text = (SUPPORT / name).read_text(encoding="utf-8-sig")
        assert "setCombatMode 'STEALTH'" not in text
        assert "setCombatMode 'BLUE'" in text or 'setCombatMode "BLUE"' in text
