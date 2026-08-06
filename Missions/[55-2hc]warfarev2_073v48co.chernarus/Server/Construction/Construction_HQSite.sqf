Private ["_areas","_commanderTeam","_defenses","_deployed","_direction","_grp","_HQ","_HQName","_logic","_logik","_MHQ","_near","_position","_side","_sideText","_site","_type","_update"];

_type = _this select 0;
_side = _this select 1;
_position = _this select 2;
_direction = _this select 3;
_sideText = _side;
_sideID = (_side) Call GetSideID;
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;

if (typeName _position == "OBJECT") then {_position = position _position};

/* Handle the LAG. */
//--- r60 waitUntil: bare waitUntil hard-spins and never times out if wfbe_hqinuse sticks true
//--- (mid-script crash between set true and set false). Match AI_Commander_MHQReloc: sleep + deadline +
//--- defaulted getVariable; force-clear stale lock so mobilize/deploy cannot permanently jam.
private ["_hqLockDeadline"];
_hqLockDeadline = time + (missionNamespace getVariable ["WFBE_C_HQ_INUSE_WAIT", 45]);
waitUntil {
	sleep 0.5;
	time > _hqLockDeadline || {!(_logik getVariable ["wfbe_hqinuse", false])}
};
if (_logik getVariable ["wfbe_hqinuse", false]) then {
	["WARNING", Format ["Construction_HQSite.sqf: [%1] wfbe_hqinuse stuck true past wait; force-clear.", _sideText]] Call WFBE_CO_FNC_LogContent;
	_logik setVariable ["wfbe_hqinuse", false];
};
_logik setVariable ["wfbe_hqinuse", true];

_HQ = (_side) Call WFBE_CO_FNC_GetSideHQ;
_deployed = (_side) Call WFBE_CO_FNC_GetSideHQDeployStatus;

//--- r30: refuse deploy/pack when the current HQ object is missing or already destroyed.
//--- Without this, RequestStructure(index 0) against a wreck flipped dead MHQ -> live deployed HQ
//--- for free (bypassed Server_MHQRepair cost + repair count). AI recovery uses MHQRepair, not this path.
if (isNull _HQ || {!alive _HQ}) exitWith {
	_logik setVariable ["wfbe_hqinuse", false];
	["WARNING", Format ["Construction_HQSite.sqf: [%1] aborted - HQ missing or destroyed (cannot deploy/pack a wreck).", _sideText]] Call WFBE_CO_FNC_LogContent;
};

