"""Regression contracts for fold-wave2 antistack mainLoop r2 slices.

Teams.sqf r2 (_perfSliceYield) was NOT folded: origin/master already has
WFBE_C_AICOM_SCAN_CHUNKED scan-chunking on AI_Commander_Teams.sqf which
supersedes that approach. droppeditems_cleaner scanMs split was deferred
(master has evolved _perfDispatched path; non-trivial rebase).
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"


def test_antistack_main_records_active_slices_not_paced_wall_time():
    source = (MISSION / "Server" / "Module" / "AntiStack" / "mainLoop.sqf").read_text(encoding="utf-8")
    assert "_perfActive" in source
    assert "antistack_main_slice" in source
    assert "sliceMaxMs" in source
    assert "PerformanceAudit_Round2" in source
