from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SERVER_TOWN = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / "Server" / "FSM" / "server_town.sqf"


def test_guer_capture_reaps_untracked_static_gunner_before_clearing_reference():
    source = SERVER_TOWN.read_text(encoding="utf-8")
    start = source.index("//--- B36 (Ray 2026-06-15): capturing a GUER town")
    end = source.index("} forEach (_location getVariable", start)
    cleanup = source[start:end]

    gunner_read = cleanup.index("_oldGunner = gunner _def")
    gunner_delete = cleanup.index("deleteVehicle _oldGunner")
    defense_clear = cleanup.index('setVariable ["wfbe_defense", nil]')

    assert gunner_read < gunner_delete < defense_clear
    assert 'isNil { _x getVariable "wfbe_defense_operator" }' in cleanup
