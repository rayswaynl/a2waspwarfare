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

private ["_side","_sideText","_logik","_hq","_supply","_names","_classes","_costs","_scripts","_structures","_doctrine","_order","_idx","_have","_cost","_class","_script","_pos","_ang","_hqPos","_defMax","_defCount","_defClass","_defData","_defPrice","_funds","_deployCost","_dual","_findBuildPos","_upgrades","_coreDone","_placed","_roads","_cand","_artyBuilt","_artyClasses","_bankIdx","_bankCost","_cbrIdx","_scaffoldActivated"];

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
		["INFORMATION", Format ["AI_Commander_Base.sqf: [%1] deploying HQ (cost %2 supply).", _sideText, _deployCost]] Call WFBE_CO_FNC_AICOMLog;
	};
};

//--- 2) HQ deployed: walk the doctrine build order; build the first missing structure.
_doctrine = _logik getVariable ["wfbe_aicom_doctrine", "LF"];
_hqPos = getPos ((_side) Call WFBE_CO_FNC_GetSideHQ);

//--- V0.4: valid-position helper. Ring placement around the HQ, clearance-checked,
//--- never in water and never on a road. _this = [rmin, rmax]; returns a position.
_findBuildPos = {
	private ["_rmin","_rmax","_p","_ok","_try","_ang"];
	_rmin = _this select 0; _rmax = _this select 1;
	_ok = false; _try = 0; _p = [_hqPos, 35] Call WFBE_CO_FNC_GetEmptyPosition;
	while {!_ok && _try < 24} do {
		_ang = random 360;
		_p = [(_hqPos select 0) + (_rmin + random (_rmax - _rmin)) * sin _ang, (_hqPos select 1) + (_rmin + random (_rmax - _rmin)) * cos _ang, 0];
		_p = [_p, 30] Call WFBE_CO_FNC_GetEmptyPosition;
		if (!(surfaceIsWater _p) && {count (_p nearRoads 12) == 0}) then {_ok = true};
		_try = _try + 1;
	};
	_p
};

//--- V0.4: strategy-shaped construction. At start ONLY the core: CC -> Barracks ->
//--- doctrine factory (keeps supply free for the research program). The rest of the
//--- base is built once the research core (Gear 3 + Barracks 2) is reached = branch out.
_upgrades = _logik getVariable "wfbe_upgrades";
_coreDone = false;
if (!isNil "_upgrades") then {
	_coreDone = ((_upgrades select WFBE_UP_GEAR) >= 3) && {(_upgrades select WFBE_UP_BARRACKS) >= 2};
};
_order = if (_doctrine == "HF") then {["CommandCenter","Barracks","Heavy"]} else {["CommandCenter","Barracks","Light"]};
if (_coreDone) then {
	_order = _order + (if (_doctrine == "HF") then {["Light","ServicePoint","Aircraft"]} else {["Heavy","ServicePoint","Aircraft"]});
};

//--- V0.6 task 49b: experital-awareness build extension (nil-guarded, no-op on this mission).
//--- CBRadar and Bank only enter _order when the side's STRUCTURES array lists them.
//--- The EXACT type-name strings come from Structures_CO_RU/W.sqf in the experital branch:
//---   CBR  -> "CBRadar"   (WFBE_C_STRUCTURES_COUNTERBATTERY guard in experital)
//---   Bank -> "Bank"      (WFBE_C_ECONOMY_BANK guard in experital)
_scaffoldActivated = false;
_cbrIdx = _names find "CBRadar";
if (_cbrIdx >= 0) then {
	_order = _order + ["CBRadar"];
	_scaffoldActivated = true;
};
_bankIdx = _names find "Bank";
if (_bankIdx >= 0) then {
	//--- Supply gate: only attempt Bank when supply > 1.5x its construction cost.
	_bankCost = _costs select _bankIdx;
	if (_supply > _bankCost * 1.5) then {
		_order = _order + ["Bank"];
		_scaffoldActivated = true;
	};
};
if (_scaffoldActivated) then {
	["INFORMATION", Format ["AI_Commander_Base.sqf: [%1] experital build scaffold ACTIVE (CBR=%2 Bank=%3 in order).", _sideText, (_cbrIdx >= 0), (_bankIdx >= 0)]] Call WFBE_CO_FNC_AICOMLog;
	diag_log ("AICOMSTAT|v1|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|SCAFFOLD_BUILD|CBR=" + str (_cbrIdx >= 0) + " Bank=" + str (_bankIdx >= 0));
};

_structures = (_side) Call WFBE_CO_FNC_GetSideStructures;

