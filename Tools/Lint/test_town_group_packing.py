"""Regression contract for same-mass town-garrison consolidation."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2] / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / "Server" / "Functions"
FILES = ("Server_GetTownGroups.sqf", "Server_GetTownGroupsDefender.sqf")


class TownGroupPackingContractTests(unittest.TestCase):
    def test_consolidation_packs_individual_classnames_not_whole_rosters(self):
        for filename in FILES:
            source = (ROOT / filename).read_text(encoding="utf-8")
            self.assertIn("GROUP-PACKING", source, filename)
            self.assertIn("forEach _roster", source, filename)
            self.assertIn("if ((count _acc) >= _mergeTarget)", source, filename)
            self.assertNotIn("(count _acc) + (count _roster)", source, filename)

    def test_runtime_targets_keep_same_mass_packing_in_the_nine_to_ten_band(self):
        constants = (
            Path(__file__).resolve().parents[2]
            / "Missions"
            / "[55-2hc]warfarev2_073v48co.chernarus"
            / "Common"
            / "Init"
            / "Init_CommonConstants.sqf"
        ).read_text(encoding="utf-8")
        self.assertIn("WFBE_C_TOWNS_MERGE_TARGET = 9", constants)
        self.assertIn("WFBE_C_TOWNS_MERGE_TARGET_DEFENDER = 10", constants)
        self.assertIn("WFBE_C_TOWNS_MERGE_TARGET = 10", constants)


if __name__ == "__main__":
    unittest.main()
