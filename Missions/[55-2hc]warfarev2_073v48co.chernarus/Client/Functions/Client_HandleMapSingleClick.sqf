/*
	Capture the team leader's shift-click map order so newly spawned units can inherit it.
	Parameters:
		0 - Clicked position.
		1 - Shift pressed.
		2 - Alt pressed.
		3 - Selected units array from onMapSingleClick (mostly unreliable in Arma 2/OA, logged for debug only).
*/

// Marty: Ctrl-click map disband falls back to the legacy setDamage disband method.
// GR-2026-07-03a (Ray order: quiet the AI disband popup): the map-shortcut disband result/error
// notices below are delivered as top-right hintSilent, not center-screen titleText, so incidental
// disband feedback (incl. a stuck Ctrl-latch routing plain clicks here) never spams the middle of the
// screen. The deliberate player Command Console disband confirmation (14626/14627) is unchanged.
Private ["_aiId","_alt","_candidate","_candidateDistance","_candidatePosition","_candidatePosition2D","_candidateVehicle","_clickPosition2D","_confirmData","_confirmEnabled","_confirmExpires","_confirmTarget","_ctrlPressed","_disbandNow","_distance","_group","_message","_position","_range","_selectedUnits","_shift","_storedPosition","_target","_units","_plainClick","_selectedGroupUnits","_targetVehicle","_driver","_gunner","_commander","_crewPriority","_crewUnit","_selectionHandled","_isSelectableMapUnit","_isVehicleIcon"];

_position = _this select 0;
_shift = _this select 1;
_alt = _this select 2;
_selectedUnits = _this select 3;
_ctrlPressed = missionNamespace getVariable "WFBE_CLIENT_MAP_DISBAND_CTRL_DOWN";
//--- 2026-07-04: the ctrl latch can STICK when the KeyUp lands on another display (dialog/focus change),
//--- turning every plain map click into a disband attempt (Ray: 'popup all the time'). A held ctrl older
//--- than 20s cannot be a disband gesture - expire it and clear the latch.
if (_ctrlPressed && {(time - (missionNamespace getVariable ["WFBE_CLIENT_MAP_DISBAND_CTRL_TS", -1000])) > 20}) then {
	_ctrlPressed = false;
	missionNamespace setVariable ["WFBE_CLIENT_MAP_DISBAND_CTRL_DOWN", false];
};

// Marty: Ctrl-click selects the nearest AI in the player's group and disbands it immediately.
if (_ctrlPressed) exitWith {
	_range = 75;
	_target = objNull;
	_distance = 999999;
	_units = ((units group player) Call WFBE_CO_FNC_GetLiveUnits) - [player];
	_clickPosition2D = [_position select 0, _position select 1, 0];

	if (count _units == 0) exitWith {
		_message = "Disband: no AI in your group.";
		hintSilent _message; //--- Ray order: AI-disband feedback off center screen (was titleText [...,"PLAIN DOWN"]); non-intrusive top-right hint, matching the Command Console disband channel.
		false
	};

	{
		_candidate = _x;
		_candidateVehicle = vehicle _candidate;
		_candidatePosition = getPos _candidateVehicle;
		_candidatePosition2D = [_candidatePosition select 0, _candidatePosition select 1, 0];
		_candidateDistance = _candidatePosition2D distance _clickPosition2D;

		if (_candidateDistance < _distance) then {
			_target = _candidate;
			_distance = _candidateDistance;
		};
	} forEach _units;

	if (isNull _target) exitWith {
		_message = "Disband: no AI from your group near this map click.";
		hintSilent _message; //--- Ray order: AI-disband feedback off center screen (was titleText [...,"PLAIN DOWN"]); non-intrusive top-right hint, matching the Command Console disband channel.
		false
	};

	if (_distance > _range) exitWith {
		_message = Format ["Disband: click closer to AI %1m/%2m.", round _distance, _range];
		hintSilent _message; //--- Ray order: AI-disband feedback off center screen (was titleText [...,"PLAIN DOWN"]); non-intrusive top-right hint, matching the Command Console disband channel.
		false
	};

	if (_target == player) exitWith {
		_message = "Disband: you cannot disband yourself.";
		hintSilent _message; //--- Ray order: AI-disband feedback off center screen (was titleText [...,"PLAIN DOWN"]); non-intrusive top-right hint, matching the Command Console disband channel.
		false
	};

	if (isPlayer _target) exitWith {
		_message = "Disband: player units are protected.";
		hintSilent _message; //--- Ray order: AI-disband feedback off center screen (was titleText [...,"PLAIN DOWN"]); non-intrusive top-right hint, matching the Command Console disband channel.
		false
	};

	if (_target in playableUnits) exitWith {
		_message = "Disband: playable units are protected.";
		hintSilent _message; //--- Ray order: AI-disband feedback off center screen (was titleText [...,"PLAIN DOWN"]); non-intrusive top-right hint, matching the Command Console disband channel.
		false
	};

	if ((group _target) != (group player)) exitWith {
		_message = "Disband: this unit is not in your group.";
		hintSilent _message; //--- Ray order: AI-disband feedback off center screen (was titleText [...,"PLAIN DOWN"]); non-intrusive top-right hint, matching the Command Console disband channel.
		false
	};

	if !(alive _target) exitWith {
		_message = "Disband: this unit is already dead.";
		hintSilent _message; //--- Ray order: AI-disband feedback off center screen (was titleText [...,"PLAIN DOWN"]); non-intrusive top-right hint, matching the Command Console disband channel.
		false
	};

	_aiId = _target Call WFBE_CL_FNC_GetAIID;
	_disbandNow = true;
	_confirmEnabled = (missionNamespace getVariable ["WFBE_C_DISBAND_CONFIRM", 1]) > 0;
	if (_confirmEnabled) then {
		_confirmData = missionNamespace getVariable ["WFBE_CLIENT_DISBAND_PENDING", []];
		_confirmTarget = objNull;
		_confirmExpires = -1;

		if ((typeName _confirmData) == "ARRAY") then {
			if ((count _confirmData) > 1) then {
				_confirmTarget = _confirmData select 0;
				_confirmExpires = _confirmData select 1;
			};
		};

		if ((isNull _confirmTarget) || {_confirmTarget != _target} || {time > _confirmExpires}) then {
			_confirmData = [_target, time + 3];
			missionNamespace setVariable ["WFBE_CLIENT_DISBAND_PENDING", _confirmData];
			_message = Format ["Hold CTRL-click again within 3s to disband AI %1.", _aiId];
			hintSilent _message; //--- fix(hunt): Ray order - disband feedback stays OFF center screen (matches the eight hintSilent exits above; center-screen titleText regressed in the disband-confirm merge)
			_disbandNow = false;
		} else {
			missionNamespace setVariable ["WFBE_CLIENT_DISBAND_PENDING", []];
		};
	};

	if (_disbandNow) then {
		//--- owner ruling 2026-07-22 20:06 (destructive retire): visible death, never a silent vanish.
		_target setDamage 1;
		_message = Format ["Disbanded AI %1.", _aiId];
		hintSilent _message; //--- fix(hunt): Ray order - disband feedback stays OFF center screen (matches the eight hintSilent exits above; center-screen titleText regressed in the disband-confirm merge)
	};
	false
};

