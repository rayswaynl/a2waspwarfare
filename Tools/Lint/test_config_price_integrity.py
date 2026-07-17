#!/usr/bin/env python3
"""Regression checks for faction config and loadout price integrity."""

from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"
MIRRORS = (
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)
CORE = MISSION / "Common" / "Config" / "Core"
GEAR = MISSION / "Common" / "Config" / "Gear"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig")


class ConfigPriceIntegrityTests(unittest.TestCase):
    def test_shared_classnames_have_one_canonical_registration(self) -> None:
        expected = {
            "Mi24_P": "Core_RU.sqf",
            "Ka137_MG_PMC": "Core_PMC.sqf",
            "BVP1_TK_ACR": "Core_TKA.sqf",
        }
        for classname, owner in expected.items():
            registrations = [
                path.name
                for path in CORE.glob("Core_*.sqf")
                if f"['{classname}']" in read(path)
            ]
            with self.subTest(classname=classname):
                self.assertEqual(registrations, [owner])

    def test_core_metadata_has_complete_tuples_and_faction_tags(self) -> None:
        tkciv = read(CORE / "Core_TKCIV.sqf")
        self.assertIn("[['','',50,0,0,0,'Fortification',0,'Takistani Civilians',[]]]", tkciv)
        self.assertIn("[['','',80,0,0,0,'Fortification',0,'Takistani Civilians',[]]]", tkciv)
        self.assertIn("'CDF',[]]]", read(CORE / "Core_CDF.sqf"))
        self.assertIn("'Insurgents',[]]]", read(CORE / "Core_INS.sqf"))

    def test_every_enabled_loadout_weapon_has_a_price_row(self) -> None:
        expected = {
            "Gear_RU.sqf": ("m8_carbine", "m8_carbine_pmc", "m8_carbineGL", "m8_compact", "m8_compact_pmc", "m8_holo_sd", "m8_SAW", "m8_sharpshooter", "m8_tws", "m8_tws_sd", "AA12_PMC", "SMAW"),
            "Gear_GUE.sqf": ("Pecheneg", "Saiga12K", "RPG18", "Igla"),
        }
        for filename, weapons in expected.items():
            text = read(GEAR / filename)
            for weapon in weapons:
                with self.subTest(gear=filename, weapon=weapon):
                    self.assertIn(f'_u = _u + ["{weapon}"]', text)

    def test_guer_counterbattery_has_a_buildable_structure(self) -> None:
        structures = read(MISSION / "Common" / "Config" / "Core_Structures" / "Structures_CO_GUE.sqf")
        self.assertIn('_v = _v\t\t+ ["CBRadar"]', structures)

    def test_chernarus_template_matches_current_release_shape(self) -> None:
        template = read(MISSION / "version.sqf.template")
        self.assertIn("candidate=build89-cmdcon44-20260703", template)
        self.assertIn("#define WF_MAXPLAYERS 55", template)

    def test_config_fixes_are_mirrored_to_both_terrain_copies(self) -> None:
        relatives = (
            Path("Common/Config/Core/Core_CDF.sqf"),
            Path("Common/Config/Core/Core_GUE.sqf"),
            Path("Common/Config/Core/Core_INS.sqf"),
            Path("Common/Config/Core/Core_TKCIV.sqf"),
            Path("Common/Config/Core_Structures/Structures_CO_GUE.sqf"),
            Path("Common/Config/Gear/Gear_GUE.sqf"),
            Path("Common/Config/Gear/Gear_RU.sqf"),
        )
        for relative in relatives:
            source = (MISSION / relative).read_bytes()
            for mirror in MIRRORS:
                with self.subTest(path=relative, mirror=mirror.name):
                    self.assertEqual(source, (mirror / relative).read_bytes())


if __name__ == "__main__":
    unittest.main()
