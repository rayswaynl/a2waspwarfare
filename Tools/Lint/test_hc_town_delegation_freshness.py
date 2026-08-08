"""Regression contract for keeping town AI on fresh HC registry entries."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = (
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)
DELEGATE_PATH = "Server/Functions/Server_DelegateAITownHeadless.sqf"
TOWN_AI_PATH = "Server/FSM/server_town_ai.sqf"


def test_town_delegation_and_preflight_require_fresh_hcstat():
    """Stale owner-positive HC bodies must not receive or suppress a server fallback wave."""
    pairs = []
    for mission_root in MISSION_ROOTS:
        delegate = (mission_root / DELEGATE_PATH).read_text(encoding="utf-8-sig")
        town_ai = (mission_root / TOWN_AI_PATH).read_text(encoding="utf-8-sig")
        pairs.append((delegate.encode("utf-8"), town_ai.encode("utf-8")))

        assert 'missionNamespace getVariable ["WFBE_HCFPS_REG", []]' in delegate
        assert 'Format ["HC-%1", netId (leader _x)]' in delegate
        assert '(time - (_slot select 2)) <= 150' in delegate
        assert delegate.index("_fresh = true") < delegate.index(
            "_live = _live + [leader _x]"
        )

        assert 'missionNamespace getVariable ["WFBE_HCFPS_REG", []]' in town_ai
        assert 'Format ["HC-%1", netId (leader _x)]' in town_ai
        assert '(time - (_slot select 2)) <= 150' in town_ai
        assert town_ai.index("_fresh = true") < town_ai.index(
            "_liveHCs = _liveHCs + 1"
        )
        assert town_ai.index("_liveHCs = _liveHCs + 1") < town_ai.index(
            "if (_liveHCs > 0)"
        )

    assert pairs[0] == pairs[1] == pairs[2]


if __name__ == "__main__":
    test_town_delegation_and_preflight_require_fresh_hcstat()
    print("HC town delegation freshness contract: PASS")
