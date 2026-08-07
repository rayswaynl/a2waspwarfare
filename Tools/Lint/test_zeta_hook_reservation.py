"""Regression contract for player-facing Zeta cargo hook reservations."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
HOOK = ROOT / (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/"
    "Client/Module/ZetaCargo/Zeta_Hook.sqf"
)
UNHOOK = ROOT / (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/"
    "Client/Module/ZetaCargo/Zeta_Unhook.sqf"
)


def test_zeta_hook_reserves_lifter_and_cargo_until_release() -> None:
    hook = HOOK.read_text(encoding="utf-8-sig")
    unhook = UNHOOK.read_text(encoding="utf-8-sig")

    lifter_guard = 'if (_lifter getVariable ["Attached", false]) exitWith {};'
    cargo_guard = 'if (_vehicle getVariable ["wfbe_airlifted", false]) exitWith {};'
    attach = "_vehicle attachTo [_lifter,_position];"

    assert lifter_guard in hook, "a replacement pilot can start a second hook on an occupied lifter"
    assert cargo_guard in hook, "a second lifter can claim cargo already marked in transit"
    assert hook.index(lifter_guard) < hook.index("_vehicles = _lifter nearObjects")
    assert hook.index(cargo_guard) < hook.index(attach)
    assert '_lifter setVariable ["Attached",true,true];' in hook
    assert unhook.count('_lifter setVariable ["Attached",false,true];') >= 2
