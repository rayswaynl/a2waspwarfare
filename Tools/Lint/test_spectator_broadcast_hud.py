#!/usr/bin/env python3
"""Static contract for the opt-in Arma 2 OA spectator broadcast HUD."""

from __future__ import annotations

import hashlib
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ROOTS = (
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)
SOURCE = ROOTS[0]
SQF_FILES = (
    "Client/Functions/Client_SpectatorEnter.sqf",
    "Client/Functions/Client_SpectatorExit.sqf",
    "Common/Init/Init_CommonConstants.sqf",
)
CONFIG_FILES = (
    "Rsc/Titles.hpp",
    "Rsc/Dialogs.hpp",
)


def read(root: Path, relative: str) -> str:
    return (root / relative).read_text(encoding="utf-8")


def sha256(root: Path, relative: str) -> str:
    return hashlib.sha256((root / relative).read_bytes()).hexdigest()


def code_without_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    return "\n".join(line.split("//", 1)[0] for line in text.splitlines())


def delimiter_delta(data: str, left: str, right: str) -> int:
    code = code_without_comments(data)
    return code.count(left) - code.count(right)


class SpectatorBroadcastHudContractTests(unittest.TestCase):
    def test_flag_and_config_contract(self) -> None:
        constants = read(SOURCE, "Common/Init/Init_CommonConstants.sqf")
        enter = read(SOURCE, "Client/Functions/Client_SpectatorEnter.sqf")
        titles = read(SOURCE, "Rsc/Titles.hpp")
        dialogs = read(SOURCE, "Rsc/Dialogs.hpp")

        # Owner armed 2026-08-01 (folded via staging wave 2026-08-02): the caster overlay was dark
        # on the h5 stream ("NO OVERLAY") because this still defaulted 0 — deliberate default change.
        self.assertIn(
            'if (isNil "WFBE_C_SPECTATOR_BROADCAST_HUD") then {WFBE_C_SPECTATOR_BROADCAST_HUD = 1}',
            constants,
        )
        self.assertIn("class WFBE_SpectatorBroadcastHud", titles)
        self.assertIn("WFBE_SpectatorBroadcastHud", titles.split("titles[] =", 1)[1])
        self.assertIn("12456 cutRsc [\"WFBE_SpectatorBroadcastHud\"", enter)
        self.assertIn("class WFBE_SpectatorMapDialog", dialogs)
        self.assertIn("class SBH_Map : RscMapControl", dialogs)
        self.assertIn("onMouseButtonDown", dialogs)
        self.assertIn("displayAddEventHandler", dialogs)

    def test_hud_modes_and_free_map_key_are_gated(self) -> None:
        enter = read(SOURCE, "Client/Functions/Client_SpectatorEnter.sqf")

        self.assertIn(
            'if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_BROADCAST_HUD", 0]) > 0) then {',
            enter,
        )
        self.assertIn("WFBE_C_VAR_SpectatorHudMode = 2", enter)
        self.assertIn("case 35: { //--- H: FULL -> MINIMAL -> OFF", enter)
        # v8 rebuild (staging wave 2026-08-02): the cycle uses a namespace-safe read of the mode.
        self.assertIn('WFBE_C_VAR_SpectatorHudMode = ((missionNamespace getVariable ["WFBE_C_VAR_SpectatorHudMode", 2]) + 1) % 3', enter)
        self.assertIn("case 50: { //--- M: open/close spectator map dialog", enter)
        self.assertIn("createDialog \"WFBE_SpectatorMapDialog\"", enter)
        self.assertIn("WFBE_C_VAR_SpectatorHideHint", enter)
        self.assertIn("12455 cutText [_dirCard, \"PLAIN DOWN\", 0]", enter)

    def test_scheduled_spectator_code_has_no_live_serialization_or_hint_calls(self) -> None:
        enter_code = code_without_comments(read(SOURCE, "Client/Functions/Client_SpectatorEnter.sqf"))
        self.assertNotIn("disableSerialization", enter_code)
        self.assertNotIn("hintSilent", enter_code)

    def test_sqf_has_crlf_and_balanced_delimiters(self) -> None:
        for root in ROOTS:
            for relative in SQF_FILES:
                data = (root / relative).read_bytes()
                self.assertEqual(data.count(b"\r\n"), data.count(b"\n"), f"non-CRLF line ending: {root}/{relative}")
                text = data.decode("utf-8")
                self.assertEqual(delimiter_delta(text, "{", "}"), 0, f"brace delta: {root}/{relative}")
                self.assertEqual(delimiter_delta(text, "[", "]"), 0, f"bracket delta: {root}/{relative}")

    def test_feature_files_are_sha256_identical_across_terrains(self) -> None:
        for relative in SQF_FILES + CONFIG_FILES:
            source_hash = sha256(SOURCE, relative)
            for root in ROOTS[1:]:
                self.assertEqual(source_hash, sha256(root, relative), relative)


if __name__ == "__main__":
    unittest.main()
