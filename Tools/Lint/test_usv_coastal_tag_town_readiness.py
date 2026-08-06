"""Regression contract for USV coastal tagging after the town roster is populated."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
USV = ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Server_USVFlotilla.sqf"


def test_coastal_tag_requires_a_populated_town_roster_without_an_unbounded_wait():
    source = USV.read_text(encoding="utf-8-sig")

    tag_index = source.index("//--- ONE-TIME: tag every town wfbe_is_coastal")
    gate = source[source.index("_usvTownDeadline = diag_tickTime + 90;") : tag_index]

    assert "waitUntil { !isNil \"towns\" && {count towns > 0} };" not in gate
    assert "diag_tickTime >= _usvTownDeadline" in gate
    assert "if (!_usvTownInitReady || {!_usvTownsReady}) exitWith" in gate


if __name__ == "__main__":
    test_coastal_tag_waits_for_a_populated_town_roster()
