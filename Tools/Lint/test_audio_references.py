"""Regression checks for client-local audio calls in the maintained mission roots."""

import re
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad"),
)


def _cfg_sound_classes(cfg_path: Path) -> set[str]:
    text = cfg_path.read_text(encoding="utf-8")
    return set(re.findall(r"(?im)^\s*class\s+([A-Za-z0-9_]+)\s*\{", text))


def _literal_play_sound_names(source_path: Path) -> set[str]:
    text = source_path.read_text(encoding="utf-8")
    return set(re.findall(r"(?i)\bplaySound\s*(?:\[\s*)?\"([^\"]+)\"", text))


def test_classic_nuke_audio_calls_are_registered_in_every_maintained_root() -> None:
    missing = []
    for mission_root in MISSION_ROOTS:
        cfg_classes = _cfg_sound_classes(REPO_ROOT / mission_root / "Sounds/description.ext")
        calls = _literal_play_sound_names(
            REPO_ROOT / mission_root / "Client/PVFunctions/NukeIncoming.sqf"
        )
        missing.extend(
            f"{mission_root}: {name}"
            for name in sorted(calls - cfg_classes)
        )

    assert not missing, "Unregistered classic-nuke sound cue(s): " + ", ".join(missing)
