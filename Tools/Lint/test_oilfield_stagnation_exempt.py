from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions/[55-2hc]warfarev2_073v48co.chernarus"


def read(relative):
    return (MISSION / relative).read_text(encoding="utf-8")


def test_oilfield_income_reuses_the_ai_commander_stagnation_exemption():
    source = read("Server/Server_Oilfields.sqf")

    assert 'WFBE_C_AICOM_SUPPLY_STAGNATION_EXEMPT", 0' in source
    assert "_supplyStagnation = true;" in source
    assert "_owner Call WFBE_CO_FNC_GetCommanderTeam" in source
    assert "WFBE_C_AI_COMMANDER_HYBRID_REFILL" in source
    assert "WFBE_C_AI_COMMANDER_ENABLED" in source
    assert "_supplyStagnation] Call ChangeSideSupply;" in source
    assert '[_owner, _pay, Format ["OILFIELD passive income (held by %1).", str _owner], true] Call ChangeSideSupply;' not in source
