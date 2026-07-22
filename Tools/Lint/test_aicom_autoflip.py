#!/usr/bin/env python3
"""Static contract for AICOM auto-flip coverage of mobilized AI MHQs.

The existing bounded AICOM loop discovers ordinary hulls through ``wfbe_teams``.
An AI command HQ is stored separately as the side logic's ``wfbe_hq`` while it is
mobilized, so it needs an explicit, server-local candidate path.  These tests are
source-level only; a force-flip on a test server remains the runtime acceptance gate.
"""

from pathlib import Path
import unittest

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"
AUTOFLIP = MISSION / "Common" / "Functions" / "Common_AICOM_AutoFlip.sqf"


def code() -> str:
    return mask_comments(AUTOFLIP.read_text(encoding="utf-8-sig"))


class AicomAutoFlipMfqContractTests(unittest.TestCase):
    def test_mobilized_side_hq_is_a_bounded_candidate(self) -> None:
        text = code()
        self.assertIn('"wfbe_hq_deployed", true', text)
        self.assertIn('"wfbe_hq", objNull', text)
        self.assertIn('[_veh, _now] Call WFBE_CO_FNC_AICOM_AutoFlip_Check', text)

    def test_deployed_static_hq_is_not_passed_to_vehicle_recovery(self) -> None:
        text = code()
        self.assertIn(
            'if (!(_logik getVariable ["wfbe_hq_deployed", true])) then', text
        )

    def test_intervention_logs_player_proximity_without_suppressing_recovery(self) -> None:
        text = code()
        self.assertIn('forEach playableUnits', text)
        self.assertIn('playersNear=', text)
        self.assertLess(text.index('_vehicle setVectorUp [0,0,1]'), text.index('playersNear='))


if __name__ == "__main__":
    unittest.main()
