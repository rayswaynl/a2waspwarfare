"""Regression contract for AICOM airmobile transport crew-cap accounting."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSIONS = (
    ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.takistan",
    ROOT / "Missions_Vanilla" / "[61-2hc]warfarev2_073v48co.zargabad",
)


def test_airlift_grant_uses_effective_vehicle_crew_slots_for_cap_reservation():
    for mission in MISSIONS:
        produce = mission / "Server" / "AI" / "Commander" / "AI_Commander_Produce.sqf"
        source = produce.read_text(encoding="utf-8-sig")
        block = source[source.index("_alClass = \"\";"):source.index("_alFunds = (_side) Call GetAICommanderFunds;")]

        assert "_alCrewSlots = _alData select QUERYUNITCREW;" in block
        assert "_alCapCost = 1;" in block
        assert "if (_alHasGunner) then {_alCapCost = _alCapCost + 1};" in block
        assert "if (_alHasCommander) then {_alCapCost = _alCapCost + 1};" in block
        assert "_alExtraTurretCount" not in block
        assert "_alCapCost = 3 + count (_alData select QUERYUNITTURRETS);" not in block
