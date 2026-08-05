"""Static contract for the configurable 1-4 HC start path.

The provisioning README promises that Start-Wasp-4HC.ps1 accepts -HcCount.
The script launches Windows processes, so this contract pins the parameter and
the two downstream consumers without starting a server in CI.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
START = ROOT / "server-config" / "provision" / "Start-Wasp-4HC.ps1"
README = ROOT / "server-config" / "provision" / "README.md"


def test_start_hccount_drives_launcher_selection():
    source = START.read_text(encoding="utf-8")

    assert "[ValidateRange(1, 4)][Int]$HcCount = 4" in source
    assert "foreach ($n in 1..$HcCount)" in source
    assert "foreach ($n in 1..4)" not in source


def test_start_hccount_is_forwarded_to_affinity_and_status_output():
    source = START.read_text(encoding="utf-8")

    assert "& (Join-Path $here 'Set-WaspAffinity.ps1') -HcCount $HcCount" in source
    assert "Not all 5 processes were pinned" not in source
    assert "(1 + $HcCount)" in source


def test_runbook_and_affinity_contract_share_the_same_hccount_range():
    readme = README.read_text(encoding="utf-8")

    assert "every script" in readme
    assert "-HcCount 1..4" in readme
    assert "Start-Wasp-4HC.ps1 -HcCount 4" in readme


if __name__ == "__main__":
    test_start_hccount_drives_launcher_selection()
    test_start_hccount_is_forwarded_to_affinity_and_status_output()
    test_runbook_and_affinity_contract_share_the_same_hccount_range()
