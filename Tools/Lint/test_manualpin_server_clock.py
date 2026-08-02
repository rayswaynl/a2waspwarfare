from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = [
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
]


class ManualPinServerClockTests(unittest.TestCase):
    def test_client_requests_authoritative_manual_pin_without_publishing_its_clock(self):
        for mission in MISSIONS:
            source = (mission / "Client" / "GUI" / "GUI_Menu_Command.sqf").read_text(encoding="utf-8")
            self.assertNotIn(
                'setVariable ["wfbe_aicom_manualpin", time, true]', source
            )
            requests = re.findall(
                r'\["RequestSpecial", \["aicom-manualpin", sideJoined, [^\]]+, player\]\] Call WFBE_CO_FNC_SendToServer',
                source,
            )
            self.assertEqual(2, len(requests), mission.name)

    def test_server_validates_commander_then_stamps_manual_pin_with_server_time(self):
        for mission in MISSIONS:
            source = (mission / "Server" / "Functions" / "Server_HandleSpecial.sqf").read_text(encoding="utf-8")
            self.assertIn('case "aicom-manualpin": {', source)
            self.assertIn('_mpAuth = (!isNull _mpPlayer) && {alive _mpPlayer} && {isPlayer _mpPlayer}', source)
            self.assertIn('_mpTeam setVariable ["wfbe_aicom_manualpin", time, true];', source)


if __name__ == "__main__":
    unittest.main()
