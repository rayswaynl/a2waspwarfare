"""Regression contracts for A-Life cap refusal and population reservation."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TOWN_AI = ROOT / (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/"
    "Server/FSM/server_town_ai.sqf"
)
TEAMS = ROOT / (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/"
    "Server/AI/Commander/AI_Commander_Teams.sqf"
)
DISBAND = ROOT / (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/"
    "Common/Functions/Common_AICOMDisbandTeam.sqf"
)


def test_full_side_cap_defers_a_garrison_before_it_claims_an_active_town() -> None:
    """A cap-full town may not latch active and preempt another town's budget slot."""
    text = TOWN_AI.read_text(encoding="utf-8-sig")

    assert 'GARRISON_CAP_DEFER' in text
    assert 'wfbe_active", true' in text
    assert text.index('GARRISON_CAP_DEFER') < text.index('wfbe_active", true')
    assert '_garrisonKeep = ceil ((count _groups) / 2);' not in text


def test_full_group_cap_defers_a_garrison_before_empty_group_allocation() -> None:
    """A group-cap refusal leaves the town retryable instead of active and empty."""
    text = TOWN_AI.read_text(encoding="utf-8-sig")

    assert 'TOWN_AI_GROUP_CAP_DEFER' in text
    assert text.index('TOWN_AI_GROUP_CAP_DEFER') < text.index('wfbe_active", true')


def test_hc_founding_reserves_the_full_template_population_before_pending() -> None:
    """A full-team HC request cannot consume more bodies than the side cap has left."""
    text = TEAMS.read_text(encoding="utf-8-sig")

    assert '_foundCapCost = 0;' in text
    assert '_foundCapCost = _foundCapCost + 1;' in text
    assert '_foundCapCost = _foundCapCost + (3 + count (_foundCapData select QUERYUNITTURRETS));' in text
    assert 'if ((_sideAINow + _foundCapCost) > _aiCapTier) exitWith {' in text
    assert text.index('if ((_sideAINow + _foundCapCost) > _aiCapTier) exitWith {') < text.index('_pendingIds = _pendingIds + [[_pendingNext, time]];')


def test_hc_founding_uses_a_per_dispatch_pending_reservation() -> None:
    """A late acknowledgement cannot consume a replacement team's pending slot."""
    text = TEAMS.read_text(encoding="utf-8-sig")

    assert 'wfbe_aicom_pending_ids' in text
    assert 'wfbe_aicom_pending_id' in text


def test_disband_stands_down_when_a_player_crews_a_team_vehicle() -> None:
    """Protected player-crewed hulls keep the team alive rather than deleting seated AI."""
    text = DISBAND.read_text(encoding="utf-8-sig")

    assert '_hasPlayerCrew = false;' in text
    assert 'if ({isPlayer _x} count (crew _x) > 0) then {_hasPlayerCrew = true};' in text
    assert 'if (_hasPlayerCrew) exitWith {false};' in text
