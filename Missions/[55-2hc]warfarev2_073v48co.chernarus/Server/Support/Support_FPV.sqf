Private["_activeDrone","_activeKey","_ammoClass","_argDriver","_argDrone","_argPayload","_argPlayer","_argTeam","_argToken","_args","_cap","_capExpired","_capExpires","_capKey","_clientSide","_cooldown","_cost","_deny","_detGrace","_driver","_drone","_existingFpvArr","_existingFpvKey","_expectedClass","_expectedPilot","_funds","_inflight","_inflightKey","_mode","_next","_nextKey","_payload","_player","_playerTeam","_replyId","_requestBound","_result","_resultKey","_slotReserved","_sendPrivate","_seatDeadline","_serverSide","_side","_timeStart","_timeout","_uav2Level","_upgrades","_uid"];

//--- OA 1.62+ targeted PVF sender. The shared RequestSpecial bus carries no sender identity, so
//--- capability and purchase results must never use the legacy all-client vanilla broadcast.
_sendPrivate = {
	Private ["_id","_parameters","_pvf","_target","_targetUID"];
	_target = _this select 0;
	_parameters = _this select 1;
	if (count _this > 2) then {
		_id = _this select 2;
	} else {
		if (isNull _target) then {_id = -1} else {_id = owner _target};
	};
	if (count _this > 3) then {
		_targetUID = _this select 3;
	} else {
		if (isNull _target) then {_targetUID = ""} else {_targetUID = getPlayerUID _target};
	};
	if (typeName _id != "SCALAR") exitWith {};
	if (typeName _targetUID != "STRING" || {_targetUID == ""}) exitWith {};
	_pvf = [_targetUID, "CLTFNCHandleSpecial", _parameters];
	if (!isHostedServer) then {
		if (_id > 0) then {
			isNil {WFBE_PVF_FPVPrivate = _pvf; _id publicVariableClient "WFBE_PVF_FPVPrivate"};
		};
	} else {
		_pvf Spawn WFBE_CL_FNC_HandlePVF;
		if (isMultiplayer && {_id > 0}) then {
			isNil {WFBE_PVF_FPVPrivate = _pvf; _id publicVariableClient "WFBE_PVF_FPVPrivate"};
		};
	};
};

_args = _this;
if (typeName _args != "ARRAY") exitWith {
	["WARNING", "Support_FPV.sqf: denied non-array request payload."] Call WFBE_CO_FNC_LogContent;
};
if (count _args < 2) exitWith {
	["WARNING", Format ["Support_FPV.sqf: denied malformed request payload (%1 fields).", count _args]] Call WFBE_CO_FNC_LogContent;
};

_mode = _args select 1;
if (typeName _mode != "STRING") exitWith {
	["WARNING", "Support_FPV.sqf: denied request with invalid mode."] Call WFBE_CO_FNC_LogContent;
};

