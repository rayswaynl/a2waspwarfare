"""Regression checks for the merged RequestStructure.sqf authority contract.

RequestStructure.sqf builds a side's economy structure (Barracks / CB Radar /
AA Radar / Bank / etc.) at a client-supplied position for a client-supplied
SIDE. The merged server path now requires a verified player requester for
every structure, binds `side group _reqPlayer` to the claimed `_side`, and
adds a separate commander-team check for the CommandCenter/HQ slot (index 0).
This test locks the current contract so a future edit cannot silently drop the
requester gate, move it behind a build reservation, or remove the HQ authority
check.
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

        # Every structure request, including CommandCenter/HQ, requires a real
        # player object before any side or build gate can run.
        requester_gate = text.index(
            'if (isNull _reqPlayer || {!isPlayer _reqPlayer}) then {'
        )
        assert capture < requester_gate
        requester_block = text[requester_gate: requester_gate + 450]
        assert '_reject = true;' in requester_block
        assert 'StructureRequesterMismatch' in requester_block

        # A verified same-side player is required - client-claimed _side is never
        # trusted on its own (mirrors RequestMHQRepair.sqf / RequestSiteClearance.sqf).
        side_gate = text.index('if !((side group _reqPlayer) in [_side]) then {')
        assert requester_gate < side_gate
        side_gate_block = text[side_gate: side_gate + 400]
        assert '_reject = true;' in side_gate_block
        assert 'StructureRequesterMismatch' in side_gate_block

        # CommandCenter/HQ requests add a server-side commander-team check;
        # the client menu's commander gate is not the authority boundary.
        hq_gate = text.index('if (!_reject && _index == 0) then {')
        assert side_gate < hq_gate
        hq_block = text[hq_gate: hq_gate + 500]
        assert '_cmdTeam = (_side) Call WFBE_CO_FNC_GetCommanderTeam;' in hq_block
        assert 'isNull _cmdTeam || {group _reqPlayer != _cmdTeam}' in hq_block
        assert 'StructureRequesterMismatch' in hq_block

        # The side-binding gate runs BEFORE any of the CBRadar/AARadar/Bank
        # duplicate-race pending-reservation gates, so a forged/mismatched
        # request can never stamp a pending lock against another side.
        cbr_gate = text.index('if (_rlType == "CBRadar") then {')
        assert hq_gate < cbr_gate

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
