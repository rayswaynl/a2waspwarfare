"""Regression contract for exclusive AICOM service and HQ-strike commitments."""

from hashlib import sha256
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad",
)
STRATEGY = Path("Server/AI/Commander/AI_Commander_Strategy.sqf")


def _source(mission: Path) -> str:
    return (mission / STRATEGY).read_text(encoding="utf-8-sig")


def test_hq_strike_picker_excludes_service_enroute_team() -> None:
    """A logistics reservation must survive the separate HQ-strike picker."""
    for mission in MISSIONS:
        source = _source(mission)
        picker = source[source.index("while {_strikeCount < _strikeTarget} do {") : source.index("if (isNull _best) exitWith {};")]
        assert '"wfbe_aicom_svcstate"' in picker
        assert '_svcStateStrike != "enroute"' in picker


def test_hq_strike_service_reservation_mirrors_match_chernarus() -> None:
    """The exclusive-commitment contract must match on all maintained terrains."""
    expected = sha256(_source(MISSIONS[0]).encode("utf-8")).hexdigest()
    for mission in MISSIONS[1:]:
        assert sha256(_source(mission).encode("utf-8")).hexdigest() == expected