//--- Phase 1: atomically mint/reuse a short-lived capability and return it only to the
//--- nominated player's owner. A per-UID in-flight reservation blocks overlapping handshakes.
if (_mode == "auth") exitWith {
	Private ["_authBlocked","_authChallenge","_authInflight","_authInflightKey","_authLast","_authLastKey","_authNow","_authPlayer","_authUID","_capValid","_expires","_token"];
	if (count _args < 4) exitWith {};
	_authPlayer = _args select 2;
	_authChallenge = _args select 3;
	if (typeName _authPlayer != "OBJECT" || {isNull _authPlayer}) exitWith {};
	if (typeName _authChallenge != "STRING" || {_authChallenge == ""} || {(count toArray _authChallenge) > 96}) exitWith {};
	if (!alive _authPlayer || {!isPlayer _authPlayer}) exitWith {};
	if (!((side (group _authPlayer)) in [west,east,resistance])) exitWith {};
	if (!((missionNamespace getVariable ["WFBE_C_FPV_DRONE", 0]) > 0)) exitWith {};
	_authUID = getPlayerUID _authPlayer;
	if (_authUID == "") exitWith {};

	_capKey = Format ["wfbe_fpv_cap_server_%1", _authUID];
	_authInflightKey = Format ["wfbe_fpv_purchase_inflight_%1", _authUID];
	//--- SECURITY (harden-in-place, d028 FPV follow-up): "auth" was the one mode with no
	//--- cost/cooldown/registration gate of its own - purchase is bounded by the active-slot
	//--- + rearm cooldown, and status/purchase both require an unguessable secret, but auth can
	//--- be requested for ANY valid player reference with no rate limit at all. A modified
	//--- client could flood this entry point - for its own UID or any other connected player's
	//--- UID - at an unbounded rate for free. Add a per-target-UID minimum interval, mirroring
	//--- the existing per-side cooldown pattern in Support_FPV_Detonate.sqf / Support_ScudStrike.sqf,
	//--- so repeated requests against the same UID are throttled server-side regardless of who
	//--- issues them. The stamp is written before any other work so the gate bounds call
	//--- FREQUENCY, not just the minted-token outcome.
	_authLastKey = Format ["wfbe_fpv_auth_last_%1", _authUID];
	_authBlocked = false;
	_token = "";
	_expires = 0;
	isNil {
		_authInflight = missionNamespace getVariable [_authInflightKey, ""];
		if (typeName _authInflight != "STRING") then {_authInflight = ""};
		if (_authInflight != "") then {
			_authBlocked = true;
		} else {
			_cap = missionNamespace getVariable [_capKey, []];
			_capValid = false;
			if (typeName _cap == "ARRAY" && {count _cap >= 2}) then {
				if (typeName (_cap select 0) == "STRING" && {typeName (_cap select 1) == "SCALAR"}) then {
					if ((_cap select 0) != "" && {(_cap select 1) > time}) then {_capValid = true};
				};
			};
			//--- Only the FRESH-MINT path is rate-limited. Reusing an already-valid capability is a
			//--- cheap read with no state mutation and must stay ungated - throttling it too would let
			//--- a spamming attacker deny a victim's own legitimate reuse for up to 1s at a time,
			//--- which is a WORSE outcome than the flood this hardens against.
			if (_capValid) then {
				_token = _cap select 0;
				_expires = _cap select 1;
			} else {
				_authNow = time;
				_authLast = missionNamespace getVariable [_authLastKey, -1e9];
				if (typeName _authLast != "SCALAR") then {_authLast = -1e9};
				if ((_authNow - _authLast) < 1) then {
					_authBlocked = true;
				} else {
					missionNamespace setVariable [_authLastKey, _authNow];
					_token = Format ["%1:%2:%3:%4", _authUID, floor (diag_tickTime * 1000), floor (random 1000000000), floor (random 1000000000)];
					_expires = time + 15;
					_cap = [_token, _expires];
					missionNamespace setVariable [_capKey, _cap];
				};
			};
		};
	};
	if (_authBlocked) exitWith {
		["WARNING", Format ["Support_FPV.sqf: auth request throttled for UID [%1].", _authUID]] Call WFBE_CO_FNC_LogContent;
	};
	[_authPlayer, ["fpv-auth-token", _token, _expires, _authChallenge]] Call _sendPrivate;
};

