from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCES = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / "Server" / "Init" / "Init_Server.sqf",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan" / "Server" / "Init" / "Init_Server.sqf",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad" / "Server" / "Init" / "Init_Server.sqf",
)


def test_player_team_registration_does_not_reassign_outer_side():
    for source in SOURCES:
        text = source.read_text(encoding="utf-8")
        team_loop_start = text.index('Private ["_group"];', text.index('//--- Groups init.'))
        start = text.index('if(isPlayer (leader (group _x)))then{')
        end = text.index('\n\t\t\t\t\t};', start) + len('\n\t\t\t\t\t};')
        player_block = text[start:end]

        inner_setup = text[team_loop_start:start]
        assert 'Private ["_playerSide"];' in inner_setup
        assert '_playerSide = _side;' in inner_setup
        assert 'Private ["_playerSide"];' not in player_block
        assert '_playerSide = side (leader (group _x));' in player_block
        assert '_side = side (leader (group _x));' not in player_block
        assert 'Team [%2] was initialized.", _playerSide, _group' in text
