"""Regression contract for duplicate player-commander upgrade requests.

Public-variable requests are handled by independently spawned scheduled scripts.  Two
identical RequestUpgrade handlers must therefore acquire the shared upgrading latch in
one unscheduled check-and-set before either handler charges supply/funds or starts the
timer worker.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
REQUEST_PATHS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/PVFunctions/RequestUpgrade.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/PVFunctions/RequestUpgrade.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/PVFunctions/RequestUpgrade.sqf"),
)


def test_upgrade_latch_is_acquired_atomically_before_payment_and_spawn():
    source_bytes = []

    for relative in REQUEST_PATHS:
        path = ROOT / relative
        text = path.read_text(encoding="utf-8-sig")
        source_bytes.append(path.read_bytes())

        supply_gate = text.index('if (_dual && {_supply < (_cost select 0)}) exitWith {')
        acquire_seed = text.index("_upgradeAcquired = false;")
        atomic_open = text.index("isNil {", acquire_seed)
        latch_check = text.index(
            'if !(_logic getVariable ["wfbe_upgrading", false]) then {', atomic_open
        )
        latch_set = text.index(
            '_logic setVariable ["wfbe_upgrading", true, true];', latch_check
        )
        id_set = text.index(
            '_logic setVariable ["wfbe_upgrading_id", _upgrade_id, true];', latch_set
        )
        acquired = text.index("_upgradeAcquired = true;", id_set)
        duplicate_exit = text.index("if (!_upgradeAcquired) exitWith {", acquired)
        supply_debit = text.index("Call ChangeSideSupply;", duplicate_exit)
        funds_debit = text.index("Call WFBE_CO_FNC_ChangeTeamFunds;", duplicate_exit)
        worker_spawn = text.index("_args Spawn WFBE_SE_FNC_ProcessUpgrade;", duplicate_exit)

        assert supply_gate < acquire_seed < atomic_open
        assert atomic_open < latch_check < latch_set < id_set < acquired < duplicate_exit
        assert duplicate_exit < supply_debit < funds_debit < worker_spawn
        assert text.count('_logic setVariable ["wfbe_upgrading", true, true];') == 1

    assert source_bytes[0] == source_bytes[1] == source_bytes[2]
