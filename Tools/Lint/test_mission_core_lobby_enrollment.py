"""Regression contract for denied join enrollment ordering."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TERRAINS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)
REQUEST_JOIN = Path("Server/PVFunctions/RequestJoin.sqf")
PLAYER_CONNECTED = Path("Server/Functions/Server_OnPlayerConnected.sqf")
DECISION_KEY = "WFBE_CONNECT_JOIN_DECISION_"


def test_denied_join_is_decided_before_server_enrollment_stamps_identity() -> None:
    """A lobby-denied client must not be enrolled by the parallel connect handler."""

    for terrain in TERRAINS:
        request_source = (ROOT / terrain / REQUEST_JOIN).read_text(encoding="utf-8")
        connected_source = (ROOT / terrain / PLAYER_CONNECTED).read_text(encoding="utf-8")

        assert DECISION_KEY in request_source, f"{terrain}: join decision key is not published"
        assert "[_pendingId, _side, _canJoin]" in request_source, (
            f"{terrain}: join decision does not bind to the current connection"
        )
        assert "if (_pendingId < 0) then {_pendingId = owner _player};" in request_source, (
            f"{terrain}: join decision has no object-owner fallback"
        )
        assert DECISION_KEY in connected_source, f"{terrain}: connect handler does not read join decision"
        assert "!(_joinDecision select 2)" in connected_source, (
            f"{terrain}: denied join does not stop enrollment"
        )

        connection_binding = connected_source.index("missionNamespace setVariable [_connectKey, _id];")
        denial = connected_source.index("!(_joinDecision select 2)")
        stamp_on_demand = connected_source.index('setVariable ["wfbe_side", _sod_side]')
        uid_stamp = connected_source.index('setVariable ["wfbe_uid", _uid]')
        leader_stamp = connected_source.index('setVariable ["wfbe_teamleader", leader _team]')
        assert connection_binding < denial < stamp_on_demand < uid_stamp < leader_stamp, (
            f"{terrain}: denial gate must precede all enrollment-side mutations"
        )


if __name__ == "__main__":
    test_denied_join_is_decided_before_server_enrollment_stamps_identity()
    print("mission-core lobby enrollment regression check passed")
