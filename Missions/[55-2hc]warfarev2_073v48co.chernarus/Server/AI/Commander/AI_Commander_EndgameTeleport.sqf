/*
	AI_Commander_EndgameTeleport.sqf - END-GAME TELEPORT closer (owner ask 2026-07-25).
	"Maybe end game (after 6 Hrs or so...) Allow AI commander to teleport units from base to
	friendly frontline towns" - an end-game accelerant that attacks the zombie-round problem
	from the logistics side (sibling efforts: PR #1459 air-vs-factories, PR #1463 overrun-razer
	rewire - different files, checked for collisions at implementation time).

	Called once per Strategy.sqf tick (~WFBE_C_AI_COMMANDER_STRATEGY_INTERVAL, default 60s), AFTER
	the REACTIVE DEFENSE / withdrawal passes have settled team state for this pass. Reuses
	everything Strategy already computed this tick (_teams, _attacked, _ownTownObjs, _myHQ) - a
	handful of O(1)/O(team) comparisons per team, no new forEach over towns/units beyond the
	per-team walk Strategy already does elsewhere.

	DECISION ONLY. Physical relocation happens in Common_RunCommanderTeam.sqf, the per-team
	driver ALREADY running on whichever machine owns this team (HC-resident, or the server-local
	no-HC fallback - the same locality guarantee "delegate-aicom-team" established once at
	founding). This file only stamps a broadcast sibling group var
	(wfbe_aicom_endgame_tp = [destPos, stampTime]) that driver instance polls for on its existing
	per-pass read of the team's group vars - NOT part of the wfbe_aicom_order array (element 3
	there is already the unstuck-tier read, _usTier) and NOT a new PVF/HandleSpecial case (no
	Client_HandlePVF.sqf allowlist edit needed - nothing here is dispatched through HandleSpecial).

	Scope guards (owner 2026-07-25):
	  - WEST/EAST AICOM only. GUER's own Director (AI_Commander_Wildcard_GUER.sqf) never reaches
	    this file structurally - Init_Server.sqf spawns AI_Commander.sqf (and therefore
	    Strategy.sqf, and therefore this call) only for (WFBE_PRESENTSIDES - [resistance]). The
	    _side in [west, east] check below is belt-and-braces defense-in-depth on top of that,
	    matching this codebase's own style.
	  - A human-commanded side is NEVER teleported (_humanCmd, same idiom as
	    AI_Commander_AssignTowns.sqf:33-37 / AI_Commander_Paratroops.sqf:46-48 - Strategy.sqf
	    itself does not compute this today).
	  - A team with ANY human anywhere in its roster is NEVER teleported - stricter than the
	    codebase-wide leader-only !isPlayer (leader _team) idiom, checked explicitly here.

	Flag WFBE_C_AICOM_ENDGAME_TELEPORT_ENABLE, default 0 - the very first check below exits, so
	nothing else in this file ever runs and the mission is byte-identical to HEAD at flag 0,
	regardless of the other four (also default-0) tuning constants.

	Params: [ side, teams (array of GROUP), attacked (array of contested-own-town OBJECTs, may
	          be empty), ownTownObjs (array of owned-town OBJECTs), myHQ (OBJECT) ]
	Returns: nil.
*/
private ["_side","_teams","_attacked","_ownTownObjs","_myHQ","_sideID","_egMinTime","_egCooldown","_egMaxPerTick","_egMinDist","_egHomeR","_egCmdTeam","_egHumanCmd","_egLogik","_egCount","_egTeam","_egLdr","_egLast","_egDestObj","_egDest","_egBestD","_egD","_egPrim","_egBestD2","_egD2"];

_side        = _this select 0;
_teams       = _this select 1;
_attacked    = _this select 2;
_ownTownObjs = _this select 3;
_myHQ        = _this select 4;

//--- kill-switch first (O(1)) - flag-off leaves this whole file a byte-identical no-op.
if ((missionNamespace getVariable ["WFBE_C_AICOM_ENDGAME_TELEPORT_ENABLE", 0]) <= 0) exitWith {};

//--- Belt-and-braces WEST/EAST-only guard (structurally already true today - see docblock).
if !(_side in [west, east]) exitWith {};

//--- Match-age gate (raw SQF time, resets at round start - same idiom as AI_Commander_Base.sqf:546
//--- and AI_Commander_AssignTypes.sqf's JET_START/FULL_SECS ramp).
_egMinTime = missionNamespace getVariable ["WFBE_C_AICOM_ENDGAME_TELEPORT_MIN_TIME", 0];
if (time < _egMinTime) exitWith {};

//--- Human-commanded side gate (AssignTowns.sqf:33-37 / Paratroops.sqf:46-48 idiom - Strategy.sqf
//--- itself does not compute _humanCmd today, so this file computes its own, self-contained).
_egCmdTeam = (_side) Call WFBE_CO_FNC_GetCommanderTeam;
_egHumanCmd = false;
if (!isNull _egCmdTeam) then { if (isPlayer (leader _egCmdTeam)) then {_egHumanCmd = true} };
if (_egHumanCmd) exitWith {};

if (isNull _myHQ) exitWith {};
if (isNil "_teams" || {count _teams == 0}) exitWith {};

