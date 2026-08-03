"""Regression checks for the RequestStructure.sqf requester side-binding fix.

RequestStructure.sqf built a side's economy structure (Barracks / CB Radar /
AA Radar / Bank / etc.) at a client-supplied position for a client-supplied
SIDE, and never checked the requester's own side against the claimed side -
unlike its siblings RequestDefense.sqf's neighbours RequestMHQRepair.sqf and
RequestSiteClearance.sqf, which both bind `side group _reqPlayer` to the
claimed `_side`. A forger could build (or duplicate-race-grief) structures
for a side they do not belong to. The fix adds the same requester-side gate,
with a documented exception ONLY for structure index 0 (CommandCenter) to
keep the HQ-mobilize toggle (coin_interface.sqf:545, the one caller that
omits the player arg) working exactly as before. This test locks that
contract so a future edit cannot silently drop the gate or widen the
no-requester exception past the CommandCenter slot.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
STRUCTURE_PATHS = (
    Path('Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/PVFunctions/RequestStructure.sqf'),
    Path('Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/PVFunctions/RequestStructure.sqf'),
    Path('Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/PVFunctions/RequestStructure.sqf'),
)


def test_requester_side_is_verified_before_any_build_gate():
    source_bytes = []
    for relative in STRUCTURE_PATHS:
        path = ROOT / relative
        text = path.read_text(encoding='utf-8-sig')
        source_bytes.append(path.read_bytes())

        # The requester object is captured (optional arg 4, mirrors RequestDefense.sqf).
        capture = text.index(
            "_reqPlayer = if (count _this > 4) then {_this select 4} else {objNull};"
        )

        # HARDEN u2 (60-audit) shape - STRONGER than the original fix: a missing or
        # non-player requester is rejected for EVERY structure index (the old
        # index-0/CommandCenter no-player exception is gone; the HQ caller sends the
        # real player object), and client-claimed _side is never trusted on its own.
        player_check = text.index('if (isNull _reqPlayer || {!isPlayer _reqPlayer}) then {')
        assert capture < player_check
        no_player_block = text[player_check: player_check + 400]
        assert '_reject = true;' in no_player_block
        assert 'StructureRequesterMismatch' in no_player_block

        side_gate = text.index('if !((side group _reqPlayer) in [_side]) then {')
        assert player_check < side_gate
        side_gate_block = text[side_gate: side_gate + 400]
        assert '_reject = true;' in side_gate_block
        assert 'StructureRequesterMismatch' in side_gate_block

        # HQ deploy/pack (index 0) additionally requires the acting commander
        # team's group - any same-side player is no longer enough.
        no_player_gate = text.index('if (!_reject && _index == 0) then {')
        assert side_gate < no_player_gate
        no_player_block = text[no_player_gate: no_player_gate + 500]
        assert '_reject = true;' in no_player_block
        assert 'GetCommanderTeam' in no_player_block

        # The side-binding gate runs BEFORE any of the CBRadar/AARadar/Bank
        # duplicate-race pending-reservation gates, so a forged/mismatched
        # request can never stamp a pending lock against another side.
        cbr_gate = text.index('if (_rlType == "CBRadar") then {')
        assert no_player_gate < cbr_gate

        radar_pending_stamp = text.index('missionNamespace setVariable [_rrPendingKey, time];')
        bank_pending_stamp = text.index('missionNamespace setVariable [_pendingKey, time];')
        assert cbr_gate < radar_pending_stamp
        assert cbr_gate < bank_pending_stamp

        # The reject/refund exitWith still runs after all gates, keyed off the
        # same _reject flag the new gate participates in (B66 flag idiom, not
        # exitWith-inside-then{}).
        reject_exit = text.index('if (_reject) exitWith {')
        assert bank_pending_stamp < reject_exit

        build_line = text.index('ExecVM (Format["Server\\Construction\\Construction_%1.sqf",_script])')
        assert reject_exit < build_line

    assert source_bytes[0] == source_bytes[1] == source_bytes[2]


if __name__ == '__main__':
    test_requester_side_is_verified_before_any_build_gate()
    print('RequestStructure requester side-authority contract: PASS')
