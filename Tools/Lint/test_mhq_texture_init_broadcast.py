"""Regression contract for the MHQ desert-camo JIP init broadcast.

``setVehicleInit`` stores one payload, so the three texture assignments must be
combined before the single ``processInitCommands`` flush.  Separate calls retain
only the final texture assignment for JIP clients.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TERRAINS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)
SOURCES = (
    "Server/Init/Init_Server.sqf",
    "Server/Functions/Server_MHQRepair.sqf",
)
TEXTURE_COMMANDS = (
    'setObjectTexture [0,""Textures\\lavbody_coD.paa""]',
    'setObjectTexture [1,""Textures\\lavbody2_coD.paa""]',
    'setObjectTexture [2,""Textures\\lav_hq_coD.paa""]',
)


def test_desert_mhq_camo_uses_one_jip_payload_per_path() -> None:
    for terrain in TERRAINS:
        for relative in SOURCES:
            text = (ROOT / terrain / relative).read_text(encoding="utf-8")
            start = text.index('if (_side == west && !(IS_chernarus_map_dependent))')
            block = text[start:text.index('\n};', start) + 3]

            assert block.count('setVehicleInit') == 1, f"{terrain}/{relative}: payload was overwritten"
            assert block.count('processinitcommands') == 1, f"{terrain}/{relative}: expected one flush"
            for command in TEXTURE_COMMANDS:
                assert command in block, f"{terrain}/{relative}: missing desert texture command {command}"


if __name__ == "__main__":
    test_desert_mhq_camo_uses_one_jip_payload_per_path()
    print("MHQ texture init broadcast regression checks passed")
