/*
	Server-observable CHATRELAY fallback for Arma 2 OA 1.64.
	Parameters: [channel, player, text]

	The display-24 client chat hook is blocked-pending-BE: repository/config evidence cannot prove
	its OA 1.64 semantics. This function therefore accepts only server-created event data; there is
	no client ingress, inbound path, or JIP/respawn client handler.
*/
private ["_channel","_player","_text","_sanitize","_safeChannel","_safePlayer","_safeText","_window","_lastWindow","_emitted","_dropped"];

if (!isServer) exitWith {};
if ((missionNamespace getVariable ["WFBE_C_CHAT_RELAY", 0]) <= 0) exitWith {};
if ((typeName _this) != "ARRAY") exitWith {};
if ((count _this) < 3) exitWith {};

_channel = _this select 0;
_player = _this select 1;
_text = _this select 2;
if ((typeName _channel) != "STRING") exitWith {};
if ((typeName _player) != "STRING") exitWith {};
if ((typeName _text) != "STRING") exitWith {};

//--- Global budget: reserve line 20 for one overflow summary, so total CHATRELAY lines stay <=20/minute.
//--- The summary is emitted on the first event in the next window, after the prior window's
//--- dropped counter is complete; this keeps the summary accurate while retaining one line only.
_window = floor (time / 60);
_lastWindow = missionNamespace getVariable ["WFBE_CHATRELAY_WINDOW", -1];
if (_lastWindow != _window) then {
	_dropped = missionNamespace getVariable ["WFBE_CHATRELAY_DROPPED", 0];
	if (_lastWindow >= 0 && {_dropped > 0}) then {
		diag_log Format ["CHATRELAY|v1|SUMMARY|SERVER|dropped=%1", _dropped];
	};
	missionNamespace setVariable ["WFBE_CHATRELAY_WINDOW", _window];
	missionNamespace setVariable ["WFBE_CHATRELAY_EMITTED", 0];
	missionNamespace setVariable ["WFBE_CHATRELAY_DROPPED", 0];
};
_emitted = missionNamespace getVariable ["WFBE_CHATRELAY_EMITTED", 0];
_dropped = missionNamespace getVariable ["WFBE_CHATRELAY_DROPPED", 0];
if (_emitted >= 19) then {
	_dropped = _dropped + 1;
	missionNamespace setVariable ["WFBE_CHATRELAY_DROPPED", _dropped];
	exitWith {};
};

//--- Strip pipes and line breaks before the fixed pipe-delimited RPT contract; cap every field.
_sanitize = {
	private ["_raw","_limit","_out","_codes","_i","_code","_max"];
	_raw = _this select 0;
	_limit = _this select 1;
	_out = "";
	_codes = toArray _raw;
	_max = count _codes;
	if (_max > _limit) then {_max = _limit};
	if (_max > 0) then {
		for "_i" from 0 to (_max - 1) do {
			_code = _codes select _i;
			if (_code == 10 || {_code == 13} || {_code == 124}) then {_code = 32};
			_out = _out + toString [_code];
		};
	};
	_out
};

_safeChannel = [_channel, 32] call _sanitize;
_safePlayer = [_player, 64] call _sanitize;
_safeText = [_text, 256] call _sanitize;
diag_log Format ["CHATRELAY|v1|%1|%2|%3", _safeChannel, _safePlayer, _safeText];
missionNamespace setVariable ["WFBE_CHATRELAY_EMITTED", _emitted + 1];
