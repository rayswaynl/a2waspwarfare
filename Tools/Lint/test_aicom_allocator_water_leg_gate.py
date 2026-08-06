"""Regression contracts for allocator-side terrain capability gating.

The repository's lint suite has no Arma 2 OA runtime, so this contract checks
that the allocator does not publish a straight-line water-leg target that its
AssignTowns consumer will immediately reject.
"""

from hashlib import sha256
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)
ALLOCATE = Path("Server/AI/Commander/AI_Commander_Allocate.sqf")


def _source(relative_path: Path, mission: Path) -> str:
    return (mission / relative_path).read_text(encoding="utf-8-sig")


def test_allocator_has_the_same_land_only_water_leg_contract_as_consumer() -> None:
    """The producer must classify the team and sample the same four-leg gate."""
    for mission in MISSIONS:
        source = _source(ALLOCATE, mission)
        assert '"_teamAmphib","_waterBlocks"' in source
        assert '>> "canFloat"' in source
        assert '"WFBE_C_AICOM_WATER_LEG_GATE"' in source
        assert 'surfaceIsWater [_px, _py, 0]' in source
        assert "(_hits >= 2)" in source


def test_main_allocator_write_rejects_and_clears_water_leg_targets() -> None:
    """A blocked target must never become a fresh allocator stamp."""
    for mission in MISSIONS:
        source = _source(ALLOCATE, mission)
        assert '_waterBlocked = if (!isNull _tgt) then {[_ldrPos, getPos _tgt, _teamAir, _teamAmphib] Call _waterBlocks} else {false};' in source
        write_guard = '&& {!_waterBlocked}) then {'
        assert write_guard in source
        write = source.index('"wfbe_aicom_alloc_target", _tgt')
        clear = source.index('"wfbe_aicom_alloc_target", nil', write)
        assert write < clear
        assert '"wfbe_aicom_alloc_tick", nil' in source[clear : clear + 200]


def test_allocator_mirrors_match_chernarus() -> None:
    """The source contract must not drift across maintained terrains."""
    expected = sha256(_source(ALLOCATE, MISSIONS[0]).encode("utf-8")).hexdigest()
    for mission in MISSIONS[1:]:
        actual = sha256(_source(ALLOCATE, mission).encode("utf-8")).hexdigest()
        assert actual == expected, f"{ALLOCATE} drifted in {mission.name}"
