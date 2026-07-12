#!/usr/bin/env python3

from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ALLOCATE_PATHS = (
    ROOT
    / "Missions"
    / "[55-2hc]warfarev2_073v48co.chernarus"
    / "Server"
    / "AI"
    / "Commander"
    / "AI_Commander_Allocate.sqf",
    ROOT
    / "Missions_Vanilla"
    / "[61-2hc]warfarev2_073v48co.takistan"
    / "Server"
    / "AI"
    / "Commander"
    / "AI_Commander_Allocate.sqf",
    ROOT
    / "Missions_Vanilla"
    / "[61-2hc]warfarev2_073v48co.zargabad"
    / "Server"
    / "AI"
    / "Commander"
    / "AI_Commander_Allocate.sqf",
)

TRACK_NEAREST = (
    "if (_ev < _expandWarnDist) then "
    "{_expandWarnDist = _ev; _expandWarnTown = _x}"
)
WARN_GUARD = (
    "if (_expandN > 0 && {_expandCount == 0} && "
    "{(count _neutTowns) > 0} && {!isNull _expandWarnTown}) then {"
)
WARN_TOKEN = "AICOM2|WARN|EXPAND_UNREACHABLE|"


class AicomExpandUnreachableLogTests(unittest.TestCase):
    def test_unreachable_expansion_warning_is_tracked_and_guarded(self) -> None:
        sources = [path.read_text(encoding="utf-8") for path in ALLOCATE_PATHS]

        for path, source in zip(ALLOCATE_PATHS, sources):
            with self.subTest(path=path):
                self.assertIn('"_expandWarnTown","_expandWarnDist"', source)
                self.assertIn(
                    "_expandWarnTown = objNull; _expandWarnDist = 1e9;",
                    source,
                )
                self.assertEqual(source.count(TRACK_NEAREST), 2)
                self.assertEqual(source.count(WARN_GUARD), 1)
                self.assertEqual(source.count(WARN_TOKEN), 1)

        self.assertEqual(sources[1:], [sources[0], sources[0]])


if __name__ == "__main__":
    unittest.main()
