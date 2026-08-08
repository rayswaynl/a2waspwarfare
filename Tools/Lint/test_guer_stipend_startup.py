"""Regression coverage for the GUER economy startup dependency wait."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
STIPEND = (
    ROOT
    / "Missions"
    / "[55-2hc]warfarev2_073v48co.chernarus"
    / "Server"
    / "Server_GuerStipend.sqf"
)


def test_guer_stipend_startup_wait_yields_and_fails_closed() -> None:
    """A missing town/logic dependency must not leave a permanent worker behind."""
    source = STIPEND.read_text(encoding="utf-8-sig")

    assert "_startupStarted = diag_tickTime;" in source
    assert "_startupDeadline = _startupStarted + 300;" in source
    assert "sleep 0.25;" in source
    assert "diag_log format [\"GUERSTIPEND|ABORT|STARTUP_TIMEOUT" in source
    assert "if (" in source
    assert "isNil \"towns\"" in source
    assert "isNil \"WFBE_L_GUE\"" in source


if __name__ == "__main__":
    test_guer_stipend_startup_wait_yields_and_fails_closed()
