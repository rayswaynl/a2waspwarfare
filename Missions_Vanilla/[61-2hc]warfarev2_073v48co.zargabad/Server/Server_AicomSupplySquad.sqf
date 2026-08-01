/*
	Server_AicomSupplySquad.sqf - fable/aicom-supply-squad (owner 2026-07-28: "Allow the ai
	commander to run a small supply squad by itself once it reaches its unlock gates (Truck, or
	helicopter)"). That order SUPERSEDES the older do-not-re-propose entry for "AI supply trucks"
	(and is a different shape from the removed W17 Supply Convoy wildcard: standing logistics
	behavior at unlock, no player cash payout - the side supply pool is credited instead).

	Shape: ONE standalone server maintain-loop (registry pattern cloned from Server_USVFlotilla.sqf
	- deliberately NOT the delegate-aicom-team path, which would burn a WFBE_C_AICOM_TEAMS_HARD_CAP
	combat slot). Per W/E side, at most ONE squad: a supply truck + driver + 1 cargo escort, or -
	once AIR >= 3, the same gate the player LOAD SUPPLIES heli uses - the side supply helicopter
	with a pilot. It cycles base -> nearest owned town -> (load dwell) -> base, and each completed
	round trip credits the SIDE SUPPLY POOL via ChangeSideSupply (the AI-usable primitive - the
	player supply-mission handler is isPlayer-hardgated and cannot be reused). Killing the squad
	matters: respawn only after WFBE_C_AICOM_SUPPLY_COOLDOWN.

	Unlock gates ("Truck, or helicopter"):
	  TRUCK: the side has a live Light Vehicle Factory (supply trucks are tier-0 units - factory
	         existence IS the unlock; checked via GetFactories over the side structure list).
	  HELI : WFBE_UP_AIR >= 3 (mirrors Client/Module/supplyMission gating for player supply helis).
	AI-commander-only by default (WFBE_C_AICOM_SUPPLY_AI_ONLY): a human commander runs his own
	logistics; the squad despawns (player-safe) when a human takes command.
	GUER is excluded by design: no supply economy (wfbe_supply_resistance is never published).
*/

if (!isServer) exitWith {};
if ((missionNamespace getVariable ["WFBE_C_AICOM_SUPPLY_SQUAD", 0]) <= 0) exitWith {
	["INFORMATION", "Server_AicomSupplySquad.sqf : WFBE_C_AICOM_SUPPLY_SQUAD=0 - feature OFF."] Call WFBE_CO_FNC_LogContent;
};

waitUntil { !isNil "townInit" && townInit };
waitUntil { !isNil "towns" };

Private ["_tick","_grant","_dwell","_cooldown","_aiOnly","_squads","_kept","_now"];

//--- fable/supply-startpos-fix (LIVE RPT 2026-07-28, m0728f Zargabad): the first cut read
//--- wfbe_startpos and indexed it as a position array. It is an OBJECT - Init_Server.sqf:735
//--- takes it from the side tuple and line 740 calls getDir on it, which only works on an object.
//--- So every spawn attempt threw "Type Object, expected Array" at the createVehicle line and the
//--- squad NEVER spawned once on the live server (zero AICOMSUPPLY lines all match).
//--- NOTE for the next reader: RequestDefense.sqf:44 carries a comment asserting the opposite
//--- ("wfbe_startpos is a POSITION ARRAY"). That comment is wrong; those call sites only survive
//--- because `distance` accepts an object as happily as an array. Anything that INDEXES it must
//--- normalise first, which is what this helper is for. Always returns a real [x,y,z].
WFBE_SE_FNC_AicomSupplyBasePos = {
	private ["_lg","_bp"];
	_lg = _this select 0;
	if (isNull _lg) exitWith {[0,0,0]};
	_bp = _lg getVariable "wfbe_startpos";
	if (isNil "_bp") exitWith {getPos _lg};
	if ((typeName _bp) == "OBJECT") exitWith {if (isNull _bp) then {getPos _lg} else {getPos _bp}};
	if ((typeName _bp) == "ARRAY" && {(count _bp) >= 2}) exitWith {[_bp select 0, _bp select 1, 0]};
	getPos _lg
};

