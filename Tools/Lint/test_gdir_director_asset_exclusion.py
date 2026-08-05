import pathlib
import unittest


REPO = pathlib.Path(__file__).resolve().parents[2]
MISSION_ROOTS = (
    REPO / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    REPO / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    REPO / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)


class GuerDirectorAssetExclusionTests(unittest.TestCase):
    def test_director_census_excludes_independent_naval_assets(self):
        for mission_root in MISSION_ROOTS:
            with self.subTest(mission_root=mission_root.name):
                director = (mission_root / "Server" / "AI" / "Server_GuerDirector.sqf").read_text(
                    encoding="utf-8"
                )
                flotilla = (mission_root / "Server" / "Server_USVFlotilla.sqf").read_text(
                    encoding="utf-8"
                )

                self.assertIn('!([_x, "wfbe_naval_cap", false] Call WFBE_CO_FNC_GroupGetBool)', director)
                self.assertIn('!([_x, "wfbe_usv_flotilla", false] Call WFBE_CO_FNC_GroupGetBool)', director)
                self.assertIn('_grp setVariable ["wfbe_usv_flotilla", true, true];', flotilla)


if __name__ == "__main__":
    unittest.main()
