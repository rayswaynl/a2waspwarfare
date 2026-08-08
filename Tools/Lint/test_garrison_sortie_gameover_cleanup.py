from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)


def _read(mission: str) -> str:
    return (ROOT / mission / "Server/Server_GarrisonSortie.sqf").read_text(
        encoding="utf-8-sig"
    )


def test_gameover_finalizer_reclaims_non_player_sortie_units_after_main_loop():
    for mission in MISSIONS:
        source = _read(mission)
        loop = source.index("while {!WFBE_GameOver} do {")
        marker = source.index(
            'GARSORTIE|DESPAWN|town=%1|reason=game_over|remainingPlayers=%2'
        )
        finalizer = source.rindex("if (WFBE_GameOver) then {")
        assert finalizer > loop
        assert marker > finalizer
        assert '"garrisonsortie-gameover"' in source[finalizer:]
        assert "deleteGroup _goGrp" in source[finalizer:]
        assert "isPlayer _x" in source[finalizer:]
