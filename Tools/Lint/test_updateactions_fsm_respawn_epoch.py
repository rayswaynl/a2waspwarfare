from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
CH = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"


class UpdateActionsFsmRespawnEpochTests(unittest.TestCase):
    def test_each_fsm_launch_advances_the_lifecycle_epoch(self):
        sources = [
            CH / "Client" / "Init" / "Init_Client.sqf",
            CH / "Client" / "Functions" / "Client_PreRespawnHandler.sqf",
        ]
        marker = 'missionNamespace setVariable ["WFBE_CL_UpdateActionsEpoch",'
        for source in sources:
            self.assertIn(marker, source.read_text(encoding="utf-8"), source)

    def test_superseded_fsm_transitions_to_end(self):
        fsm = (CH / "Client" / "FSM" / "updateactions.fsm").read_text(encoding="utf-8")
        self.assertIn(
            '_wfbeUpdateActionsEpoch = missionNamespace getVariable [""WFBE_CL_UpdateActionsEpoch"", 0];',
            fsm,
        )
        self.assertIn('class Superseded', fsm)
        self.assertIn(
            '_wfbeUpdateActionsEpoch != (missionNamespace getVariable [""WFBE_CL_UpdateActionsEpoch"", 0])',
            fsm,
        )
        self.assertIn('class Superseded\n        {\n          priority = 2.000000;\n          to="End";', fsm)


if __name__ == "__main__":
    unittest.main()
