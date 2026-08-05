#!/usr/bin/env python3
"""Regression contract for BASE-GC crew teardown seat safety.

The server-side BASE-GC path deletes idle crewed air/armor at a base.  A2 OA can
still be moving a deleted Man between a vehicle's seat array and its group when
the next deletion runs, so the crew pass must yield between deletes before the
hull is removed.  Keep this contract mirrored across all maintained terrains.
"""

from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)
SOURCE = Path("Server/FSM/server_groupsGC.sqf")
START = "// ============ (ii) IDLE CREWED HELI/ARMOR AT BASE (delete only) ============"
END = "// --- Orphaned-team zombie reaper ---"


class GroupsGcBaseCrewSeatSafeTests(unittest.TestCase):
    def test_base_gc_yields_between_crew_deletes_before_hull_delete(self) -> None:
        for mission in MISSIONS:
            with self.subTest(mission=mission.name):
                text = (mission / SOURCE).read_text(encoding="utf-8-sig")
                self.assertIn(START, text)
                self.assertIn(END, text)
                cleanup = text[text.index(START):text.index(END)]

                self.assertRegex(
                    cleanup,
                    re.compile(
                        r'\{\s*if \(!isPlayer _x\) then \{'
                        r'.*?"gc-baseair-unit".*?'
                        r'deleteVehicle _x;\s*sleep 0;\s*\};'
                        r'\s*\} forEach _baseVcrew;',
                        re.DOTALL,
                    ),
                )
                crew_end = cleanup.index("} forEach _baseVcrew;")
                hull_delete = cleanup.index('"gc-baseair-hull"')
                self.assertLess(
                    crew_end,
                    hull_delete,
                    "BASE-GC must finish the yielded crew pass before deleting the hull",
                )


if __name__ == "__main__":
    unittest.main()
