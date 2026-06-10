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
         "_staticsList","_isStatic"];

_cls  = _this select 0;
_side = _this select 1;

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
	//--- Check via config: if the classname has a non-empty gunner turret it is a static.
	//--- We do this via getNumber on artilleryScanner + emptyPositions proxy would need an object.
	//--- Cheaper: match known prefixes for crewable statics across all factions.
	private "_clsLower";
	_clsLower = toLower _cls;
	if (
		(_clsLower find "mgnestt")     >= 0 ||
		(_clsLower find "mgbag")       >= 0 ||
		(_clsLower find "mgnest")      >= 0 ||
		(_clsLower find "m2staticmg")  >= 0 ||
		(_clsLower find "kord")        >= 0 ||
		(_clsLower find "dshkm")       >= 0 ||
		(_clsLower find "zu23")        >= 0 ||
		(_clsLower find "ags")         >= 0 ||
		(_clsLower find "mk19")        >= 0 ||
		(_clsLower find "tow")         >= 0 ||
		(_clsLower find "stinger")     >= 0 ||
		(_clsLower find "igla")        >= 0 ||
		(_clsLower find "metis")       >= 0 ||
		(_clsLower find "spg9")        >= 0 ||
		(_clsLower find "m252")        >= 0 ||
		(_clsLower find "2b14")        >= 0 ||
		(_clsLower find "m119")        >= 0 ||
		(_clsLower find "d30")         >= 0 ||
		(_clsLower find "mlrs")        >= 0 ||
		(_clsLower find "baf_gpmg")    >= 0 ||
		(_clsLower find "baf_gmg")     >= 0 ||
		(_clsLower find "baf_l2a1")    >= 0 ||
		(_clsLower find "m2hd")        >= 0 ||
		(_clsLower find "m1129")       >= 0
	) then {
		_isStatic = true;
	};
};

if (_isStatic) exitWith {"STATICS"};

//=============================================================================
// 3. FORTIFICATIONS — walls, barriers, sandbags, wire, hedgehogs, nets, ramparts, nests
//=============================================================================
private "_clsLower2";
_clsLower2 = toLower _cls;
if (
	(_clsLower2 find "hbarrier")          >= 0 ||
	(_clsLower2 find "barrier5x")         >= 0 ||
	(_clsLower2 find "barrier10x")        >= 0 ||
	(_clsLower2 find "bagfence")          >= 0 ||
	(_clsLower2 find "razorwire")         >= 0 ||
	(_clsLower2 find "hedgehog")          >= 0 ||
	(_clsLower2 find "hhedgehog")         >= 0 ||
	(_clsLower2 find "camonet")           >= 0 ||
	(_clsLower2 find "camo_net")          >= 0 ||
	(_clsLower2 find "fort_rampart")      >= 0 ||
	(_clsLower2 find "fort_artillery")    >= 0 ||
	(_clsLower2 find "fortified_nest")    >= 0 ||
	(_clsLower2 find "concrete_wall")     >= 0 ||
	(_clsLower2 find "cncblock")          >= 0
) exitWith {"FORTIFICATIONS"};

//=============================================================================
// 4. Everything else: OTHER (uncapped in v1)
//=============================================================================
"OTHER"
