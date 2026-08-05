"""Behavioral regression for RadiusHold progress ownership.

The repository has no Arma 2/OA executable or SQF interpreter, so this narrow
harness executes the state transition in Python while binding the fixed branch
to the real SQF source.  It fails on the deployed wave0804b behavior where a
new sole side inherits the opponent's accumulated hold seconds.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCE = (
    ROOT
    / "Missions/[55-2hc]warfarev2_073v48co.chernarus"
    / "Common/Functions/Common_RadiusHold.sqf"
)


def execute_sole_eligible_tick(
    source: str, *, progress: int, progress_side: int, sole_side: int, tick: int = 5
) -> tuple[int, int]:
    """Return the observable progress state after one sole-side tick."""

    has_side_handoff_guard = (
        'setVariable ["wfbe_rh_progress_side", -1, true]' in source
        and '_progressSideNum = _anchor getVariable ["wfbe_rh_progress_side",-1];'
        in source
        and "if (_progressSideNum != _holderSideNum) then {" in source
        and "_progressSideNum = _holderSideNum;" in source
        and 'setVariable ["wfbe_rh_progress_side", _progressSideNum, true]'
        in source
    )
    if has_side_handoff_guard and progress_side != sole_side:
        progress = 0
        progress_side = sole_side
    return progress + tick, progress_side


def test_opposing_side_starts_its_own_hold_instead_of_inheriting_progress():
    source = SOURCE.read_text(encoding="utf-8-sig")

    progress, progress_side = execute_sole_eligible_tick(
        source,
        progress=280,
        progress_side=1,  # EAST built the existing hold.
        sole_side=0,  # WEST becomes the sole eligible presence.
    )

    assert (progress, progress_side) == (5, 0)
