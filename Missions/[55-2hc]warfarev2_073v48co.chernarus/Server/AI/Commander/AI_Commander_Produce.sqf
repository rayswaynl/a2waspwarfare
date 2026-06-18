/*
	AI Commander - reinforce under-strength AI teams via AIBuyUnit, within a per-side AI cap.
	feat/ai-commander. Server-side worker.
	Parameter: _this = side.

	For each AI team with no build in flight and below its template size, build the first
	template unit it is short on, at an alive factory of the right kind, if unlocked and
	affordable.
	V0.6.7 ADAPTIVE BATCH: per cycle, per eligible team, order up to (deficit) units capped
	by WFBE_C_AICOM_PRODUCE_BATCH (default 3) and available funds; each unit still charged
	individually.  When the wfbe_aicom_reinforce_rich flag is set by the supervisor (P4
	wealth-conversion), the effective batch cap doubles.
*/

private ["_side","_sideText","_logik","_cap","_sideAI","_teams","_templates","_upgrades","_buildings","_structTypes","_facDefs","_team","_type","_template","_want","_cur","_toBuild","_d","_have","_fac","_unitList","_typeName","_track","_ud","_reqUp","_price","_kind","_factories","_isVeh","_id","_q","_canProduce","_funds","_hqP","_batchCap","_batchOrdered","_richFlag","_myID","_ownTowns","_nearFwd","_fwdR","_facObj","_ldr","_effBatch","_ordered"];

_side = _this;
_sideText = str _side;
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNil "_logik") exitWith {};

//--- V0.6.7: batch cap - tunable, doubled when supervisor sets the wealth-rich flag.
_batchCap = missionNamespace getVariable ["WFBE_C_AICOM_PRODUCE_BATCH", 3];
_richFlag = _logik getVariable ["wfbe_aicom_reinforce_rich", false];
if (_richFlag) then {_batchCap = _batchCap * 2};

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
_facDefs = [["Barracks","BARRACKSUNITS",WFBE_UP_BARRACKS], ["Light","LIGHTUNITS",WFBE_UP_LIGHT], ["Heavy","HEAVYUNITS",WFBE_UP_HEAVY]];
//--- AIRCRAFT GATE (defence-in-depth, mirrors AI_Commander_Base): only let the producer
//--- make aircraft once the side is established (>= WFBE_C_AICOM_AIR_MIN_TOWNS towns), so a
//--- captured/pre-placed air factory can't pump aircraft the AI flies poorly with early on.
_myID = (_side) Call WFBE_CO_FNC_GetSideID;
_ownTowns = 0;
{ if ((_x getVariable "sideID") == _myID) then {_ownTowns = _ownTowns + 1} } forEach towns;
if (_ownTowns >= (missionNamespace getVariable ["WFBE_C_AICOM_AIR_MIN_TOWNS", 4])) then {
	_facDefs = _facDefs + [["Aircraft","AIRCRAFTUNITS",WFBE_UP_AIR]];
};

