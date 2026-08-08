"""Regression contracts for the Arma 2 aircraft HandleDamage chain."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
TERRAIN_ROOTS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)


def read(terrain: Path, *parts: str) -> str:
    return (terrain.joinpath(*parts)).read_text(encoding="utf-8")


class JetDamageCompositionTests(unittest.TestCase):
    def test_jet_handler_is_centralized_at_vehicle_creation(self) -> None:
        source = read(
            TERRAIN_ROOTS[0], "Common", "Functions", "Common_CreateVehicle.sqf"
        )
        self.assertIn("HandleJetAADamage", source)
        modify_air = source.index("WFBE_CO_FNC_ModifyAirVehicle")
        jet_handler = source.index("HandleJetAADamage")
        self.assertGreater(jet_handler, modify_air)
        self.assertIn(
            'if (_vehicle isKindOf "Plane" && (missionNamespace getVariable '
            '["WFBE_C_JET_AA_SURVIVE", 1]) > 0) then {',
            source,
        )

    def test_buy_paths_do_not_add_a_second_vehicle_handle_damage_handler(self) -> None:
        for terrain in TERRAIN_ROOTS:
            for relative in (
                ("Client", "Functions", "Client_BuildUnit.sqf"),
                ("Server", "Functions", "Server_BuyUnit.sqf"),
            ):
                source = read(terrain, *relative)
                self.assertNotIn("HandleJetAADamage", source)

    def test_jet_handler_composes_generated_air_to_air_rearmor(self) -> None:
        source = read(
            TERRAIN_ROOTS[0], "Common", "Functions", "Common_JetAADamage.sqf"
        )
        self.assertIn('getVariable ["wfbe_air_aa_rearmor", false]', source)
        self.assertIn('"M_R73_AA"', source)
        self.assertIn('"M_Sidewinder_AA"', source)
        self.assertIn("_result = (_result / 100) * 99", source)

    def test_generated_air_rearmor_defers_to_central_jet_handler(self) -> None:
        for terrain in TERRAIN_ROOTS:
            source = read(
                terrain, "Common", "Functions", "Common_ModifyAirVehicle.sqf"
            )
            self.assertIn(
                '_vehicle setVariable ["wfbe_air_aa_rearmor", true, true];',
                source,
            )
            self.assertIn(
                'missionNamespace getVariable ["WFBE_C_JET_AA_SURVIVE", 1]) <= 0',
                source,
            )


if __name__ == "__main__":
    unittest.main()
