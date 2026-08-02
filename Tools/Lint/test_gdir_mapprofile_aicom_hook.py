"""Regression contract for the default-off GDIR map profile and AICOM hook."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad"),
)


def source(root: Path, relative: str) -> str:
    return (ROOT / root / relative).read_text(encoding="utf-8-sig")


def test_gdir_salvage_is_default_off_and_mirrored() -> None:
    for root in MISSION_ROOTS:
        constants = source(root, "Common/Init/Init_CommonConstants.sqf")
        director = source(root, "Server/AI/Server_GuerDirector.sqf")

        assert 'if (isNil "AICOMV2_GDIR_MAP_PROFILE")' in constants
        assert 'AICOMV2_GDIR_MAP_PROFILE = 0' in constants
        assert 'if (isNil "AICOMV2_GDIR_AICOM_HOOK")' in constants
        assert 'AICOMV2_GDIR_AICOM_HOOK = 0' in constants
        assert 'AICOMV2_GDIR_MOVE_TIMEOUT_FACTOR_OWNER_SET' in constants
        assert 'AICOMV2_GDIR_CELL_SPEED_MS_OWNER_SET' in constants

        assert 'getVariable ["AICOMV2_GDIR_MAP_PROFILE", 0]' in director
        assert 'getVariable ["AICOMV2_GDIR_AICOM_HOOK", 0]' in director
        assert 'toLower worldName' in director
        assert '"takistan"' in director
        assert 'AICOMV2_GDIR_MOVE_TIMEOUT_FACTOR' in director
        assert 'AICOMV2_GDIR_CELL_SPEED_MS' in director


def test_hook_reads_enemy_effectiveness_and_restores_temporary_baselines() -> None:
    for root in MISSION_ROOTS:
        director = source(root, "Server/AI/Server_GuerDirector.sqf")

        assert 'select WFBE_SNAP_ENEFF' in director
        assert 'select WFBE_SNAP_TEAMS' in director
        assert 'select WFBE_SNAP_TGTTOWNOBJS' in director
        assert 'select WFBE_SNAP_TIME' in director
        assert '_snapMaxAge' in director
        assert '_westSnapOk && {_eastSnapOk}' in director
        assert '_coordBaselineRestore' in director
        assert 'GDIR_COORD_BASELINE_RESTORE' in director
        assert '_coordMult = 1.1' in director
        assert '_needed * 0.5 * _coordMult' in director
        assert '_needed * 0.3 * _coordMult' in director
        assert director.index('PHASE 2: OBSERVE') < director.index('P6: read-only occupier-awareness')
        assert director.index('P6: read-only occupier-awareness') < director.index('PHASE 3: ASSESSMENT')
        assert director.index('GDIR_COORD_BASELINE_RESTORE') < director.index('PHASE 6: MATERIALIZATION')


if __name__ == "__main__":
    test_gdir_salvage_is_default_off_and_mirrored()
    test_hook_reads_enemy_effectiveness_and_restores_temporary_baselines()
