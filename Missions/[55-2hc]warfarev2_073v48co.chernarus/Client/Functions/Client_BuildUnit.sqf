Private ["_building","_buyFailed","_cpt","_commander","_crew","_crewCostPerHead","_crewCreated","_currentUnit","_description","_direction","_distance","_driver","_extracrew","_factory","_factoryPosition","_factoryType","_group","_gunner","_index","_init","_isArtillery","_isMan","_locked","_longest","_position","_queu","_queu2","_ret","_show","_soldier","_spawnedUnits","_waitTime","_txt","_type","_upgrades","_unique","_unit","_vehi","_vehicle","_vehicles","_faction","_queuLabels","_unitLabel33","_ah6xM134Kit","_tkEasaKit","_tkeRow","_nextQueueHint","_queuePos","_queueEta","_qTailFn","_qTail","_isTkvToken","_scudProof"];
_building = _this select 0;
_unit = _this select 1;
_vehi = _this select 2;
_factory = _this select 3;
_cpt = _this select 4;
_currentCost = if (count _this > 5) then {_this select 5} else {0}; //--- FC2: client-paid crew component; SCUD hull cost is charged by the server on proof consumption.
_scudProof = if (count _this > 6) then {_this select 6} else {""};

_isMan = if (_unit isKindOf "Man") then {true} else {false};

unitQueu = unitQueu + _cpt;

_distance = 0;
_direction = 0;
_longest = 0;
_position = 0;
_waitTime = 0;
_factoryType = "";
_description = "";

_currentUnit = missionNamespace getVariable _unit;
//--- fable/fix-unit-purchase-nil-guards: guard nil _currentUnit (unregistered classname) before the select-chain below - matches a55605e10/#1003/Server_BuyUnit.sqf(#1001) shape. Nil = keep the safe pre-init defaults above (_waitTime=0, _description="").
if !(isNil "_currentUnit") then {
_waitTime = _currentUnit select QUERYUNITTIME;
_description = _currentUnit select QUERYUNITLABEL;
} else {
	["WARNING", Format ["Client_BuildUnit.sqf: unit classname [%1] not registered in missionNamespace; using safe defaults (waitTime=0, no description).", _unit]] Call WFBE_CO_FNC_LogContent;
};
	
_spawnpaddir=2;


_type = typeOf _building;
_index = (missionNamespace getVariable Format ["WFBE_%1STRUCTURENAMES",sideJoinedText]) find _type;
if (_index != -1) then {
	_distance = (missionNamespace getVariable Format ["WFBE_%1STRUCTUREDISTANCES",sideJoinedText]) select _index;
	_direction = (missionNamespace getVariable Format ["WFBE_%1STRUCTUREDIRECTIONS",sideJoinedText]) select _index;
	_factoryType = (missionNamespace getVariable Format ["WFBE_%1STRUCTURES",sideJoinedText]) select _index;

	
if (_factoryType in ["Light"]) then {
	//--- Place Wheeled vehicles on Pads if avaiable.
	Private ["_pads","_free","_dir","_no","_selpad"];

	_pads = _building nearObjects ["HeliH", 250];

	// Filter out unwanted objects from _pads based on their names (because they inherit from HeliH)
    _filteredPads = [];
    {
        if (typeOf _x != "HeliHCivil" && typeOf _x != "HeliHRescue") then {
            _filteredPads set [count _filteredPads, _x];
        };
    } forEach _pads;
    _pads = _filteredPads;

	_free = [];
	_dir = 0;
	if (count _pads > 0) then {
		for "_i" from 0 to (count _pads - 1) do {
			_dir = getDir (_pads select _i);
			_free = _free + [[getpos (_pads select _i), _dir]];
		};
	};
	if (count _free > 0) then {
		_selpad =_free  call BIS_fnc_selectRandom;
		_position = [_selpad select 0 select 0,_selpad select 0 select 1,_selpad select 1];
		_position set [2, .5];
		_spawnpaddir=5;//dirswitch to prevent overwrite dir later
		_direction=_selpad select 1;

	}else{
	_position = _building modelToWorld [(sin _direction * _distance), (cos _direction * _distance), 0];
	_position set [2, .5];};

}else{//---------------------------------------------------------check for heavy


if (_factoryType in ["Heavy"]) then {
	//--- Place Wheeled vehicles on Pads if avaiable.
	Private ["_pads","_free","_dir","_no","_selpad"];
	_pads = _building nearObjects ["HeliHRescue", 250];
	_free = [];
	_dir = 0;
	if (count _pads > 0) then {
		for "_i" from 0 to (count _pads - 1) do {
			_dir = getDir (_pads select _i);
			_free = _free + [[getpos (_pads select _i), _dir]];
		};
	};
	if (count _free > 0) then {
		_selpad =_free  call BIS_fnc_selectRandom;
		_position = [_selpad select 0 select 0,_selpad select 0 select 1,_selpad select 1];
		_position set [2, .5];
		_spawnpaddir=5;//dirswitch to prevent overwrite dir later
		_direction=_selpad select 1;

	}else{
	_position = _building modelToWorld [(sin _direction * _distance), (cos _direction * _distance), 0];
	_position set [2, .5];};

}else{//--------------------------------------------------------check for air


if (_factoryType in ["Aircraft"]) then {
	//--- Place Wheeled vehicles on Pads if avaiable.
	Private ["_pads","_free","_dir","_no","_selpad"];
	_pads = _building nearObjects ["HeliHCivil", 250];
	_free = [];
	_dir = 0;
	if (count _pads > 0) then {
		for "_i" from 0 to (count _pads - 1) do {
			_dir = getDir (_pads select _i);
			_free = _free + [[getpos (_pads select _i), _dir]];
		};
	};
	if (count _free > 0) then {
		_selpad =_free  call BIS_fnc_selectRandom;
		_position = [_selpad select 0 select 0,_selpad select 0 select 1,_selpad select 1];
		_position set [2, .5];
		_spawnpaddir=5;//dirswitch to prevent overwrite dir later
		_direction=_selpad select 1;

	}else{
	_position = _building modelToWorld [(sin _direction * _distance), (cos _direction * _distance), 0];
	_position set [2, .5];};

}else{//-------------------------------------------its barracks,found only 3 marker in a2 for now

	//--- Place Wheeled vehicles on Pads if avaiable.
	Private ["_pads","_free","_dir","_no","_selpad"];
	_pads = _building nearObjects ["Sr_border", 250];
	_free = [];
	_dir = 0;
	if (count _pads > 0) then {
		for "_i" from 0 to (count _pads - 1) do {
			_dir = getDir (_pads select _i);
			_free = _free + [[getpos (_pads select _i), _dir]];
		};
	};
	if (count _free > 0) then {
		_selpad =_free  call BIS_fnc_selectRandom;
		_position = [_selpad select 0 select 0,_selpad select 0 select 1,_selpad select 1];
		_position set [2, .5];
		_spawnpaddir=5;//dirswitch to prevent overwrite dir later
		_direction=_selpad select 1;

	}else{
	_position = _building modelToWorld [(sin _direction * _distance), (cos _direction * _distance), 0];
	_position set [2, .5];};

//_position = [getPos _building,_distance,getDir _building + _direction] Call GetPositionFrom;

};};};

//--- cmdcon44-f (Ray 2026-07-03, Zargabad live): CASE FIX. Init_Common.sqf:369 stores these keys UPPERCASE
//--- (forEach ["BARRACKS","LIGHT","HEAVY","AIRCRAFT","AIRPORT","DEPOT"]) but _factoryType here is Title-case
//--- ("Barracks"/"Light"/"Heavy"/"Aircraft"), so Format["WFBE_LONGEST%1BUILDTIME",_factoryType] built a
//--- non-existent Title-cased key (e.g. ...LONGEST + Light + BUILDTIME) -> _longest was nil on EVERY player buy. A2-OA
//--- silently evaluates `_ret > nil` and `_queuePos * nil` as nil (no RPT error), so the stuck-head purge
//--- (the _ret>_longest branch below) never fired and the queue-ETA hint rendered garbage - a batch of buys
//--- could pile in the queue, climb unitQueu and never spawn with ZERO logged error. toUpper re-arms the
//--- lookup exactly like the AI path already does (Server_BuyUnit.sqf:101). Floor guarantees a real number.
_longest = missionNamespace getVariable Format ["WFBE_LONGEST%1BUILDTIME",toUpper _factoryType];
if (isNil "_longest" || {_longest <= 0}) then {_longest = 60};  //--- safety floor: the purge deadline must always be a real number (mirrors Server_BuyUnit.sqf:102).


} else {
	if (_type == WFBE_Logic_Depot) then {
		_distance = missionNamespace getVariable "WFBE_C_DEPOT_BUY_DISTANCE";
		_direction = missionNamespace getVariable "WFBE_C_DEPOT_BUY_DIR";
		_factoryType = "Depot";
	};
	if (_type == WFBE_Logic_Airfield) then {
		_distance = missionNamespace getVariable "WFBE_C_HANGAR_BUY_DISTANCE";
		_direction = missionNamespace getVariable "WFBE_C_HANGAR_BUY_DIR";
		_factoryType = "Airport";
	};
	_position = [getPos _building,_distance,getDir _building + _direction] Call GetPositionFrom;
	//--- depot-buy-round3 (diagnostic, ALWAYS-ON): the depot/airfield spawn path had NO observable
	//--- output on release clients - every WFBE_CO_FNC_LogContent breadcrumb here is compiled out
	//--- (WF_LOG_CONTENT undefined on players; only HCs force it). This one plain diag_log is the
	//--- evidence line: the next failed Depot/Airport buy on ANY client leaves the resolved factory
	//--- object + its getPos + the computed spawn position + side + class in that client's RPT, so a
	//--- null/blocked spawn (createVehicle/createUnit objNull) can finally be told apart from a bad
	//--- resolve. One line per Depot/Airport buy (not the per-second queue loop); negligible cost.
	diag_log Format ["BUYTRACE|v1|depot-pos|side=%1|factory=%2|class=%3|obj=%4|objType=%5|objPos=%6|spawnPos=%7|dist=%8|dir=%9", sideJoinedText, _factoryType, _unit, _building, _type, getPos _building, _position, _distance, _direction];
	//--- cmdcon44-f: same case fix as the factory branch above - "Depot"/"Airport" must be UPPERCASEd to match
	//--- the WFBE_LONGEST*BUILDTIME keys stored in Init_Common.sqf:369 (DEPOT/AIRPORT), else _longest = nil.
	_longest = missionNamespace getVariable Format ["WFBE_LONGEST%1BUILDTIME",toUpper _factoryType];
	if (isNil "_longest" || {_longest <= 0}) then {_longest = 60};  //--- safety floor (mirrors Server_BuyUnit.sqf:102).
};

