Private ["_map","_fpvCooldown","_fpvWasAlive","_fpvState","_fpvRemain","_fpvTTL",
         "_fpvElapsed","_battPct","_battFull","_battEmpty","_battBar","_battI",
         "_hvtList","_platform","_carHolder","_hSID","_carrierOwned",
         "_scudState","_scudCost","_scudCooldownKey","_scudLast","_scudRemain",
         "_funds","_liveDrones","_mxPos","_scudTargeting","_scudTargetPos",
         "_t","_tm","_ts","_minStr","_secStr","_x"];

//--- fable/drones-menu: GUER Drone Operations menu (idd=32000). GR-2026-07-03a.
//--- Phase-1: FPV card fully live; SCUD card gated behind WFBE_C_GUER_DRONE_SCUD (default 0).
if ((missionNamespace getVariable ["WFBE_C_GUER_DRONES_MENU", 1]) <= 0) exitWith {closeDialog 0};
if (sideJoined != resistance) exitWith {closeDialog 0};

_map = (findDisplay 32000) displayCtrl 32060;

if (!isNull _map) then {
	_map ctrlMapAnimAdd [0, 0.15, player];
	ctrlMapAnimCommit _map;
};

mouseButtonUp = -1;
mouseX = 0.5;
mouseY = 0.5;

_fpvWasAlive   = false;
_scudTargeting = false;
_scudTargetPos = [];

MenuAction = -1;

