#!/usr/bin/env python3
"""Regression checks for ICBM TEL runtime object-state replication."""

from __future__ import annotations

import re
import unittest
from pathlib import Path

from check_sqf import mask_comments


ROOT = Path(__file__).resolve().parents[2]
MAINTAINED_ROOTS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)

TEL_INIT = Path("Server/Init/Init_IcbmTel.sqf")
ON_CONNECTED = Path("Server/Functions/Server_OnPlayerConnected.sqf")


def read(root: Path, relative: Path) -> str:
    return (root / relative).read_text(encoding="utf-8-sig")


class IcbmTelRuntimeStateSyncTests(unittest.TestCase):
    def test_runtime_tel_state_is_broadcast_after_each_mutation(self) -> None:
        required = (
            r"missionNamespace setVariable \[_key, _tel\];\s*publicVariable _key;",
            r"missionNamespace setVariable \[Format \[\"WFBE_ICBM_TEL_%1\", _dSideText\], objNull\];\s*publicVariable \(Format \[\"WFBE_ICBM_TEL_%1\", _dSideText\]\);",
            r"missionNamespace setVariable \[_key, _live\];\s*publicVariable _key(?:;|\s*\})",
            r"missionNamespace setVariable \[_key, _arr\];\s*publicVariable _key;",
            r"missionNamespace setVariable \[_dKey, _dLive\];\s*publicVariable _dKey;",
        )
        for root in MAINTAINED_ROOTS:
            source = mask_comments(read(root, TEL_INIT))
            for pattern in required:
                with self.subTest(root=root, pattern=pattern):
                    self.assertRegex(source, pattern)

    def test_jip_joiner_receives_its_side_tel_and_scud_state(self) -> None:
        for root in MAINTAINED_ROOTS:
            source = mask_comments(read(root, ON_CONNECTED))
            with self.subTest(root=root):
                self.assertIn('Format ["WFBE_ICBM_TEL_%1", str _sideJoined]', source)
                self.assertIn('Format ["WFBE_TK_SCUD_PLATFORMS_%1", str _sideJoined]', source)
                self.assertIn('_id publicVariableClient _telJipKey', source)
                self.assertIn('_id publicVariableClient _scudJipKey', source)

    def test_nuke_countdown_uses_the_shared_absolute_impact_deadline(self) -> None:
        for root in MAINTAINED_ROOTS:
            source = mask_comments(read(root, TEL_INIT))
            with self.subTest(root=root):
                self.assertRegex(
                    source,
                    r'_deadline\s*=\s*time\s*\+\s*_secs;\s*'
                    r'missionNamespace setVariable \[_cdKey, _deadline\];\s*'
                    r'\[nil, "HandleSpecial", \["icbm-countdown", time, _deadline\]\]',
                )
                self.assertRegex(
                    source,
                    r'while\s*\{\s*time\s*<\s*_deadline\s*\}\s*do\s*\{\s*sleep 1;',
                )
                self.assertNotIn('_steps', source)

    def test_tel_replacement_retries_until_an_hq_exists_or_the_match_ends(self) -> None:
        for root in MAINTAINED_ROOTS:
            source = mask_comments(read(root, TEL_INIT))
            with self.subTest(root=root):
                self.assertRegex(
                    source,
                    r'(?s)WFBE_SE_FNC_ScheduleIcbmTelRespawn\s*=\s*\{.*?'
                    r'while\s*\{\s*!WFBE_GameOver\s*&&\s*\{isNull _tel\}\s*\}\s*do\s*\{.*?'
                    r'_tel\s*=\s*\[_rs\]\s*Call\s*WFBE_SE_FNC_SpawnIcbmTel;.*?'
                    r'if\s*\(isNull _tel\s*&&\s*\{!WFBE_GameOver\}\)\s*then\s*\{.*?sleep 30;',
                )
                self.assertIn('[_dSide] Call WFBE_SE_FNC_ScheduleIcbmTelRespawn;', source)
                self.assertRegex(source, r'\[_side\] Call WFBE_SE_FNC_ScheduleIcbmTelRespawn\s*\}')


if __name__ == "__main__":
    unittest.main()
