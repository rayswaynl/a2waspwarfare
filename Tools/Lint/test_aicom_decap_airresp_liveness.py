#!/usr/bin/env python3
"""Static contracts for the DECAP/AIRRESP closer liveness repair."""

from pathlib import Path
import unittest

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"


def code(relative: str) -> str:
    return mask_comments((MISSION / relative).read_text(encoding="utf-8-sig"))


class DecapAirRespLivenessTests(unittest.TestCase):
    def setUp(self) -> None:
        self.airresp = code("Server/AI/Commander/AI_Commander_AirResp.sqf")
        self.decap = code("Server/AI/Commander/AI_Commander_Decapitate.sqf")
        self.constants = code("Common/Init/Init_CommonConstants.sqf")

    def test_airresp_accepts_the_live_aircraft_factory_waiver(self) -> None:
        self.assertIn('"_hasAirFactory","_afStructNames","_afStructs","_afStructIdx","_afStructClass"', self.airresp)
        self.assertIn('_hasAirFactory = false;', self.airresp)
        self.assertIn('_hasAirFactory = true', self.airresp)
        self.assertIn('_airOK = _hasAirFactory ||', self.airresp)
        self.assertIn('forEach vehicles;', self.airresp)
        self.assertIn('Call WFBE_CO_FNC_GetSideUpgrades', self.airresp)

    def test_airresp_telemetry_explains_a_liveness_skip(self) -> None:
        self.assertIn('|airAlive=" + str _airAlive', self.airresp)
        self.assertIn('|skip=" + _skipReason', self.airresp)

    def test_decap_senses_before_it_commits(self) -> None:
        sense = self.constants.index('if (isNil "WFBE_C_AICOM2_DECAP_SENSE_RADIUS")')
        commit = self.constants.index('if (isNil "WFBE_C_AICOM2_DECAP_COMMIT_RADIUS")')
        sense_line = self.constants[sense:self.constants.index("\n", sense)]
        commit_line = self.constants[commit:self.constants.index("\n", commit)]
        self.assertIn('then {3000} else {5000}', sense_line)
        self.assertIn('then {2000} else {3000}', commit_line)
        self.assertNotIn('= WFBE_C_AICOM2_DECAP_SENSE_RADIUS', commit_line)

    def test_decap_telemetry_names_the_first_arm_gate(self) -> None:
        self.assertIn('"_gateReason"', self.decap)
        self.assertIn('|gate=" + _gateReason', self.decap)
        self.assertIn('|domRatio=" + str _domRatio', self.decap)
        self.assertIn('|maxEnTowns=" + str _maxEnTowns', self.decap)


if __name__ == "__main__":
    unittest.main()
