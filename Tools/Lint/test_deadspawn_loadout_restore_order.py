"""Regression contract for deadspawn loadout restoration order.

Arma 2 OA requires a compatible weapon before its magazine can bind to a
muzzle.  The deadspawn guard captures a live AI loadout, calls
removeAllWeapons, then restores it on the normal and player-handoff paths.
Each restore must add weapons before magazines so launcher and grenade
magazines cannot be silently rejected after the strip.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION_DIRS = (
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)
RESPAWN_FILES = ("Server/AI/AI_AdvancedRespawn.sqf", "Server/AI/AI_SquadRespawn.sqf")


def test_deadspawn_restore_adds_weapons_before_magazines_on_every_terrain() -> None:
    for mission_dir in MISSION_DIRS:
        for relative_path in RESPAWN_FILES:
            source = (mission_dir / relative_path).read_text(encoding="utf-8")
            weapon_restore = 'addWeapon _x} forEach (_'
            magazine_restore = 'addMagazine _x} forEach (_'

            assert source.count(weapon_restore) == 2
            assert source.count(magazine_restore) == 2

            first_magazine = source.index(magazine_restore)
            first_weapon = source.index(weapon_restore)
            assert first_weapon < first_magazine, (
                f"{mission_dir / relative_path}: player-handoff restore adds magazines before weapons"
            )

            second_magazine = source.index(magazine_restore, first_magazine + 1)
            second_weapon = source.index(weapon_restore, first_weapon + 1)
            assert second_weapon < second_magazine, (
                f"{mission_dir / relative_path}: normal restore adds magazines before weapons"
            )
