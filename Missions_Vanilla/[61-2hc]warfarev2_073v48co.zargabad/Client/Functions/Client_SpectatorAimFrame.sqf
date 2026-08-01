/* Client_SpectatorAimFrame.sqf  (spectator v5 P1 - council C8 verdict 2026-08-01, 4/4 APPROVE)
   UNSCHEDULED aim easing, run via onEachFrame every render frame while the spectator is active.
   Position is engine-driven (camera attachTo subject vehicle - see Client_SpectatorEnter.sqf
   follow case); this file owns ONLY the eased camSetTarget for the attached follow mode.
   HARD RULES (unscheduled): no sleep / waitUntil / spawn-heavy work; no Display handles
   (A2 serialization trap); null-guard every dereference; exit cheap when inactive.
   LIVENESS CONTRACT: stamps WFBE_C_VAR_SpectatorAimFrameTick every frame. The scheduled
   movement loop treats a stale stamp (>1s old) as frame-aim-dead and falls back to the v4
   scheduled aim path - so an unavailable/lost onEachFrame degrades gracefully (council
   failure-mode 1) instead of leaving a frozen aim.
   Registered ONLY here (repo-wide grep: no other onEachFrame user). A second registrant
   would silently replace this handler - if you ever add one, stack them (council FM 5). */
Private ["_now","_dt","_goal","_cur","_gain"];
if (!(missionNamespace getVariable ["WFBE_C_VAR_SpectatorActive", false])) exitWith {};
_now = diag_tickTime;
WFBE_C_VAR_SpectatorAimFrameTick = _now;
if (isNull (missionNamespace getVariable ["WFBE_C_VAR_SpectatorCam", objNull])) exitWith {};
if ((missionNamespace getVariable ["WFBE_C_VAR_SpectatorMode", "free"]) != "follow") exitWith {};
if (isNull (missionNamespace getVariable ["WFBE_C_VAR_SpectatorAttachedTo", objNull])) exitWith {};
_goal = missionNamespace getVariable ["WFBE_C_VAR_SpectatorAimGoal", []];
if ((count _goal) < 3) exitWith {};
//--- engine-seat sign-off condition: explicit per-frame dt capture, clamped so an alt-tab or
//--- load hitch cannot slew the aim in one giant step (frame-rate-independent easing).
_dt = _now - (missionNamespace getVariable ["WFBE_C_VAR_SpectatorAimLastT", _now]);
WFBE_C_VAR_SpectatorAimLastT = _now;
_dt = (_dt max 0) min 0.2;
_cur = missionNamespace getVariable ["WFBE_C_VAR_SpectatorAimCur", []];
if ((count _cur) < 3) then {_cur = _goal};
//--- time-constant ~1/rate s (default 3.5 -> ~0.29s), inside the council 0.25-0.4s aim band.
_gain = (((missionNamespace getVariable ["WFBE_C_SPECTATOR_AIM_RATE", 3.5]) * _dt) min 1) max 0;
_cur = [
	(_cur select 0) + (((_goal select 0) - (_cur select 0)) * _gain),
	(_cur select 1) + (((_goal select 1) - (_cur select 1)) * _gain),
	(_cur select 2) + (((_goal select 2) - (_cur select 2)) * _gain)
];
WFBE_C_VAR_SpectatorAimCur = _cur;
WFBE_C_VAR_SpectatorCam camSetTarget _cur;
WFBE_C_VAR_SpectatorCam camCommit 0;
