disableSerialization;

_display = _this select 0;
_map = _display DisplayCtrl 23002;

MenuAction = -1;
mouseButtonDown = -1;
mouseButtonUp = -1;

_incomeSystem = missionNamespace getVariable "WFBE_C_ECONOMY_INCOME_SYSTEM";
_incomeDividision = missionNamespace getVariable "WFBE_C_ECONOMY_INCOME_DIVIDED";
_supplySystem = missionNamespace getVariable "WFBE_C_ECONOMY_SUPPLY_SYSTEM";
_lastComboUpdate = -30;
_lastPurchase = -5;
_income = 0;
_hasStarted = true;

_lastUse = 0;
ctrlEnable [23016,false];
if (_supplySystem != 0) then {ctrlShow [23016, false]};

//--- QoL: Economy Overview dashboard (read-only) + sell-marker state.
_sellMarkers = [];
_lastDash = -10;
_dash = _display DisplayCtrl 23020;
_econInterval = missionNamespace getVariable ["WFBE_C_ECONOMY_INCOME_INTERVAL", 60];
if (_econInterval <= 0) then {_econInterval = 60};
_totalTowns = count towns;

if (_incomeSystem in [3,4]) then {
	sliderSetRange[23010,0,missionNamespace getVariable "WFBE_C_ECONOMY_INCOME_PERCENT_MAX"];
	_income = WFBE_Client_Logic getVariable "wfbe_commander_percent";
	sliderSetPosition[23010, _income];
} else {
	ctrlEnable [23012, false];
};

/* //--- Disable the selling function if the HQ is dead.
if !(alive ((sideJoined) Call WFBE_CO_FNC_GetSideHQ)) then {
	ctrlEnable [23015, false];
}; */

