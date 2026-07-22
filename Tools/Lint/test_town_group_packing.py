"""Regression contract for same-mass town-garrison consolidation (flat-pack variant).

The flat-pack merge landed on master via update-wave PR #1196 (merge b34559739b),
superseding the packed-segments draft PR #1197. This contract pins the merged
behavior: whole-roster accumulation with a cap-bounded flush, vehicles atomic,
the tuned merge-target constants, and CH/TK/ZG mirror parity for every touched file.
"""

from collections import Counter
from hashlib import sha256
from pathlib import Path
import unittest

REPO = Path(__file__).resolve().parents[2]
CH = REPO / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"
MIRRORS = (
    REPO / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    REPO / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)
SHARED_PLANNER = Path("Server") / "Functions" / "Server_GetTownGroups.sqf"
DEFENDER_PLANNER = Path("Server") / "Functions" / "Server_GetTownGroupsDefender.sqf"
CONSTANTS = Path("Common") / "Init" / "Init_CommonConstants.sqf"


def flat_pack(rosters, target, cap):
    """Python mirror of the flat-pack loop in Server_GetTownGroups*.sqf (whole rosters)."""
    merged = []
    acc = []
    for roster in rosters:
        if len(acc) + len(roster) > cap and len(acc) > 0:
            merged.append(acc)
            acc = []
        acc = acc + list(roster)
        if len(acc) >= target:
            merged.append(acc)
            acc = []
    if len(acc) > 0:
        merged.append(acc)
    return merged


class TownGroupPackingContractTests(unittest.TestCase):
    def test_flat_pack_model_preserves_mass_and_bounds_group_size(self):
        rosters = [
            ["leader_a", "a1", "a2", "a3", "a4", "a5"],
            ["leader_b", "b1", "b2", "b3"],
            ["leader_c", "c1", "c2", "c3", "c4", "c5"],
            ["leader_d", "d1", "d2"],
            ["leader_e", "e1", "e2", "e3", "e4"],
        ]
        merged = flat_pack(rosters, target=9, cap=10)
        self.assertLess(len(merged), len(rosters))  # fewer group-brains than rosters
        self.assertEqual([len(group) for group in merged], [10, 9, 5])
        self.assertTrue(all(len(group) <= 10 for group in merged))
        self.assertEqual(
            Counter(unit for roster in rosters for unit in roster),
            Counter(unit for group in merged for unit in group),
        )

    def test_flat_pack_model_keeps_oversized_roster_atomic(self):
        oversized = [["leader_x"] + ["x%d" % i for i in range(11)]]
        self.assertEqual(flat_pack(oversized, target=9, cap=10), oversized)

    def test_shared_planner_uses_flat_pack_whole_roster_merge(self):
        source = (CH / SHARED_PLANNER).read_text(encoding="utf-8")
        for marker in (
            "GROUP-COUNT REDUCTION",
            "_infRosters = []",
            "_vehRosters = []",
            "_acc = _acc + _roster",
            "if (count _acc >= _mergeTarget)",
            "((count _acc) + (count _roster)) > _mergeCap",
            "forEach _vehRosters",
            'missionNamespace getVariable ["WFBE_C_TOWNS_MERGE_TARGET", 5]',
        ):
            self.assertIn(marker, source)
        self.assertNotIn("_packedSegments", source)  # superseded variant must not return

    def test_defender_planner_cap_and_target_fallback(self):
        source = (CH / DEFENDER_PLANNER).read_text(encoding="utf-8")
        for marker in (
            "GROUP-COUNT REDUCTION",
            'missionNamespace getVariable ["WFBE_C_TOWNS_MERGE_TARGET_DEFENDER", 0]',
            'if (_mergeTarget <= 0) then {_mergeTarget = missionNamespace getVariable ["WFBE_C_TOWNS_MERGE_TARGET", 5]}',
            'missionNamespace getVariable ["WFBE_C_TOWNS_MERGE_CAP_DEFENDER", 10]',
            "((count _acc) + (count _roster)) > _mergeCap",
        ):
            self.assertIn(marker, source)

    def test_constants_match_merged_merge_targets(self):
        constants = (CH / CONSTANTS).read_text(encoding="utf-8")
        # Global WEST/EAST target plus the Zargabad-block override, both 9.
        self.assertEqual(constants.count("WFBE_C_TOWNS_MERGE_TARGET = 9;"), 2)
        self.assertIn("WFBE_C_TOWNS_MERGE_TARGET_DEFENDER = 10", constants)
        self.assertIn("WFBE_C_TOWNS_MERGE_CAP_DEFENDER = 12", constants)

    def test_mirror_parity_for_planners_and_constants(self):
        for rel in (SHARED_PLANNER, DEFENDER_PLANNER, CONSTANTS):
            digest = sha256((CH / rel).read_bytes()).hexdigest()
            for mirror in MIRRORS:
                mirrored = sha256((mirror / rel).read_bytes()).hexdigest()
                self.assertEqual(digest, mirrored, "%s drifted on %s" % (rel, mirror.name))


if __name__ == "__main__":
    unittest.main()
