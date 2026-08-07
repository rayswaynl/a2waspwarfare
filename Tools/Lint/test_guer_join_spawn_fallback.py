from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
INIT_CLIENTS = (
    ROOT
    / "Missions"
    / "[55-2hc]warfarev2_073v48co.chernarus"
    / "Client"
    / "Init"
    / "Init_Client.sqf",
    ROOT
    / "Missions_Vanilla"
    / "[61-2hc]warfarev2_073v48co.takistan"
    / "Client"
    / "Init"
    / "Init_Client.sqf",
    ROOT
    / "Missions_Vanilla"
    / "[61-2hc]warfarev2_073v48co.zargabad"
    / "Client"
    / "Init"
    / "Init_Client.sqf",
)


def test_guer_join_without_friendly_towns_uses_the_safe_start_position():
    """A GUER join must never widen an empty safe-haven list to hostile towns."""
    for source in INIT_CLIENTS:
        text = source.read_text(encoding="utf-8-sig")

        assert 'if (count _fr == 0) then {_fr = towns};' not in text, source
        assert '_base = WFBE_Client_Logic getVariable "wfbe_startpos";' in text, source
        assert (
            'if (isNil "_base") then {_base = getMarkerPos "GuerTempRespawnMarker"};'
            in text
        ), source
