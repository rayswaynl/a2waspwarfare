"""Regression contracts for epoch-scoped delegated town-AI cleanup."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)
CLIENT_CLEANUP = Path("Client") / "Functions" / "Client_CleanupDelegatedTownAI.sqf"
TOWN_AI = Path("Server") / "FSM" / "server_town_ai.sqf"
TOWN_CAPTURE = Path("Server") / "FSM" / "server_town.sqf"


def _assert_in_order(text: str, *needles: str) -> None:
    cursor = -1
    for needle in needles:
        position = text.index(needle, cursor + 1)
        assert position > cursor, "expected source-contract token order was not preserved"
        cursor = position


def test_cleanup_receiver_has_a_narrow_exact_epoch_mode() -> None:
    """Lifecycle teardown must not delete a newer reactivation batch."""
    for mission in MISSIONS:
        text = (mission / CLIENT_CLEANUP).read_text(encoding="utf-8-sig")
        assert '_epochExact = (count _this > 3) && {(_this select 3) == "exact"};' in text
        exact_match = (
            'if (_epochExact) then {_epochMatch = (_entryEpoch == _epochGate)} '
            'else {_epochMatch = (_entryEpoch != _epochGate)};'
        )
        assert text.count(exact_match) == 2


def test_deactivation_targets_the_retired_epoch_before_broadcast() -> None:
    for mission in MISSIONS:
        text = (mission / TOWN_AI).read_text(encoding="utf-8-sig")
        _assert_in_order(
            text,
            '_cleanupEpoch = _town getVariable ["wfbe_town_ai_epoch", 0];',
            '_town setVariable ["wfbe_town_ai_epoch", _cleanupEpoch + 1];',
            '[nil, "HandleSpecial", ["cleanup-townai", _town, _side, _cleanupEpoch, "exact"]]',
        )


def test_capture_targets_the_retired_epoch_before_existing_epoch_bump() -> None:
    for mission in MISSIONS:
        text = (mission / TOWN_CAPTURE).read_text(encoding="utf-8-sig")
        _assert_in_order(
            text,
            '_captureCleanupEpoch = _location getVariable ["wfbe_town_ai_epoch", 0];',
            '_location setVariable ["wfbe_town_ai_epoch", (_location getVariable ["wfbe_town_ai_epoch", 0]) + 1];',
            '[nil, "HandleSpecial", ["cleanup-townai", _location, _side, _captureCleanupEpoch, "exact"]]',
        )


if __name__ == "__main__":
    test_cleanup_receiver_has_a_narrow_exact_epoch_mode()
    test_deactivation_targets_the_retired_epoch_before_broadcast()
    test_capture_targets_the_retired_epoch_before_existing_epoch_bump()
