"""Regression contract for same-mass town-garrison consolidation."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2] / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / "Server" / "Functions"
FILES = ("Server_GetTownGroups.sqf", "Server_GetTownGroupsDefender.sqf")


def pack_segments(rosters, target):
    """Model cap-bounded packs while retaining each source roster's first-unit guarantee."""
    packed = []
    current = []
    current_size = 0
    for roster in rosters:
        remaining = list(roster)
        force_first = True
        while remaining:
            space = target - current_size
            segment = remaining[:space]
            current.append((segment, force_first))
            current_size += len(segment)
            remaining = remaining[space:]
            force_first = False
            if current_size == target:
                packed.append(current)
                current = []
                current_size = 0
    if current:
        packed.append(current)
    return packed


def expected_spawns(segments, probability=0.90):
    """Expected created units for CreateTeam segments (forced source heads only)."""
    total = 0
    for classes, force_first in segments:
        if force_first:
            total += 1 + probability * (len(classes) - 1)
        else:
            total += probability * len(classes)
    return total


class TownGroupPackingContractTests(unittest.TestCase):
    def test_consolidation_packs_cap_bounded_source_roster_segments(self):
        for filename in FILES:
            source = (ROOT / filename).read_text(encoding="utf-8")
            self.assertIn("GROUP-COUNT REDUCTION", source, filename)
            self.assertIn("PACKED-SEGMENTS", source, filename)
            self.assertIn("forEach _infRosters", source, filename)
            self.assertIn("_packedSegments = []", source, filename)
            self.assertIn("WFBE_TOWN_PACKED_SEGMENTS", source, filename)
            self.assertNotIn("_roster select [", source, filename)
            self.assertNotIn("(count _acc) + (count _roster)", source, filename)

    def test_defender_nonpositive_cap_disables_packing_without_empty_groups(self):
        source = (ROOT / "Server_GetTownGroupsDefender.sqf").read_text(encoding="utf-8")
        self.assertIn("if (_mergeCap <= 0) then {_mergeTarget = 0}", source)

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

    def test_packed_segments_preserve_each_source_roster_spawn_contract(self):
        rosters = [
            ["a_leader", "a_1", "a_2", "a_3", "a_4", "a_5"],
            ["b_leader", "b_1", "b_2", "b_3", "b_4", "b_5"],
            ["c_leader", "c_1", "c_2", "c_3", "c_4", "c_5"],
        ]
        packed = pack_segments(rosters, 10)
        self.assertEqual([sum(len(classes) for classes, _ in group) for group in packed], [10, 8])
        self.assertCountEqual(
            [unit for roster in rosters for unit in roster],
            [unit for group in packed for classes, _ in group for unit in classes],
        )
        self.assertEqual(sum(expected_spawns(group) for group in packed), sum(expected_spawns([(roster, True)]) for roster in rosters))
        for filename in FILES:
            source = (ROOT / filename).read_text(encoding="utf-8")
            self.assertIn("PACKED-SEGMENTS", source, filename)
            self.assertIn("_forceFirst", source, filename)
        create_town_units = (
            Path(__file__).resolve().parents[2]
            / "Missions"
            / "[55-2hc]warfarev2_073v48co.chernarus"
            / "Common"
            / "Functions"
            / "Common_CreateTownUnits.sqf"
        ).read_text(encoding="utf-8")
        create_team = (
            Path(__file__).resolve().parents[2]
            / "Missions"
            / "[55-2hc]warfarev2_073v48co.chernarus"
            / "Common"
            / "Functions"
            / "Common_CreateTeam.sqf"
        ).read_text(encoding="utf-8")
        self.assertIn("TOWN-PACKED-SEGMENTS", create_town_units)
        self.assertIn("_forceFirst = if (count _this > 8)", create_team)


if __name__ == "__main__":
    unittest.main()
