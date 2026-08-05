import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TERRAIN_DIRS = (
    Path("Missions") / "[55-2hc]warfarev2_073v48co.chernarus",
    Path("Missions_Vanilla") / "[61-2hc]warfarev2_073v48co.takistan",
    Path("Missions_Vanilla") / "[61-2hc]warfarev2_073v48co.zargabad",
)
HELPER_RELATIVE_PATH = Path("Common/Functions/Common_ChangeUnitGroup.sqf")
FUNCTION_TOKEN = "WFBE_CO_FNC_ChangeUnitGroup"
REGISTRATION = re.compile(
    rf"(?im)^\s*{re.escape(FUNCTION_TOKEN)}\s*=\s*Compile\b"
)


class DeadSquadJoinRegistrationTests(unittest.TestCase):
    def test_retired_squadjoin_helper_is_not_registered_in_maintained_terrains(self):
        for terrain_relative_path in TERRAIN_DIRS:
            terrain = ROOT / terrain_relative_path
            init_common = terrain / "Common/Init/Init_Common.sqf"
            init_text = init_common.read_text(encoding="utf-8-sig")

            self.assertIsNone(
                REGISTRATION.search(init_text),
                f"retired squad-join helper is still registered in {init_common}",
            )

            references = [
                path
                for path in terrain.rglob("*.sqf")
                if FUNCTION_TOKEN in path.read_text(encoding="utf-8-sig")
            ]
            self.assertEqual(
                [],
                references,
                f"retired squad-join function still has maintained-mission references: {references}",
            )

            self.assertTrue(
                (terrain / HELPER_RELATIVE_PATH).is_file(),
                f"shared helper was unexpectedly removed from {terrain}",
            )


if __name__ == "__main__":
    unittest.main()
