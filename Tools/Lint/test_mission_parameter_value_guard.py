#!/usr/bin/env python3
"""Regression contract for rejecting stale lobby values outside the live schema."""

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TERRAINS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)
MISSION = TERRAINS[0]


def test_parameter_ingestion_falls_back_when_lobby_value_is_not_in_current_schema() -> None:
    config = (MISSION / "Rsc" / "Parameters.hpp").read_text(encoding="utf-8")

    start_mode = re.search(
        r'class WFBE_C_BASE_STARTING_MODE\s*\{(?P<body>.*?)\n\s*\};',
        config,
        re.DOTALL,
    )
    assert start_mode, "starting-mode parameter schema is missing"
    assert "values[] = {0,1,2};" in start_mode.group("body")
    assert "default = 2" in start_mode.group("body")

    parser_bytes = []
    for terrain in TERRAINS:
        parser = (terrain / "Common" / "Init" / "Init_Parameters.sqf").read_text(encoding="utf-8")
        parser_bytes.append(parser.encode("utf-8"))
        assert 'getArray (missionConfigFile >> "Params" >> _paramName >> "values")' in parser
        assert re.search(r"if\s*\(\(count _values > 0\).*!\(_value in _values\)", parser, re.DOTALL)
        assert re.search(
            r"_value\s*=\s*getNumber\s*\(missionConfigFile >> \"Params\" >> _paramName >> \"default\"\)",
            parser,
        )

    assert parser_bytes[0] == parser_bytes[1] == parser_bytes[2]


if __name__ == "__main__":
    test_parameter_ingestion_falls_back_when_lobby_value_is_not_in_current_schema()
    print("mission parameter value guard regression check passed")
