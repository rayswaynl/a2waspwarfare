#!/usr/bin/env python3
"""Static regression contract for AIRRESP's shared AICOM air ceiling."""

from pathlib import Path
import unittest

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"


def code(relative: str) -> str:
    return mask_comments((MISSION / relative).read_text(encoding="utf-8-sig"))


class AirRespGlobalAirCapTests(unittest.TestCase):
    def test_airresp_rejects_dispatch_at_the_shared_air_cap(self) -> None:
        airresp = code("Server/AI/Commander/AI_Commander_AirResp.sqf")
        self.assertIn('"_airMaxTotal"', airresp)
        self.assertIn('_airMaxTotal = missionNamespace getVariable ["WFBE_C_AICOM_AIR_MAX_TOTAL", 3];', airresp)
        self.assertIn('_airAlive < _airMaxTotal', airresp)
        self.assertIn('_skipReason = "air-cap"', airresp)


if __name__ == "__main__":
    unittest.main()
