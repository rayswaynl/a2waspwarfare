from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"


def _source(relative_path: str) -> str:
    return (MISSION / relative_path).read_text(encoding="utf-8")


def test_dead_player_requests_are_rejected_before_state_mutation():
    cases = {
        "Server/PVFunctions/RequestUpgrade.sqf": "_logic setVariable [\"wfbe_upgrading\", true, true]",
        "Server/PVFunctions/RequestAutoWallConstructinChange.sqf": "missionNamespace setVariable [Format[\"WFBE_AUTOWALL_%1\", _side]",
        "Server/PVFunctions/RequestCancelQueue.sqf": "_building setVariable [\"queu\", _queu, true]",
    }

    for relative_path, mutation in cases.items():
        source = _source(relative_path)
        live_guard = "!alive _requester" if "RequestUpgrade" in relative_path else "!alive _player"
        assert live_guard in source
        assert source.index(live_guard) < source.index(mutation)
