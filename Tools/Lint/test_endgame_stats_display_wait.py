from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RELATIVE_PATHS = (
    Path(
        "Missions/[55-2hc]warfarev2_073v48co.chernarus/"
        "Client/GUI/GUI_EndOfGameStats.sqf"
    ),
    Path(
        "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/"
        "Client/GUI/GUI_EndOfGameStats.sqf"
    ),
    Path(
        "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/"
        "Client/GUI/GUI_EndOfGameStats.sqf"
    ),
)


def test_endgame_stats_display_wait_yields_and_fails_closed():
    sources = [(ROOT / relative).read_bytes() for relative in RELATIVE_PATHS]
    assert sources[1:] == [sources[0], sources[0]]

    for raw_source in sources:
        source = raw_source.decode("utf-8")
        deadline = "_cutWaitDeadline = diag_tickTime + 5;"
        wait = (
            "waitUntil {sleep 0.05; !isNull ([\"currentCutDisplay\"] call BIS_FNC_GUIget) "
            "|| diag_tickTime > _cutWaitDeadline};"
        )
        null_guard = "if (isNull _cutDisp) exitWith {};"

        assert "waitUntil {!isNull ([\"currentCutDisplay\"] call BIS_FNC_GUIget)};" not in source
        assert deadline in source
        assert wait in source
        assert source.index(deadline) < source.index(wait) < source.index(null_guard)