_tick     = missionNamespace getVariable ["WFBE_C_AICOM_SUPPLY_TICK", 15];
if (_tick < 5) then {_tick = 5};

["INITIALIZATION", "Server_AicomSupplySquad.sqf : maintain loop starting (W/E, 1 squad per side)."] Call WFBE_CO_FNC_LogContent;

//--- Registry entry: [side, sideID, mode("truck"/"heli"), veh, grp, state("outbound"/"loading"/"inbound"), targetPos, lastPos, stuckTicks, stateTime, townRef]
_squads = [];

while {!WFBE_GameOver} do {
	sleep _tick;
	_now      = time;
	_grant    = missionNamespace getVariable ["WFBE_C_AICOM_SUPPLY_GRANT", 300];
	_dwell    = missionNamespace getVariable ["WFBE_C_AICOM_SUPPLY_DWELL", 20];
	_cooldown = missionNamespace getVariable ["WFBE_C_AICOM_SUPPLY_COOLDOWN", 300];
	_aiOnly   = missionNamespace getVariable ["WFBE_C_AICOM_SUPPLY_AI_ONLY", 1];

	//=== (1) TICK + PRUNE existing squads =====================================================
	_kept = [];
	{
		Private ["_e","_eSide","_eSideID","_eMode","_eVeh","_eGrp","_eState","_eTarget","_eLast","_eStuck","_eStateT","_eTown","_drop","_reason","_eLogik","_eBasePos","_eObj","_eArrive","_eCur","_playerNear"];
		_e = _x;
		_eSide = _e select 0; _eSideID = _e select 1; _eMode = _e select 2; _eVeh = _e select 3;
		_eGrp = _e select 4; _eState = _e select 5; _eTarget = _e select 6; _eLast = _e select 7;
		_eStuck = _e select 8; _eStateT = _e select 9; _eTown = _e select 10;

		_drop = false; _reason = "";
		if (isNull _eVeh || {!alive _eVeh}) then {
			_drop = true; _reason = "destroyed";
			missionNamespace setVariable [Format ["wfbe_aicomsupply_cd_%1", str _eSide], _now];
		};

		//--- Human took command (AI_ONLY): stand the squad down, player-safe.
		if (!_drop && {_aiOnly > 0}) then {
			_eLogik = (_eSide) Call WFBE_CO_FNC_GetSideLogic;
			if (!(_eLogik getVariable ["wfbe_aicom_running", false])) then {_drop = true; _reason = "human_commander";};
		};

		if (_drop) then {
			if (_reason != "destroyed" && {!isNull _eVeh} && {({isPlayer _x} count (crew _eVeh)) == 0}) then {
				{["aicomsupply-unit", _x, ""] Call WFBE_CO_FNC_LogVehDelete; deleteVehicle _x; sleep 0} forEach (crew _eVeh); //--- crash 014EFCF4 sweep: sleep 0 between crew deletes (order-dependent on the deleteGroup below; already-scheduled).
				["aicomsupply-hull", _eVeh, ""] Call WFBE_CO_FNC_LogVehDelete; deleteVehicle _eVeh;
				if (!isNull _eGrp) then {deleteGroup _eGrp};
			};
			diag_log Format ["AICOMSUPPLY|DESPAWN|side=%1|reason=%2", str _eSide, _reason];
		} else {
			//--- Re-check hull after prune gate (TOCTOU): concurrent destroy between isNull and getPos/velocity is native-crash class (014EFCF4).
			if (isNull _eVeh || {!alive _eVeh}) then {
				missionNamespace setVariable [Format ["wfbe_aicomsupply_cd_%1", str _eSide], _now];
				diag_log Format ["AICOMSUPPLY|DESPAWN|side=%1|reason=destroyed_race", str _eSide];
			} else {
			//--- State machine: outbound -> loading (dwell) -> inbound -> deliver -> outbound.
			_eLogik   = (_eSide) Call WFBE_CO_FNC_GetSideLogic;
			_eBasePos = [_eLogik] Call WFBE_SE_FNC_AicomSupplyBasePos;
			_eArrive  = if (_eMode == "heli") then {150} else {120};
			_eObj     = if (_eState == "inbound") then {_eBasePos} else {_eTarget};
			_eCur     = getPos _eVeh;

			if (_eState == "loading") then {
				if ((_now - _eStateT) >= _dwell) then {
					_eState = "inbound"; _eStateT = _now; _eStuck = 0;
				};
			} else {
				if ((_eCur distance _eObj) < _eArrive) then {
					if (_eState == "outbound") then {
						_eState = "loading"; _eStateT = _now; _eStuck = 0;
					} else {
						//--- Completed round trip: credit the SIDE SUPPLY POOL (AI-usable primitive;
						//--- W2 Supply Drop precedent). Server-side, clamped at the economy ceiling.
						[_eSide, _grant, "AICOM supply squad delivery.", false] Call ChangeSideSupply;
						diag_log Format ["AICOMSUPPLY|DELIVER|side=%1|mode=%2|grant=%3", str _eSide, _eMode, _grant];
						_eState = "outbound"; _eStateT = _now; _eStuck = 0; _eTown = objNull;
					};
				};
			};

			//--- (Re)pick the objective town for outbound legs: nearest OWNED town to base.
			if (_eState == "outbound" && {isNull _eTown || {(_eTown getVariable ["sideID", -1]) != _eSideID}}) then {
				Private ["_bestT","_bestD","_t","_d"];
				_bestT = objNull; _bestD = 1e9;
				{
					_t = _x;
					if (!isNull _t && {(_t getVariable ["sideID", -1]) == _eSideID}) then {
						_d = _t distance _eBasePos;
						if (_d < _bestD) then {_bestD = _d; _bestT = _t};
					};
				} forEach towns;
				_eTown = _bestT;
				if (!isNull _eTown) then {_eTarget = getPos _eTown};
			};

			//--- Movement: re-issue every tick (cheap, self-healing). No owned town -> hold at base.
			if (_eState != "loading") then {
				if (_eState == "outbound" && {isNull _eTown}) then {
					_eObj = _eBasePos;
				};
				_eObj = if (_eState == "inbound") then {_eBasePos} else {if (isNull _eTown) then {_eBasePos} else {_eTarget}};
				if (!isNull (driver _eVeh) && {alive (driver _eVeh)}) then {(driver _eVeh) doMove _eObj};

				//--- Truck unstuck (USV idiom): 3 low-progress ticks = wedged. Velocity hop when a
				//--- player is near (no teleports in view); otherwise nudge it 60m along the bearing.
				if (_eMode == "truck") then {
					if ((_eCur distance _eLast) < 15 && {(_eCur distance _eObj) > _eArrive}) then {_eStuck = _eStuck + 1} else {_eStuck = 0};
					if (_eStuck >= 3) then {
						_eStuck = 0;
						_playerNear = {isPlayer _x && {alive _x} && {(side _x) != civilian} && {!((name _x) in WFBE_C_HC_NAMES)} && {(_x distance _eVeh) < 200}} count playableUnits;
						if (_playerNear > 0) then {
							_eVeh setVelocity [(velocity _eVeh) select 0, (velocity _eVeh) select 1, 3];
						} else {
							Private ["_ang2"];
							_ang2 = ((_eObj select 0) - (_eCur select 0)) atan2 ((_eObj select 1) - (_eCur select 1));
							_eVeh setPos [(_eCur select 0) + 60 * sin _ang2, (_eCur select 1) + 60 * cos _ang2, 0];
						};
						diag_log Format ["AICOMSUPPLY|UNSTUCK|side=%1|near=%2", str _eSide, _playerNear];
					};
				};
				_eLast = _eCur;
			};

			_kept = _kept + [[_eSide, _eSideID, _eMode, _eVeh, _eGrp, _eState, _eTarget, _eLast, _eStuck, _eStateT, _eTown]];
			};
		};
	} forEach _squads;
	_squads = _kept;

	//=== (2) MAINTAIN: one squad per W/E side when gates are met =============================
	{
		Private ["_side","_sideText","_sideID","_logik","_has","_cdLast","_ups","_airLvl","_mode","_structures","_lightIdx","_lightFacs","_basePos","_cls","_veh","_grp","_crewCls","_drv","_esc","_heliList","_heliIdx"];
		_side = _x;
		_sideText = str _side;
		_has = false;
		{if ((_x select 0) == _side) then {_has = true}} forEach _squads;
		if (!_has) then {
			_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
			if (!isNull _logik && {(_aiOnly <= 0) || {_logik getVariable ["wfbe_aicom_running", false]}}) then {
				_cdLast = missionNamespace getVariable [Format ["wfbe_aicomsupply_cd_%1", _sideText], -99999];
				if ((_now - _cdLast) >= _cooldown) then {
					//--- Unlock gates: HELI at AIR>=3 (player supply-heli parity), else TRUCK if a live
					//--- Light Vehicle Factory exists (supply trucks are tier-0: the factory IS the gate).
					_ups    = (_side) Call WFBE_CO_FNC_GetSideUpgrades;
					_airLvl = if (count _ups > WFBE_UP_AIR) then {_ups select WFBE_UP_AIR} else {0};
					_mode = "";
					if (_airLvl >= 3) then {
						_mode = "heli";
					} else {
						_structures = (_side) Call WFBE_CO_FNC_GetSideStructures;
						_lightIdx   = missionNamespace getVariable Format ["WFBE_%1LIGHTTYPE", _sideText];
						if (!isNil "_lightIdx") then {
							_lightFacs = [_side, _lightIdx, _structures] Call GetFactories;
							if (count _lightFacs > 0) then {_mode = "truck"};
						};
					};
					if (_mode != "") then {
						_basePos = [_logik] Call WFBE_SE_FNC_AicomSupplyBasePos;
						_sideID = (_side) Call GetSideID;
						_cls = "";
						if (_mode == "heli") then {
							_heliList = missionNamespace getVariable ["WFBE_C_SUPPLY_HELI_TYPES", []];
							_heliIdx  = if (_side == west) then {0} else {1};
							if (count _heliList > _heliIdx) then {_cls = _heliList select _heliIdx};
						} else {
							Private ["_tl"];
							_tl = missionNamespace getVariable Format ["WFBE_%1SUPPLYTRUCKS", _sideText];
							if (!isNil "_tl" && {count _tl > 0}) then {_cls = _tl select 0};
						};
						if (_cls != "") then {
							_veh = [_cls, [(_basePos select 0) + 25, (_basePos select 1) + 25, 0], _side, random 360, false, true] Call WFBE_CO_FNC_CreateVehicle;
							if (!isNull _veh) then {
								_grp = [_side, "aicom-supply"] Call WFBE_CO_FNC_CreateGroup;
								_crewCls = if (_mode == "heli") then {missionNamespace getVariable [Format ["WFBE_%1PILOT", _sideText], ""]} else {missionNamespace getVariable [Format ["WFBE_%1SOLDIER", _sideText], ""]};
								if (!isNull _grp && {_crewCls != ""}) then {
									_drv = [_crewCls, _grp, _basePos, _sideID] Call WFBE_CO_FNC_CreateUnit;
									if (!isNull _drv) then {
										_drv moveInDriver _veh;
										if (_mode == "truck") then {
											//--- Small squad: one cargo escort so ambushing it is a fight, not a freebie.
											_esc = [_crewCls, _grp, _basePos, _sideID] Call WFBE_CO_FNC_CreateUnit;
											if (!isNull _esc) then {_esc moveInCargo _veh};
										} else {
											_veh flyInHeight 80;
										};
										_grp setBehaviour "AWARE"; _grp setSpeedMode "FULL";
										_veh setVariable ["wfbe_aicom_supply", true, true];
										_squads = _squads + [[_side, _sideID, _mode, _veh, _grp, "outbound", _basePos, getPos _veh, 0, _now, objNull]];
										diag_log Format ["AICOMSUPPLY|SPAWN|side=%1|mode=%2|class=%3", _sideText, _mode, _cls];
										["INFORMATION", Format ["Server_AicomSupplySquad.sqf: [%1] %2 supply squad spawned (%3).", _sideText, _mode, _cls]] Call WFBE_CO_FNC_LogContent;
									} else {
										deleteVehicle _veh; deleteGroup _grp;
									};
								} else {
									deleteVehicle _veh;
									if (!isNull _grp) then {deleteGroup _grp};
								};
							};
						};
					};
				};
			};
		};
	} forEach [west, east];
};
