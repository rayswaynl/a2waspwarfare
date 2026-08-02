#!/usr/bin/env python3
"""Contract: a late JIP player receives the current scheduled-restart warning.

The periodic global RestartAnnounce broadcast is not replayed by A2 OA.  The
server's join resolver must therefore send the *current* remaining countdown
directly to a resolved human player while the warning window is still live.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCES = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / "Server" / "Functions" / "Server_OnPlayerConnected.sqf",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan" / "Server" / "Functions" / "Server_OnPlayerConnected.sqf",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad" / "Server" / "Functions" / "Server_OnPlayerConnected.sqf",
)


def test_late_jip_receives_a_direct_current_restart_warning_before_funds_latch():
    for source in SOURCES:
        text = source.read_text(encoding="utf-8-sig")
        replay = text.index("RESTART JIP REPLAY")
        funds_latch = text.index("JIPFUNDS GUARDS")
        assert replay < funds_latch, source

        replay_window = text[replay:funds_latch]
        assert 'missionNamespace getVariable ["WFBE_C_RESTART_ENABLED", 0]' in replay_window
        assert 'missionNamespace getVariable ["WFBE_C_RESTART_AT_MIN", 90]' in replay_window
        assert 'missionNamespace getVariable ["WFBE_C_RESTART_WARN_MIN", 5]' in replay_window
        assert "ceil ((_restartJipUntil - time) / 60)" in replay_window
        assert '[leader _team, "RestartAnnounce", [Format [_restartJipMsg, _restartJipMinutes]]]' in replay_window
        assert "Call WFBE_CO_FNC_SendToClient" in replay_window
