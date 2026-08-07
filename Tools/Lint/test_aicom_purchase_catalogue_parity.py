"""Regression contract for the RU Mi-8 AICOM squad's catalogue parity."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SQUAD_PATHS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / "Common" / "Config" / "Core_Squads" / "Squad_RU.sqf",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan" / "Common" / "Config" / "Core_Squads" / "Squad_RU.sqf",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad" / "Common" / "Config" / "Core_Squads" / "Squad_RU.sqf",
)
UNIT_PATHS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / "Common" / "Config" / "Core_Units" / "Units_CO_RU.sqf",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan" / "Common" / "Config" / "Core_Units" / "Units_CO_RU.sqf",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad" / "Common" / "Config" / "Core_Units" / "Units_CO_RU.sqf",
)


def test_ru_mi8_squad_uses_the_catalogued_medic():
    squad_sources = []
    unit_sources = []

    for squad_path, unit_path in zip(SQUAD_PATHS, UNIT_PATHS):
        squad = squad_path.read_text(encoding="utf-8-sig")
        unit = unit_path.read_text(encoding="utf-8-sig")
        squad_sources.append(squad_path.read_bytes())
        unit_sources.append(unit_path.read_bytes())

        start = squad.index('//--- (13) Air - Infantry Mi-8 Squadron')
        end = squad.index('//--- (14) Air - Mi-8 Rocket Assault', start)
        template = squad[start:end]

        assert 'RU_Soldier_Medic' in template
        assert 'MVD_Soldier_Medic' not in template
        assert 'RU_Soldier_Medic' in unit

    assert squad_sources[0] == squad_sources[1] == squad_sources[2]
    assert unit_sources[0] == unit_sources[1] == unit_sources[2]


def test_ru_spetsnaz_medic_is_in_the_east_barracks_catalogue():
    unit_sources = []

    for squad_path, unit_path in zip(SQUAD_PATHS, UNIT_PATHS):
        squad = squad_path.read_text(encoding="utf-8-sig")
        unit = unit_path.read_text(encoding="utf-8-sig")
        unit_sources.append(unit_path.read_bytes())

        start = squad.index('//--- (16) Infantry - Spetsnaz Recon Patrol')
        end = squad.index('//--- (17)', start)
        template = squad[start:end]

        assert 'RUS_Soldier_Medic' in template
        assert 'RUS_Soldier_Medic' in unit

    assert unit_sources[0] == unit_sources[1] == unit_sources[2]


if __name__ == "__main__":
    test_ru_mi8_squad_uses_the_catalogued_medic()
    test_ru_spetsnaz_medic_is_in_the_east_barracks_catalogue()
    print("AICOM purchase catalogue parity contract: PASS")
