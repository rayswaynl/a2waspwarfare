"""Regression contract for OA-local weather replay from server-authored state."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"


def test_server_publishes_timestamped_weather_state() -> None:
    server_init = (MISSION / "Server" / "Init" / "Init_Server.sqf").read_text(encoding="utf-8")

    assert "WFBE_ENVIRONMENT_WEATHER_STATE" in server_init
    assert 'publicVariable "WFBE_ENVIRONMENT_WEATHER_STATE"' in server_init
    assert "[time, 60, _oc, _rain]" in server_init


def test_client_replays_only_the_remaining_authoritative_transition() -> None:
    client_init = (MISSION / "Client" / "Init" / "Init_Client.sqf").read_text(encoding="utf-8")

    assert "WFBE_ENVIRONMENT_WEATHER_STATE" in client_init
    assert "addPublicVariableEventHandler" in client_init
    assert "_remaining = (_state select 1) - (time - (_state select 0));" in client_init
    assert "_remaining max 0" in client_init


if __name__ == "__main__":
    test_server_publishes_timestamped_weather_state()
    test_client_replays_only_the_remaining_authoritative_transition()
    print("weather authoritative sync contract: PASS")
