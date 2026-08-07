"""Regression contract for wildcard grants racing an active paid upgrade."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)
PROCESS_PATH = "Server/Functions/Server_ProcessUpgrade.sqf"
WILDCARD_PATH = "Server/Functions/AI_Commander_Wildcard.sqf"


def test_wildcard_grant_supersedes_matching_paid_upgrade_completion():
    """A concurrent free grant must not make the timer increment the same tier twice."""
    process_sources = []
    wildcard_sources = []
    for mission_root in MISSION_ROOTS:
        process = (mission_root / PROCESS_PATH).read_text(encoding="utf-8-sig")
        wildcard = (mission_root / WILDCARD_PATH).read_text(encoding="utf-8-sig")
        process_sources.append(process.encode("utf-8"))
        wildcard_sources.append(wildcard.encode("utf-8"))

        guard = process[process.index("_curLvl = _upgrades select _upgrade_id;") : process.index("_upgrades set [_upgrade_id, _curLvl + 1];")]
        assert "if (_curLvl > _upgrade_level) exitWith" in guard
        assert 'setVariable ["wfbe_upgrading", false, true]' in guard
        assert 'setVariable ["wfbe_upgrading_id", -1, true]' in guard
        assert 'setVariable ["wfbe_upgrading_end_time", -1, true]' in guard
        assert "completion superseded" in guard
        assert 'setVariable ["wfbe_upgrades", _newUpgrades, true]' in wildcard

    assert process_sources[0] == process_sources[1] == process_sources[2]
    assert wildcard_sources[0] == wildcard_sources[1] == wildcard_sources[2]


if __name__ == "__main__":
    test_wildcard_grant_supersedes_matching_paid_upgrade_completion()
    print("Upgrade completion wildcard-race contract: PASS")
