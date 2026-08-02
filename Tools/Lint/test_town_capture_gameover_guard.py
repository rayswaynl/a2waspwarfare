from pathlib import Path


SOURCE = Path(__file__).parents[2] / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / "Server" / "FSM" / "server_town.sqf"


def test_town_capture_completion_does_not_run_after_game_over():
    source = SOURCE.read_text(encoding="utf-8-sig")

    assert "if(_captured && !WFBE_GameOver) then {" in source, (
        "town capture completion must be gated when the round has already ended"
    )
