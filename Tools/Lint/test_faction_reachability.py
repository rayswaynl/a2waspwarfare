#!/usr/bin/env python3
"""Regression tests for terrain-specific faction configuration reachability."""

from __future__ import annotations

import sys
import unittest
from pathlib import PurePosixPath

sys.path.insert(0, str(PurePosixPath(__file__).parent))

import check_faction_reachability


class FactionReachabilityTests(unittest.TestCase):
    def test_takistan_live_factions_are_allowed_in_every_dynamic_config_layer(self) -> None:
        paths = [
            "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/"
            f"Common/Config/{layer}/{prefix}_{faction}.sqf"
            for layer, prefix in (
                ("Core_Root", "Root"),
                ("Defenses", "Defenses"),
                ("Groups", "Groups"),
                ("Core_Artillery", "Artillery"),
            )
            for faction in ("US", "TKA", "TKGUE")
        ]

        self.assertEqual(check_faction_reachability.find_unreachable_paths(paths), [])

    def test_takistan_unreachable_faction_paths_are_reported(self) -> None:
        paths = [
            "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/"
            "Common/Config/Core_Root/Root_RU.sqf",
            "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/"
            "Common/Config/Defenses/Defenses_GUE.sqf",
            "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/"
            "Common/Config/Groups/Groups_CDF.sqf",
            "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/"
            "Common/Config/Core_Artillery/Artillery_USMC.sqf",
        ]

        self.assertEqual(
            check_faction_reachability.find_unreachable_paths(paths),
            paths,
        )

    def test_chernarus_live_factions_are_allowed(self) -> None:
        paths = [
            "Missions/[55-2hc]warfarev2_073v48co.chernarus/"
            "Common/Config/Core_Root/Root_RU.sqf",
            "Missions/[55-2hc]warfarev2_073v48co.chernarus/"
            "Common/Config/Defenses/Defenses_GUE.sqf",
            "Missions/[55-2hc]warfarev2_073v48co.chernarus/"
            "Common/Config/Groups/Groups_USMC.sqf",
        ]

        self.assertEqual(check_faction_reachability.find_unreachable_paths(paths), [])

    def test_zargabad_uses_the_takistan_faction_set(self) -> None:
        live_path = (
            "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/"
            "Common/Config/Core_Root/Root_TKGUE.sqf"
        )
        dead_path = (
            "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/"
            "Common/Config/Core_Artillery/Artillery_RU.sqf"
        )

        self.assertEqual(check_faction_reachability.find_unreachable_paths([live_path]), [])
        self.assertEqual(check_faction_reachability.find_unreachable_paths([dead_path]), [dead_path])

    def test_chain_loaded_second_layer_configs_are_reachable_via_their_loader_faction(self) -> None:
        # Regression guard (#1297 night-fold bounce): CombinedOps artillery (Artillery_CO_*,
        # Artillery_OA_*) and Root_GUE_PlayerOverlay are chain-loaded from a live faction Root,
        # so they must NOT be flagged unreachable on a terrain whose faction loads them.
        chernarus = "Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Config/"
        takistan = "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Config/"
        reachable = [
            # Chernarus (USMC/RU/GUE) loads CO_US via Root_USMC, CO_RU via Root_RU,
            # CO_GUE via Root_GUE, and Root_GUE_PlayerOverlay via Root_GUE.
            chernarus + "Core_Artillery/Artillery_CO_US.sqf",
            chernarus + "Core_Artillery/Artillery_CO_RU.sqf",
            chernarus + "Core_Artillery/Artillery_CO_GUE.sqf",
            chernarus + "Core_Root/Root_GUE_PlayerOverlay.sqf",
            # Takistan/Zargabad (US/TKA/TKGUE) loads CO_US via Root_US, CO_RU/OA_TKA via
            # Root_TKA, CO_GUE/OA_TKGUE via Root_TKGUE, and the overlay via Root_TKGUE.
            takistan + "Core_Artillery/Artillery_CO_US.sqf",
            takistan + "Core_Artillery/Artillery_OA_TKA.sqf",
            takistan + "Core_Artillery/Artillery_OA_TKGUE.sqf",
            takistan + "Core_Root/Root_GUE_PlayerOverlay.sqf",
        ]

        self.assertEqual(check_faction_reachability.find_unreachable_paths(reachable), [])

    def test_chain_loaded_configs_are_still_unreachable_where_no_loader_is_live(self) -> None:
        # OA_TKA / OA_TKGUE are TK/ZG-only (loaded by Root_TKA / Root_TKGUE), so editing them
        # in the Chernarus tree is genuinely unreachable and must still be reported.
        chernarus = "Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Config/"
        dead = [
            chernarus + "Core_Artillery/Artillery_OA_TKA.sqf",
            chernarus + "Core_Artillery/Artillery_OA_TKGUE.sqf",
        ]

        self.assertEqual(check_faction_reachability.find_unreachable_paths(dead), dead)

    def test_non_faction_and_unknown_terrain_paths_are_ignored(self) -> None:
        paths = [
            "Tools/Lint/check_sqf.py",
            "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/"
            "Common/Init/Init_Common.sqf",
            "Missions_Custom/example/Common/Config/Core_Root/Root_RU.sqf",
        ]

        self.assertEqual(check_faction_reachability.find_unreachable_paths(paths), [])


if __name__ == "__main__":
    unittest.main()
