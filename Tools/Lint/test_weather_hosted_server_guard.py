#!/usr/bin/env python3
"""Regression contract for authoritative weather on player-hosted servers."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SERVER_INIT = (
    ROOT
    / "Missions"
    / "[55-2hc]warfarev2_073v48co.chernarus"
    / "Server"
    / "Init"
    / "Init_Server.sqf"
)


def test_weather_transition_runs_on_every_server_role() -> None:
    server_init = SERVER_INIT.read_text(encoding="utf-8")
    weather_block = server_init[
        server_init.index("//--- Weather.") : server_init.index(
            '["INITIALIZATION", "Init_Server.sqf: Weather module is loaded."]'
        )
    ]

    assert "if (!isServer) exitWith {};" in weather_block, (
        "The authoritative weather transition must run on both dedicated and player-hosted servers."
    )
    assert "if (!isDedicated) exitWith {};" not in weather_block, (
        "A dedicated-only weather guard skips the authoritative transition on a player-hosted server."
    )


if __name__ == "__main__":
    test_weather_transition_runs_on_every_server_role()
    print("weather hosted-server guard contract: PASS")
