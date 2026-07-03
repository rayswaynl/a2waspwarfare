/* Description: Builds a commander-placed defensive "position" — a multi-object composition designed
   in the WDDM editor and stored as a WFBE_NEURODEF_* template. The selected build-menu item is an
   "anchor" classname (a cheap placeholder model used only for the placement ghost); when placed, this
   function resolves the matching composition for the building side and spawns each child by routing it
   through the stock ConstructDefense. That means every crewable child (gun) is manned/scored/artillery-
   enabled exactly like an individually-built defense, and every prop (wall/sandbag/ammo) is placed the
   same way — no duplicated manning logic.

   Called from Server\PVFunctions\RequestDefense.sqf:  [_side,_anchorType,_pos,_dir,_manned] Spawn Server_ConstructPosition;
*/
Private ["_side","_anchorType","_pos","_dir","_manned","_map","_base","_factionSpecific","_tplName","_template","_origin","_created","_i","_entry","_cls","_relPos","_relDir","_worldPos","_worldDir","_one","_placementID","_flakHostCls","_flakAutoZ","_deckTop","_bb"];
_side       = _this select 0;
_anchorType = _this select 1;
_pos        = _this select 2;
_dir        = _this select 3;
_manned     = _this select 4;

//--- cmdcon44-c (Build 89): flak-tower deck AUTO-HEIGHT. The Flak Tower composition mounts an AA gun on a
//--- non-zero z (the tower deck). Rather than trust a hardcoded deck estimate (the thin illuminant tower's
//--- top platform height was never measured empirically), measure the just-spawned HOST tower's REAL top via
//--- boundingBox and lift the gun to that (self-correcting). Same idiom Ray used in Init_NavalHVT.sqf (B754:
//--- boundingBox carrier-deck measurement replacing a hardcoded 16 guess; boundingBox is A2-OA 1.64-safe).
//--- _deckTop is captured when a GROUND child (z~0) whose class == the configured flak host is created, then
//--- reused for the elevated gun child later in the same composition. Guarded by WFBE_C_DEF_FLAKTOWER_AUTOZ.
_flakHostCls = missionNamespace getVariable ["WFBE_C_DEF_FLAKTOWER_STRUCTURE", "Land_Ind_IlluminantTower"];
_flakAutoZ   = (missionNamespace getVariable ["WFBE_C_DEF_FLAKTOWER_AUTOZ", 1]) > 0;
_deckTop     = 0;

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

if (isNil "WFBE_WDDMPlacementCounter") then { WFBE_WDDMPlacementCounter = 0 };
WFBE_WDDMPlacementCounter = WFBE_WDDMPlacementCounter + 1;
_placementID = format ["%1_%2", _anchorType, str WFBE_WDDMPlacementCounter];

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
			_one setVariable ["WFBE_WDDMPositionAnchor", _placementID, true];
				//--- cmdcon44-c: capture the flak-tower HOST deck height. This ground child (z~0) is the tower;
				//--- measure its real top via boundingBox so the gun child (later in this composition) mounts on
				//--- the actual platform, not a guessed z. boundingBox max-z is the model top above the object's
				//--- position; the host sits at ground z=0 so this IS the deck height. A2-OA 1.64-safe.
				if (_flakAutoZ && {(_relPos select 2) <= 0.1} && {_cls == _flakHostCls}) then {
					_bb = boundingBox _one;
					_deckTop = (_bb select 1) select 2;
					if (WF_Debug) then {
						["DEBUG (Server_ConstructPosition.sqf)", Format ["cmdcon44-c flak host [%1] boundingBox deck top measured = %2 (anchor %3).", _cls, _deckTop, _anchorType]] Call WFBE_CO_FNC_LogContent;
					};
				};
			//--- cmdcon42-g: elevated children (non-zero z offset, e.g. the Flak Tower AA gun on the
			//--- tower deck) - ConstructDefense placed the child at ground (z flattened above), so lift
			//--- it onto the deck now via setPosATL + level it (proposal B.5 roof-mount idiom).
			//--- Static-on-building is physics-fragile in A2 (settle/jitter) -> NEEDS-BOX-VERIFY.
			private ["_zOff"];
			_zOff = _relPos select 2;
			if (_zOff > 0.1) then {
				//--- cmdcon44-c: prefer the auto-measured host deck top over the flag's fallback estimate.
				if (_flakAutoZ && {_deckTop > 0.1}) then { _zOff = _deckTop; };
				_worldPos set [2, _zOff];
				_one setPosATL _worldPos;
				_one setVectorDirAndUp [[sin _worldDir, cos _worldDir, 0], [0,0,1]];
				if (WF_Debug) then {
					["DEBUG (Server_ConstructPosition.sqf)", Format ["cmdcon42-g flak/elevated child [%1] lifted to deck z=%2 at %3 (anchor %4).", _cls, _zOff, _worldPos, _anchorType]] Call WFBE_CO_FNC_LogContent;
				};
				//--- Always-on state line so the tester can confirm the roof-mount fired on the box RPT.
				["INFORMATION", Format ["Server_ConstructPosition.sqf: [%1] elevated child [%2] mounted on deck (z=%3) for anchor [%4].", str _side, _cls, _zOff, _anchorType]] Call WFBE_CO_FNC_LogContent;
			};
		};
		_created = _created + [_one];
	};
};

//--- (origin helper removed: child positions are computed by direct rotation above)

["INFORMATION", Format ["Server_ConstructPosition.sqf: [%1] position [%2] built (%3 objects).", str _side, _anchorType, count _created]] Call WFBE_CO_FNC_LogContent;
_created
