#!/usr/bin/env python3
"""Regression contract for the server-town AI team-list bootstrap."""

from pathlib import Path


SOURCE = (
    Path(__file__).resolve().parents[2]
    / "Missions"
    / "[55-2hc]warfarev2_073v48co.chernarus"
    / "Server"
    / "FSM"
    / "server_town_ai.sqf"
)


def test_town_team_read_has_an_array_default_and_type_guard():
    source = SOURCE.read_text(encoding="utf-8")

    read = '_town_teams = _town getVariable ["wfbe_town_teams", []];'
    guard = 'if (typeName _town_teams != "ARRAY") then {_town_teams = []};'
    assert read in source
    assert guard in source
    assert source.index(read) < source.index(guard)


def test_town_team_guard_precedes_both_rpt_consumers():
    source = SOURCE.read_text(encoding="utf-8")
    guard_at = source.index('if (typeName _town_teams != "ARRAY") then {_town_teams = []};')

    assert guard_at < source.index('_town_teams = _town_teams + (_retVal select 0);')
    assert guard_at < source.index('count _town_teams]] Call WFBE_CO_FNC_AICOMLog;')


if __name__ == "__main__":
    test_town_team_read_has_an_array_default_and_type_guard()
    test_town_team_guard_precedes_both_rpt_consumers()
