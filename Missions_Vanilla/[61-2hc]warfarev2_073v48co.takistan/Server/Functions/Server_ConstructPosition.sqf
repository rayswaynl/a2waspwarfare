/* Description: Builds a commander-placed defensive "position" — a multi-object composition designed
   in the WDDM editor and stored as a WFBE_NEURODEF_* template. The selected build-menu item is an
   "anchor" classname (a cheap placeholder model used only for the placement ghost); when placed, this
   function resolves the matching composition for the building side and spawns each child by routing it
   through the stock ConstructDefense. That means every crewable child (gun) is manned/scored/artillery-
   enabled exactly like an individually-built defense, and every prop (wall/sandbag/ammo) is placed the
   same way — no duplicated manning logic.

   Called from Server\PVFunctions\RequestDefense.sqf:  [_side,_anchorType,_pos,_dir,_manned] Spawn Server_ConstructPosition;
*/
Private ["_side","_anchorType","_pos","_dir","_manned","_map","_base","_factionSpecific","_tplName","_template","_origin","_created","_i","_entry","_cls","_relPos","_relDir","_worldPos","_worldDir","_one"];
_side       = _this select 0;
_anchorType = _this select 1;
_pos        = _this select 2;
_dir        = _this select 3;
_manned     = _this select 4;

//--- Resolve which composition template this anchor maps to (faction-specific or neutral).
_base = "";
_factionSpecific = false;
_map = if (isNil "WFBE_POSITION_TEMPLATE_MAP") then {[]} else {WFBE_POSITION_TEMPLATE_MAP};
{
	if ((_x select 0) == _anchorType) exitWith {_base = _x select 1; _factionSpecific = _x select 2};
} forEach _map;

if (_base == "") exitWith {
	["ERROR", Format ["Server_ConstructPosition.sqf: no template mapping for anchor [%1].", _anchorType]] Call WFBE_CO_FNC_LogContent;
	[]
};

_tplName = if (_factionSpecific) then {_base + (if (_side == west) then {"_WEST"} else {"_EAST"})} else {_base};
_template = missionNamespace getVariable _tplName;
if (isNil "_template") exitWith {
	["ERROR", Format ["Server_ConstructPosition.sqf: template [%1] is undefined.", _tplName]] Call WFBE_CO_FNC_LogContent;
	[]
};
if (count _template == 0) exitWith {[]};

//--- Convert each child's model-space offset to world space by direct rotation about _pos (Arma dir = CW from north).
//--- (A Land_HelipadEmpty "origin" + modelToWorld was unreliable: the helper spawned at [0,0,0], so the whole
//---  composition built ~12km away at the map corner. Direct trig is deterministic and needs no spawned helper.)

_created = [];
for "_i" from 0 to (count _template - 1) do {
	_entry  = _template select _i;
	_cls    = _entry select 0;
	_relPos = _entry select 1;
	_relDir = _entry select 2;

	_worldPos = [
		(_pos select 0) + (_relPos select 0) * (cos _dir) + (_relPos select 1) * (sin _dir),
		(_pos select 1) - (_relPos select 0) * (sin _dir) + (_relPos select 1) * (cos _dir),
		0
	];
	_worldPos set [2, 0];
	_worldDir = _dir - _relDir;

	//--- Stock defense builder: guns get manned + scored + artillery-enabled; props get placed.
	//--- WDDM children are tagged before manning starts so duplicate crew requests can be filtered.
	_one = [_cls, _side, _worldPos, _worldDir, _manned, false, missionNamespace getVariable "WFBE_C_BASE_DEFENSE_MANNING_RANGE", false, true] Call ConstructDefense;
	if (!isNil "_one") then {
		if (typeName _one == "OBJECT") then {
			_one setVariable ["WFBE_WDDMPositionAnchor", _anchorType, true];
		};
		_created = _created + [_one];
	};
};

//--- (origin helper removed: child positions are computed by direct rotation above)

["INFORMATION", Format ["Server_ConstructPosition.sqf: [%1] position [%2] built (%3 objects).", str _side, _anchorType, count _created]] Call WFBE_CO_FNC_LogContent;
_created