if (!_deployed) then {
	_HQ setPos [1,1,1];

	_site = createVehicle [_type, _position, [], 0, "NONE"];
	//--- r36 fail-clean: createVehicle null after parking the MHQ would publish a null HQ and delete the live MHQ.
	//--- Restore the parked MHQ, clear the lag latch, and abort before setVariable/deployed/deleteVehicle.
	if (isNull _site) exitWith {
		_HQ setPos _position;
		_HQ setDir _direction;
		_logik setVariable ["wfbe_hqinuse", false];
		["WARNING", Format ["Construction_HQSite.sqf: [%1] HQ deploy createVehicle FAILED for type [%2] at %3 - MHQ restored.", _sideText, _type, _position]] Call WFBE_CO_FNC_LogContent;
	};
	_site setDir _direction;
	_site setPos _position;
	_site setVariable ["wfbe_side", _side, true]; //--- r30 getvar-jip
	_site setVariable ["wfbe_structure_type", "Headquarters", true]; //--- r30 getvar-jip

	_logik setVariable ['wfbe_hq_deployed', true, true];
	_logik setVariable ["wfbe_hq", _site, true];

	_site setVehicleInit Format["[this,true,%1] ExecVM 'Client\Init\Init_BaseStructure.sqf'",_sideID];
	processInitCommands;

	[_side,"Deployed", ["Base", _site]] Spawn SideMessage;
	_site addEventHandler ['killed', {_this Spawn WFBE_SE_FNC_OnHQKilled}];
	_site addEventHandler ["hit",{_this Spawn BuildingDamaged}];
	_site addEventHandler ['handleDamage',{[_this select 0,_this select 2,_this select 3, _this select 4] Call BuildingHandleDamages}];
	_defenses = [_site, missionNamespace getVariable "WFBE_NEURODEF_HEADQUARTERS_WALLS"] call CreateDefenseTemplate;
	_site setVariable ["wfbe_hq_walls", _defenses];
	_site setVariable ["WFBE_Walls", _defenses];

	//--- base area limits.
	if ((missionNamespace getVariable "WFBE_C_BASE_AREA") > 0) then {
		_update = true;
		_areas = _logik getVariable "wfbe_basearea";
		_near = [_position,_areas] Call WFBE_CO_FNC_GetClosestEntity;
		if (!isNull _near) then {
			if (_near distance _position < ((missionNamespace getVariable "WFBE_C_BASE_AREA_RANGE") + (missionNamespace getVariable "WFBE_C_BASE_HQ_BUILD_RANGE"))) then {_update = false};
		};
		if (_update) then {
			_grp = createGroup sideLogic;
			_logic = _grp createUnit ["Logic",[0,0,0],[],0,"NONE"];
			_logic setVariable ["DefenseTeam", ([_side, "defense"] Call WFBE_CO_FNC_CreateGroup)];
            (_logic getVariable "DefenseTeam") setVariable ["wfbe_persistent", true];
	        _logic setVariable ["weapons",missionNamespace getVariable "WFBE_C_BASE_DEFENSE_MAX_AI"];
        [nil, "RequestBaseArea", [_logic, _position,_side,_logik,_areas]] Call WFBE_CO_FNC_SendToClients;
			//--- fix(base): on a dedicated server the SendToClients above is only a publicVariable -
			//--- the server itself never runs RequestBaseArea, and on a headless-only session (fresh
			//--- boot, HQs auto-deploy before any human joins) NO machine runs it: the area logic
			//--- stayed at [0,0,0] and wfbe_basearea stayed [], so Construction_StationaryDefense.sqf
			//--- (!isNull _area, line ~96) silently skipped manning EVERY AI base defense
			//--- (placed-but-unmanned guns, box test 2026-07-11). Restore the server-side
			//--- registration (below, previously commented out) ALONGSIDE the client broadcast:
			//--- the public wfbe_basearea write replicates to clients; the client handler stays for
			//--- client-local avail/side copies, and its identical-snapshot write is idempotent.
			_logic setPos _position;
			_logic setVariable ["avail",missionNamespace getVariable "WFBE_C_BASE_AV_STRUCTURES"];
			_logic setVariable ["side",_side];
			_logik setVariable ["wfbe_basearea", _areas + [_logic], true];
		};
	};

	["INFORMATION", Format ["Construction_HQSite.sqf: [%1] MHQ has been deployed.", _sideText]] Call WFBE_CO_FNC_LogContent;

	deleteVehicle _HQ;
} else {
	_position = getPos _HQ;
	_direction = getDir _HQ;
	_HQName = missionNamespace getVariable Format["WFBE_%1MHQNAME",_sideText];

	_defenses = _HQ getVariable ["wfbe_hq_walls", _HQ getVariable ["WFBE_Walls", []]];

	_HQ setPos [1,1,1];

	_MHQ = [_HQName, _position, _sideID, _direction, true, false] Call WFBE_CO_FNC_CreateVehicle;
	//--- r36 fail-clean: Common_CreateVehicle already logs null, but callers used to stamp wfbe_hq=objNull
	//--- and delete the deployed HQ. Restore parked HQ + lag latch; keep walls until create succeeds.
	if (isNull _MHQ) exitWith {
		_HQ setPos _position;
		_HQ setDir _direction;
		_logik setVariable ["wfbe_hqinuse", false];
		["WARNING", Format ["Construction_HQSite.sqf: [%1] MHQ mobilize create FAILED at %2 - deployed HQ restored.", _sideText, _position]] Call WFBE_CO_FNC_LogContent;
	};
	{if (!isNull _x) then {deleteVehicle _x}} forEach _defenses;
	_MHQ setVelocity [0,0,-1];
	_MHQ setVariable ["WFBE_Taxi_Prohib", true];
	_MHQ setVariable ["wfbe_side", _side, true]; //--- r30 getvar-jip
	_MHQ setVariable ["wfbe_trashable", false];
	_MHQ setVariable ["wfbe_structure_type", "Headquarters", true]; //--- r30 getvar-jip
	_MHQ addEventHandler ["hit",{_this Spawn BuildingDamaged}];
	_logik setVariable ["wfbe_hq", _MHQ, true];
	_logik setVariable ['wfbe_hq_deployed', false, true];
    if (_side == west && !(IS_chernarus_map_dependent)) then {
	//--- fix(code-as-string r33): setVehicleInit keeps ONLY the last string - three separate
	//--- calls applied only slot 2. One combined init so all three desert LAV selections run.
	_MHQ setVehicleInit "this setObjectTexture [0,""Textures\lavbody_coD.paa""]; this setObjectTexture [1,""Textures\lavbody2_coD.paa""]; this setObjectTexture [2,""Textures\lav_hq_coD.paa""]";
	processInitCommands;
	};

	//--- B66: the DEPLOY branch (~:32) fires Init_BaseStructure via setVehicleInit so every client draws the
	//--- HQ map marker; the MOBILIZE branch never did, so an undeployed/relocating MHQ had NO client marker
	//--- (own-side + JIP players saw nothing). Mirror the deploy-branch call so the mobilized MHQ also gets a
	//--- client marker (Init_BaseStructure handles the mobilized state). Matches the deploy-branch quoting.
	_MHQ setVehicleInit Format["[this,true,%1] ExecVM 'Client\Init\Init_BaseStructure.sqf'",_sideID];
	processInitCommands;

	[_side,"Mobilized", ["Base", _MHQ]] Spawn SideMessage;
	_MHQ addEventHandler ['killed', {_this Spawn WFBE_SE_FNC_OnHQKilled}]; //--- Killed EH fires localy, this is the server.

	if (isMultiplayer) then {[_side, "HandleSpecial", ["set-hq-killed-eh", _MHQ]] Call WFBE_CO_FNC_SendToClients}; //--- WAVE-3 (60-audit): _mhq -> _MHQ (case-sensitive local was nil -> mobilized HQ's killed round-ender wired to nothing). Since the Killed EH fires localy, we send the information to the existing clients, JIP clients need to have the event in init_client.sqf (if !deployed).

	_MHQ addEventHandler ['handleDamage',{[_this select 0,_this select 2,_this select 3,_this select 4] Call BuildingHandleDamages}];

	["INFORMATION", Format ["Construction_HQSite.sqf: [%1] MHQ has been mobilized.", _sideText]] Call WFBE_CO_FNC_LogContent;

	deleteVehicle _HQ;
		//--- [>1.62] Set the HQ to be local to the commander.
	 _commanderTeam = (_side) Call WFBE_CO_FNC_GetCommanderTeam;

};

/* Handle the LAG. */
_logik setVariable ["wfbe_hqinuse", false];
