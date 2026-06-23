Private ["_allowCustom","_buildings","_charge","_funds","_get","_loadDefault","_listbp","_mode","_price","_skip","_spawn","_spawnInside","_typeof","_unit","_weaps"];

_unit = _this select 0;
_spawn = _this select 1;
_loadDefault = true;
_typeof = typeOf _spawn;

WFBE_Client_IsRespawning = false;
_allowCustom = true;

// Marty: Respawn creates a fresh player object, so restart AFK tracking before any movement occurs.
_unit setVariable ["lastActionTime", time];
_unit setVariable ["lastPosition", position _unit];

//--- Default gear enforcement on mobile respawn.
if ((missionNamespace getVariable "WFBE_C_RESPAWN_MOBILE") == 2) then {
	if (_typeof in (missionNamespace getVariable Format ["WFBE_%1AMBULANCES",sideJoinedText])) then {_allowCustom = false};
};
//--- Default gear enforcement on redeploy truck respawn (same mode gate as mobile).
if ((missionNamespace getVariable ["WFBE_C_UNITS_REDEPLOYTRUCK",0]) > 0 && (missionNamespace getVariable "WFBE_C_RESPAWN_MOBILE") == 2) then {
	if (_typeof in (missionNamespace getVariable [Format ["WFBE_%1REDEPLOYTRUCKS",sideJoinedText],[]])) then {_allowCustom = false};
};

//--- Default gear enforcement on leader respawn.
if ((missionNamespace getVariable "WFBE_C_RESPAWN_LEADER") == 2) then {
	if (_spawn == leader group _unit) then {_allowCustom = false};
};

//--- Respawn.
if (_spawn isKindOf "Man") then {_spawn = vehicle _spawn};
_spawnInside = false;
if (_typeof in (missionNamespace getVariable Format ["WFBE_%1AMBULANCES",sideJoinedText]) && alive _spawn) then {
	if (_spawn emptyPositions "cargo" > 0 && !(locked _spawn)) then {_unit moveInCargo _spawn;_spawnInside = true};
};
if ((missionNamespace getVariable ["WFBE_C_UNITS_REDEPLOYTRUCK",0]) > 0 && _typeof in (missionNamespace getVariable [Format ["WFBE_%1REDEPLOYTRUCKS",sideJoinedText],[]]) && alive _spawn) then {
	if (_spawn emptyPositions "cargo" > 0 && !(locked _spawn)) then {_unit moveInCargo _spawn;_spawnInside = true};
};

if !(_spawnInside) then {
	if (sideJoined == resistance) then {
		//--- GUER respawn: honor the player's SELECTED town when valid; otherwise a random friendly town (resistance-held or neutral; never WEST/EAST = safe haven).
		private ["_owned","_t"];
		_owned = [];
		{ if (((_x getVariable ["sideID",-1]) != WFBE_C_WEST_ID) && {(_x getVariable ["sideID",-1]) != WFBE_C_EAST_ID}) then {_owned = _owned + [_x]} } forEach towns;
		if (count _owned == 0) then {_owned = towns};
		//--- B74.1 merge: keep the respawn-guard's _spawn preference (b71 harvest) AND Naval's HVT deck-spawn.
		_t = objNull;
		if (!isNull _spawn && {_spawn in _owned}) then {_t = _spawn};
		if (isNull _t) then {_t = _owned select (floor (random (count _owned)))};
		if (_t getVariable ["wfbe_is_naval_hvt", false]) then {
			_unit setPosASL [(getPos _t) select 0, (getPos _t) select 1, ((_t getVariable ["wfbe_naval_deckz", 16]) + 2)];
		} else {
			_unit setPos ([getPos _t, 5, 15] Call GetRandomPosition);
		};
	} else {
		_unit setPos ([getPos _spawn,10,20] Call GetRandomPosition);
	};
};

