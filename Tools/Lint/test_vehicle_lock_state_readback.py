"""Regression contract for Arma 2/OA numeric vehicle lock readback.

``locked`` returns a scalar state in Arma 2/OA: 0 is fully open, while 1, 2,
and 3 all impose an access restriction.  The mission must compare that state
explicitly instead of feeding the scalar into Boolean operators.  UAV control
is the deliberate exception: it captures and restores the exact numeric state.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)


def read(mission: Path, relative: str) -> str:
    return (mission / relative).read_text(encoding="utf-8-sig")


def test_lock_action_menus_compare_numeric_state_explicitly() -> None:
    for mission in MISSIONS:
        for relative in (
            "Client/PVFunctions/SetMHQLock.sqf",
            "Client/Module/CoIn/coin_interface.sqf",
            "Client/Functions/Client_BuildUnit.sqf",
            "Client/FSM/updateclient.sqf",
        ):
            source = read(mission, relative)
            assert "(locked _target) > 0" in source
            assert "(locked _target) == 0" in source
            assert "&& locked _target" not in source
            assert "&& !(locked _target)" not in source


def test_guer_lockpick_treats_every_restricted_state_as_locked() -> None:
    for mission in MISSIONS:
        action = read(mission, "Client/Action/Action_GuerLockpick.sqf")
        init = read(mission, "Common/Init/Init_Unit.sqf")

        assert action.count("{(locked _veh) == 0}") == 2
        assert action.count("{(locked _veh) > 0}") == 1
        assert "{(locked _target) > 0}" in init


def test_specops_lockpick_compares_numeric_state_before_boolean_flow() -> None:
    for mission in MISSIONS:
        source = read(mission, "Client/Module/Skill/Skill_SpecOps.sqf")
        assert source.count("if ((locked _vehicle) == 0) exitWith {};") == 2
        assert "if (!locked _vehicle)" not in source


def test_respawn_automount_requires_a_fully_open_vehicle() -> None:
    for mission in MISSIONS:
        source = read(mission, "Client/Functions/Client_OnRespawnHandler.sqf")
        assert source.count("&& {(locked _spawn) == 0}") == 2
        assert "&& !(locked _spawn)" not in source


def test_town_static_hint_compares_numeric_state_explicitly() -> None:
    for mission in MISSIONS:
        source = read(mission, "Client/Init/Init_TownStaticReserved.sqf")
        assert "'(locked _target) > 0'" in source
        assert "'', 'locked _target'" not in source


def test_uav_control_preserves_the_exact_numeric_lock_state() -> None:
    for mission in MISSIONS:
        for relative in (
            "Client/Module/UAV/uav_interface.sqf",
            "Client/Module/UAV/uav_interface_oa.sqf",
        ):
            source = read(mission, relative)
            assert "_locked = locked _uav;" in source
            assert "_uav lock _locked" in source
