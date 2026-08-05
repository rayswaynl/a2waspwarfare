"""Regression contract for the AICOM per-tick unit-cap reservation."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PRODUCE = ROOT / (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/"
    "Server/AI/Commander/AI_Commander_Produce.sqf"
)


def test_refill_orders_cannot_exceed_remaining_side_cap_in_one_tick() -> None:
    """Async AIBuyUnit orders must consume the same tick's remaining side budget."""
    text = PRODUCE.read_text(encoding="utf-8-sig")

    assert '_capRemaining = (_cap - _sideAI) max 0;' in text
    assert 'while {_cur < _want && _batchOrdered < _effBatch && _capRemaining > 0} do {' in text
    assert '_capRemaining = _capRemaining - _capCost;' in text
    assert text.index('_capRemaining = (_cap - _sideAI) max 0;') < text.index('while {_cur < _want')
    assert text.index('_capRemaining = _capRemaining - _capCost;') > text.index('Spawn AIBuyUnit;')


def test_vehicle_refills_reserve_all_potential_crew_before_queueing() -> None:
    """A vehicle order can create driver, gunner, commander, and turret crew."""
    text = PRODUCE.read_text(encoding="utf-8-sig")

    assert '_capCost = 1;' in text
    # PR #1854 (staging wave 2026-08-02): crew-cap cost is now derived from the vehicle's actual
    # crew seats (QUERYUNITCREW gunner/commander flags) instead of the flat 3 + turret count.
    assert 'if (_hasGunner) then {_capCost = _capCost + 1};' in text
    assert 'if (_hasCommander) then {_capCost = _capCost + 1};' in text
    assert 'if (_capRemaining < _capCost) exitWith {};' in text
    assert '_capRemaining = _capRemaining - _capCost;' in text
    assert text.index('if (_capRemaining < _capCost) exitWith {};') < text.index('Spawn AIBuyUnit;')
    assert text.index('_capRemaining = _capRemaining - _capCost;') > text.index('Spawn AIBuyUnit;')


def test_hc_topup_requests_reserve_the_same_remaining_side_cap() -> None:
    """A multi-unit HC top-up must not bypass the producer's global budget."""
    text = PRODUCE.read_text(encoding="utf-8-sig")

    assert '_wm_missing = ((6 - _wm_alive) min 4) min _capRemaining;' in text
    assert '_capRemaining = _capRemaining - _wm_missing;' in text
    # Econ-triad fold (staging wave 2026-08-02) added a dedup READ of wfbe_aicom_topup_req before
    # the computation; the reservation invariant is compute-before-WRITE, so anchor on setVariable.
    assert text.index('_wm_missing = ((6 - _wm_alive) min 4) min _capRemaining;') < text.index('_team setVariable ["wfbe_aicom_topup_req"')
    assert text.index('_capRemaining = _capRemaining - _wm_missing;') > text.index('_team setVariable ["wfbe_aicom_topup_req"')
