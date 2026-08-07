#!/usr/bin/env python3
"""Regression coverage for the local rocket-tracer emitter lifetime."""

from pathlib import Path
import re
import unittest


SOURCE = (
    Path(__file__).resolve().parents[2]
    / "Missions"
    / "[55-2hc]warfarev2_073v48co.chernarus"
    / "Common"
    / "Functions"
    / "Common_HandleRocketTracer.sqf"
)


class RocketTracerLifecycleTests(unittest.TestCase):
    def test_reaps_early_emitters_when_projectile_expires_during_delay(self) -> None:
        source = SOURCE.read_text(encoding="utf-8")

        self.assertRegex(
            source,
            re.compile(
                r"sleep 0\.7;\s*(?://[^\n]*\n\s*)*"
                r"if \(isNull _rocket\) exitWith \{\s*"
                r"\{if \(!isNull _x\) then \{deleteVehicle _x\}\} "
                r"forEach \[_sp, _fp\];\s*\};"
            ),
        )

    def test_reaps_all_created_particle_sources_after_their_lifetime(self) -> None:
        source = SOURCE.read_text(encoding="utf-8")

        self.assertIn(
            "{if (!isNull _x) then {deleteVehicle _x}} forEach [_sp, _fp, _fp1];",
            source,
        )


if __name__ == "__main__":
    unittest.main()
