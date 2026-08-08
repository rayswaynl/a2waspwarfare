"""Regression contract for the optional GUER start-area enforcer.

The enforcer owns one player at a time.  A player who crosses the boundary
while seated must leave their current vehicle before the body is repositioned;
the vehicle and any other occupants must not be moved by a player-body setPos.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
LOCKOUT = ROOT / (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/"
    "Client/Functions/Client_GuerLockout.sqf"
)


def test_lockout_detaches_only_the_moved_player_before_repositioning() -> None:
    source = LOCKOUT.read_text(encoding="utf-8-sig")
    boundary = 'if ((player distance [_hold select 0, _hold select 1, _hold select 2]) > 150) then {'
    detach = 'if (vehicle player != player) then {moveOut player};'
    reposition = 'player setPosASL _hold;'

    assert boundary in source
    assert detach in source
    assert reposition in source
    guarded = source[source.index(boundary) : source.index('if ((time - _lastHint)', source.index(boundary))]
    assert guarded.index(detach) < guarded.index(reposition)
