"""Regression contract for the owner-approved removal of custom Miksuu radio.

The mission must retain native Arma communication commands while carrying no
executable custom vehicle-radio, Radio Tower, addon, or extension wiring.
"""

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)
TEXT_SUFFIXES = {".sqf", ".hpp", ".cpp", ".cs", ".csproj", ".config", ".txt"}
FORBIDDEN = re.compile(
    r"mkswf_vehicle_radio|WASP[\\/]Radio|WASP_RADIO_MODE|WFBE_C_RADIO_MODE|"
    r"WFBE_C_STRUCTURES_RADIOTOWER|WFBE_C_STRUCTURES_RADIOTOWER_CASH_COST|"
    r"WFBE_RADIOTOWER_(?:WEST|EAST)|WFBE_CO_FNC_HasSideRadioTower|"
    r"RadioTower|Radio Tower|vehicle-radio|Vehicle Radio|ManagedBass|bass\.dll|"
    r"ExtensionName\.RADIO|class\s+RADIO\b",
    re.IGNORECASE,
)


def _executable_text_files():
    roots = (*MISSION_ROOTS, ROOT / "Extension")
    for base in roots:
        if not base.exists():
            continue
        for path in base.rglob("*"):
            if path.is_file() and path.suffix.lower() in TEXT_SUFFIXES:
                yield path


def test_custom_radio_payload_paths_are_absent():
    forbidden_paths = [
        ROOT / "Mods" / "mkswf_vehicle_radio",
        ROOT / "Extension" / "src" / "BaseExtensionClass" / "Implementations" / "RADIO.cs",
        ROOT / "Extension" / "native" / "bass.dll",
        ROOT / "Extension" / "native" / "bass-LICENSE.txt",
    ]
    for mission in MISSION_ROOTS:
        forbidden_paths.extend(
            [
                mission / "WASP" / "Radio",
                mission / "Common" / "Functions" / "Common_HasSideRadioTower.sqf",
            ]
        )
    existing = [str(path.relative_to(ROOT)) for path in forbidden_paths if path.exists()]
    assert existing == [], f"custom radio payloads still exist: {existing}"


def test_no_live_custom_radio_or_tower_tokens_remain():
    hits = []
    for path in _executable_text_files():
        text = path.read_text(encoding="utf-8-sig", errors="replace")
        for line_number, line in enumerate(text.splitlines(), 1):
            if FORBIDDEN.search(line):
                hits.append(f"{path.relative_to(ROOT)}:{line_number}:{line.strip()}")
    assert hits == [], "custom radio tokens remain:\n" + "\n".join(hits)


def test_native_arma_communications_remain_available():
    client_tree = MISSION_ROOTS[0] / "Client"
    combined = "\n".join(
        path.read_text(encoding="utf-8-sig", errors="replace")
        for path in client_tree.rglob("*.sqf")
    )
    # These are native game communication facilities, not the deleted DLL radio.
    assert "sideChat" in combined
    assert "groupChat" in combined
    assert "vehicleChat" in combined
    assert "commandChat" in combined
    assert "playSound" in combined
    assert "playMusic" in combined


def test_unrelated_global_game_stats_extension_remains_registered():
    project = (ROOT / "Extension" / "Extension.csproj").read_text(
        encoding="utf-8-sig", errors="replace"
    )
    extension_names = (
        ROOT / "Extension" / "src" / "BaseExtensionClass" / "ExtensionName.cs"
    ).read_text(encoding="utf-8-sig", errors="replace")
    assert "Implementations\\GLOBALGAMESTATS.cs" in project
    assert "GLOBALGAMESTATS" in extension_names
