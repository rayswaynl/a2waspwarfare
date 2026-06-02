//============================================================================
//  Black Market Cache  -  WASP Warfare "mystery" feature (Zargabad low-pop)
//  A supply crate periodically drops at a random town; the first combatant to
//  reach it wins a random reward (cash to their commander, a free light
//  vehicle, or a jackpot of both). Reuses the mission's `towns` list, the
//  commander-economy funcs and WFBE_CO_FNC_CreateVehicle - no new deps.
//  Server-only. Toggle: WFBE_C_MYSTERY_CACHE_ENABLED (default 1).
//  Arma 2 OA SQF only (no remoteExec / no `select {}` filters / no params).
//  Read results in the server RPT: grep "MYSTERY:".
//============================================================================
if (!isServer) exitWith {};
if ((missionNamespace getVariable ["WFBE_C_MYSTERY_CACHE_ENABLED", 1]) <= 0) exitWith {};

waitUntil {!isNil "serverInitComplete" && {serverInitComplete}};
waitUntil {!isNil "towns" && {count towns > 0}};

//--- Reward cash to a side's economy, whether commanded by a human or the AI.
WFBE_MC_GiveFunds = {
	private ["_side","_amt","_team"];
	_side = _this select 0; _amt = _this select 1;
	_team = _side call WFBE_CO_FNC_GetCommanderTeam;
	if (!isNull _team) then { [_team, _amt] call WFBE_CO_FNC_ChangeTeamFunds }
		else { if (!isNil "ChangeAICommanderFunds") then { [_side, _amt] call ChangeAICommanderFunds } };
};

sleep (90 + random 90);   //--- let the war warm up before the first cache

while {true} do {
	sleep (480 + random 240);   //--- 8-12 min between caches

	//--- pick a random initialised town (A2 has no `select {}` filter -> forEach)
	private ["_pool","_town","_pos"];
	_pool = [];
	{ if (!isNil {_x getVariable "supplyValue"}) then { _pool = _pool + [_x] } } forEach towns;
	if (count _pool > 0) then {
		_town = _pool select (floor random count _pool);
		_pos  = getPos _town;

		//--- drop the crate + a GLOBAL map marker (createMarker is broadcast in A2)
		private ["_crate","_mk"];
		_crate = createVehicle ["USBasicAmmunitionBox_EP1", _pos, [], 8, "NONE"];
		clearWeaponCargoGlobal _crate; clearMagazineCargoGlobal _crate; clearItemCargoGlobal _crate;
		_crate addEventHandler ["handleDamage", {false}];   //--- can't be destroyed before it's claimed
		_mk = createMarker ["WFBE_MysteryCache", _pos];
		_mk setMarkerType "mil_warning"; _mk setMarkerColor "ColorYellow";
		_mk setMarkerText "Black Market Cache";
		["INFORMATION", format ["MYSTERY: Black Market Cache dropped near %1 - first team there wins.", _town getVariable "name"]] call WFBE_CO_FNC_LogContent;

		//--- first living WEST/EAST entity within reach claims it (or it times out)
		private ["_winner","_t","_cand"];
		_winner = objNull; _t = 0;
		while {(!isNull _crate) && (alive _crate) && (_t < 360) && (isNull _winner)} do {
			_cand = nearestObjects [_pos, ["Man","Car","Tank","Air"], 12];
			{ if ((isNull _winner) && (alive _x) && (side _x in [west,east])) then { _winner = _x } } forEach _cand;
			if (isNull _winner) then { sleep 3; _t = _t + 3 };
		};
		deleteMarker _mk;

		if (!isNull _winner) then {
			private ["_side","_sideID","_roll","_what","_cls"];
			_side = side _winner; _sideID = _side call WFBE_CO_FNC_GetSideID;
			_cls  = if (_side == west) then {"HMMWV_M998A2_SOV_DES_EP1"} else {"UAZ_Unarmed_TK_EP1"};
			_roll = floor random 3; _what = "";
			switch (_roll) do {
				case 0: { [_side, 6000] call WFBE_MC_GiveFunds; _what = "6000 funds"; };
				case 1: {
					[_cls, _pos, _sideID, random 360, false, true, true, ""] call WFBE_CO_FNC_CreateVehicle;
					_what = "a free vehicle";
				};
				default {
					[_side, 3000] call WFBE_MC_GiveFunds;
					[_cls, _pos, _sideID, random 360, false, true, true, ""] call WFBE_CO_FNC_CreateVehicle;
					_what = "JACKPOT: 3000 funds + a vehicle";
				};
			};
			["INFORMATION", format ["MYSTERY: %1 claimed the cache near %2 -> %3.", _side, _town getVariable "name", _what]] call WFBE_CO_FNC_LogContent;
		} else {
			["INFORMATION", format ["MYSTERY: cache near %1 went unclaimed.", _town getVariable "name"]] call WFBE_CO_FNC_LogContent;
		};
		if (!isNull _crate) then { deleteVehicle _crate };
	};
};