while {alive player && dialog} do {
	if (!dialog) exitWith {};

	//--- Wallet.
	_funds = call GetPlayerFunds;
	if (isNil "_funds") then {_funds = 0};

	//--- FPV state machine.
	_fpvCooldown = missionNamespace getVariable ["wfbe_fpv_guer_cooldown", 0];
	if (!isNull playerFPV && {alive playerFPV}) then {
		//--- IN FLIGHT: track time for battery bar.
		_fpvWasAlive = true;
		_fpvTTL     = missionNamespace getVariable ["WFBE_C_FPV_DRONE_TTL", 240];
		_fpvElapsed = time - (missionNamespace getVariable ["wfbe_fpv_guer_launch", time]);
		_fpvRemain  = (_fpvTTL - _fpvElapsed) max 0;
		_battPct    = (_fpvRemain / _fpvTTL) max 0;
		_battFull   = floor (_battPct * 10);
		_battEmpty  = 10 - _battFull;
		_battBar    = "[";
		for "_battI" from 0 to (_battFull - 1)  do {_battBar = _battBar + "|"};
		for "_battI" from 0 to (_battEmpty - 1) do {_battBar = _battBar + " "};
		_battBar    = _battBar + "]";
		_fpvState   = 1;
	} else {
		//--- Not in flight: stamp cooldown when drone was alive and just ended.
		if (_fpvWasAlive && {_fpvCooldown <= time}) then {
			missionNamespace setVariable ["wfbe_fpv_guer_cooldown", time + (missionNamespace getVariable ["WFBE_C_FPV_COOLDOWN", 60])];
			_fpvCooldown = missionNamespace getVariable ["wfbe_fpv_guer_cooldown", 0];
		};
		_fpvWasAlive = false;
		if (_fpvCooldown > time) then {
			_fpvRemain = _fpvCooldown - time;
			_fpvState  = 2;
		} else {
			_fpvRemain = 0;
			_fpvState  = 0;
		};
	};

	//--- FPV card update.
	if (_fpvState == 0) then {
		ctrlSetText [32012, "READY - one drone available"];
		ctrlSetText [32014, Format ["$%1", (missionNamespace getVariable ["WFBE_C_FPV_DRONE_COST_GUER", 5000])]];
		ctrlEnable  [32013, _funds >= (missionNamespace getVariable ["WFBE_C_FPV_DRONE_COST_GUER", 5000])];
	};
	if (_fpvState == 1) then {
		_t = round _fpvRemain; if (_t < 0) then {_t = 0};
		_tm = floor (_t / 60); _ts = _t - (_tm * 60);
		_minStr = str _tm; _secStr = str _ts;
		if (_ts < 10) then {_secStr = "0" + _secStr};
		ctrlSetText [32012, Format ["IN FLIGHT %1 %2", _battBar, _minStr + ":" + _secStr]];
		ctrlSetText [32014, "DRONE ACTIVE - 1 in air"];
		ctrlEnable  [32013, false];
	};
	if (_fpvState == 2) then {
		_t = round _fpvRemain; if (_t < 0) then {_t = 0};
		_tm = floor (_t / 60); _ts = _t - (_tm * 60);
		_minStr = str _tm; _secStr = str _ts;
		if (_ts < 10) then {_secStr = "0" + _secStr};
		ctrlSetText [32012, Format ["REARMING - %1", _minStr + ":" + _secStr]];
		ctrlSetText [32014, Format ["$%1 (wait for rearm)", (missionNamespace getVariable ["WFBE_C_FPV_DRONE_COST_GUER", 5000])]];
		ctrlEnable  [32013, false];
	};

	//--- SCUD card (Phase-2; hidden when WFBE_C_GUER_DRONE_SCUD <= 0, default 0).
	if ((missionNamespace getVariable ["WFBE_C_GUER_DRONE_SCUD", 0]) > 0) then {
		//--- Carrier check.
		_hvtList = missionNamespace getVariable ["WFBE_NAVAL_HVT_PLATFORMS", []];
		_platform = objNull;
		_carHolder = "NONE";
		{
			if (!isNull _x && {_x getVariable ["wfbe_is_naval_hvt", false]}) then {
				_hSID = _x getVariable ["sideID", -1];
				if (_hSID == sideID) then {_platform = _x};
				if (_hSID == 0) then {_carHolder = "BLUFOR"};
				if (_hSID == 1) then {_carHolder = "OPFOR"};
				if (_hSID == 2) then {_carHolder = "RESISTANCE"};
			};
		} forEach _hvtList;
		_carrierOwned = !isNull _platform;
		_scudCost = missionNamespace getVariable ["WFBE_C_SCUD_COST_GUER", 40000];

		ctrlShow [32020, true]; ctrlShow [32021, true]; ctrlShow [32022, true];
		ctrlShow [32023, true]; ctrlShow [32024, true];

		if (!_carrierOwned) then {
			_scudState = 0;
			ctrlSetText [32022, "[LOCKED] SEIZE KHE SANH CHARLIE TO ARM"];
			ctrlSetText [32024, Format ["$%1 (carrier required)", _scudCost]];
			ctrlEnable  [32023, false];
		} else {
			_scudCooldownKey = Format ["WFBE_SCUD_LAST_%1", str _platform];
			_scudLast        = missionNamespace getVariable [_scudCooldownKey, -99999];
			_scudRemain      = (missionNamespace getVariable ["WFBE_C_SCUD_COOLDOWN", 300]) - (time - _scudLast);
			if (_scudRemain > 0) then {
				_scudState = 2;
				_t = round _scudRemain; if (_t < 0) then {_t = 0};
				_tm = floor (_t / 60); _ts = _t - (_tm * 60);
				_minStr = str _tm; _secStr = str _ts;
				if (_ts < 10) then {_secStr = "0" + _secStr};
				ctrlSetText [32022, Format ["[COOLDOWN] %1 remaining", _minStr + ":" + _secStr]];
				ctrlSetText [32024, Format ["$%1 (wait for cooldown)", _scudCost]];
				ctrlEnable  [32023, false];
			} else {
				_scudState = 1;
				if (_scudTargeting) then {
					ctrlSetText [32022, "[ARMED] Click map to designate target"];
					ctrlSetText [32024, "Click map -- then TARGET to confirm"];
					ctrlEnable  [32023, false];
				} else {
					ctrlSetText [32022, Format ["[ARMED] carrier payoff ($%1)", _scudCost]];
					ctrlSetText [32024, Format ["$%1", _scudCost]];
					ctrlEnable  [32023, _funds >= _scudCost];
				};
			};
		};

		//--- Map click: designate SCUD impact zone.
		if (mouseButtonUp == 0) then {
			mouseButtonUp = -1;
			if (_scudTargeting && {_scudState == 1}) then {
				_mxPos = _map posScreenToWorld [mouseX, mouseY];
				if (typeName _mxPos == "ARRAY" && {count _mxPos >= 2}) then {
					_scudTargetPos = _mxPos;
					_scudTargeting = false;
					hint Format ["Target designated. Click TARGET to confirm SCUD ($%1).", _scudCost];
				};
			};
		};

		//--- TARGET/FIRE action.
		if (MenuAction == 80) then {
			MenuAction = -1;
			if (_scudState == 1) then {
				if (_funds < _scudCost) then {
					hint "Insufficient funds.";
				} else {
					if (count _scudTargetPos == 0) then {
						_scudTargeting = true;
						hint "Click the map to designate SCUD impact zone.";
					} else {
						["RequestSpecial", ["ScudStrike", sideJoined, _scudTargetPos, clientTeam]] Call WFBE_CO_FNC_SendToServer;
						hint "SCUD strike ordered. Impact inbound.";
						["INFORMATION", Format ["GUI_Menu_GuerDrones.sqf: SCUD ordered by [%1] to %2.", name player, str _scudTargetPos]] Call WFBE_CO_FNC_LogContent;
						_scudTargetPos = [];
						_scudTargeting = false;
					};
				};
			};
		};

	} else {
		//--- SCUD card hidden (Phase-1 / flag off).
		ctrlShow [32020, false]; ctrlShow [32021, false]; ctrlShow [32022, false];
		ctrlShow [32023, false]; ctrlShow [32024, false];
	};

	//--- Live drone count.
	_liveDrones = 0;
	if (!isNull playerFPV && {alive playerFPV}) then {_liveDrones = 1};

	//--- Status strip.
	ctrlSetText [32030, Format ["Wallet: $%1 | Active drones: %2", _funds, _liveDrones]];

	//--- Drone telemetry (under map).
	if (_fpvState == 1) then {
		_t = round _fpvRemain; if (_t < 0) then {_t = 0};
		_tm = floor (_t / 60); _ts = _t - (_tm * 60);
		_minStr = str _tm; _secStr = str _ts;
		if (_ts < 10) then {_secStr = "0" + _secStr};
		ctrlSetText [32061, Format ["FPV: IN FLIGHT - battery %1", _minStr + ":" + _secStr]];
	} else {
		ctrlSetText [32061, "FPV: no active drone"];
	};

	//--- LAUNCH FPV.
	if (MenuAction == 1) then {
		MenuAction = -1;
		if (_fpvState == 0 && {_funds >= (missionNamespace getVariable ["WFBE_C_FPV_DRONE_COST_GUER", 5000])}) then {
			missionNamespace setVariable ["wfbe_fpv_guer_launch", time];
			closeDialog 0;
			ExecVM "Client\Module\FPV\fpv.sqf";
		} else {
			if (_fpvState != 0) then {hint "Drone already active or rearming."};
			if (_funds < (missionNamespace getVariable ["WFBE_C_FPV_DRONE_COST_GUER", 5000])) then {hint "Insufficient funds."};
		};
	};

	//--- BACK.
	if (MenuAction == 90) then {
		MenuAction = -1;
		_scudTargetPos = [];
		_scudTargeting = false;
		closeDialog 0;
		createDialog "WF_Menu";
	};

	sleep 0.15;
};
