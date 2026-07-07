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
private ["_side","_sideText","_logik","_names","_costs","_structures","_counts","_i","_st","_stype","_idx","_cost","_victim","_victimCost","_victimIdx","_victimType","_refund","_protected"];
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
//--- never sell the HQ or the CommandCenter (the base's spine); everything else is sellable.
_protected = ["Headquarters", "CommandCenter"];
//--- 1) tally how many ALIVE structures of each TYPE we hold (by wfbe_structure_type tag).
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
//--- B758 (Ray 2026-06-26) HARDEN BASE-REBUILD: Pass 1 - prefer a STRANDED OLD-BASE structure: one now FAR
//--- (> WFBE_C_AICOM_BASE_RADIUS) from the CURRENT/rebuilt HQ but whose TYPE still has a working copy NEAR the HQ.
//--- After an MHQ relocate + REBASE this recoups the abandoned old base, which the >MAX-duplicate trigger misses
//--- (a single relocate leaves only 2 of a type). A2-OA-safe: outer struct captured into _struc so the inner count's
//--- _x can't clobber it; getPos/distance/count/find core commands; no isEqualTo/isEqualType.
private ["_hq","_hqPos","_baseRad","_struc","_nearSame"];
_hq = (_side) Call WFBE_CO_FNC_GetSideHQ;
if ((missionNamespace getVariable ["WFBE_C_AICOM_SELL_STRANDED", 1]) > 0 && {!isNull _hq}) then {
	_hqPos = getPos _hq;
	_baseRad = missionNamespace getVariable ["WFBE_C_AICOM_BASE_RADIUS", 450];
	{
		_struc = _x;
		if (!isNull _struc && {alive _struc}) then {
			_stype = _struc getVariable ["wfbe_structure_type", ""];
			if (!(_stype in _protected) && {(_struc distance _hqPos) > _baseRad}) then {
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
if (isNull _victim) then {
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
if (isNull _victim) exitWith {};                  //--- nothing redundant to sell this tick.
//--- 3) refund a fraction of the build cost to side SUPPLY (dual-currency only), clamped non-negative.
_refund = round (_victimCost * ((missionNamespace getVariable ["WFBE_C_AICOM_SELL_REFUND_FRAC", 0.5]) max 0));
if ((missionNamespace getVariable ["WFBE_C_ECONOMY_CURRENCY_SYSTEM", 0]) == 0 && {_refund > 0}) then {
	[_side, _refund, "AI commander base-sell refund.", false] Call ChangeSideSupply;
};
//--- 4) free the build slot (decrement wfbe_structures_live, mirroring Server_BuildingKilled), then drop
//--- the object from wfbe_structures and delete it. The live-count array is indexed (_idx-1) exactly as the
//--- killed path does (B74.2: matches Server_BuildingKilled.sqf so the player CanBuild / item-4 cap reads it correctly).
private ["_live"];
_live = _logik getVariable "wfbe_structures_live";
if (!isNil "_live" && {typeName _live == "ARRAY"} && {_victimIdx - 1 >= 0} && {_victimIdx - 1 < count _live}) then {
	_live set [_victimIdx - 1, ((_live select (_victimIdx - 1)) - 1) max 0];
	_logik setVariable ["wfbe_structures_live", _live, true];
};
_logik setVariable ["wfbe_structures", (_logik getVariable "wfbe_structures") - [_victim, objNull], true];
deleteVehicle _victim;
["INFORMATION", Format ["AI_Commander_BaseSell.sqf: [%1] SOLD redundant %2 (cost %3, refunded %4 supply).", _sideText, _victimType, _victimCost, _refund]] Call WFBE_CO_FNC_AICOMLog;
diag_log ("AICOM2|v1|SELL|" + _sideText + "|" + str (round (time / 60)) + "|event=BASE_SELL|type=" + _victimType + "|cost=" + str _victimCost + "|refund=" + str _refund);
