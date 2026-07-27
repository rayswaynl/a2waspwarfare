"""Regression coverage for GUER Director QRF contract activation."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DIRECTOR_PATHS = (
    Path(
        "Missions/[55-2hc]warfarev2_073v48co.chernarus/"
        "Server/AI/Server_GuerDirector.sqf"
    ),
    Path(
        "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/"
        "Server/AI/Server_GuerDirector.sqf"
    ),
    Path(
        "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/"
        "Server/AI/Server_GuerDirector.sqf"
    ),
)


def test_qrf_contracts_follow_the_live_town_attack_latch() -> None:
    """Armed QRF contracts must fire from the town FSM's maintained attack state."""
    for relative_path in DIRECTOR_PATHS:
        source = (ROOT / relative_path).read_text(encoding="utf-8")
        assert 'if (_cTownObj getVariable ["wfbe_active", false]) then {' in source
        assert 'getVariable ["wfbe_contact_time", 0]' not in source


if __name__ == "__main__":
    test_qrf_contracts_follow_the_live_town_attack_latch()
