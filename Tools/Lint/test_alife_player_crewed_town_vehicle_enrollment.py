from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TOWN_AI = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus" / "Server" / "FSM" / "server_town_ai.sqf"


def test_player_crewed_town_hull_is_enrolled_before_site_registry_is_cleared() -> None:
    """A player takeover must protect the hull now and reap it only after it becomes empty."""
    text = TOWN_AI.read_text(encoding="utf-8")
    player_guard = 'if (({isPlayer _x} count crew _x) == 0) then {'
    guard_at = text.index(player_guard)
    registry_clear_at = text.index("_town setVariable ['wfbe_active_vehicles', []];", guard_at)
    player_branch = text[guard_at:registry_clear_at]

    enrollment = '["aicom-vehicle-abandoned", _x] Call HandleSpecial;'
    enrollment_at = player_branch.rindex(enrollment)
    assert '} else {' in player_branch[:enrollment_at]
