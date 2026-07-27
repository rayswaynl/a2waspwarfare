#!/usr/bin/env python3
"""Regression contract: a rejected/forged attack-wave request must release the overlap reservation.

Follow-up to #1417. The combined patch reserved the side's overlap guard
(ATTACK_WAVE_ACTIVE_WEST/EAST = true, plus *_SET_TIME = time) in Server_AttackWave.sqf's
ATTACK_WAVE_INIT PVEH *unconditionally, before spawning the worker*, and then tried to detect a
requester-bind rejection inside WFBE_SE_FNC_HandleAttackWaveDetails by checking "the flag the
handler would have flipped true on success". That check was dead code: the reservation had already
forced the flag true on every path, and the handler's reject branch (exitWith, WARNING log only)
never cleared it - so a forged/invalid-requester activation latched the side's heavy attack for a
full _attackWaveLength sleep (and a spurious wave-end announce), re-armable indefinitely for free.

Fix: the requester-bind reject branch inside WFBE_SE_FNC_HandleAttackWaveDetails clears the
reservation itself, synchronously (no sleep between check and state change). The worker's existing
release check then observes the cleared flag and exits before its sleep; it stays in place as an
idempotent defense-in-depth re-clear and to skip a spurious wave-end announce. The accept path and
the wave-end/reset path are untouched.
"""

from pathlib import Path

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]

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

GUARD_LINE = (
    'if (isNull _requester || {!isPlayer _requester} || {!alive _requester} || {side _requester != _side}) exitWith {'
)
CLEAR_WEST = 'if (_side == west) then {ATTACK_WAVE_ACTIVE_WEST = false};'
CLEAR_EAST = 'if (_side == east) then {ATTACK_WAVE_ACTIVE_EAST = false};'
REJECT_LOG = 'rejected ATTACK_WAVE_DETAILS activation'


def test_reject_branch_clears_the_reservation_itself():
    """The core fix: inside the requester-bind reject exitWith block, both per-side flags are
    cleared before the WARNING log, with no sleep/uiSleep between the guard check and the clear."""
    for relative in DETAILS_PATHS:
        text = mask_comments((ROOT / relative).read_text(encoding='utf-8-sig'))

        guard = text.index(GUARD_LINE)
        log_line = text.index(REJECT_LOG, guard)
        block_close = text.index('};', log_line)

        clear_west = text.index(CLEAR_WEST, guard)
        clear_east = text.index(CLEAR_EAST, guard)

        # Both clears live inside the reject block, between the guard and its log line.
        assert guard < clear_west < log_line
        assert guard < clear_east < log_line
        assert clear_west < block_close
        assert clear_east < block_close

        # No suspension between the rejection check and the state change (would re-open the race).
        between = text[guard:clear_east]
        assert 'sleep' not in between
        assert 'uiSleep' not in between


def test_reject_clear_does_not_leak_into_accept_or_reset_paths():
    """Only the reject branch may clear the flag early: the accept path still flips the flags true
    below the guard, and the wave-end/reset branch is unchanged (multi-line reset form, no
    requester logic). The one-line clear idiom appears exactly once in the handler file - the new
    reject-branch clear; the reset branch uses its original expanded `if/else` form."""
    for relative in DETAILS_PATHS:
        text = mask_comments((ROOT / relative).read_text(encoding='utf-8-sig'))

        guard = text.index(GUARD_LINE)
        activate_west = text.index('ATTACK_WAVE_ACTIVE_WEST = true;', guard)
        activate_east = text.index('ATTACK_WAVE_ACTIVE_EAST = true;', guard)
        # Accept path still sets the flags AFTER the guard (rejection cannot reach it).
        assert guard < activate_west
        assert guard < activate_east

        # Exactly one early (one-line-idiom) clear per side: the new reject-branch clear.
        # The wave-end reset keeps its original expanded form and is asserted below.
        assert text.count(CLEAR_WEST) == 1
        assert text.count(CLEAR_EAST) == 1

        # The wave-end/reset branch still contains no requester logic.
        deactivate_branch = text.index('} else {\n        ["INFORMATION"', text.index('AttackModeActivated'))
        reset_slice = text[deactivate_branch:]
        assert '_requester' not in reset_slice
        assert 'ATTACK_WAVE_ACTIVE_WEST = false;' in reset_slice


def test_worker_still_short_circuits_before_the_sleep():
    """The worker's release check stays between the activation call and the sleep, so a rejection
    (flag now cleared by the handler) exits the worker immediately - no sleeping out the window,
    no spurious wave-end announce. The normal-completion release after the end call is unchanged."""
    for relative in SERVER_PATHS:
        text = mask_comments((ROOT / relative).read_text(encoding='utf-8-sig'))

        start_call = text.index(
            '[_side, _discountPercentage, _attackWaveLength, _requester] Call WFBE_SE_FNC_HandleAttackWaveDetails;'
        )
        release_guard = text.index(
            'if ((_side == west && {!ATTACK_WAVE_ACTIVE_WEST}) || (_side == east && {!ATTACK_WAVE_ACTIVE_EAST})) exitWith {'
        )
        sleep_stmt = text.index('sleep _attackWaveLength;')
        assert start_call < release_guard < sleep_stmt

        end_call = text.index('[_side, 1, _attackWaveLength, _requester] Call WFBE_SE_FNC_HandleAttackWaveDetails;')
        final_west_release = text.rindex(CLEAR_WEST)
        final_east_release = text.rindex(CLEAR_EAST)
        assert end_call < final_west_release
        assert end_call < final_east_release


def test_all_roots_are_byte_identical():
    for group in (SERVER_PATHS, DETAILS_PATHS):
        blobs = [(ROOT / relative).read_bytes() for relative in group]
        assert blobs[0] == blobs[1] == blobs[2]


if __name__ == '__main__':
    test_reject_branch_clears_the_reservation_itself()
    test_reject_clear_does_not_leak_into_accept_or_reset_paths()
    test_worker_still_short_circuits_before_the_sleep()
    test_all_roots_are_byte_identical()
    print('AttackWave reject-release contract: PASS')
