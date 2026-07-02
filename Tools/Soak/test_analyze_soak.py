import tempfile
import unittest
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import analyze_soak


SAMPLE = """\
AICOMSTAT|v1|MHQRELOC|WEST|12|TRIGGER|frontDist=900
AICOMSTAT|v1|MHQRELOC|WEST|14|DEPLOYED|reason=front
AICOMSTAT|v2|EVENT|WEST|15|PATROL_UNSTUCK|team=B 1-1-A
AICOMSTAT|v2|EVENT|EAST|16|BUILD_ROAD_CLEAR|type=Barracks
FPSREPORT|v1|uid=1|fps=47.5|fpsMin=31|players=4|hc=2
WASPSTAT|v1|2|ROUNDEND|WEST|5432|chernarus
HCSIDE|v1|connect|uid=hc1|owner=2|side=CIV
[WFBE (SKIN)] B6 COMPLETE: player='Ray' class='US_Soldier'
Support_ScudStrike.sqf : [WEST] denied -- cooldown (120s left).
GUI_Menu_EASA.sqf: Player vehicle [car] was not found within the list.
"""


class AnalyzeSoakTests(unittest.TestCase):
    def test_sample_kpis(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "build86.rpt"
            path.write_text(SAMPLE, encoding="utf-8")
            builds = analyze_soak.analyze([("Build86", path)], recurse=False)
            row = builds["Build86"].row()

        self.assertEqual(row["mhq_triggers"], 1)
        self.assertEqual(row["mhq_deployed"], 1)
        self.assertEqual(row["patrol_unstuck"], 1)
        self.assertEqual(row["build_road"], 1)
        self.assertEqual(row["fps_reports"], 1)
        self.assertEqual(row["roundend"], 1)
        self.assertEqual(row["hc_connect"], 1)
        self.assertEqual(row["skin_complete"], 1)
        self.assertEqual(row["scud_denied"], 1)
        self.assertEqual(row["easa_gear"], 1)


if __name__ == "__main__":
    unittest.main()
