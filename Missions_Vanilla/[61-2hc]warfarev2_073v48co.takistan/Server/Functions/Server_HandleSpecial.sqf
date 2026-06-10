Private['_args'];

_args = _this;

switch (_args select 0) do {
	case "update-teamleader": {
		Private ["_leader","_team"];
		_team = _args select 1;
		_leader = _args select 2;

		_team setVariable ["wfbe_teamleader", _leader];
	};
	case "group-query": {
		Private ["_group","_player","_side"];
		_group = _args select 1;
		_player = _args select 2;
		_side = _args select 3;

		if (alive _player) then {
			if (alive leader _group) then {
				if (isPlayer leader _group) then {
					//--- Player, forward the request.
					if (WF_A2_Vanilla) then {
						[getPlayerUID (leader _group), "HandleSpecial", ["group-join-request", _player]] Call WFBE_CO_FNC_SendToClients;
					} else {
						[leader _group, "HandleSpecial", ["group-join-request", _player]] Call WFBE_CO_FNC_SendToClient;
					};
				} else {
					if (isNil {_group getVariable "wfbe_uid"}) then { //--- Ensure that the group is ai-controlled.
						[_player, _group, _side] Call WFBE_CO_FNC_ChangeUnitGroup;

						//--- Tell the player that his request is granted.
						if (WF_A2_Vanilla) then {
							[getPlayerUID (_player), "HandleSpecial", ["group-join-accept", _group]] Call WFBE_CO_FNC_SendToClients;
						} else {
							[_player, "HandleSpecial", ["group-join-accept", _group]] Call WFBE_CO_FNC_SendToClient;
						};
					};
				};
			};
		};
	};
	case "Paratroops": {
		_args spawn KAT_Paratroopers;
	};

	case "ParaVehi": {
		_args spawn KAT_ParaVehicles;
	};

	case "ParaAmmo": {
		_args spawn KAT_ParaAmmo;
	};

	case "RespawnST": {
		Private ["_side","_st"];
		_side = _args select 1;
		_st = (_side call WFBE_CO_FNC_GetSideLogic) getVariable "wfbe_ai_supplytrucks";
		{if (!isNull (driver _x)) then {driver _x setDammage 1};_x setDammage 1} forEach _st;
		["INFORMATION", Format ["Server_HandleSpecial.sqf: [%1] Supply Trucks were forced respawn.", str _side]] Call WFBE_CO_FNC_LogContent;
	};

	case "uav": {
		_args spawn KAT_UAV;
	};

	case "upgrade-sync": {
		Private ["_side","_upgrade_id","_upgrade_level"];
		_side = _args select 1;
		_upgrade_id = _this select 2;
		_upgrade_level = _this select 3;

		if !(isNil {missionNamespace getVariable Format["WFBE_upgrade_%1_%2_%3_sync", str _side, _upgrade_id, _upgrade_level]}) then {missionNamespace setVariable [Format["WFBE_upgrade_%1_%2_%3_sync", str _side, _upgrade_id, _upgrade_level], true]};
	};
	case "update-clientfps": {
		Private ["_fps","_uid"];
		_uid = _args select 1;
		_fps = _args select 2;

		_get = missionNamespace getVariable format["WFBE_AI_DELEGATION_%1", _uid];
		if !(isNil "_get") then {
			_get set [0, _fps];
			missionNamespace setVariable [format["WFBE_AI_DELEGATION_%1", _uid], _get];
		};
	};
	case "update-town-delegation": {
		Private ["_teams","_town","_vehicles"];
		_town = _args select 1;
		_teams = [];
		_vehicles = [];

		// Marty: New delegated town AI reports include local HC/client groups before vehicles; keep old vehicle-only format compatible.
		if (count _args > 3) then {
			_teams = _args select 2;
			_vehicles = _args select 3;
		} else {
			_vehicles = _args select 2;
		};

		// Marty: Track the real delegated groups so server-side state and cleanup requests reference the same town assets.
		{
			if !(isNull _x) then {
				if !(_x in (_town getVariable "wfbe_town_teams")) then {
					_town setVariable ['wfbe_town_teams', (_town getVariable "wfbe_town_teams") + [_x]];
				};
			};
		} forEach _teams;

		_town setVariable ['wfbe_active_vehicles', (_town getVariable 'wfbe_active_vehicles') + _vehicles];
		// Marty: Log the server acknowledgement of delegated town assets for production RPT diagnosis.
		["INFORMATION", Format ["TOWN_AI_HC_CLEANUP server_update town:%1 teams:%2 vehicles:%3 totalTeams:%4 totalVehicles:%5", _town getVariable "name", count _teams, count _vehicles, count (_town getVariable "wfbe_town_teams"), count (_town getVariable 'wfbe_active_vehicles')]] Call WFBE_CO_FNC_LogContent;
		{
			[_x] spawn WFBE_SE_FNC_HandleEmptyVehicle;
			_x setVariable ["WFBE_Taxi_Prohib", true];
		} forEach _vehicles;
	};
	case "ICBM": {
		Private ["_base","_playerTeam","_side","_target"];

		_side = _args select 1;
		_base = _args select 2;
		_target = _args select 3;
		_playerTeam = _args select 4;

		["INFORMATION", Format ["Server_HandleSpecial.sqf: [%1] Team [%2] [%3] called in an ICBM Nuke.", str _side, _playerTeam, name (leader _playerTeam)]] Call WFBE_CO_FNC_LogContent;

		if (isNull _target || !alive _target) exitWith {};

		waitUntil {!alive _target || isNull _target};

		[_base] Spawn NukeDammage;
	};

	case "process-killed-hq": {
		(_args select 1) Spawn WFBE_SE_FNC_OnHQKilled;
	};
	// Marty: Authoritative cleanup for dead player AI that can remain in the command bar on dedicated servers.
	case "commandbar-cleanup-dead-unit": {
		_args Spawn {
			Private ["_acceptedLogged","_alreadyDetachedLogged","_attempt","_requester","_requesterGroup","_successLogged","_unit","_warningLogged"];

			_requester = _this select 1;
			_unit = _this select 2;

			if (isNull _requester) exitWith {};
			if (isNull _unit) exitWith {};
			if (!alive _requester) exitWith {};
			if (alive _unit) exitWith {};
			if (isPlayer _unit) exitWith {};
			if (_unit in playableUnits) exitWith {};

			_requesterGroup = group _requester;
			if (isNull _requesterGroup) exitWith {};
			if (leader _requesterGroup != _requester) exitWith {};
			if ((group _unit) != _requesterGroup) exitWith {
				_alreadyDetachedLogged = _unit getVariable ["CommandBar_DeadUnits_ServerAlreadyDetachedLogged", false];
				if !(_alreadyDetachedLogged) then {
					_unit setVariable ["CommandBar_DeadUnits_ServerAlreadyDetachedLogged", true, false];
					["INFORMATION", Format ["COMMAND_BAR_DEAD_UNIT SERVER_ALREADY_DETACHED requester:%1 unit:%2 unitGroup:%3 requesterGroup:%4 localUnit:%5 unitOwner:%6 requesterOwner:%7", name _requester, _unit, group _unit, _requesterGroup, local _unit, owner _unit, owner _requester]] Call WFBE_CO_FNC_LogContent;
				};
				[_requester, "HandleSpecial", ["commandbar-force-dead-cleanup", _unit]] Call WFBE_CO_FNC_SendToClient;
			};

			if (_unit getVariable ["CommandBar_DeadUnits_ServerCleanupRunning", false]) exitWith {};
			_unit setVariable ["CommandBar_DeadUnits_ServerCleanupRunning", true, false];
			_acceptedLogged = _unit getVariable ["CommandBar_DeadUnits_ServerAcceptedLogged", false];
			if !(_acceptedLogged) then {
				_unit setVariable ["CommandBar_DeadUnits_ServerAcceptedLogged", true, false];
				["INFORMATION", Format ["COMMAND_BAR_DEAD_UNIT SERVER_ACCEPTED requester:%1 unit:%2 type:%3 unitGroup:%4 localUnit:%5 unitOwner:%6 requesterOwner:%7", name _requester, _unit, typeOf _unit, _requesterGroup, local _unit, owner _unit, owner _requester]] Call WFBE_CO_FNC_LogContent;
			};

			for "_attempt" from 0 to 20 do {
				if (isNull _unit) exitWith {};
				if (alive _unit) exitWith {};
				if ((group _unit) != _requesterGroup) exitWith {};

				if (local _unit) then {
					if (WF_Debug) then {
						["DEBUG", Format ["COMMAND_BAR_DEAD_UNIT SERVER_JOIN_ATTEMPT attempt:%1 requester:%2 unit:%3 localUnit:%4 unitOwner:%5", _attempt, name _requester, _unit, local _unit, owner _unit]] Call WFBE_CO_FNC_LogContent;
					};
					[_unit] joinSilent grpNull;
				} else {
					if !(WF_A2_Vanilla) then {_unit setOwner (owner _requester)};
					if ((_attempt mod 4) == 0) then {
						if (WF_Debug) then {
							["DEBUG", Format ["COMMAND_BAR_DEAD_UNIT SERVER_TRANSFER_REQUEST attempt:%1 requester:%2 unit:%3 localUnit:%4 unitOwner:%5 requesterOwner:%6", _attempt, name _requester, _unit, local _unit, owner _unit, owner _requester]] Call WFBE_CO_FNC_LogContent;
						};
						[_requester, "HandleSpecial", ["commandbar-force-dead-cleanup", _unit]] Call WFBE_CO_FNC_SendToClient;
					};
				};

				sleep 0.25;
			};

			if (!isNull _unit) then {
				if (!alive _unit && (group _unit) != _requesterGroup) then {
					_successLogged = _unit getVariable ["CommandBar_DeadUnits_ServerSuccessLogged", false];
					if !(_successLogged) then {
						_unit setVariable ["CommandBar_DeadUnits_ServerSuccessLogged", true, false];
						["INFORMATION", Format ["COMMAND_BAR_DEAD_UNIT SERVER_DETACHED requester:%1 unit:%2 finalGroup:%3 requesterGroup:%4 localUnit:%5 unitOwner:%6", name _requester, _unit, group _unit, _requesterGroup, local _unit, owner _unit]] Call WFBE_CO_FNC_LogContent;
					};
				};
				if (!alive _unit && (group _unit) == _requesterGroup) then {
					_warningLogged = _unit getVariable ["CommandBar_DeadUnits_ServerCleanupWarningLogged", false];
					if !(_warningLogged) then {
						_unit setVariable ["CommandBar_DeadUnits_ServerCleanupWarningLogged", true, false];
						["WARNING", Format ["COMMAND_BAR_DEAD_UNIT SERVER_STILL_STUCK requester:%1 unit:%2 requesterGroup:%3 localUnit:%4 unitOwner:%5 requesterOwner:%6", name _requester, _unit, _requesterGroup, local _unit, owner _unit, owner _requester]] Call WFBE_CO_FNC_LogContent;
					};
				};
			};

			if (!isNull _unit) then {_unit setVariable ["CommandBar_DeadUnits_ServerCleanupRunning", false, false]};
		};
	};
	case "sidepatrol-started": {
		Private ["_psideID","_punit","_plist"];
		_psideID = _args select 1;
		_punit = _args select 2;
		if (!isNull _punit) then {
			_plist = missionNamespace getVariable ["WFBE_ACTIVE_PATROLS", []];
			missionNamespace setVariable ["WFBE_ACTIVE_PATROLS", _plist + [[_punit, _psideID]]];
			publicVariable "WFBE_ACTIVE_PATROLS";
		};
	};
	case "sidepatrol-ended": {
		Private ["_psideID","_punit","_plogik","_plist","_pnew"];
		_psideID = _args select 1;
		_punit = _args select 2;
		_plogik = ((_psideID) Call WFBE_CO_FNC_GetSideFromID) Call WFBE_CO_FNC_GetSideLogic;
		if (!isNull _plogik) then {
			//--- Release the slot and re-arm the spawn cooldown.
			_plogik setVariable ["wfbe_side_patrols", ((_plogik getVariable ["wfbe_side_patrols", 1]) - 1) max 0];
			_plogik setVariable ["wfbe_side_patrol_last", time];
		};
		_plist = missionNamespace getVariable ["WFBE_ACTIVE_PATROLS", []];
		_pnew = [];
		{
			//--- Drop the ended patrol's entry and any null leftovers while we're here.
			if (!isNull (_x select 0) && {(_x select 0) != _punit}) then {_pnew = _pnew + [_x]};
		} forEach _plist;
		missionNamespace setVariable ["WFBE_ACTIVE_PATROLS", _pnew];
		publicVariable "WFBE_ACTIVE_PATROLS";
	};
	case "connected-hc": {
		Private ["_hc","_id","_uid","_hcOld","_hcList","_hcValid"];
		_hc = _args select 1;
		_id = owner _hc;
		_uid = getPlayerUID _hc;

		["INFORMATION", Format["Server_HandleSpecial.sqf: Headless client is now connected [%1] [%2] with Owner ID [%3].", _hc, _uid, _id]] Call WFBE_CO_FNC_LogContent;

		if (_id != 0) then {
			//--- Registry hygiene: an HC re-registers after every reconnect, and the old append-only
			//--- list kept dead groups forever - delegation could then pick a corpse and the town AI
			//--- silently vanished. Drop this UID's previous group and prune any dead entries.
			_hcList = missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []];
			_hcOld = missionNamespace getVariable Format["WFBE_HEADLESS_%1", _uid];
			if (!isNil "_hcOld") then {_hcList = _hcList - [_hcOld]};
			_hcValid = [];
			{
				if (!isNull _x && {!isNull leader _x} && {alive leader _x}) then {_hcValid = _hcValid + [_x]};
			} forEach _hcList;
			if (count _hcValid != count _hcList) then {
				["INFORMATION", Format["Server_HandleSpecial.sqf: Pruned [%1] dead headless client entries from the registry.", (count _hcList) - (count _hcValid)]] Call WFBE_CO_FNC_LogContent;
			};
			//--- Add the Headless client to our candidates.
			missionNamespace setVariable [Format["WFBE_HEADLESS_%1", _uid], group _hc];
			missionNamespace setVariable ["WFBE_HEADLESSCLIENTS_ID", _hcValid + [group _hc]];
		} else {
			["WARNING", Format["Server_HandleSpecial.sqf: Headless client [%1] Owner ID is [0], it is server controlled.",_hc]] Call WFBE_CO_FNC_LogContent;
		};
	};
	case "track-playerobject": {
		Private ["_get","_object","_uid"];
		_uid = _args select 1;
		_object = _args select 2;

		_get = missionNamespace getVariable Format ["WFBE_CLIENT_%1_OBJECTS", _uid];

		if (isNil '_get') then {
			missionNamespace setVariable [Format ["WFBE_CLIENT_%1_OBJECTS", _uid], [_object]];
		} else {
			_get = _get - [objNull] + [_object];
			missionNamespace setVariable [Format ["WFBE_CLIENT_%1_OBJECTS", _uid], _get];
		};
	};
	case "repair-camp": {
		Private ["_camp_sideID","_logic","_repairSideID","_townModel"];
		_logic = _args select 1;
		_repairSideID = _args select 2;

		if (alive (_logic getVariable 'wfbe_camp_bunker')) exitWith {};

		_townModel = (missionNamespace getVariable "WFBE_C_CAMP") createVehicle (getPos _logic);
		_townModel setDir ((getDir _logic) + (missionNamespace getVariable "WFBE_C_CAMP_RDIR"));
		_townModel setPos (getPos _logic);
		_townModel addEventHandler ["killed", {(_this select 0) Spawn WFBE_SE_FNC_OnBuildingKilled}];
		_townModel addEventHandler ["handleDamage",{getDammage (_this select 0)+((_this select 2)/(missionNamespace getVariable "WFBE_C_CAMP_HEALTH_COEF"))}];
		_logic setVariable ["wfbe_camp_bunker", _townModel, true];

		//--- Do we have to update the camp SID ?
		_camp_sideID = _logic getVariable "sideID";
		if (_camp_sideID != _repairSideID) then {
			Private ["_town"];
			_logic setVariable ["sideID", _repairSideID, true];

			//--- Notify / update map if needed.
			[nil, "CampCaptured", [_logic, _repairSideID, _camp_sideID, true]] Call WFBE_CO_FNC_SendToClients;
		};
	};
};
