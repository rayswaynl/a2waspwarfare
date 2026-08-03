#!/usr/bin/env python3
"""Static contracts for the OVERRUN razer dead-wiring repair (overrunrazer lane, 2026-07-25).

B74.1's scripted razer in AI_Commander_Strategy.sqf only ever runs when `_strikeOn` is true, and
`_strikeOn`'s only setter is nested inside the V1 HQ-strike block that is itself suppressed whenever
`WFBE_C_AICOM2_DECAP_ENABLE > 0` (the live default) - so on the live cutover build the razer path is
permanently unreachable. This suite asserts the NEW post-HQ-death mop-up closer breaks that
dependency entirely: its arm condition does not reference `_strikeOn` at all, it is declared textually
AFTER the DECAP-gated V1 block closes (i.e. it is not nested inside the suppressed block and cannot
inherit that suppression), and its owner-directed flag registration remains explicitly armed at 1;
the rollback value 0 remains byte-identical to HEAD when off. It also
asserts the companion BASE-ASSAULT engage-gate patch exists behind the SAME flag, since a reachable
trigger with no engage-gate patch reproduces the exact same live-idle failure with a different name.
"""

from pathlib import Path
import unittest

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"

FLAG = "WFBE_C_AICOM_OVERRUN_MOPUP_ENABLE"


def code(relative: str) -> str:
    return mask_comments((MISSION / relative).read_text(encoding="utf-8-sig"))


class OverrunRazerReachabilityTests(unittest.TestCase):
    def setUp(self) -> None:
        self.strategy = code("Server/AI/Commander/AI_Commander_Strategy.sqf")
        self.driver = code("Common/Functions/Common_RunCommanderTeam.sqf")
        self.constants = code("Common/Init/Init_CommonConstants.sqf")

    def test_new_flag_is_armed_and_never_reassigned(self) -> None:
        idx = self.constants.index('if (isNil "%s")' % FLAG)
        line = self.constants[idx: self.constants.index("\n", idx)]
        self.assertIn("= 1}", line)
        # Exactly one declaration site (append-only convention; never re-defaulted elsewhere).
        self.assertEqual(self.constants.count('"%s"' % FLAG), 1)

    def test_v1_strikeon_suppression_is_unchanged(self) -> None:
        # The pre-existing DECAP-cutover suppression of the V1 HQ-strike block (the confirmed dead
        # wire) must still be present exactly as before - this repair does not touch it.
        self.assertIn(
            'if ((missionNamespace getVariable ["WFBE_C_AICOM2_DECAP_ENABLE", 0]) <= 0) then {',
            self.strategy,
        )
        self.assertIn("_strikeOn = false;", self.strategy)

    def test_mopup_closer_is_declared_outside_the_suppressed_v1_block(self) -> None:
        # The V1 block opens at the DECAP-gate `if` and closes at its matching "end DECAP GATE"
        # marker comment (stripped by mask_comments, so locate via the surrounding source instead).
        raw = (MISSION / "Server/AI/Commander/AI_Commander_Strategy.sqf").read_text(encoding="utf-8-sig")
        gate_open = raw.index('if ((missionNamespace getVariable ["WFBE_C_AICOM2_DECAP_ENABLE", 0]) <= 0) then {')
        gate_close = raw.index("end DECAP GATE (V1 HQ-strike block)", gate_open)
        mopup_open = raw.index('if ((missionNamespace getVariable ["%s", 0]) > 0) then {' % FLAG)
        self.assertGreater(
            mopup_open,
            gate_close,
            "mop-up closer must be declared AFTER the suppressed V1 block closes, "
            "never nested inside it - otherwise it inherits the same dead gate.",
        )

    def test_mopup_arm_condition_never_reads_strikeon(self) -> None:
        # Isolate just the new closer's source span and assert `_strikeOn` never appears in it -
        # proving its trigger is fully independent of the dead V1 flag.
        raw = (MISSION / "Server/AI/Commander/AI_Commander_Strategy.sqf").read_text(encoding="utf-8-sig")
        start = raw.index('if ((missionNamespace getVariable ["%s", 0]) > 0) then {' % FLAG)
        # The closer is the last top-level block before the POSTURE telemetry section.
        end = raw.index("POSTURE + FRONT telemetry", start)
        block = raw[start:end]
        self.assertNotIn("_strikeOn", block)
        self.assertNotIn("wfbe_aicom_strike_on", block)

    def test_mopup_arms_only_once_the_enemy_hq_is_confirmed_dead(self) -> None:
        self.assertIn(
            "if (!isNull _enemyHQ && {!alive _enemyHQ}) then {",
            self.strategy,
        )

    def test_mopup_dispatch_stamps_its_own_team_var_not_decap_or_strike(self) -> None:
        self.assertIn('"wfbe_aicom_overrun_mopup"', self.strategy)
        # Never reuses DECAP's own press-stamp key (that would race DECAP's clear-when-idle pass).
        self.assertNotIn('_moTeam setVariable ["wfbe_aicom_decap"', self.strategy)
        self.assertNotIn('_moTeam setVariable ["wfbe_aicom_strike"', self.strategy)

    def test_existing_overrun_defaults_are_untouched(self) -> None:
        # This repair must not change the meaning of the pre-existing OVERRUN constants.
        self.assertIn('if (isNil "WFBE_C_AICOM_OVERRUN_RAZE")          then {WFBE_C_AICOM_OVERRUN_RAZE          = 400}', self.constants)
        self.assertIn('if (isNil "WFBE_C_AICOM_OVERRUN_SCRIPTRAZE")     then {WFBE_C_AICOM_OVERRUN_SCRIPTRAZE = 0}', self.constants)

    def test_engagegate_companion_patch_exists_behind_the_same_flag(self) -> None:
        # The BASE-ASSAULT engage-gate must gain an else-branch, gated on the SAME flag, that can
        # set _inRange true when the enemy HQ is dead - otherwise a mop-up team presses onto a
        # factory and simply idles in the arrival SAD forever (the original bug, renamed).
        idx = self.driver.index('_engageRange = missionNamespace getVariable ["WFBE_C_AICOM_ASSAULT_ENGAGE_RANGE", 400];')
        gate_span = self.driver[idx: idx + 2500]
        self.assertIn("} else {", gate_span)
        self.assertIn(FLAG, gate_span)
        self.assertIn("Call WFBE_CO_FNC_GetClosestEntity", gate_span)
        self.assertIn("_inRange = true", gate_span)

    def test_engagegate_patch_alive_filters_before_ranging(self) -> None:
        # GetSideStructures returns dead structures too; the patch must alive-filter before
        # picking a nearest target, or it can anchor on a corpse building and never engage.
        idx = self.driver.index(FLAG)
        span = self.driver[idx: idx + 800]
        self.assertIn("alive _x", span)


if __name__ == "__main__":
    unittest.main()
