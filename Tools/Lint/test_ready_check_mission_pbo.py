"""Static contract for Ready-Check's configured mission PBO selection.

The readiness gate must follow the mission template in the box's server config,
because the active terrain/build can change without changing the checker.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
READY_CHECK = ROOT / "server-config" / "provision" / "Ready-Check.ps1"


def test_ready_check_accepts_an_explicit_mission_pbo_override():
    source = READY_CHECK.read_text(encoding="utf-8")

    assert "[String]$MissionPbo = ''" in source
    assert "$MissionPboOverride" in source
    assert "MissionPboOverride $MissionPbo" in source


def test_ready_check_derives_pbo_from_server_template():
    source = READY_CHECK.read_text(encoding="utf-8")

    assert "Get-Content -LiteralPath $ConfigPath" in source
    assert "template\\s*=\\s*\"([^\"]+)\"" in source
    assert 'Join-Path $MissionRoot ("{0}.pbo" -f $template)' in source
    assert "wave0725c4hc.zargabad.pbo" not in source


def test_ready_check_keeps_bracket_safe_literal_path_probe():
    source = READY_CHECK.read_text(encoding="utf-8")

    assert "function TP" in source
    assert "Test-Path -LiteralPath $Path" in source
    assert "C (TP $missionPboPath)" in source


if __name__ == "__main__":
    test_ready_check_accepts_an_explicit_mission_pbo_override()
    test_ready_check_derives_pbo_from_server_template()
    test_ready_check_keeps_bracket_safe_literal_path_probe()
