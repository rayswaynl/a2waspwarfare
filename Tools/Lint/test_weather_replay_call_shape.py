#!/usr/bin/env python3
"""Regression contract for the weather replay helper's SQF call payload."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CLIENT_INIT = (
    ROOT
    / "Missions"
    / "[55-2hc]warfarev2_073v48co.chernarus"
    / "Client"
    / "Init"
    / "Init_Client.sqf"
)


def _weather_block() -> str:
    source = CLIENT_INIT.read_text(encoding="utf-8")
    start = source.index(
        "// OA weather commands are local, so replay the server-authored state"
    )
    end = source.index(
        "// Marty: Volumetric clouds are disabled globally;",
        start,
    )
    return source[start:end]


def test_weather_replay_passes_the_state_array_directly() -> None:
    block = _weather_block()

    # The helper intentionally treats _this as the four-slot state array.
    assert "_state = _this;" in block

    # A wrapped [_state] Call makes _this a one-element array, so the helper's
    # count/type guards exit before issuing setOvercast/setRain.
    assert "[_state] Call WFBE_CL_FNC_ApplyEnvironmentWeather;" not in block
    assert "[_this select 1] Call WFBE_CL_FNC_ApplyEnvironmentWeather;" not in block
    assert "_state Call WFBE_CL_FNC_ApplyEnvironmentWeather;" in block
    assert "(_this select 1) Call WFBE_CL_FNC_ApplyEnvironmentWeather;" in block


if __name__ == "__main__":
    test_weather_replay_passes_the_state_array_directly()
    print("weather replay call-shape contract: PASS")
