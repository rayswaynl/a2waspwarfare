from pathlib import Path


def test_base_reap_uses_scheduled_safe_crew_teardown():
    source = Path(
        "Missions/[55-2hc]warfarev2_073v48co.chernarus/"
        "Common/Functions/Common_RunCommanderTeam.sqf"
    ).read_text(encoding="utf-8")
    start = source.index("B74.2 HELI BASE-REAP")
    end = source.index("} forEach _reapVehs;", start)
    base_reap = source[start:end]

    assert "[_rh, true] Spawn WFBE_CO_FNC_SafeCrewDelete;" in base_reap
    assert "deleteVehicle _rh;" not in base_reap
