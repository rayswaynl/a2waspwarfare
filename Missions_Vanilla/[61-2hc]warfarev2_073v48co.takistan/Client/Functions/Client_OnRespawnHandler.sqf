Private ["_allowCustom","_buildings","_charge","_funds","_gear_cost","_get","_loadDefault","_listbp","_mode","_price","_skip","_spawn","_spawnInside","_typeof","_unit","_weaps"];

_unit = _this select 0;
_spawn = _this select 1;
_loadDefault = true;
_typeof = typeOf _spawn;

WFBE_Client_IsRespawning = false;
_allowCustom = true;

//--- cmdcon23 RHUD/funds respawn re-home. GROUP respawn (respawn=3) can drop the player into a
//--- DIFFERENT group than the init-time `clientTeam` (frozen at Init_Client.sqf:282 and never
//--- reassigned). The RHUD reads funds via GetPlayerFunds -> (clientTeam) Call GetTeamFunds, so a
//--- stale clientTeam makes the Money row render $0 even when the real group has funds. Re-point
//--- clientTeam at the player's CURRENT group on every respawn so the HUD reads the right group,
//--- and fire ONE authoritative funds re-broadcast (server-side RequestFundsResend is idempotent:
//--- it echoes an absolute stored value, never adds, so this cannot duplicate money). A2-OA-1.64
//--- safe (group player / typeName / SendToServer); idempotent (sets an absolute global, sends once).
if (!isNull (group _unit)) then {clientTeam = group _unit};
if (!isNil "WFBE_Client_SideJoined") then {
	["RequestFundsResend", [_unit, WFBE_Client_SideJoined]] Call WFBE_CO_FNC_SendToServer;
};

//--- cmdcon23 deadspawn-strand fallback. _spawn arrives objNull when the respawn menu's spawn list
//--- was empty or entirely invalid (HQ dead + no live factory = base-overran late game), because
//--- GetClosestEntity returns objNull on an empty list and GUI_RespawnMenu never replaces the objNull
//--- _spawn_at_current. The WEST/EAST else-branch below would then setPos [getPos objNull...] = [0,0,0]
//--- (ocean SW corner) and strand the player. Resolve a real destination here: live side HQ if any,
//--- else the side startpos (a POSITION array, used directly). The GUER branch already self-heals via
//--- a random friendly town, so this is only needed for the non-resistance path. Idempotent (only acts
//--- when _spawn is null), A2-OA-1.64 safe (isNull / GetSideHQ / GetRandomPosition / setPos).
if (isNull _spawn && {sideJoined != resistance}) then {
	private "_fbHQ";
	_fbHQ = (sideJoined) Call WFBE_CO_FNC_GetSideHQ;
	if (!isNull _fbHQ && {alive _fbHQ}) then {
		_spawn = _fbHQ;
		_typeof = typeOf _spawn;
	} else {
		private "_fbPos";
		_fbPos = WFBE_Client_Logic getVariable "wfbe_startpos";
		if (!isNil "_fbPos") then {
			_unit setPos ([_fbPos, 10, 25] Call GetRandomPosition);
			//--- Already delivered to the startpos; skip the object-based setPos branches below.
			_spawn = _unit;
			_typeof = typeOf _spawn;
		};
	};
};

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
		private ["_guerStart","_owned","_t","_usedFallbackPos"];
		_owned = [];
		_usedFallbackPos = false;
		{ if (((_x getVariable ["sideID",-1]) != WFBE_C_WEST_ID) && {(_x getVariable ["sideID",-1]) != WFBE_C_EAST_ID}) then {_owned = _owned + [_x]} } forEach towns;
		//--- B75 (guer-tech FOB): a selected FOB delivery truck is a valid MOBILE spawn candidate ("freely like any
		//--- town"). Add it so the _spawn-in-_owned preference below picks it and setPos lands the player beside it.
		if (!isNull _spawn && {alive _spawn} && {_spawn getVariable ["wfbe_is_guer_fob", false]}) then {_owned = _owned + [_spawn]};
		//--- B75 (guer-tech FOB): a selected BUILT GUER FOB factory is also a valid forward spawn. It is registered in
		//--- the GUER side structures by the construction path (so GetFactories already OFFERS it in
		//--- Client_GetRespawnAvailable), but it carries no wfbe_is_guer_fob flag - so add it here too, or the
		//--- _spawn-in-_owned preference below falls through to a random town.
		if (!isNull _spawn && {alive _spawn} && {_spawn in (resistance Call WFBE_CO_FNC_GetSideStructures)}) then {_owned = _owned + [_spawn]};
		//--- B74.1 merge: keep the respawn-guard's _spawn preference (b71 harvest) AND Naval's HVT deck-spawn.
		_t = objNull;
		if (!isNull _spawn && {_spawn in _owned}) then {_t = _spawn};
		if (isNull _t) then {
			if (count _owned > 0) then {
				_t = _owned select (floor (random (count _owned)));
			} else {
				_guerStart = WFBE_Client_Logic getVariable "wfbe_startpos";
				if (isNil "_guerStart") then {_guerStart = getMarkerPos "GuerTempRespawnMarker"};
				_unit setPos ([_guerStart, 10, 25] Call GetRandomPosition);
				_usedFallbackPos = true;
			};
		};
		if !(_usedFallbackPos) then {
			if (_t getVariable ["wfbe_is_naval_hvt", false]) then {
				_unit setPosASL [(getPos _t) select 0, (getPos _t) select 1, ((_t getVariable ["wfbe_naval_deckz", 16]) + 2)];
			} else {
				_unit setPos ([getPos _t, 5, 15] Call GetRandomPosition);
			};
		};
	} else {
		//--- B74.2: WEST/EAST naval carrier deck-respawn. If the selected/assigned respawn point is a
		//--- naval-HVT town this side holds, deck-spawn on the carrier (mirror the resistance deckZ logic
		//--- above); otherwise keep the normal town/base respawn. _spawn is an object here, so the
		//--- getVariable[name,default] reads are reliable (object namespace, A2-OA-safe).
		if (!isNull _spawn && {_spawn getVariable ["wfbe_is_naval_hvt", false]} && {(_spawn getVariable ["sideID", -1]) == WFBE_Client_SideID}) then {
			_unit setPosASL [(getPos _spawn) select 0, (getPos _spawn) select 1, ((_spawn getVariable ["wfbe_naval_deckz", 16]) + 2)];
		} else {
			_unit setPos ([getPos _spawn,10,20] Call GetRandomPosition);
		};
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
			if (!isNil "_mag" && {typeName _mag == "STRING"} && {_mag in ["BAF_ied_v1","BAF_ied_v2","BAF_ied_v3","BAF_ied_v4"]}) then {
				_shooter setVariable ["wfbe_ied_recent", time, true];
			};
		}];
	};
};

