/*
	Action_BuildFOB.sqf — GUER "Build FOB" addAction handler (B75 guer-tech).

	Added to a GUER FOB delivery truck in Common\Init\Init_Unit.sqf when its class is in WFBE_C_GUER_FOB_TRUCKS.
	The action condition already restricts it to a nearby resistance player at a real (flagged) FOB truck. This
	resolves WHICH factory the truck builds from its class index, places the factory a short distance in front of the
	truck, runs a client-side restriction PRE-check (immediate feedback) and asks the SERVER to build it
	authoritatively (RequestFOBStructure.sqf re-validates, reserves the FOB token until construction confirms its start,
	then runs the standard GUER construction and consumes the truck). FOB amounts are unlimited - you can extend near an existing GUE factory or
	bring another truck for another factory; the only gates are the per-type token + the enemy-town/base no-build zone.

	A2 OA 1.62/1.63 safe: array-form private only, `_arr + [x]` (no pushBack), no params/isEqualType, titleText/hint.

	_this = [target(truck), caller(player), actionId, args]
*/
private ["_truck","_player","_idx","_facType","_dir","_pos","_avail","_structures","_structIndex","_structureDistances","_flatRadius"];
_truck  = _this select 0;
_player = _this select 1;

if (isNull _truck || {!alive _truck}) exitWith {};
if (side group player != resistance) exitWith {};
if !(_truck getVariable ["wfbe_is_guer_fob", false]) exitWith {};

//--- Which factory does this truck build? Index into WFBE_C_GUER_FOB_TRUCKS == [Barracks, Light, Heavy] index.
_idx = (missionNamespace getVariable ["WFBE_C_GUER_FOB_TRUCKS", []]) find (typeOf _truck);
if (_idx < 0) exitWith {};
_facType = (missionNamespace getVariable ["WFBE_C_GUER_FOB_STRUCTS", ["Barracks","Light","Heavy"]]) select _idx;
_flatRadius = missionNamespace getVariable ["WFBE_C_STRUCTURES_FLAT_RADIUS", 10];
_structures = missionNamespace getVariable Format ['WFBE_%1STRUCTURES', str resistance];
_structIndex = _structures find _facType;
if (_structIndex >= 0) then {
	_structureDistances = missionNamespace getVariable Format ['WFBE_%1STRUCTUREDISTANCES', str resistance];
	if (_structIndex < (count _structureDistances) && {(typeName (_structureDistances select _structIndex)) == "SCALAR"}) then {
		_flatRadius = _flatRadius max (_structureDistances select _structIndex);
	};
};

//--- Token available for this type? (Server re-checks authoritatively; this is for instant feedback.)
_avail = missionNamespace getVariable ["WFBE_GUER_FOB_AVAIL", [0,0,0]];
if (_idx >= (count _avail) || {(_avail select _idx) <= 0}) exitWith {
	titleText ["No FOB of this type is available - destroy more enemy factories of this type first.", "PLAIN DOWN"];
};

//--- Placement: a short distance directly in front of the truck, facing the truck's heading. Snap z to ground.
_dir = getDir _truck;
_pos = _truck modelToWorld [0, (missionNamespace getVariable ["WFBE_C_GUER_FOB_BUILD_DIST", 22]), 0];
_pos set [2, 0];

//--- Client PRE-check (the server is authoritative; this just avoids a wasted round-trip + gives instant feedback).
//--- Check the actual configured factory footprint rather than the generic 10m construction default.
if ([_pos, _flatRadius] Call WFBE_FNC_GuerFobBlocked) exitWith {
	titleText ["Restricted area - choose dry, flat ground that fits the FOB factory.", "PLAIN DOWN"];
};

["RequestFOBStructure", [_facType, _pos, _dir, _truck, _player]] Call WFBE_CO_FNC_SendToServer;
titleText [Format ["Building FOB %1 ...", _facType], "PLAIN DOWN"];
