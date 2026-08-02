"""Regression check for the compiled artillery Fired event-handler payload."""

from pathlib import Path


SOURCE = Path(
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_FireArtillery.sqf"
)


def test_fired_handler_serializes_ammo_classnames_with_sqf_quotes():
    source = SOURCE.read_text(encoding="utf-8")
    assert "_ammoText = str _ammo;" in source
    assert ",_ammoText,_destination," in source


if __name__ == "__main__":
    test_fired_handler_serializes_ammo_classnames_with_sqf_quotes()
    print("PASS: artillery Fired handler preserves ammo classname strings")
