/*
	Oeprate the defenses in a town, spawn or despawn.
	 Parameters:
		- Town.
		- Side.
		- Action ("spawn"/"remove").
*/

Private ["_action","_ai_delegation_enabled","_defense","_groups","_grpKey","_grpIdx","_grpVar","_liveHCs","_op","_positions","_side","_sideID","_spawn","_team","_town","_unit","_units","_use_server"];

_town = _this select 0;
_side = _this select 1;
_action = _this select 2;
_sideID = (_side) Call WFBE_CO_FNC_GetSideID;


switch (_action) do {
	case "spawn": {
		//_side_group = createGroup _side;

		//--- Per-town shared gunner group (GROUP BLOAT REDUCTION).
		//--- One group per town per side replaces one-group-per-gunner.  Groups are capped at 12
		//--- members; if a town somehow has more than 12 static slots a second group (index 1) is
		//--- used, and so on.  Groups are stored on the town object so different towns never share.
		//--- wfbe_persistent prevents the empty-group GC from deleting them between gunner deaths.
		_grpIdx = 0;
		_grpKey = Format ["wfbe_gungrp_%1_%2", _sideID, _grpIdx];
		_team = _town getVariable _grpKey;
		if (isNil "_team") then {_team = grpNull};
		//--- Advance to the next slot if the current group is full (12-unit cap per group).
		while {!(isNull _team) && {count units _team >= 12}} do {
			_grpIdx = _grpIdx + 1;
			_grpKey = Format ["wfbe_gungrp_%1_%2", _sideID, _grpIdx];
			_team = _town getVariable _grpKey;
			if (isNil "_team") then {_team = grpNull};
		};
		if (isNull _team) then {
			_team = [_side, "defense-gunners"] Call WFBE_CO_FNC_CreateGroup;
			if !(isNull _team) then {
				_team setVariable ["wfbe_persistent", true];
				_town setVariable [_grpKey, _team];
			};
		};
		//--- Fallback: if group creation failed (cap reached), use the global DefenseTeam.
		//--- r40 handoff: DefenseTeam may be unset (nil) when group cap blocked createGroup — never leave _team as nil for RevealArea/setBehaviour.
if (isNull _team) then {
	_team = missionNamespace getVariable Format ["WFBE_%1_DefenseTeam", _side];
	if (isNil "_team") then {_team = grpNull};
};

		//--- Man the defenses.
		{
			_defense = _x getVariable "wfbe_defense";
			_use_server = true;
			//--- r33: objNull is not nil - a failed createVehicle still stamped the logic; never man/lock null hulls.
			if (!(isNil "_defense") && {!isNull _defense} && {alive _defense}) then {
				_positions = [];
				_groups = [];
				if !(alive gunner _defense) then { //--- Make sure that the defense gunner is null or dead.
					_ai_delegation_enabled = missionNamespace getVariable "WFBE_C_AI_DELEGATION";
					if(_ai_delegation_enabled > 0)then{
						switch (_ai_delegation_enabled) do {
							case 2: { //--- Headless Client delegation.
								[_positions, getPos _x] call WFBE_CO_FNC_ArrayPush;
								[_groups, missionNamespace getVariable Format ["WFBE_%1SOLDIER", _side]] call WFBE_CO_FNC_ArrayPush;

								//--- Pass the per-town group as _team.  On the HC, Common_CreateUnitForStaticDefence
								//--- will bridge to a HC-local group keyed on this server group object.
								_liveHCs = {!isNull _x && {!isNull leader _x} && {alive leader _x}} count (missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []]);
								if (_liveHCs > 0) then {
									//--- Silent-drop fix: only skip the server-side create if the delegate actually
									//--- dispatched to a live HC (its own liveness rebuild can come up empty mid-call,
									//--- previously leaving this gun unmanned with no log until the next town cycle).
									if (([_side, _groups, _positions, _team, _defense, true] Call WFBE_CO_FNC_DelegateAIStaticDefenceHeadless) > 0) then {
										_use_server = false;
									};
								};
							};
						};
					};

					if (_use_server) then {
						//--- r62 alife-static-manning: multi-group 12-cap is intended (header), but the pre-loop
						//--- while only advances on ALREADY-full groups. Mid-forEach after CreateUnit fills slot 12,
						//--- further guns kept stuffing the same group (bloat) or failed creates left guns empty.
						//--- Re-pick a non-full per-town gunner group before each server-side CreateUnit.
						while {!(isNull _team) && {count units _team >= 12}} do {
							_grpIdx = _grpIdx + 1;
							_grpKey = Format ["wfbe_gungrp_%1_%2", _sideID, _grpIdx];
							_team = _town getVariable _grpKey;
							if (isNil "_team") then {_team = grpNull};
						};
						if (isNull _team) then {
							_team = [_side, "defense-gunners"] Call WFBE_CO_FNC_CreateGroup;
							if !(isNull _team) then {
								_team setVariable ["wfbe_persistent", true];
								_town setVariable [_grpKey, _team];
							};
						};
						if (isNull _team) then {_team = missionNamespace getVariable Format ["WFBE_%1_DefenseTeam", _side]};
						_unit = [missionNamespace getVariable Format ["WFBE_%1SOLDIER", _side], _team, getPos _x, _side] Call WFBE_CO_FNC_CreateUnit;
						if (isNull _unit) then {
							["WARNING", Format ["Server_OperateTownDefensesUnits.sqf: Town [%1] failed to create a defense gunner for [%2].", _town getVariable "name", typeOf _defense]] Call WFBE_CO_FNC_LogContent;
						} else {
							//--- Defender classification (public: the activation scan runs server-side).
							_unit setVariable ["WFBE_IsTownDefenderAI", true, true];
							_unit assignAsGunner _defense;
							[_unit] orderGetIn true;
							//--- OWNER RULING (statics lock): brief unlock so the assigned AI can be seated;
							//--- re-locked immediately below once manned so no player can board a free seat.
							_defense lock false;
							_unit moveInGunner _defense;
							//--- B5: per-gunner 175m reveal dropped — the town-wide reveal at the end of
							//--- this "spawn" case (range = town range, covers every defense position) already
							//--- reveals the same enemies to the gunner group, so this per-gunner pass was
							//--- redundant RevealArea spam. Enemies are still revealed (just once, town-wide).
							_x setVariable ["wfbe_defense_operator", _unit]; //--- Track the original gunner.
							//--- OWNER RULING (statics lock): manned - re-lock so a player cannot board any
							//--- other free seat on this static while our AI holds the gunner position.
							_defense lock true;
						};
					};
				};

			};

			// Added small delay to avoid the lag spike when spawning all units at once
			sleep 0.5;
		} forEach (_town getVariable "wfbe_town_defenses");

		//--- D10#4 (WFBE_C_STATIC_DEF_COMBAT): give the manned static-defence group an explicit combat posture
		//--- so it actually engages (legacy: no setBehaviour/setCombatMode anywhere -> gunners sat passive while
		//--- roaming garrisons are forced RED). AWARE (not COMBAT) keeps manned-static gunners ON their guns
		//--- rather than dismounting to seek cover. Flag default 0 = legacy passive. Harmless no-op on the
		//--- HC-delegated path (server _team is empty there; the HC group is postured in Common_CreateUnitForStaticDefence).
		if ((missionNamespace getVariable ["WFBE_C_STATIC_DEF_COMBAT", 0]) > 0 && {!isNull _team}) then {
			_team setBehaviour "AWARE";
			_team setCombatMode "RED";
		};

		//--- Reveal the town area to the statics.
		if (count (_town getVariable "wfbe_town_defenses") > 0) then {
			[_team, _town getVariable "range", _town] Call RevealArea;
		};

		["INFORMATION", Format ["Server_OperateTownDefensesUnits.sqf : Town [%1] defenses were manned for [%2] defenses on [%3].", _town getVariable "name", count (_town getVariable "wfbe_town_defenses"),_side]] Call WFBE_CO_FNC_LogContent;
	};
	case "remove": {
		//--- De-man the defenses.
		{
			_defense = _x getVariable "wfbe_defense";

			//--- r33: skip null hulls (same class as spawn gate).
			if (!(isNil "_defense") && {!isNull _defense}) then {
				_unit = gunner _defense;
				if !(isNull _unit) then { //--- Make sure that we do not remove a player's unit.
					//--- fix(alife) proper #1370 audit: the bare deleteVehicle below silently no-ops when
					//--- _unit is HC-local (HC-delegated town statics, Common_CreateUnitForStaticDefence.sqf
					//--- via Server_DelegateAIStaticDefenceHeadless.sqf) - same latent locality hole already
					//--- fixed for commander arty/heli wrecks in server_groupsGC.sqf (~L405-410). Route
					//--- non-local deletes to the owning machine via the same established
					//--- WFBE_CO_FNC_SendToClient -> HandleSpecial dispatch channel those reapers use (new
					//--- "cleanup-town-defense-gunner" HandleSpecial case). This is a locality-correctness fix
					//--- to already-shipped de-man behaviour, not new behaviour - unconditional, no flag. The
					//--- setPos calls below are pre-existing and out of scope for this fix.
					if (alive _unit) then {
						if (isNil {(group _unit) getVariable "wfbe_funds"}) then {
							_unit setPos (getPos _x);
							if (local _unit) then {deleteVehicle _unit} else {[_unit, "HandleSpecial", ["cleanup-town-defense-gunner", _unit, "remove-case"]] Call WFBE_CO_FNC_SendToClient};
						};
					} else {
						//--- fable/cleanup-locality-2 (PVF-class hunt, MEDIUM): the alive-branch above skips funded
						//--- (player-squad) groups before de-manning; this dead-branch had no such guard, so a dead
						//--- player-squad unit in the seat was setPos'd + dispatch-deleted - and the dispatch case is
						//--- HC-allowlist-only, so for a client-local body it was also silently DROPPED. Same guard
						//--- both branches: funded-group corpses belong to the normal death pipeline, not the de-man.
						if (isNil {(group _unit) getVariable "wfbe_funds"}) then {
							_unit setPos (getPos _x);
							if (local _unit) then {deleteVehicle _unit} else {[_unit, "HandleSpecial", ["cleanup-town-defense-gunner", _unit, "remove-case"]] Call WFBE_CO_FNC_SendToClient};
						};
					};
				};
				//--- OWNER RULING (statics lock): de-manned (or already empty) - lock so a player
				//--- cannot board/steal the gun until the next "spawn" pass re-mans it.
				_defense lock true;
			};
			if !(isNil {_x getVariable "wfbe_defense_operator"}) then { //--- Delete the original gunner if he's still around.
				//--- r62: operator delete locality parity with gunner remove-case (HC-local deleteVehicle no-ops).
				private "_opUnit"; _opUnit = _x getVariable "wfbe_defense_operator";
				if (!isNull _opUnit && {alive _opUnit}) then {
					if (local _opUnit) then {deleteVehicle _opUnit} else {[_opUnit, "HandleSpecial", ["cleanup-town-defense-gunner", _opUnit, "remove-case"]] Call WFBE_CO_FNC_SendToClient};
				};
				_x setVariable ["wfbe_defense_operator", nil];
			};
		} forEach (_town getVariable "wfbe_town_defenses");

		//--- Clear per-town gunner group references so the next spawn creates fresh groups.
		//--- The groups themselves drain to 0 units and are reaped by the empty-group GC
		//--- (wfbe_persistent is not set on despawn so GC will collect them).
		_grpIdx = 0;
		_grpKey = Format ["wfbe_gungrp_%1_%2", _sideID, _grpIdx];
		_grpVar = _town getVariable _grpKey;
		while {!(isNil "_grpVar")} do {
			if !(isNil "_grpVar") then {
				if !(isNull _grpVar) then {
					_grpVar setVariable ["wfbe_persistent", false];
				};
			};
			_town setVariable [_grpKey, nil];
			_grpIdx = _grpIdx + 1;
			_grpKey = Format ["wfbe_gungrp_%1_%2", _sideID, _grpIdx];
			_grpVar = _town getVariable _grpKey;
		};

		["INFORMATION", Format ["Server_OperateTownDefensesUnits.sqf : Town [%1] defenses units were removed for [%2] defenses.", _town getVariable "name", count (_town getVariable "wfbe_town_defenses")]] Call WFBE_CO_FNC_LogContent;
	};
};
