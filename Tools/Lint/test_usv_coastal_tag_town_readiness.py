"""Regression contract for USV coastal tagging after the town roster is populated."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
USV = ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Server_USVFlotilla.sqf"


def test_coastal_tag_waits_for_a_populated_town_roster():
    source = USV.read_text(encoding="utf-8-sig")

    assert 'waitUntil { !isNil "towns" && {count towns > 0} };' in source
    assert source.index('waitUntil { !isNil "towns" && {count towns > 0} };') < source.index(
        "//--- ONE-TIME: tag every town wfbe_is_coastal"
    )


if __name__ == "__main__":
    test_coastal_tag_waits_for_a_populated_town_roster()
