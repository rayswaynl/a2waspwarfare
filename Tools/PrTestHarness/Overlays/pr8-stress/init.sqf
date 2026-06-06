// WASP PR test harness overlay.
// This file is copied into a local test mission only; do not ship it in normal missions.

diag_log "[WASP-PR8-STRESS] init.sqf reached";
diag_log "[WASP-PR8-BUILD] activeMission=local-pr-test source=Tools/PrTestHarness profile=pr8-stress queue=server hcPreflight=true";

WASP_PR8_STRESS_ENABLED = true;
WASP_PR8_STRESS_PROFILE = "normal";
WASP_PR8_STRESS_GROUPS_PER_SIDE = 8;
WASP_PR8_STRESS_UNITS_PER_GROUP = 5;
WASP_PR8_STRESS_VEHICLE_PAIRS = 6;
WASP_PR8_STRESS_SAMPLE_COUNT = 24;
WASP_PR8_STRESS_SAMPLE_DELAY = 20;
WASP_PR8_STRESS_PHASE_DELAY = 10;
WASP_PR8_STRESS_REINFORCEMENT_INTERVAL = 6;
WASP_PR8_STRESS_REINFORCEMENT_GROUPS = 2;
WASP_PR8_STRESS_TRIGGER_DIRECT_ACTIONS = true;
WASP_PR8_STRESS_TOWN_LIFECYCLE_ENABLED = true;
WASP_PR8_STRESS_TOWN_WAIT = 8;
WASP_PR8_STRESS_TOWN_RESTORE = true;
WASP_PR8_STRESS_CLEANUP = false;
WASP_PR8_STRESS_REQUIRE_HC = true;
WASP_PR8_STRESS_HC_WAIT = 300;

if (isServer) then {
	diag_log "[WASP-PR8-STRESS] init.sqf handoff to stress harness";
	[] execVM "test\wasp_pr8_stress_mission.sqf";

	diag_log "[WASP-SELFTEST] init.sqf handoff to smoke harness";
	[] execVM "test\wasp_selftest.sqf";
};

if (!isDedicated) then {
	diag_log "[WASP-PR8-STRESS] init.sqf handoff to client stress actions";
	[] execVM "test\wasp_pr8_stress_client.sqf";
};
