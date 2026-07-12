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
waitUntil {!(_logik getVariable "wfbe_hqinuse")};
_logik setVariable ["wfbe_hqinuse", true];

_HQ = (_side) Call WFBE_CO_FNC_GetSideHQ;
_deployed = (_side) Call WFBE_CO_FNC_GetSideHQDeployStatus;

if (!_deployed) then {
	_HQ setPos [1,1,1];

	_site = createVehicle [_type, _position, [], 0, "NONE"];
	_site setDir _direction;
	_site setPos _position;
	_site setVariable ["wfbe_side", _side];
	_site setVariable ["wfbe_structure_type", "Headquarters"];

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
	{if (!isNull _x) then {deleteVehicle _x}} forEach _defenses;

	_HQ setPos [1,1,1];

	_MHQ = [_HQName, _position, _sideID, _direction, true, false] Call WFBE_CO_FNC_CreateVehicle;
	_MHQ setVelocity [0,0,-1];
	_MHQ setVariable ["WFBE_Taxi_Prohib", true];
	_MHQ setVariable ["wfbe_side", _side];
	_MHQ setVariable ["wfbe_trashable", false];
	_MHQ setVariable ["wfbe_structure_type", "Headquarters"];
	_MHQ addEventHandler ["hit",{_this Spawn BuildingDamaged}];
	_logik setVariable ["wfbe_hq", _MHQ, true];
	_logik setVariable ['wfbe_hq_deployed', false, true];
    if (_side == west && !(IS_chernarus_map_dependent)) then {
	_MHQ setVehicleInit "this setObjectTexture [0,""Textures\lavbody_coD.paa""]";
	_MHQ setVehicleInit "this setObjectTexture [1,""Textures\lavbody2_coD.paa""]";
	_MHQ setVehicleInit "this setObjectTexture [2,""Textures\lav_hq_coD.paa""]";
	processinitcommands;
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

	_MHQ addEventHandler ['handleDamage',{[_this select 0,_this select 2,_this select 3] Call BuildingHandleDamages}];

	["INFORMATION", Format ["Construction_HQSite.sqf: [%1] MHQ has been mobilized.", _sideText]] Call WFBE_CO_FNC_LogContent;

	deleteVehicle _HQ;
		//--- [>1.62] Set the HQ to be local to the commander.
	 _commanderTeam = (_side) Call WFBE_CO_FNC_GetCommanderTeam;

};

/* Handle the LAG. */
_logik setVariable ["wfbe_hqinuse", false];
