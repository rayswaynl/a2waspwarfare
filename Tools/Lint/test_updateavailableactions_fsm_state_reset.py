from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
CH = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"
FSM_PATHS = [
    CH / "Client" / "FSM" / "updateavailableactions.fsm",
    ROOT
    / "Missions_Vanilla"
    / "[61-2hc]warfarev2_073v48co.takistan"
    / "Client"
    / "FSM"
    / "updateavailableactions.fsm",
    ROOT
    / "Missions_Vanilla"
    / "[61-2hc]warfarev2_073v48co.zargabad"
    / "Client"
    / "FSM"
    / "updateavailableactions.fsm",
]


class UpdateAvailableActionsFsmStateResetTests(unittest.TestCase):
    def test_fast_travel_availability_resets_before_command_range_gate(self):
        reset = '"\t_fastTravel = false;" \\n'
        guard = '"if ((_ft > 0) && commandInRange) then {" \\n'

        for path in FSM_PATHS:
            fsm = path.read_text(encoding="utf-8")
            state = fsm.split("class Update_Client_Ac", 1)[1].split("class End", 1)[0]

            self.assertIn(reset, state, path)
            self.assertIn(guard, state, path)
            self.assertLess(
                state.index(reset),
                state.index(guard),
                f"fast-travel state must be cleared before the eligibility gate runs: {path}",
            )


if __name__ == "__main__":
    unittest.main()
