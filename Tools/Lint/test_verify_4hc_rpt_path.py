"""Static contract for the 4HC verifier's server-RPT path.

The verifier runs on the Windows host, where ArmA 2 OA writes the dedicated
server RPT under the service account's USERPROFILE.  The profile directory
passed to the server with -profiles is not the RPT location on the live box.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
VERIFY = ROOT / "server-config" / "provision" / "Verify-4HC.ps1"
START = ROOT / "server-config" / "provision" / "Start-Wasp-4HC.ps1"


def test_verifier_exposes_the_same_server_rpt_default_as_the_launcher():
    verify = VERIFY.read_text(encoding="utf-8")
    start = START.read_text(encoding="utf-8")
    default = '[String]$ServerRpt = "$env:USERPROFILE\\AppData\\Local\\ArmA 2 OA\\arma2oaserver.RPT"'

    assert default in start
    assert default in verify


def test_verifier_reads_the_explicit_server_rpt_instead_of_profiles_directory_scan():
    verify = VERIFY.read_text(encoding="utf-8")

    assert "$rpt = Get-Item -LiteralPath $ServerRpt -ErrorAction SilentlyContinue" in verify
    assert "Join-Path $WaspDir 'profiles-pr8'" not in verify
    assert "Get-ChildItem -LiteralPath $rptDir -Filter '*.RPT'" not in verify


if __name__ == "__main__":
    test_verifier_exposes_the_same_server_rpt_default_as_the_launcher()
    test_verifier_reads_the_explicit_server_rpt_instead_of_profiles_directory_scan()
