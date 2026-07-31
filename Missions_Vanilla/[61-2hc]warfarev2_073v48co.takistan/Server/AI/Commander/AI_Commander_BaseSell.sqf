/*
	AI Commander - structure SELL / recycle worker (B74.2, Ray 2026-06-24 directive #5).
	Server-side, full-command mode. Parameter: _this = side.
	Sells the LOWEST-COST redundant non-HQ / non-CommandCenter structure, refunds a fraction of its
	build cost to side SUPPLY (mirrors a human recycle), and frees the build slot so the base/building
	cap (item 1/4) can re-use it. Dark by default (gated in the supervisor on WFBE_C_AICOM_BASE_SELL_ENABLE).
	Trigger (pre-cap, self-contained): a structure TYPE is held in DUPLICATE beyond WFBE_C_AICOM_SELL_REDUNDANT_MAX.
	A2-OA-1.64 safe: no isEqualType/findIf/pushBack/params; find/+/- on arrays; getVariable[name,default] on the
	side-logic OBJECT only; typeOf/distance/deleteVehicle core commands.
*/
private ["_side","_sideText","_logik","_names","_costs","_structures","_counts","_i","_st","_stype","_idx","_cost","_victim","_victimCost","_victimIdx","_victimType","_refund","_protected","_protectedPass1","_artyNear","_artyFar","_artyPiece","_artyMax","_artyDist","_artyBestDist","_artyUd","_artyPrice","_artyReg","_artyRegLive","_artyCluster","_artyStrandedDist","_relocOn","_relocVictim","_relocVictimCost","_relocVictimType","_relocVictimIdx","_relocVictimOldDist","_relocVictimIsReloc","_relocCenters","_relocCenter","_relocCenterDist","_relocOldCenter","_relocOldCenterDist","_relocRadius","_relocDist","_relocBaseRadius","_relocProtectRadius","_relocAttackDist","_relocHQ","_relocHQPos","_relocHQDeployed","_relocCCFound","_relocUnderAttack","_relocPending","_relocOther","_relocQueued","_relocAnyQueued","_relocHasCC","_relocCandidate","_relocCandidateCost","_relocCandidateType","_relocCandidateIdx","_relocLiveHQ","_relocLiveHQPos","_relocLiveHQDeployed","_relocLiveStructures","_relocSaleValid"];
if ((missionNamespace getVariable ["WFBE_C_AICOM_BASE_SELL_ENABLE", 0]) <= 0) exitWith {};
_side = _this;
if (_side == resistance) exitWith {};            //--- GUER has no commander economy.
_sideText = str _side;
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNull _logik) exitWith {};
//--- only sell while the side actually has a deployed HQ (don't dismantle mid-relocation).
if (_logik getVariable ["wfbe_mhqreloc_active", false]) exitWith {};
_names = missionNamespace getVariable Format ["WFBE_%1STRUCTURENAMES", _sideText];
_costs = missionNamespace getVariable Format ["WFBE_%1STRUCTURECOSTS", _sideText];
if (isNil "_names" || isNil "_costs") exitWith {};
_structures = (_side) Call WFBE_CO_FNC_GetSideStructures;
if (isNil "_structures" || {typeName _structures != "ARRAY"}) exitWith {};
//--- Pass 2 protects both base-spine types from the crude duplicate-trigger sell.
_protected = ["Headquarters", "CommandCenter"];
//--- Pass 1 may recoup a stranded CommandCenter once a working copy exists at the current HQ.
_protectedPass1 = ["Headquarters"];
//--- 1) tally how many ALIVE structures of each TYPE we hold (by wfbe_structure_type tag).

_relocOn = (missionNamespace getVariable ["WFBE_C_AICOM_RELOC_SELL", 0]) > 0;
_relocVictim = objNull;
_relocVictimCost = 1e9;
_relocVictimType = "";
_relocVictimIdx = -1;
_relocVictimOldDist = 0;
_relocVictimIsReloc = false;
_relocPending = false;
_relocUnderAttack = false;

