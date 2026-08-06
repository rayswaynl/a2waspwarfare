"""Regression contract for AICOM refill-hull triage refresh.

``AIBuyUnit`` can add a crewed refill to a long-lived commander group after
``Common_RunCommanderTeam`` captured its original vehicle array.  The order
loop must fold currently crewed group hulls into that array before its
abandonment and service decisions, otherwise a damaged or immobile refill is
invisible for the remainder of the team's lifetime.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RUNNER_PATHS = (
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_RunCommanderTeam.sqf",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Functions/Common_RunCommanderTeam.sqf",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Common/Functions/Common_RunCommanderTeam.sqf",
)

REFILL_VEHICLE_REFRESH = (
    "{if (!isNull _x && {!(_x in _vehicles)}) then {_vehicles = _vehicles + [_x]}} "
    "forEach ([_team, false] Call GetTeamVehicles);"
)


def test_refill_hulls_join_the_long_lived_commander_triage_set() -> None:
    raw = []
    for path in RUNNER_PATHS:
        source = path.read_text(encoding="utf-8-sig")
        raw.append(path.read_bytes())

        assert REFILL_VEHICLE_REFRESH in source, (
            "commander loop does not refresh post-foundation refill hulls: %s" % path
        )
        assert source.index(REFILL_VEHICLE_REFRESH) < source.index("//--- TRUCK-ABANDON"), (
            "refresh must run before abandonment triage: %s" % path
        )
        assert source.index(REFILL_VEHICLE_REFRESH) < source.index(
            "Call WFBE_CO_FNC_AICOMServiceTick"
        ), "refresh must run before service triage: %s" % path

    assert raw[0] == raw[1] == raw[2], "commander triage mirrors differ"
