/*
	Common_GetDefenseCategory.sqf — WFBE_CO_FNC_GetDefenseCategory
	Maps a defense classname to one of four budget categories:
	  "STATICS"       — crewable weapons (MG, GL, AT/AA pods, mortars, cannons, arty)
	  "FORTIFICATIONS"— walls, barriers, sandbags, razor wire, hedgehogs, camo nets, ramparts, nests
	  "MINES"         — mine-laying defense entries (Sign_Danger = the mine-field placer)
	  "OTHER"         — everything else (ammo crates, MASH, lights, spawn markers) — UNCAPPED in v1

	Uses the side-specific DEFENSES_MG/GL/AAPOD/ATPOD/CANNON/MORTAR arrays where possible,
	then falls back to substring matching for fortification and mine classnames.
	Registers as WFBE_CO_FNC_GetDefenseCategory (loaded in Common\Init\Init_Common.sqf).

	Parameters:
		_this select 0 : classname (String)
		_this select 1 : side (Side) — used to look up faction-specific static arrays

	Returns: category String — "STATICS" | "FORTIFICATIONS" | "MINES" | "OTHER"
*/

private ["_cls","_side","_sideText","_cat",
         "_mgs","_gls","_aapods","_atpods","_cannons","_mortars",
         "_staticsList","_isStatic","_matchAny"];

_cls  = _this select 0;
_side = _this select 1;

//--- A2-safe substring matcher: `find` on STRINGS is an ARMA 3 command - on A2 OA it
//--- throws "Type String, expected Array" (live-burned 2026-06-11: every classname
//--- that reached the substring sections below killed the calling script, including
//--- RequestDefense mid-purchase). _this = [haystackLower, [needle1, needle2, ...]].
_matchAny = {
	private ["_hayA","_needles","_found","_nA","_hl","_nl","_i","_j","_ok"];
	_hayA = toArray (_this select 0);
	_needles = _this select 1;
	_hl = count _hayA;
	_found = false;
	{
		if (!_found) then {
			_nA = toArray _x;
			_nl = count _nA;
			if (_nl > 0 && _nl <= _hl) then {
				for "_i" from 0 to (_hl - _nl) do {
					if (!_found) then {
						_ok = true;
						for "_j" from 0 to (_nl - 1) do {
							if ((_hayA select (_i + _j)) != (_nA select _j)) exitWith {_ok = false};
						};
						if (_ok) then {_found = true};
					};
				};
			};
		};
	} forEach _needles;
	_found
};

//--- Defensive entry guard (live RPT 2026-06-10: one "Undefined variable _cls" at the
//--- toLower below — a caller passed a nil/non-string classname; an abort here can
//--- swallow a placement mid-gate). Unknown input classifies as OTHER (uncapped).
if (isNil "_cls" || {typeName _cls != "STRING"}) exitWith {"OTHER"};

_cat = "OTHER"; // default

//=============================================================================
// 1. MINES — classname check first (faction-neutral: Sign_Danger is the mine placer)
//=============================================================================
if (_cls == "Sign_Danger") exitWith {"MINES"};

//=============================================================================
// 2. STATICS — pull faction-specific arrays (populated by Core_Structures files)
//=============================================================================
_sideText = str _side;
_mgs     = missionNamespace getVariable [Format["WFBE_%1DEFENSES_MG",    _sideText], []];
_gls     = missionNamespace getVariable [Format["WFBE_%1DEFENSES_GL",    _sideText], []];
_aapods  = missionNamespace getVariable [Format["WFBE_%1DEFENSES_AAPOD", _sideText], []];
_atpods  = missionNamespace getVariable [Format["WFBE_%1DEFENSES_ATPOD", _sideText], []];
_cannons = missionNamespace getVariable [Format["WFBE_%1DEFENSES_CANNON",_sideText], []];
_mortars = missionNamespace getVariable [Format["WFBE_%1DEFENSES_MORTAR",_sideText], []];

_staticsList = _mgs + _gls + _aapods + _atpods + _cannons + _mortars;

//--- Also gate WDDM composition guns: any classname that has gunner positions and is
//--- NOT in the fortification list is a static.  For v1, use a second substring pass
//--- below only if the faction arrays don't cover the class.

_isStatic = (_cls in _staticsList);

//--- Supplemental statics: MGNests (crew turrets) not in the faction arrays.
//--- WarfareBMGNest_* classes are the sandbag-ring MG nests.
//--- The searchlight is non-crewable for combat — keep as OTHER.
if (!_isStatic) then {
	//--- Match known prefixes for crewable statics across all factions (A2-safe matcher).
	if ([toLower _cls, ["mgnestt","mgbag","mgnest","m2staticmg","kord","dshkm","zu23","ags","mk19","tow","stinger","igla","metis","spg9","m252","2b14","m119","d30","mlrs","baf_gpmg","baf_gmg","baf_l2a1","m2hd","m1129"]] call _matchAny) then {
		_isStatic = true;
	};
};

if (_isStatic) exitWith {"STATICS"};

//=============================================================================
// 3. FORTIFICATIONS — walls, barriers, sandbags, wire, hedgehogs, nets, ramparts, nests
//=============================================================================
if ([toLower _cls, ["hbarrier","barrier5x","barrier10x","bagfence","razorwire","hedgehog","hhedgehog","camonet","camo_net","fort_rampart","fort_artillery","fortified_nest","concrete_wall","cncblock"]] call _matchAny) exitWith {"FORTIFICATIONS"};

//=============================================================================
// 4. Everything else: OTHER (uncapped in v1)
//=============================================================================
"OTHER"
