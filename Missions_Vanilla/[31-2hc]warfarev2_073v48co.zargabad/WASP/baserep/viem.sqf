repairprocess = "no";
_isCommander = false;

// Marty: Keep the base repair action ID on the player object.
// The old global rep variable could point to a stale addAction ID after respawn.
if ((player getVariable ["WASP_BaseRepair_Action", -1]) >= 0) then {
	player removeAction (player getVariable ["WASP_BaseRepair_Action", -1]);
};
player setVariable ["WASP_BaseRepair_Action", -1, false];
// Marty: Leave rep cleared for compatibility with old scripts that may still check the global.
rep = Nil;

waitUntil
{  
	/////// SNIPER
	if (WFBE_SK_V_Type == "Spotter")then{
		_obj = cursortarget;
		_dis = player distance _obj;
		if (!isNull _obj && !(side group player == side _obj) && (_dis < 1000) )then{
			for "_i" from 0 to (count baseb) do {
				if (_obj isKindOf (baseb select _i select 0)) then{
					_dam = (1 - getDammage _obj)*100;
					_color = "#00ff00";
					if ( _dam > 67) then {_color = "#00ff00";} else { if ( _dam > 37) then {_color = "#ffe400"} else {_color = "#ff0000"}};  
					_text = composeText [parseText format ["<t size='1.2'>%1:</t><t size='1.2' color='%2' align='center'> %3 %4</t>",localize "RB_state",_color ,str (_dam), "%"]];
					hintSilent _text;
				};
			};
		};
    };
    
	/////// REPAIR BUILD (only commander)
	if (!isNull(commanderTeam)) then {if (commanderTeam == group player) then {_isCommander = true}};
	if (_isCommander) then {
		if (repairprocess == "no") then {
			_obj = cursorTarget;
			if (!isNull _obj && side group player == side _obj) then {
				for "_i" from 0 to (count baseb) do {
					if (_obj isKindOf (baseb select _i select 0)) then {
						_dam = (1 - getDammage _obj)*100;
						_color = "#00ff00";
						if ( _dam > 67) then {_color = "#00ff00";} else { if ( _dam > 37) then {_color = "#ffe400"} else {_color = "#ff0000"}};  

						_text = composeText [parseText format ["<t size='1'>%1</t><br /><t size='1.2'>%2:</t><t size='1.2' color='%3' align='center'> %4 %5</t>",(baseb select _i) select 1,localize "RB_state",_color ,str (_dam), "%"]];
						hintSilent _text;
						_dis = player distance _obj; 
						// Marty: Read the action ID from this player, not from a shared global.
						_repairAction = player getVariable ["WASP_BaseRepair_Action", -1];
						if (_dis < (baseb select _i select 2) && _dam < 100 && _repairAction < 0) then {
							obj = _obj; objnum = _i;
							repairprocess = "yes";
							_repairAction = player addAction [localize "STR_WASP_actions_brepair","WASP\baserep\repair.sqf"];
							player setVariable ["WASP_BaseRepair_Action", _repairAction, false];
						};
						if ((_dis > (baseb select _i select 2) || _dam == 100) && _repairAction >= 0) then {
							// Marty: Remove only the repair action that belongs to this player object.
							player removeAction _repairAction;
							player setVariable ["WASP_BaseRepair_Action", -1, false];
						};	        	
					};
				};
			};
		}else{
			_dis = player distance obj;
			// Marty: Same cleanup path while a repair is already in progress.
			_repairAction = player getVariable ["WASP_BaseRepair_Action", -1];
			if ((_dis > (baseb select objnum select 2)) && _repairAction >= 0) then {
				player removeAction _repairAction;
				player setVariable ["WASP_BaseRepair_Action", -1, false];
				repairprocess = "no";
			};
		};   
		sleep 3;
	};
};
