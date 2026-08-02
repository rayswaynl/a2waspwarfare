from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[2]
MISSION_DIRS = [
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
]
ANIM_REL = Path("Client/Functions/Client_SetControlFadeAnim.sqf")
STOP_REL = Path("Client/Functions/Client_SetControlFadeAnimStop.sqf")
DISPLAY_LOOKUP = re.compile(
    r'_display\s*=\s*uiNamespace\s+getVariable\s+\["currentBEDialog",\s*displayNull\]\s*;'
)


class UiDisplayHandleLifecycleTests(unittest.TestCase):
    def test_fade_worker_captures_display_and_control_before_sleep(self):
        for mission_dir in MISSION_DIRS:
            code = (mission_dir / ANIM_REL).read_text(encoding="utf-8")
            self.assertIn("disableSerialization;", code, mission_dir.name)
            self.assertRegex(code, DISPLAY_LOOKUP, mission_dir.name)
            self.assertIn("_ctrl = _display displayCtrl _control;", code, mission_dir.name)
            self.assertIn("if (isNull _display) exitWith {};", code, mission_dir.name)
            self.assertIn("if (isNull _ctrl) exitWith {};", code, mission_dir.name)
            self.assertNotIn("currentBEDialog displayCtrl", code, mission_dir.name)
            self.assertIn(
                "while {_i < _duration && {!isNull _display} && {!isNull _ctrl}} do {",
                code,
                mission_dir.name,
            )
            self.assertIn(
                "if (!isNull _display && {!isNull _ctrl}) then {",
                code,
                mission_dir.name,
            )

    def test_fade_stop_uses_the_same_snapshot_and_fails_closed(self):
        for mission_dir in MISSION_DIRS:
            code = (mission_dir / STOP_REL).read_text(encoding="utf-8")
            self.assertIn("disableSerialization;", code, mission_dir.name)
            self.assertRegex(code, DISPLAY_LOOKUP, mission_dir.name)
            self.assertIn("_ctrl = _display displayCtrl _control;", code, mission_dir.name)
            self.assertIn("if (isNull _display) exitWith {};", code, mission_dir.name)
            self.assertIn("if (isNull _ctrl) exitWith {};", code, mission_dir.name)
            self.assertNotIn("currentBEDialog displayCtrl", code, mission_dir.name)

    def test_all_map_mirrors_have_identical_lifecycle_contract(self):
        anim_sources = [(mission_dir / ANIM_REL).read_bytes() for mission_dir in MISSION_DIRS]
        stop_sources = [(mission_dir / STOP_REL).read_bytes() for mission_dir in MISSION_DIRS]
        for source in anim_sources + stop_sources:
            self.assertNotIn(b"\n", source.replace(b"\r\n", b""))
        self.assertTrue(all(source == anim_sources[0] for source in anim_sources[1:]))
        self.assertTrue(all(source == stop_sources[0] for source in stop_sources[1:]))


if __name__ == "__main__":
    unittest.main()
