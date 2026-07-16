/* Generated-copy pre-init entrypoint. This file is never referenced by a production mission. */

if (!isNil "WASP_LAB_PREINIT_DONE") exitWith {};
WASP_LAB_PREINIT_DONE = true;

diag_log ("WASPLAB|v1|BOOT|run=boot-" + str (round (diag_tickTime * 1000)) + "|map=" + worldName + "|phase=preinit");
call compile preprocessFileLineNumbers "test\ProvingGround_Config.sqf";

diag_log format ["WASPLAB|v1|PREINIT|server=%1|dedicated=%2|map=%3", isServer, isDedicated, worldName];

if (isServer) then {
	[] execVM "test\ProvingGround_Server.sqf";
};
