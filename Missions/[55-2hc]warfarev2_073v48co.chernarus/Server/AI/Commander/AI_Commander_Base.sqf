/*
	AI Commander - deploy the HQ and build the base, following the side's doctrine.
	feat/ai-commander V0.2. Server-side worker, full-command mode only.
	Parameter: _this = side.

	Doctrine (wfbe_aicom_doctrine, picked by the supervisor): "LF" or "HF" decides
	which production factory is built first; everything is built eventually.
	One construction per call (gentle supply drain, no build spam). Costs are paid
	from side supply exactly like a human commander's COIN build (the client normally
	deducts before RequestStructure; here the server deducts itself).
*/

private ["_side","_sideText","_logik","_hq","_supply","_names","_classes","_costs","_scripts","_structures","_doctrine","_order","_idx","_have","_cost","_class","_script","_pos","_ang","_hqPos","_defMax","_defCount","_defClass","_defData","_defPrice","_funds","_deployCost","_dual"];

_side = _this;
_sideText = str _side;
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNil "_logik") exitWith {};

_hq = (_side) Call WFBE_CO_FNC_GetSideHQ;
if (isNull _hq || {!alive _hq}) exitWith {};

_dual = (missionNamespace getVariable "WFBE_C_ECONOMY_CURRENCY_SYSTEM") == 0;
_supply = if (_dual) then {(_side) Call WFBE_CO_FNC_GetSideSupply} else {9000000};

_names   = missionNamespace getVariable Format ["WFBE_%1STRUCTURES", _sideText];
_classes = missionNamespace getVariable Format ["WFBE_%1STRUCTURENAMES", _sideText];
_costs   = missionNamespace getVariable Format ["WFBE_%1STRUCTURECOSTS", _sideText];
_scripts = missionNamespace getVariable Format ["WFBE_%1STRUCTURESCRIPTS", _sideText];
if (isNil "_names" || isNil "_classes" || isNil "_costs" || isNil "_scripts") exitWith {};

//--- 1) Deploy the HQ where it stands (the MHQ starts at the side's start location).
if (!((_side) Call WFBE_CO_FNC_GetSideHQDeployStatus)) exitWith {
	if (_logik getVariable ["wfbe_hqinuse", false]) exitWith {};
	_deployCost = _costs select 0;
	if (_supply >= _deployCost) then {
		if (_dual) then {[_side, -_deployCost, "AI commander HQ deployment.", false] Call ChangeSideSupply};
		[_classes select 0, _side, getPos _hq, getDir _hq, 0] ExecVM "Server\Construction\Construction_HQSite.sqf";
		["INFORMATION", Format ["AI_Commander_Base.sqf: [%1] deploying HQ (cost %2 supply).", _sideText, _deployCost]] Call WFBE_CO_FNC_LogContent;
	};
};

//--- 2) HQ deployed: walk the doctrine build order; build the first missing structure.
_doctrine = _logik getVariable ["wfbe_aicom_doctrine", "LF"];
//--- Logical-name build order (resolved to indices below). Primary factory first.
_order = if (_doctrine == "HF") then {
	["Barracks","Heavy","Light","ServicePoint","Aircraft","CommandCenter"]
} else {
	["Barracks","Light","Heavy","ServicePoint","Aircraft","CommandCenter"]
};

_structures = (_side) Call WFBE_CO_FNC_GetSideStructures;
_hqPos = getPos ((_side) Call WFBE_CO_FNC_GetSideHQ);

{
	_idx = _names find _x;
	if (_idx >= 0) then {
		_class = _classes select _idx;
		//--- Already have an ALIVE one of this type?
		_have = false;
		{ if (typeOf _x == _class && {alive _x}) exitWith {_have = true} } forEach _structures;
		if (!_have) exitWith {
			_cost = _costs select _idx;
			if (_supply >= _cost) then {
				//--- Ring placement around the HQ, clearance-checked.
				_ang = 30 + (_idx * 55) + (random 20);
				_pos = [(_hqPos select 0) + (45 + random 20) * sin _ang, (_hqPos select 1) + (45 + random 20) * cos _ang, 0];
				_pos = [_pos, 35] Call WFBE_CO_FNC_GetEmptyPosition;
				if (_dual) then {[_side, -_cost, Format ["AI commander base construction (%1).", _x], false] Call ChangeSideSupply};
				_script = _scripts select _idx;
				[_class, _side, _pos, random 360, _idx] ExecVM (Format ["Server\Construction\Construction_%1.sqf", _script]);
				["INFORMATION", Format ["AI_Commander_Base.sqf: [%1] building %2 (cost %3 supply, doctrine %4).", _sideText, _x, _cost, _doctrine]] Call WFBE_CO_FNC_LogContent;
			};
		};
	};
} forEach _order;

//--- 3) Base defenses: a few manned statics once the Barracks stands (crewed from it).
_defMax = missionNamespace getVariable ["WFBE_C_AI_COMMANDER_DEFENSES_MAX", 4];
_defCount = _logik getVariable ["wfbe_aicom_defenses", 0];
if (_defCount < _defMax) then {
	_have = false;
	{ if ((_x getVariable ["wfbe_structure_type", ""]) == "Barracks" && {alive _x}) exitWith {_have = true} } forEach ((_side) Call WFBE_CO_FNC_GetSideStructures);
	if (_have) then {
		//--- Alternate MG / AA pods; classnames from the faction defense config (guarded).
		_defClass = if (_defCount % 2 == 0) then {
			missionNamespace getVariable Format ["WFBE_%1DEFENSES_MG", _sideText]
		} else {
			missionNamespace getVariable Format ["WFBE_%1DEFENSES_AAPOD", _sideText]
		};
		if (!isNil "_defClass") then {
			if (typeName _defClass == "ARRAY") then {_defClass = _defClass select 0};
			_defData = missionNamespace getVariable _defClass;
			_defPrice = if (!isNil "_defData") then {_defData select QUERYUNITPRICE} else {0};
			_funds = (_side) Call GetAICommanderFunds;
			if (_funds >= _defPrice) then {
				[_side, -_defPrice] Call ChangeAICommanderFunds;
				_ang = _defCount * 90 + 45;
				_pos = [(_hqPos select 0) + 35 * sin _ang, (_hqPos select 1) + 35 * cos _ang, 0];
				_pos = [_pos, 15] Call WFBE_CO_FNC_GetEmptyPosition;
				[_defClass, _side, _pos, random 360, true, true] Call ConstructDefense;
				_logik setVariable ["wfbe_aicom_defenses", _defCount + 1];
				["INFORMATION", Format ["AI_Commander_Base.sqf: [%1] placed base defense %2/%3 [%4].", _sideText, _defCount + 1, _defMax, _defClass]] Call WFBE_CO_FNC_LogContent;
			};
		};
	};
};
