from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
UAV_INTERFACE = (
    ROOT
    / "Missions"
    / "[55-2hc]warfarev2_073v48co.chernarus"
    / "Client"
    / "Module"
    / "UAV"
    / "uav_interface.sqf"
)


def test_uav_keyboard_speed_uses_the_same_kmh_value_as_initialization():
    source = UAV_INTERFACE.read_text(encoding="utf-8")

    assert "driver _uav forcespeed (_level / 3.6);" not in source
    assert source.count("driver _uav forcespeed _level;") == 2
