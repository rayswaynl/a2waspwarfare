/*
	Common_AICOMArtyPickAmmo.sqf   (claude-gaming 2026-06-29)

	AICOM ARTY AMMO-TYPE SELECTOR. Given an AI-owned artillery hull, its side, the artillery-type
	index (parallel to WFBE_%1_ARTILLERY_AMMOS etc.) and the target position, choose ONE situationally
	appropriate ammo index AND load it onto the gun (reusing the exact same WFBE_CO_FNC_LoadArtilleryAmmo
	mechanism players use from the Tactical Center), so the next FireArtillery burst uses that round and
	WFBE_CO_FNC_HandleArtillery applies the matching FX (smoke / illum / cluster / laser).

	HARD UNLOCK RULE (Ray): the AI may ONLY use an ammo type it has actually RESEARCHED. Candidate ammo
	comes EXCLUSIVELY from WFBE_CO_FNC_GetArtilleryAmmoOptions, which itself gates every special round on
	(GetSideUpgrades select WFBE_UP_ARTYAMMO) >= the per-mag required level. Default HE has no extended-mag
	upgrade requirement, so it is always present -> a side that has not researched arty ammo only ever gets HE.

	FLAG-GATED, DEFAULT OFF: WFBE_C_AICOM_ARTY_AMMOTYPES_ENABLE (inline default 0). When off (or when only HE
	is unlocked) this returns the default HE index and loads nothing extra, so the AI fire path is unchanged.

	Returns the chosen ammo INDEX (the WFBE_%1_ARTILLERY_AMMOS sub-index), default 0 (HE / first listed).

	LOCALITY: AI arty is server-local; LoadArtilleryAmmo forwards to the owning machine if not local, so this
	is safe to call from either AI fire path (Strategy on server, RunCommanderTeam mobile SPG on the HC).

	A2-OA SAFE: no isEqualType/findIf/pushBack/selectRandom/params; 2-arg getVariable only on objects/namespace.
*/
Private ["_arty","_side","_artilleryIndex","_tgtPos","_sideText","_options","_opt","_i","_proj","_chosen","_chosenProj","_smokeList","_illumList","_sadarmList","_laserList","_isNight","_armorNear","_heIndex"];

_arty = _this select 0;
_side = _this select 1;
_artilleryIndex = _this select 2;
_tgtPos = _this select 3;

_sideText = if (typeName _side == "SIDE") then {str _side} else {_side};
_heIndex = 0;

//--- Master switch (inline default OFF). When off: keep the historic behaviour = default HE, load nothing.
if ((missionNamespace getVariable ["WFBE_C_AICOM_ARTY_AMMOTYPES_ENABLE", 0]) <= 0) exitWith {_heIndex};

if (isNull _arty) exitWith {_heIndex};
if (_artilleryIndex < 0) exitWith {_heIndex};

//--- ONLY unlocked ammo: GetArtilleryAmmoOptions already gates each entry on WFBE_UP_ARTYAMMO.
//--- Each option = [displayName, projectileClass, magazineClass, ammoIndex].
_options = [_sideText, _artilleryIndex] Call WFBE_CO_FNC_GetArtilleryAmmoOptions;
if (count _options <= 1) exitWith {_heIndex}; //--- only HE (or nothing) unlocked -> nothing to switch to.

//--- Per-side special projectile lists (already defined in the Core_Artillery configs).
_smokeList  = missionNamespace getVariable Format ["WFBE_%1_ARTILLERY_DEPLOY_SMOKE", _sideText];
_illumList  = missionNamespace getVariable Format ["WFBE_%1_ARTILLERY_AMMO_ILLUMN", _sideText];
_sadarmList = missionNamespace getVariable Format ["WFBE_%1_ARTILLERY_AMMO_SADARM", _sideText];
_laserList  = missionNamespace getVariable Format ["WFBE_%1_ARTILLERY_AMMO_LASER", _sideText];
if (typeName _smokeList  != "ARRAY") then {_smokeList  = []};
if (typeName _illumList  != "ARRAY") then {_illumList  = []};
if (typeName _sadarmList != "ARRAY") then {_sadarmList = []};
if (typeName _laserList  != "ARRAY") then {_laserList  = []};

//--- Situational signals.
//--- NIGHT: sunOrMoon < 1 means the sun is below the horizon (engine-standard night test, A2-OA valid).
_isNight = (sunOrMoon < 1);
//--- ARMOUR at the target: cluster/SADARM top-attack is worth it only against vehicles.
_armorNear = false;
if (typeName _tgtPos == "ARRAY" && {count _tgtPos >= 2}) then {
	{ if (alive _x && {!(_x isKindOf "Man")}) exitWith {_armorNear = true} } forEach (nearestObjects [_tgtPos, ["Tank","Car","Wheeled_APC","Tracked_APC"], 120]);
};

//--- PRIORITY (highest first, only among UNLOCKED options):
//---   1) night + ILLUM unlocked      -> illuminate.
//---   2) armour at target + SADARM    -> cluster/top-attack.
//---   3) otherwise default HE.
//--- (LASER needs a friendly laser designator on target -> left to players, not auto-selected here.
//---  SMOKE/WP screening is reserved for a future explicit screen order; HE remains the AI default.)
_chosen = -1;
_chosenProj = "";

if (_chosen < 0 && {_isNight} && {count _illumList > 0}) then {
	for "_i" from 0 to (count _options) - 1 do {
		_opt = _options select _i;
		_proj = _opt select 1;
		if (_chosen < 0 && {_proj in _illumList}) then {_chosen = _opt select 3; _chosenProj = _proj};
	};
};

if (_chosen < 0 && {_armorNear} && {count _sadarmList > 0}) then {
	for "_i" from 0 to (count _options) - 1 do {
		_opt = _options select _i;
		_proj = _opt select 1;
		if (_chosen < 0 && {_proj in _sadarmList}) then {_chosen = _opt select 3; _chosenProj = _proj};
	};
};

//--- Fall back to HE: the FIRST option whose projectile is NOT a special round (smoke/illum/sadarm/laser).
if (_chosen < 0) then {
	for "_i" from 0 to (count _options) - 1 do {
		_opt = _options select _i;
		_proj = _opt select 1;
		if (_chosen < 0 && {!(_proj in _smokeList)} && {!(_proj in _illumList)} && {!(_proj in _sadarmList)} && {!(_proj in _laserList)}) then {_chosen = _opt select 3; _chosenProj = _proj};
	};
};

//--- Absolute last resort: first listed option (keeps us valid even if every option is a special round).
if (_chosen < 0) then {_chosen = (_options select 0) select 3; _chosenProj = (_options select 0) select 1};

//--- Load the chosen magazine via the SAME helper players use (sets WFBE_A_ArtilleryAmmoSelection, addMagazineTurret + loadMagazine).
[_arty, _sideText, _artilleryIndex, _chosen] Call WFBE_CO_FNC_LoadArtilleryAmmo;

if (WF_Debug) then {
	["INFORMATION", Format ["Common_AICOMArtyPickAmmo: [%1] arty %2 idx %3 -> ammo %4 (%5) night=%6 armor=%7.", _sideText, typeOf _arty, _artilleryIndex, _chosen, _chosenProj, _isNight, _armorNear]] Call WFBE_CO_FNC_LogContent;
};

_chosen
