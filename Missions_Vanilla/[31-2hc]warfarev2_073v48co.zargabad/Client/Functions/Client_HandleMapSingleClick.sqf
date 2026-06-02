/*
	Capture the team leader's shift-click map order so newly spawned units can inherit it.
	Parameters:
		0 - Clicked position.
		1 - Shift pressed.
		2 - Alt pressed.
		3 - Selected units array from onMapSingleClick (mostly unreliable in Arma 2/OA, logged for debug only).
*/

// Marty: Ctrl-click map disband falls back to the legacy setDamage disband method.
Private ["_aiId","_alt","_candidate","_candidateDistance","_candidatePosition","_candidatePosition2D","_candidateVehicle","_clickPosition2D","_ctrlPressed","_distance","_group","_hasCommandableUnits","_message","_position","_range","_selectedUnits","_shift","_storedPosition","_target","_units","_plainClick","_selectedGroupUnits","_targetVehicle","_driver","_gunner","_commander","_crewPriority","_crewUnit","_selectionHandled","_isSelectableMapUnit","_isVehicleIcon"];

_position = _this select 0;
_shift = _this select 1;
_alt = _this select 2;
_selectedUnits = _this select 3;
_ctrlPressed = missionNamespace getVariable "WFBE_CLIENT_MAP_DISBAND_CTRL_DOWN";

// Marty: Only real map clicks refresh command-map activity; merely opening the map never touches this state.
_hasCommandableUnits = ((count (((units group player) Call WFBE_CO_FNC_GetLiveUnits) - [player])) > 0) || ((count (hcAllGroups player)) > 0);
if (_hasCommandableUnits) then {
	missionNamespace setVariable ["WFBE_CLIENT_LAST_MAP_COMMAND_CLICK_TIME", time];
	missionNamespace setVariable ["WFBE_CLIENT_LAST_MAP_COMMAND_CLICK_POS", _position];
	player setVariable ["lastActionTime", time];
	if !(isNil "WFBE_CO_VAR_NotAFK_update") then {WFBE_CO_VAR_NotAFK_update = true};
	// Marty: This is marker text only; it never changes the Warfare commander role.
	if (player getVariable ["WASP_AFK", false]) then {
		player setVariable ["WASP_CommandAndConquer", true, true];
	};
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
		titleText [_message, "PLAIN DOWN"];
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
		titleText [_message, "PLAIN DOWN"];
		false
	};

	if (_distance > _range) exitWith {
		_message = Format ["Disband: click closer to AI %1m/%2m.", round _distance, _range];
		titleText [_message, "PLAIN DOWN"];
		false
	};

	if (_target == player) exitWith {
		_message = "Disband: you cannot disband yourself.";
		titleText [_message, "PLAIN DOWN"];
		false
	};

	if (isPlayer _target) exitWith {
		_message = "Disband: player units are protected.";
		titleText [_message, "PLAIN DOWN"];
		false
	};

	if (_target in playableUnits) exitWith {
		_message = "Disband: playable units are protected.";
		titleText [_message, "PLAIN DOWN"];
		false
	};

	if ((group _target) != (group player)) exitWith {
		_message = "Disband: this unit is not in your group.";
		titleText [_message, "PLAIN DOWN"];
		false
	};

	if !(alive _target) exitWith {
		_message = "Disband: this unit is already dead.";
		titleText [_message, "PLAIN DOWN"];
		false
	};

	_aiId = _target Call WFBE_CL_FNC_GetAIID;
	_target setDamage 1;
	_message = Format ["Disbanded AI %1.", _aiId];
	titleText [_message, "PLAIN DOWN"];
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
if (WF_Debug && !_shift) then {
	vehicle player setPos _position;
	(vehicle player) setVelocity [0,0,-0.1];
	diag_log getPos player;
};

false
