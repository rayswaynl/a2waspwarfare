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
    def test_fade_worker_holds_no_display_across_its_sleep(self):
        """2026-08-03 INVERTED. This test previously REQUIRED the snapshot idiom -
        disableSerialization plus _display/_ctrl locals captured before a sleeping
        loop. On A2 OA 1.64 that is the script-killing pattern documented by this
        repo's own m0730f->g incident (docs/CHANGELOG-m0730g.md): the worker dies
        after its first sleep, its cleanup never runs, and the Tactical placement
        hint stays stuck on screen. The test therefore enforced the bug instead of
        catching it. The contract is now the proven-safe GUI_RespawnMenu.sqf idiom:
        no disableSerialization, no Display/Control bound to a local, every lookup
        re-fetched inline at its point of use."""
        for mission_dir in MISSION_DIRS:
            code = (mission_dir / ANIM_REL).read_text(encoding="utf-8")
            self.assertNotIn("disableSerialization;", code, mission_dir.name)
            self.assertNotRegex(code, DISPLAY_LOOKUP, mission_dir.name)
            self.assertNotIn("_ctrl = _display displayCtrl _control;", code, mission_dir.name)
            # The worker must still suspend (it is an animation) ...
            self.assertIn("sleep 1;", code, mission_dir.name)
            # ... and every dialog/control access must be an inline re-fetch.
            self.assertIn(
                '(uiNamespace getVariable ["currentBEDialog", displayNull]) displayCtrl _control',
                code,
                mission_dir.name,
            )

    def test_fade_stop_uses_the_same_snapshot_and_fails_closed(self):
        """The Stop variant is straight-line: it never suspends, so holding the
        Display in a local is safe here and the snapshot idiom stays required."""
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
