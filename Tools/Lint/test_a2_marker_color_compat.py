"""Static contract checks for marker colours supported by Arma 2 OA."""

import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = (
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)
RUNTIME_FILES = (
    "Server/Init/Init_ZgKoth.sqf",
    "Server/Init/Init_NavalHVT.sqf",
    "Common/Init/Init_CommonConstants.sqf",
    "Client/FSM/updateteamsmarkers.sqf",
)
UNSUPPORTED_COLORS = ("ColorGray", "ColorWest", "ColorEast")


class A2MarkerColorCompatibilityTests(unittest.TestCase):
    def test_runtime_paths_do_not_emit_undefined_marker_colors(self):
        for mission_root in MISSION_ROOTS:
            for relative_path in RUNTIME_FILES:
                source = (mission_root / relative_path).read_text(encoding="utf-8")
                for color in UNSUPPORTED_COLORS:
                    self.assertIsNone(
                        re.search(rf'"{color}"', source),
                        f"{mission_root.name}/{relative_path} still emits {color}",
                    )
            description = (mission_root / "description.ext").read_text(encoding="utf-8")
            self.assertNotIn(
                "class CfgMarkerColors",
                description,
                f"{mission_root.name}/description.ext must not advertise inert custom colors",
            )

    def test_zg_koth_and_naval_hvt_keep_side_and_neutral_fallbacks(self):
        for mission_root in MISSION_ROOTS:
            koth = (mission_root / RUNTIME_FILES[0]).read_text(encoding="utf-8")
            naval = (mission_root / RUNTIME_FILES[1]).read_text(encoding="utf-8")
            constants = (mission_root / RUNTIME_FILES[2]).read_text(encoding="utf-8")
            teams = (mission_root / RUNTIME_FILES[3]).read_text(encoding="utf-8")

            for source, label in ((koth, "KOTH"), (naval, "NavalHVT")):
                self.assertIn('"ColorBlue"', source, label)
                self.assertIn('"ColorRed"', source, label)
                self.assertIn('"ColorBlack"', source, label)
            self.assertIn('WFBE_C_NEUTRAL_COLOR = "ColorBlack"', constants)
            self.assertIn('_markerColor = "ColorBlack"', teams)


if __name__ == "__main__":
    unittest.main()