//--- Flag-off is a hard gate: no relocation state is read or written while the feature is dark.
if (_relocOn) then {
	_relocCenters = _logik getVariable "wfbe_aicom_reloc_sell_old_centers";
	if (isNil "_relocCenters" || {typeName _relocCenters != "ARRAY"}) then {
		_relocCenters = [];
	};
	if (count _relocCenters > 0) then {
		_relocPending = true;
	};
	_relocRadius = missionNamespace getVariable ["WFBE_C_AICOM_RELOC_SELL_RADIUS", 300];
	_relocDist = missionNamespace getVariable ["WFBE_C_AICOM_RELOC_SELL_DIST", 500];
	_relocBaseRadius = missionNamespace getVariable ["WFBE_C_AICOM_BASE_RADIUS", 450];
	if (_relocRadius > 0 && {_relocDist > 0}) then {
		_relocProtectRadius = _relocRadius max _relocBaseRadius;
		_relocHQ = (_side) Call WFBE_CO_FNC_GetSideHQ;
		_relocHQDeployed = (_side) Call WFBE_CO_FNC_GetSideHQDeployStatus;
		if (typeName _relocHQDeployed == "BOOL" && {_relocHQDeployed} && {!isNull _relocHQ} && {alive _relocHQ}) then {
			_relocHQPos = getPos _relocHQ;
			if (typeName _relocHQPos == "ARRAY" && {count _relocHQPos >= 2}) then {
				_relocCCFound = false;
				{
					if (!_relocCCFound && {!isNull _x} && {alive _x} && {(_x getVariable ["wfbe_structure_type", ""]) == "CommandCenter"} && {(_x distance _relocHQPos) <= _relocProtectRadius}) then {
						_relocCCFound = true;
					};
				} forEach _structures;
				if (_relocCCFound) then {
					_relocCenter = _logik getVariable "wfbe_aicom_reloc_sell_center";
					if (isNil "_relocCenter" || {typeName _relocCenter != "ARRAY"} || {count _relocCenter < 2}) then {
						_logik setVariable ["wfbe_aicom_reloc_sell_center", _relocHQPos];
					} else {
						_relocCenterDist = _relocHQ distance _relocCenter;
						if (_relocCenterDist > _relocDist) then {
							_relocCenters = _logik getVariable "wfbe_aicom_reloc_sell_old_centers";
							if (isNil "_relocCenters" || {typeName _relocCenters != "ARRAY"}) then {
								_relocCenters = [];
							};
							_relocCenters = _relocCenters + [_relocCenter];
							_logik setVariable ["wfbe_aicom_reloc_sell_old_centers", _relocCenters];
							_logik setVariable ["wfbe_aicom_reloc_sell_center", _relocHQPos];
							diag_log Format ["AICOMSELL|v1|RELOC|side=%1|event=DETECTED|oldDist=%2|old=%3|new=%4", _sideText, round _relocCenterDist, _relocCenter, _relocHQPos];
						};
					};

					_relocCenters = _logik getVariable "wfbe_aicom_reloc_sell_old_centers";
					if (isNil "_relocCenters" || {typeName _relocCenters != "ARRAY"}) then {
						_relocCenters = [];
					};
					if (count _relocCenters > 0) then {
						_relocOldCenter = _relocCenters select 0;
						if (typeName _relocOldCenter == "ARRAY" && {count _relocOldCenter >= 2}) then {
							_relocPending = true;
							_relocAttackDist = missionNamespace getVariable ["WFBE_C_AICOM_RELIEF_ENEMY_DIST", 500];
							if (_relocAttackDist < _relocRadius) then {
								_relocAttackDist = _relocRadius;
							};
							_relocUnderAttack = ({alive _x && {side _x != _side} && {side _x != civilian}} count (_relocOldCenter nearEntities [["Man","LandVehicle","Air"], _relocAttackDist])) > 0;
							if (!_relocUnderAttack) then {
								_relocOther = false;
								_relocAnyQueued = false;
								_relocHasCC = false;
								_relocCandidate = objNull;
								_relocCandidateCost = 1e9;
								_relocCandidateType = "";
								_relocCandidateIdx = -1;
								{
									if (!isNull _x && {alive _x}) then {
										_stype = _x getVariable ["wfbe_structure_type", ""];
										_relocOldCenterDist = _x distance _relocOldCenter;
										if (_relocOldCenterDist <= _relocRadius && {(_x distance _relocHQPos) > _relocProtectRadius} && {_stype != "Headquarters"}) then {
											if (_stype == "CommandCenter") then {
												_relocHasCC = true;
											} else {
												_relocOther = true;
												_relocQueued = _x getVariable "queu";
												if (isNil "_relocQueued" || {typeName _relocQueued != "ARRAY"}) then {
													_relocQueued = [];
												};
												if (count _relocQueued > 0) then {
													_relocAnyQueued = true;
												} else {
													_idx = _names find _stype;
													_cost = if (_idx >= 0) then {_costs select _idx} else {0};
													if (_cost < _relocCandidateCost) then {
														_relocCandidate = _x;
														_relocCandidateCost = _cost;
														_relocCandidateType = _stype;
														_relocCandidateIdx = _idx;
													};
												};
											};
										};
									};
								} forEach _structures;

								//--- The old CommandCenter is a final candidate only after every other orphan is gone and queues are empty.
								if (isNull _relocCandidate && {!_relocOther} && {!_relocAnyQueued} && {_relocHasCC}) then {
									{
										if (isNull _relocCandidate && {!isNull _x} && {alive _x}) then {
											_stype = _x getVariable ["wfbe_structure_type", ""];
											if (_stype == "CommandCenter" && {(_x distance _relocOldCenter) <= _relocRadius} && {(_x distance _relocHQPos) > _relocProtectRadius}) then {
												_idx = _names find _stype;
												_relocCandidate = _x;
												_relocCandidateCost = if (_idx >= 0) then {_costs select _idx} else {0};
												_relocCandidateType = _stype;
												_relocCandidateIdx = _idx;
											};
										};
									} forEach _structures;
								};

								if (!isNull _relocCandidate) then {
									_relocVictim = _relocCandidate;
									_relocVictimCost = _relocCandidateCost;
									_relocVictimType = _relocCandidateType;
									_relocVictimIdx = _relocCandidateIdx;
									_relocVictimOldDist = _relocVictim distance _relocOldCenter;
									_relocVictimIsReloc = true;
								} else {
									if (!_relocOther && {!_relocAnyQueued} && {!_relocHasCC}) then {
										_relocCenters = _relocCenters - [_relocOldCenter];
										_logik setVariable ["wfbe_aicom_reloc_sell_old_centers", _relocCenters];
									};
								};
							};
						} else {
							_relocCenters = _relocCenters - [_relocOldCenter];
							_logik setVariable ["wfbe_aicom_reloc_sell_old_centers", _relocCenters];
						};
					};
				};
			};
		};
	};
};

