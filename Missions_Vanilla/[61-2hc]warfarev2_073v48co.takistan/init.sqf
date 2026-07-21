//--- Global Init, first file called (real mission entry point).
//--- The Arma 2 OA engine auto-runs init.sqf at mission start on every machine
//--- (dedicated server, every connecting client, and every headless client).
//---
//--- WASP_INIT_LAUNCH_MARKER: this file must delegate to the real bootstrap
//--- below. Never replace it with a self-test/observer harness stub - Tools\Pack\
//--- pack_pbo.py refuses to pack any mission source folder whose init.sqf does not
//--- contain this exact line:
execVM "initJIPCompatible.sqf";
