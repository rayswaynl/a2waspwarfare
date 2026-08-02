"""Regression contract for turret weapon-removal ordering.

Arma 2 OA can re-evaluate a turret magazine against the next remaining muzzle
when the weapon is removed first.  The generated balance code must therefore
remove the weapon's magazines before removing the weapon itself.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
GENERATOR = ROOT / "Tools/LoadoutManager/Data/Vehicles/BaseVehicle.cs"
BALANCE_FILES = (
    ROOT
    / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_BalanceInit.sqf",
    ROOT
    / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Functions/Common_BalanceInit.sqf",
    ROOT
    / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Common/Functions/Common_BalanceInit.sqf",
)
CASES = ("BMP2_INS", "BMP2_TK_EP1", "BTR90")
MAGAZINE = 'removeMagazineTurret ["8Rnd_AT5_BMP2", [0]]'
WEAPON = 'removeWeaponTurret ["AT5LauncherSingle", [0]]'


def _case_block(source: str, case_name: str) -> str:
    start = source.index(f'case "{case_name}"')
    next_case = source.find('\ncase "', start + 1)
    return source[start:] if next_case < 0 else source[start:next_case]


def test_generator_removes_turret_magazines_before_weapon() -> None:
    source = GENERATOR.read_text(encoding="utf-8")
    for method_name in (
        "private string GenerateSQFCodeForWeaponRemoval()",
        "private string GenerateSQFCodeForWeaponRemovalOnTheTurret()",
    ):
        method_start = source.index(method_name)
        method = source[method_start:]
        assert method.index("removeMagazineTurret") < method.index("removeWeaponTurret")


def test_generated_balance_mirrors_remove_at5_magazines_first() -> None:
    for path in BALANCE_FILES:
        source = path.read_text(encoding="utf-8")
        for case_name in CASES:
            block = _case_block(source, case_name)
            assert block.index(MAGAZINE) < block.index(WEAPON), (
                f"{path}: {case_name} leaves AT5 magazine behind while removing its weapon"
            )
