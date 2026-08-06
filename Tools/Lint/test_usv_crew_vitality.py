import re
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
USV_PATHS = (
    REPO_ROOT
    / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Server_USVFlotilla.sqf",
    REPO_ROOT
    / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/Server_USVFlotilla.sqf",
    REPO_ROOT
    / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Server/Server_USVFlotilla.sqf",
)


def _crew_vitality_block(path: Path) -> str:
    source = path.read_text(encoding="utf-8-sig")
    prune_start = source.index("//=== (2) PRUNE")
    maintain_start = source.index("//=== (3) MAINTAIN")
    prune = source[prune_start:maintain_start]
    marker = "//--- r187 crew-vitality:"
    block_start = prune.index(marker)
    block_end = prune.index("//--- Gate closed", block_start)
    return prune[block_start:block_end]


def test_usv_prune_recycles_bare_or_unseated_weapon_crew_slots():
    for path in USV_PATHS:
        block = _crew_vitality_block(path)

        assert re.search(r"isNull\s+_eStatic", block)
        assert re.search(r"alive\s+_eStatic", block)
        assert re.search(r"isNull\s+_eGunner", block)
        assert re.search(r"alive\s+_eGunner", block)
        assert "gunner _eStatic" in block
        assert "crew _eBoat" in block
        assert "crew _eStatic" in block
        assert "isPlayer _x" in block
        assert 'weapon_crew_lost' in block


def test_usv_prune_retains_player_occupied_drop_for_later_cleanup():
    for path in USV_PATHS:
        source = path.read_text(encoding="utf-8-sig")
        prune_start = source.index("//=== (2) PRUNE")
        maintain_start = source.index("//=== (3) MAINTAIN")
        prune = source[prune_start:maintain_start]
        drop_start = prune.index("if (_drop) then {")
        movement_marker = "//--- Movement only while the gate is active"
        drop = prune[drop_start:prune.index(movement_marker, drop_start)]

        player_safe = re.search(
            r"if \(!_boatHasPlayer && !_staticHasPlayer\) then \{(?P<delete>.*?)\}"
            r"\s*else\s*\{(?P<occupied>.*?)\}",
            drop,
            re.DOTALL,
        )
        assert player_safe, "drop teardown must branch on player occupancy"
        assert re.search(r"_kept\s*=\s*_kept\s*\+\s*\[_entry\];", player_safe.group("occupied")), (
            "player-occupied drop must stay registered until a later prune can clean it up"
        )
