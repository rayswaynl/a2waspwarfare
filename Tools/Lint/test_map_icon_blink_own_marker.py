#!/usr/bin/env python3
"""Regression coverage for combat blinking of the visible local-player marker."""

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BLINK_PATHS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Client_BlinkMapIcon.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/Functions/Client_BlinkMapIcon.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Client/Functions/Client_BlinkMapIcon.sqf"),
)
UNIT_MARKER = '_marker = _unit getVariable "unitMarkerBlink";'
LOCAL_PLAYER_GUARD = "if (_unit == player) then {"
OWN_MARKER = '_marker = Format["%1AdvancedSquadOWNMarker",sideJoinedText];'
OWN_COLOR = '_markerColor = "ColorOrange";'


class MapIconBlinkOwnMarkerTests(unittest.TestCase):
    def test_local_player_blinks_the_visible_own_marker(self) -> None:
        for relative_path in BLINK_PATHS:
            text = (ROOT / relative_path).read_text(encoding="utf-8")

            self.assertIn(UNIT_MARKER, text, f"unit marker fallback is missing in {relative_path}")
            self.assertIn(LOCAL_PLAYER_GUARD, text, f"local-player override is missing in {relative_path}")
            self.assertIn(OWN_MARKER, text, f"visible own marker is not selected in {relative_path}")
            self.assertIn(OWN_COLOR, text, f"own-marker restore color is not selected in {relative_path}")
            self.assertLess(text.index(UNIT_MARKER), text.index(LOCAL_PLAYER_GUARD))

    def test_production_mirrors_are_exact_crlf_copies(self) -> None:
        payloads = []
        for relative_path in BLINK_PATHS:
            payload = (ROOT / relative_path).read_bytes()
            self.assertNotIn(b"\n", payload.replace(b"\r\n", b""), f"bare LF found in {relative_path}")
            payloads.append(payload)

        self.assertEqual(payloads[0], payloads[1], "Takistan blink mirror drifted from Chernarus")
        self.assertEqual(payloads[0], payloads[2], "Zargabad blink mirror drifted from Chernarus")


if __name__ == "__main__":
    unittest.main()
