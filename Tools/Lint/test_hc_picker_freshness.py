"""Regression contract for excluding departed HC registry entries from picks."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)
PICKER_PATH = "Server/Functions/Server_PickLeastLoadedHC.sqf"


def test_picker_requires_a_fresh_hcstat_for_each_registered_hc():
    """A registered group with no fresh heartbeat must not become the argmin target."""
    sources = []
    for mission_root in MISSION_ROOTS:
        source = (mission_root / PICKER_PATH).read_text(encoding="utf-8-sig")
        sources.append(source.encode("utf-8"))

        assert 'missionNamespace getVariable ["WFBE_HCFPS_REG", []]' in source
        assert 'Format ["HC-%1", netId (leader _x)]' in source
        assert '(_slot select 2)' in source
        assert '(time - (_slot select 2)) <= 150' in source
        assert source.index("_fresh = true") < source.index("_live = _live + [_x]")

    assert sources[0] == sources[1] == sources[2]


if __name__ == "__main__":
    test_picker_requires_a_fresh_hcstat_for_each_registered_hc()
    print("HC picker freshness contract: PASS")
