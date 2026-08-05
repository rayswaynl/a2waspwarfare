from pathlib import Path


SOURCE = (
    Path(__file__).resolve().parents[2]
    / "Missions"
    / "[55-2hc]warfarev2_073v48co.chernarus"
    / "Client"
    / "Functions"
    / "Client_OnKilled.sqf"
)


def test_respawn_timeout_aborts_before_living_body_restore_work():
    """A failed respawn must not reconfigure the still-dead player body."""
    source = SOURCE.read_text(encoding="utf-8-sig")
    wait = 'waitUntil {sleep 0.2; alive player || {(time - _respawnWaitT0) > 600}};'
    timeout_abort = 'if (!alive player) exitWith {'
    restore = '["RequestSpecial", ["update-teamleader", WFBE_Client_Team, player]] Call WFBE_CO_FNC_SendToServer;'

    assert wait in source
    assert timeout_abort in source
    assert source.index(wait) < source.index(timeout_abort) < source.index(restore)