//--- B67 (Ray 2026-06-21) item #3: IED anti-farm kill tagging. The A2-OA "killed" EH does not name the ammo,
//--- so we tag the killer here: when a GUER player detonates a BAF_ied magazine, stamp wfbe_ied_recent = time
//--- (broadcast so the server can read it in RequestOnUnitKilled.sqf, which then pays only the 30% IED bounty).
//--- Fired EH params (A2 OA): [unit, weapon, muzzle, mode, ammo, magazine, projectile]; index 5 = magazine class.
//--- Idempotent across respawns via a per-unit flag (the unit is fresh each respawn, but belt-and-braces).
if ((missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0 && {sideJoined == resistance}) then {
	if !(_unit getVariable ["wfbe_ied_eh_added", false]) then {
		_unit setVariable ["wfbe_ied_eh_added", true];
		_unit addEventHandler ["Fired", {
			private ["_shooter","_mag"];
			_shooter = _this select 0;
			_mag = _this select 5;
			if (!isNil "_mag" && {typeName _mag == "STRING"} && {(_mag find "BAF_ied") == 0}) then {
				_shooter setVariable ["wfbe_ied_recent", time, true];
			};
		}];
	};
};

//--- Loadout.
if (!isNil {_unit getVariable "wfbe_custom_gear"} && !WFBE_RespawnDefaultGear && _allowCustom) then {
	_mode = missionNamespace getVariable "WFBE_C_RESPAWN_PENALTY";
	
	if (_mode in [0,2,3,4,5]) then {
		//--- Calculate the price/funds.
		_skip = false;
		_gear_cost = _unit getVariable "wfbe_custom_gear_cost";
		if (_mode != 0) then {
			_price = 0;
			
			//--- Get the mode pricing.
			switch (_mode) do {
				case 2: {_price = _gear_cost};
				case 3: {_price = round(_gear_cost/2)};
				case 4: {_price = round(_gear_cost/4)};
				case 5: {_price = _gear_cost};
			};
			
			//--- Are we charging only on mobile respawn?
			_charge = true;
			if (_mode == 5) then {
				_buildings = (sideJoined) Call WFBE_CO_FNC_GetSideStructures;
				if (_spawn in _buildings || _spawn == ((sideJoined) Call WFBE_CO_FNC_GetSideHQ)) then {_charge = false};
			};
			
			//--- Charge if possible.
			_funds = Call GetPlayerFunds;
			if (_funds >= _price && _charge) then {
				-(_price) Call ChangePlayerFunds;
				(Format[localize 'STR_WF_CHAT_Gear_RespawnCharge',_price]) Call GroupChatMessage;
			};
			
			//--- Check that the player has enough funds.
			if (_funds < _price) then {_skip = true};
		};
		
		//--- Use the respawn loadout.
		if !(_skip) then {
			_get = _unit getVariable "wfbe_custom_gear";
			[_unit, _get select 0, _get select 1, _get select 4, _get select 2, _get select 3] Call WFBE_CO_FNC_EquipUnit;
			_loadDefault = false;
		};
	};
};

//--- Load the default loadout.
if (_loadDefault) then {
	Private ["_default"];
	_default = [];
	switch (WFBE_SK_V_Type) do {

case "Spotter": {_default = missionNamespace getVariable Format["WFBE_%1_DefaultGearSpot", WFBE_Client_SideJoinedText]};

case "Officer": {_default = missionNamespace getVariable Format["WFBE_%1_DefaultGearOfficer", WFBE_Client_SideJoinedText]};

case "Soldier": {_default = missionNamespace getVariable Format["WFBE_%1_DefaultGearSoldier", WFBE_Client_SideJoinedText]};

case "Engineer": {_default = missionNamespace getVariable Format["WFBE_%1_DefaultGearEngineer", WFBE_Client_SideJoinedText]};

case "SpecOps": {_default = missionNamespace getVariable Format["WFBE_%1_DefaultGearLock", WFBE_Client_SideJoinedText]};

case "Medic": {_default = missionNamespace getVariable Format["WFBE_%1_DefaultGearMedic", WFBE_Client_SideJoinedText]};
};
	
	//_default = missionNamespace getVariable Format["WFBE_%1_DefaultGear", WFBE_Client_SideJoinedText];
	if (count _default <= 3) then {
		[_unit, _default select 0, _default select 1, _default select 2] Call WFBE_CO_FNC_EquipUnit;
	} else {
		[_unit, _default select 0, _default select 1, _default select 2, _default select 3, _default select 4] Call WFBE_CO_FNC_EquipUnit;
	};
};

//--- Command Deck: re-apply persisted skin class after respawn.
//--- sleep 0.5 first so the engine completes unit creation before we swap models.
if (WFBE_C_SKIN_SELECTOR == 1 && {WFBE_SkinSelector_Applied}) then {
	Private ["_uid","_skinKey","_savedSkin"];
	_uid     = getPlayerUID _unit;
	_skinKey = "WFBE_SkinSelector_Skin_" + _uid;
	_savedSkin = missionNamespace getVariable [_skinKey, ""];
	if (_savedSkin != "") then {
		_unit setVariable ["WFBE_SkinSelector_PendingRespawnSkin", _savedSkin];
		[_unit] spawn {
			Private ["_u","_cls"];
			_u = _this select 0;
			sleep 0.5;
			_cls = _u getVariable ["WFBE_SkinSelector_PendingRespawnSkin", ""];
			if (_cls != "" && {alive _u} && {vehicle _u == _u}) then {
				[_cls] execVM "WASP\actions\SkinSelector\SkinSelector_Apply.sqf";
			};
		};
	};
};
