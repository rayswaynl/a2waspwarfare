#!/usr/bin/env python3
"""Regression contract for client-local rainy-weather initialization."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"


def test_rainy_lobby_weather_initializes_rain_on_each_client() -> None:
    client_init = (MISSION / "Client" / "Init" / "Init_Client.sqf").read_text(encoding="utf-8")
    weather_block = client_init[client_init.index("//--- Handle the weather."):client_init.index("// Marty: Volumetric clouds")]

    assert "case 2: {_oc = 1; _rain = 0.5};" in weather_block, (
        "Rainy lobby weather must retain its 0.5 rain target in the client weather path"
    )
    assert "setRain _rain;" in weather_block, (
        "Rainy lobby weather must apply the server-authored rain target on clients"
    )


if __name__ == "__main__":
    test_rainy_lobby_weather_initializes_rain_on_each_client()
    print("weather client rain contract: PASS")
