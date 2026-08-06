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
