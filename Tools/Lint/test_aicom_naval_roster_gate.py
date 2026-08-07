"""Regression contract for AICOM naval-template admission.

RHIB and RHIB2Turret are valid player/unit classes, but the current AICOM
founding and no-HC assignment paths only have ground/air placement and routing.
Keep those Ship templates out of the AICOM roster until a water-aware founder
exists, without removing the player/unit registrations.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)
SQUAD_FILES = tuple(
    ROOT / mission_root / "Common/Config/Core_Squads/Squad_USMC.sqf"
    for mission_root in MISSION_ROOTS
)
CONSTANT_FILES = tuple(
    ROOT / mission_root / "Common/Init/Init_CommonConstants.sqf"
    for mission_root in MISSION_ROOTS
)
NAVAL_GATE = 'if ((missionNamespace getVariable ["WFBE_C_AICOM_NAVAL_TEMPLATES", 0]) > 0) then {'
DEFAULT_CONSTANT = 'if (isNil "WFBE_C_AICOM_NAVAL_TEMPLATES") then {WFBE_C_AICOM_NAVAL_TEMPLATES = 0};'


def test_aicom_ship_templates_are_default_off_and_mirrored() -> None:
    squad_sources = []
    for path in SQUAD_FILES:
        source = path.read_text(encoding="utf-8-sig")
        squad_sources.append(source)

        gate_start = source.index(NAVAL_GATE)
        gate_end = source.index(
            "//--- Mechanized - M1135 ATGM Ambush Team",
            gate_start,
        )
        gated_region = source[gate_start:gate_end]

        assert '_u\t\t= ["RHIB"];' in gated_region
        assert '_u\t\t= ["RHIB2Turret"];' in gated_region

    assert squad_sources[1:] == [squad_sources[0], squad_sources[0]]

    constant_sources = []
    for path in CONSTANT_FILES:
        source = path.read_text(encoding="utf-8-sig")
        constant_sources.append(source)
        assert DEFAULT_CONSTANT in source

    assert constant_sources[1:] == [constant_sources[0], constant_sources[0]]


def test_player_ship_registrations_remain_available() -> None:
    core_files = tuple(
        ROOT / mission_root / "Common/Config/Core/Core_USMC.sqf"
        for mission_root in MISSION_ROOTS
    )
    for path in core_files:
        source = path.read_text(encoding="utf-8-sig")
        assert "_c = _c + ['RHIB'];" in source
        assert "_c = _c + ['RHIB2Turret'];" in source


if __name__ == "__main__":
    test_aicom_ship_templates_are_default_off_and_mirrored()
    test_player_ship_registrations_remain_available()
    print("PASS: AICOM Ship templates are default-off; player Ship rows remain registered")
