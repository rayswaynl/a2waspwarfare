#!/usr/bin/env python3
"""Regression contract for GUER-only director intelligence delivery."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad"),
)
STATE_KEYS = ("WFBE_GDIR_ORDER_MSG", "AICOMV2_GDIR_JIP_SNAP")


def test_guer_director_state_is_published_only_to_resistance_clients() -> None:
    for mission in MISSIONS:
        server_init = (ROOT / mission / "Server/Init/Init_Server.sqf").read_text(encoding="utf-8-sig")
        director = (ROOT / mission / "Server/AI/Server_GuerDirector.sqf").read_text(encoding="utf-8-sig")

        assert "WFBE_SE_FNC_PublishResistanceState" in server_init
        for key in STATE_KEYS:
            assert f'publicVariable "{key}";' not in director
            assert f'["{key}"] Call WFBE_SE_FNC_PublishResistanceState;' in director


def test_guer_director_jip_snapshot_is_not_replayed_to_non_resistance_joiners() -> None:
    for mission in MISSIONS:
        connect = (ROOT / mission / "Server/Functions/Server_OnPlayerConnected.sqf").read_text(encoding="utf-8-sig")

        assert 'if (_sideJoined == resistance) then {' in connect
        assert '_id publicVariableClient "AICOMV2_GDIR_JIP_SNAP"' in connect


if __name__ == "__main__":
    test_guer_director_state_is_published_only_to_resistance_clients()
    test_guer_director_jip_snapshot_is_not_replayed_to_non_resistance_joiners()
