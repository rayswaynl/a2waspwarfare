from pathlib import Path
import re


SOURCE = Path(
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/"
    "Common/Functions/Common_RunCommanderTeam.sqf"
)


def team_cleanup_tail() -> str:
    source = SOURCE.read_text(encoding="utf-8")
    marker = "//--- Team wiped: release the brain's slot."
    return source[source.rindex(marker):]


def test_team_tail_uses_scheduled_seat_safe_cleanup():
    tail = team_cleanup_tail()

    assert "[_team] Spawn {" in tail
    assert "_cleanupUnits = +(units _cleanupTeam);" in tail
    assert "if (!isNull _cleanupUnit && {!isPlayer _cleanupUnit})" in tail
    assert re.search(r"deleteVehicle _cleanupUnit;\s+sleep 0;", tail)
    assert "deleteGroup _cleanupTeam" in tail
    assert "{if (!isNull _x && {!isPlayer _x}) then {deleteVehicle _x}} forEach (units _team);" not in tail


def test_team_tail_probe_precedes_every_direct_unit_delete():
    tail = team_cleanup_tail()

    assert re.search(
        r"WFBE_CO_FNC_LogVehDelete;\s+deleteVehicle _cleanupUnit;",
        tail,
    )