//--- A client that did not observe the first result polls by secret token. The server either
//--- replays its cached terminal result, waits while that token is in flight, or records a safe
//--- denial for a purchase that never reached authority. No client-side timeout guesses outcome.
if (_mode == "status") exitWith {
	Private ["_statusCap","_statusCapKey","_statusDriver","_statusDrone","_statusInflight","_statusInflightKey","_statusNext","_statusPlayer","_statusReplyId","_statusResult","_statusResultKey","_statusState","_statusToken","_statusUID"];
	if (count _args < 6) exitWith {};
	_statusPlayer = _args select 2;
	_statusDrone = _args select 3;
	_statusDriver = _args select 4;
	_statusToken = _args select 5;
	if (typeName _statusPlayer != "OBJECT" || {isNull _statusPlayer}) exitWith {};
	if (typeName _statusToken != "STRING" || {_statusToken == ""}) exitWith {};
	if (typeName _statusDrone != "OBJECT") then {_statusDrone = objNull};
	if (typeName _statusDriver != "OBJECT") then {_statusDriver = objNull};
	_statusUID = getPlayerUID _statusPlayer;
	if (_statusUID == "") exitWith {};
	_statusReplyId = owner _statusPlayer;
	_statusCapKey = Format ["wfbe_fpv_cap_server_%1", _statusUID];
	_statusInflightKey = Format ["wfbe_fpv_purchase_inflight_%1", _statusUID];
	_statusResultKey = Format ["wfbe_fpv_purchase_result_server_%1", _statusUID];
	_statusResult = [];
	_statusState = 0;
	isNil {
		_statusResult = missionNamespace getVariable [_statusResultKey, []];
		if (typeName _statusResult == "ARRAY" && {count _statusResult >= 7} && {typeName (_statusResult select 6) == "STRING"} && {(_statusResult select 6) == _statusToken}) then {
			_statusState = 1;
		} else {
			_statusInflight = missionNamespace getVariable [_statusInflightKey, ""];
			if (typeName _statusInflight != "STRING") then {_statusInflight = ""};
			if (_statusInflight == _statusToken) then {
				_statusState = 0;
			} else {
				if (_statusInflight == "") then {
					_statusCap = missionNamespace getVariable [_statusCapKey, []];
					if (typeName _statusCap == "ARRAY" && {count _statusCap >= 1} && {typeName (_statusCap select 0) == "STRING"} && {(_statusCap select 0) == _statusToken}) then {
						missionNamespace setVariable [_statusCapKey, []];
						_statusNext = missionNamespace getVariable [Format ["wfbe_fpv_next_%1", _statusUID], 0];
						if (typeName _statusNext != "SCALAR") then {_statusNext = 0};
						_statusResult = ["fpv-purchase-result", false, _statusNext, "FPV purchase was not completed. Try again.", _statusDrone, _statusDriver, _statusToken];
						missionNamespace setVariable [_statusResultKey, _statusResult];
						_statusState = 1;
					};
				};
			};
		};
	};
	if (_statusState == 1) then {
		[_statusPlayer, _statusResult, _statusReplyId, _statusUID] Call _sendPrivate;
	};
};

if (_mode != "purchase") exitWith {
	["WARNING", Format ["Support_FPV.sqf: denied unknown mode [%1].", _mode]] Call WFBE_CO_FNC_LogContent;
};
if (count _args < 8) exitWith {
	["WARNING", Format ["Support_FPV.sqf: denied malformed purchase payload (%1 fields).", count _args]] Call WFBE_CO_FNC_LogContent;
};

//--- Phase 2: atomically compare-consume the secret token and reserve this UID before any
//--- scheduled yield. Every later semantic denial is cached and privately correlated.
_deny = "";
_drone = objNull;
_playerTeam = grpNull;
_player = objNull;
_driver = objNull;
_side = sideUnknown;
_serverSide = sideUnknown;
_replyId = -1;
_requestBound = false;
_next = 0;
_nextKey = "";
_activeKey = "";

_clientSide = _args select 2;
_argDrone = _args select 3;
_argTeam = _args select 4;
_argPlayer = _args select 5;
_argDriver = _args select 6;
_argToken = _args select 7;
_argPayload = "fpv";
if (count _args > 8) then {_argPayload = _args select 8};

if (typeName _argPlayer != "OBJECT") exitWith {
	["WARNING", "Support_FPV.sqf: denied purchase with an invalid player binding."] Call WFBE_CO_FNC_LogContent;
};
_player = _argPlayer;
if (isNull _player) exitWith {
	["WARNING", "Support_FPV.sqf: denied purchase with a null player binding."] Call WFBE_CO_FNC_LogContent;
};
if (typeName _argToken != "STRING" || {_argToken == ""}) exitWith {
	["WARNING", "Support_FPV.sqf: denied purchase with an invalid capability shape."] Call WFBE_CO_FNC_LogContent;
};
_uid = getPlayerUID _player;
if (_uid == "") exitWith {
	["WARNING", "Support_FPV.sqf: denied purchase without a player UID."] Call WFBE_CO_FNC_LogContent;
};
_replyId = owner _player;
_capKey = Format ["wfbe_fpv_cap_server_%1", _uid];
_inflightKey = Format ["wfbe_fpv_purchase_inflight_%1", _uid];
_resultKey = Format ["wfbe_fpv_purchase_result_server_%1", _uid];
_atomicState = 0;
_capExpires = 0;
_result = [];

