/*
    Client_AutoRun.sqf
    Client-local double-tap W autorun for A2 OA 1.64.
    The standard rifle-lowered forward-run animation carries the translation;
    the token and cancel helper stop it without taking over normal movement.
*/
Private ["_display","_oldDisplay","_oldEH"];

if ((missionNamespace getVariable ["WFBE_C_CLIENT_AUTORUN", 1]) <= 0) exitWith {};

if (isNil "WFBE_CL_FNC_AutoRunCancel") then {
	WFBE_CL_FNC_AutoRunIsStandingRifle = {
		Private ["_anim","_animChars","_prefixChars","_rifleChars","_prefixValid","_rifleFound","_i","_j","_match"];
		if ((currentWeapon player == primaryWeapon player) && {primaryWeapon player != ""}) then {
			_anim = toLower (animationState player);
			_animChars = toArray _anim;
			_prefixChars = toArray "amovperc";
			_rifleChars = toArray "wrfl";
			_prefixValid = count _animChars >= count _prefixChars;
			if (_prefixValid) then {
				for "_i" from 0 to ((count _prefixChars) - 1) do {
					if ((_animChars select _i) != (_prefixChars select _i)) then {_prefixValid = false};
				};
			};
			if (!_prefixValid) exitWith {false};
			_rifleFound = false;
			if (count _animChars >= count _rifleChars) then {
				for "_i" from 0 to ((count _animChars) - (count _rifleChars)) do {
					_match = true;
					for "_j" from 0 to ((count _rifleChars) - 1) do {
						if ((_animChars select (_i + _j)) != (_rifleChars select _j)) then {_match = false};
					};
					if (_match) then {_rifleFound = true};
				};
			};
			_rifleFound
		} else {
			false
		};
	};

	WFBE_CL_FNC_AutoRunCancel = {
		Private ["_wasActive","_token"];
		_wasActive = missionNamespace getVariable ["WFBE_CL_VAR_AutoRunActive", false];
		_token = (missionNamespace getVariable ["WFBE_CL_VAR_AutoRunToken", 0]) + 1;
		missionNamespace setVariable ["WFBE_CL_VAR_AutoRunActive", false];
		missionNamespace setVariable ["WFBE_CL_VAR_AutoRunToken", _token];
		if (_wasActive) then {
			//--- Vehicle, unconscious, and dead states belong to the engine; do not reset their animation.
			if (alive player && {(vehicle player) == player} && {lifeState player != "UNCONSCIOUS"}) then {
				player playMoveNow "AmovPercMstpSlowWrflDnon";
			};
			hintSilent "Autorun: OFF";
		};
	};

	WFBE_CL_FNC_AutoRunStart = {
		Private ["_token","_standingRifle"];
		if (missionNamespace getVariable ["WFBE_CL_VAR_AutoRunActive", false]) exitWith {};
		_standingRifle = call WFBE_CL_FNC_AutoRunIsStandingRifle;
		if (!_standingRifle) exitWith {hintSilent "Autorun: stand up with a rifle first"};
		if (!alive player || {(vehicle player) != player} || {getDammage player > 0} || {lifeState player == "UNCONSCIOUS"} || {surfaceIsWater (getPos player)} || {dialog}) exitWith {};
		_token = (missionNamespace getVariable ["WFBE_CL_VAR_AutoRunToken", 0]) + 1;
		missionNamespace setVariable ["WFBE_CL_VAR_AutoRunActive", true];
		missionNamespace setVariable ["WFBE_CL_VAR_AutoRunToken", _token];
		hintSilent "Autorun: ON";
		[_token] spawn {
			Private ["_runToken","_progressAnchor","_progressStarted","_currentPos"];
			_runToken = _this select 0;
			_progressAnchor = getPos player;
			_progressStarted = diag_tickTime;
			while {
				missionNamespace getVariable ["WFBE_CL_VAR_AutoRunActive", false] &&
				{(missionNamespace getVariable ["WFBE_CL_VAR_AutoRunToken", 0]) == _runToken} &&
				{alive player} &&
				{(vehicle player) == player} &&
				{getDammage player <= 0} &&
				{lifeState player != "UNCONSCIOUS"} &&
				{!surfaceIsWater (getPos player)} &&
				{!dialog}
			} do {
				if !(call WFBE_CL_FNC_AutoRunIsStandingRifle) exitWith {};
				_currentPos = getPos player;
				if ((_currentPos distance _progressAnchor) >= 0.5) then {
					_progressAnchor = _currentPos;
					_progressStarted = diag_tickTime;
				};
				if ((diag_tickTime - _progressStarted) >= 1.5) exitWith {[] call WFBE_CL_FNC_AutoRunCancel};
				//--- A2 OA 1.64 stock forward-run family; its root motion advances the player.
				//--- Animation commands are globally visible by design; reissue only after drift.
				if ((toLower (animationState player)) != "amovpercmrunslowwrfldf") then {player playMoveNow "AmovPercMrunSlowWrflDf"};
				sleep 0.05;
			};
			if (missionNamespace getVariable ["WFBE_CL_VAR_AutoRunActive", false] && {(missionNamespace getVariable ["WFBE_CL_VAR_AutoRunToken", 0]) == _runToken}) then {
				[] call WFBE_CL_FNC_AutoRunCancel;
			};
		};
	};

	WFBE_CL_FNC_AutoRunKeyDown = {
		Private ["_key","_now","_lastW"];
		_key = _this select 1;
		if (_key in [17,30,31,32]) then {
			if (_key == 17) then {
				_now = diag_tickTime;
				_lastW = missionNamespace getVariable ["WFBE_CL_VAR_AutoRunLastW", -1];
				if (missionNamespace getVariable ["WFBE_CL_VAR_AutoRunActive", false]) then {
					[] call WFBE_CL_FNC_AutoRunCancel;
					missionNamespace setVariable ["WFBE_CL_VAR_AutoRunLastW", -1];
				} else {
					if ((_now - _lastW) <= 0.3) then {
						[] call WFBE_CL_FNC_AutoRunStart;
						missionNamespace setVariable ["WFBE_CL_VAR_AutoRunLastW", -1];
					} else {
						missionNamespace setVariable ["WFBE_CL_VAR_AutoRunLastW", _now];
					};
				};
			} else {
				if (missionNamespace getVariable ["WFBE_CL_VAR_AutoRunActive", false]) then {[] call WFBE_CL_FNC_AutoRunCancel};
			};
		};
		false
	};
};

_display = findDisplay 46;
if (isNull _display) exitWith {};
if (!isNil "WFBE_CL_VAR_AutoRunDisplay") then {
	_oldDisplay = WFBE_CL_VAR_AutoRunDisplay;
	if (!isNull _oldDisplay && {!isNil "WFBE_CL_VAR_AutoRunEH"}) then {
		_oldEH = WFBE_CL_VAR_AutoRunEH;
		_oldDisplay displayRemoveEventHandler ["KeyDown", _oldEH];
	};
};
WFBE_CL_VAR_AutoRunDisplay = _display;
WFBE_CL_VAR_AutoRunEH = _display displayAddEventHandler ["KeyDown", "_this call WFBE_CL_FNC_AutoRunKeyDown"];
