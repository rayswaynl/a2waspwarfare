"""Regression contract for AICOM passenger egress after early transport loss."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad"),
)

FIXED_LOSS_CLEANUP = (
    "{if (alive _x) then {if (vehicle _x != _x) then {"
    "unassignVehicle _x; [_x] orderGetIn false; "
    "if (vehicle _x != _x) then {moveOut _x}}; _x doMove _obj}} forEach _pax;"
)

OLD_LOSS_CLEANUP = (
    "{if (alive _x) then {if (vehicle _x != _x) then {"
    "unassignVehicle _x; [_x] orderGetIn false}; _x doMove _obj}} forEach _pax;"
)


def test_airleg_early_transport_loss_forces_egress_in_both_abort_exits() -> None:
    for mission in MISSIONS:
        source = (ROOT / mission / "Common/Functions/Common_AICOMAirLeg.sqf").read_text(
            encoding="utf-8-sig"
        )

        assert source.count(FIXED_LOSS_CLEANUP) == 2
        assert source.count(OLD_LOSS_CLEANUP) == 0
