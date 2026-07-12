Private ['_boundaries','_camps','_eStart','_half','_initied','_limit','_minus','_near','_nearTownsE','_nearTownsW','_require','_resTowns','_total','_town','_towns','_wStart','_z'];

waitUntil {townInit};

//--- Special Towns mode.
switch (missionNamespace getVariable "WFBE_C_TOWNS_STARTING_MODE") do {
	//--- 50-50.
	case 1: {
		_half = round(count towns)/2;
		_wStart = (west Call WFBE_CO_FNC_GetSideLogic) getVariable "wfbe_startpos";
		_eStart = (east Call WFBE_CO_FNC_GetSideLogic) getVariable "wfbe_startpos";

		_nearTownsW = [];
		_nearTownsE = [];
		
		_near = [_wStart,towns] Call SortByDistance;
		if (count _near > 0) then {
			for [{_z = 0},{_z < _half},{_z = _z + 1}] do {_nearTownsW = _nearTownsW + [_near select _z]};
		};
		
		_nearTownsE = (towns - _nearTownsW);
		
		{
			_x setVariable ['sideID',WESTID,true];
			_camps = _x getVariable "camps";
			{_x setVariable ['sideID',WESTID,true]} forEach _camps;
		} forEach _nearTownsW;
		{
			_x setVariable ['sideID',EASTID,true];
			_camps = _x getVariable "camps";
			{_x setVariable ['sideID',EASTID,true]} forEach _camps;
		} forEach _nearTownsE;
	};
	
	//--- Nearby Towns.
	case 2: {
		_total = count towns;
		_wStart = (west Call WFBE_CO_FNC_GetSideLogic) getVariable "wfbe_startpos";
		_eStart = (east Call WFBE_CO_FNC_GetSideLogic) getVariable "wfbe_startpos";
		_limit = floor(_total / 6);
		_nearTownsW = [];
		_nearTownsE = [];
		
		_near = [_wStart,towns] Call SortByDistance;
		if (count _near > 0) then {
			for [{_z = 0},{_z < _limit},{_z = _z + 1}] do {_nearTownsW = _nearTownsW + [_near select _z]};
		};
		
		_near = [_eStart,(towns - _nearTownsW)] Call SortByDistance;
		if (count _near > 0) then {
			for [{_z = 0},{_z < _limit},{_z = _z + 1}] do {_nearTownsE = _nearTownsE + [_near select _z]};
		};
		
		{
			_x setVariable ['sideID',WESTID,true];
			_camps = _x getVariable "camps";
			{_x setVariable ['sideID',WESTID,true]} forEach _camps;
		} forEach _nearTownsW;
		{
			_x setVariable ['sideID',EASTID,true];
			_camps = _x getVariable "camps";
			{_x setVariable ['sideID',EASTID,true]} forEach _camps;
		} forEach _nearTownsE;
	};
	
	//--- Random Towns (25% East, 25% West, 50% Res).
	case 3: {
		_total = count towns;
		_half = round(count towns)/4;
		_minus = round(count towns)/2;
		_boundaries = missionNamespace getVariable 'WFBE_BOUNDARIESXY';
		_nearTownsW = [];
		_resTowns = [];
		_towns = +towns;
		
		//--- Use boundaries to determinate the center if possible.
		if !(isNil '_boundaries') then {
			Private ["_dis1","_dis2","_e","_posF1","_posF2","_posx","_posy","_searchArea","_size"];
			//--- Attempt to set the center of the island resistance.
			_searchArea = [(_boundaries / 2)-0.1,(_boundaries / 2)+0.1,0];
			_posx = _searchArea select 0;
			_posy = _searchArea select 0;
			_size = _boundaries/5;
			_e = sqrt((_size)^2 - (_size)^2);
			_posF1 = [_posx + (sin (90) * _e),_posy + (cos (90) * _e)];
			_posF2 = [_posx - (sin (90) * _e),_posy - (cos (90) * _e)];
			_total = 2 * _size;
			
			//--- Determinate resistance towns.
			{
				_position = getPos _x;
				
				_dis1 = _position distance _posF1;
				_dis2 = _position distance _posF2;
				if (_dis1+_dis2 < _total) then {
					_resTowns = _resTowns + [_x];
				};
				
				if (count _resTowns >= _minus) exitWith {};
			} forEach towns;
			
			//--- Update Towns.
			_towns = _towns - _resTowns;
			_e = count _towns;
			
			//--- Check if we couldn't reach 50% Res.
			if (count _resTowns < _minus) then {
				for '_z' from 0 to _e-1 do {
					_town = _towns select round(random((count _towns)-1));
					_towns = _towns - [_town];
					
					_resTowns = _resTowns + [_town];
					
					if (count _resTowns >= _minus) exitWith {};
				};
			};
			
			//--- Update Towns Again.
			_towns = _towns - _resTowns;
			_e = count _towns;
			
			//--- Assign west or east towns.
			for '_z' from 0 to totalTowns-_minus-1 do {
				_town = _towns select round(random((count _towns)-1));
				_towns = _towns - [_town];
				if (count _nearTownsW < _half) then {
					_nearTownsW = _nearTownsW + [_town];
					_town setVariable ['sideID',WESTID,true];
					_camps = _town getVariable "camps";
					{_x setVariable ['sideID',WESTID,true]} forEach _camps;
				} else {
					_town setVariable ['sideID',EASTID,true];
					_camps = _town getVariable "camps";
					{_x setVariable ['sideID',EASTID,true]} forEach _camps;
				};
			};
		} else {
			//--- No boundaries defined, we use a random system.
			for '_z' from 0 to _minus-1 do {
				_town = _towns select round(random((count _towns)-1));
				_towns = _towns - [_town];
				if (count _nearTownsW < _half) then {
					_nearTownsW = _nearTownsW + [_town];
					_town setVariable ['sideID',WESTID,true];
					_camps = _town getVariable "camps";
					{_x setVariable ['sideID',WESTID,true]} forEach _camps;
				} else {
					_town setVariable ['sideID',EASTID,true];
					_camps = _town getVariable "camps";
					{_x setVariable ['sideID',EASTID,true]} forEach _camps;
				};
			};
		};
		
		
	};
};

