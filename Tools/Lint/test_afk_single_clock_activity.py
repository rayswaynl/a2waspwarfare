"""Regression contracts for the client AFK timer's single-clock activity model."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus"
INIT = MISSION / "Client/Init/Init_Client.sqf"
KEYS = MISSION / "Client/Module/AFKkick/handleKeys.sqf"
UPDATECLIENT = MISSION / "Client/FSM/updateclient.sqf"


def test_client_starts_only_the_lobby_configured_afk_clock():
    """The old fixed 30-minute monitor must not race updateclient's lobby timer."""
    source = INIT.read_text(encoding="utf-8")
    update_source = UPDATECLIENT.read_text(encoding="utf-8")

    assert '[] execVM "Client\\Module\\AFKkick\\monitorAFK.sqf";' not in source
    assert 'WFBE_C_AFK_TIME' in update_source


def test_non_movement_keyboard_and_mouse_activity_refresh_the_afk_clock():
    """Map/chat/terminal input must count as activity without requiring movement."""
    init_source = INIT.read_text(encoding="utf-8")
    key_source = KEYS.read_text(encoding="utf-8")

    assert 'player setVariable ["lastActionTime", time];' in key_source
    assert '"MouseButtonDown", "if (!isNull player) then {player setVariable [\'lastActionTime\', time]}; false"' in init_source
