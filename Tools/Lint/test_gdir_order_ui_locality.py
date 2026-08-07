#!/usr/bin/env python3
"""Regression tests for the GDIR order notification's client-only UI path."""

from __future__ import annotations

import re
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
SOURCES = (
    REPO_ROOT
    / "Missions"
    / "[55-2hc]warfarev2_073v48co.chernarus"
    / "Common"
    / "Init"
    / "Init_PublicVariables.sqf",
    REPO_ROOT
    / "Missions_Vanilla"
    / "[61-2hc]warfarev2_073v48co.takistan"
    / "Common"
    / "Init"
    / "Init_PublicVariables.sqf",
    REPO_ROOT
    / "Missions_Vanilla"
    / "[61-2hc]warfarev2_073v48co.zargabad"
    / "Common"
    / "Init"
    / "Init_PublicVariables.sqf",
)


class GDirOrderUiLocalityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.blocks = {}
        for source in SOURCES:
            text = source.read_text(encoding="utf-8-sig")
            start = text.index("//--- WFBE_C_GDIR_VIS")
            end_marker = text.find("//--- Spectator v8", start)
            end = len(text) if end_marker == -1 else end_marker
            cls.blocks[source] = text[start:end]

    def test_order_handler_is_registered_only_on_interface_machines(self) -> None:
        pattern = re.compile(
            r"if\s*\(\s*hasInterface\s*&&\s*\{!isServer\s*\|\|\s*\{local player\}\}\s*\)\s*then\s*\{\s*"
            r"\"WFBE_GDIR_ORDER_MSG\"\s+addPublicVariableEventHandler\s*\{",
            re.IGNORECASE,
        )
        for source, block in self.blocks.items():
            with self.subTest(source=source):
                self.assertRegex(block, pattern)

    def test_order_handler_waits_for_client_side_before_hint(self) -> None:
        pattern = re.compile(
            r"if\s*\(\s*hasInterface\s*&&\s*\{!isServer\s*\|\|\s*\{local player\}\}\s*\)\s*then\s*\{\s*"
            r"\"WFBE_GDIR_ORDER_MSG\"\s+addPublicVariableEventHandler\s*\{\s*"
            r"if\s*\(!isNil\s+\"sideJoined\"\s*&&\s*\{sideJoined\s*==\s*resistance\}\s*\)\s*then\s*\{hint",
            re.IGNORECASE,
        )
        for source, block in self.blocks.items():
            with self.subTest(source=source):
                self.assertRegex(block, pattern)


if __name__ == "__main__":
    unittest.main()
