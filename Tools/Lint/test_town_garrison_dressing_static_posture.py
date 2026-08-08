from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION = "Missions/[55-2hc]warfarev2_073v48co.chernarus"


def test_dressing_zu23_gunner_is_postured_after_a_successful_seat():
    source = (ROOT / MISSION / "Server/Server_TownGarrisonDressing.sqf").read_text(
        encoding="utf-8-sig"
    )

    seated = source.index("if (_gunnerSeated) then {")
    disabled_move = source.index('_crew disableAI "MOVE";', seated)
    aware = source.index('_grp setBehaviour "AWARE";', disabled_move)
    red = source.index('_grp setCombatMode "RED";', aware)
    searchlight = source.index("//--- Optional night searchlight.", red)

    assert seated < disabled_move < aware < red < searchlight
