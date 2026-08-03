#!/usr/bin/env python3
"""Regression coverage for the one-shot town-coordinate RPT harvest gate."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad"),
)

DEFAULT = 'if (isNil "WFBE_C_LOG_TOWN_COORDS") then {WFBE_C_LOG_TOWN_COORDS = 0};'
LEGACY_FORCED_ON = "WFBE_C_LOG_TOWN_COORDS = 1;"
SERVER_GATE = 'missionNamespace getVariable ["WFBE_C_LOG_TOWN_COORDS", 0]'


def test_town_coordinate_rpt_harvest_is_default_off_and_operator_overridable() -> None:
    for mission in MISSIONS:
        constants = (ROOT / mission / "Common/Init/Init_CommonConstants.sqf").read_text(
            encoding="utf-8"
        )
        towns_init = (ROOT / mission / "Server/Init/Init_Towns.sqf").read_text(
            encoding="utf-8"
        )

        assert DEFAULT in constants, f"{mission}: coordinate logger must default off"
        assert LEGACY_FORCED_ON not in constants, f"{mission}: coordinate logger overwrites operator setting"
        assert SERVER_GATE in towns_init, f"{mission}: coordinate emission must remain server-gated"
        assert 'diag_log Format ["TOWNPOS|v1|' in towns_init, f"{mission}: harvest emission missing"


if __name__ == "__main__":
    test_town_coordinate_rpt_harvest_is_default_off_and_operator_overridable()
