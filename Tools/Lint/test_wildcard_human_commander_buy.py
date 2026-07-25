from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"
CONSTANTS = MISSION / "Common" / "Init" / "Init_CommonConstants.sqf"
WILDCARD = MISSION / "Server" / "Functions" / "AI_Commander_Wildcard.sqf"


def test_human_wildcard_buy_is_flagged_and_reuses_aicom_treasury():
    constants = CONSTANTS.read_text(encoding="utf-8")
    wildcard = WILDCARD.read_text(encoding="utf-8")

    assert 'WFBE_C_AI_COMMANDER_WILDCARD_HUMAN_BUY = 0' in constants
    assert 'if (_humanCmd && {!_humanWildcardBuy}) then {' in wildcard
    assert 'human commander has no buy path yet' in wildcard
    assert '(_side) Call GetAICommanderFunds' in wildcard
    assert '[_side, -_wcCost] Call ChangeAICommanderFunds' in wildcard


def test_human_flag_off_keeps_the_legacy_skip_log():
    wildcard = WILDCARD.read_text(encoding="utf-8")

    assert 'human commander has no buy path yet' in wildcard
    assert 'if (_humanCmd && {!_humanWildcardBuy}) then {' in wildcard


if __name__ == "__main__":
    test_human_wildcard_buy_is_flagged_and_reuses_aicom_treasury()
    test_human_flag_off_keeps_the_legacy_skip_log()
    print("wildcard human commander buy tests passed")