//--- Patrols v2: the old fixed-random-towns patrol flagging is RETIRED. Patrols are now
//--- a 3-level side upgrade (WFBE_UP_PATROLS) driven by Server\FSM\server_side_patrols.sqf
//--- (spawn at the friendly town nearest the HQ, frontline gravitation, capped per side).

//--- [town-coord logger] One-shot dump of every town's real map position, for the
//--- post-match report renderer's TOWN_COORDS table (Tools/MatchReport). Towns are
//--- engine Locations, so their positions are STATIC per map - this only needs to run
//--- once per world to harvest exact coords (Chernarus + Takistan). Default OFF; flip
//--- WFBE_C_LOG_TOWN_COORDS=1 for a single boot, grep the RPT for "TOWNPOS|", paste the
//--- values into matchdata.TOWN_COORDS, then turn it back off. Server-side, zero gameplay
//--- effect. Line shape: TOWNPOS|v1|<world>|<name>|<x>|<y>
if ((missionNamespace getVariable ["WFBE_C_LOG_TOWN_COORDS", 0]) == 1) then {
	{
		private ["_nm","_p"];
		_nm = _x getVariable ["name", "unknown"];
		_p  = getPos _x;
		diag_log Format ["TOWNPOS|v1|%1|%2|%3|%4", worldName, _nm, round(_p select 0), round(_p select 1)];
	} forEach towns;
	diag_log Format ["TOWNPOS|v1|%1|__COUNT__|%2|0", worldName, count towns];
};

//--- ===== TEST-ONLY fast-bench town cap (WFBE_C_TEST_TOWN_CAP, default -1 = off; declared in
//--- Common\Init\Init_CommonConstants.sqf's TEST HARNESS block next to WFBE_C_TEST_POPTIER_PIN) =====
//--- When >0: keep only the N towns nearest EACH side's start position (wfbe_startpos, already set by
//--- Init_Server.sqf before this file is Call-compiled - Server\Init\Init_Server.sqf:747 runs before :1089)
//--- ACTIVE, using the same [pos,towns] Call SortByDistance utility the "Nearby Towns" mode above already
//--- uses. Every OTHER town is dropped from towns[] and flagged wfbe_inactive=true - the SAME "town doesn't
//--- exist for gameplay" mechanism Common\Init\Init_Town.sqf already uses for TownTemplate-disabled towns
//--- (Init_Town.sqf:30-33), so every consumer that trusts towns[] (server_town_ai.sqf's whole activation
//--- loop, server_town.sqf supply, AI_Commander_AssignTowns, patrols, GUI town lists) automatically skips
//--- them - no deletion of the town object/camps/depot model, so nothing that already holds a reference
//--- breaks. Pairs with WFBE_C_TEST_TEAM_CAP + WF_Debug for a "2 teams + 1 town" minutes-fast dev bench.
//--- -1/0 = off (this whole block is skipped; no effect on live play).
private ["_testTownCap"];
_testTownCap = missionNamespace getVariable ["WFBE_C_TEST_TOWN_CAP", -1];
if (_testTownCap > 0) then {
	private ["_capWStart","_capEStart","_capAll","_capKeep","_capNear","_capN","_capDropped","_z2"];
	_capWStart = (west Call WFBE_CO_FNC_GetSideLogic) getVariable ["wfbe_startpos", [0,0,0]];
	_capEStart = (east Call WFBE_CO_FNC_GetSideLogic) getVariable ["wfbe_startpos", [0,0,0]];
	_capAll  = +towns;
	_capKeep = [];
	{
		_capNear = [_x, _capAll] Call SortByDistance;
		_capN = _testTownCap min (count _capNear);
		for [{_z2 = 0},{_z2 < _capN},{_z2 = _z2 + 1}] do {
			if !((_capNear select _z2) in _capKeep) then {_capKeep = _capKeep + [_capNear select _z2]};
		};
	} forEach [_capWStart, _capEStart];
	_capDropped = 0;
	{
		if !(_x in _capKeep) then {
			_x setVariable ["wfbe_inactive", true, true];
			towns = towns - [_x];
			_capDropped = _capDropped + 1;
		};
	} forEach _capAll;
	diag_log format ["FASTBENCH|v1|TOWN_CAP|cap=%1|kept=%2|dropped=%3|total=%4", _testTownCap, count _capKeep, _capDropped, count _capAll];
	["INFORMATION", Format ["Init_Towns.sqf: WFBE_C_TEST_TOWN_CAP=%1 active - kept %2 towns (nearest %1 per side), dropped %3 (marked wfbe_inactive).", _testTownCap, count _capKeep, _capDropped]] Call WFBE_CO_FNC_LogContent;
};

townInitServer = true;

["INITIALIZATION", "Init_Towns.sqf: Town starting mode is done."] Call WFBE_CO_FNC_LogContent;
