"""Regression contract for the Teamstack notification's score fan-in wait."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus"


def read_source(relative: Path) -> str:
    return (MISSION / relative).read_text(encoding="utf-8-sig")


def test_teamstack_score_wait_is_bounded_and_has_a_transport_fallback() -> None:
    source = read_source(Path("Client/PVFunctions/LocalizeMessage.sqf"))
    start = source.index('case "Teamstack"')
    end = source.index('case "CommanderDisconnected"', start)
    teamstack = source[start:end]

    assert 'waitUntil { !(isNil {missionNamespace getVariable "WFBE_BLUFOR_SCORE_JOIN"}) && !(isNil {missionNamespace getVariable "WFBE_OPFOR_SCORE_JOIN"}) };' not in teamstack
    assert "_teamstackDeadline = diag_tickTime + 15;" in teamstack
    assert "uiSleep 0.25;" in teamstack
    assert "diag_tickTime > _teamstackDeadline" in teamstack
    assert 'Localize "STR_WF_CHAT_TeamstackOrTeamSwap"' in teamstack


if __name__ == "__main__":
    test_teamstack_score_wait_is_bounded_and_has_a_transport_fallback()
    print("Teamstack wait-bound regression contract: PASS")
