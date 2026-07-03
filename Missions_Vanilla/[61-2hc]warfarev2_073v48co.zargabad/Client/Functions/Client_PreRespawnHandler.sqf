Private ["_hq","_unit","_rearmor","_rearmorEH","_x"];

_unit = _this;

//--- salvage-522 / Lane 193: reset the factory-queue counters on respawn. Client_BuildUnit.sqf
//--- increments unitQueu at buy time; without a reset the value climbs across deaths and eventually
//--- exceeds the factory queue cap, silently blocking further purchases. Gated behind
//--- WFBE_C_FIX_RESPAWN_UNITQUEU_RESET (default 0 = dark). Zeroes the group-cap counter AND every
//--- per-factory queue slot so an in-flight Client_BuildUnit coroutine that fires after this reset
//--- clamps to 0 (all its decrements use `max 0`, salvage-522) rather than overshooting negative.
if ((missionNamespace getVariable ["WFBE_C_FIX_RESPAWN_UNITQUEU_RESET", 0]) > 0) then {
	unitQueu = 0;
	{missionNamespace setVariable [_x, 0]} forEach [
		"WFBE_C_QUEUE_BARRACKS","WFBE_C_QUEUE_LIGHT","WFBE_C_QUEUE_HEAVY",
		"WFBE_C_QUEUE_AIRCRAFT","WFBE_C_QUEUE_AIRPORT","WFBE_C_QUEUE_DEPOT"
	];
};

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
			
if (!isNil "WFBE_PLAYERHDMEH_UNIT") then {
	if (!isNull WFBE_PLAYERHDMEH_UNIT) then {
		_rearmorEH = WFBE_PLAYERHDMEH_UNIT getVariable ["WFBE_PLAYERHDMEH", -1];
		if (_rearmorEH >= 0) then {
			WFBE_PLAYERHDMEH_UNIT removeEventHandler ["HandleDamage", _rearmorEH];
			WFBE_PLAYERHDMEH_UNIT setVariable ["WFBE_PLAYERHDMEH", -1, false];
		};
	};
};

_rearmorEH = _unit addEventHandler ["HandleDamage",format ["_this Call %1", _rearmor]];
_unit setVariable ["WFBE_PLAYERHDMEH", _rearmorEH, false];
WFBE_PLAYERHDMEH_UNIT = _unit;

if (!isNull commanderTeam) then {
	_hq = (sideJoined) Call WFBE_CO_FNC_GetSideHQ;
	if (commanderTeam == group _unit) then {HQAction = _unit addAction [localize "STR_WF_BuildMenu","Client\Action\Action_Build.sqf", [_hq], 100, false, true, "", "hqInRange && canBuildWHQ && (_target == player)"]};
};

[sideJoinedText,'UnitsCreated',1] Call UpdateStatistics;
