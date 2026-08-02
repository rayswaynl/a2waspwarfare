"""Regression contract for active allocator selection in the provision readiness gate."""

from __future__ import annotations

import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
READY_CHECK = ROOT / "server-config/provision/Ready-Check.ps1"


def test_ready_check_selftest_exercises_allocator_token_parser() -> None:
    result = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(READY_CHECK),
            "-SelfTest",
        ],
        capture_output=True,
        text=True,
        check=False,
    )

    assert result.returncode == 0, result.stdout + result.stderr
    assert "SELFTEST: PASS" in result.stdout
    assert "allocator parser: REM comment" in result.stdout
    assert "allocator parser: quoted text" in result.stdout


def test_ready_check_wires_expected_allocator_tokens_to_required_launchers() -> None:
    source = READY_CHECK.read_text(encoding="utf-8-sig")

    assert "function Get-MallocTokenFromText" in source
    assert "function Get-MallocToken" in source
    assert "[ValidateRange(1, 4)][Int]$HcCount = 4" in source
    assert "for ($i = 1; $i -lt $launchers.Count; $i++)" in source
    assert "Check-Malloc $serverLauncher 'mimalloc'" in source
    assert "Check-Malloc (Join-Path 'C:\\WASP' $launchers[$i]) 'tbb4malloc_bi'" in source
