/*
	Set a town's camps to a side.
	 Parameters:
		- Town.
		- Old Side.
		- New Side.
*/

Private ["_camps","_side_old","_side_new","_startingSV","_town","_flag","_newSide","_flagTex","_anyFlag"];

_town = _this select 0;
_side_old = _this select 1;
_side_new = _this select 2;

if (isNil "_town" || {typeName _town != "OBJECT"} || {isNull _town}) exitWith {
	["WARNING", "Server_SetCampsToSide.sqf: null/invalid town - abort"] Call WFBE_CO_FNC_LogContent;
};

//--- Nil-safe camps list (cmdcon44-d class): forEach nil throws and aborts the whole flip mid-town.
_camps = _town getVariable ["camps", []];
if (isNil "_camps") then {_camps = []};
//--- SV heal target: town starting SV (parity with bulk FLIPS_CAMPS path). Nil must not poison setVariable.
_startingSV = _town getVariable ["startingSupplyValue", 30];
if (isNil "_startingSV" || {typeName _startingSV != "SCALAR"}) then {_startingSV = 30};
_newSide = (_side_new) Call WFBE_CO_FNC_GetSideFromID;
_flagTex = missionNamespace getVariable Format["WFBE_%1FLAG", _newSide];
_anyFlag = false;

{
	if (!isNull _x) then {
		//--- sideID + full SV heal so leftover camps match the new town owner (no drained re-flip race).
		_x setVariable ["sideID", _side_new, true];
		_x setVariable ["supplyValue", _startingSV, true];

		//--- Null-guard flag pole (parity with server_town bulk FLIPS_CAMPS / repair-camp harden).
		//--- Bare setFlagTexture on a missing pole is an A2 script error every legacy SetCampsToSide call.
		_flag = _x getVariable ["wfbe_flag", objNull];
		if (!isNull _flag) then {
			_flag setFlagTexture _flagTex;
			_flag setVehicleInit (Format ["this setFlagTexture '%1'", _flagTex]);
			_anyFlag = true;
		};
	};
} forEach _camps;

//--- One processInitCommands bake for all flipped flags (JIP-safe texture replay); not per-camp.
if (_anyFlag) then {processInitCommands};

["INFORMATION",Format ["Server_SetCampsToSide.sqf : [%1] Camps [%2] were set to [%3], previously owned by [%4].", _town getVariable "name", count _camps, _side_new, _side_old]] Call WFBE_CO_FNC_LogContent;

if (count _camps > 0) then {[nil, "AllCampsCaptured",[_town, _side_old, _side_new]] Call WFBE_CO_FNC_SendToClients};
