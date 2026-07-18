import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"


def source(relative_path):
    return (MISSION / relative_path).read_text(encoding="utf-8")


class LedgerNextPatchTests(unittest.TestCase):
    def test_ctl_invest_is_preserved_across_owner_flip(self):
        text = source("Server/AI/Server_CmdTownLedger.sqf")
        self.assertIn("_pendingInvest = _town getVariable [\"wfbe_ctl_pending_invest\", 0];", text)
        self.assertIn("CTL_INVEST_TRANSFER", text)
        self.assertIn("wfbe_ctl_pending_invest_cost", source("Server/FSM/server_town.sqf"))
        self.assertIn("CTL_INVEST_REFUND", source("Server/FSM/server_town.sqf"))

    def test_defender_ledger_multipliers_are_regime_exclusive(self):
        text = source("Server/Functions/Server_GetTownGroupsDefender.sqf")
        self.assertIn("_townSideId == WFBE_C_GUER_ID", text)
        self.assertIn("_townSideId == WFBE_C_WEST_ID", text)

    def test_aicom_funds_null_bail_is_observable(self):
        self.assertIn("AICOMFUNDS|NULL_LOGIK", source("Server/Functions/Server_ChangeAICommanderFunds.sqf"))

    def test_wildcard_bonus_uses_team_funds_chokepoint(self):
        text = source("Server/Functions/AI_Commander_Wildcard.sqf")
        self.assertIn("[_cmdTeam, _bonus] Call WFBE_CO_FNC_ChangeTeamFunds;", text)

    def test_unaffordable_founding_is_debounced(self):
        text = source("Server/AI/Commander/AI_Commander_Teams.sqf")
        self.assertIn("wfbe_aicom_foundskip_warn_t", text)
        self.assertIn("AICOM founding skipped", text)

    def test_ctl_group_budget_is_incremented_in_sweep(self):
        text = source("Server/FSM/server_town_ai.sqf")
        self.assertIn("missionNamespace setVariable [_ctlCacheVar, _ctlCached + _ctlWaveGroups]", text)

    def test_delegated_ctl_credit_uses_the_town_wave_gate(self):
        text = source("Server/Functions/Server_HandleSpecial.sqf")
        self.assertIn('(_town getVariable ["wfbe_ctl_ground_wave", false])', text)
        self.assertIn('{_ctlUnits7 = _ctlUnits7 + (count units _x)} forEach _teams;', text)
        self.assertNotIn('_x getVariable ["wfbe_ctl_ground_wave", false]', text)

    def test_gdir_dead_suppression_field_is_removed(self):
        text = source("Server/AI/Server_GuerDirector.sqf")
        self.assertNotIn("_suppEnd", text)
        self.assertNotIn("_suppressSec", text)
        self.assertNotIn("AICOMV2_GDIR_SUPPRESS_SEC", source("Common/Init/Init_CommonConstants.sqf"))


if __name__ == "__main__":
    unittest.main()
