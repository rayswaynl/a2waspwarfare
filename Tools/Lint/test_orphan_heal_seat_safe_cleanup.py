#!/usr/bin/env python3
"""Regression contract for HC-orphan team retirement seat safety."""

from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)
SOURCE = Path("Server/FSM/server_aicom_orphan_heal.sqf")
START = "if (_never || {(!_pNear) && {!_combat}}) then {"
END = '["aicom-team-ended", _sideID, _g] Call HandleSpecial;'


class OrphanHealSeatSafeTests(unittest.TestCase):
    def test_orphan_retire_yields_before_hull_enumeration_and_requires_empty_hulls(self) -> None:
        for mission in MISSIONS:
            with self.subTest(mission=mission.name):
                source = (mission / SOURCE).read_text(encoding="utf-8-sig")
                self.assertIn(START, source)
                self.assertIn(END, source)
                start = source.index(START)
                cleanup = source[start:source.index(END, start)]

                self.assertRegex(
                    cleanup,
                    re.compile(
                        r"\{\s*if \(!isNull _x && \{local _x\}\) then \{"
                        r".*?deleteVehicle _x;\s*sleep 0;\s*_delN",
                        re.DOTALL,
                    ),
                )
                hulls_index = cleanup.index("_hulls = [_g, false] Call GetTeamVehicles;")
                unit_loop_index = cleanup.index("if (!isNull _x && {local _x}) then {")
                self.assertLess(
                    hulls_index,
                    unit_loop_index,
                    "hulls must be captured before the yielded unit purge empties the group",
                )
                self.assertRegex(
                    cleanup,
                    re.compile(
                        r"\{isPlayer _x\} count \(crew _h\).*?"
                        r"count \(crew _h\)\) == 0",
                        re.DOTALL,
                    ),
                )

    def test_orphan_healer_is_started_in_a_scheduled_execvm_context(self) -> None:
        init = (
            ROOT
            / "Missions"
            / "[55-2hc]warfarev2_073v48co.chernarus"
            / "Server"
            / "Init"
            / "Init_Server.sqf"
        ).read_text(encoding="utf-8-sig")
        self.assertIn('[] execVM "Server\\FSM\\server_aicom_orphan_heal.sqf";', init)


if __name__ == "__main__":
    unittest.main()
