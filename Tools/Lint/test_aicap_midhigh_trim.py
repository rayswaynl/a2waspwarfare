#!/usr/bin/env python3
"""Static contract for the default-off MID/HIGH commander AI-cap trim."""

from pathlib import Path
import unittest

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"


def code(relative: str) -> str:
    return mask_comments((MISSION / relative).read_text(encoding="utf-8-sig"))


class AicapMidHighTrimTests(unittest.TestCase):
    def setUp(self) -> None:
        self.constants = code("Common/Init/Init_CommonConstants.sqf")
        self.server_init = code("Server/Init/Init_Server.sqf")

    def test_default_off_gate_keeps_legacy_and_applies_only_mid_high_trim(self) -> None:
        flag = 'if (isNil "WFBE_C_AICAP_MIDHIGH_TRIM") then {WFBE_C_AICAP_MIDHIGH_TRIM = 0}'
        self.assertIn(flag, self.constants)
        self.assertIn('WFBE_C_TOTAL_AI_MAX_BY_TIER       = [140,130,100,80]', self.constants)
        gate = self.constants.index('if (WFBE_C_AICAP_MIDHIGH_TRIM > 0) then {')
        block = self.constants[gate : gate + 500]
        self.assertIn('worldName != "Zargabad"', block)
        self.assertIn('WFBE_C_TOTAL_AI_MAX_BY_TIER = [140,115,90,80]', block)

    def test_active_trim_emits_match_start_attribution_stamp(self) -> None:
        gate = 'if ((missionNamespace getVariable ["WFBE_C_AICAP_MIDHIGH_TRIM", 0]) > 0) then {'
        self.assertIn(gate, self.server_init)
        stamp_at = self.server_init.index('diag_log ("AICAP|v1|tiers="')
        self.assertGreater(stamp_at, self.server_init.index(gate))
        self.assertIn('missionNamespace getVariable ["WFBE_C_TOTAL_AI_MAX_BY_TIER", []]',
                      self.server_init[stamp_at : stamp_at + 250])


if __name__ == "__main__":
    unittest.main()
