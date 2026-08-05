"""Regression contract for rejected AICOM buy-unit queue tokens."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PRODUCE = ROOT / (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/"
    "Server/AI/Commander/AI_Commander_Produce.sqf"
)
BUY_UNIT = ROOT / (
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/"
    "Server/Functions/Server_BuyUnit.sqf"
)


def test_producer_records_queue_token_before_spawning_buy_unit() -> None:
    """The auth rejection owns a token already published by the producer."""
    text = PRODUCE.read_text(encoding="utf-8-sig")

    queue_write = text.index('setVariable ["wfbe_queue"')
    spawn = text.index("Spawn AIBuyUnit;", queue_write)

    assert queue_write < spawn


def test_auth_rejection_releases_queue_token_before_refunding() -> None:
    """An early auth exit must release its token before the treasury refund."""
    text = BUY_UNIT.read_text(encoding="utf-8-sig")
    start = text.index('if (_authBad != "") exitWith {')
    end = text.index("_sideID = (_side) Call GetSideID;", start)
    auth_exit = text[start:end]

    release = auth_exit.index('_team setVariable ["wfbe_queue"')
    refund = auth_exit.index("[_side, _price] Call ChangeAICommanderFunds;")

    assert 'typeName _team == "GROUP"' in auth_exit
    assert '_tq = _team getVariable "wfbe_queue";' in auth_exit
    assert 'if (isNil "_tq") then {_tq = []};' in auth_exit
    assert 'if (typeName _tq != "ARRAY") then {_tq = []};' in auth_exit
    assert release < refund