if ((missionNamespace getVariable ["WFBE_C_FIX_FACTORY_QUEUE_TOKEN_HARDENING", 0]) > 0) then {
	if (isNil "WFBE_CL_FACTORY_QUEUE_SEQUENCE") then {WFBE_CL_FACTORY_QUEUE_SEQUENCE = 0};
	WFBE_CL_FACTORY_QUEUE_SEQUENCE = WFBE_CL_FACTORY_QUEUE_SEQUENCE + 1;
	varQueu = Format["%1_%2_%3_%4", getPlayerUID player, diag_tickTime, WFBE_CL_FACTORY_QUEUE_SEQUENCE, floor random 1000000];
} else {
	varQueu = Format["%1_%2", getPlayerUID player, diag_tickTime];
};
_unique = varQueu;
_queu = _building getVariable "queu";
if (isNil "_queu") then {_queu = []};
_queu = _queu + [_unique];
_building setVariable ["queu",_queu,true];
//--- QoL cancel: store price-paid and cpt in parallel arrays so Action_CancelQueue.sqf can refund correctly.
private ["_queuCosts","_queuCpts"];
_queuCosts = _building getVariable ["queu_costs", []];
_queuCosts = _queuCosts + [_currentCost];
_building setVariable ["queu_costs", _queuCosts, true];
_queuCpts = _building getVariable ["queu_cpts", []];
_queuCpts = _queuCpts + [_cpt];
_building setVariable ["queu_cpts", _queuCpts, true];
//--- Task 33: store the human-readable unit label so the buy-menu queue readout can display it.
_unitLabel33 = _currentUnit select QUERYUNITLABEL;
_queuLabels = _building getVariable ["queu_labels", []];
_queuLabels = _queuLabels + [_unitLabel33];
_building setVariable ["queu_labels", _queuLabels, true];
//--- QoL cancel: add a cancel action on this building for the buyer (removed after their slot resolves).
private ["_cancelActionID"];
_cancelActionID = _building addAction [
	"<t color='#ff9900'>Cancel last queued unit</t>",
	"Client\Action\Action_CancelQueue.sqf",
	[_factory],
	50,
	false,
	true,
	"",
	"cursorObject == _target && player distance _target < 25"
];
_building setVariable [Format ["wfbe_cancel_action_%1", getPlayerUID player], _cancelActionID];

_ret = 0;
_queu2 = [0];

if (count _queu > 0) then {_queu2 = _building getVariable "queu"};

_show = false;
_nextQueueHint = time;
//--- Ray 2026-07-04: build the compact QUEUED tail from the building's real ordered label list
//--- (queu_labels, kept parallel to queu). Drop slot 0 (the item building / next up), compress runs
//--- of the same label to "Label xK", cap the shown segments to 5 and append " +N more" counting the
//--- pending UNITS not shown. Empty string when nothing is pending after the head (so the readout stays
//--- single-item, no trailing pipe). Each _out entry is [segmentText, unitCount] so +N needs no string parse.
_qTailFn = {
	private ["_lbls","_out","_shown","_i","_cur","_run","_more","_seg","_joined","_j"];
	_lbls = _this;
	if (isNil "_lbls") then {_lbls = []};
	if ((count _lbls) <= 1) exitWith {""};
	//--- pending = everything after the head (slot 0). Compress consecutive duplicates.
	_out = [];
	_i = 1;
	while {_i < (count _lbls)} do {
		_cur = _lbls select _i;
		_run = 1;
		while {((_i + _run) < (count _lbls)) && {(_lbls select (_i + _run)) == _cur}} do {_run = _run + 1};
		_seg = if (_run > 1) then {Format ["%1 x%2", _cur, _run]} else {_cur};
		_out = _out + [[_seg, _run]];
		_i = _i + _run;
	};
	//--- cap the DISTINCT shown segments to 5; +N counts the pending UNITS beyond those 5 segments.
	_shown = _out;
	_more = 0;
	if ((count _out) > 5) then {
		_shown = [_out select 0, _out select 1, _out select 2, _out select 3, _out select 4];
		_more = (count _lbls) - 1;
		{_more = _more - (_x select 1)} forEach _shown;
		if (_more < 0) then {_more = 0};
	};
	_joined = "";
	_j = 0;
	{
		if (_j == 0) then {_joined = (_x select 0)} else {_joined = _joined + ", " + (_x select 0)};
		_j = _j + 1;
	} forEach _shown;
	if (_more > 0) then {_joined = _joined + Format [" +%1 more", _more]};
	_joined
};
while {!(_unique in [_queu select 0]) && alive _building && !isNull _building} do {
	sleep 4;
	_show = true;
	_ret = _ret + 4;
	_queu = _building getVariable "queu";
	if ((count _queu > 0) && {time >= _nextQueueHint}) then {
		_nextQueueHint = time + 12;
		_queuePos = _queu find _unique;
		if (_queuePos >= 0) then {
			_queueEta = (_queuePos * _longest) + _waitTime;
			if (_queueEta < _waitTime) then {_queueEta = _waitTime};
			//--- Ray B89: route the queue readout to the RHUD bottom line (WFBE_CL_QUEUE_HUD) instead of a
			//--- center-screen titleText. Client_UpdateRHUD.sqf renders it (small, colored) and auto-hides it
			//--- when the timestamp goes stale, so no exit path needs to clear it. Compact: FACTORY | UNIT #p/t ~ETAs.
			WFBE_CL_QUEUE_HUD = Format ["<t color='#ffd24a' size='0.9'>%1 | %2  #%3/%4  ~%5s</t>", _factoryType, _description, _queuePos + 1, count _queu, ceil _queueEta];
			//--- Ray 2026-07-04: append the pending QUEUED tail (everything after the head) in a dimmer color.
			_qTail = (_building getVariable ["queu_labels", []]) call _qTailFn;
			if (_qTail != "") then {
				WFBE_CL_QUEUE_HUD = WFBE_CL_QUEUE_HUD + Format ["<t color='#b9a94a' size='0.85'>  |  QUEUED: %1</t>", _qTail];
			};
			WFBE_CL_QUEUE_HUD_TS = time;
		};
	};

	if ((_queu select 0) in [_queu2 select 0]) then {
		if (_ret > _longest) then {
			if (count _queu > 0) then {
				_queu = _building getVariable "queu";
				_queu = _queu - [_queu select 0];
				_building setVariable ["queu",_queu,true];
			};
		};
	};
	if !((count _queu) in [count _queu2]) then {
		_ret = 0;
		_queu2 = _building getVariable "queu";
	};
};

if (_show) then {hint(parseText(Format [localize "STR_WF_INFO_BuyEffective",_description]))};

//--- Ray B89: live "building now" countdown on the RHUD queue line while this unit is under construction.
//--- Ticks the same total wall-clock as the old `sleep _waitTime` (guarded end-time), refreshing the HUD var
//--- each second; blanks it on completion so the line hides. No queue-mechanic change (the head is already
//--- ours here - the wait loop above only exits once _unique reached slot 0).
private ["_buildEnd","_bRemain"];
_buildEnd = time + _waitTime;
while {time < _buildEnd && alive _building && !isNull _building} do {
	_bRemain = ceil (_buildEnd - time);
	if (_bRemain < 0) then {_bRemain = 0};
	WFBE_CL_QUEUE_HUD = Format ["<t color='#7bd642' size='0.9'>%1 | BUILDING: %2  ~%3s</t>", _factoryType, _description, _bRemain];
	//--- Ray 2026-07-04: append the pending QUEUED tail (queu_labels after the head) in a dimmer color.
	_qTail = (_building getVariable ["queu_labels", []]) call _qTailFn;
	if (_qTail != "") then {
		WFBE_CL_QUEUE_HUD = WFBE_CL_QUEUE_HUD + Format ["<t color='#5f8f3a' size='0.85'>  |  QUEUED: %1</t>", _qTail];
	};
	WFBE_CL_QUEUE_HUD_TS = time;
	sleep 1;
};
WFBE_CL_QUEUE_HUD = "";
WFBE_CL_QUEUE_HUD_TS = time;

_queu = _building getVariable "queu";
private ["_qIdx"];
_qIdx = _queu find _unique;
_queu = _queu - [_unique];
_building setVariable ["queu",_queu,true];
//--- QoL cancel: keep parallel arrays in sync when the unit actually spawns.
if (_qIdx >= 0) then {
	private ["_qCosts","_qCpts","_qLabels","_newArr","_i"];
	_qCosts = _building getVariable ["queu_costs", []];
	_qCpts  = _building getVariable ["queu_cpts",  []];
	_qLabels = _building getVariable ["queu_labels", []];
	if (_qIdx < count _qCosts) then {
		_newArr = []; _i = 0;
		{if (_i != _qIdx) then {_newArr = _newArr + [_x]}; _i = _i + 1} forEach _qCosts;
		_building setVariable ["queu_costs", _newArr, true];
	};
	if (_qIdx < count _qCpts) then {
		_newArr = []; _i = 0;
		{if (_i != _qIdx) then {_newArr = _newArr + [_x]}; _i = _i + 1} forEach _qCpts;
		_building setVariable ["queu_cpts", _newArr, true];
	};
	//--- Task 33: keep queu_labels in sync.
	if (_qIdx < count _qLabels) then {
		_newArr = []; _i = 0;
		{if (_i != _qIdx) then {_newArr = _newArr + [_x]}; _i = _i + 1} forEach _qLabels;
		_building setVariable ["queu_labels", _newArr, true];
	};
};
//--- QoL cancel: remove the per-player cancel action once their slot is resolved.
private ["_myActionKey","_myActionID"];
_myActionKey = Format ["wfbe_cancel_action_%1", getPlayerUID player];
_myActionID = _building getVariable [_myActionKey, -1];
if (_myActionID >= 0) then {
	_building removeAction _myActionID;
	_building setVariable [_myActionKey, -1];
};

//--- E1: was this slot CANCELLED during its build? Action_CancelQueue removed _unique from the queue,
//--- already decremented unitQueu + WFBE_C_QUEUE_<factory>, and refunded the price. Bail WITHOUT spawning
//--- (else the player keeps BOTH the refund AND the unit) and WITHOUT re-touching the counters (the cancel
//--- already balanced them). _qIdx (queue index just after sleep) == -1 means no longer queued => cancelled.
if (_qIdx < 0) exitWith {};
_group = group player;
_spawnedUnits = [];
//--- cmdcon44-g SINGLE-RELEASE CONTRACT. ENGINE-VERIFIED on A2OA 1.64 (XWT probe suite, 2026-07-03,
//--- local offline instance of the live box's own binary): an exitWith fired INSIDE a then{}/else{}
//--- block exits ONLY that block - execution FALLS THROUGH to the shared tail of this script; it does
//--- NOT abort the spawned script. Only a top-scope exitWith (the two exits just above/below) aborts.
//--- Consequence: block-level BUYFAIL exits must NOT release unitQueu / WFBE_C_QUEUE_<factory> inline -
//--- the tail always runs and releases them exactly once. They set _buyFailed instead (refund + RPT
//--- warning stay inline; the tail gates the success-only steps on it).
_buyFailed = false;
//--- TOP-SCOPE exitWith: verified to abort the whole spawned script (the shared tail below never runs),
//--- so THIS exit must keep releasing the counters inline - unlike the block-level exits further down.
if (!alive _building || isNull _building) exitWith {
	unitQueu = (unitQueu - _cpt) max 0;  //--- salvage-522: clamp so an in-flight coroutine firing after a respawn-reset (WFBE_C_FIX_RESPAWN_UNITQUEU_RESET) cannot drive the group-cap counter negative.
	missionNamespace setVariable [Format["WFBE_C_QUEUE_%1",_factory],((missionNamespace getVariable Format["WFBE_C_QUEUE_%1",_factory])-1) max 0];  //--- salvage-522: clamp per-factory queue slot to >=0 (mirror of the unitQueu clamp).
	//--- FC2: factory was destroyed mid-build (nothing spawned) -> refund the purchase price. This is the real destroyed-factory path.
	if (_currentCost > 0) then {(_currentCost) Call ChangePlayerFunds};
};

