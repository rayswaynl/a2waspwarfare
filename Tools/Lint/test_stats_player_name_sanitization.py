#!/usr/bin/env python3
"""Regression contract for player names in the pipe-delimited WASPSTAT stream."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CH = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"
MIRRORS = (
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)
RELATIVE = Path("Server/Stats/StatsFlush.sqf")


def test_player_name_is_delimiter_safe_before_waspstat_append() -> None:
    source = (CH / RELATIVE).read_text(encoding="utf-8")

    assert 'private ["_uid","_buf","_sideNum","_csv","_playerName","_safeName","_char"];' in source
    assert '_playerName = missionNamespace getVariable ["WFBE_STAT_NAME_" + _uid, ""];' in source
    assert 'forEach (toArray _playerName);' in source
    assert '_char = if (_x in [10,13,34,124,126]) then {"_"} else {toString [_x]};' in source
    assert 'if ((count _safeName) < 48) then {' in source
    assert '_safeName = _safeName + _char;' in source
    assert '_line = _line + "|" + _uid + ":" + _csv + "~" + _safeName;' in source
    assert '_line = _line + "|" + _uid + ":" + _csv + "~" + (missionNamespace getVariable ["WFBE_STAT_NAME_" + _uid, ""]);' not in source

    source_bytes = (CH / RELATIVE).read_bytes()
    for mirror in MIRRORS:
        assert (mirror / RELATIVE).read_bytes() == source_bytes, f"StatsFlush mirror drift: {mirror.name}"


if __name__ == "__main__":
    test_player_name_is_delimiter_safe_before_waspstat_append()
    print("test_stats_player_name_sanitization: PASS")
