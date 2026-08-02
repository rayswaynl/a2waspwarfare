#!/usr/bin/env python3
"""Regression contract for nuke screen-effect cleanup."""

from hashlib import sha256
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MAINTAINED_ROOTS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)
NUKE = Path("Client/Module/Nuke/nuke.sqf")


def test_nuke_cleanup_uses_the_effect_start_range() -> None:
    source = (MAINTAINED_ROOTS[0] / NUKE).read_text(encoding="utf-8-sig")

    assert "_screenFx = player distance _target < 4000;" in source
    assert "player distance _target < 4000" not in source.replace(
        "_screenFx = player distance _target < 4000;", ""
    )
    assert source.count("if (_screenFx) then {") == 4
    assert '"colorCorrections" ppEffectEnable false' in source


def test_nuke_screen_effect_source_matches_mirrors() -> None:
    digest = sha256((MAINTAINED_ROOTS[0] / NUKE).read_bytes()).hexdigest()
    for root in MAINTAINED_ROOTS[1:]:
        assert sha256((root / NUKE).read_bytes()).hexdigest() == digest


if __name__ == "__main__":
    test_nuke_cleanup_uses_the_effect_start_range()
    test_nuke_screen_effect_source_matches_mirrors()