if (_isMan) then {
	_soldier = [_unit,_group,_position,WFBE_Client_SideID] Call WFBE_CO_FNC_CreateUnit;

	//--- cmdcon44-f (Ray 2026-07-03, Zargabad live): INFANTRY BUYFAIL-REFUND GUARD, the missing sibling of the
	//--- vehicle BUYFAIL guard (cmdcon42c, further below). WFBE_CO_FNC_CreateUnit returns objNull whenever the
	//--- engine refuses the unit (group/unit limit, null group, bad class) - Common_CreateUnit.sqf logs a WARNING
	//--- but still hands back objNull. The player was ALREADY charged at buy time (GUI_Menu_BuyUnits.sqf:
	//--- -(_currentCost) Call ChangePlayerFunds), so a silent null soldier = pay-and-get-nothing AND a leaked
	//--- squad slot: unitQueu never comes back down, so the player hits "max group" with fewer real units than
	//--- the counter claims (exactly Ray's "added to my unit count but nothing spawned"). Refund the exact price
	//--- and flag the buy failed - byte-for-byte the vehicle guard's contract.
	//--- cmdcon44-g: this exitWith only exits the _isMan then-block (ENGINE-VERIFIED, see the _buyFailed
	//--- contract above) - the shared tail still runs and is the single point that releases the queue slot.
	//--- The original inline release here made every infantry BUYFAIL free the slot TWICE.
	if (isNull _soldier) exitWith {
		_buyFailed = true;
		if (_currentCost > 0) then {(_currentCost) Call ChangePlayerFunds};
		//--- depot-buy-round3 (diagnostic, ALWAYS-ON): the WARNING below is compiled out on release clients.
		diag_log Format ["BUYFAIL|v1|infantry|side=%1|factory=%2|class=%3|refund=%4|spawnPos=%5", sideJoinedText, _factory, _unit, _currentCost, _position];
		["WARNING", Format ["Client_BuildUnit.sqf: BUYFAIL infantry buy of [%1] produced objNull (spawn failed) - refunded $%2; queue slot for factory [%3] released once by the shared tail.", _unit, _currentCost, _factory]] Call WFBE_CO_FNC_LogContent;
	};

	//--- OA or CO, Since BIS will soon fix it... not!, we fix unit backpack attachment on creation.
	if (WF_A2_Arrowhead || WF_A2_CombinedOps) then {
		//--- Make sure that our unit is supposed to have a backpack.
		if (getText(configFile >> 'CfgVehicles' >> _unit >> 'backpack') != "") then {
			//--- Retrieve the unit gear config.
			_gear_config = (_unit) Call WFBE_CO_FNC_GetUnitConfigGear;
			_gear_backpack = _gear_config select 2;
			_gear_backpack_content = _gear_config select 3;

			//--- Backpack handling.
			if (_gear_backpack != "") then {[_soldier, _gear_backpack, _gear_backpack_content] Call WFBE_CO_FNC_EquipBackpack};
		};
	};

	//--- TEAMBAR-FIRST (fable/player-teambar-slot): newly bought infantry AI must rank BELOW the player
	//--- (COLONEL) so the A2 command bar always places the player at slot 1. PRIVATE is lowest rank.
	if (!isNull _soldier && {(missionNamespace getVariable ["WFBE_C_PLAYER_TEAMBAR_FIRST", 0]) > 0}) then {
		_soldier setRank "PRIVATE";
	};
	_spawnedUnits = [_soldier];
	//--- UD-23: Unit designer -- apply active template to bought infantry (WFBE_C_UNIT_DESIGNER).
	if ((missionNamespace getVariable ["WFBE_C_UNIT_DESIGNER", 1]) > 0) then {
		private ["_udActive2","_udTemplates2","_udTpl","_udWL","_udML","_udBpC","_udBpCt","_udWpC"];
		private ["_udClW","_udClM","_udClBp","_udClBpCt","_udCost2","_udCI","_udDI"];
		_udActive2    = missionNamespace getVariable ["WFBE_UD_Active", -1];
		_udTemplates2 = missionNamespace getVariable ["WFBE_UD_Templates", [[],[],[],[]]];
		if (_udActive2 >= 0 && {_udActive2 <= 3}) then {
			_udTpl = _udTemplates2 select _udActive2;
			if (count _udTpl > 0) then {
				_udWL   = _udTpl select 0;
				_udML   = _udTpl select 1;
				_udBpC  = _udTpl select 2;
				_udBpCt = _udTpl select 3;
				_udWpC  = _udTpl select 4;
				//--- Validate weapons: keep only missionNamespace-registered strings.
				_udClW = [];
				{
					if (typeName _x == "STRING") then {
						_udDI = missionNamespace getVariable _x;
						if !(isNil "_udDI") then {_udClW = _udClW + [_x]};
					};
				} forEach _udWL;
				//--- Validate magazines.
				_udClM = [];
				{
					if (typeName _x == "STRING") then {
						_udDI = missionNamespace getVariable ("Mag_" + _x);
						if !(isNil "_udDI") then {_udClM = _udClM + [_x]};
					};
				} forEach _udML;
				//--- Validate backpack classname.
				_udClBp = _udBpC;
				if (_udBpC != "") then {
					if (typeName _udBpC != "STRING") then {_udClBp = ""} else {
						_udDI = missionNamespace getVariable _udBpC;
						if (isNil "_udDI") then {_udClBp = ""};
					};
				};
				//--- Validate backpack contents (filter unregistered entries).
				_udClBpCt = _udBpCt;
				if (typeName _udBpCt == "ARRAY" && {count _udBpCt >= 2}) then {
					private ["_udBK","_udBKN","_udBKC","_udBKClN","_udBKClC","_udBKP","_udBKI","_udBKIt"];
					_udClBpCt = [];
					_udBKP = "";
					for "_udBK" from 0 to 1 do {
						_udBKN  = (_udBpCt select _udBK) select 0;
						_udBKC  = (_udBpCt select _udBK) select 1;
						_udBKClN = [];
						_udBKClC = [];
						for "_udBKI" from 0 to ((count _udBKN) - 1) do {
							if (typeName (_udBKN select _udBKI) == "STRING") then {
								_udBKIt = missionNamespace getVariable (_udBKP + (_udBKN select _udBKI));
								if !(isNil "_udBKIt") then {
									_udBKClN = _udBKClN + [_udBKN select _udBKI];
									_udBKClC = _udBKClC + [_udBKC select _udBKI];
								};
							};
						};
						_udClBpCt = _udClBpCt + [[_udBKClN, _udBKClC]];
						_udBKP = "Mag_";
					};
				};
				//--- Compute template gear cost from registry.
				_udCost2 = 0;
				{
					_udCI = missionNamespace getVariable _x;
					if !(isNil "_udCI") then {_udCost2 = _udCost2 + (_udCI select 2)};
				} forEach _udClW;
				{
					_udCI = missionNamespace getVariable ("Mag_" + _x);
					if !(isNil "_udCI") then {_udCost2 = _udCost2 + (_udCI select 2)};
				} forEach _udClM;
				if (_udClBp != "") then {
					_udCI = missionNamespace getVariable _udClBp;
					if !(isNil "_udCI") then {_udCost2 = _udCost2 + (_udCI select 2)};
				};
				if (typeName _udClBpCt == "ARRAY" && {count _udClBpCt >= 2}) then {
					private ["_udBPK2","_udBPN2","_udBPC2","_udBPP2","_udBPI2","_udBPIt2"];
					_udBPP2 = "";
					for "_udBPK2" from 0 to 1 do {
						_udBPN2 = (_udClBpCt select _udBPK2) select 0;
						_udBPC2 = (_udClBpCt select _udBPK2) select 1;
						for "_udBPI2" from 0 to ((count _udBPN2) - 1) do {
							if (typeName (_udBPN2 select _udBPI2) == "STRING") then {
								_udBPIt2 = missionNamespace getVariable (_udBPP2 + (_udBPN2 select _udBPI2));
								if !(isNil "_udBPIt2") then {_udCost2 = _udCost2 + ((_udBPIt2 select 2) * (_udBPC2 select _udBPI2))};
							};
						};
						_udBPP2 = "Mag_";
					};
				};
				//--- Apply: equip AI infantry with template. Skip silently if player is too poor.
				if ((Call GetPlayerFunds) >= _udCost2) then {
					if (_udCost2 > 0) then {-(_udCost2) Call ChangePlayerFunds};
					[_soldier, _udClW, _udClM, _udWpC, _udClBp, _udClBpCt] Call WFBE_CO_FNC_EquipUnit;
					["INFORMATION", Format ["[UD] Applied template slot %1 to infantry ($%2 charged).", _udActive2 + 1, _udCost2]] Call WFBE_CO_FNC_LogContent;
				} else {
					["INFORMATION", Format ["[UD] Insufficient funds for template (slot %1, cost $%2) -- default gear kept.", _udActive2 + 1, _udCost2]] Call WFBE_CO_FNC_LogContent;
				};
			};
		};
	};


	[sideJoinedText,'UnitsCreated',1] Call UpdateStatistics;
} else {
	_driver = _vehi select 0;
	_gunner = _vehi select 1;
	_commander = _vehi select 2;
	_extracrew = _vehi select 3;
	_locked = _vehi select 4;
	_crewCostPerHead = if ((count _vehi) > 5) then {_vehi select 5} else {0};

	_factoryPosition = getPos _building;
	
	
	if (_spawnpaddir==2) then {//there is no spawnpad
	_direction = -((((_position select 1) - (_factoryPosition select 1)) atan2 ((_position select 0) - (_factoryPosition select 0))) - 90);//--- model to world that later on.
	};
	//--- cmdcon42 Option C Row 2: the synthetic buy token "AH6X_M134" is NOT a CfgVehicles class, so
	//--- createVehicle on it would return objNull. Capture the variant flag (the tuple time/label were
	//--- already read from the synthetic key at :21-23 above, giving the 5500 price + "AH-6X (M134)" name),
	//--- then remap _unit to the real hull AH6X_EP1 BEFORE createVehicle. After this line every downstream
	//--- _unit use (createVehicle, isKindOf "Air" pilot-crew + CM/AA blocks) sees the real hull.
	_ah6xM134Kit = (_unit == "AH6X_M134");
	if (_ah6xM134Kit) then {_unit = "AH6X_EP1"};

	//--- fable/east-c130: EASTV_C130J is a SYNTHETIC East buy token (Core_US.sqf registration, Units_CO_RU
	//--- roster, flag WFBE_C_EAST_C130) remapped to the real hull before createVehicle. Stock livery by design.
	if (_unit == "EASTV_C130J") then {_unit = "C130J_US_EP1"};

	//--- cmdcon42-i: TK-EASA variant tokens (e.g. "TKV_AH64D_HELLFIRE") are SYNTHETIC buy keys, NOT CfgVehicles
	//--- classes, so createVehicle on the token would return objNull. Resolve the catalog row (self-gates on
	//--- worldName + WFBE_C_TK_EASA_ROSTER -> [] on Chernarus), capture the kit, then remap _unit to the real base
	//--- hull BEFORE createVehicle so every downstream _unit use (createVehicle, isKindOf "Air" crew/CM blocks)
	//--- sees the real hull. Mirrors the AH6X_M134 precedent (Core_US.sqf synthetic token, PR #151).
	//--- Cheap prefix guard: TK-EASA synthetic tokens are the only classes prefixed "TKV_", so a normal purchase
	//--- (real hull, any map) skips the catalog lookup entirely (no compile, no forEach) - the catalog is only
	//--- consulted for an actual variant buy, which only exists on Takistan with the flag on.
	_tkEasaKit = [];
	//--- GR-2026-07-03a ROOT FIX (Fable, remote-factory-vehicle-buy): the prefix test was `_unit find "TKV_"`,
	//--- but `string find string` is ARMA 3-ONLY. On A2 OA 1.64 `find` requires an ARRAY receiver, so this line
	//--- threw "Error find: Type String, expected Array" (RPT-confirmed, Zwanon/WEST cmdcon44i Zargabad) and
	//--- ABORTED the whole buy coroutine one line before createVehicle (:421) - every player VEHICLE purchase on
	//--- EVERY map was charged then spawned nothing, with no BUYFAIL (createVehicle never ran). Infantry was
	//--- unaffected (the _isMan branch returns above, never reaching here). A2-safe leading-byte compare via
	//--- toArray, exactly the _uidPrefix33 idiom in GUI_Menu_BuyUnits.sqf:297. Keeps the cheap-guard property:
	//--- a non-TKV_ class (the normal case, any map) fails the compare fast and skips the catalog entirely.
	_isTkvToken = {
		private ["_u","_uA","_pA","_pl","_ok","_j"];
		_u = _this;
		_uA = toArray _u;
		_pA = toArray "TKV_";
		_pl = count _pA;
		_ok = (count _uA) >= _pl;
		if (_ok) then {
			for "_j" from 0 to (_pl - 1) do {
				if ((_uA select _j) != (_pA select _j)) exitWith {_ok = false};
			};
		};
		_ok
	};
	if (_unit call _isTkvToken) then {
		{
			if ((_x select 0) == _unit) exitWith { _tkeRow = _x; _unit = _x select 1; _tkEasaKit = _x select 7; };
		} forEach (Call Compile preprocessFile "Common\Functions\Common_TKEasaRoster.sqf");
	};
	//--- GR-2026-07-03a diagnostic (ALWAYS-ON, mirrors the depot-pos trace): the FACTORY branch had no spawn-position
	//--- evidence line. Emit resolved factory obj + getPos + computed spawn pos + class right BEFORE createVehicle so a
	//--- future failed factory buy tells a bad resolve apart from a null/blocked spawn. One line per factory buy.
	//--- WFBE_C_AIR_SPAWN_SAFETY (fable/aircraft-spawn-safety, GR-2026-07-06a restructure):
	//--- PRE-CREATE candidate scan: eliminates the create-then-setPos window that could accrue
	//--- collision damage in the engine physics thread between createVehicle and the old setPos.
	//--- Gate: _factoryType == "Aircraft" || _factoryType == "Airport" identifies aircraft/airfield
	//--- purchases before the vehicle exists (no isKindOf needed pre-creation).
	//--- _unit is the fully-resolved hull classname here (AH6X_M134/TKV_* tokens already remapped).
	//--- Failure modes addressed:
	//---   FM-1  Factory pad picker picks without occupancy check: simultaneous buys land on the same pad.
	//---   FM-2  Airport/hangar always spawns at a fixed offset: multiple buys collide on the same point.
	//---   FM-3  No slope guard: fixed offset can land on taxiway edge, causing slide/flip on spawn.
	//---   FM-4  No clearance guard: static obstacles within rotor/wingtip radius cause instant clip damage.
	//--- Strategy: build a 9-candidate set (nominal + 8-point ring), evaluate slope + occupancy for each,
	//---   take the first passing candidate and update _position before createVehicle.  Fall back to
	//---   nominal if none pass (never block the purchase).  No setPos after creation.
	//--- W3: clearance radius 17 m covers A-10 half-span (~17 m); large fixed-wing still limited by ring
	//---   step (25.5 m at default radius), which may not clear a B-52-class span -- acceptable for A2 OA.
	if ((missionNamespace getVariable ["WFBE_C_AIR_SPAWN_SAFETY", 0]) > 0
		&& {_factoryType == "Aircraft" || _factoryType == "Airport"}) then {
		private ["_nomPos","_safePos","_candidates","_ci","_cpos",
		         "_objs","_sn","_slope","_clearRad","_slopeThresh","_ox","_oy",
		         "_stepAng","_stepDist","_ri","_ra","_filtObjs"];
		//--- nominal spawn position already computed above (factory pad or fixed offset).
		_nomPos = _position;
		_safePos = _nomPos;  //--- default: keep nominal if no candidate passes.
		//--- W3: 17 m covers A-10 half-span; override via WFBE_C_AIR_SPAWN_CLEAR_RADIUS.
		//--- Large fixed-wing (B-1 class) may still overlap at ring step 25.5 m -- document limitation.
		_clearRad = missionNamespace getVariable ["WFBE_C_AIR_SPAWN_CLEAR_RADIUS", 17];
		//--- W2 (fable/east-c130): C-130J hull has ~40 m half-span; bump clearance to 22 m for this spawn only.
		//--- Does not change the global default (17 m) used for all other airframes.
		if (_unit == "C130J_US_EP1" && {WFBE_C_AIR_SPAWN_SAFETY > 0}) then {_clearRad = 22};
		//--- Slope limit: surfaceNormal z=1.0 = flat; 0.97 ~= 14 deg max slope.
		_slopeThresh = missionNamespace getVariable ["WFBE_C_AIR_SPAWN_SLOPE_MAX", 0.97];
		//--- Build 9-candidate set: nominal (index 0) + 8-point ring at 1.5x clearance radius.
		//--- Nominal is tested first -- an unoccupied nominal returns immediately with zero relocation.
		_candidates = [[_nomPos select 0, _nomPos select 1, 0]];
		_stepAng  = 45;
		_stepDist = _clearRad * 1.5;
		_ri = 0;
		while {_ri < 8} do {
			_ra = _ri * _stepAng;
			_ox = (_nomPos select 0) + _stepDist * (sin _ra);
			_oy = (_nomPos select 1) + _stepDist * (cos _ra);
			_candidates = _candidates + [[_ox, _oy, 0]];
			_ri = _ri + 1;
		};
		//--- Evaluate each candidate: (a) slope, (b) clearance from non-infantry objects.
		_ci = 0;
		while {_ci < (count _candidates)} do {
			_cpos = _candidates select _ci;
			_sn = surfaceNormal [_cpos select 0, _cpos select 1];
			_slope = _sn select 2;
			if (_slope < _slopeThresh) then { _ci = _ci + 1 } else {
			//--- nearestObjects [[x,y,z], classes, radius] -- A2-OA safe (no A3 form).
			_objs = nearestObjects [[_cpos select 0, _cpos select 1, 0], ["All"], _clearRad];
			//--- No vehicle to exclude: scan runs before createVehicle.
			_filtObjs = [];
			{ if (!(_x isKindOf "Man")) then { _filtObjs = _filtObjs + [_x] } } forEach _objs;
			if ((count _filtObjs) > 0) then { _ci = _ci + 1 } else {
				_safePos = [_cpos select 0, _cpos select 1, 0.5];
				_ci = count _candidates;
			};
			};
		};
		//--- Apply safe position BEFORE createVehicle: vehicle is created at the safe point directly.
		_position = _safePos;
		if ((_safePos select 0) != (_nomPos select 0) || {(_safePos select 1) != (_nomPos select 1)}) then {
			diag_log Format ["AIRSPAWN|v2|pre-create-relocated|side=%1|class=%2|from=%3|to=%4", sideJoinedText, _unit, _nomPos, _safePos];
		} else {
			diag_log Format ["AIRSPAWN|v2|pre-create-ok|side=%1|class=%2|pos=%3", sideJoinedText, _unit, _safePos];
		};
	};
	//--- carrier-deck-spawn-xy (fable/tonight-hotfixes2): ROOT CAUSE FIX. The Depot buy path
	//--- uses WFBE_C_DEPOT_BUY_DIR=0 (absolute north) + distance 21m; carriers face east
	//--- (SpawnLHD dir=90) and their town logics keep getDir 0, so the spawn point lands 5m
	//--- past the ~16m port half-beam - over open water - and the vehicle sinks unseen.
	//--- The old Z-only override was inert (Depot path already preserves deck-height Z).
	//--- Deck-centred point via deckpart modelToWorld [0,-50,0]: 50m toward the bow on the
	//--- centreline, clear of the HeliH pad, SCUD, and stern camps.
	if (_building getVariable ["wfbe_is_carrier_hvt", false]) then {
		private ["_deckZ","_deckPart","_deckXY"];
		_deckZ    = _building getVariable ["wfbe_naval_deckz", 15.9];
		_deckPart = _building getVariable ["wfbe_naval_deckpart", objNull];
		if (!isNull _deckPart) then {
			_deckXY = _deckPart modelToWorld [0, -50, 0];
			_position = [_deckXY select 0, _deckXY select 1, _deckZ];
		} else {
			_position = [(getPosASL _building) select 0, (getPosASL _building) select 1, _deckZ];
		};
	};
	diag_log Format ["BUYTRACE|v1|factory-pos|side=%1|factory=%2|class=%3|obj=%4|objType=%5|objPos=%6|spawnPos=%7|remote=%8", sideJoinedText, _factory, _unit, _building, typeOf _building, getPos _building, _position, !(local _building)];
	_vehicle = [_unit, _position, sideID, _direction, _locked] Call WFBE_CO_FNC_CreateVehicle;
	//--- GR-2026-07-03a diagnostic (ALWAYS-ON): name the createVehicle RETURN at the call site so the next failed buy
	//--- shows objNull-vs-hull without waiting for the downstream BUYFAIL guard. isNull => the BUYFAIL branch below fires.
	diag_log Format ["BUYTRACE|v1|createveh|side=%1|factory=%2|class=%3|null=%4|veh=%5|vehPos=%6", sideJoinedText, _factory, _unit, isNull _vehicle, _vehicle, (if (isNull _vehicle) then {[]} else {getPos _vehicle})];

	//--- naval-air-spawn-easa: carrier fixed-wing velocity fix + EASA random.
	//--- WFBE_CO_FNC_CreateVehicle with _special="FORM" (default) calls
	//---   setVelocity [0,0,-1] (downward kick) — safe for rotary/ground vehicles
	//---   but causes fixed-wing to stall-dive on carrier deck spawn.
	//--- Override: if spawned from a carrier HVT airfield AND the hull is a
	//---   fixed-wing (isKindOf "Plane" walks CfgVehicles, valid for vehicles):
	//---   a) set a random heading and apply forward speed (~80 m/s).
	//---   b) if WFBE_C_NAVAL_EASA_RANDOM > 0, apply a random EASA preset
	//---      (EASA_Equip runs client-side on the local hull — safe here).
	if (!isNull _vehicle && {_building getVariable ["wfbe_is_carrier_hvt", false]}) then {
		private ["_carrierDir","_easaVehi","_easaTypeIdx","_easaLoadouts","_easaRandIdx","_cReseatZ","_cReseatP"];
		//--- carrier-deck-reseat (fable/tonight-hotfixes2): FORM createVehicle over water may seat
		//--- the hull at the water surface despite _position Z. Hard-seat to deck height at the
		//--- vehicle's actual post-create XY; reset the [0,0,-1] spawn kick for helicopters
		//--- (planes get the 80 m/s launch override just below anyway).
		_cReseatZ = _building getVariable ["wfbe_naval_deckz", 15.9];
		_cReseatP = getPosASL _vehicle;
		_vehicle setPosASL [_cReseatP select 0, _cReseatP select 1, _cReseatZ];
		if (_vehicle isKindOf "Helicopter") then {
			_vehicle setVelocity [0, 0, 0];
		};
		//--- Fixed-wing velocity fix: override the downward kick from FORM spawn.
		if (_vehicle isKindOf "Plane") then {
			_carrierDir = random 360;
			_vehicle setDir _carrierDir;
			_vehicle setVelocity [(sin _carrierDir) * 80, (cos _carrierDir) * 80, 0];
		};
		//--- EASA random preset.
		if ((missionNamespace getVariable ["WFBE_C_NAVAL_EASA_RANDOM", 0]) > 0) then {
			_easaVehi = missionNamespace getVariable ["WFBE_EASA_Vehicles", []];
			_easaTypeIdx = _easaVehi find (typeOf _vehicle);
			if (_easaTypeIdx >= 0) then {
				_easaLoadouts = (missionNamespace getVariable ["WFBE_EASA_Loadouts", []]) select _easaTypeIdx;
				_easaRandIdx = floor (random (count _easaLoadouts));
				[_vehicle, _easaRandIdx] call EASA_Equip;
				["INFORMATION", Format ["Client_BuildUnit.sqf: naval EASA random preset %1 applied to %2 (carrier buy).", _easaRandIdx, typeOf _vehicle]] Call WFBE_CO_FNC_LogContent;
			};
		};
	};

	//--- cmdcon42c HOTFIX (Ray 2026-07-02): UNIVERSAL BUYFAIL-REFUND GUARD. WFBE_CO_FNC_CreateVehicle
	//--- returns objNull whenever the engine cannot spawn the hull - a bad/unresolved buy class (e.g. a
	//--- synthetic AH6X_M134 / TKV_* token whose remap above did not resolve to a real hull), a blocked
	//--- spawn position, or any createVehicle failure. The player was ALREADY charged at buy time
	//--- (GUI_Menu_BuyUnits.sqf: -(_currentCost) Call ChangePlayerFunds), so a silent null spawn = the
	//--- player pays and gets nothing. Detect it here, refund the exact price paid, and flag the buy failed.
	//--- cmdcon44-g: this exitWith only exits this else-block (ENGINE-VERIFIED, see the _buyFailed contract
	//--- above) - the shared tail still runs and is the single point that releases the queue slot + unitQueu.
	//--- The original inline release here made every vehicle BUYFAIL free the slot TWICE.
	if (isNull _vehicle) exitWith {
		_buyFailed = true;
		if (_currentCost > 0) then {(_currentCost) Call ChangePlayerFunds};
		//--- depot-buy-round3 (diagnostic, ALWAYS-ON): the WARNING below is compiled out on release clients.
		diag_log Format ["BUYFAIL|v1|vehicle|side=%1|factory=%2|class=%3|refund=%4|spawnPos=%5", sideJoinedText, _factory, _unit, _currentCost, _position];
		["WARNING", Format ["Client_BuildUnit.sqf: buy of [%1] produced objNull (spawn failed) - refunded $%2; queue slot for factory [%3] released once by the shared tail.", _unit, _currentCost, _factory]] Call WFBE_CO_FNC_LogContent;
	};

	clientTeam reveal _vehicle;

	//--- cmdcon42 Option C Row 2: arm the AH-6X hull with the AH-6J's minigun. The AH6X_EP1 hull ships
	//--- UNARMED (weapons[]={}/magazines[]={}, config-proven from CfgVehicles AH6X_EP1). We add the exact
	//--- weapon+magazine the armed AH6J_EP1 carries: weapon "TwinM134" (class TwinM134 : M134) and magazine
	//--- "4000Rnd_762x51_M134" (both config-proven present in CfgWeapons/CfgMagazines). On the AH-6 these are
	//--- HULL-level (AH6J_EP1 weapons[]/magazines[] sit on the vehicle body, class Turrets {} is empty), so
	//--- plain addWeapon/addMagazine (NOT the [-1] turret path used for the Ka-137). Runs on the buyer's client
	//--- on the freshly-created local hull (same machine/timing as the existing GUER Ka-137 flares kit below);
	//--- Common_CreateVehicle globalizes the hull via setVehicleInit right after creation, so the weapon state
	//--- replicates. Idempotent remove-then-add so a re-buy or JIP re-run cannot stack duplicate mags.
	if (_ah6xM134Kit && {!isNull _vehicle}) then {
		_vehicle removeMagazine "4000Rnd_762x51_M134";
		_vehicle removeWeapon "TwinM134";
		_vehicle addWeapon "TwinM134";
		_vehicle addMagazine "4000Rnd_762x51_M134";
		["INFORMATION", Format ["Client_BuildUnit.sqf: AH-6X (M134) armed with TwinM134 + 4000Rnd_762x51_M134 [%1].", typeOf _vehicle]] Call WFBE_CO_FNC_LogContent;
	};

	//--- cmdcon42-i: arm the freshly-created base hull with the variant's EASA-proven weapon+magazine kit.
	//--- All four TK-EASA base hulls (AH64D_EP1 / A10_US_EP1 / Mi24_D_TK_EP1 / Su25_TK_EP1) mount at HULL level
	//--- (none is in EASA_Equip's turret-special list), so plain addWeapon/addMagazine is correct - same path,
	//--- machine and timing as the AH6X_M134 kit. Idempotent remove-then-add so a re-buy / JIP re-run cannot
	//--- stack duplicate mags. Runs on the buyer's client on the local hull; WFBE_CO_FNC_CreateVehicle globalises
	//--- the hull (setVehicleInit) right after creation, so the weapon state replicates. Kit classnames are reused
	//--- verbatim from Client\Module\EASA\EASA_Init.sqf for the same base hull (all config-proven on that airframe).
	if ((count _tkEasaKit) == 2 && {!isNull _vehicle}) then {
		{ _vehicle removeMagazine _x } forEach (_tkEasaKit select 1);
		{ _vehicle removeWeapon _x }   forEach (_tkEasaKit select 0);
		{ _vehicle addWeapon _x }      forEach (_tkEasaKit select 0);
		{ _vehicle addMagazine _x }    forEach (_tkEasaKit select 1);
		["INFORMATION", Format ["Client_BuildUnit.sqf: TK-EASA variant '%1' armed on %2 (weapons %3).", (_tkeRow select 0), typeOf _vehicle, (_tkEasaKit select 0)]] Call WFBE_CO_FNC_LogContent;
	};

	_vehicles = (WF_Logic getVariable "emptyVehicles") + [_vehicle];
	WF_Logic setVariable ["emptyVehicles",_vehicles,true];

	if (isHostedServer) then {_vehicle setVariable ["WFBE_Taxi_Prohib", true]};

	//--- cmdcon42-j (Ray 2026-07-02): PRODUCIBLE SCUD (Takistan). A bought MAZ_543_SCUD_TK_EP1 becomes a side launch
	//--- platform: (a) consume its server-issued purchase proof (cap/funds rechecked; no client-controlled refund), and
	//--- (b) give the vehicle a "SCUD Fire Mission (map-click)" action for its crew/owner-side players that opens a map-click
	//--- and sends the SAME icbm-tel-fire payload the Tactical menu uses, WITH this specific hull as the platform hint (the
	//--- server re-validates everything). Fires a SATURATION conventional strike (the flagship conventional munition). Mirrors
	//--- the carrier scud-action-add + GUER-VBIED buyer-local-add / GetIn-re-add persistence idioms. TK + flag gated.
	if ((missionNamespace getVariable ["WFBE_C_TK_SCUD_HF", 1]) > 0 && {worldName == "Takistan" || {(missionNamespace getVariable ["WFBE_C_SCUD_DRIVABLE_ALLMAPS", 1]) > 0}} && {(typeOf _vehicle) == (missionNamespace getVariable ["WFBE_C_TK_SCUD_HF_TYPE", "MAZ_543_SCUD_TK_EP1"])}) then {
		//--- (a) Consume the server-issued purchase proof against this exact spawned hull. No client-provided
		//--- cost or shared registration request can establish provenance, delete a vehicle, or create a refund.
		[_vehicle, sideJoined, group player, player, _scudProof] Spawn WFBE_CO_FNC_RequestIcbmTelRegister;

		//--- Global flag so any machine that gets this hull local can recognise it + (re)arm the action.
		_vehicle setVariable ["wfbe_is_tk_scud", true, true];

		//--- Local helper: add the fire-mission action once per local hull instance (dedupe via wfbe_tk_scud_action). The
		//--- condition restricts the action to the owning side; the server still validates side/cooldown/range/funds on fire.
		WFBE_CL_FNC_AddTkScudAction = {
			private ["_v","_aid"];
			_v = _this;
			if (isNull _v) exitWith {};
			if (!(_v getVariable ["wfbe_is_tk_scud", false])) exitWith {};
			if ((_v getVariable ["wfbe_tk_scud_action", -1]) >= 0) exitWith {};   //--- already armed on this machine.
			_aid = _v addAction [
				"<t color='#ff9900'>SCUD Fire Mission (map-click)</t>",
				{
					private ["_v","_caller","_cost"];
					_v = _this select 0;
					_caller = _this select 1;
					_cost = missionNamespace getVariable ["WFBE_C_ICBM_TEL_SAT_COST", 12000];
					if (((group _caller) Call WFBE_CO_FNC_GetTeamFunds) < _cost) exitWith { hintSilent parseText Format ["<t color='#F8D664'>Not enough funds for a SCUD saturation strike ($%1).</t>", _cost]; };
					hintSilent parseText "<t color='#F89060'>SCUD: click the target on the map.</t>";
					openMap true;
					//--- capture the firing hull so onMapSingleClick can hint it as the platform.
					wfbe_tk_scud_fire_veh = _v;
					onMapSingleClick {
						onMapSingleClick {};
						openMap false;
						private ["_veh"];
						_veh = wfbe_tk_scud_fire_veh;
						if (isNull _veh || {!alive _veh}) exitWith { hintSilent parseText "<t color='#ff5a5a'>That SCUD is gone.</t>"; };
						//--- SAME payload the Tactical menu sends, + this hull as the platform hint. No client fund deduction
						//--- (the server WFBE_SE_FNC_IcbmTelFire re-validates platform/cooldown/range/funds and charges).
						[playerSide, [_pos select 0, _pos select 1, 0], "SATURATION", group player, 0, _veh] Spawn WFBE_CO_FNC_RequestIcbmTelFire;
						hintSilent parseText "<t color='#F89060'>SCUD saturation order sent (server validates SCUD + range + funds).</t>";
						false
					};
				},
				//--- Show only to a crew member whose side matches the hull's registered owner side (server-set wfbe_tk_scud_side;
				//--- falls back to playerSide before registration replicates). Server re-validates side on fire regardless.
				[], 6, false, true, "", "alive _target && {_this in crew _target} && {(_target getVariable ['wfbe_tk_scud_side', playerSide]) == side _this}"
			];
			_v setVariable ["wfbe_tk_scud_action", _aid];
		};

		//--- owner refinement 2026-07-08 (fable/scud-chernarus-artillery): drivable-SCUD speed governor. A2-OA has no
		//--- setMaxSpeed/limitSpeed (Arma-3-only - see WFBE_CL_FNC_GuerVbiedM113Boost below for the identical constraint on
		//--- the M113 VBIED), so cap top speed with the same periodic setVelocity idiom that boost loop uses, but scaling
		//--- the WHOLE velocity vector DOWN to the cap instead of nudging one component up - a firm governor (direction
		//--- preserved, magnitude clamped) rather than a soft nudge. Intent (owner): the SCUD is a slow, precious,
		//--- airliftable asset, not a fast mobile launcher - driving it should be tedious enough that sling-loading is the
		//--- practical way to relocate it. Idempotent via wfbe_scud_governor_running (one loop per local vehicle instance,
		//--- mirrors the boost loop's dedupe pattern). Local-driver-gated exactly like the boost loop, so it shares that
		//--- loop's known scope: reliable for the buyer's own machine across get-in/get-out; a teammate who becomes driver
		//--- on an entirely different, never-subscribed client is the same documented gap the VBIED note above already
		//--- accepts for this file's addAction/addEventHandler idiom.
		WFBE_CL_FNC_TkScudSpeedGovernor = {
			private ["_v"];
			_v = _this;
			if (isNull _v) exitWith {};
			if (_v getVariable ["wfbe_scud_governor_running", false]) exitWith {};   //--- already governing on this machine.
			_v setVariable ["wfbe_scud_governor_running", true];
			[_v] spawn {
				private ["_v","_cap","_s","_vel","_ratio"];
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
		};

		//--- Immediate buyer-local add (instant availability) + GetIn re-add for persistence (mirrors the VBIED idiom).
		_vehicle call WFBE_CL_FNC_AddTkScudAction;
		_vehicle call WFBE_CL_FNC_TkScudSpeedGovernor;
		_vehicle addEventHandler ["GetIn", {
			private ["_v","_pos","_u"];
			_v = _this select 0;
			_pos = _this select 1;
			_u = _this select 2;
			if (_u == player) then {
				_v call WFBE_CL_FNC_AddTkScudAction;
				if (_pos == "driver") then { _v call WFBE_CL_FNC_TkScudSpeedGovernor };
			};
		}];
	};

	//--- Clear the vehicle.
	(_vehicle) call WFBE_CO_FNC_ClearVehicleCargo;

	/* Section: Local Init (Client Only) */

	//--- Lock / Unlock.
	_vehicle addAction [localize "STR_WF_Unlock","Client\Action\Action_ToggleLock.sqf", [], 95, false, true, '', 'alive _target && locked _target'];
	_vehicle addAction [localize "STR_WF_Lock","Client\Action\Action_ToggleLock.sqf", [], 94, false, true, '', 'alive _target && !(locked _target)'];

	//--- Vehicle Sell (item #43): team-leader or side-commander sells an empty nearby vehicle for a partial cash refund.
	//--- addAction is LOCAL (re-adds on rebuy) -- the buyer-owns-vehicle model; same constraint as lock/unlock.
	//--- Non-Man units only (_isMan false). Condition string hides action when flag=0 or vehicle occupied/out-of-range.
	if (!_isMan) then {
		//--- item #43 hardening: tag the buying team (broadcast) so the RequestVehicleSell PVF can
		//--- validate ownership server-side; untagged hulls (AI/town/enemy) are not sellable.
		_vehicle setVariable ["wfbe_buyteam", clientTeam, true];
		_vehicle addAction ["<t color='#e8c84a'>Sell Vehicle</t>", "Client\Action\Action_VehicleSell.sqf", [], 93, false, true, '', 'alive _target && {count crew _target == 0} && {(missionNamespace getVariable ["WFBE_C_VEHICLE_SELL", 1]) > 0} && {lightInRange || heavyInRange || depotInRange || aircraftInRange || hangarInRange} && {player == leader clientTeam || (!isNull commanderTeam && {commanderTeam == clientTeam})}'];
	};

	//--- GUER PLAYER VBIED: the buyable hilux1_civil_2_covered gets a driver-detonate action (Feature B player-side).
	//--- The action is driver-only + resistance-only (condition) and asks the server to blast (mirrors AI wildcard W21)
	//--- + pays the driver's GUER team cash-for-kills.
	//--- C2 (persistence): addAction is LOCAL, so a single buyer-time add was lost the moment the buyer relogged
	//--- (EHs/actions are not JIP-persistent) or any other client became the driver. We now (a) tag the vehicle with
	//--- a global flag so any client can recognise it as a VBIED, and (b) attach a GetIn driver-path that re-adds the
	//--- action to the *local* driver instance whenever a unit takes the wheel — so the buyer keeps it across
	//--- get-out/get-in and re-driving, and a local player who inherits this truck as driver gets it on their own
	//--- machine. Idempotent via wfbe_vbied_action (one action per local vehicle instance). Gate-OFF / non-VBIED =
	//--- no flag, no EH, no action (byte-for-byte today's behaviour).
	//--- NOTE (out of my file scope): for a teammate already standing on ANOTHER client when the truck spawns, the
	//--- fully-correct delivery is an all-clients re-applier (the per-client updateclient.sqf MHQ-action pattern, or a
	//--- registered PVFunction like SetMHQLock). That re-applier lives outside the GUER bundle's owned files.
	if ((missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0 && {((typeOf _vehicle) == (missionNamespace getVariable ["WFBE_C_GUER_VBIED_TYPE", "hilux1_civil_2_covered"])) || ((typeOf _vehicle) == (missionNamespace getVariable ["WFBE_C_GUER_VBIED_M113_TYPE", "M113_UN_EP1"])) || (((missionNamespace getVariable ["WFBE_C_GUER_SUICIDE_BIKE", 0]) > 0) && {(typeOf _vehicle) == (missionNamespace getVariable ["WFBE_C_GUER_SUICIDE_BIKE_TYPE", "TT650_Ins"])})} && {(side group player) == resistance}) then {  //--- B75: hilux/datsun truck VBIED OR the kill-gated M113 APC VBIED. fable/guer-suicide-bike: OR the flag-gated suicide motorcycle.
		//--- Global flag so any machine that gets this vehicle local can recognise + (re)arm the action.
		_vehicle setVariable ["wfbe_is_guer_vbied", true, true];

		//--- B75 (guer-tech): tag the VBIED variant so the GetIn path arms the right movement assist. The soft truck
		//--- (a Car) keeps Valhalla high-climbing; the tracked M113 APC gets the dedicated ~2x-speed boost loop instead.
		if ((typeOf _vehicle) == (missionNamespace getVariable ["WFBE_C_GUER_VBIED_M113_TYPE", "M113_UN_EP1"])) then {
			_vehicle setVariable ["wfbe_vbied_m113", true, true];
		} else {
			if (((missionNamespace getVariable ["WFBE_C_GUER_SUICIDE_BIKE", 0]) > 0) && {(typeOf _vehicle) == (missionNamespace getVariable ["WFBE_C_GUER_SUICIDE_BIKE_TYPE", "TT650_Ins"])}) then {
				//--- fable/guer-suicide-bike: Motorcycle-class hull, already fast/nimble stock -- no movement-assist
				//--- boost needed (unlike the Car VBIED's Valhalla climb or the M113's speed loop).
			} else {
				//--- B67 (guer-reward): the truck VBIED is a Car, so enable Valhalla High Climbing on it (broadcast) so the
				//--- suicide truck can scale steep terrain to reach targets. Mirrors LowGear_Toggle.sqf's enable path.
				_vehicle setVariable ["WFBE_HighClimbingEnabled", true, true];
			};
		};

		//--- Local helper: add the detonate action once per local vehicle instance (dedupe via wfbe_vbied_action).
		WFBE_CL_FNC_AddGuerVbiedAction = {
			private ["_v"];
			_v = _this;
			if (isNull _v) exitWith {};
			if (!(_v getVariable ["wfbe_is_guer_vbied", false])) exitWith {};
			if ((_v getVariable ["wfbe_vbied_action", -1]) >= 0) exitWith {};   //--- already armed on this machine.
			private ["_aid"];
			_aid = _v addAction ["<t color='#ff3333'>Detonate VBIED</t>","Client\Action\Action_GuerVbiedDetonate.sqf", [], 6, false, true, "", "driver _target == _this && {side _this == resistance}"];
			_v setVariable ["wfbe_vbied_action", _aid];
		};

		//--- B75 (guer-tech): M113 VBIED ~2x-speed driver-local boost. A2-OA has NO setMaxSpeed, so mirror the Valhalla
		//--- high-climbing setVelocity idiom: each tick, while the LOCAL player drives, nudge the forward velocity up
		//--- until ~2x the M113's stock top speed (self-limiting). Idempotent via wfbe_m113_boost_running.
		WFBE_CL_FNC_GuerVbiedM113Boost = {
			private ["_v"];
			_v = _this;
			if (isNull _v) exitWith {};
			if (_v getVariable ["wfbe_m113_boost_running", false]) exitWith {};   //--- already boosting on this machine.
			_v setVariable ["wfbe_m113_boost_running", true];
			[_v] spawn {
				private ["_v","_coef","_baseMax","_target","_vel","_dir","_fwd"];
				_v = _this select 0;
				_coef = missionNamespace getVariable ["WFBE_C_GUER_VBIED_M113_SPEEDCOEF", 2.0];
				_baseMax = getNumber (configFile >> "CfgVehicles" >> (typeOf _v) >> "maxSpeed");   //--- km/h
				if (_baseMax <= 0) then {_baseMax = 60};
				_target = _baseMax * _coef;
				while {alive _v && {driver _v == player} && {canMove _v}} do {
					if (isEngineOn _v && {(speed _v) > 3} && {(speed _v) < _target}) then {
						_vel = velocity _v;
						_dir = direction _v;
						_fwd = (_vel select 0) * sin _dir + (_vel select 1) * cos _dir;   //--- forward velocity component (only boost when actually moving forward).
						if (_fwd > 0) then {
							//--- add 7% of the forward speed ALONG the heading only, so a turning/skidding tracked APC
							//--- doesn't get its lateral drift amplified (self-limited by the speed < _target guard above).
							private ["_add"];
							_add = _fwd * 0.07;
							_v setVelocity [(_vel select 0) + (_add * sin _dir), (_vel select 1) + (_add * cos _dir), (_vel select 2)];
						};
					};
					sleep 0.1;
				};
				_v setVariable ["wfbe_m113_boost_running", false];
			};
		};

		//--- Immediate buyer-local add (instant availability) + GetIn driver-path re-add for persistence.
		_vehicle call WFBE_CL_FNC_AddGuerVbiedAction;
		_vehicle addEventHandler ["GetIn", {
			private ["_v","_pos","_u"];
			_v = _this select 0;
			_pos = _this select 1;
			_u = _this select 2;
			if (_pos == "driver" && {_u == player} && {side _u == resistance}) then {
				_v call WFBE_CL_FNC_AddGuerVbiedAction;
				//--- B67 (guer-reward): start the Valhalla High Climbing loop for the local driver, exactly the way
				//--- LowGear_Toggle.sqf does (set Local_HighClimbingModeOn, spawn VALHALLA_FNC_LowGear if not running).
				if (_v getVariable ["WFBE_HighClimbingEnabled", false]) then {
					Local_HighClimbingModeOn = true;
					if (!Local_HighClimbingRunning) then {
						_v spawn VALHALLA_FNC_LowGear;
					};
				};
				//--- B75 (guer-tech): start the M113 ~2x-speed boost for the local driver (mirrors the high-climb start above).
				if (_v getVariable ["wfbe_vbied_m113", false]) then {
					_v call WFBE_CL_FNC_GuerVbiedM113Boost;
				};
			};
		}];
	};

	//--- B75 (guer-tech FOB): tag a freshly-bought GUER FOB delivery truck (broadcast) so any machine can recognise it
	//--- as a real FOB truck (vs an AI faction's Ural_INS that shares the classname). The flag gates the "Build FOB"
	//--- action (Init_Unit.sqf) and the spawn-on-truck list (Client_GetRespawnAvailable.sqf).
	if ((missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0 && {(typeOf _vehicle) in (missionNamespace getVariable ["WFBE_C_GUER_FOB_TRUCKS", []])}) then {
		_vehicle setVariable ["wfbe_is_guer_fob", true, true];
	};

	//--- B76 (guer-depot climb): GUER buys EVERY vehicle from the Depot (GUI_Menu_BuyUnits forces _type='Depot'),
	//--- and their technicals need to scale the steep Takistan/Chernarus terrain to be useful. Only the VBIED truck
	//--- (line ~357) had Valhalla High Climbing forced on; every other Depot car spawned with it OFF (default
	//--- WFBE_HighClimbingDefaultEnabled = false), so the buyer had to toggle it by hand each time. Enable it by
	//--- default on GUER Depot cars (broadcast), mirroring the VBIED path. Skip vehicles already handled as a VBIED
	//--- (their own GetIn path already arms the climb loop). The buyer keeps the Init_Unit "High-climbing gear off"
	//--- toggle to turn it back off. GetIn driver-path starts the loop for whoever takes the wheel, exactly the way
	//--- LowGear_Toggle.sqf does. Idempotent: setVariable + a dedupe-guarded GetIn EH (wfbe_depot_climb_eh).
	if ((missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0 && {_factory == "Depot"} && {_vehicle isKindOf "Car"} && {!(_vehicle getVariable ["wfbe_is_guer_vbied", false])}) then {
		_vehicle setVariable ["WFBE_HighClimbingEnabled", true, true];

		if ((_vehicle getVariable ["wfbe_depot_climb_eh", -1]) < 0) then {
			private ["_eh"];
			_eh = _vehicle addEventHandler ["GetIn", {
				private ["_v","_pos","_u"];
				_v = _this select 0;
				_pos = _this select 1;
				_u = _this select 2;
				if (_pos == "driver" && {_u == player} && {_v getVariable ["WFBE_HighClimbingEnabled", false]}) then {
					Local_HighClimbingModeOn = true;
					if (!Local_HighClimbingRunning) then {
						_v spawn VALHALLA_FNC_LowGear;
					};
				};
			}];
			_vehicle setVariable ["wfbe_depot_climb_eh", _eh];
		};
	};

	//--- Salvage Truck.
	if (_unit in (missionNamespace getVariable Format['WFBE_%1SALVAGETRUCK',sideJoinedText])) then {[_vehicle] execVM 'Client\FSM\updatesalvage.sqf'};

	//--- Units Balancing.
	if ((missionNamespace getVariable "WFBE_C_UNITS_BALANCING") > 0) then {_vehicle setVariable ["wfbe_balance_side", sideJoined]; (_vehicle) Call BalanceInit};

	if (_unit isKindOf "Air") then {
		//--- Countermeasures.
			if (getNumber(configFile >> "CfgVehicles" >> typeOf _vehicle >> "incommingmissliedetectionsystem") > 8) then {_vehicle addeventhandler ['IncomingMissile',{_this spawn HandleAlarm;}]};
		if !(WF_A2_Vanilla) then {
			switch (missionNamespace getVariable "WFBE_C_MODULE_WFBE_FLARES") do { //--- Remove CM if needed.
				case 0: {(_vehicle) Call WFBE_CO_FNC_RemoveCountermeasures}; //--- Disabled.
				case 1: { //--- Enabled with upgrades.
					if (((sideJoined Call WFBE_CO_FNC_GetSideUpgrades) select WFBE_UP_FLARESCM) == 0) then {
						(_vehicle) Call WFBE_CO_FNC_RemoveCountermeasures;
					};
				};
			};
		};

		//--- No AA missiles.
		switch (missionNamespace getVariable "WFBE_C_GAMEPLAY_AIR_AA_MISSILES") do {
			case 0: {(_vehicle) Call WFBE_CO_FNC_RemoveAAMissiles};
			case 1: {
				if (((sideJoined Call WFBE_CO_FNC_GetSideUpgrades) select WFBE_UP_AIRAAM) == 0) then {
					(_vehicle) Call WFBE_CO_FNC_RemoveAAMissiles;
				};
			};
		};
	};

	//--- B75 (guer-tech): KILL-SCALED Ka-137 FLARES. The Ka137_MG_PMC ships with no countermeasures, and the GUER
	//--- air CM-strip above (RemoveCountermeasures, fired because GUER has no flares upgrade) would also strip anything
	//--- we add - so we arm flares HERE, AFTER that strip. Give the player's Ka-137 a CMFlareLauncher + a flare mag
	//--- sized by the kill tier (60 -> 120 -> 240). The Ka-137 fires from its MainTurret, so turret-path [-1] is
	//--- MANDATORY (hull addMagazine/addWeapon silently no-op on it - same special-case the EASA path keys on).
	if ((missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0 && {sideJoined == resistance} && {(typeOf _vehicle) == (missionNamespace getVariable ["WFBE_C_GUER_KA137_TYPE", "Ka137_MG_PMC"])}) then {
		private ["_ka137Tier","_ka137Mags","_ka137Mag","_ka137Launcher"];
		_ka137Tier = missionNamespace getVariable ["WFBE_GUER_VEHICLE_TIER", 0];
		_ka137Mags = missionNamespace getVariable ["WFBE_C_GUER_KA137_FLARE_MAGS", ["60Rnd_CMFlareMagazine","120Rnd_CMFlareMagazine","240Rnd_CMFlareMagazine"]];
		if (_ka137Tier < 0) then {_ka137Tier = 0};
		if (_ka137Tier > ((count _ka137Mags) - 1)) then {_ka137Tier = (count _ka137Mags) - 1};
		_ka137Mag = _ka137Mags select _ka137Tier;
		_ka137Launcher = missionNamespace getVariable ["WFBE_C_GUER_KA137_FLARE_LAUNCHER", "CMFlareLauncher"];
		//--- Clear any flare mag/launcher already on the turret (idempotent), then arm launcher + the sized mag. Uses
		//--- the same remove/add turret-path [-1] commands EASA_RemoveLoadout.sqf / Server_GuerAirDef.sqf use (A2-OA safe).
		{_vehicle removeMagazineTurret [_x, [-1]]} forEach ["60Rnd_CMFlareMagazine","120Rnd_CMFlareMagazine","240Rnd_CMFlareMagazine"];
		_vehicle removeWeaponTurret [_ka137Launcher, [-1]];
		_vehicle addWeaponTurret [_ka137Launcher, [-1]];
		_vehicle addMagazineTurret [_ka137Mag, [-1]];
		["INFORMATION", Format ["Client_BuildUnit.sqf: GUER Ka-137 armed with flares [%1] at tier [%2].", _ka137Mag, _ka137Tier]] Call WFBE_CO_FNC_LogContent;
	};

	//--- Are we dealing with an artillery unit.

	_isArtillery = [_unit,sideJoinedText] Call IsArtillery;
	if (_isArtillery != -1) then {[_vehicle,_isArtillery,sideJoinedText] Call EquipArtillery;};

	/* Section: Creation */

	[sideJoinedText,'VehiclesCreated',1] Call UpdateStatistics;
	_built = 0;
	_group addVehicle _vehicle;

_vehicle allowCrewInImmobile true;
_vehicle addEventHandler ["Fired",{_this Spawn HandleRocketTraccer}];

if ((typeOf _vehicle ) in ['MLRS','GRAD','GRAD_CDF','MLRS_DES_EP1','M1129_MC_EP1','GRAD_TK_EP1','GRAD_CDF','GRAD_RU','GRAD_INS']) then {
	_vehicle setVariable ["restricted",false];_vehicle addEventHandler ["GetIn",{_this Spawn HandleArty}]
};

// Could seperate the array here for modded vehicles
if(typeOf _vehicle in ['F35B','AV8B','AV8B2','A10','A10_US_EP1','Su25_TK_EP1','Su34','Su39','An2_TK_EP1','L159_ACR','L39_TK_EP1','Su25_Ins','ibrPRACS_MiG21mol']) then {
	_vehicle addeventhandler ['Fired',{_this spawn HandleAAMissiles}];
};

//--- Jets survive the first SPAAG (Tunguska/Linebacker) hit — fuel drained + slight damage to attempt a landing; a second hit explodes. Set WFBE_C_JET_AA_SURVIVE 0 to disable.
if (_vehicle isKindOf "Plane" && (missionNamespace getVariable ["WFBE_C_JET_AA_SURVIVE", 1]) > 0) then {
	_vehicle addEventHandler ["HandleDamage", {_this Call HandleJetAADamage}];
};

if(typeOf _vehicle in ['2S6M_Tunguska','M6_EP1']) then {
	_vehicle addeventhandler ['Fired',{_this spawn HandleAAMissiles;}];
};

//--- B93 SEAD: tier-5 jets get anti-radar guidance EH when WFBE_C_SEAD > 0
if ((missionNamespace getVariable ["WFBE_C_SEAD", 0]) > 0 && {typeOf _vehicle in ["F35B","Su34"]}) then {
	_vehicle addeventhandler ["Fired",{_this spawn WFBE_CO_FNC_HandleSEADMissile}];
};

if(typeOf _vehicle in ['T90','BMP3']) then {
	_vehicle addeventhandler ['Fired',{_this spawn HandleATReload;}];
};

if(typeOf _vehicle in ['Pandur2_ACR']) then {
	_vehicle addeventhandler ['Fired',{_this spawn HandleCommanderReload;}];
};

if ({(typeOf _vehicle) isKindOf _x} count ["LAV25_Base","M2A2_Base","BMP2_Base","BTR90_Base" ] != 0) then {_vehicle addeventhandler ["fired",{_this spawn HandleReload;}];};

//--- V2: removed duplicate "fired"->HandleReload event handler (was identical to the IFV line above; double-registering spawned HandleReload twice per shot).

if({(_vehicle isKindOf _x)} count ["Tank","Wheeled_APC"] !=0) then {_vehicle addeventhandler ['Engine',{_this execVM "Client\Module\Engines\Engine.sqf"}];
     _vehicle addAction ["<t color='"+"#00E4FF"+"'>STEALTH ON</t>","Client\Module\Engines\Stopengine.sqf", [], 7,false, true,"","alive _target &&(isEngineOn _target)"];};

// IRS MODULE
if ((typeOf _vehicle) isKindOf "Tank" || (typeOf _vehicle) isKindOf "Car") then {

	_vehicle addeventhandler ['incomingMissile',{_this spawn HandleATMissiles}];


	if ((missionNamespace getVariable "WFBE_C_MODULE_WFBE_IRSMOKE") > 0) then { //--- IR Smoke
		if (((sideJoined) Call WFBE_CO_FNC_GetSideUpgrades) select WFBE_UP_IRSMOKE > 0) then { //--- Make sure that the unit is defined in IRS_Init and that the upgrade is available.
			_get = missionNamespace getVariable Format ["%1_IRS", (typeOf _vehicle)];
			if !(isNil '_get') then {

				_getSelectOne = _get select 1;

				// Check if the vehicle has the 2nd upgrade for the IR Smoke. Double the amount of smoke if true.
				if (((sideJoined) Call WFBE_CO_FNC_GetSideUpgrades) select WFBE_UP_IRSMOKE > 1) then { _getSelectOne = _getSelectOne * 2;};

				_vehicle setVariable ["wfbe_irs_flares", _getSelectOne, true];
				_vehicle addEventHandler ["incomingMissile", {_this spawn WFBE_CO_MOD_IRS_OnIncomingMissile}];

				//--- Trello #38: per-vehicle toggle for automatic IR smoke. addAction is LOCAL (re-adds on rebuy) - acceptable for a personal toggle.
				_vehicle addAction [localize "STR_WF_Action_IRS_Disable","Client\Action\Action_ToggleIRSmoke.sqf", [true], 6, false, true, "", "alive _target && !(_target getVariable ['wfbe_irs_disabled', false])"];
				_vehicle addAction [localize "STR_WF_Action_IRS_Enable","Client\Action\Action_ToggleIRSmoke.sqf", [false], 6, false, true, "", "alive _target && (_target getVariable ['wfbe_irs_disabled', false])"];
			};
		};
	};
};

	//--- Empty Vehicle: a crewless purchase is COMPLETE at this point - this exitWith only skips the
	//--- crew-management remainder of this else-block (ENGINE-VERIFIED, see the _buyFailed contract above);
	//--- execution falls through to the shared tail, which releases the queue slot exactly once and shows
	//--- the Build-Complete hint. NOT a failed buy, so _buyFailed stays false.
	//--- cmdcon44-g REVERTS fix #3 (ab828d06b): its inline release here assumed this exitWith aborted the
	//--- script before the tail - in reality the tail always ran too, so every crewless buy (the most common
	//--- player vehicle purchase) freed the slot TWICE and unitQueu / WFBE_C_QUEUE_<factory> drifted negative,
	//--- quietly widening the factory queue cap. The June-2 "leak" fix #3 patched was actually the Title-case
	//--- WFBE_LONGEST*BUILDTIME lookup bug (stuck queue head), properly fixed by the toUpper above (cmdcon44-f).
	if (!_driver && !_gunner && !_commander && !_extracrew) exitWith {};

	//--- Crew Management.
	_crew = missionNamespace getVariable Format ["WFBE_%1SOLDIER",sideJoinedText];
	
	// Marty : All crew members in tanks and wheeled APCs (LAV-25, BTR-90, Pandur / HF vehicles) are replaced by engineers of their side.
	// Russian side do not have engineer class so we use takistan class engineer for russian.
	//if (_unit isKindOf "Tank") then {_crew = missionNamespace getVariable Format ["WFBE_%1CREW",sideJoinedText]};
	if (_unit isKindOf "Tank" || _unit isKindOf "Wheeled_APC") then {
		if (sideJoinedText == "WEST")then 
		{
			// WEST side (american)
			_crew = "US_Soldier_Engineer_EP1" ;
			//player sideChat Format ["US_Soldier_Engineer_EP1 for %1",sideJoinedText];
		}
		else 
		{
			// EAST side (russian)
			_crew = "TK_Soldier_Engineer_EP1" ;
			//player sideChat Format ["TK_Soldier_Engineer_EP1 for %1",sideJoinedText];
		};
	};

	if (_unit isKindOf "Air") then {
		_crew = missionNamespace getVariable Format ["WFBE_%1PILOT",sideJoinedText];
	};

	_rearmor = {
   				_ammo = _this select 4;
   				_result = 0;

   				switch (_ammo) do {
                    case "B_20mm_AA" :{_dam=_this select 2; _p=12; _result=(_dam/100)*(100-_p);};
					case "B_23mm_AA" :{_dam=_this select 2; _p=12; _result=(_dam/100)*(100-_p);};
					case "B_25mm_HE" :{_dam=_this select 2; _p=12; _result=(_dam/100)*(100-_p);};
					case "B_25mm_HEI" :{_dam=_this select 2; _p=12; _result=(_dam/100)*(100-_p);};
					case "B_30mm_AA" :{_dam=_this select 2; _p=12; _result=(_dam/100)*(100-_p);};
					case "B_30mm_HE" :{_dam=_this select 2; _p=12; _result=(_dam/100)*(100-_p);};
					case "Sh_40_HE" :{_dam=_this select 2; _p=12; _result=(_dam/100)*(100-_p);};   
     				default {_result = _this select 2;};
    			};
   				_result
  			};

	_crewCreated = 0;

	//--- Driver.
	if (_driver) then {
		_soldier = [_crew,_group,_position,WFBE_Client_SideID] Call WFBE_CO_FNC_CreateUnit;
		if (isNull _soldier) then {
			if (_crewCostPerHead > 0) then {_crewCostPerHead Call ChangePlayerFunds};
			diag_log Format ["BUYFAIL|v1|crew|side=%1|factory=%2|class=%3|seat=driver|refund=%4|spawnPos=%5", sideJoinedText, _factory, _unit, _crewCostPerHead, _position];
		} else {
			[_soldier] allowGetIn true;
			_soldier addeventhandler ["HandleDamage",format ["_this Call %1", _rearmor]];
			_soldier moveInDriver _vehicle;
			if (vehicle _soldier != _vehicle) then {_soldier assignAsDriver _vehicle; [_soldier] orderGetIn true}; //--- cmdcon44s: moveIn can silently fail on a same-frame-created unit under client lag; walk-in fallback so the crew actually mans it
			_spawnedUnits = _spawnedUnits + [_soldier];
			_crewCreated = _crewCreated + 1;
		};
	};

	//--- Gunner.
	if (_gunner) then {
		_soldier = [_crew,_group,_position,WFBE_Client_SideID] Call WFBE_CO_FNC_CreateUnit;
		if (isNull _soldier) then {
			if (_crewCostPerHead > 0) then {_crewCostPerHead Call ChangePlayerFunds};
			diag_log Format ["BUYFAIL|v1|crew|side=%1|factory=%2|class=%3|seat=gunner|refund=%4|spawnPos=%5", sideJoinedText, _factory, _unit, _crewCostPerHead, _position];
		} else {
			_soldier addeventhandler ["HandleDamage",format ["_this Call %1", _rearmor]];
			[_soldier] allowGetIn true;
			_soldier moveInGunner _vehicle;
			if (vehicle _soldier != _vehicle) then {_soldier assignAsGunner _vehicle; [_soldier] orderGetIn true}; //--- cmdcon44s seat-verify walk-in fallback
			_spawnedUnits = _spawnedUnits + [_soldier];
			_crewCreated = _crewCreated + 1;
		};
	};

	//--- Commander.
	if (_commander) then {
		_soldier = [_crew,_group,_position,WFBE_Client_SideID] Call WFBE_CO_FNC_CreateUnit;
		if (isNull _soldier) then {
			if (_crewCostPerHead > 0) then {_crewCostPerHead Call ChangePlayerFunds};
			diag_log Format ["BUYFAIL|v1|crew|side=%1|factory=%2|class=%3|seat=commander|refund=%4|spawnPos=%5", sideJoinedText, _factory, _unit, _crewCostPerHead, _position];
		} else {
			_soldier addeventhandler ["HandleDamage",format ["_this Call %1", _rearmor]];
			[_soldier] allowGetIn true;
			_soldier moveInCommander _vehicle;
			if (vehicle _soldier != _vehicle) then {_soldier assignAsCommander _vehicle; [_soldier] orderGetIn true}; //--- cmdcon44s seat-verify walk-in fallback
			_spawnedUnits = _spawnedUnits + [_soldier];
			_crewCreated = _crewCreated + 1;
		};
	};

	//--- Extra vehicle turrets.
	if (_extracrew) then {
		Private ["_turrets"];
		_turrets = _currentUnit select QUERYUNITTURRETS;

		{
			if (isNull (_vehicle turretUnit _x)) then {
				_soldier = [_crew,_group,_position,WFBE_Client_SideID] Call WFBE_CO_FNC_CreateUnit;
				if (isNull _soldier) then {
					if (_crewCostPerHead > 0) then {_crewCostPerHead Call ChangePlayerFunds};
					diag_log Format ["BUYFAIL|v1|crew|side=%1|factory=%2|class=%3|seat=turret|refund=%4|spawnPos=%5", sideJoinedText, _factory, _unit, _crewCostPerHead, _position];
				} else {
					_soldier addeventhandler ["HandleDamage",format ["_this Call %1", _rearmor]];
					[_soldier] allowGetIn true;
					_soldier moveInTurret [_vehicle, _x];
					if (vehicle _soldier != _vehicle) then {_soldier moveInTurret [_vehicle, _x]}; //--- cmdcon44t: retry moveInTurret (no A2-OA walk-in command exists for a turret seat)
					_spawnedUnits = _spawnedUnits + [_soldier];
					_crewCreated = _crewCreated + 1;
				};
			};
		} forEach _turrets;
	};



	[sideJoinedText,'UnitsCreated',_crewCreated] Call UpdateStatistics;
};

//--- SHARED TAIL (cmdcon44-g) - the ONLY queue-slot release for every path that did not abort at top
//--- scope. ENGINE-VERIFIED (A2OA 1.64): the block-level exits above (infantry/vehicle BUYFAIL,
//--- empty-vehicle) fall through to here, so each buy releases its slot exactly once. Do NOT add
//--- releases to block-level exits and do NOT gate these two counter lines on _buyFailed.
if (!_buyFailed && {_factory in ["Barracks","Light","Heavy","Aircraft","Depot","Airport"]}) then {
	[_group, _spawnedUnits] call WFBE_CL_FNC_SendSpawnedUnitsToLeaderWaypoint;
};

unitQueu = (unitQueu - _cpt) max 0;  //--- salvage-522: clamp so an in-flight coroutine firing after a respawn-reset (WFBE_C_FIX_RESPAWN_UNITQUEU_RESET) cannot drive the group-cap counter negative.

missionNamespace setVariable [Format["WFBE_C_QUEUE_%1",_factory],((missionNamespace getVariable Format["WFBE_C_QUEUE_%1",_factory])-1) max 0];  //--- salvage-522: clamp per-factory queue slot to >=0 (mirror of the unitQueu clamp).
if (_buyFailed) then {
	//--- failed buy: the player already got the refund (guard above); tell them instead of "complete".
	hint parseText(Format ["<t color='#ff9060'>%1 could not be built - price refunded.</t>", _description]);
} else {
	hint parseText(Format [localize "STR_WF_INFO_Build_Complete",_description]);
};
