/*
    Test-only client helper for the WASP PR8 stress mission copy.
    The normal mission does not call this file.
*/

if (isDedicated) exitWith {};
if (isNil "WASP_PR8_STRESS_ENABLED") exitWith {};
if (!WASP_PR8_STRESS_ENABLED) exitWith {};

diag_log "[WASP-PR8-STRESS-CLIENT] helper waiting for player";

waitUntil {!isNull player};
_isHeadless = false;
if (!isNil "isHeadLessClient") then {_isHeadless = isHeadLessClient};
if ((!hasInterface) || {_isHeadless}) exitWith {
	diag_log Format ["[WASP-PR8-STRESS-CLIENT] helper skipped headless/non-interface player=%1 hasInterface=%2 isHeadless=%3", player, hasInterface, _isHeadless];
};

WASP_PR8_STRESS_CLIENT_LAST_PLAYER = objNull;
WASP_PR8_STRESS_CLIENT_AUTOFIRED = false;
WASP_PR8_STRESS_CLIENT_DIALOG_WATCH_RUNNING = false;

if (!WASP_PR8_STRESS_CLIENT_DIALOG_WATCH_RUNNING) then {
	WASP_PR8_STRESS_CLIENT_DIALOG_WATCH_RUNNING = true;
	[] Spawn {
		Private ["_watch","_displayOpen","_command","_lastKey","_lastTime","_now","_key","_label"];
		disableSerialization;
		_lastKey = "";
		_lastTime = -999;
		diag_log "[WASP-PR8-STRESS-CLIENT] dialog watcher started";
		while {true} do {
			waitUntil {!isNull player};
			_watch = [
				["wf-menu", 11000, "ui-audit"],
				["buy-menu", 12000, "ui-audit"],
				["team-menu", 13000, "ui-audit"],
				["command-menu", 14000, "ui-audit"],
				["tactical-menu", 17000, "ui-audit"],
				["service-menu", 20000, "ui-audit"],
				["unit-camera-menu", 21000, "ui-audit"],
				["parameters-menu", 22000, "ui-audit"],
				["economy-menu", 23000, "ui-audit"],
				["easa-menu", 24000, "ui-audit"],
				["gear-menu", 503000, "ui-audit"],
				["upgrade-menu", 504000, "ui-audit"],
				["transfer-menu", 505000, "ui-audit"],
				["help-menu", 508000, "ui-audit"],
				["respawn-menu", 511000, "ui-audit"],
				["vote-menu", 500000, "ui-audit"],
				["commander-vote-menu", 500999, "ui-audit"]
			];
			{
				_label = _x select 0;
				_displayOpen = !(isNull (findDisplay (_x select 1)));
				_command = _x select 2;
				if (_displayOpen) exitWith {
					_now = time;
					_key = Format ["%1:%2", _label, _command];
					if ((_key != _lastKey) || {(_now - _lastTime) > 45}) then {
						_lastKey = _key;
						_lastTime = _now;
						diag_log Format ["[WASP-PR8-STRESS-CLIENT] DIALOG_AUTO_PROBE dialog auto probe label=%1 command=%2", _label, _command];
						[player, player, -2, [_command]] execVM "test\wasp_pr8_stress_client_action.sqf";
					};
				};
			} forEach _watch;
			sleep 3;
		};
	};
};

while {true} do {
	waitUntil {!isNull player};
	if (player != WASP_PR8_STRESS_CLIENT_LAST_PLAYER) then {
		Private ["_oldActions","_actions","_id"];
		if (!isNull WASP_PR8_STRESS_CLIENT_LAST_PLAYER) then {
			_oldActions = WASP_PR8_STRESS_CLIENT_LAST_PLAYER getVariable ["WASP_PR8_STRESS_CLIENT_ACTIONS", []];
			{WASP_PR8_STRESS_CLIENT_LAST_PLAYER removeAction _x} forEach _oldActions;
		};

		_actions = [];
		_id = player addAction ["<t color='#7cff9b'>PR8 AUTO: full bughunt run</t>", "test\wasp_pr8_stress_client_action.sqf", ["queue-operator"], 1, false, true];
		_actions set [count _actions, _id];
		_id = player addAction ["<t color='#7cff9b'>PR8 AUTO: AI/FPS soak</t>", "test\wasp_pr8_stress_client_action.sqf", ["queue-ai-long"], 1, false, true];
		_actions set [count _actions, _id];
		_id = player addAction ["<t color='#7cff9b'>PR8 AUTO: systems sweep</t>", "test\wasp_pr8_stress_client_action.sqf", ["queue-systems"], 1, false, true];
		_actions set [count _actions, _id];
		_id = player addAction ["<t color='#7cff9b'>PR8 AUTO: UI/GPS sweep</t>", "test\wasp_pr8_stress_client_action.sqf", ["queue-ui-long"], 1, false, true];
		_actions set [count _actions, _id];
		_id = player addAction ["<t color='#7cff9b'>PR8 AUTO: town cap regression</t>", "test\wasp_pr8_stress_client_action.sqf", ["queue-town-regression"], 1, false, true];
		_actions set [count _actions, _id];
		_id = player addAction ["<t color='#ffb86c'>PR8 Queue: status</t>", "test\wasp_pr8_stress_client_action.sqf", ["queue-status"], 1, false, true];
		_actions set [count _actions, _id];
		_id = player addAction ["<t color='#ff6b6b'>PR8 Queue: stop/clear</t>", "test\wasp_pr8_stress_client_action.sqf", ["queue-stop"], 1, false, true];
		_actions set [count _actions, _id];
		_id = player addAction ["<t color='#ffb86c'>PR8 Cleanup loop: start 5m</t>", "test\wasp_pr8_stress_client_action.sqf", ["cleanup-loop-start"], 1, false, true];
		_actions set [count _actions, _id];
		_id = player addAction ["<t color='#ffb86c'>PR8 Cleanup loop: stop</t>", "test\wasp_pr8_stress_client_action.sqf", ["cleanup-loop-stop"], 1, false, true];
		_actions set [count _actions, _id];

		player setVariable ["WASP_PR8_STRESS_CLIENT_ACTIONS", _actions];
		WASP_PR8_STRESS_CLIENT_LAST_PLAYER = player;
		diag_log Format ["[WASP-PR8-STRESS-CLIENT] actions added count=%1 player=%2", count _actions, player];

		if (!WASP_PR8_STRESS_CLIENT_AUTOFIRED) then {
			WASP_PR8_STRESS_CLIENT_AUTOFIRED = true;
			[] Spawn {
				Private ["_commands","_command"];
				sleep 18;
				_commands = ["ui-audit","gps-ui-audit","gps-gain-toggle-audit","player-experience-audit","ai-delegation-audit","bughunt-audit","random-bughunt-audit"];
				{
					_command = _x;
					diag_log Format ["[WASP-PR8-STRESS-CLIENT] auto probe command=%1", _command];
					[player, player, -1, [_command]] execVM "test\wasp_pr8_stress_client_action.sqf";
					sleep 6;
				} forEach _commands;
				diag_log "[WASP-PR8-STRESS-CLIENT] auto probes complete";
			};
		};
	};
	sleep 10;
};
