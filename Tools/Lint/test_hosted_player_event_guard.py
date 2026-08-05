#!/usr/bin/env python3
"""Regression checks for hosted-server player event handler reachability."""

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TERRAINS = (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)
EVENT_HANDLERS = (
    "Server/Functions/Server_OnPlayerConnected.sqf",
    "Server/Functions/Server_OnPlayerDisconnected.sqf",
)


def test_hosted_player_event_handlers_are_not_gated_by_local_player() -> None:
    for terrain in TERRAINS:
        for relative_path in EVENT_HANDLERS:
            path = ROOT / terrain / relative_path
            header = "\n".join(path.read_text(encoding="utf-8-sig").splitlines()[:40])
            guards = [line for line in header.splitlines() if "exitWith" in line]
            assert guards, f"{terrain}/{relative_path}: event guard not found"
            assert not re.search(r"\blocal\s+player\b", guards[0], re.IGNORECASE), (
                f"{terrain}/{relative_path}: hosted server event is gated by local player"
            )


if __name__ == "__main__":
    test_hosted_player_event_handlers_are_not_gated_by_local_player()
    print("hosted player event guard regression check passed")