_sideID       = (_side) Call WFBE_CO_FNC_GetSideID;
_egCooldown   = missionNamespace getVariable ["WFBE_C_AICOM_ENDGAME_TELEPORT_COOLDOWN", 0];
_egMaxPerTick = missionNamespace getVariable ["WFBE_C_AICOM_ENDGAME_TELEPORT_MAX_PER_TICK", 0];
_egMinDist    = missionNamespace getVariable ["WFBE_C_AICOM_ENDGAME_TELEPORT_MIN_DIST", 0];
//--- "At base" reuses the SAME primitive AI_Commander_Produce.sqf already uses for its own
//--- refit-at-base test (Produce.sqf:274/407) - read-only reuse of an existing always-on
//--- constant, not a new one (its own default/behaviour is untouched by this file).
_egHomeR = missionNamespace getVariable ["WFBE_C_AICOM_RETREAT_HOME_RANGE", 800];
_egLogik = (_side) Call WFBE_CO_FNC_GetSideLogic;

_egCount = 0;
{
	_egTeam = _x;
	if (_egCount < _egMaxPerTick) then {
	if (!isNull _egTeam && {({alive _x} count (units _egTeam)) > 0}) then {
		//--- Fully-AI gate: leader AND every rider (stricter than the codebase's leader-only
		//--- idiom - explicit per the owner's "ANY human player" wording).
		if (!isPlayer (leader _egTeam) && {({isPlayer _x} count (units _egTeam)) == 0}) then {
			_egLdr = leader _egTeam;
			if (!isNull _egLdr && {alive _egLdr} && {behaviour _egLdr != "COMBAT"}) then {
				//--- At/near base.
				if ((_egLdr distance _myHQ) <= _egHomeR) then {
					//--- Not already tasked to something else: plain "towns" baseline mode, not
					//--- capture-locked, not already relief/strike/rally-stamped - mirrors the
					//--- relief-eligibility idiom (this same tick's REACTIVE DEFENSE pass) verbatim.
					if ((toLower ([_egTeam, "wfbe_teammode", "towns"] Call WFBE_CO_FNC_GroupGetBool)) == "towns"
						&& {isNull ([_egTeam, "wfbe_aicom_relief", objNull] Call WFBE_CO_FNC_GroupGetBool)}
						&& {!([_egTeam, "wfbe_aicom_strike", false] Call WFBE_CO_FNC_GroupGetBool)}
						&& {!([_egTeam, "wfbe_aicom_rallying", false] Call WFBE_CO_FNC_GroupGetBool)}
						&& {!([_egTeam] Call WFBE_CO_FNC_CapLock)}) then {
						//--- Per-team cooldown - server-local bookkeeping var, NOT broadcast (only
						//--- this file ever reads it; mirrors wfbe_aicom_rally_cooldown_until's own
						//--- "not broadcast on purpose" comment).
						_egLast = [_egTeam, "wfbe_aicom_endgame_tp_last", 0] Call WFBE_CO_FNC_GroupGetBool;
						if ((time - _egLast) >= _egCooldown) then {
							//--- Destination: nearest _attacked (contested-own) town to this team;
							//--- fall back to the nearest OWNED town to the current spearhead pick
							//--- (wfbe_aicom_front_prim, an enemy/neutral target town - Strategy.sqf
							//--- L447) when _attacked is empty (late static front, no live contact).
							//--- Both pools already computed this Strategy tick - zero new scans.
							_egDestObj = objNull;
							if (count _attacked > 0) then {
								_egBestD = 1e9;
								{ _egD = _egLdr distance _x; if (_egD < _egBestD) then {_egBestD = _egD; _egDestObj = _x} } forEach _attacked;
							} else {
								if (count _ownTownObjs > 0 && {!isNil "_egLogik"} && {!isNull _egLogik}) then {
									_egPrim = _egLogik getVariable "wfbe_aicom_front_prim";
									if (isNil "_egPrim" || {isNull _egPrim}) then {_egPrim = _myHQ};
									_egBestD2 = 1e9;
									{ _egD2 = _x distance _egPrim; if (_egD2 < _egBestD2) then {_egBestD2 = _egD2; _egDestObj = _x} } forEach _ownTownObjs;
								};
							};
							if (!isNull _egDestObj) then {
								_egDest = getPos _egDestObj;
								if ((_egLdr distance _egDest) >= _egMinDist) then {
									//--- Dispatch: same shape as the relief-dispatch order writer (this
									//--- file's sibling REACTIVE DEFENSE block) - SetTeamMoveMode/
									//--- SetTeamMovePos for every team, PLUS an HC order-channel
									//--- broadcast + the teleport signal, gated on wfbe_aicom_hc (both
									//--- are read only by the Common_RunCommanderTeam.sqf driver).
									[_egTeam, "towns"] Call SetTeamMoveMode;
									[_egTeam, _egDest] Call SetTeamMovePos;
									if ([_egTeam, "wfbe_aicom_hc", false] Call WFBE_CO_FNC_GroupGetBool) then {
										_egTeam setVariable ["wfbe_aicom_order", [(if (isNil {_egTeam getVariable "wfbe_aicom_order"}) then {-1} else {(_egTeam getVariable "wfbe_aicom_order") select 0}) + 1, "towns-target", _egDest], true];
										_egTeam setVariable ["wfbe_aicom_endgame_tp", [_egDest, time], true];
									};
									_egTeam setVariable ["wfbe_aicom_endgame_tp_last", time];
									_egCount = _egCount + 1;
									["INFORMATION", Format ["AI_Commander_EndgameTeleport.sqf: [%1] team [%2] ENDGAME_TELEPORT ordered %3m -> %4.", _side, _egTeam, round (_egLdr distance _egDest), _egDestObj getVariable ["name", "town"]]] Call WFBE_CO_FNC_AICOMLog;
									diag_log ("AICOMSTAT|v2|EVENT|" + str _sideID + "|" + str (round (time / 60)) + "|ENDGAME_TELEPORT_ORDER|team=" + (str _egTeam) + "|dist=" + str (round (_egLdr distance _egDest)));
								};
							};
						};
					};
				};
			};
		};
	};
	};
} forEach _teams;
