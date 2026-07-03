Private ["_hq","_unit","_rearmor"];

_unit = _this;

//--- Lane 193: reset the factory-queue counter that Client_BuildUnit.sqf
//--- increments at line 11 (unitQueu = unitQueu + _cpt).  Without this reset
//--- the value climbs across deaths, blocking further purchases once it exceeds
//--- the factory's queue cap.  Flag WFBE_C_FIX_RESPAWN_UNITQUEU_RESET must be 1.
if ((missionNamespace getVariable ["WFBE_C_FIX_RESPAWN_UNITQUEU_RESET", 0]) > 0) then {unitQueu = 0};

(_unit) Call WFBE_SK_FNC_Apply;
[] execFSM "Client\FSM\updateactions.fsm";

// Marty: Re-add the WF menu on the new respawned unit and store the action ID on that unit.
_unit Call WFBE_CL_FNC_AddWFMenuAction;
_unit Call WFBE_CL_FNC_AddPlayerAIActions;
[] execVM "WASP\actions\OnKilled.sqf";
player call Compile preprocessFileLineNumbers "WASP\rpg_dropping\DropRPG.sqf";
(vehicle player) addEventHandler ["Fired",{_this Spawn HandleAT}];
(vehicle player) addEventHandler ["Fired",{_this Spawn HandleRocketTraccer}];

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
			
player addeventhandler ["HandleDamage",format ["_this Call %1", _rearmor]];

if (!isNull commanderTeam) then {
	_hq = (sideJoined) Call WFBE_CO_FNC_GetSideHQ;
	if (commanderTeam == group _unit) then {HQAction = _unit addAction [localize "STR_WF_BuildMenu","Client\Action\Action_Build.sqf", [_hq], 100, false, true, "", "hqInRange && canBuildWHQ && (_target == player)"]};
};

[sideJoinedText,'UnitsCreated',1] Call UpdateStatistics;