//--- isNil code executes unscheduled in A2/OA: cache replay, token compare-consume and the
//--- per-UID in-flight reservation therefore cannot interleave with another spawned request.
isNil {
	_result = missionNamespace getVariable [_resultKey, []];
	if (typeName _result == "ARRAY" && {count _result >= 7} && {typeName (_result select 6) == "STRING"} && {(_result select 6) == _argToken}) then {
		_atomicState = 2;
	} else {
		_inflight = missionNamespace getVariable [_inflightKey, ""];
		if (typeName _inflight != "STRING") then {_inflight = ""};
		if (_inflight == _argToken) then {
			_atomicState = 3;
		} else {
			if (_inflight != "") then {
				_atomicState = 4;
			} else {
				_cap = missionNamespace getVariable [_capKey, []];
				if (typeName _cap != "ARRAY" || {count _cap < 2}) then {
					_atomicState = -1;
				} else {
					if (typeName (_cap select 0) != "STRING" || {typeName (_cap select 1) != "SCALAR"}) then {
						_atomicState = -2;
					} else {
						if (_argToken != (_cap select 0)) then {
							_atomicState = -3;
						} else {
							_capExpires = _cap select 1;
							missionNamespace setVariable [_capKey, []];
							missionNamespace setVariable [_inflightKey, _argToken];
							_requestBound = true;
							_atomicState = 1;
						};
					};
				};
			};
		};
	};
};
if (_atomicState == 2) exitWith {
	[_player, _result, _replyId, _uid] Call _sendPrivate;
};
if (_atomicState != 1) exitWith {};

_capExpired = _capExpires <= time;
if (_capExpired) then {_deny = "FPV purchase capability expired."};

//--- From here on, failures are authenticated and safe to return only to the captured client.
if (typeName _argDrone != "OBJECT") then {_deny = "FPV request carried an invalid drone."} else {_drone = _argDrone};
if (typeName _argTeam != "GROUP") then {if (_deny == "") then {_deny = "FPV request carried an invalid player team."}} else {_playerTeam = _argTeam};
if (typeName _argDriver != "OBJECT") then {if (_deny == "") then {_deny = "FPV request carried an invalid pilot."}} else {_driver = _argDriver};
if (typeName _clientSide != "SIDE" && {_deny == ""}) then {_deny = "FPV request carried an invalid side."};

if (_deny == "" && {isNull _drone}) then {_deny = "FPV drone no longer exists."};
if (_deny == "" && {isNull _playerTeam}) then {_deny = "FPV player team no longer exists."};
if (_deny == "" && {isNull _driver}) then {_deny = "FPV pilot no longer exists."};
if (_deny == "" && {!alive _drone}) then {_deny = "FPV drone is not alive."};
if (_deny == "" && {!alive _driver}) then {_deny = "FPV pilot is not alive."};
if (_deny == "" && {!alive _player}) then {_deny = "FPV operator is not alive."};
if (_deny == "" && {!isPlayer _player}) then {_deny = "FPV operator is not a player."};
if (_deny == "" && {isPlayer _driver}) then {_deny = "FPV pilot must be AI."};
if (_deny == "" && {_playerTeam != group _player}) then {_deny = "FPV player/team binding failed."};
if (_deny == "" && {group _driver == _playerTeam}) then {_deny = "FPV pilot group must be isolated from the player team."};

if (_deny == "") then {
	_side = side (group _player);
	if (_side != _clientSide) then {_deny = "FPV player side does not match the request."};
};
if (_deny == "" && {!(_side in [west,east,resistance])}) then {_deny = "FPV player side is not playable."};
if (_deny == "" && {!((missionNamespace getVariable ["WFBE_C_FPV_DRONE", 0]) > 0)}) then {_deny = "FPV strike drones are disabled."};

