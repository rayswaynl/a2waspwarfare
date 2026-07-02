Private ["_side","_sideID","_unit","_unit_kind"];

_unit 				= _this select 0;
_sideID 	 		= _this select 1;
_unit_kind = typeOf _unit;

_side = (_sideID) Call GetSideFromID;

waitUntil {clientInitComplete}; //--- Wait for the client part.

sleep 2; //--- Wait a bit.

if(side _unit == east && !(_unit hasWeapon "NVGoggles")) then {
	_unit addWeapon "NVGoggles";
};

// --- 				[Side specific initialization] (Run on the desired client team).
if (sideID != _sideID) exitWith {};

Private ["_color","_markerName","_params","_size","_txt","_type"];

//--- Map Marker tracking.
_type = "Vehicle";
_color = missionNamespace getVariable (Format ["WFBE_C_%1_COLOR", _side]);
_size = [5,5];
_txt = "";
_params = [];

unitMarker = unitMarker + 1;
_markerName = Format ["unitMarker%1", unitMarker];

_type = "mil_dot";
_size = [0.5,0.5];
if (group _unit == group player) then {
    _color = "ColorOrange";
	_txt = (_unit) Call GetAIDigit;
};
_params = [_type,_color,_size,_txt,_markerName,_unit,1,true,"DestroyedVehicle",_color,false,_side,[1,1]];

_params Spawn MarkerUpdate;

// --- Trello #90: one-shot paradrop audio + transient drop-zone marker (client-local, friendly side only).
// This file already runs only on the matching client (sideID != _sideID exitWith above).
// Throttled via WFBE_C_LastParatroopSound so a stick of paratroopers does not stack one chime per trooper.
Private ["_lastParaSound"];
_lastParaSound = missionNamespace getVariable ["WFBE_C_LastParatroopSound", -1000];
if (time - _lastParaSound > 8) then {
	missionNamespace setVariable ["WFBE_C_LastParatroopSound", time];
	playSound "commanderNotification";

	Private ["_dzMarker"];
	_dzMarker = createMarkerLocal [Format ["paraDZ_%1", round time], position _unit];
	_dzMarker setMarkerTypeLocal "mil_objective";
	_dzMarker setMarkerColorLocal _color;
	_dzMarker setMarkerTextLocal "Paradrop";
	[_dzMarker] spawn {
		Private ["_m"];
		_m = _this select 0;
		sleep 30;
		deleteMarkerLocal _m;
	};
};

// Marty: Performance Audit counts paratrooper marker spawns separately from regular Init_Unit markers.
if !(isNil "PerformanceAudit_Record") then {
	if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
		["paratrooper_marker_spawn", 0, Format["type:%1;side:%2;markerType:%3;refresh:%4;groupPlayer:%5", _unit_kind, _sideID, _params select 0, _params select 6, group _unit == group player], "CLIENT"] Call PerformanceAudit_Record;
	};
};
