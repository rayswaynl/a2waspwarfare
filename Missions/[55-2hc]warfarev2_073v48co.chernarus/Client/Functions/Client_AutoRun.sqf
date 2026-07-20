/*
    Client_AutoRun.sqf
    Client-local double-tap W autorun for A2 OA 1.64.
    The standard rifle-lowered forward-run animation carries the translation;
    the token and cancel helper stop it without taking over normal movement.
*/
Private ["_display","_oldDisplay","_oldEH"];

if ((missionNamespace getVariable ["WFBE_C_CLIENT_AUTORUN", 1]) <= 0) exitWith {};

if (isNil "WFBE_CL_FNC_AutoRunCancel") then {
	WFBE_CL_FNC_AutoRunCancel = {
		Private ["_wasActive","_token"];
		_wasActive = missionNamespace getVariable ["WFBE_CL_VAR_AutoRunActive", false];
		_token = (missionNamespace getVariable ["WFBE_CL_VAR_AutoRunToken", 0]) + 1;
		missionNamespace setVariable ["WFBE_CL_VAR_AutoRunActive", false];
		missionNamespace setVariable ["WFBE_CL_VAR_AutoRunToken", _token];
		if (_wasActive) then {
			if (alive player) then {player switchMove ""};
			hintSilent "Autorun: OFF";
		};
	};

	WFBE_CL_FNC_AutoRunStart = {
		Private ["_token","_stance"];
		if (missionNamespace getVariable ["WFBE_CL_VAR_AutoRunActive", false]) exitWith {};
		if (!alive player || {(vehicle player) != player} || {getDammage player > 0} || {lifeState player == "UNCONSCIOUS"} || {surfaceIsWater (getPos player)} || {dialog}) exitWith {};
		_stance = stance player;
		_token = (missionNamespace getVariable ["WFBE_CL_VAR_AutoRunToken", 0]) + 1;
		missionNamespace setVariable ["WFBE_CL_VAR_AutoRunActive", true];
		missionNamespace setVariable ["WFBE_CL_VAR_AutoRunToken", _token];
		missionNamespace setVariable ["WFBE_CL_VAR_AutoRunStance", _stance];
		hintSilent "Autorun: ON";
		[_token] spawn {
			Private ["_runToken","_runStance"];
			_runToken = _this select 0;
			_runStance = missionNamespace getVariable ["WFBE_CL_VAR_AutoRunStance", stance player];
			while {
				missionNamespace getVariable ["WFBE_CL_VAR_AutoRunActive", false] &&
				{(missionNamespace getVariable ["WFBE_CL_VAR_AutoRunToken", 0]) == _runToken} &&
				{alive player} &&
				{(vehicle player) == player} &&
				{getDammage player <= 0} &&
				{lifeState player != "UNCONSCIOUS"} &&
				{!surfaceIsWater (getPos player)} &&
				{stance player == _runStance} &&
				{!dialog}
			} do {
				//--- A2 OA 1.64 stock forward-run family; its root motion advances the player.
				player playMoveNow "AmovPercMrunSlowWrflDf";
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
