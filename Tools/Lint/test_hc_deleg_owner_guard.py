#!/usr/bin/env python3
"""Regression contract for HCDELEG's disconnect-safe live-HC filter."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = [
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
]


def read(root: Path) -> str:
    return (root / "Server/AI/Commander/AI_Commander.sqf").read_text(
        encoding="utf-8-sig"
    )


def test_hcdeleg_excludes_registered_groups_after_owner_falls_back_to_server() -> None:
    sources = [read(root) for root in MISSION_ROOTS]

    for text in sources:
        assert 'missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []]' in text
        assert (
            "{alive leader _x} && {(owner (leader _x)) > 2}) then {_hcLive = _hcLive + [_x]}"
            in text
        )
        assert '"HCDELEG|v1|"' in text

    assert sources[0] == sources[1] == sources[2]


if __name__ == "__main__":
    test_hcdeleg_excludes_registered_groups_after_owner_falls_back_to_server()
    print("HCDELEG owner guard contract: PASS")
