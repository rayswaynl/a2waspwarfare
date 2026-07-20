"""Regression contract for same-mass town-garrison consolidation."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2] / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / "Server" / "Functions"
FILES = ("Server_GetTownGroups.sqf", "Server_GetTownGroupsDefender.sqf")


def pack_rosters(rosters, target):
    """Model the source contract: retain each roster leader at an output-group start."""
    packed = []
    current = []
    for roster in rosters:
        if not current:
            current = list(roster)
        else:
            space = target - len(current)
            if space >= len(roster):
                current.extend(roster)
            else:
                split_at = len(roster) - space
                current.extend(roster[split_at:])
                packed.append(current)
                current = list(roster[:split_at])
        if len(current) >= target:
            packed.append(current)
            current = []
    if current:
        packed.append(current)
    return packed


class TownGroupPackingContractTests(unittest.TestCase):
    def test_consolidation_packs_individual_classnames_not_whole_rosters(self):
        for filename in FILES:
            source = (ROOT / filename).read_text(encoding="utf-8")
            self.assertIn("GROUP-PACKING", source, filename)
            self.assertIn("LEADER-PRESERVING", source, filename)
            self.assertIn("forEach _infRosters", source, filename)
            self.assertIn("_prefix = []", source, filename)
            self.assertIn("for '_packIndex' from 0 to ((count _roster) - 1) do", source, filename)
            self.assertNotIn("_roster select [", source, filename)
            self.assertNotIn("(count _acc) + (count _roster)", source, filename)

    def test_split_keeps_the_next_roster_leader_at_the_next_group_start(self):
        rosters = [
            ["squad_co", "squad_gl", "squad_ar", "squad_mg"],
            ["team_co", "team_sniper", "team_ar", "team_gl", "team_at", "team_medic"],
        ]
        packed = pack_rosters(rosters, 9)
        self.assertEqual(packed, [
            ["squad_co", "squad_gl", "squad_ar", "squad_mg", "team_sniper", "team_ar", "team_gl", "team_at", "team_medic"],
            ["team_co"],
        ])
        self.assertEqual([group[0] for group in packed], ["squad_co", "team_co"])
        self.assertCountEqual(
            [unit for roster in rosters for unit in roster],
            [unit for group in packed for unit in group],
        )

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


if __name__ == "__main__":
    unittest.main()