// Marty: Plain map click selects one nearby AI only when no group unit is already selected.
_selectionHandled = call {
	_plainClick = (!_shift && !_alt);
	if !(_plainClick) exitWith {false};

	_selectedGroupUnits = groupSelectedUnits player;
	if ((count _selectedGroupUnits) > 0) exitWith {false};

	_range = 75;
	_target = objNull;
	_targetVehicle = objNull;
	_distance = 999999;
	_units = ((units group player) Call WFBE_CO_FNC_GetLiveUnits) - [player];
	_clickPosition2D = [_position select 0, _position select 1, 0];

	if ((count _units) == 0) exitWith {false};

	{
		_candidate = _x;
		_candidateVehicle = vehicle _candidate;
		_candidatePosition = getPos _candidateVehicle;
		_candidatePosition2D = [_candidatePosition select 0, _candidatePosition select 1, 0];
		_candidateDistance = _candidatePosition2D distance _clickPosition2D;

		if (_candidateDistance < _distance) then {
			_targetVehicle = _candidateVehicle;
			_distance = _candidateDistance;
		};
	} forEach _units;

	if (isNull _targetVehicle) exitWith {false};
	if (_distance > _range) exitWith {false};

	_isSelectableMapUnit = {
		_crewUnit = _this;
		if (isNull _crewUnit) exitWith {false};
		if !(alive _crewUnit) exitWith {false};
		if (_crewUnit == player) exitWith {false};
		if (isPlayer _crewUnit) exitWith {false};
		if ((group _crewUnit) != (group player)) exitWith {false};
		true
	};

	_target = _targetVehicle;
	_isVehicleIcon = !(_targetVehicle isKindOf "Man");

	if (_isVehicleIcon) then {
		_driver = driver _targetVehicle;
		_gunner = gunner _targetVehicle;
		_commander = commander _targetVehicle;
		_crewPriority = [_driver, _gunner, _commander];
		_target = objNull;

		{
			_crewUnit = _x;
			if (isNull _target) then {
				if (_crewUnit call _isSelectableMapUnit) then {_target = _crewUnit};
			};
		} forEach _crewPriority;
	};

	if !(_target call _isSelectableMapUnit) exitWith {false};

	{player groupSelectUnit [_x, false]} forEach units group player;
	player groupSelectUnit [_target, true];
	true
};

if (_selectionHandled) exitWith {true};

if (_shift && (leader (group player)) == player) then {
	_group = group player;
	_storedPosition = [_position select 0, _position select 1, 0];

	missionNamespace setVariable ["WFBE_CLIENT_LAST_TEAMLEADER_MAP_ORDER_POSITION", _storedPosition];
	missionNamespace setVariable ["WFBE_CLIENT_LAST_TEAMLEADER_MAP_ORDER_GROUP", _group];
	missionNamespace setVariable ["WFBE_CLIENT_LAST_TEAMLEADER_MAP_ORDER_TIME", time];
};

// Preserve the legacy debug teleport on plain map clicks without blocking shift-click move capture.
if ((missionNamespace getVariable ["WFBE_DEBUG_TELEPORT_ARMED", false]) && !_shift) then {	//--- FIX: was "WF_Debug" => every map click teleported (ate the sell/ICBM confirm second-click). Now arm with the "[" key first.
	vehicle player setPos _position;
	(vehicle player) setVelocity [0,0,-0.1];
	diag_log getPos player;
		missionNamespace setVariable ["WFBE_DEBUG_TELEPORT_ARMED", false];	//--- one-shot: disarm after teleporting
		hintSilent "Teleported.";
};

false
