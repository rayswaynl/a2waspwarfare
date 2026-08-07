"""Static contract checks for aggregate AICOM no-progress telemetry."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCE = (
    ROOT
    / "Missions"
    / "[55-2hc]warfarev2_073v48co.chernarus"
    / "Server"
    / "AI"
    / "Commander"
    / "AI_Commander.sqf"
)


def test_supervisor_emits_bounded_no_progress_event_after_eligible_windows() -> None:
    source = SOURCE.read_text(encoding="utf-8")

    assert "WFBE_C_AICOM_NO_PROGRESS_WINDOWS" in source
    assert "wfbe_aicom_noprogress_windows" in source
    assert "NO_PROGRESS" in source
    assert "_npEligible" in source
    assert "_npOpen == 0" in source


def test_no_progress_state_resets_when_existing_activity_is_observed() -> None:
    source = SOURCE.read_text(encoding="utf-8")

    assert "_npChanged" in source
    assert "_npEvents > 0" in source
    assert 'setVariable ["wfbe_aicom_noprogress_windows", 0]' in source
