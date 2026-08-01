"""Static contracts for RHUD/artillery-ring cooldown reads."""

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TERRAIN_ROOTS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)
RELATIVE_PATHS = (
    "Client/Client_UpdateRHUD.sqf",
    "Client/Functions/Client_ArtyRangeRings.sqf",
)


class RhudArtilleryCooldownGuardTests(unittest.TestCase):
    def test_rhud_fails_closed_before_indexing_upgrade_or_interval_tables(self):
        source = (ROOT / TERRAIN_ROOTS[0] / RELATIVE_PATHS[0]).read_text(
            encoding="utf-8"
        )

        self.assertIn(
            'missionNamespace getVariable ["WFBE_C_ARTILLERY_INTERVALS", []]',
            source,
        )
        self.assertIn(
            'typeName _intervals != "ARRAY"',
            source,
        )
        self.assertIn(
            'typeName _ups != "ARRAY"',
            source,
        )
        self.assertIn("_artyIntervalIndex", source)
        self.assertIn("_artyUpgradeIndex", source)
        self.assertNotIn(
            "_fireTime = _intervals select (_ups select WFBE_UP_ARTYTIMEOUT);",
            source,
        )

    def test_artillery_rings_share_the_same_bounded_read_contract(self):
        source = (ROOT / TERRAIN_ROOTS[0] / RELATIVE_PATHS[1]).read_text(
            encoding="utf-8"
        )

        self.assertIn(
            'missionNamespace getVariable ["WFBE_C_ARTILLERY_INTERVALS", []]',
            source,
        )
        self.assertIn('typeName _artyIntervals == "ARRAY"', source)
        self.assertIn("_artyIntervalIndex", source)
        self.assertIn("_artyUpgradeIndex", source)
        self.assertNotIn(
            "_artyFireTime = _artyIntervals select (_artyUps select WFBE_UP_ARTYTIMEOUT);",
            source,
        )

    def test_all_maintained_terrain_copies_match(self):
        for relative_path in RELATIVE_PATHS:
            source = (ROOT / TERRAIN_ROOTS[0] / relative_path).read_bytes().replace(
                b"\r\n", b"\n"
            )
            for terrain_root in TERRAIN_ROOTS[1:]:
                mirror = (ROOT / terrain_root / relative_path).read_bytes().replace(
                    b"\r\n", b"\n"
                )
                self.assertEqual(source, mirror, relative_path)


if __name__ == "__main__":
    unittest.main()
