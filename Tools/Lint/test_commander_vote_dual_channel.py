#!/usr/bin/env python3
"""Regression contract for the commander-vote dual-channel timeout path.

The start notification and the wfbe_votetime state travel through separate
replication paths.  If the state is still absent when the bounded readiness
wait expires, the client must not compare a missing value with a number.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / "Client" / "Functions" / "Client_FNC_Special.sqf"


def test_vote_start_timeout_guards_missing_votetime_before_numeric_compare() -> None:
    source = SOURCE.read_text(encoding="utf-8-sig")

    wait = 'waitUntil {sleep 0.2; !isNil {WFBE_Client_Logic getVariable "wfbe_votetime"} || {(time - _voteWaitT0) > 30}};'
    cache = '_voteTime = WFBE_Client_Logic getVariable "wfbe_votetime";'
    guard = 'if ((typeName _voteTime) == "SCALAR" && {_voteTime > 0} && {!voted}) then {'

    assert wait in source
    wait_index = source.index(wait)
    cache_index = source.index(cache)
    guard_index = source.index(guard)
    assert wait_index < cache_index < guard_index
