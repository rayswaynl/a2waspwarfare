"""Regression contract for OA vehicle rearm muzzle binding."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
REARM = ROOT / (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/"
    "Common/Functions/Common_RearmVehicleOA.sqf"
)


def test_oa_rearm_uses_engine_binding_for_multi_muzzle_turrets() -> None:
    """Rearming must not replay a combined turret magazine list by path."""
    source = REARM.read_text(encoding="utf-8-sig")

    assert "_vehicle setVehicleAmmo 1;" in source, (
        "OA rearm must restore the engine-configured weapon/magazine bindings"
    )
    assert "WFBE_CO_FNC_GetVehicleTurretsGear" not in source, (
        "OA rearm still flattens multi-muzzle turret magazine lists before restoring them"
    )
    assert "WFBE_CO_FNC_SetTurretsMagazines" not in source, (
        "OA rearm still replays a combined turret magazine list without a weapon binding"
    )
