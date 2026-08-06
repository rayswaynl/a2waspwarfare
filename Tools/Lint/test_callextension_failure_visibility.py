"""Regression contracts for the database callExtension failure boundary.

These checks inspect SQF source text because the Arma 2 runtime is not available to
pytest.  The contract keeps the existing neutral return value, but requires the
mission to report an invalid native response instead of logging success first.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SEND_PLAYER_LIST = (
    ROOT
    / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Module/AntiStack/"
    / "callDatabaseSendPlayerList.sqf"
)


def test_send_player_list_validates_the_native_response_before_success_logging():
    source = SEND_PLAYER_LIST.read_text(encoding="utf-8")
    compiled = source.index("_response = call compile _response;")
    response_code = source.index("_responseCode = _response select 0;")
    success_log = source.index(
        "CallDatabaseSendPlayerList.sqf: Called database successfully"
    )

    assert compiled < response_code < success_log


def test_send_player_list_reports_empty_or_invalid_native_responses():
    source = SEND_PLAYER_LIST.read_text(encoding="utf-8")
    guard_start = source.index("//--- task46")
    guard_end = source.index("};", guard_start) + 2
    guard = source[guard_start:guard_end]

    assert '["ERROR",' in guard
    assert "invalid or empty response" in guard
    assert "\n\t1\n" in guard