while {alive player && dialog} do {	
	if (side group player != sideJoined) exitWith {closeDialog 0};
	if !(dialog) exitWith {};
	
	_funds = Call GetPlayerFunds;
	
	//--- Income System.
	if (_incomeSystem in [3,4]) then {
		ctrlSetText[23011, Format["%1%2",_income,"%"]];
		_currentPercent = WFBE_Client_Logic getVariable "wfbe_commander_percent";
		
		_income = floor(sliderPosition 23010);
		
		sliderSetPosition[23010, _income];
		
		_calInc = (sideJoined) Call GetTownsIncome;
		
		if (_currentPercent != _income || _hasStarted) then {
			if (_hasStarted) then {_hasStarted = false};
			
			_income_players = 0;
			_income_commander = 0;
			switch (_incomeSystem) do {
				case 3: {
					private "_tc2"; _tc2 = WFBE_Client_Teams_Count; if (isNil "_tc2" || {_tc2 < 1}) then {_tc2 = 1};   //--- same div-by-zero guard as Client_GetIncome (WFBE_Client_Teams_Count=0 for an unsynced JIP joiner; Ray client RPT 2026-06-27).
					_income_players = round(_calInc * (((100 - _income)/100)/_tc2));
					_income_commander = round((_calInc * (_income/100)) / _incomeDividision) + _income_players;
				};
				case 4: {
					_income_players = round(_calInc * (100 - _income) / 100);
					_income_commander = round((_calInc - _income_players)*WFBE_Client_Teams_Count) + _income_players;
				};
			};
			
			ctrlSetText [23013, localize 'STR_WF_ECONOMY_Income_Sys_Com' + ": $" + str(_income_commander)];
			ctrlSetText [23014, localize 'STR_WF_ECONOMY_Income_Sys_Ply' + ": $" + str(_income_players)];
		};
		
		if (MenuAction == 3) then {
			MenuAction = -1;
			
			if (_currentPercent != _income) then {
				WFBE_Client_Logic setVariable ["wfbe_commander_percent", _income, true];
			};
		};
	};
	
	//--- ST Handler.
	if (_supplySystem == 0) then {
		_isCommander = false;
		if (!isNull(commanderTeam)) then {if (commanderTeam == group player) then {_isCommander = true}};
		ctrlEnable [23016,if (time - _lastUse > 5 && _isCommander) then {true} else {false}];
	};
	
	//--- Respawn Supply Trucks.
	if (MenuAction == 4) then {
		MenuAction = -1;
		// WFBE_RequestSpecial = ['SRVFNCREQUESTSPECIAL',["RespawnST",sideJoined]];
		// publicVariable 'WFBE_RequestSpecial';
		// if (isHostedServer) then {['SRVFNCREQUESTSPECIAL',["RespawnST",sideJoined]] Spawn HandleSPVF};
		["RequestSpecial", ["RespawnST",sideJoined]] Call WFBE_CO_FNC_SendToServer;
		_lastUse = time;
	};
	
	//added-MrNiceGuy
	if (mouseButtonUp == 0) then {
		mouseButtonUp = -1;
		
		//--- Sell Building.
		if (MenuAction == 105) then {
			_isCommander = false;
			if (!isNull(commanderTeam)) then {if (commanderTeam == group player) then {_isCommander = true}};
			if !(_isCommander) exitWith {MenuAction = -1};
			_position = _map posScreenToWorld[mouseX,mouseY];
			_structures = (sideJoined) Call WFBE_CO_FNC_GetSideStructures;
			_closest = [_position,_structures] Call WFBE_CO_FNC_GetClosestEntity;
			if (!isNull _closest && _closest distance _position < 100 && isNil {_closest getVariable "WFBE_SOLD"}) then {
				_scName = getText (configFile >> "CfgVehicles" >> (typeOf _closest) >> "displayName");
				_scId = (missionNamespace getVariable Format ["WFBE_%1STRUCTURENAMES",sideJoinedText]) find (typeOf _closest);
				_scRef = if (_scId > -1) then {round(((missionNamespace getVariable Format ["WFBE_%1STRUCTURECOSTS",sideJoinedText]) select _scId) * (missionNamespace getVariable "WFBE_C_STRUCTURES_SALE_PERCENT") / 100)} else {0};
				if ([Format ["wf_sell_%1", _closest], Format ["<t color='#ff5a5a' size='1.1'>Sell %1?</t><br/>Refund $%2. Click it again to confirm.", _scName, _scRef]] call WFBE_CL_FNC_ConfirmAction) then {
					MenuAction = -1;
					mouseButtonDown = -1;
					mouseButtonUp = -1;
					uiNamespace setVariable ["wfbe_confirm_key", ""];
					uiNamespace setVariable ["wfbe_confirm_time", -1000];
					hintSilent "";
					{deleteMarkerLocal _x} forEach _sellMarkers; _sellMarkers = [];
					//--- Spawn a sell thread.
					(_closest) Spawn {
						Private ["_closest","_delay","_id","_supplyB","_type"];
						_closest = _this;
						_closest setVariable ["WFBE_SOLD", true];
						_delay = missionNamespace getVariable "WFBE_C_STRUCTURES_SALE_DELAY";
						_type = typeOf _closest;

						//--- Inform the side (before).
						// WFBE_LocalizeMessage = [sideJoined,'CLTFNCLOCALIZEMESSAGE',['StructureSell',_type,_delay]];
						// publicVariable 'WFBE_LocalizeMessage';
						[sideJoined, "LocalizeMessage", ['StructureSell',_type,_delay, _closest]] Call WFBE_CO_FNC_SendToClients;
						if (!isHostedServer) then {['StructureSell',_type,_delay, _closest] Spawn CLTFNCLocalizeMessage};
						
						sleep _delay;
						
						if !(alive _closest) exitWith {};
						
						_id = (missionNamespace getVariable Format ["WFBE_%1STRUCTURENAMES",sideJoinedText]) find _type;
						
						//--- TODO: Change the find system with a getvar system.
						if (_id > -1) then {
							private "_rtRlS";
							_rtRlS = (missionNamespace getVariable Format ["WFBE_%1STRUCTURES",sideJoinedText]) select _id;
							//--- owner 2026-07-09: Radio Tower was bought with CASH -> refund CASH (salePercent of the cash price), not supply.
							if (_rtRlS == "RadioTower") then {
								(round(((missionNamespace getVariable ["WFBE_C_STRUCTURES_RADIOTOWER_CASH_COST", 2500]) * (missionNamespace getVariable "WFBE_C_STRUCTURES_SALE_PERCENT")) / 100)) Call ChangePlayerFunds;
							} else {
								_supplyB = (missionNamespace getVariable Format ["WFBE_%1STRUCTURECOSTS",sideJoinedText]) select _id;
								_supplyB = round((_supplyB * (missionNamespace getVariable "WFBE_C_STRUCTURES_SALE_PERCENT")) / 100);
								if ((missionNamespace getVariable "WFBE_C_ECONOMY_CURRENCY_SYSTEM") == 0) then {[sideJoined, _supplyB, "Factory sold.", false] Call ChangeSideSupply} else {(_supplyB) Call ChangePlayerFunds};
							};
						};
						//--- #856 follow-up (closes the #692 queue-counter leak; owner's post-merge review
						//--- comment on PR #856). #692 added a LUMP-SUM refund of all pending queu_costs to
						//--- the SELLER, then force-cleared queu/queu_costs/queu_cpts/queu_labels before
						//--- setDammage 1. That force-clear makes every still-waiting buyer's
						//--- Client_BuildUnit.sqf coroutine resolve _qIdx == -1 on its next poll, routing it
						//--- through the E1 CANCELLED-exit (Client_BuildUnit.sqf ~:372-376), which assumes
						//--- Action_CancelQueue.sqf already decremented that buyer's unitQueu and the
						//--- machine-local WFBE_C_QUEUE_<factory> counter. It had not -- both counters leak
						//--- permanently for every buyer still queued (not yet building) when the factory
						//--- sold. unitQueu and WFBE_C_QUEUE_<factory> are UNBROADCAST, buyer-client-local
						//--- variables (Client_BuildUnit.sqf:11 plain `unitQueu = unitQueu + _cpt`; :391
						//--- `missionNamespace setVariable` with no publicVariable/broadcast flag) -- this
						//--- seller-side thread has no way to reach or decrement another player's copy, and
						//--- no existing broadcast channel carries that request (see the rejected fix (b) in
						//--- the PR body). So: do NOT lump-refund and do NOT force-clear the queue arrays
						//--- here. Just let setDammage 1 below mark the building dead and leave queu/
						//--- queu_costs/queu_cpts/queu_labels alone -- exactly like an organic combat kill
						//--- (Server_BuildingKilled.sqf does no queue handling at all). Each buyer's own
						//--- coroutine already detects !alive _building on its own machine within one 4s
						//--- poll, self-dequeues its own entry (Client_BuildUnit.sqf:335-362), finds
						//--- _qIdx >= 0 (skips E1), and hits the existing top-scope FC2 dead-building exit
						//--- (Client_BuildUnit.sqf ~:389-394), which already refunds _currentCost to that
						//--- buyer AND correctly decrements their own unitQueu / WFBE_C_QUEUE_<factory> --
						//--- locally, no cross-client access needed. This also fixes the #692 lump-refund's
						//--- second latent issue: it credited the SELLER's own team funds / side supply
						//--- instead of the buyers who actually paid.
						
						//--- Inform the side.
						// WFBE_LocalizeMessage = [sideJoined,'CLTFNCLOCALIZEMESSAGE',['StructureSold',_type]];
						// publicVariable 'WFBE_LocalizeMessage';
						[sideJoined, "LocalizeMessage",['StructureSold',_type, _closest]] Call WFBE_CO_FNC_SendToClients;
						if (!isHostedServer) then {['StructureSold',_type, _closest] Spawn CLTFNCLocalizeMessage};
						if ((missionNamespace getVariable "WFBE_C_STRUCTURES_CONSTRUCTION_MODE") == 1) then {_closest setVariable ["sold",true,true]};
						_closest setDammage 1;
					};
				};
			} else {
				MenuAction = -1;
				mouseButtonDown = -1;
				mouseButtonUp = -1;
				uiNamespace setVariable ["wfbe_confirm_key", ""];
				uiNamespace setVariable ["wfbe_confirm_time", -1000];
				hintSilent "";
			};
		};
	};
	
	//--- FIX: Back button checked BEFORE the dashboard block so a dashboard hiccup can never starve it (regression: dashboard added below ran before the old back-button check).
	if (MenuAction == 5) exitWith {
		MenuAction = -1;
		mouseButtonDown = -1;
		mouseButtonUp = -1;
		uiNamespace setVariable ["wfbe_confirm_key", ""];
		uiNamespace setVariable ["wfbe_confirm_time", -1000];
		hintSilent "";
		{deleteMarkerLocal _x} forEach _sellMarkers; _sellMarkers = [];
		closeDialog 0;
		createDialog "WF_Menu";
	};

	//--- QoL: Economy Overview dashboard + sell-mode markers/preview (read-only).
	if (MenuAction == 105) then {
		if (count _sellMarkers == 0) then {
			_sNames2 = missionNamespace getVariable Format ["WFBE_%1STRUCTURENAMES",sideJoinedText];
			_sCosts2 = missionNamespace getVariable Format ["WFBE_%1STRUCTURECOSTS",sideJoinedText];
			_salePct = missionNamespace getVariable "WFBE_C_STRUCTURES_SALE_PERCENT";
			{
				_i2 = _sNames2 find (typeOf _x);
				if (_i2 > 0 && isNil {_x getVariable "WFBE_SOLD"}) then {
					_ref2 = round(((_sCosts2 select _i2) * _salePct) / 100);
					_mk = Format ["wfbe_econ_sell_%1", _forEachIndex];
					createMarkerLocal [_mk, getPos _x];
					_mk setMarkerTypeLocal "Empty";
					_mk setMarkerColorLocal "ColorYellow";
					_mk setMarkerSizeLocal [0.7,0.7];
					_mk setMarkerTextLocal Format ["$%1", _ref2];
					_sellMarkers set [count _sellMarkers, _mk];	//--- FIX: pushBack is Arma-3-only; A2 OA 1.64 has no pushBack (was throwing "Undefined" every sell-mode tick)
				};
			} forEach ((sideJoined) Call WFBE_CO_FNC_GetSideStructures);
		};
		_pPos = _map posScreenToWorld[mouseX,mouseY];
		_pNear = [_pPos,((sideJoined) Call WFBE_CO_FNC_GetSideStructures)] Call WFBE_CO_FNC_GetClosestEntity;
		_pTxt = "<t color='#ffae3a' shadow='1'>SELL MODE - click a structure to sell.</t>";
		if (!isNull _pNear && _pNear distance _pPos < 100 && isNil {_pNear getVariable "WFBE_SOLD"}) then {
			_pId = (missionNamespace getVariable Format ["WFBE_%1STRUCTURENAMES",sideJoinedText]) find (typeOf _pNear);
			if (_pId > 0) then {
				_pRef = round(((missionNamespace getVariable Format ["WFBE_%1STRUCTURECOSTS",sideJoinedText]) select _pId) * (missionNamespace getVariable "WFBE_C_STRUCTURES_SALE_PERCENT") / 100);
				_pTxt = _pTxt + Format ["<br/><t color='#e0b94f' shadow='1'>%1</t> - refund <t color='#76f563' shadow='1'>$%2</t>", getText (configFile >> "CfgVehicles" >> (typeOf _pNear) >> "displayName"), _pRef];
			};
		};
		_dash ctrlSetStructuredText (parseText _pTxt);
		_lastDash = -10;
	} else {
		if (count _sellMarkers > 0) then {{deleteMarkerLocal _x} forEach _sellMarkers; _sellMarkers = []};
		if (time - _lastDash > 1) then {
			_lastDash = time;
			_pool = (sideJoined) Call GetTownsIncome;
			_perMin = round(_pool * 60 / _econInterval);
			_dash ctrlSetStructuredText (parseText Format ["<t color='#9fb0bc' shadow='1'>Side income pool: </t><t color='#e0b94f' shadow='1'>$%1/min</t><t color='#9fb0bc' shadow='1'>  ($%2/hr)</t><br/><t color='#9fb0bc' shadow='1'>Towns held: </t><t shadow='1'>%3 / %4</t><br/><t color='#9fb0bc' shadow='1'>Supply: </t><t shadow='1'>%5</t>", _perMin, (_perMin * 60), (sideJoined Call GetTownsHeld), _totalTowns, (missionNamespace getVariable [format ["wfbe_supply_%1", str sideJoined], "?"])]);	//--- FIX: non-blocking read (GetSideSupply does a publicVariableServer+waitUntil that can stall this loop)
		};
	};

	sleep 0.1;
	
	//--- Back Button.
	if (MenuAction == 5) exitWith { //---added-MrNiceGuy
		MenuAction = -1;
		mouseButtonDown = -1;
		mouseButtonUp = -1;
		uiNamespace setVariable ["wfbe_confirm_key", ""];
		uiNamespace setVariable ["wfbe_confirm_time", -1000];
		hintSilent "";
		closeDialog 0;
		createDialog "WF_Menu";
	};
};

//--- QoL: clean up sell markers when the dialog closes (global map overlays).
MenuAction = -1;
mouseButtonDown = -1;
mouseButtonUp = -1;
uiNamespace setVariable ["wfbe_confirm_key", ""];
uiNamespace setVariable ["wfbe_confirm_time", -1000];
hintSilent "";
{deleteMarkerLocal _x} forEach _sellMarkers;
_sellMarkers = [];
