"""Regression contract for capture-lock ownership during graceful withdrawal."""

from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)
STRATEGY = Path("Server/AI/Commander/AI_Commander_Strategy.sqf")


@pytest.mark.parametrize("mission", MISSIONS, ids=lambda mission: mission.name)
def test_capture_lock_blocks_only_automatic_understrength_withdrawal(
    mission: Path,
) -> None:
    """A live capture order survives auto-rally while explicit breakoff still works."""
    source = (mission / STRATEGY).read_text(encoding="utf-8-sig")
    trigger = source[
        source.index("//--- Trigger: driver explicitly asked to rally") :
        source.index("//--- fable/aicom-disband-merge")
    ]

    explicit = "if (_gwWant) then {_gwTrigger = true};"
    automatic = next(
        line for line in trigger.splitlines() if "_gwAlive > 0" in line
    )

    assert explicit in trigger
    assert trigger.index(explicit) < trigger.index(automatic)
    assert "!([_gwTeam] Call WFBE_CO_FNC_CapLock)" in automatic