_counts = [];
{ _counts set [_forEachIndex, 0]; } forEach _names;   //--- one slot per name (parallel to _names/_costs).
{
	if (!isNull _x && {alive _x}) then {
		_stype = _x getVariable ["wfbe_structure_type", ""];
		_idx = _names find _stype;
		if (_idx >= 0) then { _counts set [_idx, (_counts select _idx) + 1] };
	};
} forEach _structures;
//--- 2) pick the lowest-cost structure whose TYPE is held in duplicate beyond the redundant threshold.
_victim = objNull; _victimCost = 1e9; _victimIdx = -1; _victimType = "";
if (!isNull _relocVictim) then {
	_victim = _relocVictim;
	_victimCost = _relocVictimCost;
	_victimIdx = _relocVictimIdx;
	_victimType = _relocVictimType;
};
//--- B758 (Ray 2026-06-26) HARDEN BASE-REBUILD: Pass 1 - prefer a STRANDED OLD-BASE structure: one now FAR
//--- (> WFBE_C_AICOM_BASE_RADIUS) from the CURRENT/rebuilt HQ but whose TYPE still has a working copy NEAR the HQ.
//--- After an MHQ relocate + REBASE this recoups the abandoned old base, which the >MAX-duplicate trigger misses
//--- (a single relocate leaves only 2 of a type). A2-OA-safe: outer struct captured into _struc so the inner count's
//--- _x can't clobber it; getPos/distance/count/find core commands; no isEqualTo/isEqualType.
private ["_hq","_hqPos","_baseRad","_struc","_nearSame"];
_hq = (_side) Call WFBE_CO_FNC_GetSideHQ;
if (isNull _victim && {!_relocPending} && {(missionNamespace getVariable ["WFBE_C_AICOM_SELL_STRANDED", 1]) > 0} && {!isNull _hq}) then {
	_hqPos = getPos _hq;
	_baseRad = missionNamespace getVariable ["WFBE_C_AICOM_BASE_RADIUS", 450];
	{
		_struc = _x;
		if (!isNull _struc && {alive _struc}) then {
			_stype = _struc getVariable ["wfbe_structure_type", ""];
			if (!(_stype in _protectedPass1) && {(_struc distance _hqPos) > _baseRad}) then {
				_nearSame = {alive _x && {(_x getVariable ["wfbe_structure_type", ""]) == _stype} && {(_x distance _hqPos) <= _baseRad}} count _structures;
				if (_nearSame > 0) then {
					_idx = _names find _stype;
					_cost = if (_idx >= 0) then {_costs select _idx} else {0};
					if (_cost < _victimCost) then {_victimCost = _cost; _victim = _struc; _victimIdx = _idx; _victimType = _stype};
				};
			};
		};
	} forEach _structures;
};
//--- Pass 2 (fallback): the original lowest-cost > SELL_REDUNDANT_MAX duplicate trigger when nothing is stranded.
if (isNull _victim && {!_relocPending}) then {
{
	if (!isNull _x && {alive _x}) then {
		_stype = _x getVariable ["wfbe_structure_type", ""];
		if (!(_stype in _protected)) then {
			_idx = _names find _stype;
			if (_idx >= 0 && {(_counts select _idx) > (missionNamespace getVariable ["WFBE_C_AICOM_SELL_REDUNDANT_MAX", 2])}) then {
				_cost = _costs select _idx;
				if (_cost < _victimCost) then { _victimCost = _cost; _victim = _x; _victimIdx = _idx; _victimType = _stype };
			};
		};
	};
} forEach _structures;
};
//--- Pass 3 (flag WFBE_C_AICOM_ARTY_SELL_STRANDED, default 0): base-artillery is NOT in wfbe_structures.
//--- Commander SPGs are defense vehicles tagged WFBE_CommanderArtillery (AI_Commander_Base.sqf), counted
//--- globally toward WFBE_C_AI_COMMANDER_ARTILLERY_MAX. After MHQ relocate they stay at the abandoned base
//--- and freeze the 2/2 cap for hours (RPT-DEEPDIVE-20260730 sec 2.5; PR #1635 left this as a separate card).
//--- Sell ONE stranded piece per tick so Base.sqf can rebuild near the current HQ. Prefer pieces co-located
//--- with other far structures (old-base cluster); fallback: all live pieces are far AND at/over cap.
if (isNull _victim && {!_relocPending} && {(missionNamespace getVariable ["WFBE_C_AICOM_ARTY_SELL_STRANDED", 0]) > 0}) then {
	_hq = (_side) Call WFBE_CO_FNC_GetSideHQ;
	if (!isNull _hq && {(missionNamespace getVariable ["WFBE_C_AI_COMMANDER_ARTILLERY", 0]) > 0}) then {
		_hqPos = getPos _hq;
		_baseRad = missionNamespace getVariable ["WFBE_C_AICOM_BASE_RADIUS", 450];
		_artyStrandedDist = missionNamespace getVariable ["WFBE_C_AICOM_ARTY_SELL_STRANDED_DIST", 1500];
		if (_artyStrandedDist < _baseRad) then {_artyStrandedDist = _baseRad};
		_artyMax = missionNamespace getVariable ["WFBE_C_AI_COMMANDER_ARTILLERY_MAX", 2];
		_artyNear = 0;
		_artyFar = [];
		{
			_artyPiece = _x;
			if (!isNull _artyPiece && {alive _artyPiece}) then {
				if ((_artyPiece getVariable ["WFBE_CommanderArtillery", false]) && {(_artyPiece getVariable ["WFBE_CommanderArtillerySide", ""]) == _sideText} && {[_artyPiece, _side] Call IsMobileArtillery}) then {
					if ((_artyPiece distance _hqPos) > _artyStrandedDist) then {
						_artyFar set [count _artyFar, _artyPiece];
					} else {
						_artyNear = _artyNear + 1;
					};
				};
			};
		} forEach vehicles;
		if (count _artyFar > 0) then {
			_victim = objNull;
			_artyBestDist = -1;
			{
				_artyPiece = _x;
				_artyCluster = false;
				{
					if (!isNull _x && {alive _x} && {(_x distance _hqPos) > _baseRad} && {(_artyPiece distance _x) <= _baseRad}) exitWith {_artyCluster = true};
				} forEach _structures;
				//--- Prefer old-base cluster; allow all-far+at-cap fallback so a fully abandoned rear still unfreezes.
				if (_artyCluster || {(_artyNear == 0) && {(_artyNear + count _artyFar) >= _artyMax}}) then {
					_artyDist = _artyPiece distance _hqPos;
					if (_artyDist > _artyBestDist) then {
						_artyBestDist = _artyDist;
						_victim = _artyPiece;
					};
				};
			} forEach _artyFar;
			if (!isNull _victim) then {
				_victimType = "CommanderArtillery";
				_victimIdx = -1;
				_artyUd = missionNamespace getVariable (typeOf _victim);
				_artyPrice = if (!isNil "_artyUd") then {_artyUd select QUERYUNITPRICE} else {0};
				_victimCost = _artyPrice;
			};
		};
	};
};

