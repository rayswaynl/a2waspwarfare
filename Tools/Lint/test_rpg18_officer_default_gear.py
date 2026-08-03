from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MIRRORS = (
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Config/Core_Root/Root_RU.sqf",
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Config/Core_Root/Root_TKA.sqf",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Config/Core_Root/Root_RU.sqf",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Config/Core_Root/Root_TKA.sqf",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Common/Config/Core_Root/Root_RU.sqf",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Common/Config/Core_Root/Root_TKA.sqf",
)


def _officer_block(path: Path) -> str:
    source = path.read_text(encoding="utf-8")
    marker = 'missionNamespace setVariable [Format["WFBE_%1_DefaultGearOfficer", _side], ['
    start = source.index(marker)
    end = source.index("// Soldier", start)
    return source[start:end]


def test_officer_rpg18_has_a_matching_magazine_in_every_terrain_mirror():
    for path in MIRRORS:
        block = _officer_block(path)
        weapon_line = block.splitlines()[1]
        magazine_line = block.splitlines()[2]
        assert "'RPG18'" in weapon_line, path
        assert "'RPG18'" in magazine_line, path


def test_officer_rpg18_magazine_is_added_once_not_duplicated():
    for path in MIRRORS:
        block = _officer_block(path)
        assert block.count("'RPG18'") == 2, path
