from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RELATIVE_PATHS = (
    Path(
        "Missions/[55-2hc]warfarev2_073v48co.chernarus/"
        "Client/Functions/Client_BookkeepBlinkingIcons.sqf"
    ),
    Path(
        "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/"
        "Client/Functions/Client_BookkeepBlinkingIcons.sqf"
    ),
    Path(
        "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/"
        "Client/Functions/Client_BookkeepBlinkingIcons.sqf"
    ),
)


def test_bookkeep_group_filter_skips_enemy_groups_without_ending_scan():
    sources = [(ROOT / relative).read_bytes() for relative in RELATIVE_PATHS]
    assert sources[1:] == [sources[0], sources[0]]

    for raw_source in sources:
        source = raw_source.decode("utf-8")
        assert "if (side _x != side player) exitWith {};" not in source
        assert "if (side _x == side player) then {" in source
        assert "        };\n    } forEach clientTeams;" in source
