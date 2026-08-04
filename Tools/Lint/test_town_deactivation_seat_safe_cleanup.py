#!/usr/bin/env python3
"""Regression contract for seat-safe town-garrison deactivation cleanup."""

from hashlib import sha256
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CH = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"
MIRRORS = (
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)
TOWN_AI = Path("Server") / "FSM" / "server_town_ai.sqf"


def test_town_deactivation_yields_between_group_member_deletes() -> None:
    source = (CH / TOWN_AI).read_text(encoding="utf-8")
    start = source.index("//--- Teams Units.")
    end = source.index("//--- Commander Town Ledger", start)
    cleanup = source[start:end]

    delete = cleanup.index("deleteVehicle _x")
    loop_end = cleanup.index("forEach units _deactGrp", delete)
    assert "sleep 0.05" in cleanup[delete:loop_end]
    assert cleanup.index("deleteGroup _deactGrp") > loop_end


def test_town_deactivation_cleanup_mirrors_match_chernarus() -> None:
    digest = sha256((CH / TOWN_AI).read_bytes()).hexdigest()
    for mirror in MIRRORS:
        assert sha256((mirror / TOWN_AI).read_bytes()).hexdigest() == digest


if __name__ == "__main__":
    test_town_deactivation_yields_between_group_member_deletes()
    test_town_deactivation_cleanup_mirrors_match_chernarus()