//--- Loadout.
if (!isNil {_unit getVariable "wfbe_custom_gear"} && !WFBE_RespawnDefaultGear && _allowCustom) then {
	_mode = missionNamespace getVariable "WFBE_C_RESPAWN_PENALTY";
	
	if (_mode in [1]) then {
		(Format ["%1: %2", localize "STR_WF_PARAMETER_Respawn_Penalty", localize "STR_WF_PARAMETER_Respawn_Penalty_Remove"]) Call GroupChatMessage;
	};
	if (_mode in [0,2,3,4,5]) then {
		//--- Calculate the price/funds.
		_skip = false;
		_gear_cost = _unit getVariable ["wfbe_custom_gear_cost", 0];
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
			if (_charge && _funds < _price) then {_skip = true}; //--- wiki-wins: only strip gear when actually charging (mode-5-at-base sets _charge=false and charges nothing)
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
	
	//--- GUER-GEARFIX (2026-07-02): same fallback as Init_Client.sqf - a "" skill type (unregistered playerType,
	//--- e.g. the CH-classname GUER slots on Takistan) or a nil per-role WFBE_%1_DefaultGearXXX used to strip the
	//--- respawned player NAKED. Fall back to the faction-wide WFBE_%1_DefaultGear and warn in the RPT.
	if (isNil '_default' || {count _default == 0}) then {
		["WARNING", Format ["Client_OnRespawnHandler.sqf : No role default gear for type [%1] (playerType [%2]) - falling back to WFBE_%3_DefaultGear.", WFBE_SK_V_Type, typeOf _unit, WFBE_Client_SideJoinedText]] Call WFBE_CO_FNC_LogContent;
		_default = missionNamespace getVariable Format["WFBE_%1_DefaultGear", WFBE_Client_SideJoinedText];
	};
	if (!isNil '_default' && {count _default >= 3}) then {
		if (count _default <= 3) then {
			[_unit, _default select 0, _default select 1, _default select 2] Call WFBE_CO_FNC_EquipUnit;
		} else {
			[_unit, _default select 0, _default select 1, _default select 2, _default select 3, _default select 4] Call WFBE_CO_FNC_EquipUnit;
		};
	} else {
		["WARNING", Format ["Client_OnRespawnHandler.sqf : WFBE_%1_DefaultGear is missing/short too - keeping the unit's config gear.", WFBE_Client_SideJoinedText]] Call WFBE_CO_FNC_LogContent;
	};
};

//--- Command Deck: re-apply persisted skin class after respawn.
//--- sleep 0.5 first so the engine completes unit creation before we swap models.
if ((call (compile preprocessFile "WASP\actions\SkinSelector\SkinSelector_Enabled.sqf")) && {missionNamespace getVariable ["WFBE_SkinSelector_Applied", false]}) then {
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
