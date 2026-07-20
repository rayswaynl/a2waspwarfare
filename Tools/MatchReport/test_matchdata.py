import unittest

from matchdata import TOWN_COORDS, coords_for, parse_waspstat


class ZargabadControlMapTests(unittest.TestCase):
    def test_zargabad_uses_static_8192m_town_set_and_keeps_unknown_capture(self):
        towns, world_size = coords_for(
            "zargabad", list(TOWN_COORDS.get("zargabad", {}).keys()) + ["New Capture"]
        )

        self.assertEqual(8192, world_size)
        self.assertEqual(11, len(TOWN_COORDS.get("zargabad", {})))
        self.assertIn("Zargabad", towns)
        self.assertIn("Zargabad AF", towns)
        self.assertIn("New Capture", towns)

    def test_zargabad_parser_builds_full_static_map_from_roundend(self):
        report = parse_waspstat([
            '"WASPSTAT|v1|1|CAPTURE|Zargabad|4|0|t=60"',
            '"WASPSTAT|v1|2|ROUNDEND|WEST|600|zargabad"',
        ])

        self.assertEqual(8192, report.world_size)
        self.assertEqual(11, len(report.towns))
        self.assertIn("Yarum", report.towns)


if __name__ == "__main__":
    unittest.main()
