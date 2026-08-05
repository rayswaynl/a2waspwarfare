"""Regression contract for camp-clearing target distribution."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION_ROOTS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)


def test_mode2_camp_clear_uses_each_unit_nearest_live_foe_and_is_mirrored():
    sources = []
    expected = (
        'if (count _campEnemy > 0) then {\n'
        '\t\t\t\t\t\t\t\t\t{\n'
        '\t\t\t\t\t\t\t\t\t\tif (alive _x) then {\n'
        '\t\t\t\t\t\t\t\t\t\t\tprivate ["_campFoe"];\n'
        '\t\t\t\t\t\t\t\t\t\t\t_campFoe = [_x, _campEnemy] Call WFBE_CO_FNC_GetClosestEntity;\n'
        '\t\t\t\t\t\t\t\t\t\t\tif (!isNull _campFoe) then {\n'
        '\t\t\t\t\t\t\t\t\t\t\t\t_x reveal _campFoe;\n'
        '\t\t\t\t\t\t\t\t\t\t\t\t_x doTarget _campFoe;\n'
        '\t\t\t\t\t\t\t\t\t\t\t\t_x doFire _campFoe;\n'
    )
    for mission_root in MISSION_ROOTS:
        source = (mission_root / "Common" / "Functions" / "Common_RunCommanderTeam.sqf").read_text(encoding="utf-8-sig")
        sources.append(source.encode("utf-8"))
        assert expected in source
        assert "_campFoe = _campEnemy select 0;" not in source

    assert sources[0] == sources[1] == sources[2]


if __name__ == "__main__":
    test_mode2_camp_clear_uses_each_unit_nearest_live_foe_and_is_mirrored()
    print("AICOM camp target distribution contract: PASS")
