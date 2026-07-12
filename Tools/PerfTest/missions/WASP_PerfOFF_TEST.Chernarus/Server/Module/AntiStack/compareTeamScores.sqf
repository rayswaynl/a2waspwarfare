private["_side","_name","_uid","_totalSkillBLUFOR","_totalSkillOPFOR","_canJoin","_playersOnBLUFOR","_playersOnOPFOR","_playerNumberDifferenceBLUFOR","_playerNumberDifferenceOPFOR","_player","_totalEffectiveSkillBLUFOR","_totalEffectiveSkillOPFOR"];

_side = _this select 0;
_name = _this select 1;
_uid = _this select 2;
_player = _this select 3;
_totalSkillBLUFOR = _this select 4;
_totalSkillOPFOR = _this select 5;

_playersOnBLUFOR = 0;
_playersOnOPFOR = 0;

_totalEffectiveSkillBLUFOR = _totalSkillBLUFOR;
_totalEffectiveSkillOPFOR = _totalSkillOPFOR;

_diffCoef = 0;

_canJoin = true;

{
	if (isPlayer _x && (side _x == west)) then {
		_playersOnBLUFOR = _playersOnBLUFOR + 1;
	};
} forEach allUnits;

{
	if (isPlayer _x && (side _x == east)) then {
		_playersOnOPFOR = _playersOnOPFOR + 1;
	};
} forEach allUnits;

if (_side == west) then {
	_playersOnBLUFOR = _playersOnBLUFOR - 1;
} else {
	if (_side == east) then {
		_playersOnOPFOR = _playersOnOPFOR - 1;
	};
};

_playerNumberDifferenceBLUFOR = _playersOnBLUFOR - _playersOnOPFOR;
_playerNumberDifferenceOPFOR = _playersOnOPFOR - _playersOnBLUFOR;

if (_playerNumberDifferenceBLUFOR > 0 && ((_playersOnBLUFOR + _playersOnOPFOR) < 8)) then {
	_diffCoef = _playerNumberDifferenceBLUFOR * PLAYER_NUMBER_DIFFERENCE_MODIFIER * 2;
	_totalEffectiveSkillBLUFOR = _totalSkillBLUFOR * (1 + _diffCoef);
} else {
	if (_playerNumberDifferenceBLUFOR > 0 && ((_playersOnBLUFOR + _playersOnOPFOR) < 12)) then {
		_diffCoef = _playerNumberDifferenceBLUFOR * PLAYER_NUMBER_DIFFERENCE_MODIFIER;
		_totalEffectiveSkillBLUFOR = _totalSkillBLUFOR * (1 + _diffCoef);
	} else {
		_diffCoef = 0;
		_totalEffectiveSkillBLUFOR = _totalSkillBLUFOR;
	};
};

if (_playerNumberDifferenceOPFOR > 0 && ((_playersOnBLUFOR + _playersOnOPFOR) < 8)) then {
	_diffCoef = _playerNumberDifferenceOPFOR * PLAYER_NUMBER_DIFFERENCE_MODIFIER * 2;
	_totalEffectiveSkillOPFOR = _totalSkillOPFOR * (1 + _diffCoef);
} else {
	if (_playerNumberDifferenceOPFOR > 0 && ((_playersOnBLUFOR + _playersOnOPFOR) < 12)) then {
		_diffCoef = _playerNumberDifferenceOPFOR * PLAYER_NUMBER_DIFFERENCE_MODIFIER;
		_totalEffectiveSkillOPFOR = _totalSkillOPFOR * (1 + _diffCoef);
	} else {
		_diffCoef = 0;
		_totalEffectiveSkillOPFOR = _totalSkillOPFOR;
	};
};

if (_side == west) then {
	if (_totalEffectiveSkillBLUFOR > _totalEffectiveSkillOPFOR) then {
		_canJoin = false;
		["INFORMATION", Format["CompareTeamScores.sqf: BLUFOR total skills: sum [%1], effective [%2]. OPFOR total skills: sum [%3], effective [%4]. Coef: %5. Player (name: %6) (UID: %7) side: %8. Player can join: [%9]", _totalSkillBLUFOR, _totalEffectiveSkillBLUFOR, _totalSkillOPFOR, _totalEffectiveSkillOPFOR, _diffCoef, _name, _uid, _side, _canJoin]] Call WFBE_CO_FNC_LogContent;
		[leader group _player, "LocalizeMessage", ['Teamstack',_name,_uid,_side]] Call WFBE_CO_FNC_SendToClient;
	};
} else {
	if (_side == east) then {
		if (_totalEffectiveSkillOPFOR > _totalEffectiveSkillBLUFOR) then {
			_canJoin = false;
			["INFORMATION", Format["CompareTeamScores.sqf: BLUFOR total skills: sum [%1], effective [%2]. OPFOR total skills: sum [%3], effective [%4]. Coef: %5. Player (name: %6) (UID: %7) side: %8. Player can join: [%9]", _totalSkillBLUFOR, _totalEffectiveSkillBLUFOR, _totalSkillOPFOR, _totalEffectiveSkillOPFOR, _diffCoef, _name, _uid, _side, _canJoin]] Call WFBE_CO_FNC_LogContent;
			[leader group _player, "LocalizeMessage", ['Teamstack',_name,_uid,_side]] Call WFBE_CO_FNC_SendToClient;
		};
	};
};

["INFORMATION", Format["CompareTeamScores.sqf: BLUFOR total skills: sum [%1], effective [%2]. OPFOR total skills: sum [%3], effective [%4]. Coef: %5. Player (name: %6) (UID: %7) side: %8. Player can join: [%9]", _totalSkillBLUFOR, _totalEffectiveSkillBLUFOR, _totalSkillOPFOR, _totalEffectiveSkillOPFOR, _diffCoef, _name, _uid, _side, _canJoin]] Call WFBE_CO_FNC_LogContent;

_canJoin