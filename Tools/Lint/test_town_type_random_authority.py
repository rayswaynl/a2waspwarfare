"""Regression contract: town-type rolls are server-authored and public."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TERRAINS = (
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)


def test_town_type_roll_is_server_authored_and_public() -> None:
    for terrain in TERRAINS:
        source = (terrain / "Common/Init/Init_Town.sqf").read_text(encoding="utf-8")
        assignment = '_town setVariable ["wfbe_town_type", _town_type, true];'

        assert assignment in source
        assert (
            'if (isServer) then {\n'
            '\tif (typeName _town_type == "ARRAY") then '
            '{_town_type = _town_type select floor(random count _town_type)};\n'
            f'\t{assignment}\n'
            '};'
        ) in source
        assert '_town setVariable ["wfbe_town_type", _town_type];' not in source
