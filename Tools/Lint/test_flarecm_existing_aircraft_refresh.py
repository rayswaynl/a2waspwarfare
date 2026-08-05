from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
PROCESS = ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/Server_ProcessUpgrade.sqf"
REFRESH = ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_RefreshAirCountermeasures.sqf"
INIT = ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_Common.sqf"


class FlareCMExistingAircraftRefreshTests(unittest.TestCase):
    def test_flare_upgrade_refreshes_existing_owned_aircraft(self):
        source = PROCESS.read_text(encoding="utf-8")
        self.assertIn("_upgrade_id == WFBE_UP_FLARESCM", source)
        self.assertIn('"wfbe_side_id"', source)
        self.assertIn("WFBE_CO_FNC_RefreshAirCountermeasures", source)

    def test_refresh_is_registered_and_idempotent(self):
        source = REFRESH.read_text(encoding="utf-8")
        init = INIT.read_text(encoding="utf-8")
        self.assertIn("WFBE_CO_FNC_RefreshAirCountermeasures", init)
        self.assertIn('"wfbe_flarecm_refresh_done"', source)
        self.assertIn("addEventHandler", source)


if __name__ == "__main__":
    unittest.main()
