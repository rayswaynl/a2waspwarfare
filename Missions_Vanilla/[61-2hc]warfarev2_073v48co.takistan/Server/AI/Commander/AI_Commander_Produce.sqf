/*
	AI Commander - reinforce under-strength AI teams via AIBuyUnit, within a per-side AI cap.
	feat/ai-commander. Server-side worker.
	Parameter: _this = side.

	For each AI team with no build in flight and below its template size, build the first
	template unit it is short on, at an alive factory of the right kind, if unlocked and
	affordable. One order per team per call. No-ops when the factory does not exist.
*/

private ["_side","_sideText","_logik","_cap","_sideAI","_teams","_templates","_upgrades","_buildings","_structTypes","_facDefs","_team","_type","_template","_want","_cur","_toBuild","_d","_have","_fac","_unitList","_typeName","_track","_ud","_reqUp","_price","_kind","_factories","_isVeh","_id","_q","_canProduce","_funds"];

_side = _this;
_sideText = str _side;
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNil "_logik") exitWith {};

//--- Safety cap: do not produce above the per-side AI ceiling.
_cap = missionNamespace getVariable "WFBE_C_AI_COMMANDER_TOTAL_AI_MAX";
_sideAI = {(side _x == _side) && !(isPlayer _x)} count allUnits;
if (_sideAI >= _cap) exitWith {};

_teams = _logik getVariable "wfbe_teams";
if (isNil "_teams") exitWith {};
_templates = missionNamespace getVariable Format ["WFBE_%1AITEAMTEMPLATES", _sideText];
if (isNil "_templates") exitWith {};

_upgrades   = (_side) Call WFBE_CO_FNC_GetSideUpgrades;
_buildings  = (_side) Call WFBE_CO_FNC_GetSideStructures;
_structTypes = missionNamespace getVariable Format ["WFBE_%1STRUCTURES", _sideText];
if (isNil "_structTypes") exitWith {};

//--- [STRUCTURES type-name, per-factory UNITS-list suffix, upgrade-track index].
_facDefs = [["Barracks","BARRACKSUNITS",WFBE_UP_BARRACKS], ["Light","LIGHTUNITS",WFBE_UP_LIGHT], ["Heavy","HEAVYUNITS",WFBE_UP_HEAVY], ["Aircraft","AIRCRAFTUNITS",WFBE_UP_AIR]];

{
	_team = _x;
	_type = _team getVariable ["wfbe_teamtype", -1];
	_canProduce = false;
	//--- V0.3: HC-resident commander teams are produced whole on the HC - never here.
	if (!isPlayer (leader _team) && {!(_team getVariable ["wfbe_aicom_hc", false])}) then {
		if (_type >= 0) then {
			if (_type < count _templates) then {
				if (count (_team getVariable ["wfbe_queue", []]) == 0) then {_canProduce = true};
			};
		};
	};
	if (_canProduce) then {
		_template = _templates select _type;
		_want = (count _template) min (missionNamespace getVariable "WFBE_C_AI_MAX");
		_cur  = {alive _x} count (units _team);

		if (_cur < _want) then {
			//--- First template classname the team is short on.
			_toBuild = "";
			{
				_d = _x;
				_have = {typeOf _x == _d} count (units _team);
				if (_have < ({_x == _d} count _template)) exitWith {_toBuild = _d};
			} forEach _template;

			if (_toBuild != "") then {
				//--- Which production factory builds it?
				_fac = [];
				{
					_unitList = missionNamespace getVariable [Format ["WFBE_%1%2", _sideText, (_x select 1)], []];
					if (_toBuild in _unitList) exitWith {_fac = _x};
				} forEach _facDefs;

				if (count _fac > 0) then {
					_ud = missionNamespace getVariable _toBuild;
					if (!isNil "_ud") then {
						_typeName = _fac select 0;
						_track    = _fac select 2;
						_reqUp    = _ud select QUERYUNITUPGRADE;
						_price    = _ud select QUERYUNITPRICE;

						if (_reqUp <= (_upgrades select _track)) then {
							_kind = _structTypes find _typeName;
							if (_kind >= 0) then {
								_factories = [_side, _kind, _buildings] Call GetFactories;
								_funds = (_side) Call GetAICommanderFunds;
								if (count _factories > 0) then {
									if (_funds >= _price) then {
										[_side, -_price] Call ChangeAICommanderFunds;
										_isVeh = if (_toBuild isKindOf "Man") then {[]} else {[true,true,true,true]};
										_id = [floor (random 1000000)];
										_q = (_team getVariable ["wfbe_queue", []]) + [_id];
										_team setVariable ["wfbe_queue", _q];
										[_id, (_factories select 0), _toBuild, _side, _team, _isVeh] Spawn AIBuyUnit;
										["INFORMATION", Format ["AI_Commander_Produce.sqf: [%1] team [%2] ordering [%3] at %4 factory (cost %5).", _sideText, _team, _toBuild, _typeName, _price]] Call WFBE_CO_FNC_AICOMLog;
									};
								};
							};
						};
					};
				};
			};
		};
	};
} forEach _teams;
