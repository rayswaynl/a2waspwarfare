from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)


def _read(mission: str) -> str:
    return (ROOT / mission / "Server/FSM/server_groupsGC.sqf").read_text(
        encoding="utf-8-sig"
    )


def test_base_gc_excludes_short_lived_garrison_sorties_from_re_adoption():
    for mission in MISSIONS:
        source = _read(mission)
        guard = '[_baseG, "wfbe_garrison_sortie", false] Call WFBE_CO_FNC_GroupGetBool'
        assert guard in source
        assert '&& {!_baseIsGarrisonSortie}' in source
        assert source.index(guard) < source.index('if (!_baseIsPers &&')
