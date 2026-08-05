from pathlib import Path


AT_GUIDANCE = (
    Path(__file__).resolve().parents[2]
    / "Missions"
    / "[55-2hc]warfarev2_073v48co.chernarus"
    / "Common"
    / "Functions"
    / "Common_HandleATMissiles.sqf"
)


def test_at_guidance_dispatches_cfgammo_classes_by_exact_ammo_name():
    """CfgAmmo class strings are not CfgVehicles inheritance receivers."""
    source = AT_GUIDANCE.read_text(encoding="utf-8-sig")
    assert 'case (_am == "M_AT10_AT")' in source
    assert 'case (_am == "M_AT11_AT")' in source
    assert 'case (_am isKindOf "M_AT10_AT")' not in source
    assert 'case (_am isKindOf "M_AT11_AT")' not in source
