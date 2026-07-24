#!/usr/bin/env python3
"""Regression contract for HC town-delegation lifecycle handoff."""

from hashlib import sha256
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CH = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"
MIRRORS = (
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)


def _source(mission: Path, relative: str) -> str:
    return (mission / relative).read_text(encoding="utf-8")


def test_delegated_town_batches_carry_and_validate_a_lifecycle_epoch() -> None:
    delegation = _source(CH, "Server/Functions/Server_DelegateAITownHeadless.sqf")
    client = _source(CH, "Client/Functions/Client_DelegateTownAI.sqf")
    town_ai = _source(CH, "Server/FSM/server_town_ai.sqf")
    town_capture = _source(CH, "Server/FSM/server_town.sqf")
    handle = _source(CH, "Server/Functions/Server_HandleSpecial.sqf")

    assert '"wfbe_town_ai_epoch"' in town_ai
    assert '"wfbe_town_ai_epoch"' in town_capture
    assert "_episode" in delegation
    assert "_episode" in client
    assert "_episode" in handle
    assert "Town delegation stale" in client
    assert "Town delegation stale" in handle


def test_hc_town_delegation_epoch_mirrors_match_chernarus() -> None:
    relatives = (
        "Server/Functions/Server_DelegateAITownHeadless.sqf",
        "Client/Functions/Client_DelegateTownAI.sqf",
        "Server/FSM/server_town_ai.sqf",
        "Server/FSM/server_town.sqf",
        "Server/Functions/Server_HandleSpecial.sqf",
    )
    for relative in relatives:
        digest = sha256((CH / relative).read_bytes()).hexdigest()
        for mirror in MIRRORS:
            assert sha256((mirror / relative).read_bytes()).hexdigest() == digest


if __name__ == "__main__":
    test_delegated_town_batches_carry_and_validate_a_lifecycle_epoch()
    test_hc_town_delegation_epoch_mirrors_match_chernarus()
