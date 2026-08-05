"""Regression contract for recycled AICOM group pending reservations."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RUN_TEAM = ROOT / (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/"
    "Common/Functions/Common_RunCommanderTeam.sqf"
)


def test_recycled_group_clears_pending_id_before_optional_new_stamp() -> None:
    """A server-local three-argument team must not inherit an old HC request id."""
    source = RUN_TEAM.read_text(encoding="utf-8-sig")
    clear = '_team setVariable ["wfbe_aicom_pending_id", nil, true];'
    stamp = 'if (_pendingId >= 0) then {_team setVariable ["wfbe_aicom_pending_id", _pendingId, true]};'

    assert clear in source
    assert stamp in source
    assert source.index(clear) < source.index(stamp)
