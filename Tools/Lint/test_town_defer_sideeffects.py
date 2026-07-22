#!/usr/bin/env python3
"""Regression contract for town activation budget deferral side effects."""

from hashlib import sha256
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CH = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"
MIRRORS = (
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)
TOWN_AI = Path("Server") / "FSM" / "server_town_ai.sqf"


def test_deferred_activation_skips_all_creation_side_effects() -> None:
    source = (CH / TOWN_AI).read_text(encoding="utf-8")

    guard = 'if (!_activationDeferred) then {'
    assert '_activationDeferred = false;' in source
    assert source.count('_activationDeferred = true;') == 2
    assert guard in source

    guard_start = source.index(guard)
    block_start = source.index("{", guard_start)
    depth = 0
    block_end = None
    for index in range(block_start, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                block_end = index
                break
    assert block_end is not None, "activation guard must close"
    guarded = source[block_start:block_end]
    for side_effect in (
        'Town [%1] ACTIVATED',
        'AICOMV2_GDIR_VEHICLE_ORDER',
        'WFBE_SE_FNC_OperateTownDefensesUnits',
        'WFBE_CO_FNC_SpawnFactionSmoke',
    ):
        assert side_effect in guarded, '%s must remain inside the activation guard' % side_effect


def test_group_creation_does_not_clobber_town_sweep_iterator() -> None:
    source = (CH / TOWN_AI).read_text(encoding="utf-8")
    assert 'for "_i" from 0 to ((count towns) - 1) step 1 do' in source
    assert "for '_i' from 0 to count(_groups)-1 do" not in source
    assert 'for "_groupIndex" from 0 to count(_groups)-1 do' in source
    assert '_bearingP = (360 / _grpTotalP) * _groupIndex' in source


def test_town_ai_mirrors_match_chernarus() -> None:
    digest = sha256((CH / TOWN_AI).read_bytes()).hexdigest()
    for mirror in MIRRORS:
        assert sha256((mirror / TOWN_AI).read_bytes()).hexdigest() == digest


if __name__ == "__main__":
    test_deferred_activation_skips_all_creation_side_effects()
    test_group_creation_does_not_clobber_town_sweep_iterator()
    test_town_ai_mirrors_match_chernarus()
