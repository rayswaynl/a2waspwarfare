from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MIRRORS = (
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_EquipUnit.sqf",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Functions/Common_EquipUnit.sqf",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Common/Functions/Common_EquipUnit.sqf",
)


def test_each_magazine_is_bound_to_a_compatible_muzzle_before_addition():
    for path in MIRRORS:
        source = path.read_text(encoding="utf-8")
        assert 'forEach _magazines;' in source, path
        assert '{_unit addMagazine _x} forEach _magazines;' not in source, path
        assert 'forEach (["Throw","Put"] + _weapons);' in source, path
        assert 'getArray (configFile >> "CfgWeapons" >> _weapon >> "magazines")' in source, path
        assert 'getArray (configFile >> "CfgWeapons" >> _weapon >> _x >> "magazines")' in source, path
        assert 'if (!_bound && {_mag in (_entry select 1)}) then {' in source, path
        assert '_unit selectWeapon (_entry select 0);' in source, path
        assert '_unit addMagazine _mag;' in source, path
        assert 'if (!_bound) then {_unit addMagazine _mag};' in source, path


def test_three_terrain_mirrors_are_identical_after_newline_normalization():
    normalized = [path.read_text(encoding="utf-8").replace("\r\n", "\n") for path in MIRRORS]
    assert normalized[0] == normalized[1] == normalized[2]
