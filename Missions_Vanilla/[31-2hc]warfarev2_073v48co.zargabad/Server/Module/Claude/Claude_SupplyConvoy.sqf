//============================================================================
//  [CLAUDE FEATURE - REMOVABLE]   Supply Convoy  -  Zargabad mechanic #3
//  ---------------------------------------------------------------------------
//  Periodically an AI logistics convoy (2 supply trucks) sets out from one of a
//  side's owned towns toward another, flagged on everyone's map. Two outcomes:
//    * it REACHES the destination  -> the owning side is paid a logistics bonus;
//    * it is DESTROYED en route    -> the side that wrecked it gets a (bigger)
//                                      interdiction/cargo bounty.
//  So the owner has reason to escort and the enemy has reason to ambush -> moving
//  fights along Zargabad's road network instead of static town sieges.
//
//  Server-only. Reuses the side supply-truck models, createVehicleCrew, group
//  move orders, and the commander economy (WFBE_CLAUDE_FNC_GiveFunds).
//  Toggle:  WFBE_C_CLAUDE_CONVOY_ENABLED  (default 1)
//  Remove:  delete this file + its line in Claude_Features_Init.sqf.
//  Arma 2 OA SQF only (no remoteExec / no `select {}` / no while-loop exitWith). ~120 LOC.
//============================================================================
if (!isServer) exitWith {};
if ((missionNamespace getVariable ["WFBE_C_CLAUDE_CONVOY_ENABLED", 1]) <= 0) exitWith {};

waitUntil {!isNil "serverInitComplete" && {serverInitComplete}};
waitUntil {!isNil "towns" && {count towns > 0}};

#define CV_ARRIVE_PAY    4000
#define CV_INTERDICT_PAY 6000

//--- towns a side currently owns (A2 has no `select {}` filter -> forEach)
WFBE_CLAUDE_CONVOY_OwnedTowns = {
	private ["_side","_id","_out"];
	_side = _this; _id = _side call WFBE_CO_FNC_GetSideID; _out = [];
	{ if ((_x getVariable ["sideID", -1]) == _id && !isNil {_x getVariable "supplyValue"}) then { _out = _out + [_x] } } forEach towns;
	_out
};

sleep (300 + random 240);   //--- first convoy 5-9 min in

while {true} do {
	if ((missionNamespace getVariable ["WFBE_C_CLAUDE_CONVOY_ENABLED", 1]) > 0) then {
		//--- pick an owning side that holds >= 2 towns
		private "_cands"; _cands = [];
		{ if (count (_x call WFBE_CLAUDE_CONVOY_OwnedTowns) >= 2) then { _cands = _cands + [_x] } } forEach [west, east];
		if (count _cands > 0) then {
			private ["_side","_owned","_start","_dest","_destPos","_truckCls","_trucks","_i","_veh","_g","_mk"];
			_side    = _cands select (floor random count _cands);
			_owned   = _side call WFBE_CLAUDE_CONVOY_OwnedTowns;
			_start   = _owned select (floor random count _owned);
			_dest    = _owned select (floor random count _owned);
			if (_dest == _start) then { _dest = _owned select (((_owned find _start) + 1) mod (count _owned)) };
			_destPos = getPos _dest;
			_truckCls = missionNamespace getVariable [format ["WFBE_%1SUPPLYTRUCK", _side], "V3S_TK_GUE_EP1"];

			//--- spawn 2 crewed trucks and order them toward the destination town
			_trucks = [];
			for "_i" from 0 to 1 do {
				_veh = createVehicle [_truckCls, getPos _start, [], 14, "NONE"];
				if (!isNull _veh) then {
					_veh setVariable ["wfbe_claude_convoy", true, true];
					_g = createGroup _side;   //--- A2 OA has no createVehicleCrew; crew the driver manually (and on _side)
					(_g createUnit [missionNamespace getVariable [format ["WFBE_%1CREW", _side], "TK_GUE_Soldier_EP1"], getPos _veh, [], 0, "FORM"]) moveInDriver _veh;
					_g move _destPos; _g setBehaviour "SAFE"; _g setSpeedMode "LIMITED"; _g setCombatMode "YELLOW";
					_veh addEventHandler ["Killed", {
						private "_k"; _k = _this select 1;
						if (!isNull _k && {side _k in [west,east]}) then { WFBE_CLAUDE_CONVOY_LASTKILLER = side _k };
					}];
					_trucks = _trucks + [_veh];
				};
			};

			if (count _trucks > 0) then {
				WFBE_CLAUDE_CONVOY_LASTKILLER = sideUnknown;
				_mk = createMarker ["WFBE_Claude_Convoy", getPos _start];
				_mk setMarkerType "mil_pickup"; _mk setMarkerColor (if (_side == west) then {"ColorBlue"} else {"ColorRed"});
				_mk setMarkerText format ["%1 supply convoy", _side];
				["INFORMATION", format ["Claude_SupplyConvoy.sqf: %1 convoy departing %2 -> %3.", _side, _start getVariable "name", _dest getVariable "name"]] call WFBE_CO_FNC_LogContent;

				//--- monitor: arrival, destruction, or timeout (~12 min)
				private ["_t","_resolved","_alive","_arrived","_lead"];
				_t = 0; _resolved = false;
				while {!_resolved && (_t < 720)} do {
					sleep 10; _t = _t + 10;
					_alive = 0; _arrived = false;
					{
						if (!isNull _x && {alive _x}) then {
							_alive = _alive + 1;
							_mk setMarkerPos (getPos _x);   //--- marker tracks the lead survivor
							if ((_x distance _destPos) < 110) then { _arrived = true };
						};
					} forEach _trucks;

					if (_arrived) then {
						[_side, CV_ARRIVE_PAY] call WFBE_CLAUDE_FNC_GiveFunds;
						["INFORMATION", format ["Claude_SupplyConvoy.sqf: %1 convoy reached %2 -> +%3 logistics.", _side, _dest getVariable "name", CV_ARRIVE_PAY]] call WFBE_CO_FNC_LogContent;
						_resolved = true;
					} else {
						if (_alive == 0) then {
							if (WFBE_CLAUDE_CONVOY_LASTKILLER in [west,east]) then {
								[WFBE_CLAUDE_CONVOY_LASTKILLER, CV_INTERDICT_PAY] call WFBE_CLAUDE_FNC_GiveFunds;
								["INFORMATION", format ["Claude_SupplyConvoy.sqf: %1 wrecked the %2 convoy -> +%3 interdiction bounty.", WFBE_CLAUDE_CONVOY_LASTKILLER, _side, CV_INTERDICT_PAY]] call WFBE_CO_FNC_LogContent;
							} else {
								["INFORMATION", "Claude_SupplyConvoy.sqf: convoy lost (no claimant)."] call WFBE_CO_FNC_LogContent;
							};
							_resolved = true;
						};
					};
				};

				deleteMarker _mk;
				sleep 45;
				{ if (!isNull _x) then { {deleteVehicle _x} forEach (crew _x); deleteVehicle _x } } forEach _trucks;
			};
		};
	};
	sleep (720 + random 480);   //--- 12-20 min between convoys
};
