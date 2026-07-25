#!/usr/bin/env python3
"""Regression contract for the combined attack-wave patch superseding #1350/#1373/#1399/#1401.

Server_AttackWave.sqf had four open drafts crammed into one ~60-line function at overlapping
anchor points:

1. #1350 - a per-side overlap guard (ATTACK_WAVE_ACTIVE_WEST/EAST) so a second client activation
   can't spawn a second timer/debit while one is already running. Shipped with a self-latching bug
   (never reset, so the side is permanently suppressed after its first wave).
2. #1373 - fixes #1350's latch: an explicit reset on the worker's normal-completion exit path, plus
   a time-based staleness ceiling (WFBE_C_ATTACK_WAVE_STALE_MINUTES) so a worker that dies before
   reaching its own reset (exception, JIP/save-load edge, mission end) cannot latch the side forever.
3. #1399 - binds the supply-debiting activation branch to a live, same-side requester (threaded from
   Common_AttackWaveActivate.sqf's addAction through ATTACK_WAVE_INIT and the wave-start/wave-end
   calls), so a forged _side can no longer wipe an uninvolved side's whole supply. The reset branch
   stays ungated so it always fires even if the original requester disconnects mid-wave.
4. #1401 - re-derives the discount/duration input from server-authoritative supply
   (`_side call GetSideSupply`) instead of trusting the client-supplied _supply figure in
   ATTACK_WAVE_INIT, so a forged supply value can no longer skew the wave's discount or duration.

This test locks all four intents plus one combination-specific fix that is NOT part of any single
source PR: stacking #1350/#1373's guard reservation (set unconditionally from the client-asserted
_side, before the worker even starts) on top of #1399's requester-bind rejection (inside the worker,
after the fact) meant a forged/invalid-requester activation would still lock the targeted side out of
future waves for a full wave-length window (up to ~25 minutes) even though nothing was ever debited or
announced - a denial-of-service purely from the combination. The combined patch detects that rejection
(the guard's flag never flips true) and releases the reservation immediately instead of sleeping out
the window.

See PR body for the full four-intent end-to-end trace (honest activation / forged activation /
completed wave / crashed worker).
"""

from pathlib import Path

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]

CONSTANTS_PATHS = (
    Path('Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf'),
    Path('Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Init/Init_CommonConstants.sqf'),
    Path('Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Common/Init/Init_CommonConstants.sqf'),
)
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


def test_stale_minutes_constant_is_declared():
    for relative in CONSTANTS_PATHS:
        text = (ROOT / relative).read_text(encoding='utf-8-sig')
        assert 'if (isNil "WFBE_C_ATTACK_WAVE_STALE_MINUTES") then {WFBE_C_ATTACK_WAVE_STALE_MINUTES = 30};' in text
        assert 'ATTACK_WAVE_ACTIVE_WEST_SET_TIME = -1;' in text
        assert 'ATTACK_WAVE_ACTIVE_EAST_SET_TIME = -1;' in text


def test_client_action_sends_the_live_local_player():
    for relative in ACTIVATE_PATHS:
        text = (ROOT / relative).read_text(encoding='utf-8-sig')
        assert '_requester = player;' in text
        assert 'ATTACK_WAVE_INIT = [_supply, _side, _requester];' in text


def test_overlap_guard_checks_both_active_flag_and_staleness():
    for relative in SERVER_PATHS:
        text = mask_comments((ROOT / relative).read_text(encoding='utf-8-sig'))
        assert (
            'if (_side == west && {ATTACK_WAVE_ACTIVE_WEST} && '
            '{(time - ATTACK_WAVE_ACTIVE_WEST_SET_TIME) < (WFBE_C_ATTACK_WAVE_STALE_MINUTES * 60)}) exitWith {};'
        ) in text
        assert (
            'if (_side == east && {ATTACK_WAVE_ACTIVE_EAST} && '
            '{(time - ATTACK_WAVE_ACTIVE_EAST_SET_TIME) < (WFBE_C_ATTACK_WAVE_STALE_MINUTES * 60)}) exitWith {};'
        ) in text
        assert 'if (_side == west) then {ATTACK_WAVE_ACTIVE_WEST_SET_TIME = time};' in text
        assert 'if (_side == east) then {ATTACK_WAVE_ACTIVE_EAST_SET_TIME = time};' in text


