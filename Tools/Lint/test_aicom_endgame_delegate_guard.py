from pathlib import Path


MISSION = Path(__file__).resolve().parents[2] / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"


def test_chunked_founding_rechecks_gameover_before_commit():
    source = (MISSION / "Server" / "AI" / "Commander" / "AI_Commander_Teams.sqf").read_text(encoding="utf-8")
    final_yield = source.rfind("Call _sliceYield;")
    assert final_yield >= 0
    commit = source.index("[_side, -_price] Call ChangeAICommanderFunds", final_yield)
    assert "if (gameOver) exitWith {};" in source[final_yield:commit]


def test_delegated_team_creation_rejects_completed_round():
    source = (MISSION / "Common" / "Functions" / "Common_RunCommanderTeam.sqf").read_text(encoding="utf-8")
    create_group = source.index('[_side, "aicom"] Call WFBE_CO_FNC_CreateGroup')
    assert "if (gameOver || {WFBE_GameOver}) exitWith {};" in source[:create_group]
