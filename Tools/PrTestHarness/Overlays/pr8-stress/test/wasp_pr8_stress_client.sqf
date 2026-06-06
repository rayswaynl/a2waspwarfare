/*
    Test-only client helper for the WASP PR8 stress mission copy.
    The normal mission does not call this file.
*/

if (isDedicated) exitWith {};
if (isNil "WASP_PR8_STRESS_ENABLED") exitWith {};
if (!WASP_PR8_STRESS_ENABLED) exitWith {};

diag_log "[WASP-PR8-STRESS-CLIENT] helper waiting for player";

WASP_PR8_STRESS_CLIENT_LAST_PLAYER = objNull;

while {true} do {
	waitUntil {!isNull player};
	if (player != WASP_PR8_STRESS_CLIENT_LAST_PLAYER) then {
		Private ["_oldActions","_actions","_id"];
		if (!isNull WASP_PR8_STRESS_CLIENT_LAST_PLAYER) then {
			_oldActions = WASP_PR8_STRESS_CLIENT_LAST_PLAYER getVariable ["WASP_PR8_STRESS_CLIENT_ACTIONS", []];
			{WASP_PR8_STRESS_CLIENT_LAST_PLAYER removeAction _x} forEach _oldActions;
		};

		_actions = [];
		_id = player addAction ["<t color='#7cff9b'>PR8 Queue: full sequence</t>", "test\wasp_pr8_stress_client_action.sqf", ["queue-full"], 1, false, true];
		_actions set [count _actions, _id];
		_id = player addAction ["<t color='#7cff9b'>PR8 Queue: AI behavior</t>", "test\wasp_pr8_stress_client_action.sqf", ["queue-ai"], 1, false, true];
		_actions set [count _actions, _id];
		_id = player addAction ["<t color='#7cff9b'>PR8 Queue: factories</t>", "test\wasp_pr8_stress_client_action.sqf", ["queue-factory"], 1, false, true];
		_actions set [count _actions, _id];
		_id = player addAction ["<t color='#7cff9b'>PR8 Queue: service/supply</t>", "test\wasp_pr8_stress_client_action.sqf", ["queue-service"], 1, false, true];
		_actions set [count _actions, _id];
		_id = player addAction ["<t color='#7cff9b'>PR8 Queue: WDDM/artillery</t>", "test\wasp_pr8_stress_client_action.sqf", ["queue-wddm"], 1, false, true];
		_actions set [count _actions, _id];
		_id = player addAction ["<t color='#7cff9b'>PR8 Queue: UI/UX</t>", "test\wasp_pr8_stress_client_action.sqf", ["queue-ui"], 1, false, true];
		_actions set [count _actions, _id];
		_id = player addAction ["<t color='#7cff9b'>PR8 Queue: load/perf</t>", "test\wasp_pr8_stress_client_action.sqf", ["queue-load"], 1, false, true];
		_actions set [count _actions, _id];
		_id = player addAction ["<t color='#7cff9b'>PR8 Queue: GPS/UI</t>", "test\wasp_pr8_stress_client_action.sqf", ["queue-gps-ui"], 1, false, true];
		_actions set [count _actions, _id];
		_id = player addAction ["<t color='#7cff9b'>PR8 Queue: bughunt sweep</t>", "test\wasp_pr8_stress_client_action.sqf", ["queue-bughunt"], 1, false, true];
		_actions set [count _actions, _id];
		_id = player addAction ["<t color='#ffb86c'>PR8 Queue: status</t>", "test\wasp_pr8_stress_client_action.sqf", ["queue-status"], 1, false, true];
		_actions set [count _actions, _id];
		_id = player addAction ["<t color='#ff6b6b'>PR8 Queue: stop/clear</t>", "test\wasp_pr8_stress_client_action.sqf", ["queue-stop"], 1, false, true];
		_actions set [count _actions, _id];
		_id = player addAction ["<t color='#ffb86c'>PR8 Cleanup loop: start 5m</t>", "test\wasp_pr8_stress_client_action.sqf", ["cleanup-loop-start"], 1, false, true];
		_actions set [count _actions, _id];
		_id = player addAction ["<t color='#ffb86c'>PR8 Cleanup loop: stop</t>", "test\wasp_pr8_stress_client_action.sqf", ["cleanup-loop-stop"], 1, false, true];
		_actions set [count _actions, _id];
		_id = player addAction ["<t color='#f6d365'>PR8 Test: snapshot all</t>", "test\wasp_pr8_stress_client_action.sqf", ["snapshot"], 1, false, true];
		_actions set [count _actions, _id];
		_id = player addAction ["<t color='#f6d365'>PR8 Test: AI behavior audit</t>", "test\wasp_pr8_stress_client_action.sqf", ["ai-audit"], 1, false, true];
		_actions set [count _actions, _id];
		_id = player addAction ["<t color='#f6d365'>PR8 Test: AI deep sample</t>", "test\wasp_pr8_stress_client_action.sqf", ["ai-deep-sample"], 1, false, true];
		_actions set [count _actions, _id];
		_id = player addAction ["<t color='#f6d365'>PR8 Test: spawn AI wave</t>", "test\wasp_pr8_stress_client_action.sqf", ["spawn-wave"], 1, false, true];
		_actions set [count _actions, _id];
		_id = player addAction ["<t color='#f6d365'>PR8 Test: spawn HEAVY AI wave</t>", "test\wasp_pr8_stress_client_action.sqf", ["spawn-heavy-wave"], 1, false, true];
		_actions set [count _actions, _id];
		_id = player addAction ["<t color='#f6d365'>PR8 Test: FPS burst sample</t>", "test\wasp_pr8_stress_client_action.sqf", ["perf-burst"], 1, false, true];
		_actions set [count _actions, _id];
		_id = player addAction ["<t color='#f6d365'>PR8 Test: spawn vehicle load</t>", "test\wasp_pr8_stress_client_action.sqf", ["vehicle-load"], 1, false, true];
		_actions set [count _actions, _id];
		_id = player addAction ["<t color='#f6d365'>PR8 Test: factories/queues audit</t>", "test\wasp_pr8_stress_client_action.sqf", ["factory-audit"], 1, false, true];
		_actions set [count _actions, _id];
		_id = player addAction ["<t color='#f6d365'>PR8 Test: UI/UX audit</t>", "test\wasp_pr8_stress_client_action.sqf", ["ui-audit"], 1, false, true];
		_actions set [count _actions, _id];
		_id = player addAction ["<t color='#f6d365'>PR8 Test: GPS/UI audit</t>", "test\wasp_pr8_stress_client_action.sqf", ["gps-ui-audit"], 1, false, true];
		_actions set [count _actions, _id];
		_id = player addAction ["<t color='#f6d365'>PR8 Test: GPS gain/toggle audit</t>", "test\wasp_pr8_stress_client_action.sqf", ["gps-gain-toggle-audit"], 1, false, true];
		_actions set [count _actions, _id];
		_id = player addAction ["<t color='#f6d365'>PR8 Test: player FPS/UX audit</t>", "test\wasp_pr8_stress_client_action.sqf", ["player-experience-audit"], 1, false, true];
		_actions set [count _actions, _id];
		_id = player addAction ["<t color='#f6d365'>PR8 Test: AI delegation audit</t>", "test\wasp_pr8_stress_client_action.sqf", ["ai-delegation-audit"], 1, false, true];
		_actions set [count _actions, _id];
		_id = player addAction ["<t color='#f6d365'>PR8 Test: bughunt audit</t>", "test\wasp_pr8_stress_client_action.sqf", ["bughunt-audit"], 1, false, true];
		_actions set [count _actions, _id];
		_id = player addAction ["<t color='#f6d365'>PR8 Test: service/supply audit</t>", "test\wasp_pr8_stress_client_action.sqf", ["service-supply-audit"], 1, false, true];
		_actions set [count _actions, _id];
		_id = player addAction ["<t color='#f6d365'>PR8 Test: WDDM/artillery audit</t>", "test\wasp_pr8_stress_client_action.sqf", ["wddm-artillery-audit"], 1, false, true];
		_actions set [count _actions, _id];
		_id = player addAction ["<t color='#f6d365'>PR8 Test: town lifecycle</t>", "test\wasp_pr8_stress_client_action.sqf", ["town-lifecycle"], 1, false, true];
		_actions set [count _actions, _id];
		_id = player addAction ["<t color='#f6d365'>PR8 Test: direct probes</t>", "test\wasp_pr8_stress_client_action.sqf", ["trigger-direct"], 1, false, true];
		_actions set [count _actions, _id];
		_id = player addAction ["<t color='#f6d365'>PR8 Test: dump profile</t>", "test\wasp_pr8_stress_client_action.sqf", ["profile"], 1, false, true];
		_actions set [count _actions, _id];
		_id = player addAction ["<t color='#f6d365'>PR8 Test: cleanup/reset</t>", "test\wasp_pr8_stress_client_action.sqf", ["cleanup"], 1, false, true];
		_actions set [count _actions, _id];

		player setVariable ["WASP_PR8_STRESS_CLIENT_ACTIONS", _actions];
		WASP_PR8_STRESS_CLIENT_LAST_PLAYER = player;
		diag_log Format ["[WASP-PR8-STRESS-CLIENT] actions added count=%1 player=%2", count _actions, player];
	};
	sleep 10;
};
