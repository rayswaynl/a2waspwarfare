#!/usr/bin/env python3
"""Contract for the small-map AICOM tune (fable/zg-aicom-smallmap-tune, round 3).

Round-3 review repairs pinned here: gate + armed-helper defined BEFORE the first tuned
constant; tuned values applied as conditional FIRST-INIT defaults inside the original
isNil guards (explicit mission overrides always win; nothing is overwritten later);
HOME_RANGE direction corrected (RAISED - the retreat trigger is `dist > HOME_RANGE`);
retarget cooldown reads a DEDICATED target-change stamp; both suppressions carry the
hard-abandon blacklist exclusion.
"""

from pathlib import Path
import unittest

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"


def code(relative: str) -> str:
    return mask_comments((MISSION / relative).read_text(encoding="utf-8-sig"))


class SmallMapTuneTests(unittest.TestCase):
    def setUp(self) -> None:
        self.constants = code("Common/Init/Init_CommonConstants.sqf")
        self.assign = code("Server/AI/Commander/AI_Commander_AssignTowns.sqf")

    def test_gate_and_armed_helper_precede_every_tuned_constant(self) -> None:
        gate = self.constants.index('if (isNil "WFBE_C_AICOM_SMALLMAP_TUNE")')
        armed = self.constants.index("WFBE_AICOM_SMALLMAP_ARMED = ")
        for name in ("WFBE_C_AICOM_RETREAT_MAX_ISSUES", "WFBE_C_AICOM_RETREAT_HOME_RANGE",
                     "WFBE_C_AICOM_STRANDED_MERGE_RANGE", "WFBE_C_AICOM_COMMIT_COMBAT",
                     "WFBE_C_AICOM_RETARGET_COOLDOWN"):
            self.assertLess(gate, self.constants.index(f'if (isNil "{name}")'), name)
            self.assertLess(armed, self.constants.index(f'if (isNil "{name}")'), name)

    def test_tuned_values_are_conditional_first_init_defaults(self) -> None:
        # Each tuned constant: ONE isNil-guarded init whose default branches on the armed
        # helper - and no later re-assignment anywhere (explicit overrides never clobbered).
        for name, armed_val, legacy_val in (
            ("WFBE_C_AICOM_RETREAT_MAX_ISSUES", "14", "8"),
            ("WFBE_C_AICOM_RETREAT_HOME_RANGE", "1600", "800"),
            ("WFBE_C_AICOM_STRANDED_MERGE_RANGE", "2000", "1200"),
            ("WFBE_C_AICOM_COMMIT_COMBAT", "1", "0"),
            ("WFBE_C_AICOM_RETARGET_COOLDOWN", "600", "0"),
        ):
            inits = self.constants.count(f'if (isNil "{name}")')
            self.assertEqual(inits, 1, f"{name}: expected exactly one isNil init, got {inits}")
            idx = self.constants.index(f'if (isNil "{name}")')
            line = self.constants[idx : self.constants.index("\n", idx)]
            self.assertIn("WFBE_AICOM_SMALLMAP_ARMED", line, name)
            self.assertIn(f"{name} = {armed_val}", line, name)
            self.assertIn(f"{name} = {legacy_val}", line, name)
            # No non-guarded later assignment.
            assigns = self.constants.count(f"{name} = ")
            self.assertEqual(assigns, 2, f"{name}: expected only the two guarded branch assignments")

    def test_home_range_direction_is_raised_not_lowered(self) -> None:
        idx = self.constants.index('if (isNil "WFBE_C_AICOM_RETREAT_HOME_RANGE")')
        line = self.constants[idx : self.constants.index("\n", idx)]
        self.assertIn("= 1600", line)
        self.assertNotIn("= 500", line)

    def test_cooldown_uses_dedicated_target_change_stamp(self) -> None:
        # Stamped ONLY on target change at the dispatch write...
        stamp = self.assign.index('setVariable ["wfbe_aicom_tgt_since", time]')
        window = self.assign[stamp - 400 : stamp]
        self.assertIn("!_priorOpen || {!_sameTgt}", window)
        # ...and read (1-arg + isNil, G1-safe) by the cooldown, not _dispT0.
        hold = self.assign.index("RETARGET_COOLDOWN_HOLD")
        block = self.assign[hold - 900 : hold]
        self.assertIn('getVariable "wfbe_aicom_tgt_since"', block)
        self.assertIn('isNil "_jcTgtSince"', block)
        self.assertNotIn("(_jcOrd select 1)", block)

    def test_both_suppressions_carry_the_hard_abandon_exclusion(self) -> None:
        bl = self.assign.index("_jcBlHit = false")
        combat = self.assign.index('WFBE_C_AICOM_COMMIT_COMBAT", 0]) > 0')
        self.assertLess(bl, combat)
        self.assertIn('"wfbe_aicom_blacklist"', self.assign[bl - 300 : combat])
        # Both gates require the target NOT blacklisted.
        self.assertEqual(self.assign.count("{!_jcBlHit} &&"), 2)
        # Exclusion sits INSIDE the still-enemy guard region (flipped towns already retargetable).
        self.assertGreater(bl, self.assign.index('sideID", -1]) != _sideID'))

    def test_use_site_names_still_match(self) -> None:
        produce = code("Server/AI/Commander/AI_Commander_Produce.sqf")
        for name in ("WFBE_C_AICOM_RETREAT_MAX_ISSUES", "WFBE_C_AICOM_RETREAT_HOME_RANGE",
                     "WFBE_C_AICOM_STRANDED_MERGE_RANGE"):
            self.assertIn(name, produce)


if __name__ == "__main__":
    unittest.main()
