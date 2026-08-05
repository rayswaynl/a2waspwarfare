from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[2]
MIRRORS = (
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_CreateUnit.sqf",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Functions/Common_CreateUnit.sqf",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Common/Functions/Common_CreateUnit.sqf",
)


def _mvd_branch(path: Path) -> str:
    source = path.read_text(encoding="utf-8")
    match = re.search(
        r'if \(_type == "MVD_Soldier_AT"\) then \{(?P<body>.*?)\n\};',
        source,
        re.S,
    )
    assert match, f"missing MVD_Soldier_AT replacement branch in {path}"
    return match.group("body")


def test_rpg7vr_mags_bind_to_rpg7v_muzzle_before_they_are_added():
    for path in MIRRORS:
        body = _mvd_branch(path)
        add_weapon_pos = body.index('addWeapon "RPG7V"')
        select_pos = body.index('selectWeapon "RPG7V"')
        first_mag_pos = body.index('addMagazine "PG7VR"')
        assert add_weapon_pos < select_pos, path
        assert select_pos < first_mag_pos, path
        assert body.count('addMagazine "PG7VR"') == 2, path


def test_mvd_branch_preserves_the_unit_selected_weapon_after_rearming():
    for path in MIRRORS:
        body = _mvd_branch(path)
        assert "currentWeapon" in body, path
        assert "selectWeapon _mvdPreviousWeapon" in body, path
