/* Common_SpectatorEventFeed.sqf  (spectator v8 DEFINITIVE rebuild 2026-08-01)
   Server/HC-side compact Fired/Killed event forwarder for the caster auto-director.
   LOCALITY (Codex trap #1): AI Fired/Killed event handlers fire on the machine where the
   unit is LOCAL - for this mission that is the dedicated server and the headless clients,
   never the caster's client. So each AI-hosting machine runs this file (ExecVM from
   Server\Init\Init_Server.sqf and Headless\Init\Init_HC.sqf):
     - a 4s sweep attaches O(1) Fired/Killed enqueue EHs to LOCAL armed belligerent units
       (and their crewed vehicles) exactly once per machine (wfbe_sev claim var, local-only);
     - EH bodies do NOTHING but a ring-buffer append (no nearEntities, no sleeps, per-unit
       1s fired rate limit) - O(1) as mandated;
     - the SERVER batches new events to every client at <=1Hz as
       WFBE_SPECTATOR_EVENTS = [seq, serverTime, [[t,x,y,sideID,kind], ...]] (kind 0=fired,
       1=killed; bounded, only NEW events per packet, max 30);
     - each HC forwards its new events to the server over the registered SpectatorEvents
       PVF channel (Server\PVFunctions\SpectatorEvents.sqf merges them into the same ring).
   Clients receive the packet via the PVEH registered in Common\Init\Init_PublicVariables.sqf
   and the caster director assigns each event to the nearest fight track / town.
   Captive units (deadspawn pen/park bodies) and CIV never enqueue - parked bodies must not
   fabricate fights (Codex audit finding).
   A2-OA-1.64 safe; scheduled (ExecVM) so the waits below are legal. */
Private ["_isHC","_i"];

if (isNil "commonInitComplete") then {commonInitComplete = false};
waitUntil {commonInitComplete};
_isHC = (!isNil "isHeadLessClient" && {isHeadLessClient});
if (!(isServer || _isHC)) exitWith {};
if ((missionNamespace getVariable ["WFBE_C_SPECTATOR", 0]) <= 0) exitWith {};
if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_EVENTFEED", 1]) <= 0) exitWith {};
if (missionNamespace getVariable ["WFBE_SEV_STARTED", false]) exitWith {}; //--- one instance per machine.
WFBE_SEV_STARTED = true;

//--- 64-slot ring + monotonic write index: EH appends are O(1), readers trail the index.
WFBE_SEV_RING = [];
_i = 0;
while {_i < 64} do {WFBE_SEV_RING = WFBE_SEV_RING + [[]]; _i = _i + 1};
WFBE_SEV_WI = 0;

WFBE_CO_FNC_SpectatorEvEnqueue = {
	//--- _this = [t, x, y, sideID, kind]; O(1), callable from unscheduled EH context.
	WFBE_SEV_RING set [(missionNamespace getVariable ["WFBE_SEV_WI", 0]) % 64, _this];
	WFBE_SEV_WI = (missionNamespace getVariable ["WFBE_SEV_WI", 0]) + 1;
};

diag_log Format ["SPECTATE|v8|eventfeed|start|server=%1|hc=%2", isServer, _isHC];

if (isServer) then {
	//--- <=1Hz batch broadcaster: publishes only NEW events, bounded to the last 30.
	[] spawn {
		Private ["_seq","_ri","_wi","_batch","_j","_e"];
		_seq = 0;
		_ri = 0;
		WFBE_SPECTATOR_EVENTS = [0, 0, []];
		while {true} do {
			sleep 1;
			_wi = missionNamespace getVariable ["WFBE_SEV_WI", 0];
			if (_wi > _ri) then {
				if ((_wi - _ri) > 30) then {_ri = _wi - 30};
				_batch = [];
				_j = _ri;
				while {_j < _wi} do {
					_e = WFBE_SEV_RING select (_j % 64);
					if ((typeName _e) == "ARRAY" && {(count _e) >= 5}) then {_batch = _batch + [_e]};
					_j = _j + 1;
				};
				_ri = _wi;
				if ((count _batch) > 0) then {
					_seq = _seq + 1;
					WFBE_SPECTATOR_EVENTS = [_seq, time, _batch];
					publicVariable "WFBE_SPECTATOR_EVENTS";
				};
			};
		};
	};
};

