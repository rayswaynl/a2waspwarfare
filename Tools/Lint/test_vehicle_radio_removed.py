"""Regression checks for the complete vehicle-radio removal.

These checks intentionally inspect source text rather than execute Arma 2 SQF.  They protect
the removal boundary while leaving the unrelated HQ voice-radio system and GLOBALGAMESTATS
extension path intact.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = (
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)


def text_files(root: Path):
    yield from (path for path in root.rglob("*") if path.is_file())


def test_vehicle_radio_mission_surface_is_gone():
    forbidden = (
        "WASP\\Radio",
        "WASP_Radio",
        "WASP_RADIO",
        "WFBE_C_STRUCTURES_RADIOTOWER",
        "HasSideRadioTower",
        "RadioTower",
        "a2waspwarfare_Extension\" callExtension format [\"RADIO",
        "a2waspwarfare_Extension\" callExtension \"RADIO",
    )
    leftovers = []
    for root in MISSION_ROOTS:
        for path in text_files(root):
            content = path.read_text(encoding="utf-8", errors="ignore")
            for token in forbidden:
                if token in content:
                    leftovers.append(f"{path.relative_to(ROOT)}: {token}")
    assert not leftovers, "vehicle-radio references remain:\n" + "\n".join(leftovers)


def test_radio_directories_and_extension_command_are_removed():
    assert not any((root / "WASP/Radio").exists() for root in MISSION_ROOTS)

    extension_names = (ROOT / "Extension/src/BaseExtensionClass/ExtensionName.cs").read_text(
        encoding="utf-8"
    )
    assert "GLOBALGAMESTATS" in extension_names
    assert "RADIO" not in extension_names
    assert not (ROOT / "Extension/src/BaseExtensionClass/Implementations/RADIO.cs").exists()

    csproj = (ROOT / "Extension/Extension.csproj").read_text(encoding="utf-8")
    packages = (ROOT / "Extension/src/packages.config").read_text(encoding="utf-8")
    assert "ManagedBass" not in csproj
    assert "bass.dll" not in csproj
    assert "ManagedBass" not in packages
    assert not (ROOT / "Extension/native/bass.dll").exists()
    assert not (ROOT / "Mods/mkswf_vehicle_radio").exists()


def test_globalgamestats_server_bridge_remains_intact():
    sqf = (MISSION_ROOTS[0] / "Server/CallExtensions/GlobalGameStats.sqf").read_text(
        encoding="utf-8"
    )
    init = (MISSION_ROOTS[0] / "Server/Init/Init_Server.sqf").read_text(encoding="utf-8")
    implementation = (
        ROOT / "Extension/src/BaseExtensionClass/Implementations/GLOBALGAMESTATS.cs"
    ).read_text(encoding="utf-8")
    assert "[] execVM \"Server\\CallExtensions\\GlobalGameStats.sqf\";" in init
    assert '_cSharpClassName = "GLOBALGAMESTATS";' in sqf
    assert '"a2waspwarfare_Extension" callExtension format' in sqf
    assert "public class GLOBALGAMESTATS" in implementation
