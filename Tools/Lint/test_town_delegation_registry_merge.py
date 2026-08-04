#!/usr/bin/env python3
"""Regression contract for cleanup losing a delegation registered during its yield."""

from pathlib import Path
import unittest


REPO = Path(__file__).resolve().parents[2]
CLEANUP = (
    REPO
    / "Missions"
    / "[55-2hc]warfarev2_073v48co.chernarus"
    / "Client"
    / "Functions"
    / "Client_CleanupDelegatedTownAI.sqf"
)


class TownDelegationRegistryMergeContractTests(unittest.TestCase):
    def test_cleanup_rebuild_reads_current_registry_and_preserves_retained_groups(self):
        cleanup = CLEANUP.read_text(encoding="utf-8")

        self.assertIn(
            '_registryCurrent = missionNamespace getVariable ["WFBE_CL_TownAI_Groups", []]',
            cleanup,
        )
        self.assertIn("} forEach _registryCurrent;", cleanup)
        self.assertIn("if (_entryGroup in _groups) then {", cleanup)
        self.assertIn("if !(_entryGroup in _keptRegistryGroups) exitWith {};", cleanup)


if __name__ == "__main__":
    unittest.main()
