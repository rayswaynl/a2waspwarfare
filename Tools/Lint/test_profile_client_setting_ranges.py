"""Regression checks for stale client profile setting ranges."""

from pathlib import Path


SOURCE = Path(
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Init/Init_ProfileVariables.sqf"
)


def test_stale_profile_scalars_are_limited_to_the_settings_ui_ranges():
    source = SOURCE.read_text(encoding="utf-8")
    assert '(_profile_var >= 30) && {_profile_var <= 240}' in source
    assert '(_profile_var >= 1) && {_profile_var <= (missionNamespace getVariable "WFBE_C_ENVIRONMENT_MAX_CLUTTER")}' in source


if __name__ == "__main__":
    test_stale_profile_scalars_are_limited_to_the_settings_ui_ranges()
    print("PASS: stale profile scalar settings are range-guarded")