{
	_idx = _names find _x;
	if (_idx >= 0) then {
		_class = _classes select _idx;
		//--- Already have an ALIVE one of this type? V0.4.2: construction is ASYNC, so a
		//--- site paid for last tick is not alive yet - the pending timestamp guards the
		//--- 5-min build window so we never pay for the same structure twice.
		_have = false;
		{ if (typeOf _x == _class && {alive _x}) exitWith {_have = true} } forEach _structures;
		if (!_have) then {
			if (time - (_logik getVariable [Format ["wfbe_aicom_built_%1", _x], -1e6]) < 300) then {_have = true};
		};
		if (!_have) exitWith {
			_cost = _costs select _idx;
			if (_supply >= _cost) then {
				//--- ServicePoint wants to sit ON a road (repair/refuel access); fall back to ring.
				_pos = [0,0,0];
				_placed = false;
				if (_x == "ServicePoint") then {
					_roads = _hqPos nearRoads 200;
					_cand = [];
					{ if (((getPos _x) distance _hqPos) > 25) then {_cand = _cand + [_x]} } forEach _roads;
					if (count _cand > 0) then {
						_pos = getPos (_cand select (floor (random (count _cand))));
						if (!(surfaceIsWater _pos)) then {_placed = true};
					};
				};
				if (!_placed) then {_pos = [45, 75] Call _findBuildPos};
				if (_dual) then {[_side, -_cost, Format ["AI commander base construction (%1).", _x], false] Call ChangeSideSupply};
				_logik setVariable [Format ["wfbe_aicom_built_%1", _x], time];
				_script = _scripts select _idx;
				[_class, _side, _pos, random 360, _idx] ExecVM (Format ["Server\Construction\Construction_%1.sqf", _script]);
				["INFORMATION", Format ["AI_Commander_Base.sqf: [%1] building %2 at %3 (cost %4 supply, doctrine %5, branch-out %6).", _sideText, _x, _pos, _cost, _doctrine, _coreDone]] Call WFBE_CO_FNC_AICOMLog;
				diag_log ("AICOMSTAT|v1|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|STRUCTURE_BUILT|" + _x);
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
				_pos = [28, 42] Call _findBuildPos;
				[_defClass, _side, _pos, random 360, true, true] Call ConstructDefense;
				_logik setVariable ["wfbe_aicom_defenses", _defCount + 1];
				["INFORMATION", Format ["AI_Commander_Base.sqf: [%1] placed base defense %2/%3 [%4].", _sideText, _defCount + 1, _defMax, _defClass]] Call WFBE_CO_FNC_AICOMLog;
			};
		};
	};
};

//--- 4) V0.5: two base artillery pieces once the defenses stand. Construction tags
//--- them WFBE_CommanderArtillery; the strategy worker fires them at spearhead
//--- towns / the enemy HQ (fire is free in WFBE - the real cooldown gates it).
if ((missionNamespace getVariable "WFBE_C_ARTILLERY") > 0) then {
	_artyBuilt = _logik getVariable ["wfbe_aicom_arty_built", 0];
	if (_artyBuilt < 2 && {(_logik getVariable ["wfbe_aicom_defenses", 0]) >= _defMax}) then {
		_have = false;
		{ if ((_x getVariable ["wfbe_structure_type", ""]) == "Barracks" && {alive _x}) exitWith {_have = true} } forEach ((_side) Call WFBE_CO_FNC_GetSideStructures);
		if (_have) then {
			_artyClasses = missionNamespace getVariable Format ["WFBE_%1_ARTILLERY_CLASSNAMES", _sideText];
			if (!isNil "_artyClasses" && {count _artyClasses > 0}) then {
				_defClass = _artyClasses select 0;
				_defData = missionNamespace getVariable _defClass;
				_defPrice = if (!isNil "_defData") then {_defData select QUERYUNITPRICE} else {0};
				_funds = (_side) Call GetAICommanderFunds;
				if (_funds >= _defPrice) then {
					[_side, -_defPrice] Call ChangeAICommanderFunds;
					_pos = [25, 38] Call _findBuildPos;
					[_defClass, _side, _pos, random 360, true, true] Call ConstructDefense;
					_logik setVariable ["wfbe_aicom_arty_built", _artyBuilt + 1];
					["INFORMATION", Format ["AI_Commander_Base.sqf: [%1] placed base artillery %2/2 [%3] (cost %4 funds).", _sideText, _artyBuilt + 1, _defClass, _defPrice]] Call WFBE_CO_FNC_AICOMLog;
				};
			};
		};
	};
};