def test_worker_threads_requester_and_rederives_supply_before_discount():
    for relative in SERVER_PATHS:
        text = mask_comments((ROOT / relative).read_text(encoding='utf-8-sig'))

        extract = text.index(
            '_requester = if (count (_this select 1) > 2) then {(_this select 1) select 2} else {objNull};'
        )
        spawn = text.index('[_supply, _side, _requester] spawn {')
        assert extract < spawn

        inside_spawn = text.index('_requester = _this select 2;')
        assert spawn < inside_spawn

        server_derive = text.index('_supply = _side call GetSideSupply;')
        discount_formula = text.index(
            '_discountPercentage = 0.4 + ((WFBE_C_ECONOMY_SUPPLY_MAX_TEAM_LIMIT - _supply) * (1/50000));'
        )
        assert inside_spawn < server_derive < discount_formula

        start_call = text.index(
            '[_side, _discountPercentage, _attackWaveLength, _requester] Call WFBE_SE_FNC_HandleAttackWaveDetails;'
        )
        end_call = text.index('[_side, 1, _attackWaveLength, _requester] Call WFBE_SE_FNC_HandleAttackWaveDetails;')
        assert discount_formula < start_call < end_call

        # No stale 3-element call shape should survive the combination.
        assert '[_side, _discountPercentage, _attackWaveLength] Call' not in text
        assert '[_side, 1, _attackWaveLength] Call' not in text


def test_rejected_activation_releases_the_reservation_instead_of_latching():
    """Combination-specific fix: without this, a requester-bind rejection inside the worker would
    leave the outer overlap-guard reservation (set unconditionally before the worker even validates
    anything) latched true for a full wave-length sleep - a DoS purely from stacking #1350/#1373's
    guard on top of #1399's reject path. The worker must detect the rejection (flag never flipped
    true) and release its own reservation before sleeping.
    """
    for relative in SERVER_PATHS:
        text = mask_comments((ROOT / relative).read_text(encoding='utf-8-sig'))

        start_call = text.index(
            '[_side, _discountPercentage, _attackWaveLength, _requester] Call WFBE_SE_FNC_HandleAttackWaveDetails;'
        )
        release_guard = text.index(
            'if ((_side == west && {!ATTACK_WAVE_ACTIVE_WEST}) || (_side == east && {!ATTACK_WAVE_ACTIVE_EAST})) exitWith {'
        )
        sleep_stmt = text.index('sleep _attackWaveLength;')

        # The release-on-rejection check must sit strictly between the activation call and the sleep.
        assert start_call < release_guard < sleep_stmt


def test_normal_completion_explicitly_releases_the_latch():
    for relative in SERVER_PATHS:
        text = mask_comments((ROOT / relative).read_text(encoding='utf-8-sig'))
        end_call = text.index('[_side, 1, _attackWaveLength, _requester] Call WFBE_SE_FNC_HandleAttackWaveDetails;')
        final_west_release = text.rindex('if (_side == west) then {ATTACK_WAVE_ACTIVE_WEST = false};')
        final_east_release = text.rindex('if (_side == east) then {ATTACK_WAVE_ACTIVE_EAST = false};')
        assert end_call < final_west_release
        assert end_call < final_east_release


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


def test_all_roots_are_byte_identical():
    for group in (CONSTANTS_PATHS, ACTIVATE_PATHS, SERVER_PATHS, DETAILS_PATHS):
        blobs = [(ROOT / relative).read_bytes() for relative in group]
        assert blobs[0] == blobs[1] == blobs[2]


if __name__ == '__main__':
    test_stale_minutes_constant_is_declared()
    test_client_action_sends_the_live_local_player()
    test_overlap_guard_checks_both_active_flag_and_staleness()
    test_worker_threads_requester_and_rederives_supply_before_discount()
    test_rejected_activation_releases_the_reservation_instead_of_latching()
    test_normal_completion_explicitly_releases_the_latch()
    test_requester_bind_guards_only_the_activation_branch()
    test_all_roots_are_byte_identical()
    print('Combined AttackWave guard/latch/requester/supply contract: PASS')
