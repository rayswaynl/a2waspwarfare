/*
	Arm buyer-tagged Takistan SCUDs on the local client.
	Called both by the buyer and by the generic Init_Unit/GetIn lifecycle path so
	the control action and local-driver governor survive a change of player.
*/

Private ["_aid","_v"];

_v = _this;
if (isNull _v) exitWith {};
if (!(_v getVariable ["wfbe_is_tk_scud", false])) exitWith {};

if ((_v getVariable ["wfbe_tk_scud_action", -1]) < 0) then {
	_aid = _v addAction [
		"<t color='#ff9900'>SCUD Fire Mission (map-click)</t>",
		{
			Private ["_caller","_cost","_token","_v"];
			_v = _this select 0;
			_caller = _this select 1;
			if (player getVariable ["wfbe_tk_scud_designating", false]) exitWith { hintSilent parseText "<t color='#F89060'>SCUD: click the target on the map.</t>"; };
			_cost = missionNamespace getVariable ["WFBE_C_ICBM_TEL_SAT_COST", 12000];
			if (((group _caller) Call WFBE_CO_FNC_GetTeamFunds) < _cost) exitWith { hintSilent parseText Format ["<t color='#F8D664'>Not enough funds for a SCUD saturation strike ($%1).</t>", _cost]; };
			hintSilent parseText "<t color='#F89060'>SCUD: click the target on the map.</t>";
			openMap true;
			wfbe_tk_scud_fire_veh = _v;
			player setVariable ["wfbe_tk_scud_designating", true];
			_token = diag_tickTime;
			player setVariable ["wfbe_tk_scud_design_token", _token];
			[player, _token] spawn {
				Private ["_myToken","_p"];
				_p = _this select 0;
				_myToken = _this select 1;
				waitUntil {sleep 0.1; !visibleMap || {isNull _p} || {!(_p getVariable ["wfbe_tk_scud_designating", false])}};
				if ((_p getVariable ["wfbe_tk_scud_designating", false]) && {(_p getVariable ["wfbe_tk_scud_design_token", -1]) == _myToken}) then {
					_p setVariable ["wfbe_tk_scud_designating", false];
					onMapSingleClick {[_pos, _shift, _alt, _units] call WFBE_CL_FNC_HandleMapSingleClick};
				};
			};
			onMapSingleClick {
				onMapSingleClick {[_pos, _shift, _alt, _units] call WFBE_CL_FNC_HandleMapSingleClick};
				openMap false;
				player setVariable ["wfbe_tk_scud_designating", false];
				Private ["_veh"];
				_veh = wfbe_tk_scud_fire_veh;
				if (isNull _veh || {!alive _veh}) exitWith { hintSilent parseText "<t color='#ff5a5a'>That SCUD is gone.</t>"; };
				[playerSide, [_pos select 0, _pos select 1, 0], "SATURATION", group player, 0, _veh] Spawn WFBE_CO_FNC_RequestIcbmTelFire;
				hintSilent parseText "<t color='#F89060'>SCUD saturation order sent (server validates SCUD + range + funds).</t>";
				false
			};
		},
		[], 6, false, true, "", "alive _target && {_this in crew _target} && {(_target getVariable ['wfbe_tk_scud_side', playerSide]) == side _this}"
	];
	_v setVariable ["wfbe_tk_scud_action", _aid];
};

if ((_v getVariable ["wfbe_scud_governor_running", false])) exitWith {};
if (driver _v != player) exitWith {};
_v setVariable ["wfbe_scud_governor_running", true];
[_v] spawn {
	Private ["_cap","_ratio","_s","_v","_vel"];
	_v = _this select 0;
	_cap = missionNamespace getVariable ["WFBE_C_SCUD_SPEED_CAP_KMH", 20];
	while {alive _v && {driver _v == player} && {canMove _v} && {_cap > 0}} do {
		_s = speed _v;
		if (_s > _cap) then {
			_vel = velocity _v;
			_ratio = _cap / _s;
			_v setVelocity [(_vel select 0) * _ratio, (_vel select 1) * _ratio, (_vel select 2) * _ratio];
		};
		sleep 0.1;
	};
	_v setVariable ["wfbe_scud_governor_running", false];
};
