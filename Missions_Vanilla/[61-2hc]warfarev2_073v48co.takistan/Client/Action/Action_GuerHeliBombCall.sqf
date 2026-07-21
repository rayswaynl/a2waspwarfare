/*
	Action_GuerHeliBombCall.sqf - GUER PLAYER "Call Barrel Bomb" WF-scroll addAction handler (kill-gated,
	heli-delivered call-in). Added to the player's own Man body by Common\Init\Init_Unit.sqf /
	Client_OnRespawnHandler.sqf when WFBE_C_GUER_PLAYERSIDE > 0 and side == resistance; the addAction's
	own condition string re-checks WFBE_C_GUER_HELIBOMB_ENABLE, the WFBE_GUER_PLAYER_KILLS kill-tier
	gate, and town-center proximity (WFBE_CL_FNC_CanUseTownCenterBarrelBomb) every frame, so it only
	shows when the caller is standing at a friendly (GUER-held or neutral) town center and has unlocked
	the tier.

	Flow on a single scroll-wheel click - deliberately the SAME shape as Action_GuerMortarStrike.sqf
	(fable/guer-barrelbomb: mirror the proven mortar-strike designation mechanism, per the owner's
	explicit routing instruction):
	  - cooldown gate (per-player time stamp, WFBE_C_GUER_HELIBOMB_COOLDOWN seconds);
	  - one-shot map designation via vanilla onMapSingleClick: open the map, the next map click is the
	    drop point (same mechanism as the mortar - this IS the "click drop" the owner asked about);
	  - the clicked position must be within WFBE_C_GUER_HELIBOMB_RANGE of the caller (else titleText and
	    keep waiting);
	  - on a valid click: clear the handler, close the map, stamp the cooldown, mark the caller's map,
	    and send the RequestSpecial. The server (Server_HandleSpecial.sqf "guer-heli-bomb") re-validates
	    the kill-tier gate AND funds, debits cost, and spawns the heli via Support_GuerHeliDrop.sqf.

	A2 OA 1.62/1.63/1.64 safe: array-form private only (no inline `private _x =`), `_arr + [x]` (no
	pushBack), no params/select-with-code/isEqualType, titleText (not the A3 hint structures). The
	onMapSingleClick code is a STRING (A2 onMapSingleClick passes [_units,_pos,_alt,_shift] -> the
	clicked pos is `_this select 1` inside that string).

	_this = [target(player), caller(player), actionId, args] - target == caller, this is a Man-body action.
*/
Private ["_cooldown","_last","_player","_range","_remain","_token"];
_player = _this select 1;

if (isNull _player || {!alive _player}) exitWith {};
if (side group _player != resistance) exitWith {};        //--- belt-and-braces vs the action condition.

_cooldown = missionNamespace getVariable ["WFBE_C_GUER_HELIBOMB_COOLDOWN", 900];
_range    = missionNamespace getVariable ["WFBE_C_GUER_HELIBOMB_RANGE", 1600];

//--- Per-player cooldown gate. Stamped on a successful designation (below), NOT on this scroll-wheel
//--- click, so an aborted designation (player closes the map without clicking) does not burn the cooldown.
_last = _player getVariable ["wfbe_helibomb_last", -9999];
if ((time - _last) < _cooldown) exitWith {
	_remain = ceil (_cooldown - (time - _last));
	titleText [format ["Barrel bomb heli reloading - %1s left. Last drop is marked on your map.", _remain], "PLAIN"];
};

//--- Re-select guard: if a designation is already pending on this player, do not stack a second onMapSingleClick.
if (_player getVariable ["wfbe_helibomb_designating", false]) exitWith {
	titleText ["Designating drop point - click the map for impact.", "PLAIN"];
};
_player setVariable ["wfbe_helibomb_designating", true];
_token = diag_tickTime;
_player setVariable ["wfbe_helibomb_design_token", _token];

//--- Stash the caller + range for the onMapSingleClick string to read (it runs in a different scope).
WFBE_HeliBombDesignator = _player;
WFBE_HeliBombDesignRange = _range;

titleText ["Click the map to mark the barrel bomb drop point.", "PLAIN"];
openMap true;