_expectedClass = "";
_expectedPilot = "";
_payload = _argPayload;
_ammoClass = missionNamespace getVariable ["WFBE_C_FPV_DRONE_AMMO", "R_57mm_HE"];
if (typeName _payload != "STRING") then {_deny = "FPV payload is invalid."};
if (_deny == "") then {
	_expectedClass = missionNamespace getVariable [Format ["WFBE_%1FPVDRONE", str _side], ""];
	_expectedPilot = missionNamespace getVariable [Format ["WFBE_%1PILOT", str _side], ""];
	if (_payload in ["mq9-cluster","mq9-at"]) then {
		if (!((missionNamespace getVariable ["WFBE_C_UAV2_MQ9_FPV", 0]) > 0) || {!(_side in [west,east])}) then {_deny = "MQ-9 FPV is disabled for this side."};
		_uav2Level = missionNamespace getVariable ["WFBE_C_UAV2_LEVEL", 2];
		_upgrades = (_side) Call WFBE_CO_FNC_GetSideUpgrades;
		if (_deny == "" && {typeName _upgrades != "ARRAY" || {count _upgrades <= WFBE_UP_UAV} || {(_upgrades select WFBE_UP_UAV) < _uav2Level}}) then {_deny = "MQ-9 FPV requires UAV upgrade level 2."};
		if (_deny == "") then {_expectedClass = missionNamespace getVariable [Format ["WFBE_%1UAV", str _side], ""]};
		if (_payload == "mq9-cluster") then {_ammoClass = missionNamespace getVariable ["WFBE_C_UAV2_MQ9_FPV_CLUSTER_AMMO", "Bo_Mk82"]};
		if (_payload == "mq9-at") then {_ammoClass = missionNamespace getVariable ["WFBE_C_UAV2_MQ9_FPV_AT_AMMO", "M_TOW_AT"]};
	};
	if (typeName _expectedClass != "STRING" || {_expectedClass == ""}) then {_deny = "FPV airframe configuration is invalid."};
};
if (_deny == "" && {typeOf _drone != _expectedClass}) then {_deny = "FPV request used the wrong airframe."};
if (_deny == "" && {typeName _expectedPilot != "STRING" || {_expectedPilot == ""}}) then {_deny = "FPV pilot configuration is invalid."};
if (_deny == "" && {typeOf _driver != _expectedPilot}) then {_deny = "FPV request used the wrong pilot."};
if (_deny == "" && {owner _drone != _replyId}) then {_deny = "FPV drone/player network ownership does not match."};
if (_deny == "" && {owner _driver != _replyId}) then {_deny = "FPV pilot/player network ownership does not match."};
if (_deny == "") then {
	_serverSide = side (group _driver);
	if (_serverSide != sideUnknown && {_serverSide != _side}) then {_deny = "FPV drone side does not match the player."};
};

if (_requestBound && {_deny == ""}) then {
	//--- fix(fpv-handoff-race): 1s was tighter than real client->server crew replication under load -
	//--- the purchase PV routinely arrives ahead of the pilot's GetIn update, so healthy launches were
	//--- denied and torn down. The per-UID in-flight reservation blocks overlapping buys and the client
	//--- status poll treats in-flight as "keep waiting", so a longer bounded window is safe; nothing is
	//--- charged until after this gate.
	_seatDeadline = diag_tickTime + 10;
	waitUntil {
		sleep 0.05;
		(driver _drone == _driver) || {diag_tickTime >= _seatDeadline} || {isNull _drone} || {isNull _driver}
	};
	if (isNull _drone || {isNull _driver} || {driver _drone != _driver}) then {_deny = "FPV pilot seating did not replicate to the server."};
	if (_deny == "" && {!alive _drone}) then {_deny = "FPV drone is not alive."};
	if (_deny == "" && {!alive _driver}) then {_deny = "FPV pilot is not alive."};
	if (_deny == "" && {!alive _player}) then {_deny = "FPV operator is not alive."};
};

