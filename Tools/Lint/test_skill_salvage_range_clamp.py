from pathlib import Path


MIRRORS = (
    Path("Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Module/Skill/Skill_Apply.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/Module/Skill/Skill_Apply.sqf"),
    Path("Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Client/Module/Skill/Skill_Apply.sqf"),
)

MALFORMED = "missionNamespace getVariable ['WFBE_C_UNITS_SALVAGER_SCAVENGE_RANGE', 30] max 1"
PARENTHESIZED = "(missionNamespace getVariable ['WFBE_C_UNITS_SALVAGER_SCAVENGE_RANGE', 30]) max 1"


def test_salvage_action_clamps_numeric_range_after_get_variable():
    sources = [path.read_text(encoding="utf-8-sig") for path in MIRRORS]

    assert all(PARENTHESIZED in source for source in sources)
    assert all(MALFORMED not in source for source in sources)
    assert all(source == sources[0] for source in sources)


if __name__ == "__main__":
    test_salvage_action_clamps_numeric_range_after_get_variable()
    print("Skill salvage range clamp contract: PASS")
