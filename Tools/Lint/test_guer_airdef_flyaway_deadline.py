from pathlib import Path


SOURCE = Path(__file__).parents[2] / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / "Server" / "Server_GuerAirDef.sqf"


def test_flyaway_timeout_uses_a_real_time_deadline():
    source = SOURCE.read_text(encoding="utf-8")
    start = source.index('_timeout = missionNamespace getVariable ["WFBE_C_GUER_AIRDEF_FLYAWAY_TIMEOUT", 60];')
    end = source.index('diag_log format ["GUERAIRDEF|FLYAWAYDESPAWN|', start)
    flyaway_wait = source[start:end]

    assert "_deadline = time + _timeout;" in flyaway_wait
    assert "time >= _deadline" in flyaway_wait
    assert "_tick = _tick + 1;" not in flyaway_wait
