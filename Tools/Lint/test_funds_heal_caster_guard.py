#!/usr/bin/env python3
"""Contract for the B76 funds-heal caster-seat guard."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
MISSION_RELATIVE = Path("Client") / "Init" / "Init_Client.sqf"
MISSIONS = [
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / MISSION_RELATIVE,
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan" / MISSION_RELATIVE,
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad" / MISSION_RELATIVE,
]
B76_MARKER = "//--- B76 (Ray 2026-06-29) JIP FUNDS SELF-HEAL."
B76_END_MARKER = '[] execFSM "Client\\FSM\\updateactions.fsm";'
CASTER_GUARD = 'if (player getVariable ["wfbe_caster_slot", false]) exitWith {'


class FundsHealCasterGuardTests(unittest.TestCase):
    def test_every_terrain_aborts_b76_before_delay_or_request(self) -> None:
        for mission in MISSIONS:
            with self.subTest(mission=mission.parent.parent.name):
                text = mission.read_text(encoding="utf-8-sig")
                start = text.index(B76_MARKER)
                end = text.index(B76_END_MARKER, start)
                block = text[start:end]

                guard = block.index(CASTER_GUARD)
                self.assertLess(guard, block.index("sleep 8;"))
                self.assertLess(guard, block.index('"RequestFundsResend"'))
                self.assertIn("CASTER-ABORT", block[guard : guard + 180])


if __name__ == "__main__":
    unittest.main()