_relocSaleValid = true;
if (_relocVictimIsReloc) then {
	_relocSaleValid = false;
	_relocLiveHQ = (_side) Call WFBE_CO_FNC_GetSideHQ;
	_relocLiveHQDeployed = (_side) Call WFBE_CO_FNC_GetSideHQDeployStatus;
	_relocLiveStructures = (_side) Call WFBE_CO_FNC_GetSideStructures;
	if (typeName _relocLiveStructures != "ARRAY") then {
		_relocLiveStructures = [];
	};
	if (typeName _relocLiveHQDeployed == "BOOL" && {_relocLiveHQDeployed} && {!isNull _relocLiveHQ} && {alive _relocLiveHQ} && {_victim in _relocLiveStructures}) then {
		_relocLiveHQPos = getPos _relocLiveHQ;
		_relocCCFound = false;
		{
			if (!_relocCCFound && {!isNull _x} && {alive _x} && {(_x getVariable ["wfbe_structure_type", ""]) == "CommandCenter"} && {(_x distance _relocLiveHQPos) <= _relocProtectRadius}) then {
				_relocCCFound = true;
			};
		} forEach _relocLiveStructures;
		_relocUnderAttack = ({alive _x && {side _x != _side} && {side _x != civilian}} count (_relocOldCenter nearEntities [["Man","LandVehicle","Air"], _relocAttackDist])) > 0;
		if (_relocCCFound && {!_relocUnderAttack} && {alive _victim} && {(_victim distance _relocLiveHQPos) > _relocProtectRadius} && {(_victim distance _relocOldCenter) <= _relocRadius}) then {
			_relocQueued = _victim getVariable "queu";
			if (isNil "_relocQueued" || {typeName _relocQueued != "ARRAY"}) then {
				_relocQueued = [];
			};
			if (_victimType == "CommandCenter") then {
				_relocOther = false;
				_relocAnyQueued = false;
				{
					if (!isNull _x && {alive _x}) then {
						_stype = _x getVariable ["wfbe_structure_type", ""];
						if (_stype != "Headquarters" && {_stype != "CommandCenter"} && {(_x distance _relocOldCenter) <= _relocRadius} && {(_x distance _relocLiveHQPos) > _relocProtectRadius}) then {
							_relocOther = true;
							_relocQueued = _x getVariable "queu";
							if (isNil "_relocQueued" || {typeName _relocQueued != "ARRAY"}) then {
								_relocQueued = [];
							};
							if (count _relocQueued > 0) then {
								_relocAnyQueued = true;
							};
						};
					};
				} forEach _relocLiveStructures;
				if (!_relocOther && {!_relocAnyQueued}) then {
					_relocSaleValid = true;
				};
			} else {
				if (count _relocQueued == 0) then {
					_relocSaleValid = true;
				};
			};
		};
	};
};
if (_relocVictimIsReloc && {!_relocSaleValid}) then {
	_victim = objNull;
};
if (isNull _victim) exitWith {};                  //--- nothing redundant to sell this tick.
//--- 3/4) refund + free slot. Structures: SUPPLY refund + wfbe_structures_live. CommanderArtillery:
//--- FUNDS refund (built via ChangeAICommanderFunds) + crew delete + prune wfbe_aicom_arty_reg.
_refund = round (_victimCost * ((missionNamespace getVariable ["WFBE_C_AICOM_SELL_REFUND_FRAC", 0.5]) max 0));
if (_victimType == "CommanderArtillery") then {
	if (_refund > 0) then {[_side, _refund] Call ChangeAICommanderFunds};
	{deleteVehicle _x} forEach (crew _victim);
	_artyReg = _logik getVariable ["wfbe_aicom_arty_reg", []];
	if (typeName _artyReg != "ARRAY") then {_artyReg = []};
	_artyRegLive = [];
	{
		if (!isNull _x && {_x != _victim} && {alive _x}) then {_artyRegLive set [count _artyRegLive, _x]};
	} forEach _artyReg;
	_logik setVariable ["wfbe_aicom_arty_reg", _artyRegLive];
	deleteVehicle _victim;
	["INFORMATION", Format ["AI_Commander_BaseSell.sqf: [%1] SOLD stranded base-artillery (cost %2, refunded %3 funds).", _sideText, _victimCost, _refund]] Call WFBE_CO_FNC_AICOMLog;
	diag_log ("AICOM2|v1|SELL|" + _sideText + "|" + str (round (time / 60)) + "|event=BASE_SELL|type=CommanderArtillery|cost=" + str _victimCost + "|refund=" + str _refund);
} else {
	if ((missionNamespace getVariable ["WFBE_C_ECONOMY_CURRENCY_SYSTEM", 0]) == 0 && {_refund > 0}) then {
		[_side, _refund, "AI commander base-sell refund.", false] Call ChangeSideSupply;
	};
	//--- free the build slot (decrement wfbe_structures_live, mirroring Server_BuildingKilled), then drop
	//--- the object from wfbe_structures and delete it. The live-count array is indexed (_idx-1) exactly as the
	//--- killed path does (B74.2: matches Server_BuildingKilled.sqf so the player CanBuild / item-4 cap reads it correctly).
	private ["_live"];
	_live = _logik getVariable "wfbe_structures_live";
	if (!isNil "_live" && {typeName _live == "ARRAY"} && {_victimIdx - 1 >= 0} && {_victimIdx - 1 < count _live}) then {
		_live set [_victimIdx - 1, ((_live select (_victimIdx - 1)) - 1) max 0];
		_logik setVariable ["wfbe_structures_live", _live, true];
	};
	_logik setVariable ["wfbe_structures", (_logik getVariable "wfbe_structures") - [_victim, objNull], true];
	//--- teardown (structure-loss cascade): delete the sold structure's auto-wall ring too, mirroring
	//--- Server_BuildingKilled + Server_OnHQKilled. The sell path freed the ledger slot but left the
	//--- concrete walls orphaned on the map (same engine-object leak as the destruction path).
	{if (!isNull _x) then {deleteVehicle _x}} forEach (_victim getVariable ["WFBE_Walls", []]);
	deleteVehicle _victim;
	["INFORMATION", Format ["AI_Commander_BaseSell.sqf: [%1] SOLD redundant %2 (cost %3, refunded %4 supply).", _sideText, _victimType, _victimCost, _refund]] Call WFBE_CO_FNC_AICOMLog;
	diag_log ("AICOM2|v1|SELL|" + _sideText + "|" + str (round (time / 60)) + "|event=BASE_SELL|type=" + _victimType + "|cost=" + str _victimCost + "|refund=" + str _refund);
	if (_relocVictimIsReloc) then {
		_relocVictimOldDist = _victim distance _relocOldCenter;
		diag_log Format ["AICOMSELL|v1|RELOC|side=%1|event=SALE|type=%2|refund=%3|oldDist=%4", _sideText, _victimType, _refund, round _relocVictimOldDist];
	};
};
