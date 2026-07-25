#!/usr/bin/env python3
"""Regression contract for the ATTACK_WAVE_DETAILS requester-bind hardening.

WFBE_SE_FNC_HandleAttackWaveDetails (Server/PVFunctions/AttackWave.sqf) activates a side's heavy
attack mode and debits that side's ENTIRE current supply as the activation cost. The handler
validated the payload's shape/types but never checked that the asserted `_side` belonged to
whoever asked - a player on side A could forge `_side = east` (via a spoofed ATTACK_WAVE_INIT
payload, or the raw ATTACK_WAVE_DETAILS public-variable name that no in-tree caller actually
publishes) and wipe the opposing side's whole supply balance for free.

The fix threads the acting `player` object (the sole honest source: the addAction in
Common_AttackWaveActivate.sqf) through ATTACK_WAVE_INIT -> Server_AttackWave.sqf ->
WFBE_SE_FNC_HandleAttackWaveDetails as an optional 4th payload element, and rejects the
ACTIVATION branch (the only branch that performs an economy mutation) unless the requester is a
live player whose own side matches the asserted `_side`. The wave-END/reset branch performs no
mutation and is deliberately left ungated so it keeps landing even if the original requester
later disconnects/dies/changes side mid-wave (composes with PR #1373's latch-release/staleness
rework in Server_AttackWave.sqf, which depends on that reset call always executing).

This test locks that contract so a future edit cannot silently drop the requester bind, move the
guard onto the reset branch (reintroducing the permanent-latch risk), or reorder the guard after
the mutation it is meant to gate.
"""

from pathlib import Path

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]

ACTIVATE_PATHS = (
    Path('Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_AttackWaveActivate.sqf'),
    Path('Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Functions/Common_AttackWaveActivate.sqf'),
    Path('Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Common/Functions/Common_AttackWaveActivate.sqf'),
)
SERVER_PATHS = (
    Path('Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/Server_AttackWave.sqf'),
    Path('Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/Functions/Server_AttackWave.sqf'),
    Path('Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/Functions/Server_AttackWave.sqf'),
)
DETAILS_PATHS = (
    Path('Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/PVFunctions/AttackWave.sqf'),
    Path('Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/PVFunctions/AttackWave.sqf'),
    Path('Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/PVFunctions/AttackWave.sqf'),
)


def test_client_action_sends_the_live_local_player():
    for relative in ACTIVATE_PATHS:
        text = (ROOT / relative).read_text(encoding='utf-8-sig')
        assert '_requester = player;' in text
        assert 'ATTACK_WAVE_INIT = [_supply, _side, _requester];' in text


def test_server_init_threads_requester_to_both_call_sites():
    for relative in SERVER_PATHS:
        text = mask_comments((ROOT / relative).read_text(encoding='utf-8-sig'))
        extract = text.index('_requester = if (count (_this select 1) > 2) then {(_this select 1) select 2} else {objNull};')
        spawn = text.index('[_supply, _side, _requester] spawn {')
        assert extract < spawn

        inside_spawn = text.index('_requester = _this select 2;')
        assert spawn < inside_spawn

        start_call = text.index('[_side, _discountPercentage, _attackWaveLength, _requester] Call WFBE_SE_FNC_HandleAttackWaveDetails;')
        end_call = text.index('[_side, 1, _attackWaveLength, _requester] Call WFBE_SE_FNC_HandleAttackWaveDetails;')
        assert inside_spawn < start_call < end_call

        # The 3-element legacy call shape must be gone from this file - both sites now send 4.
        assert '[_side, _discountPercentage, _attackWaveLength] Call' not in text
        assert '[_side, 1, _attackWaveLength] Call' not in text


def test_requester_bind_guards_only_the_activation_branch():
    for relative in DETAILS_PATHS:
        text = mask_comments((ROOT / relative).read_text(encoding='utf-8-sig'))

        extract = text.index('_requester = if (count _this > 3) then {_this select 3} else {objNull};')
        activation_branch = text.index('if (_attackLength > 0) then {')
        assert extract < activation_branch

        guard = text.index(
            'if (isNull _requester || {!isPlayer _requester} || {!alive _requester} || {side _requester != _side}) exitWith {'
        )
        activate_west = text.index('ATTACK_WAVE_ACTIVE_WEST = true;')
        debit = text.index('Call WFBE_SE_FNC_HandleSideSupplyChange;')
        deactivate_branch = text.index('} else {\n        [\"INFORMATION\"', text.index('AttackModeActivated'))

        # Guard sits inside the activation branch, before both the flag flip and the debit.
        assert activation_branch < guard < activate_west < debit

        # The reset/deactivation branch is untouched: no requester guard text appears in it.
        reset_slice = text[deactivate_branch:]
        assert '_requester' not in reset_slice
        assert 'ATTACK_WAVE_ACTIVE_WEST = false;' in reset_slice


def test_all_three_roots_are_byte_identical():
    for group in (ACTIVATE_PATHS, SERVER_PATHS, DETAILS_PATHS):
        blobs = [(ROOT / relative).read_bytes() for relative in group]
        assert blobs[0] == blobs[1] == blobs[2]


if __name__ == '__main__':
    test_client_action_sends_the_live_local_player()
    test_server_init_threads_requester_to_both_call_sites()
    test_requester_bind_guards_only_the_activation_branch()
    test_all_three_roots_are_byte_identical()
    print('AttackWave requester-bind contract: PASS')
