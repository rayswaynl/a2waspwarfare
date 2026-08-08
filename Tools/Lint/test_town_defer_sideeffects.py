#!/usr/bin/env python3
"""Regression contract for town activation budget deferral side effects."""

import re
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
    # 2 legacy budget-defer sites + 2 sites added by fold #2097 (GARRISON_CAP_DEFER,
    # TOWN_AI_GROUP_CAP_DEFER) - all four gate the same guarded block below.
    assert source.count('_activationDeferred = true;') == 4
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

    # Outer per-town sweep iterator - must still be "_i".
    assert 'for "_i" from 0 to ((count towns) - 1) step 1 do' in source
    # Historical regression shape: an earlier bug reused the outer sweep's own
    # iterator name for the inner per-group loop below, which permanently
    # clobbers "_i" for every later town in the same sweep once that inner loop
    # runs (SQF `for "_var" from .. do {}` loop variables are plain
    # missionNamespace-scoped strings, not block-scoped/restored on loop exit).
    assert "for '_i' from 0 to count(_groups)-1 do" not in source

    # Locate the inner per-group perimeter-bearing loop (creates each town-AI
    # group for this town) by its bearing-math use rather than by the exact name
    # of the array it counts over. That source array is an implementation detail
    # - it was renamed _groups -> _plannedGroups by the r50 fail-clean fix
    # (PR #2109) so _groups could become a build-only-on-success accumulator for
    # the parallel _groups/_positions/_teams tuples, which does not affect
    # loop-variable safety.
    bearing_match = re.search(r'_bearingP\s*=\s*\(360 / _grpTotalP\) \* (_\w+)', source)
    assert bearing_match is not None, "perimeter bearing calculation not found"
    bearing_var = bearing_match.group(1)

    preceding = source[: bearing_match.start()]
    loop_vars = re.findall(r'for ["\'](_\w+)["\'] from 0 to count\(_\w+\)-1 do', preceding)
    assert loop_vars, "group-creation for-loop not found before the bearing calculation"
    loop_var = loop_vars[-1]

    assert loop_var == bearing_var, (
        "the nearest enclosing group-creation loop must use the same variable as "
        "the bearing math (found loop var %r, bearing var %r)" % (loop_var, bearing_var)
    )
    assert loop_var != "_i", (
        "group-creation loop must not reuse the outer per-town sweep iterator _i - "
        "this would clobber the sweep's `towns select _i` for every later town"
    )


def test_cap_deferral_diagnostics_are_debounced_and_group_count_reused() -> None:
    source = (CH / TOWN_AI).read_text(encoding="utf-8")

    # Cap refusal is evaluated inside the per-town activation sweep. Keep the
    # diagnostic signal, but bound repeated emissions while a cap remains full.
    assert "_garrisonCapDeferLast" in source
    assert "_groupCapDeferLast" in source
    assert "_garrisonCapDeferLast = -9999;" in source
    assert "_groupCapDeferLast = -9999;" in source

    cap_start = source.index(
        "if (!_activationDeferred && {_enemies_ground > 0} && {(_side == west || {_side == east})}) then {"
    )
    activation_start = source.index("if(_enemies_ground > 0) then {", cap_start)
    cap_region = source[cap_start:activation_start]

    assert re.search(
        r'if \(\(_now - _garrisonCapDeferLast\) >= 300\) then \{\s*'
        r'_garrisonCapDeferLast = _now;\s*'
        r'diag_log Format \["GARRISON_CAP_DEFER\|',
        cap_region,
        re.DOTALL,
    )
    assert re.search(
        r'if \(\(_now - _groupCapDeferLast\) >= 300\) then \{\s*'
        r'_groupCapDeferLast = _now;\s*'
        r'diag_log Format \["TOWN_AI_GROUP_CAP_DEFER\|',
        cap_region,
        re.DOTALL,
    )

    # The group count is needed for the gate and the diagnostic. Do not scan
    # allGroups a second time just to format the line.
    assert cap_region.count("{side _x == _side} count allGroups") == 1


def test_town_ai_mirrors_match_chernarus() -> None:
    digest = sha256((CH / TOWN_AI).read_bytes()).hexdigest()
    for mirror in MIRRORS:
        assert sha256((mirror / TOWN_AI).read_bytes()).hexdigest() == digest


if __name__ == "__main__":
    test_deferred_activation_skips_all_creation_side_effects()
    test_group_creation_does_not_clobber_town_sweep_iterator()
    test_cap_deferral_diagnostics_are_debounced_and_group_count_reused()
    test_town_ai_mirrors_match_chernarus()
