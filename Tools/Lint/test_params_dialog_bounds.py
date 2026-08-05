#!/usr/bin/env python3
"""Regression checks for stale or short MP paramsArray values in the parameters dialog."""

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TERRAINS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)


def test_params_dialog_falls_back_for_missing_or_nil_lobby_slots() -> None:
    expected_read = re.compile(
        r"""
        _value\s*=\s*if\s*\(isMultiplayer\)\s*then\s*\{\s*
            if\s*\(_i\s*<\s*count\s+paramsArray\)\s*then\s*\{\s*
                paramsArray\s+select\s+_i\s*
            \}\s*else\s*\{\s*
                getNumber\s*\(missionConfigFile\s*>>\s*"Params"\s*>>\s*_paramName\s*>>\s*"default"\)\s*
            \}\s*
        \}\s*else\s*\{\s*
            getNumber\s*\(missionConfigFile\s*>>\s*"Params"\s*>>\s*_paramName\s*>>\s*"default"\)\s*
        \};
        """,
        re.VERBOSE,
    )

    for terrain in TERRAINS:
        source = (
            ROOT / terrain / "Client/GUI/GUI_Display_Parameters.sqf"
        ).read_text(encoding="utf-8")
        assert expected_read.search(source), (
            f"{terrain}: parameters dialog must bounds-check paramsArray before select"
        )
        assert 'if (isNil "_value") then' in source, (
            f"{terrain}: parameters dialog must replace a nil lobby slot with its default"
        )


if __name__ == "__main__":
    test_params_dialog_falls_back_for_missing_or_nil_lobby_slots()
    print("params dialog bounds regression check passed")
