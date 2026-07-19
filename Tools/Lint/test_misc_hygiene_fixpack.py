import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"


def source(relative_path):
    return (MISSION / relative_path).read_text(encoding="utf-8")


class MiscHygieneFixpackTests(unittest.TestCase):
    def test_topup_requests_refund_the_original_charge_when_stale(self):
        producer = source("Server/AI/Commander/AI_Commander_Produce.sqf")
        consumer = source("Common/Functions/Common_RunCommanderTeam.sqf")
        self.assertIn("_wm_infCls, _wm_now, _wm_charge", producer)
        self.assertIn("_topCharge = _topReq select 4", consumer)
        self.assertIn("[_side, _topCharge] Call ChangeAICommanderFunds;", consumer)
        self.assertIn("TOPUP_REQ_STALE_REFUND", consumer)

    def test_topup_missing_classlist_is_observable(self):
        text = source("Server/AI/Commander/AI_Commander_Produce.sqf")
        self.assertIn("TOPUP_REQ skipped: no infantry class", text)
        warning = (
            '["WARNING", Format ["AI_Commander_Produce.sqf: [%1] team [%2] '
            "TOPUP_REQ skipped: no infantry class resolved from barracks roster."
        )
        warning_index = text.index(warning)
        warning_window = text[warning_index - 80 : warning_index + len(warning) + 240]
        self.assertIn(
            "\t\t\t\t\t\t} else {\n\t\t\t\t\t\t\t" + warning,
            warning_window,
        )
        self.assertIn(
            "Call WFBE_CO_FNC_AICOMLog;\n\t\t\t\t\t\t};\n\t\t\t\t\t};",
            warning_window,
        )

    def test_supply_mission_rejects_a_missing_friendly_town(self):
        text = source("Client/Module/supplyMission/supplyMissionStart.sqf")
        self.assertIn("if (isNull _sourceTown) exitWith", text)

    def test_dead_officer_skill_and_ledger_timestamp_are_removed(self):
        self.assertNotIn("case 'Officer'", source("Client/Module/Skill/Skill_Apply.sqf"))
        ledger = source("Server/AI/Server_CmdTownLedger.sqf")
        self.assertNotIn("investT0", ledger)
        self.assertNotIn("_recP set [4, time];", ledger)

    def test_init_hygiene_uses_safe_defaults_and_actual_watchdog_duration(self):
        client_init = source("Client/Init/Init_Client.sqf")
        server_init = source("Server/Init/Init_Server.sqf")
        self.assertIn("90 seconds", client_init)
        self.assertIn('missionNamespace getVariable ["WFBE_WEST_PRESENT", false]', server_init)
        self.assertIn('getNumber (configFile >> "CfgWorlds" >> worldName >> "mapSize")', server_init)
        self.assertIn('(typeName _rpavg185) != "ARRAY"', server_init)


if __name__ == "__main__":
    unittest.main()