//--- fable/guer-client-startup-mapcancel: ESC / map-close cancel watcher. Without this, closing the
//--- map (ESC, or any other UI path) before a completed click left "wfbe_helibomb_designating" latched
//--- forever (the action was bricked until respawn - the :47 re-select guard above always exitWith) AND
//--- left the armed onMapSingleClick string live, so the player's next unrelated map click silently
//--- fired a paid barrel bomb strike. "_token" pins this watcher to THIS designation instance so a
//--- later, unrelated designation cannot be clobbered by a stale watcher waking up late.
[_player, _token] spawn {
	private ["_p","_myToken"];
	_p = _this select 0;
	_myToken = _this select 1;
	waitUntil {!visibleMap || {isNull _p} || {!(_p getVariable ["wfbe_helibomb_designating", false])}};
	if ((_p getVariable ["wfbe_helibomb_designating", false]) && {(_p getVariable ["wfbe_helibomb_design_token", -1]) == _myToken}) then {
		//--- Map closed without a completed/rejected click while THIS designation was still pending: treat
		//--- as a cancel - clear the latch and restore the default team-order map-click handler (same
		//--- install as Init_Client.sqf's onMapSingleClick) instead of leaving it armed or blank.
		_p setVariable ["wfbe_helibomb_designating", false];
		onMapSingleClick {[_pos, _shift, _alt, _units] call WFBE_CL_FNC_HandleMapSingleClick};
	};
};

//--- One-shot map designation. The onMapSingleClick code is a STRING (compiled by the engine); inside it
//--- the clicked world position is `_this select 1`. We validate range against the stashed caller; a
//--- too-far click is rejected with a titleText and the handler stays armed for another click (so the
//--- player can retry without re-scrolling). A valid click clears the handler, closes the map, stamps the
//--- cooldown, marks the caller's map, and sends the RequestSpecial. The marker here is LOCAL to the
//--- caller: the server creates the short GLOBAL "Incoming" marker at RELEASE time, not at call time
//--- (Support_GuerHeliDrop.sqf - so the warning doesn't spoil a multi-minute flight in advance); this
//--- local one is just the caller's own designation/cooldown breadcrumb.
onMapSingleClick "
	private ['_pos','_p','_rng','_d','_m','_cool','_start'];
	_pos = _this select 1;
	_p = WFBE_HeliBombDesignator;
	_rng = WFBE_HeliBombDesignRange;
	if (isNull _p || {!alive _p}) exitWith {
		onMapSingleClick {[_pos, _shift, _alt, _units] call WFBE_CL_FNC_HandleMapSingleClick};
		openMap false;
		_p setVariable ['wfbe_helibomb_designating', false];
	};
	_d = _p distance _pos;
	if (_d > _rng) exitWith {
		titleText [format ['Out of range (%1m of %2m). Click closer.', round _d, round _rng], 'PLAIN'];
	};
	onMapSingleClick {[_pos, _shift, _alt, _units] call WFBE_CL_FNC_HandleMapSingleClick};
	openMap false;
	_p setVariable ['wfbe_helibomb_designating', false];
	_cool = missionNamespace getVariable ['WFBE_C_GUER_HELIBOMB_COOLDOWN', 900];
	_start = time;
	_p setVariable ['wfbe_helibomb_last', _start];
	_m = Format ['wfbe_guer_helibomb_designate_%1', round (diag_tickTime * 1000)];
	createMarkerLocal [_m, _pos];
	_m setMarkerTypeLocal 'mil_destroy';
	_m setMarkerColorLocal 'ColorOrange';
	_m setMarkerSizeLocal [0.9, 0.9];
	_m setMarkerTextLocal Format ['Barrel bomb inbound - heli reloading in %1s', ceil _cool];
	[_m, _p, _start, _cool] spawn {
		private ['_marker','_player','_start','_cool','_left','_currentLast','_ready'];
		_marker = _this select 0;
		_player = _this select 1;
		_start = _this select 2;
		_cool = _this select 3;
		_ready = false;
		while {true} do {
			if (isNull _player) exitWith {};
			_currentLast = _player getVariable ['wfbe_helibomb_last', -9999];
			if !(_currentLast >= _start) exitWith {
				deleteMarkerLocal _marker;
			};
			_left = ceil (_cool - (time - _start));
			if (_left <= 0) exitWith {_ready = true};
			_marker setMarkerTextLocal Format ['Barrel bomb - heli reloading in %1s', _left];
			sleep 5;
		};
		if !(isNull _player) then {
			deleteMarkerLocal _marker;
			if (_ready && {alive _player}) then {titleText ['Barrel bomb heli ready.', 'PLAIN']};
		};
	};
	['RequestSpecial', ['guer-heli-bomb', _pos, _p]] Call WFBE_CO_FNC_SendToServer;
	titleText [Format ['Barrel bomb called in. Heli reloading - %1s.', ceil _cool], 'PLAIN'];
";
