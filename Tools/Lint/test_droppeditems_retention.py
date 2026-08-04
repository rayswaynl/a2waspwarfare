from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MISSION = ROOT / "Missions" / "[55-2hc]warfarev2_073v48co.chernarus"


def test_dropped_items_cleaner_has_age_and_player_retention_gates():
    constants = (MISSION / "Common/Init/Init_CommonConstants.sqf").read_text(
        encoding="utf-8-sig"
    )
    cleaner = (MISSION / "Server/FSM/cleaners/droppeditems_cleaner.sqf").read_text(
        encoding="utf-8-sig"
    )

    assert 'WFBE_C_DROPPEDITEMS_MIN_AGE = 120' in constants
    assert 'WFBE_C_DROPPEDITEMS_PROX = 20' in constants
    assert 'WFBE_C_DROPPEDITEMS_PROX_HOLD = 300' in constants
    assert '_whFirst = _x getVariable "wfbe_wh_first_seen";' in cleaner
    assert 'if (isNull _x) then {} else {' in cleaner
    assert 'if (_minAge > 0 && {_whAge < _minAge}) then {' in cleaner
    assert 'Call WFBE_CO_FNC_RealPlayersNear' in cleaner
    assert 'if (_whNear && {_whAge < (_minAge + _proxHold)}) then {' in cleaner
    assert 'if (!_whSkip) then {' in cleaner
    assert 'heldAge:%8;heldProx:%9' in cleaner