if (_isHC) then {
	//--- HC forwarder: ship new local events to the server over the registered PVF channel.
	[] spawn {
		Private ["_ri","_wi","_batch","_j","_e"];
		_ri = 0;
		while {true} do {
			sleep 1;
			_wi = missionNamespace getVariable ["WFBE_SEV_WI", 0];
			if (_wi > _ri) then {
				if ((_wi - _ri) > 30) then {_ri = _wi - 30};
				_batch = [];
				_j = _ri;
				while {_j < _wi} do {
					_e = WFBE_SEV_RING select (_j % 64);
					if ((typeName _e) == "ARRAY" && {(count _e) >= 5}) then {_batch = _batch + [_e]};
					_j = _j + 1;
				};
				_ri = _wi;
				if ((count _batch) > 0) then {
					["SpectatorEvents", _batch] Call WFBE_CO_FNC_SendToServer;
				};
			};
		};
	};
};

//--- EH attach sweep: LOCAL armed belligerent units + their crewed vehicles, once per machine.
[] spawn {
	Private ["_u","_v"];
	while {true} do {
		{
			if (!isNil "_x") then {
				_u = _x; //--- capture before any inner forEach rebinds _x (A2-OA gotcha)
				if (!isNull _u && {alive _u} && {local _u} && {(side _u) in [west, east, resistance]} && {!(_u getVariable ["wfbe_sev", false])} && {(count (weapons _u)) > 0}) then {
					_u setVariable ["wfbe_sev", true];
					_u setVariable ["wfbe_sev_sid", (side _u) Call GetSideID];
					_u addEventHandler ["Fired", {
						Private ["_u2","_p2"];
						_u2 = _this select 0;
						if ((time - (_u2 getVariable ["wfbe_sev_lf", -99])) > 1) then {
							_u2 setVariable ["wfbe_sev_lf", time];
							if (alive _u2 && {!(captive _u2)}) then {
								_p2 = getPos _u2;
								[time, _p2 select 0, _p2 select 1, _u2 getVariable ["wfbe_sev_sid", -1], 0] Call WFBE_CO_FNC_SpectatorEvEnqueue;
							};
						};
					}];
					_u addEventHandler ["Killed", {
						Private ["_u2","_p2"];
						_u2 = _this select 0;
						if (!isNull _u2 && {!(captive _u2)}) then {
							_p2 = getPos _u2;
							[time, _p2 select 0, _p2 select 1, _u2 getVariable ["wfbe_sev_sid", -1], 1] Call WFBE_CO_FNC_SpectatorEvEnqueue;
						};
					}];
				};
				if (!isNull _u && {alive _u}) then {
					_v = vehicle _u;
					if (_v != _u && {local _v} && {!(_v getVariable ["wfbe_sev", false])}) then {
						_v setVariable ["wfbe_sev", true];
						_v setVariable ["wfbe_sev_sid", (side _u) Call GetSideID];
						_v addEventHandler ["Fired", {
							Private ["_u2","_p2"];
							_u2 = _this select 0;
							if ((time - (_u2 getVariable ["wfbe_sev_lf", -99])) > 1) then {
								_u2 setVariable ["wfbe_sev_lf", time];
								_p2 = getPos _u2;
								[time, _p2 select 0, _p2 select 1, _u2 getVariable ["wfbe_sev_sid", -1], 0] Call WFBE_CO_FNC_SpectatorEvEnqueue;
							};
						}];
						_v addEventHandler ["Killed", {
							Private ["_u2","_p2"];
							_u2 = _this select 0;
							if (!isNull _u2) then {
								_p2 = getPos _u2;
								[time, _p2 select 0, _p2 select 1, _u2 getVariable ["wfbe_sev_sid", -1], 1] Call WFBE_CO_FNC_SpectatorEvEnqueue;
							};
						}];
					};
				};
			};
		} forEach allUnits;
		sleep 4;
	};
};
