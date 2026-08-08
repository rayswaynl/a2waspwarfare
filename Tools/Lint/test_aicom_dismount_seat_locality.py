"""The AICOM dismount-seat latch is owner-local state, not public transport state."""

from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = (
    ROOT / r"Missions\[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / r"Missions_Vanilla\[61-2hc]warfarev2_073v48co.takistan",
    ROOT / r"Missions_Vanilla\[61-2hc]warfarev2_073v48co.zargabad",
)
SEAT_WRITE_RE = re.compile(
    r'setVariable\s*\[\s*"wfbe_aicom_dismount_seat"[^;\r\n]*,\s*(true|false)\s*\]\s*;'
)


class AicomDismountSeatLocalityTests(unittest.TestCase):
    def test_dismount_seat_latch_is_local_in_all_maintained_mirrors(self) -> None:
        for mission_root in MISSION_ROOTS:
            source = (
                mission_root / "Common" / "Functions" / "Common_RunCommanderTeam.sqf"
            ).read_text(encoding="utf-8")
            self.assertEqual(
                SEAT_WRITE_RE.findall(source),
                ["false", "false", "false"],
                str(mission_root),
            )


if __name__ == "__main__":
    unittest.main()