{
	_team = _x;
	//--- V0.6.5: skip NULL entries (wiped HC teams; getVariable on a null group returns
	//--- nil even with a default -> the lazy-brace check below threw and killed Produce,
	//--- stopping ALL factory purchases for editor teams).
	if (!isNull _team) then {
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
	//--- V0.5: reinforcement sanity - AIBuyUnit spawns refills at the factory, so only
	//--- refill teams near the base; fully wiped teams reform at base anyway.
	if (_canProduce && {({alive _x} count (units _team)) > 0}) then {
		_hqP = (_side) Call WFBE_CO_FNC_GetSideHQ;
		if (!isNull _hqP) then {
			_ldr = leader _team;
			if (_ldr distance _hqP > (missionNamespace getVariable ["WFBE_C_AI_COMMANDER_REINFORCE_RANGE", 1200])) then {
				//--- FORWARD-REINFORCE: a deep team beyond base range may still refill if its
				//--- leader is hugging an owned town (front-line resupply), so spearheads stop
				//--- bleeding out far from HQ. The refill spawn point is pulled forward below.
				_nearFwd = false;
				if (_ownTowns > 0) then {
					_fwdR = missionNamespace getVariable ["WFBE_C_AICOM_FWD_REINFORCE_RANGE", 500];
					{ if (((_x getVariable "sideID") == _myID) && {(_ldr distance _x) < _fwdR}) exitWith {_nearFwd = true} } forEach towns;
				};
				if (!_nearFwd) then {_canProduce = false};
			};
		};
	};
	if (_canProduce) then {
		_template = _templates select _type;
		_cur  = {alive _x} count (units _team);
		//--- punchy-AICOM SIZE FLOOR (Ray 2026-06-17; deficit-fill 2026-06-18): an infantry/light-motorized
		//--- team is built/topped-up to clamp(templateSize, MIN, MAX). MBT teams + ATTACK-HELI teams are
		//--- EXEMPT from the MIN floor (vehicle+crew is the punch - never pad with riflemen).
		//--- DEFICIT-FILL FIX (2026-06-18): the floor now applies on REFILL of an existing under-strength team
		//--- too (not only when _cur==0). Previously _cur>0 refills used floor=1, so a team that founded small
		//--- then refilled plateaued at its template size (~5.5) instead of 8-12; LIVE CMDRSTAT showed
		//--- unitsPerTeam 5.4-5.8 with captures=0. Under-strength non-MBT/non-attack-heli teams now top up
		//--- toward MIN (8). When the template composition is already complete but the team is still below the
		//--- floor, the selector below pads with an extra dismount (FILL-TO-FLOOR) so small patrols actually
		//--- reach 8-12. Still bounded by sizeMax/AI_MAX, the batch/funds caps, and the per-side AI ceiling.
		//--- A2-OA detection: classname-literal isKindOf + getNumber transportSoldier (no A3 primitives).
		private ["_tmplSize","_isMBT","_isAttackHeli","_floorN","_sizeMin","_sizeMax"];
		_tmplSize = count _template;
		_sizeMin  = missionNamespace getVariable ["WFBE_C_AICOM_TEAM_SIZE_MIN", 8];
		_sizeMax  = missionNamespace getVariable ["WFBE_C_AICOM_TEAM_SIZE_MAX", 12];
		_isMBT = false;
		{ if (_x isKindOf "Tank") exitWith {_isMBT = true} } forEach _template;
		_isAttackHeli = false;
		{ if (_x isKindOf "Helicopter" && {(getNumber (configFile >> "CfgVehicles" >> _x >> "transportSoldier")) == 0}) exitWith {_isAttackHeli = true} } forEach _template;
		_floorN = if (!(_isMBT || _isAttackHeli)) then {_sizeMin} else {1};
		_want = ((_tmplSize max _floorN) min _sizeMax) min (missionNamespace getVariable "WFBE_C_AI_MAX");

		//--- RANK-2 health-gated refill (claude-gaming 2026-06-13): a critically-weak or JUST-FOUNDED server-local
		//--- team (alive < CRITICAL_STRENGTH of template) is rushed to FULL this cycle (effective batch = full
		//--- deficit) so server-local teams form WHOLE instead of dribbling 1-3/cycle, and depleted teams stop
		//--- lingering as 2-man remnants (cuts groups + drains the stuck war chest). Healthy teams keep the small
		//--- batch. STILL bounded by the funds gate + factory + the per-side AI cap, so no spawn runaway; HC teams
		//--- already skipped above. Set WFBE_C_AICOM_CRITICAL_STRENGTH <= 0 to disable (revert to flat batch cap).
		_effBatch = _batchCap;
		if (_want > 0 && {(_cur / _want) < (missionNamespace getVariable ["WFBE_C_AICOM_CRITICAL_STRENGTH", 0.30])}) then {
			_effBatch = _want - _cur;
		};

		if (_cur < _want) then {
			//--- V0.6.7: order up to batch cap units per team this cycle (deficit-capped; RANK-2 raises it for weak teams).
			_batchOrdered = 0;
			_ordered = []; //--- E7: per-class pending-order tally (reset per team)
			while {_cur < _want && _batchOrdered < _effBatch} do {
				//--- First template classname the team is still short on.
				_toBuild = "";
				{
					_d = _x;
					_have = ({typeOf _x == _d} count (units _team)) + ({_x == _d} count _ordered); //--- E7: real members + this-batch pending (async) orders
					if (_have < ({_x == _d} count _template)) exitWith {_toBuild = _d};
				} forEach _template;

				//--- FILL-TO-FLOOR (deficit-fill 2026-06-18): the template composition is already satisfied
				//--- but _cur is still below _want (the MIN floor raised the target above templateSize). Pad
				//--- with one extra dismount so infantry/light-motorized teams actually reach 8-12 instead of
				//--- plateauing at their template size. Pick the LAST man-class in the template (a basic
				//--- rifleman/grenadier) - never duplicate a vehicle. MBT/attack-heli teams never reach here
				//--- (floor=1 -> _want=templateSize). A2-OA safe: classname-literal isKindOf "Man".
				if (_toBuild == "") then {
					{ if (_x isKindOf "Man") then {_toBuild = _x} } forEach _template;
				};

				if (_toBuild == "") exitWith {}; //--- Nothing buildable (all-vehicle template) - stop batch.

				//--- Which production factory builds it?
				_fac = [];
				{
					_unitList = missionNamespace getVariable [Format ["WFBE_%1%2", _sideText, (_x select 1)], []];
					if (_toBuild in _unitList) exitWith {_fac = _x};
				} forEach _facDefs;

				if (count _fac == 0) exitWith {}; //--- No factory handles this class.

				_ud = missionNamespace getVariable _toBuild;
				if (isNil "_ud") exitWith {};

				_typeName = _fac select 0;
				_track    = _fac select 2;
				_reqUp    = _ud select QUERYUNITUPGRADE;
				_price    = _ud select QUERYUNITPRICE;

				if (_reqUp > (_upgrades select _track)) exitWith {}; //--- Not unlocked yet.

				_kind = _structTypes find _typeName;
				if (_kind < 0) exitWith {};

				_factories = [_side, _kind, _buildings] Call GetFactories;
				if (count _factories == 0) exitWith {};

				//--- FORWARD-REINFORCE: spawn the refill at the factory nearest this team's
				//--- leader. A forward team hugging a captured town refills from that town's
				//--- factory (resupplies the front) instead of a lone unit trekking from the
				//--- rear. Null leader (wiped team) falls back to factory[0] = reform at base.
				_facObj = _factories select 0;
				_ldr = leader _team;
				if (!isNull _ldr) then {
					{ if ((_x distance _ldr) < (_facObj distance _ldr)) then {_facObj = _x} } forEach _factories;
				};

				_funds = (_side) Call GetAICommanderFunds;
				if (_funds < _price) exitWith {}; //--- Cannot afford next unit; stop batch.

				//--- W15 BLACK MARKET (claude-gaming 2026-06-13): honor a live 50% discount flag set by the wildcard deck.
					private ["_w15Key","_w15Exp","_priceCharged"];
					_w15Key = Format ["wfbe_aicom_discount_%1", _sideText];
					_w15Exp = missionNamespace getVariable _w15Key;
					_priceCharged = if (!isNil "_w15Exp" && {_w15Exp > time}) then {round (_price * 0.5)} else {_price};
					[_side, -_priceCharged] Call ChangeAICommanderFunds;
				_isVeh = if (_toBuild isKindOf "Man") then {[]} else {[true,true,true,true]};
				_id = [floor (random 1000000)];
				_q = (_team getVariable ["wfbe_queue", []]) + [_id];
				_team setVariable ["wfbe_queue", _q];
				[_id, _facObj, _toBuild, _side, _team, _isVeh] Spawn AIBuyUnit;
				_ordered = _ordered + [_toBuild]; //--- E7: record in-flight order so the selector counts it
				["INFORMATION", Format ["AI_Commander_Produce.sqf: [%1] team [%2] ordering [%3] at %4 factory (cost %5, batch %6/%7 rich=%8).", _sideText, _team, _toBuild, _typeName, _price, _batchOrdered + 1, _batchCap, _richFlag]] Call WFBE_CO_FNC_AICOMLog;

				_batchOrdered = _batchOrdered + 1;
				_cur = _cur + 1; //--- Optimistic count so deficit loop terminates correctly.
			};
		};
	};
	}; //--- V0.6.5 null-team guard
} forEach _teams;
