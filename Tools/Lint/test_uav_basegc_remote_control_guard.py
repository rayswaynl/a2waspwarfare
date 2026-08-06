#!/usr/bin/env python3
"""Regression contract for player-directed UAV BASE-GC protection."""

from pathlib import Path
import re
import unittest

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
MAINTAINED_ROOTS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)

UAV_SERVER = Path("Server/Support/Support_UAV.sqf")
GROUPS_GC = Path("Server/FSM/server_groupsGC.sqf")
PLAYER_UAV_MARKER = "wfbe_server_player_uav"
CREATE = "_uav = createVehicle"
HANDOFF = '"uav-created"'
BASE_GC_START = "// ============ (ii) IDLE CREWED HELI/ARMOR AT BASE (delete only) ============"
BASE_GC_END = "// --- Orphaned-team zombie reaper ---"


class UavBaseGcRemoteControlTests(unittest.TestCase):
    def test_server_tags_player_uav_before_client_handoff(self) -> None:
        for mission in MAINTAINED_ROOTS:
            with self.subTest(mission=mission.name):
                code = mask_comments((mission / UAV_SERVER).read_text(encoding="utf-8-sig"))
                create = code.index(CREATE)
                self.assertIn(PLAYER_UAV_MARKER, code)
                marker = code.index(PLAYER_UAV_MARKER)
                handoff = code.index(HANDOFF)
                self.assertIn(
                    f'_uav setVariable ["{PLAYER_UAV_MARKER}", true]',
                    code,
                )
                self.assertLess(create, marker)
                self.assertLess(marker, handoff)

    def test_base_gc_skips_tagged_player_uav_before_idle_delete_predicate(self) -> None:
        expected_guard = f'!(_baseVeh getVariable ["{PLAYER_UAV_MARKER}", false])'
        for mission in MAINTAINED_ROOTS:
            with self.subTest(mission=mission.name):
                source_text = (mission / GROUPS_GC).read_text(encoding="utf-8-sig")
                self.assertIn(BASE_GC_START, source_text)
                self.assertIn(BASE_GC_END, source_text)
                cleanup = mask_comments(
                    source_text[source_text.index(BASE_GC_START) : source_text.index(BASE_GC_END)]
                )
                self.assertRegex(
                    cleanup,
                    re.compile(
                        rf'_baseVside == _baseSide.*?{re.escape(expected_guard)}.*?'
                        r'\(_baseVeh distance _baseHQ\)',
                        re.DOTALL,
                    ),
                )


if __name__ == "__main__":
    unittest.main()
