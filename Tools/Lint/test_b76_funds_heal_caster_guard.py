#!/usr/bin/env python3
"""Regression contract for the B76 caster-seat funds-heal guard."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TERRAINS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)


def test_caster_slots_do_not_start_the_b76_warfare_wallet_retry() -> None:
    """Civilian caster seats have no warfare wallet and must not request one."""
    guard = 'if !(player getVariable ["wfbe_caster_slot", false]) then {'
    for terrain in TERRAINS:
        source = (ROOT / terrain / "Client/Init/Init_Client.sqf").read_text(encoding="utf-8")
        start = source.index("//--- B76 (Ray 2026-06-29) JIP FUNDS SELF-HEAL")
        end = source.index('[] execFSM "Client\\FSM\\updateactions.fsm";', start)
        b76 = source[start:end]
        assert guard in b76, f"{terrain}: B76 must skip civilian caster slots"
        assert b76.index(guard) < b76.index("[] spawn {"), (
            f"{terrain}: caster guard must enclose the B76 retry thread"
        )


if __name__ == "__main__":
    test_caster_slots_do_not_start_the_b76_warfare_wallet_retry()
    print("B76 caster-seat funds-heal guard regression check passed")
