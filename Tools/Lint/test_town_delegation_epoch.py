#!/usr/bin/env python3
"""Regression contract for stale delegated town-garrison acknowledgments.

An HC can finish a delegated town-AI batch after its town has changed owner.
The server must reject that old lifecycle report and ask the owning machine to
clean it locally, rather than appending it to the new owner's town registry.
"""

from pathlib import Path
import unittest


REPO = Path(__file__).resolve().parents[2]
ROOTS = (
    REPO / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    REPO / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    REPO / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)


class TownDelegationEpochContractTests(unittest.TestCase):
    def test_every_maintained_mission_has_the_stale_ack_contract(self):
        for root in ROOTS:
            town = (root / "Server" / "FSM" / "server_town.sqf").read_text(encoding="utf-8")
            delegate = (root / "Server" / "Functions" / "Server_DelegateAITownHeadless.sqf").read_text(encoding="utf-8")
            client = (root / "Client" / "Functions" / "Client_DelegateTownAI.sqf").read_text(encoding="utf-8")
            handler = (root / "Server" / "Functions" / "Server_HandleSpecial.sqf").read_text(encoding="utf-8")

            self.assertIn('"wfbe_town_ai_epoch", 0', town)
            self.assertIn('"wfbe_town_ai_epoch", (_location getVariable ["wfbe_town_ai_epoch", 0]) + 1', town)
            self.assertIn('_town getVariable ["wfbe_town_ai_epoch", 0]', delegate)
            self.assertIn('_epoch = if (count _this > 5) then {_this select 5} else {-1}', client)
            self.assertIn('"update-town-delegation", _town, _town_teams, _town_vehicles, _side, _epoch', client)
            self.assertIn('_reportedEpoch', handler)
            self.assertIn('_reportedSide', handler)
            self.assertIn('"cleanup-townai", _town, _reportedSide', handler)
            self.assertIn('_reportedEpoch == (_town getVariable ["wfbe_town_ai_epoch", 0])', handler)

    def test_cleanup_preserves_a_group_registered_while_it_waits(self):
        """A cleanup worker yields, so its final rebuild must merge current entries."""
        for root in ROOTS:
            cleanup = (root / "Client" / "Functions" / "Client_CleanupDelegatedTownAI.sqf").read_text(encoding="utf-8")

            self.assertIn('_registryCurrent = missionNamespace getVariable ["WFBE_CL_TownAI_Groups", []]', cleanup)
            self.assertIn('if !(_entryGroup in _groups) then {_registryNew set [count _registryNew, _entry]}', cleanup)


if __name__ == "__main__":
    unittest.main()
