from pathlib import Path
import unittest


MISSION = (
    Path(__file__).resolve().parents[2]
    / "Missions"
    / "[55-2hc]warfarev2_073v48co.chernarus"
)


class Rm70ArtilleryAmmoGateTests(unittest.TestCase):
    def test_fire_gate_uses_actual_vehicle_ammunition(self):
        source = (
            MISSION / "Common" / "Functions" / "Common_GetTeamArtillery.sqf"
        ).read_text(encoding="utf-8")

        self.assertRegex(source, r"if \(_ignoreAmmo \|\| \(someAmmo _vehicle\)\) then")
        self.assertNotIn("_vehicle ammo _weapon > 0", source)

    def test_rm70_remains_a_distinct_grad_family_for_both_sides(self):
        for filename in ("Artillery_CO_RU.sqf", "Artillery_CO_US.sqf"):
            source = (
                MISSION / "Common" / "Config" / "Core_Artillery" / filename
            ).read_text(encoding="utf-8")

            self.assertIn("['RM70_ACR']", source)
            self.assertIn("['R_GRAD']", source)
            self.assertIn("ARTILLERY_CLASSNAMES", source)


if __name__ == "__main__":
    unittest.main()
