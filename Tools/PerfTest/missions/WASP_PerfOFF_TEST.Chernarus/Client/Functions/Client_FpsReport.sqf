//--- Client_FpsReport.sqf
//--- Staged-deploy client FPS telemetry (2026-06-15, Net_2 request).
//--- When the WFBE_C_CLIENT_FPS_REPORT lobby param is ON, each PLAYER client samples its own
//--- framerate periodically and publishes [uid, name, avgFps, minFps] to the server. The server
//--- (Init_Server.sqf) stamps each report with the day/night MODE + current in-game time so the
//--- RPT can be bucketed day-vs-night and day/night-cycle ON-vs-OFF. The goal is to compare
//--- client FPS with the accelerated day/night cycle enabled vs disabled over the rollout.
//---
//--- Players only: the dedicated server and headless clients have no meaningful "client FPS",
//--- and reporting from them would pollute the dataset. The lobby param is the single on/off gate.
if (!hasInterface) exitWith {};
if ((missionNamespace getVariable ["WFBE_C_CLIENT_FPS_REPORT", 0]) != 1) exitWith {};

private ["_interval", "_n", "_sum", "_min", "_f", "_avg", "_i"];

_interval = missionNamespace getVariable ["WFBE_C_CLIENT_FPS_REPORT_INTERVAL", 60];
if (_interval < 15) then { _interval = 15 };
_n = 5; //--- one-second samples averaged per report: smooths single-frame spikes and yields the worst.

//--- Stagger clients so N players don't all publish on the same server tick.
sleep (5 + random 20);

while { !(missionNamespace getVariable ["WFBE_GameOver", false]) } do {
	_sum = 0;
	_min = 1e6;
	for "_i" from 1 to _n do {
		_f = diag_fps;
		_sum = _sum + _f;
		if (_f < _min) then { _min = _f };
		sleep 1;
	};
	_avg = _sum / _n;

	WFBE_FPS_REPORT = [getPlayerUID player, name player, round _avg, round _min];
	publicVariableServer "WFBE_FPS_REPORT";

	sleep (_interval - _n);
};
