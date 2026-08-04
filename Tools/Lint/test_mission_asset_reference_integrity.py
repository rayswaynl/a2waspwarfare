"""Regression coverage for mission-owned texture paths used by active vehicle flows."""

from __future__ import annotations

import hashlib
import re
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = (
    REPO_ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    REPO_ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    REPO_ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)
TEXTURE_CONSUMERS = (
    Path("Common/Functions/Common_AddVehicleTexture.sqf"),
    Path("Server/Construction/Construction_HQSite.sqf"),
    Path("Server/Functions/Server_MHQRepair.sqf"),
    Path("Server/Init/Init_Server.sqf"),
)
TEXTURE_PATTERN = re.compile(r'Textures\\([A-Za-z0-9_]+\.paa)')


def _referenced_textures(mission_root: Path) -> set[str]:
    textures: set[str] = set()
    for relative_path in TEXTURE_CONSUMERS:
        source = (mission_root / relative_path).read_text(encoding="utf-8-sig")
        for line in source.splitlines():
            textures.update(TEXTURE_PATTERN.findall(line.split("//", 1)[0]))
    return textures


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def test_active_vehicle_texture_references_exist_and_match_all_terrains() -> None:
    expected_textures = _referenced_textures(MISSION_ROOTS[0])
    assert expected_textures

    source_hashes = {}
    for texture_name in expected_textures:
        source_texture = MISSION_ROOTS[0] / "Textures" / texture_name
        assert source_texture.is_file(), f"missing source texture: {source_texture}"
        source_hashes[texture_name] = _sha256(source_texture)

    for mission_root in MISSION_ROOTS[1:]:
        assert _referenced_textures(mission_root) == expected_textures
        for texture_name, expected_hash in source_hashes.items():
            mirror_texture = mission_root / "Textures" / texture_name
            assert mirror_texture.is_file(), f"missing mirror texture: {mirror_texture}"
            assert _sha256(mirror_texture) == expected_hash, (
                f"texture drift: {mirror_texture}"
            )
