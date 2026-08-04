import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
INIT_CLIENT = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / "Client" / "Init" / "Init_Client.sqf"
BRIEFING = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / "Client" / "Functions" / "Client_JIPCatchupBriefing.sqf"


class JipCatchupRoundLatchTests(unittest.TestCase):
    def test_client_init_clears_the_previous_round_latch_before_spawning_briefing(self):
        init_text = INIT_CLIENT.read_text(encoding="utf-8")
        reset = 'uiNamespace setVariable ["WFBE_JIP_CATCHUP_SHOWN", nil];'
        spawn = '[] spawn Compile preprocessFileLineNumbers "Client\\Functions\\Client_JIPCatchupBriefing.sqf";'

        self.assertIn(reset, init_text)
        self.assertIn(spawn, init_text)
        self.assertLess(init_text.index(reset), init_text.index(spawn))

    def test_briefing_keeps_its_one_shot_latch_within_a_round(self):
        briefing_text = BRIEFING.read_text(encoding="utf-8")
        self.assertIn('uiNamespace setVariable ["WFBE_JIP_CATCHUP_SHOWN", true];', briefing_text)


if __name__ == "__main__":
    unittest.main()