_existingFpvKey = "";
_existingFpvArr = [];
if (_requestBound && {_deny == ""}) then {
	_existingFpvKey = Format ["wfbe_fpv_det_arr_%1", str _side];
	_existingFpvArr = missionNamespace getVariable [_existingFpvKey, []];
	if (typeName _existingFpvArr != "ARRAY") then {_existingFpvArr = []};
	if (_drone in _existingFpvArr) then {_deny = "FPV drone is already registered."};
};

if (_requestBound && {_deny == ""}) then {
	_nextKey = Format ["wfbe_fpv_next_%1", _uid];
	_next = missionNamespace getVariable [_nextKey, 0];
	if (typeName _next != "SCALAR") then {_next = 0};
	if (_next > time) then {_deny = Format ["FPV launcher rearming: %1s.", round (_next - time)]};
};

_cost = 0;
if (_requestBound && {_deny == ""}) then {
	_cost = missionNamespace getVariable ["WFBE_C_FPV_DRONE_COST", 7500];
	if (_side == resistance && {(missionNamespace getVariable ["WFBE_C_GUER_DRONES_MENU", 1]) > 0}) then {
		_cost = missionNamespace getVariable ["WFBE_C_FPV_DRONE_COST_GUER", 5000];
	};
	if (typeName _cost != "SCALAR" || {_cost < 0}) then {_deny = "FPV cost configuration is invalid."};
};

_cooldown = missionNamespace getVariable ["WFBE_C_FPV_COOLDOWN", 60];
if (_requestBound && {_deny == ""} && {typeName _cooldown != "SCALAR" || {_cooldown < 0}}) then {_deny = "FPV cooldown configuration is invalid."};

_funds = 0;
if (_requestBound && {_deny == ""}) then {
	_funds = _playerTeam getVariable "wfbe_funds";
	if (isNil "_funds" || {typeName _funds != "SCALAR"}) then {_funds = 0};
	if (_funds < _cost) then {_deny = Format ["FPV strike drone needs $%1.", _cost]};
};

if (_deny != "") exitWith {
	_result = ["fpv-purchase-result", false, _next, _deny, _drone, _driver, _argToken];
	isNil {
		missionNamespace setVariable [_resultKey, _result];
		if ((missionNamespace getVariable [_inflightKey, ""]) == _argToken) then {missionNamespace setVariable [_inflightKey, ""]};
	};
	if (_requestBound) then {[_player, _result, _replyId, _uid] Call _sendPrivate};
	["WARNING", Format ["Support_FPV.sqf: purchase DENIED for [%1]: %2", str _player, _deny]] Call WFBE_CO_FNC_LogContent;
};

//--- Atomically check and reserve the per-UID active slot. The in-flight reservation prevents a
//--- second handshake, while this block also closes interleaving with the prior flight watchdog.
_activeKey = Format ["wfbe_fpv_active_%1", _uid];
_activeDrone = objNull;
_slotReserved = false;
isNil {
	_activeDrone = missionNamespace getVariable [_activeKey, objNull];
	if (typeName _activeDrone != "OBJECT") then {_activeDrone = objNull};
	if (!isNull _activeDrone) then {
		if (_activeDrone == _drone) then {
			_deny = "FPV drone is already active.";
		} else {
			_deny = "You already have an FPV drone in the air or settling.";
		};
	} else {
		missionNamespace setVariable [_activeKey, _drone];
		_slotReserved = true;
	};
};

if (_deny != "") exitWith {
	_result = ["fpv-purchase-result", false, _next, _deny, _drone, _driver, _argToken];
	isNil {
		missionNamespace setVariable [_resultKey, _result];
		if ((missionNamespace getVariable [_inflightKey, ""]) == _argToken) then {missionNamespace setVariable [_inflightKey, ""]};
	};
	if (_requestBound) then {[_player, _result, _replyId, _uid] Call _sendPrivate};
	["WARNING", Format ["Support_FPV.sqf: purchase DENIED for [%1]: %2", str _player, _deny]] Call WFBE_CO_FNC_LogContent;
};

