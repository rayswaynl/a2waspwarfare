//--- Client_FrameTelemetry.sqf
//--- Default-off client frame-pacing baseline for Arma 2: Operation Arrowhead 1.64.
//--- Samples inverse diag_fps at low frequency and writes one local CLIENTFRAME|v1| line per report.
//--- No publicVariable, per-sample entity scan, simulation mutation, or process/hardware query.
if (!hasInterface) exitWith {};
if ((missionNamespace getVariable ["WFBE_C_CLIENT_FRAME_TELEMETRY", 0]) <= 0) exitWith {};

private ["_interval","_sampleInterval","_nextReport","_lastSample","_fps","_frameMs","_frames","_fpsSum","_fpsMin","_long50","_long100","_mapSamples","_gpsSamples","_dialogSamples","_sampleCount","_frameText","_i","_mapOpenPct","_gpsOpenPct","_dialogOpenPct","_fpsAvg","_frameMax","_markerCount","_aarMarkerCount","_playerCount","_aiCount","_timeToPlayable","_sessionId","_profileViewDistance","_profileTerrainGrid","_reportNow"];

_interval = missionNamespace getVariable ["WFBE_C_CLIENT_FRAME_TELEMETRY_INTERVAL", 60];
if (_interval < 30) then {_interval = 30};
_sampleInterval = 0.25;
_sessionId = missionNamespace getVariable ["PerformanceAuditSessionId", "unknown"];
_timeToPlayable = diag_tickTime - (missionNamespace getVariable ["PerformanceAuditMissionStartTick", diag_tickTime]);
missionNamespace setVariable ["PerformanceAuditClientTimeToPlayable", _timeToPlayable];

//--- Stagger clients, then keep the sampler deliberately sparse: one diag_fps read per 250ms.
sleep (5 + random 10);
_frames = [];
_fpsSum = 0;
_fpsMin = 1e9;
_long50 = 0;
_long100 = 0;
_mapSamples = 0;
_gpsSamples = 0;
_dialogSamples = 0;
_sampleCount = 0;
_nextReport = diag_tickTime + _interval;
_lastSample = diag_tickTime;

while {!(missionNamespace getVariable ["WFBE_GameOver", false])} do {
	_fps = diag_fps;
	if (_fps < 0.1) then {_fps = 0.1};
	_frameMs = 1000 / _fps;
	_frames set [_sampleCount, (round (_frameMs * 100)) / 100];
	_sampleCount = _sampleCount + 1;
	_fpsSum = _fpsSum + _fps;
	if (_fps < _fpsMin) then {_fpsMin = _fps};
	if (_frameMs >= 50) then {_long50 = _long50 + 1};
	if (_frameMs >= 100) then {_long100 = _long100 + 1};
	if (visibleMap) then {_mapSamples = _mapSamples + 1};
	if (shownGPS) then {_gpsSamples = _gpsSamples + 1};
	if (dialog) then {_dialogSamples = _dialogSamples + 1};
	_lastSample = diag_tickTime;
	sleep _sampleInterval;

	if (_lastSample >= _nextReport) then {
		_reportNow = diag_tickTime;
		_sampleCount = count _frames;
		if (_sampleCount < 1) then {_sampleCount = 1};
		_frameText = "";
		for "_i" from 0 to ((count _frames) - 1) do {
			if (_frameText == "") then {_frameText = str (_frames select _i)} else {_frameText = _frameText + "," + str (_frames select _i)};
		};
		_mapOpenPct = (round ((_mapSamples / _sampleCount) * 1000)) / 1000;
		_gpsOpenPct = (round ((_gpsSamples / _sampleCount) * 1000)) / 1000;
		_dialogOpenPct = (round ((_dialogSamples / _sampleCount) * 1000)) / 1000;
		_fpsAvg = (round ((_fpsSum / _sampleCount) * 100)) / 100;
		_frameMax = 0;
		for "_i" from 0 to ((count _frames) - 1) do {
			if ((_frames select _i) > _frameMax) then {_frameMax = _frames select _i};
		};
		_markerCount = missionNamespace getVariable ["PerformanceAuditMarkerScripts", 0];
		_aarMarkerCount = missionNamespace getVariable ["PerformanceAuditAARMarkerScripts", 0];
		_playerCount = {isPlayer _x} count allUnits;
		_aiCount = (count allUnits) - _playerCount;
		_profileViewDistance = profileNamespace getVariable ["WFBE_PERSISTENT_CONST_VIEW_DISTANCE", -1];
		_profileTerrainGrid = profileNamespace getVariable ["WFBE_PERSISTENT_CONST_TERRAIN_GRID", -1];
		diag_log format ["CLIENTFRAME|v1|sid=%1|map=%2|tick=%3|time=%4|sampleSec=%5|samples=%6|frameMs=%7|frameMaxMs=%8|long50=%9|long100=%10|fpsAvg=%11|fpsMin=%12|players=%13|ai=%14|units=%15|vehicles=%16|markers=%17|aarMarkers=%18|mapOpenPct=%19|gpsOpenPct=%20|dialogOpenPct=%21|vd=%22|pvd=%23|terrainGrid=%24|ttPlayable=%25|playable=%26|hardwareTier=external|processCpuPct=na|workingSetMb=na", _sessionId, worldName, round _reportNow, round (time * 100) / 100, round (_reportNow - (_nextReport - _interval)), _sampleCount, _frameText, _frameMax, _long50, _long100, _fpsAvg, round _fpsMin, _playerCount, _aiCount, count allUnits, count vehicles, _markerCount, _aarMarkerCount, _mapOpenPct, _gpsOpenPct, _dialogOpenPct, viewDistance, _profileViewDistance, _profileTerrainGrid, round (_timeToPlayable * 100) / 100, if (isNull player) then {0} else {1}];
		_frames = [];
		_fpsSum = 0;
		_fpsMin = 1e9;
		_long50 = 0;
		_long100 = 0;
		_mapSamples = 0;
		_gpsSamples = 0;
		_dialogSamples = 0;
		_sampleCount = 0;
		_nextReport = _reportNow + _interval;
	};
};
