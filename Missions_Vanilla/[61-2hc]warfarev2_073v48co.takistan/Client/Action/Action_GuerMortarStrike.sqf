/*
	Action_GuerMortarStrike.sqf — GUER PLAYER "Call mortar strike" addAction handler (improvised indirect fire).
	Added by Client_BuildUnit.sqf to a V3S_Gue truck when WFBE_C_GUER_PLAYERSIDE > 0; the action condition already
	restricts it to the resistance driver. Mirrors the GUER VBIED feature shape EXACTLY: a driver-side scroll-wheel
	action -> a ["RequestSpecial", [...]] Call WFBE_CO_FNC_SendToServer message -> the server spawns scripted ordnance
	(Server_HandleSpecial "guer-mortar-strike"). The barrage is a cooldown-gated, range-limited call-in.

	Flow on a single scroll-wheel click:
	  - cooldown gate (per-player time stamp, WFBE_C_GUER_MORTAR_COOLDOWN seconds);
	  - one-shot map designation via vanilla onMapSingleClick: open the map, the next map click is the impact point;
	  - the clicked position must be within WFBE_C_GUER_MORTAR_RANGE of the caller (else titleText + keep waiting);
	  - on a valid click: clear the handler, close the map, stamp the cooldown, mark the impact, send the RequestSpecial.

	A2 OA 1.62/1.63/1.64 safe: array-form private only (no inline `private _x =`), `_arr + [x]` (no pushBack), no
	params/select-with-code/isEqualType, titleText (not the A3 hint structures). The onMapSingleClick code is a STRING
	(A2 onMapSingleClick passes [_units,_pos,_alt,_shift] -> the impact pos is `_this select 1` inside that string).

	_this = [target(vehicle), caller(player), actionId, args]
*/
private ["_veh","_player","_cooldown","_range","_last","_remain"];
_veh    = _this select 0;
_player = _this select 1;

if (isNull _veh || {!alive _veh}) exitWith {};
if !((driver _veh) in [_player]) exitWith {};            //--- driver only (belt-and-braces vs the action condition).

_cooldown = missionNamespace getVariable ["WFBE_C_GUER_MORTAR_COOLDOWN", 240];
_range    = missionNamespace getVariable ["WFBE_C_GUER_MORTAR_RANGE", 1200];

//--- Per-player cooldown gate. Stamped on a successful designation (below), NOT on this scroll-wheel click, so an
//--- aborted designation (player closes the map without clicking) does not burn the cooldown.
_last = _player getVariable ["wfbe_mortar_last", -9999];
if ((time - _last) < _cooldown) exitWith {
	_remain = ceil (_cooldown - (time - _last));
	titleText [format ["Mortar crew reloading - %1s left. Last impact is marked on your map.", _remain], "PLAIN"];
};

//--- Re-select guard: if a designation is already pending on this player, do not stack a second onMapSingleClick.
if (_player getVariable ["wfbe_mortar_designating", false]) exitWith {
	titleText ["Designating target - click the map for impact.", "PLAIN"];
};
_player setVariable ["wfbe_mortar_designating", true];

//--- Stash the caller + range for the onMapSingleClick string to read (it runs in a different scope).
WFBE_MortarDesignator = _player;
WFBE_MortarDesignRange = _range;

titleText ["Click the map to mark the mortar impact point.", "PLAIN"];
openMap true;

//--- One-shot map designation. The onMapSingleClick code is a STRING (compiled by the engine); inside it the clicked
//--- world position is `_this select 1`. We validate range against the stashed caller; a too-far click is rejected
//--- with a titleText and the handler stays armed for another click (so the player can retry without re-scrolling).
//--- A valid click clears the handler, closes the map, stamps the cooldown, marks the caller's map, and sends the
//--- RequestSpecial. The marker is LOCAL to the caller: the server already creates the short global Incoming marker
//--- after it accepts/debits the strike, while this one is just the caller's impact/cooldown breadcrumb.
onMapSingleClick "
	private ['_pos','_p','_rng','_d','_m','_cool','_start'];
	_pos = _this select 1;
	_p = WFBE_MortarDesignator;
	_rng = WFBE_MortarDesignRange;
	if (isNull _p || {!alive _p}) exitWith {
		onMapSingleClick '';
		openMap false;
		_p setVariable ['wfbe_mortar_designating', false];
	};
	_d = _p distance _pos;
	if (_d > _rng) exitWith {
		titleText [format ['Out of range (%1m of %2m). Click closer.', round _d, round _rng], 'PLAIN'];
	};
	onMapSingleClick '';
	openMap false;
	_p setVariable ['wfbe_mortar_designating', false];
	_cool = missionNamespace getVariable ['WFBE_C_GUER_MORTAR_COOLDOWN', 240];
	_start = time;
	_p setVariable ['wfbe_mortar_last', _start];
	_m = Format ['wfbe_guer_mortar_impact_%1', round (diag_tickTime * 1000)];
	createMarkerLocal [_m, _pos];
	_m setMarkerTypeLocal 'mil_destroy';
	_m setMarkerColorLocal 'ColorOrange';
	_m setMarkerSizeLocal [0.9, 0.9];
	_m setMarkerTextLocal Format ['Mortar impact - ready in %1s', ceil _cool];
	[_m, _p, _start, _cool] spawn {
		private ['_marker','_player','_start','_cool','_left','_currentLast','_ready'];
		_marker = _this select 0;
		_player = _this select 1;
		_start = _this select 2;
		_cool = _this select 3;
		_ready = false;
		while {true} do {
			if (isNull _player) exitWith {};
			_currentLast = _player getVariable ['wfbe_mortar_last', -9999];
			if !(_currentLast >= _start) exitWith {
				deleteMarkerLocal _marker;
			};
			_left = ceil (_cool - (time - _start));
			if (_left <= 0) exitWith {_ready = true};
			_marker setMarkerTextLocal Format ['Mortar impact - ready in %1s', _left];
			sleep 5;
		};
		if !(isNull _player) then {
			deleteMarkerLocal _marker;
			if (_ready && {alive _player}) then {titleText ['Mortar crew ready.', 'PLAIN']};
		};
	};
	['RequestSpecial', ['guer-mortar-strike', _pos, _p]] Call WFBE_CO_FNC_SendToServer;
	titleText [Format ['Strike inbound. Mortar reloading - %1s.', ceil _cool], 'PLAIN'];
";