//--- Debit and terminal-result publication are one unscheduled transaction. A status poll sees
//--- either the in-flight token or the cached success, never a charged request with no result state.
_result = ["fpv-purchase-result", true, _next, "", _drone, _driver, _argToken];
isNil {
	[_playerTeam, -_cost] Call WFBE_CO_FNC_ChangeTeamFunds;
	missionNamespace setVariable [_resultKey, _result];
	if ((missionNamespace getVariable [_inflightKey, ""]) == _argToken) then {missionNamespace setVariable [_inflightKey, ""]};
};
[_player, _result, _replyId, _uid] Call _sendPrivate;

_timeStart = time;
_timeout = (missionNamespace getVariable ["WFBE_C_FPV_DRONE_TTL", 240]) + 120;
_detGrace = 15;
["INFORMATION", Format ["Support_FPV.sqf: [%1] Team [%2] [%3] launched an FPV strike drone (cost %4).", str _side, _playerTeam, name _player, _cost]] Call WFBE_CO_FNC_LogContent;
//--- SECURITY (fable/fpv-strike-drone): stamp armed-drone ownership token so Support_FPV_Detonate
//--- can verify the requestor has a real drone in the air (one-shot; cleared on watchdog exit).
//--- FIX D8a: per-drone registry, not a per-side singleton. A second same-side drone must not
//--- clobber the first's armed token (was: scalar overwrite -> later "no armed drone token found").
private ["_fpvKey","_fpvArr"];
_fpvKey = Format ["wfbe_fpv_det_arr_%1", str _side];
_fpvArr = missionNamespace getVariable [_fpvKey, []];
if (typeName _fpvArr != "ARRAY") then {_fpvArr = []};
_fpvArr set [count _fpvArr, _drone];
missionNamespace setVariable [_fpvKey, _fpvArr];
//--- Keep the capability server-local on the exact drone object. The detonation request
//--- must present this private purchase capability; a forged client cannot read another
//--- client's local copy, and the server never trusts the request position.
_drone setVariable ["wfbe_fpv_det_cap", _argToken];
_drone setVariable ["wfbe_fpv_det_owner", _replyId];
_drone setVariable ["wfbe_fpv_ammo", _ammoClass];

while {true} do {
	sleep 5;
	if (!(isPlayer (leader _playerTeam)) || !alive _drone || ((time - _timeStart) > _timeout)) exitWith {};
};

//--- Give the owning client a bounded window to deliver the Killed EH request before
//--- removing a dead drone from the exact-match registry. No authority is granted by this
//--- grace alone: the server still requires the per-drone capability below.
if (!alive _drone) then {sleep _detGrace};

//--- Rearm begins when the flight ends, matching the approved IN FLIGHT -> REARMING contract.
//--- Keep the active slot reserved until this watchdog settles so a death/abort cannot race a new buy.
_next = time + _cooldown;
missionNamespace setVariable [_nextKey, _next];
publicVariable _nextKey;
if ((missionNamespace getVariable [_activeKey, objNull]) == _drone) then {
	missionNamespace setVariable [_activeKey, objNull];
};

//--- SECURITY: clear the ownership token so no stale detonation can fire after the drone is gone.
//--- FIX D8a: remove ONLY this drone's own entry - never blind-clobber the whole side's slot
//--- (a sibling same-side drone that is still armed must keep its own token).
private ["_fpvKey2","_fpvArr2"];
_fpvKey2 = Format ["wfbe_fpv_det_arr_%1", str _side];
_fpvArr2 = missionNamespace getVariable [_fpvKey2, []];
if (typeName _fpvArr2 != "ARRAY") then {_fpvArr2 = []};
_fpvArr2 = _fpvArr2 - [_drone];
missionNamespace setVariable [_fpvKey2, _fpvArr2];
if (!isNull _driver && {!isPlayer _driver}) then {if (alive _driver) then {_driver setDammage 1};if (isNil {_driver getVariable "wfbe_trashed"}) then {_driver setVariable ["wfbe_trashed", true];_driver Spawn TrashObject}};
if (!isNull _drone) then {if (alive _drone) then {_drone setDammage 1};if (isNil {_drone getVariable "wfbe_trashed"}) then {_drone setVariable ["wfbe_trashed", true];_drone Spawn TrashObject}};
