"""Regression contract for the HC town-delegation concurrency ceiling."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DELEGATE = ROOT / (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/"
    "Client/Functions/Client_DelegateTownAI.sqf"
)


def test_full_hc_creation_limit_queues_instead_of_bypassing_after_ten_seconds() -> None:
    """A long-running batch must retain the cap; queued work may only end at round end."""
    text = DELEGATE.read_text(encoding="utf-8-sig")

    assert 'while {(missionNamespace getVariable ["WFBE_HC_DELEG_INFLIGHT", 0]) >= 3} do {' in text
    assert "_qWait" not in text
    assert "queueing town delegation" in text
    assert text.index('while {(missionNamespace getVariable ["WFBE_HC_DELEG_INFLIGHT", 0]) >= 3} do {') < text.index(
        'if (missionNamespace getVariable ["WFBE_GameOver", false]) exitWith {'
    )
