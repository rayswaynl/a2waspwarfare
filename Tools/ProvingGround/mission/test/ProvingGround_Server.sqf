/*
	WASP Proving Ground server controller.

	Runs only in a generated test mission. It provides four orthogonal loads:
	  - real mission AICOM/town delegation (scenario pins),
	  - controlled server-local unit/group ramps,
	  - repeated Utes town-to-town path legs or matched combat,
	  - bounded round trips over the real Common_Send bus.

	Every signal uses plain diag_log so WF_LOG_CONTENT cannot make the lab invisible.
*/

Private ["_scenario","_variant","_schedulerMode","_duration","_sampleSec","_warmup","_mode","_totalGroups","_unitsPerGroup",
		"_batchGroups","_batchInterval","_vehicleEvery","_busRate","_expectedHcs","_start","_end",
		"_run","_townCount","_cleanup","_status","_reason","_fpsN","_fpsAvg","_fpsMin","_hcPctMin",
		"_busSent","_busAck","_busDrop","_busLoss","_busLatAvg","_aiPeak","_groupsPeak","_stuckMax","_trackedPeak",
		"_labTowns","_townObj","_schedRuns","_schedDeferred","_schedOverruns","_schedErrors","_schedMaxElapsed",
		"_schedAge","_schedControlAge","_spawnedTotal","_arrivals","_hcImbalanceLast","_hcGroupImbalanceLast","_stuckPctMax",
		"_busAttemptPost","_busSentPost","_busAckPost","_busExpected","_busAttainPct","_busFreshEndpoints"];
Private ["_sampleExpected","_sampleCoveragePct"];
Private ["_hcsMin","_hcBalanceN","_hcImbalancedN","_hcImbalanceMax","_hcImbalancedPct"];
Private ["_hcFpsMin","_hcFpsN","_hcOwnersFinal"];
Private ["_cleanupObjects","_cleanupGroups","_cleanupObjectsRemaining","_cleanupGroupsRemaining"];
Private ["_combatInitial","_combatAlive","_combatCasualties","_combatMovedGroups","_combatMovedPct","_combatGroups"];

Private ["_utesTownOrderOk","_paramNames","_paramSig","_paramValue","_paramIndex"];
Private ["_candidate","_git","_configId","_workloadId","_partitionId"];
Private ["_sourceId","_labCodeId"];
Private ["_baselineAi","_baselineGroups","_baselineVehicles","_auditEnabled"];
Private ["_initDeadline","_initReady"];
Private ["_targetSyntheticUnits","_spawnAnchors","_settleSec","_partitionMode","_measureStart","_measureElapsed","_spawnDeadline","_settleEnd"];
Private ["_realizedGroups","_requestedInfantry","_createdInfantry","_createdCrew","_createdVehicles","_finalMembers"];
Private ["_underfillGroups","_oversizeGroups","_createFailures","_createFailureGroups","_memberSeconds","_groupSeconds"];
Private ["_pathLegsStarted","_routeIds","_histogram","_anchorRequested","_anchorMembers"];
Private ["_drainDeadline","_drainTimedOut"];

if (!isServer) exitWith {};
if (!(missionNamespace getVariable ["WASP_LAB_ENABLED", false])) exitWith {};

_initDeadline = diag_tickTime + 180;
waitUntil {
	sleep 1;
	_initReady = (!isNil "commonInitComplete") && {commonInitComplete} &&
	{(!isNil "townInit") && {townInit}} &&
	{(!isNil "townInitServer") && {townInitServer}} &&
	{(!isNil "serverInitFull") && {serverInitFull}};
	_initReady || {diag_tickTime >= _initDeadline}
};
if !(_initReady) exitWith {
	diag_log ("WASPLAB|v1|ABORT|run=boot|reason=init_timeout|common=" + (if (isNil "commonInitComplete") then {"nil"} else {str commonInitComplete}) +
		"|town=" + (if (isNil "townInit") then {"nil"} else {str townInit}) +
		"|townServer=" + (if (isNil "townInitServer") then {"nil"} else {str townInitServer}) +
		"|serverFull=" + (if (isNil "serverInitFull") then {"nil"} else {str serverInitFull}));
};

_scenario = missionNamespace getVariable ["WASP_LAB_SCENARIO", "unknown"];
_variant = missionNamespace getVariable ["WASP_LAB_VARIANT", "control"];
_schedulerMode = missionNamespace getVariable ["WASP_LAB_SCHEDULER_MODE", "off"];
_candidate = missionNamespace getVariable ["WASP_LAB_CANDIDATE", "unknown"];
_git = missionNamespace getVariable ["WASP_LAB_GIT", "unknown"];
_configId = missionNamespace getVariable ["WASP_LAB_CONFIG_ID", "unknown"];
_workloadId = missionNamespace getVariable ["WASP_LAB_WORKLOAD_ID", "unknown"];
_partitionId = missionNamespace getVariable ["WASP_LAB_PARTITION_ID", "unknown"];
_sourceId = missionNamespace getVariable ["WASP_LAB_SOURCE_ID", "unknown"];
_labCodeId = missionNamespace getVariable ["WASP_LAB_CODE_ID", "unknown"];
_duration = missionNamespace getVariable ["WASP_LAB_DURATION_SEC", 900];
_sampleSec = missionNamespace getVariable ["WASP_LAB_SAMPLE_SEC", 15];
_warmup = missionNamespace getVariable ["WASP_LAB_WARMUP_SEC", 60];
_mode = missionNamespace getVariable ["WASP_LAB_SYNTHETIC_MODE", "none"];
_totalGroups = missionNamespace getVariable ["WASP_LAB_SYNTHETIC_GROUPS", 0];
_unitsPerGroup = missionNamespace getVariable ["WASP_LAB_UNITS_PER_GROUP", 6];
_batchGroups = missionNamespace getVariable ["WASP_LAB_BATCH_GROUPS", 4];
_batchInterval = missionNamespace getVariable ["WASP_LAB_BATCH_INTERVAL_SEC", 30];
_vehicleEvery = missionNamespace getVariable ["WASP_LAB_VEHICLE_EVERY", 0];
_busRate = missionNamespace getVariable ["WASP_LAB_BUS_RATE", 0];
_expectedHcs = missionNamespace getVariable ["WASP_LAB_EXPECTED_HCS", 2];
_cleanup = missionNamespace getVariable ["WASP_LAB_CLEANUP", true];
_targetSyntheticUnits = missionNamespace getVariable ["WASP_LAB_TARGET_SYNTHETIC_UNITS", _totalGroups * _unitsPerGroup];
_spawnAnchors = missionNamespace getVariable ["WASP_LAB_SPAWN_ANCHORS", 0];
_settleSec = missionNamespace getVariable ["WASP_LAB_SETTLE_SEC", _warmup];

// Belt-and-braces runtime caps. The JSON builder applies the same limits before this file exists.
_duration = (_duration max 60) min 14400;
_sampleSec = (_sampleSec max 5) min 300;
_totalGroups = (_totalGroups max 0) min 120;
_unitsPerGroup = (_unitsPerGroup max 1) min 12;
_batchGroups = (_batchGroups max 1) min 10;
_batchInterval = (_batchInterval max 5) min 600;
_busRate = (_busRate max 0) min 50;
_targetSyntheticUnits = (_targetSyntheticUnits max 0) min 1440;
_spawnAnchors = (_spawnAnchors max 0) min 16;
_settleSec = (_settleSec max 0) min 600;

_run = _scenario + "-" + _variant + "-" + str (round (diag_tickTime * 1000));
_start = time;
_end = _start + _duration;
_labTowns = towns;
_utesTownOrderOk = true;
if ((toLower worldName) == "utes") then {
	_labTowns = [];
	{
		_townObj = missionNamespace getVariable [_x, objNull];
		if (!isNull _townObj) then {_labTowns set [count _labTowns, _townObj]};
	} forEach ["Strelka","Airfield","Kamenyy"];
	if (count _labTowns != 3) then {
		_labTowns = towns;
		_utesTownOrderOk = false;
	};
};
missionNamespace setVariable ["WASP_LAB_TOWNS", _labTowns];
_townCount = count _labTowns;
if (_townCount > 0 && {_spawnAnchors > _townCount}) then {_spawnAnchors = _townCount};
// Fixed-anchor density arms need a common GO boundary. All zero-anchor recipes keep
// PR #997's original total-duration, wall-clock warm-up and immediate-order behavior.
_partitionMode = _spawnAnchors > 0;
if (_partitionMode) then {_end = -1};
missionNamespace setVariable ["WASP_LAB_TARGET_SYNTHETIC_UNITS", _targetSyntheticUnits];
missionNamespace setVariable ["WASP_LAB_SPAWN_ANCHORS", _spawnAnchors];
missionNamespace setVariable ["WASP_LAB_SETTLE_SEC", _settleSec];
missionNamespace setVariable ["WASP_LAB_PARTITION_MODE", _partitionMode];

missionNamespace setVariable ["WASP_LAB_RUN_ID", _run];
missionNamespace setVariable ["WASP_LAB_START", _start];
missionNamespace setVariable ["WASP_LAB_END", _end];
missionNamespace setVariable ["WASP_LAB_MEASURE_START", -1];
missionNamespace setVariable ["WASP_LAB_PHASE", "SPAWN"];
missionNamespace setVariable ["WASP_LAB_PHASE_SEQ", 1];
missionNamespace setVariable ["WASP_LAB_STOP", false];
missionNamespace setVariable ["WASP_LAB_MEASURE_CLOSING", false];
missionNamespace setVariable ["WASP_LAB_SAMPLE_INFLIGHT", 0];
missionNamespace setVariable ["WASP_LAB_PATH_INFLIGHT", 0];
missionNamespace setVariable ["WASP_LAB_DRAIN_FAILED", false];
missionNamespace setVariable ["WASP_LAB_SPAWN_DONE", _totalGroups < 1];
missionNamespace setVariable ["WASP_LAB_TRACKED_GROUPS", []];
missionNamespace setVariable ["WASP_LAB_TRACKED_OBJECTS", []];
missionNamespace setVariable ["WASP_LAB_PATH_ARRIVALS", 0];
missionNamespace setVariable ["WASP_LAB_PATH_LEGS_STARTED", 0];
missionNamespace setVariable ["WASP_LAB_ROUTE_IDS", []];
missionNamespace setVariable ["WASP_LAB_REALIZED_GROUPS", 0];
missionNamespace setVariable ["WASP_LAB_REQUESTED_INFANTRY", 0];
missionNamespace setVariable ["WASP_LAB_CREATED_INFANTRY", 0];
missionNamespace setVariable ["WASP_LAB_CREATED_CREW", 0];
missionNamespace setVariable ["WASP_LAB_CREATED_VEHICLES", 0];
missionNamespace setVariable ["WASP_LAB_FINAL_MEMBERS", 0];
missionNamespace setVariable ["WASP_LAB_UNDERFILL_GROUPS", 0];
missionNamespace setVariable ["WASP_LAB_OVERSIZE_GROUPS", 0];
missionNamespace setVariable ["WASP_LAB_CREATE_FAILURES", 0];
missionNamespace setVariable ["WASP_LAB_CREATE_FAILURE_GROUPS", 0];
missionNamespace setVariable ["WASP_LAB_GROUP_SIZE_HISTOGRAM", []];
missionNamespace setVariable ["WASP_LAB_ANCHOR_REQUESTED", []];
missionNamespace setVariable ["WASP_LAB_ANCHOR_MEMBERS", []];
missionNamespace setVariable ["WASP_LAB_MEMBER_SECONDS", 0];
missionNamespace setVariable ["WASP_LAB_GROUP_SECONDS", 0];
missionNamespace setVariable ["WASP_LAB_EXPOSURE_LAST", -1];
missionNamespace setVariable ["WASP_LAB_BUS_SENT_TOTAL", 0];
missionNamespace setVariable ["WASP_LAB_BUS_ATTEMPT_POST", 0];
missionNamespace setVariable ["WASP_LAB_BUS_SENT_POST", 0];
missionNamespace setVariable ["WASP_LAB_BUS_DROP_TOTAL", 0];
missionNamespace setVariable ["WASP_LAB_BUS_ACK_TOTAL", 0];
missionNamespace setVariable ["WASP_LAB_BUS_ACK_POST", 0];
missionNamespace setVariable ["WASP_LAB_BUS_ACK_DUP", 0];
missionNamespace setVariable ["WASP_LAB_BUS_LAT_SUM", 0];
missionNamespace setVariable ["WASP_LAB_BUS_LAT_MAX", 0];
missionNamespace setVariable ["WASP_LAB_BUS_LAT_SUM_POST", 0];
missionNamespace setVariable ["WASP_LAB_BUS_LAT_MAX_POST", 0];
missionNamespace setVariable ["WASP_LAB_BUS_ACK_SEEN", []];
missionNamespace setVariable ["WASP_LAB_BUS_ACK_ENDPOINTS", []];
missionNamespace setVariable ["WASP_LAB_BUS_PENDING", []];
missionNamespace setVariable ["WASP_LAB_FPS_N", 0];
missionNamespace setVariable ["WASP_LAB_FPS_SUM", 0];
missionNamespace setVariable ["WASP_LAB_FPS_MIN", 1000];
missionNamespace setVariable ["WASP_LAB_AI_PEAK", 0];
missionNamespace setVariable ["WASP_LAB_GROUPS_PEAK", 0];
missionNamespace setVariable ["WASP_LAB_HCPCT_MIN", 100];
missionNamespace setVariable ["WASP_LAB_HCPCT_N", 0];
missionNamespace setVariable ["WASP_LAB_STUCK_MAX", 0];
missionNamespace setVariable ["WASP_LAB_STUCK_PCT_MAX", 0];
missionNamespace setVariable ["WASP_LAB_TRACKED_PEAK", 0];
missionNamespace setVariable ["WASP_LAB_SPAWNED_TOTAL", 0];
missionNamespace setVariable ["WASP_LAB_HC_IMBALANCE_LAST", -1];
missionNamespace setVariable ["WASP_LAB_HC_GROUP_IMBALANCE_LAST", -1];
missionNamespace setVariable ["WASP_LAB_HCS_MIN", 99];
missionNamespace setVariable ["WASP_LAB_HC_BALANCE_N", 0];
missionNamespace setVariable ["WASP_LAB_HC_IMBALANCED_N", 0];
missionNamespace setVariable ["WASP_LAB_HC_IMBALANCE_MAX", 0];
missionNamespace setVariable ["WASP_LAB_HC_FPS_MIN", 1000];
missionNamespace setVariable ["WASP_LAB_HC_FPS_N", 0];
missionNamespace setVariable ["WASP_LAB_COMBAT_INITIAL_UNITS", 0];

_paramNames = missionNamespace getVariable ["WASP_LAB_PARAM_NAMES", []];
_paramSig = 17;
for "_paramIndex" from 0 to ((count _paramNames) - 1) do {
	_paramValue = missionNamespace getVariable [_paramNames select _paramIndex, 0];
	if (typeName _paramValue != "SCALAR") then {_paramValue = 0};
	_paramSig = ((_paramSig * 33) + (round (_paramValue * 1000)) + _paramIndex) mod 2147483647;
};
missionNamespace setVariable ["WASP_LAB_PARAM_SIG", _paramSig];
_baselineAi = {!(isPlayer _x)} count allUnits;
_baselineGroups = count allGroups;
_baselineVehicles = count vehicles;
_auditEnabled = missionNamespace getVariable ["PerformanceAuditEnabled", false];

diag_log ("WASPLAB|v1|START|run=" + _run + "|scenario=" + _scenario + "|map=" + worldName +
		"|build=" + _candidate + "|git=" + _git + "|source=" + _sourceId + "|lab=" + _labCodeId +
		"|config=" + _configId + "|workload=" + _workloadId +
		"|partition=" + _partitionId +
		"|variant=" + _variant + "|seed=engine|duration=" + str _duration + "|sampleSec=" + str _sampleSec +
		"|mode=" + _mode + "|targetGroups=" + str _totalGroups + "|unitsPerGroup=" + str _unitsPerGroup +
		"|targetSyntheticUnits=" + str _targetSyntheticUnits + "|spawnAnchors=" + str _spawnAnchors + "|settleSec=" + str _settleSec +
		"|batchGroups=" + str _batchGroups + "|batchInterval=" + str _batchInterval + "|vehicleEvery=" + str _vehicleEvery +
		"|busRate=" + str _busRate + "|expectedHcs=" + str _expectedHcs + "|warmupSec=" + str _warmup +
		"|minHcFps=" + str (missionNamespace getVariable ["WASP_LAB_MIN_HC_FPS", 25]) +
		"|schedulerMode=" + _schedulerMode + "|paramSig=" + str _paramSig + "|towns=" + str _townCount +
		"|baselineAi=" + str _baselineAi + "|baselineGroups=" + str _baselineGroups + "|baselineVehicles=" + str _baselineVehicles +
		"|performanceAudit=" + str _auditEnabled);

if !(_utesTownOrderOk) exitWith {
	diag_log ("WASPLAB|v1|ABORT|run=" + _run + "|reason=utes_named_towns_missing");
	missionNamespace setVariable ["WASP_LAB_STOP", true];
};

if (_townCount < 1 && {_totalGroups > 0}) exitWith {
	diag_log ("WASPLAB|v1|ABORT|run=" + _run + "|reason=towns_empty");
	missionNamespace setVariable ["WASP_LAB_STOP", true];
};

if (_schedulerMode != "off") then {
	Call Compile preprocessFileLineNumbers "test\RuntimeScheduler.sqf";
};

WASP_LAB_FNC_IndexedText = {
	Private ["_values","_text","_i","_value"];
	_values = _this select 0;
	_text = "none";
	if (count _values > 0) then {
		_text = "";
		for "_i" from 0 to ((count _values) - 1) do {
			_value = _values select _i;
			if (_value > 0) then {
				if (_text != "") then {_text = _text + ","};
				_text = _text + str _i + ":" + str _value;
			};
		};
		if (_text == "") then {_text = "none"};
	};
	_text
};

WASP_LAB_FNC_RouteText = {
	Private ["_routes","_text"];
	_routes = missionNamespace getVariable ["WASP_LAB_ROUTE_IDS", []];
	_text = "";
	{
		if (_text != "") then {_text = _text + ";"};
		_text = _text + _x;
	} forEach _routes;
	if (_text == "") then {_text = "none"};
	_text
};

WASP_LAB_FNC_CompositionText = {
	Private ["_histogramText","_anchorRequestedText","_anchorMembersText","_routeText"];
	_histogramText = [missionNamespace getVariable ["WASP_LAB_GROUP_SIZE_HISTOGRAM", []]] Call WASP_LAB_FNC_IndexedText;
	_anchorRequestedText = [missionNamespace getVariable ["WASP_LAB_ANCHOR_REQUESTED", []]] Call WASP_LAB_FNC_IndexedText;
	_anchorMembersText = [missionNamespace getVariable ["WASP_LAB_ANCHOR_MEMBERS", []]] Call WASP_LAB_FNC_IndexedText;
	_routeText = Call WASP_LAB_FNC_RouteText;
	"targetSyntheticUnits=" + str (missionNamespace getVariable ["WASP_LAB_TARGET_SYNTHETIC_UNITS", 0]) +
		"|targetGroups=" + str (missionNamespace getVariable ["WASP_LAB_SYNTHETIC_GROUPS", 0]) +
		"|spawnAnchors=" + str (missionNamespace getVariable ["WASP_LAB_SPAWN_ANCHORS", 0]) +
		"|settleSec=" + str (missionNamespace getVariable ["WASP_LAB_SETTLE_SEC", 0]) +
		"|realizedGroups=" + str (missionNamespace getVariable ["WASP_LAB_REALIZED_GROUPS", 0]) +
		"|requestedInfantry=" + str (missionNamespace getVariable ["WASP_LAB_REQUESTED_INFANTRY", 0]) +
		"|createdInfantry=" + str (missionNamespace getVariable ["WASP_LAB_CREATED_INFANTRY", 0]) +
		"|crew=" + str (missionNamespace getVariable ["WASP_LAB_CREATED_CREW", 0]) +
		"|createdVehicles=" + str (missionNamespace getVariable ["WASP_LAB_CREATED_VEHICLES", 0]) +
		"|finalMembers=" + str (missionNamespace getVariable ["WASP_LAB_FINAL_MEMBERS", 0]) +
		"|histogram=" + _histogramText +
		"|underfillGroups=" + str (missionNamespace getVariable ["WASP_LAB_UNDERFILL_GROUPS", 0]) +
		"|oversizeGroups=" + str (missionNamespace getVariable ["WASP_LAB_OVERSIZE_GROUPS", 0]) +
		"|createFailures=" + str (missionNamespace getVariable ["WASP_LAB_CREATE_FAILURES", 0]) +
		"|createFailureGroups=" + str (missionNamespace getVariable ["WASP_LAB_CREATE_FAILURE_GROUPS", 0]) +
		"|anchorRequested=" + _anchorRequestedText + "|anchorMembers=" + _anchorMembersText +
		"|memberSeconds=" + str (round (missionNamespace getVariable ["WASP_LAB_MEMBER_SECONDS", 0])) +
		"|groupSeconds=" + str (round (missionNamespace getVariable ["WASP_LAB_GROUP_SECONDS", 0])) +
		"|pathLegsStarted=" + str (missionNamespace getVariable ["WASP_LAB_PATH_LEGS_STARTED", 0]) + "|routeIds=" + _routeText
};

WASP_LAB_FNC_LogPhase = {
	Private ["_phase","_measureStart","_measureEnd","_measureNow","_measureT"];
	_phase = missionNamespace getVariable ["WASP_LAB_PHASE", "SPAWN"];
	_measureStart = missionNamespace getVariable ["WASP_LAB_MEASURE_START", -1];
	_measureEnd = missionNamespace getVariable ["WASP_LAB_END", -1];
	_measureNow = if (_phase == "CLEANUP" && {_measureEnd >= _measureStart}) then {time min _measureEnd} else {time};
	_measureT = if (_measureStart >= 0) then {round (_measureNow - _measureStart)} else {-1};
	diag_log ("WASPLAB|v1|PHASE|run=" + (missionNamespace getVariable ["WASP_LAB_RUN_ID", "?"]) +
		"|phase=" + _phase + "|phaseSeq=" + str (missionNamespace getVariable ["WASP_LAB_PHASE_SEQ", 0]) +
		"|t=" + str (round (time - (missionNamespace getVariable ["WASP_LAB_START", 0]))) + "|measureT=" + str _measureT +
		"|" + (Call WASP_LAB_FNC_CompositionText));
};

WASP_LAB_FNC_LogComposition = {
	Private ["_phase","_measureStart","_measureT"];
	_phase = missionNamespace getVariable ["WASP_LAB_PHASE", "SPAWN"];
	_measureStart = missionNamespace getVariable ["WASP_LAB_MEASURE_START", -1];
	_measureT = if (_measureStart >= 0) then {round (time - _measureStart)} else {-1};
	diag_log ("WASPLAB|v1|COMPOSITION|run=" + (missionNamespace getVariable ["WASP_LAB_RUN_ID", "?"]) +
		"|phase=" + _phase + "|t=" + str (round (time - (missionNamespace getVariable ["WASP_LAB_START", 0]))) +
		"|measureT=" + str _measureT + "|" + (Call WASP_LAB_FNC_CompositionText));
};

WASP_LAB_FNC_RecordRoute = {
	Private ["_routeId","_routes"];
	_routeId = _this select 0;
	_routes = missionNamespace getVariable ["WASP_LAB_ROUTE_IDS", []];
	if (_routeId != "" && {_routeId != "none"} && {!(_routeId in _routes)}) then {
		_routes set [count _routes, _routeId];
		missionNamespace setVariable ["WASP_LAB_ROUTE_IDS", _routes];
	};
	missionNamespace setVariable ["WASP_LAB_PATH_LEGS_STARTED", (missionNamespace getVariable ["WASP_LAB_PATH_LEGS_STARTED", 0]) + 1];
};

WASP_LAB_FNC_AccumulateExposure = {
	Private ["_last","_now","_delta","_activeGroups","_activeMembers","_group"];
	if ((missionNamespace getVariable ["WASP_LAB_PHASE", "SPAWN"]) != "MEASURE") exitWith {};
	_last = missionNamespace getVariable ["WASP_LAB_EXPOSURE_LAST", -1];
	_now = time min (missionNamespace getVariable ["WASP_LAB_END", time]);
	_delta = (_now - _last) max 0;
	if (_last >= 0) then {
		_activeGroups = 0;
		_activeMembers = 0;
		{
			_group = _x;
			if (!isNull _group && {count units _group > 0}) then {
				_activeGroups = _activeGroups + 1;
				_activeMembers = _activeMembers + count units _group;
			};
		} forEach (missionNamespace getVariable ["WASP_LAB_TRACKED_GROUPS", []]);
		missionNamespace setVariable ["WASP_LAB_MEMBER_SECONDS", (missionNamespace getVariable ["WASP_LAB_MEMBER_SECONDS", 0]) + (_activeMembers * _delta)];
		missionNamespace setVariable ["WASP_LAB_GROUP_SECONDS", (missionNamespace getVariable ["WASP_LAB_GROUP_SECONDS", 0]) + (_activeGroups * _delta)];
	};
	missionNamespace setVariable ["WASP_LAB_EXPOSURE_LAST", _now];
};

WASP_LAB_FNC_ResetMeasure = {
	missionNamespace setVariable ["WASP_LAB_PATH_ARRIVALS", 0];
	missionNamespace setVariable ["WASP_LAB_PATH_LEGS_STARTED", 0];
	missionNamespace setVariable ["WASP_LAB_ROUTE_IDS", []];
	missionNamespace setVariable ["WASP_LAB_FPS_N", 0];
	missionNamespace setVariable ["WASP_LAB_FPS_SUM", 0];
	missionNamespace setVariable ["WASP_LAB_FPS_MIN", 1000];
	missionNamespace setVariable ["WASP_LAB_AI_PEAK", 0];
	missionNamespace setVariable ["WASP_LAB_GROUPS_PEAK", 0];
	missionNamespace setVariable ["WASP_LAB_HCPCT_MIN", 100];
	missionNamespace setVariable ["WASP_LAB_HCPCT_N", 0];
	missionNamespace setVariable ["WASP_LAB_STUCK_MAX", 0];
	missionNamespace setVariable ["WASP_LAB_STUCK_PCT_MAX", 0];
	missionNamespace setVariable ["WASP_LAB_TRACKED_PEAK", 0];
	missionNamespace setVariable ["WASP_LAB_HCS_MIN", 99];
	missionNamespace setVariable ["WASP_LAB_HC_BALANCE_N", 0];
	missionNamespace setVariable ["WASP_LAB_HC_IMBALANCED_N", 0];
	missionNamespace setVariable ["WASP_LAB_HC_IMBALANCE_MAX", 0];
	missionNamespace setVariable ["WASP_LAB_HC_IMBALANCE_LAST", -1];
	missionNamespace setVariable ["WASP_LAB_HC_GROUP_IMBALANCE_LAST", -1];
	missionNamespace setVariable ["WASP_LAB_HC_FPS_MIN", 1000];
	missionNamespace setVariable ["WASP_LAB_HC_FPS_N", 0];
	missionNamespace setVariable ["WASP_LAB_BUS_ATTEMPT_POST", 0];
	missionNamespace setVariable ["WASP_LAB_BUS_SENT_POST", 0];
	missionNamespace setVariable ["WASP_LAB_BUS_ACK_POST", 0];
	missionNamespace setVariable ["WASP_LAB_BUS_DROP_TOTAL", 0];
	missionNamespace setVariable ["WASP_LAB_BUS_ACK_DUP", 0];
	// Keep authenticated pre-GO requests until their late acknowledgements drain. Their
	// stored postWarmup=false token prevents them from entering measurement counters.
	missionNamespace setVariable ["WASP_LAB_BUS_ACK_ENDPOINTS", []];
	missionNamespace setVariable ["WASP_LAB_BUS_LAT_SUM_POST", 0];
	missionNamespace setVariable ["WASP_LAB_BUS_LAT_MAX_POST", 0];
	missionNamespace setVariable ["WASP_LAB_MEMBER_SECONDS", 0];
	missionNamespace setVariable ["WASP_LAB_GROUP_SECONDS", 0];
	missionNamespace setVariable ["WASP_LAB_EXPOSURE_LAST", time];
};

if (_partitionMode) then {Call WASP_LAB_FNC_LogPhase};

WASP_LAB_FNC_ShadowStep = {
	Private ["_state","_steps","_cursor","_stepDelay","_cycleDelay","_repeat","_delay","_keep"];
	_state = _this select 0;
	_steps = _state select 0;
	_cursor = (_state select 1) + 1;
	_stepDelay = _state select 2;
	_cycleDelay = _state select 3;
	_repeat = _state select 4;
	_delay = _stepDelay;
	_keep = true;
	if (_cursor >= _steps) then {
		if (_repeat) then {_cursor = 0; _delay = _cycleDelay} else {_keep = false};
	};
	[true, [_steps, _cursor, _stepDelay, _cycleDelay, _repeat], _delay, _keep, ""]
};

WASP_LAB_FNC_HCOwners = {
	Private ["_owners","_registry","_group","_unit","_id"];
	_owners = [];
	_registry = missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []];
	{
		_group = _x;
		if (!isNull _group && {!isNull leader _group} && {alive leader _group}) then {
			_unit = leader _group;
			_id = owner _unit;
			if (_id > 2 && {!(_id in _owners)}) then {_owners set [count _owners, _id]};
		};
	} forEach _registry;
	_owners
};

WASP_LAB_FNC_AssignLeg = {
	Private ["_group","_townIndex","_town","_target","_name","_labTowns","_fromTown","_fromName","_routeId","_phase","_partitionModeNow","_groupId","_transition","_eventAt"];
	_group = _this select 0;
	_townIndex = _this select 1;
	_eventAt = if (count _this > 2) then {_this select 2} else {-1};
	_labTowns = missionNamespace getVariable ["WASP_LAB_TOWNS", []];
	_partitionModeNow = missionNamespace getVariable ["WASP_LAB_PARTITION_MODE", false];
	_phase = if (_partitionModeNow) then {missionNamespace getVariable ["WASP_LAB_PHASE", "SPAWN"]} else {"MEASURE"};
	if (isNull _group || {count _labTowns < 1}) exitWith {};
	if (_partitionModeNow && {_phase != "GO"} && {_phase != "MEASURE"}) exitWith {};
	_townIndex = _townIndex mod (count _labTowns);
	_town = _labTowns select _townIndex;
	_fromTown = _labTowns select ((_townIndex - 1 + count _labTowns) mod (count _labTowns));
	_target = getPos _town;
	_name = _town getVariable ["name", str _townIndex];
	_fromName = _fromTown getVariable ["name", str (_townIndex - 1)];
	_routeId = if (_partitionModeNow) then {_fromName + ">" + _name} else {""};
	_group setVariable ["wasp_lab_route_idx", _townIndex];
	_group setVariable ["wasp_lab_target", _target];
	_group setVariable ["wasp_lab_from_name", _fromName];
	_group setVariable ["wasp_lab_target_name", _name];
	if (_partitionModeNow) then {_group setVariable ["wasp_lab_route_id", _routeId]};
	if (_eventAt < 0) then {_eventAt = time};
	_group setVariable ["wasp_lab_leg_start", _eventAt];
	_group setVariable ["wasp_lab_last_move_t", time];
	if (!isNull leader _group) then {_group setVariable ["wasp_lab_last_pos", getPos leader _group]};
	if (_partitionModeNow) then {
		_groupId = _group getVariable "wasp_lab_group_id";
		if (isNil "_groupId") then {_groupId = -1};
		_transition = _group getVariable "wasp_lab_transition";
		if (isNil "_transition") then {_transition = 0};
		_transition = _transition + 1;
		_group setVariable ["wasp_lab_transition", _transition];
		_group setVariable ["wasp_lab_active_transition", _transition];
		[_routeId] Call WASP_LAB_FNC_RecordRoute;
		diag_log ("WASPLAB|v1|PATHLEG|run=" + (missionNamespace getVariable ["WASP_LAB_RUN_ID", "?"]) +
			"|t=" + str (round (_eventAt - (missionNamespace getVariable ["WASP_LAB_START", 0]))) +
			"|measureT=" + str (round (_eventAt - (missionNamespace getVariable ["WASP_LAB_MEASURE_START", _eventAt]))) +
			"|group=" + str _groupId + "|transition=" + str _transition +
			"|leg=" + str (_townIndex + 1) + "|routeId=" + _routeId + "|from=" + _fromName + "|to=" + _name +
			"|units=" + str (count units _group) + "|arrived=0|stuck=0|elapsed=0|status=STARTED");
	};
	[_group, _target, "MOVE", 35] Call WFBE_CO_FNC_WaypointSimple;
};

// One bounded route continuation. Active mode runs one group per scheduler job;
// control mode invokes the same step for every group, then sleeps five seconds.
WASP_LAB_FNC_PathStep = {
	Private ["_cursor","_groups","_group","_leader","_target","_lastPos","_lastMove","_idx","_from","_to",
		"_legStart","_elapsed","_nextDelay","_labTowns","_partitionModeNow","_groupId","_transition","_pathInflight","_arrivalAt","_arrivalInWindow"];
	_cursor = _this select 0;
	_partitionModeNow = missionNamespace getVariable ["WASP_LAB_PARTITION_MODE", false];
	if (_partitionModeNow) then {
		_pathInflight = (missionNamespace getVariable ["WASP_LAB_PATH_INFLIGHT", 0]) + 1;
		missionNamespace setVariable ["WASP_LAB_PATH_INFLIGHT", _pathInflight];
	};
	if (_partitionModeNow && {
		(missionNamespace getVariable ["WASP_LAB_MEASURE_CLOSING", false]) ||
		{missionNamespace getVariable ["WASP_LAB_STOP", false]} ||
		{(missionNamespace getVariable ["WASP_LAB_PHASE", "SPAWN"]) != "MEASURE"}
	}) exitWith {
		missionNamespace setVariable ["WASP_LAB_PATH_INFLIGHT", ((missionNamespace getVariable ["WASP_LAB_PATH_INFLIGHT", 1]) - 1) max 0];
		[true, _cursor, 1, true, ""]
	};
	_groups = missionNamespace getVariable ["WASP_LAB_TRACKED_GROUPS", []];
	if (count _groups < 1) exitWith {
		if (_partitionModeNow) then {missionNamespace setVariable ["WASP_LAB_PATH_INFLIGHT", ((missionNamespace getVariable ["WASP_LAB_PATH_INFLIGHT", 1]) - 1) max 0]};
		[true, 0, 1, true, ""]
	};
	if (_cursor >= count _groups) then {_cursor = 0};
	_group = _groups select _cursor;
	_labTowns = missionNamespace getVariable ["WASP_LAB_TOWNS", []];
	if (!isNull _group && {count units _group > 0}) then {
		_leader = leader _group;
		if (!isNull _leader && {alive _leader}) then {
			_target = _group getVariable "wasp_lab_target";
			if (isNil "_target") then {_target = []};
			_lastPos = _group getVariable "wasp_lab_last_pos";
			if (isNil "_lastPos") then {_lastPos = getPos _leader};
			_lastMove = _group getVariable "wasp_lab_last_move_t";
			if (isNil "_lastMove") then {_lastMove = time};
			if ((_leader distance _lastPos) > 10) then {
				_group setVariable ["wasp_lab_last_pos", getPos _leader];
				_group setVariable ["wasp_lab_last_move_t", time];
			};
			if (typeName _target == "ARRAY" && {count _target > 1} && {_leader distance _target < 100}) then {
				_arrivalAt = if (_partitionModeNow) then {time} else {-1};
				_arrivalInWindow = !_partitionModeNow || {
					!(missionNamespace getVariable ["WASP_LAB_MEASURE_CLOSING", false]) &&
					{_arrivalAt <= (missionNamespace getVariable ["WASP_LAB_END", _arrivalAt])} &&
					{(missionNamespace getVariable ["WASP_LAB_PHASE", "SPAWN"]) == "MEASURE"}
				};
				if (_arrivalInWindow) then {
					_idx = _group getVariable "wasp_lab_route_idx";
					if (isNil "_idx") then {_idx = 0};
					_from = _group getVariable "wasp_lab_from_name";
					if (isNil "_from") then {_from = str _idx};
					_to = _group getVariable "wasp_lab_target_name";
					if (isNil "_to") then {_to = str _idx};
					_legStart = _group getVariable "wasp_lab_leg_start";
					if (!_partitionModeNow) then {_arrivalAt = time};
					if (isNil "_legStart") then {_legStart = _arrivalAt};
					_elapsed = round (_arrivalAt - _legStart);
					if (_partitionModeNow) then {
						_groupId = _group getVariable "wasp_lab_group_id";
						if (isNil "_groupId") then {_groupId = -1};
						_transition = _group getVariable "wasp_lab_active_transition";
						if (isNil "_transition") then {_transition = -1};
					};
					missionNamespace setVariable ["WASP_LAB_PATH_ARRIVALS", (missionNamespace getVariable ["WASP_LAB_PATH_ARRIVALS", 0]) + 1];
					diag_log ("WASPLAB|v1|PATHLEG|run=" + (missionNamespace getVariable ["WASP_LAB_RUN_ID", "?"]) +
						"|t=" + str (round ((if (_partitionModeNow) then {_arrivalAt} else {time}) - (missionNamespace getVariable ["WASP_LAB_START", 0]))) +
						(if (_partitionModeNow) then {"|measureT=" + str (round (_arrivalAt - (missionNamespace getVariable ["WASP_LAB_MEASURE_START", _arrivalAt])))} else {""}) +
						(if (_partitionModeNow) then {"|group=" + str _groupId + "|transition=" + str _transition} else {""}) +
						"|leg=" + str (_idx + 1) + (if (_partitionModeNow) then {"|routeId=" + _from + ">" + _to} else {""}) + "|from=" + _from + "|to=" + _to +
						"|units=" + str (count units _group) + "|arrived=1|stuck=0|elapsed=" + str _elapsed + "|status=ARRIVED");
					if (_partitionModeNow) then {
						[_group, _idx + 1, _arrivalAt] Call WASP_LAB_FNC_AssignLeg;
					} else {
						[_group, _idx + 1] Call WASP_LAB_FNC_AssignLeg;
					};
				};
			};
		};
	};
	_cursor = _cursor + 1;
	_nextDelay = if (_cursor >= count _groups) then {5} else {0.01};
	if (_partitionModeNow) then {missionNamespace setVariable ["WASP_LAB_PATH_INFLIGHT", ((missionNamespace getVariable ["WASP_LAB_PATH_INFLIGHT", 1]) - 1) max 0]};
	[true, _cursor, _nextDelay, true, ""]
};

if (_mode == "path-loop" && {_schedulerMode == "active"}) then {
	["lab-path-driver", 1, 1, 5, 1, WASP_LAB_FNC_PathStep, 0] Call WASP_SCHED_FNC_Register;
};
if (_mode == "path-loop" && {_schedulerMode == "shadow"}) then {
	["shadow-path-driver", 1, 1, 5, 0.5, WASP_LAB_FNC_ShadowStep, [_totalGroups max 1, 0, 0.01, 5, true]] Call WASP_SCHED_FNC_Register;
};

if (_mode == "path-loop" && {_schedulerMode != "active"}) then {
	[] Spawn {
		Private ["_groups","_cursor","_result","_i"];
		while {!(missionNamespace getVariable ["WASP_LAB_STOP", false])} do {
			_groups = missionNamespace getVariable ["WASP_LAB_TRACKED_GROUPS", []];
			_cursor = 0;
			for "_i" from 1 to (count _groups) do {
				_result = [_cursor, diag_tickTime] Call WASP_LAB_FNC_PathStep;
				_cursor = _result select 1;
			};
			sleep 5;
		};
	};
};

// One bounded group creation. The engine call itself cannot be pre-empted, but active mode will not
// launch the rest of a burst in the same scheduler pass after this job consumes the frame budget.
WASP_LAB_FNC_SpawnOne = {
	Private ["_made","_unitN","_vehEvery","_spawnMode","_side","_startIdx","_targetIdx","_startTown",
		"_targetTown","_pos","_soldier","_trucks","_roster","_i","_group","_ret","_units",
		"_vehiclesCreated","_crewsCreated","_tracked","_objects","_success","_labTowns",
		"_spawnDir","_spawnRing","_anchorCount","_anchorIdx","_requestedVehicles","_createdInfantry",
		"_createdCrew","_createdVehicles","_finalMembers","_underfill","_oversize","_createFailures",
		"_createFailure","_routeId","_startName","_targetName","_histogram","_anchorRequested","_anchorMembers","_anchorSlot","_partitionModeNow"];
	_made = _this select 0;
	_unitN = _this select 1;
	_vehEvery = _this select 2;
	_spawnMode = _this select 3;
	_success = false;
	_labTowns = missionNamespace getVariable ["WASP_LAB_TOWNS", []];
	_anchorCount = missionNamespace getVariable ["WASP_LAB_SPAWN_ANCHORS", 0];
	_partitionModeNow = missionNamespace getVariable ["WASP_LAB_PARTITION_MODE", false];
	_anchorIdx = -1;
	_side = if (_spawnMode == "path-loop") then {west} else {
		if (_anchorCount > 0) then {if (((floor (_made / _anchorCount)) mod 2) == 0) then {west} else {east}} else {if ((_made mod 2) == 0) then {west} else {east}}
	};
	_startIdx = _made mod (count _labTowns);
	if (_anchorCount > 0) then {
		_anchorIdx = _made mod _anchorCount;
		_startIdx = _anchorIdx mod (count _labTowns);
	};
	_targetIdx = (_startIdx + 1) mod (count _labTowns);
	if (_spawnMode == "combat") then {
		_startIdx = if (_side == west) then {0} else {(count _labTowns) - 1};
		_targetIdx = floor ((count _labTowns) / 2);
	};
	_startTown = _labTowns select _startIdx;
	_targetTown = _labTowns select _targetIdx;
	_anchorSlot = if (_anchorIdx >= 0) then {floor (_made / _anchorCount)} else {-1};
	_spawnDir = if (_anchorIdx >= 0) then {(_anchorSlot mod 8) * 45} else {(_made mod 8) * 45};
	_spawnRing = if (_anchorIdx >= 0) then {20 + ((floor (_anchorSlot / 8)) * 15)} else {30 + ((floor (_made / 8)) * 15)};
	_pos = [(getPos _startTown select 0) + ((sin _spawnDir) * _spawnRing), (getPos _startTown select 1) + ((cos _spawnDir) * _spawnRing), 0];
	_startName = "";
	_targetName = "";
	_routeId = "none";
	if (_partitionModeNow) then {
		_startName = _startTown getVariable ["name", str _startIdx];
		_targetName = _targetTown getVariable ["name", str _targetIdx];
		_routeId = if (_spawnMode == "path-loop") then {_startName + ">" + _targetName} else {if (_spawnMode == "combat") then {_startName + ">" + _targetName + ":SAD"} else {"none"}};
	};
	_soldier = missionNamespace getVariable [Format ["WFBE_%1SOLDIER", _side], if (_side == west) then {"USMC_Soldier"} else {"RU_Soldier"}];
	_roster = [];
	for "_i" from 1 to _unitN do {_roster set [count _roster, _soldier]};
	_requestedVehicles = 0;
	if (_vehEvery > 0 && {((_made + 1) mod _vehEvery) == 0}) then {
		_trucks = missionNamespace getVariable [Format ["WFBE_%1SUPPLYTRUCKS", str _side], []];
		if (count _trucks > 0) then {_roster set [count _roster, _trucks select 0]; _requestedVehicles = 1};
	};
	_units = [];
	_vehiclesCreated = [];
	_crewsCreated = [];
	_group = [_side, "wasp-lab"] Call WFBE_CO_FNC_CreateGroup;
	if (!isNull _group) then {
		_ret = [_roster, _pos, _side, true, _group, true] Call WFBE_CO_FNC_CreateTeam;
		_units = _ret select 0;
		_vehiclesCreated = _ret select 1;
		_group = _ret select 2;
		_crewsCreated = _ret select 3;
		if (!isNull _group && {(count _units + count _crewsCreated) > 0}) then {
			_group setVariable ["wasp_lab_group", true, true];
			_group setVariable ["wasp_lab_spawn_t", time];
			_tracked = missionNamespace getVariable ["WASP_LAB_TRACKED_GROUPS", []];
			_tracked set [count _tracked, _group];
			missionNamespace setVariable ["WASP_LAB_TRACKED_GROUPS", _tracked];
			_objects = missionNamespace getVariable ["WASP_LAB_TRACKED_OBJECTS", []];
			{_objects set [count _objects, _x]} forEach (_units + _crewsCreated + _vehiclesCreated);
			missionNamespace setVariable ["WASP_LAB_TRACKED_OBJECTS", _objects];
			if (_partitionModeNow) then {
				_group setVariable ["wasp_lab_anchor", _anchorIdx];
				_group setVariable ["wasp_lab_route_id", _routeId];
				_group setVariable ["wasp_lab_group_id", _made + 1];
				_group setVariable ["wasp_lab_transition", 0];
			};
			if (_spawnMode == "path-loop") then {
				if (_partitionModeNow) then {_group setVariable ["wasp_lab_initial_target_idx", _targetIdx]} else {[_group, _targetIdx] Call WASP_LAB_FNC_AssignLeg};
			};
			if (_spawnMode == "combat") then {
				_group setVariable ["wasp_lab_target", getPos _targetTown];
				if (_partitionModeNow) then {
					_group setVariable ["wasp_lab_from_name", _startName];
					_group setVariable ["wasp_lab_target_name", _targetName];
				} else {
					if (!isNull leader _group) then {_group setVariable ["wasp_lab_last_pos", getPos leader _group]};
					_group setVariable ["wasp_lab_last_move_t", time];
					[_group, getPos _targetTown, "SAD", 50] Call WFBE_CO_FNC_WaypointSimple;
					missionNamespace setVariable ["WASP_LAB_COMBAT_INITIAL_UNITS", (missionNamespace getVariable ["WASP_LAB_COMBAT_INITIAL_UNITS", 0]) + count _units + count _crewsCreated];
				};
			};
			_success = true;
			missionNamespace setVariable ["WASP_LAB_SPAWNED_TOTAL", (missionNamespace getVariable ["WASP_LAB_SPAWNED_TOTAL", 0]) + 1];
		} else {
			diag_log ("WASPLAB|v1|SPAWN_FAIL|run=" + (missionNamespace getVariable ["WASP_LAB_RUN_ID", "?"]) + "|reason=createTeam");
		};
	} else {
		diag_log ("WASPLAB|v1|SPAWN_FAIL|run=" + (missionNamespace getVariable ["WASP_LAB_RUN_ID", "?"]) + "|reason=grpNull");
	};
	if (_partitionModeNow) then {
	_createdInfantry = count _units;
	_createdCrew = count _crewsCreated;
	_createdVehicles = count _vehiclesCreated;
	_finalMembers = if (!isNull _group) then {count units _group} else {0};
	_underfill = if (_createdInfantry < _unitN) then {1} else {0};
	_oversize = if (_finalMembers > 12) then {1} else {0};
	_createFailures = ((_unitN - _createdInfantry) max 0) + ((_requestedVehicles - _createdVehicles) max 0);
	_createFailure = if (_createFailures > 0 || {!(_success)}) then {1} else {0};
	missionNamespace setVariable ["WASP_LAB_REQUESTED_INFANTRY", (missionNamespace getVariable ["WASP_LAB_REQUESTED_INFANTRY", 0]) + _unitN];
	missionNamespace setVariable ["WASP_LAB_CREATED_INFANTRY", (missionNamespace getVariable ["WASP_LAB_CREATED_INFANTRY", 0]) + _createdInfantry];
	missionNamespace setVariable ["WASP_LAB_CREATED_CREW", (missionNamespace getVariable ["WASP_LAB_CREATED_CREW", 0]) + _createdCrew];
	missionNamespace setVariable ["WASP_LAB_CREATED_VEHICLES", (missionNamespace getVariable ["WASP_LAB_CREATED_VEHICLES", 0]) + _createdVehicles];
	missionNamespace setVariable ["WASP_LAB_FINAL_MEMBERS", (missionNamespace getVariable ["WASP_LAB_FINAL_MEMBERS", 0]) + _finalMembers];
	missionNamespace setVariable ["WASP_LAB_UNDERFILL_GROUPS", (missionNamespace getVariable ["WASP_LAB_UNDERFILL_GROUPS", 0]) + _underfill];
	missionNamespace setVariable ["WASP_LAB_OVERSIZE_GROUPS", (missionNamespace getVariable ["WASP_LAB_OVERSIZE_GROUPS", 0]) + _oversize];
	missionNamespace setVariable ["WASP_LAB_CREATE_FAILURES", (missionNamespace getVariable ["WASP_LAB_CREATE_FAILURES", 0]) + _createFailures];
	missionNamespace setVariable ["WASP_LAB_CREATE_FAILURE_GROUPS", (missionNamespace getVariable ["WASP_LAB_CREATE_FAILURE_GROUPS", 0]) + _createFailure];
	if (_success) then {
		missionNamespace setVariable ["WASP_LAB_REALIZED_GROUPS", (missionNamespace getVariable ["WASP_LAB_REALIZED_GROUPS", 0]) + 1];
		_histogram = missionNamespace getVariable ["WASP_LAB_GROUP_SIZE_HISTOGRAM", []];
		while {count _histogram <= _finalMembers} do {_histogram set [count _histogram, 0]};
		_histogram set [_finalMembers, (_histogram select _finalMembers) + 1];
		missionNamespace setVariable ["WASP_LAB_GROUP_SIZE_HISTOGRAM", _histogram];
	};
	if (_anchorIdx >= 0) then {
		_anchorRequested = missionNamespace getVariable ["WASP_LAB_ANCHOR_REQUESTED", []];
		_anchorMembers = missionNamespace getVariable ["WASP_LAB_ANCHOR_MEMBERS", []];
		while {count _anchorRequested <= _anchorIdx} do {_anchorRequested set [count _anchorRequested, 0]};
		while {count _anchorMembers <= _anchorIdx} do {_anchorMembers set [count _anchorMembers, 0]};
		_anchorRequested set [_anchorIdx, (_anchorRequested select _anchorIdx) + _unitN];
		_anchorMembers set [_anchorIdx, (_anchorMembers select _anchorIdx) + _finalMembers];
		missionNamespace setVariable ["WASP_LAB_ANCHOR_REQUESTED", _anchorRequested];
		missionNamespace setVariable ["WASP_LAB_ANCHOR_MEMBERS", _anchorMembers];
	};
	diag_log ("WASPLAB|v1|REALIZED|run=" + (missionNamespace getVariable ["WASP_LAB_RUN_ID", "?"]) +
		"|group=" + str (_made + 1) + "|anchor=" + str _anchorIdx + "|side=" + str _side + "|routeId=" + _routeId +
		"|requestedInfantry=" + str _unitN + "|createdInfantry=" + str _createdInfantry + "|crew=" + str _createdCrew +
		"|vehicles=" + str _createdVehicles + "|finalMembers=" + str _finalMembers + "|underfill=" + str _underfill +
		"|oversize=" + str _oversize + "|createFailures=" + str _createFailures + "|createFailure=" + str _createFailure);
	};
	if !(_success) then {
		{if (!isNull _x) then {deleteVehicle _x}} forEach (_units + _crewsCreated + _vehiclesCreated);
		if (!isNull _group) then {deleteGroup _group};
	};
	_success
};

WASP_LAB_FNC_StartOrders = {
	Private ["_modeNow","_groups","_group","_targetIdx","_target","_routeId","_leader"];
	_modeNow = missionNamespace getVariable ["WASP_LAB_SYNTHETIC_MODE", "none"];
	_groups = missionNamespace getVariable ["WASP_LAB_TRACKED_GROUPS", []];
	{
		_group = _x;
		if (!isNull _group && {count units _group > 0}) then {
			if (_modeNow == "path-loop") then {
				_targetIdx = _group getVariable "wasp_lab_initial_target_idx";
				if (isNil "_targetIdx") then {_targetIdx = 0};
				[_group, _targetIdx] Call WASP_LAB_FNC_AssignLeg;
			};
			if (_modeNow == "combat") then {
				_target = _group getVariable "wasp_lab_target";
				if (isNil "_target") then {_target = []};
				_routeId = _group getVariable "wasp_lab_route_id";
				if (isNil "_routeId") then {_routeId = "combat"};
				_leader = leader _group;
				if (!isNull _leader) then {_group setVariable ["wasp_lab_last_pos", getPos _leader]};
				_group setVariable ["wasp_lab_last_move_t", time];
				if (typeName _target == "ARRAY" && {count _target > 1}) then {
					[_routeId] Call WASP_LAB_FNC_RecordRoute;
					[_group, _target, "SAD", 50] Call WFBE_CO_FNC_WaypointSimple;
				};
			};
		};
	} forEach _groups;
	missionNamespace setVariable ["WASP_LAB_COMBAT_INITIAL_UNITS", if (_modeNow == "combat") then {
		{!(isNull _x) && {_x isKindOf "Man"} && {alive _x}} count (missionNamespace getVariable ["WASP_LAB_TRACKED_OBJECTS", []])
	} else {0}];
};

WASP_LAB_FNC_LogBatch = {
	Private ["_batch","_total","_delta"];
	_batch = _this select 0;
	_total = _this select 1;
	_delta = _this select 2;
	diag_log ("WASPLAB|v1|BATCH|run=" + (missionNamespace getVariable ["WASP_LAB_RUN_ID", "?"]) +
		"|t=" + str (round (time - (missionNamespace getVariable ["WASP_LAB_START", 0]))) +
		"|batch=" + str _batch + "|spawnedTotal=" + str _total + "|spawnedDelta=" + str _delta +
		"|ai=" + str ({!(isPlayer _x)} count allUnits) + "|groups=" + str (count allGroups));
};

WASP_LAB_FNC_SpawnScheduledStep = {
	Private ["_state","_targetTotal","_unitN","_batchN","_interval","_vehEvery","_spawnMode","_made",
		"_batchMade","_batch","_success","_delay","_keep","_partitionModeNow"];
	_state = _this select 0;
	_targetTotal = _state select 0;
	_unitN = _state select 1;
	_batchN = _state select 2;
	_interval = _state select 3;
	_vehEvery = _state select 4;
	_spawnMode = _state select 5;
	_made = _state select 6;
	_batchMade = _state select 7;
	_batch = _state select 8;
	_partitionModeNow = missionNamespace getVariable ["WASP_LAB_PARTITION_MODE", false];
	_success = [_made, _unitN, _vehEvery, _spawnMode] Call WASP_LAB_FNC_SpawnOne;
	if (_success) then {_made = _made + 1; _batchMade = _batchMade + 1} else {if (_partitionModeNow) then {_made = _made + 1}};
	if ((_partitionModeNow && {(_made mod _batchN) == 0 || {_made >= _targetTotal}}) || {!(_partitionModeNow) && {_batchMade >= _batchN || {_made >= _targetTotal}}}) then {
		_batch = _batch + 1;
		[_batch, if (_partitionModeNow) then {missionNamespace getVariable ["WASP_LAB_SPAWNED_TOTAL", 0]} else {_made}, _batchMade] Call WASP_LAB_FNC_LogBatch;
		_batchMade = 0;
	};
	// Spread the old burst evenly over its batch interval while preserving average creation rate.
	_delay = _interval / _batchN;
	_keep = _made < _targetTotal;
	if (_partitionModeNow && {!(_keep)}) then {missionNamespace setVariable ["WASP_LAB_SPAWN_DONE", true]};
	[true, [_targetTotal, _unitN, _batchN, _interval, _vehEvery, _spawnMode, _made, _batchMade, _batch], _delay, _keep, ""]
};

if (_totalGroups > 0 && {_townCount > 0} && {_schedulerMode == "active"}) then {
	["lab-group-ramp", 2, 1, _batchInterval / _batchGroups, 2, WASP_LAB_FNC_SpawnScheduledStep,
		[_totalGroups, _unitsPerGroup, _batchGroups, _batchInterval, _vehicleEvery, _mode, 0, 0, 0]] Call WASP_SCHED_FNC_Register;
};
if (_totalGroups > 0 && {_townCount > 0} && {_schedulerMode == "shadow"}) then {
	["shadow-group-ramp", 2, 1, _batchInterval / _batchGroups, 0.5, WASP_LAB_FNC_ShadowStep,
		[_totalGroups, 0, _batchInterval / _batchGroups, _batchInterval / _batchGroups, false]] Call WASP_SCHED_FNC_Register;
};

// Control and shadow keep the original burst shape; shadow only measures dispatcher overhead.
if (_totalGroups > 0 && {_townCount > 0} && {_schedulerMode != "active"}) then {
	[_totalGroups, _unitsPerGroup, _batchGroups, _batchInterval, _vehicleEvery, _mode] Spawn {
		Private ["_targetTotal","_unitN","_batchN","_interval","_vehEvery","_spawnMode","_made","_batch","_batchMade","_success","_partitionModeNow"];
		_targetTotal = _this select 0;
		_unitN = _this select 1;
		_batchN = _this select 2;
		_interval = _this select 3;
		_vehEvery = _this select 4;
		_spawnMode = _this select 5;
		_partitionModeNow = missionNamespace getVariable ["WASP_LAB_PARTITION_MODE", false];
		_made = 0;
		_batch = 0;
		while {_made < _targetTotal && {!(missionNamespace getVariable ["WASP_LAB_STOP", false])}} do {
			_batch = _batch + 1;
			_batchMade = 0;
			for "_b" from 1 to _batchN do {
				if (_made < _targetTotal && {!(missionNamespace getVariable ["WASP_LAB_STOP", false])}) then {
					_success = [_made, _unitN, _vehEvery, _spawnMode] Call WASP_LAB_FNC_SpawnOne;
					if (_success) then {_made = _made + 1; _batchMade = _batchMade + 1} else {if (_partitionModeNow) then {_made = _made + 1}};
				};
			};
			[_batch, if (_partitionModeNow) then {missionNamespace getVariable ["WASP_LAB_SPAWNED_TOTAL", 0]} else {_made}, _batchMade] Call WASP_LAB_FNC_LogBatch;
			if (_made < _targetTotal) then {sleep _interval};
		};
		if (_partitionModeNow) then {missionNamespace setVariable ["WASP_LAB_SPAWN_DONE", true]};
	};
};

// One bounded Common_Send round trip. Active mode schedules each send; control keeps the old
// sleep loop. Both deliberately traverse the real wrappers whose compile-per-send cost motivated the lab.
WASP_LAB_FNC_BusStep = {
	Private ["_state","_rate","_seq","_idx","_registry","_targets","_targetOwners","_group","_target","_delay","_ownerId","_postWarmup","_pending","_sentAt"];
	_state = _this select 0;
	_rate = _state select 0;
	_seq = _state select 1;
	_idx = _state select 2;
	_delay = 1 / _rate;
	_registry = missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []];
	_targets = [];
	_targetOwners = [];
	{
		_group = _x;
		if (!isNull _group && {!isNull leader _group} && {alive leader _group} && {owner (leader _group) > 2}) then {
			_ownerId = owner (leader _group);
			if !(_ownerId in _targetOwners) then {
				_targetOwners set [count _targetOwners, _ownerId];
				_targets set [count _targets, leader _group];
			};
		};
	} forEach _registry;
	_postWarmup = if (missionNamespace getVariable ["WASP_LAB_PARTITION_MODE", false]) then {
		(missionNamespace getVariable ["WASP_LAB_PHASE", "SPAWN"]) == "MEASURE"
	} else {
		(time - (missionNamespace getVariable ["WASP_LAB_START", time])) >= (missionNamespace getVariable ["WASP_LAB_WARMUP_SEC", 60])
	};
	if (_postWarmup) then {
		missionNamespace setVariable ["WASP_LAB_BUS_ATTEMPT_POST", (missionNamespace getVariable ["WASP_LAB_BUS_ATTEMPT_POST", 0]) + 1];
	};
	if (count _targets > 0) then {
		_target = _targets select (_idx mod (count _targets));
		_idx = _idx + 1;
		_seq = _seq + 1;
		_ownerId = owner _target;
		_sentAt = time;
		missionNamespace setVariable ["WASP_LAB_BUS_SENT_TOTAL", (missionNamespace getVariable ["WASP_LAB_BUS_SENT_TOTAL", 0]) + 1];
		if (_postWarmup) then {missionNamespace setVariable ["WASP_LAB_BUS_SENT_POST", (missionNamespace getVariable ["WASP_LAB_BUS_SENT_POST", 0]) + 1]};
		_pending = missionNamespace getVariable ["WASP_LAB_BUS_PENDING", []];
		_pending set [count _pending, [_seq, _ownerId, _postWarmup, _sentAt]];
		if (count _pending > 512) then {_pending set [0, -1]; _pending = _pending - [-1]};
		missionNamespace setVariable ["WASP_LAB_BUS_PENDING", _pending];
		[_target, "LabPing", [missionNamespace getVariable ["WASP_LAB_RUN_ID", "?"], _seq, _sentAt, _postWarmup, _ownerId]] Call WFBE_CO_FNC_SendToClient;
	} else {
		if (_postWarmup) then {
			missionNamespace setVariable ["WASP_LAB_BUS_DROP_TOTAL", (missionNamespace getVariable ["WASP_LAB_BUS_DROP_TOTAL", 0]) + 1];
		};
		_delay = 1;
	};
	[true, [_rate, _seq, _idx], _delay, true, ""]
};

if (_busRate > 0 && {_schedulerMode == "active"}) then {
	["lab-common-send", 0, 1, 1 / _busRate, 1, WASP_LAB_FNC_BusStep, [_busRate, 0, 0]] Call WASP_SCHED_FNC_Register;
};
if (_busRate > 0 && {_schedulerMode == "shadow"}) then {
	["shadow-common-send", 0, 1, 1 / _busRate, 0.5, WASP_LAB_FNC_ShadowStep, [1, 0, 1 / _busRate, 1 / _busRate, true]] Call WASP_SCHED_FNC_Register;
};

if (_busRate > 0 && {_schedulerMode != "active"}) then {
	[_busRate] Spawn {
		Private ["_rate","_state","_result"];
		_rate = _this select 0;
		_state = [_rate, 0, 0];
		while {!(missionNamespace getVariable ["WASP_LAB_STOP", false])} do {
			_result = [_state, diag_tickTime] Call WASP_LAB_FNC_BusStep;
			_state = _result select 1;
			sleep (_result select 2);
		};
	};
};

// Truthful, frequent owner-aware sample. The scan cost is reported as probeMs so its observer effect is visible.
[_sampleSec, _warmup, _busRate] Spawn {
	Private ["_interval","_warmupSec","_bus","_sample","_probeStart","_probeMs","_owners","_unit","_id",
		"_ai","_srvAi","_hcAi","_remoteAi","_otherAi","_hcPct","_remotePct","_groups","_vehicles","_tracked",
		"_activeTracked","_stuck","_group","_leader","_target","_lastPos","_lastMove","_fps","_elapsed","_sent","_ack",
		"_drop","_latAvg","_status","_lowN","_collapseN","_lastState","_schedMode","_schedAgeMs","_schedControlAgeMs",
		"_ownerCounts","_ownerGroupCounts","_ownerIdx","_hcMinAi","_hcMaxAi","_hcImbalance","_hcGroups",
		"_hcMinGroups","_hcMaxGroups","_hcGroupImbalance","_ackRows","_ackRow","_hcFresh","_hcFpsNow",
		"_hcEndpoint","_hcFpsValue","_activeMembers","_phaseNow","_measureStartNow","_measureT",
		"_exposureLast","_exposureNow","_partitionModeNow","_isBenchmark","_sampleInflight","_sampleAt"];
	_interval = _this select 0;
	_warmupSec = _this select 1;
	_bus = _this select 2;
	_sample = 0;
	_lowN = 0;
	_collapseN = 0;
	_lastState = "OK";
	while {!(missionNamespace getVariable ["WASP_LAB_STOP", false])} do {
		_probeStart = diag_tickTime;
		_partitionModeNow = missionNamespace getVariable ["WASP_LAB_PARTITION_MODE", false];
		if (_partitionModeNow) then {
			_sampleInflight = (missionNamespace getVariable ["WASP_LAB_SAMPLE_INFLIGHT", 0]) + 1;
			missionNamespace setVariable ["WASP_LAB_SAMPLE_INFLIGHT", _sampleInflight];
		};
		if (_partitionModeNow && {missionNamespace getVariable ["WASP_LAB_MEASURE_CLOSING", false]}) exitWith {
			missionNamespace setVariable ["WASP_LAB_SAMPLE_INFLIGHT", ((missionNamespace getVariable ["WASP_LAB_SAMPLE_INFLIGHT", 1]) - 1) max 0];
		};
		_owners = Call WASP_LAB_FNC_HCOwners;
		_ownerCounts = [];
		_ownerGroupCounts = [];
		{_ownerCounts set [count _ownerCounts, 0]; _ownerGroupCounts set [count _ownerGroupCounts, 0]} forEach _owners;
		_ai = 0; _srvAi = 0; _hcAi = 0; _remoteAi = 0;
		{
			_unit = _x;
			if (!(isPlayer _unit)) then {
				_ai = _ai + 1;
				if (local _unit) then {_srvAi = _srvAi + 1} else {_remoteAi = _remoteAi + 1};
				_id = owner _unit;
				_ownerIdx = _owners find _id;
				if (_ownerIdx >= 0) then {
					_hcAi = _hcAi + 1;
					_ownerCounts set [_ownerIdx, (_ownerCounts select _ownerIdx) + 1];
				};
			};
		} forEach allUnits;
		{
			_group = _x;
			if (!isNull _group && {count units _group > 0} && {!isNull leader _group} && {!(isPlayer leader _group)}) then {
				_ownerIdx = _owners find (owner (leader _group));
				if (_ownerIdx >= 0) then {_ownerGroupCounts set [_ownerIdx, (_ownerGroupCounts select _ownerIdx) + 1]};
			};
		} forEach allGroups;
		_otherAi = (_ai - _srvAi - _hcAi) max 0;
		_hcPct = if (_ai > 0) then {round ((_hcAi / _ai) * 1000) / 10} else {0};
		_remotePct = if (_ai > 0) then {round ((_remoteAi / _ai) * 1000) / 10} else {0};
		_hcMinAi = 0; _hcMaxAi = 0; _hcMinGroups = 0; _hcMaxGroups = 0;
		if (count _ownerCounts > 0) then {
			_hcMinAi = _ownerCounts select 0; _hcMaxAi = _ownerCounts select 0;
			{_hcMinAi = _hcMinAi min _x; _hcMaxAi = _hcMaxAi max _x} forEach _ownerCounts;
			_hcMinGroups = _ownerGroupCounts select 0; _hcMaxGroups = _ownerGroupCounts select 0;
			{_hcMinGroups = _hcMinGroups min _x; _hcMaxGroups = _hcMaxGroups max _x} forEach _ownerGroupCounts;
		};
		_hcGroups = 0; {_hcGroups = _hcGroups + _x} forEach _ownerGroupCounts;
		_hcImbalance = if (count _owners > 1 && {_hcAi > 0}) then {round (((_hcMaxAi - _hcMinAi) / _hcAi) * 1000) / 10} else {-1};
		_hcGroupImbalance = if (count _owners > 1 && {_hcGroups > 0}) then {round (((_hcMaxGroups - _hcMinGroups) / _hcGroups) * 1000) / 10} else {-1};
		_ackRows = missionNamespace getVariable ["WASP_LAB_BUS_ACK_ENDPOINTS", []];
		_hcFresh = 0;
		_hcFpsNow = 1000;
		{
			_ackRow = _x;
			if (typeName _ackRow == "ARRAY" && {count _ackRow >= 4}) then {
				_hcEndpoint = _ackRow select 0;
				_hcFpsValue = _ackRow select 3;
				if (typeName _hcEndpoint == "SCALAR" && {typeName (_ackRow select 1) == "SCALAR"} &&
					{typeName (_ackRow select 2) == "SCALAR"} && {typeName _hcFpsValue == "SCALAR"} &&
					{(_owners find _hcEndpoint) >= 0} && {(_ackRow select 1) >= 4} &&
					{(diag_tickTime - (_ackRow select 2)) <= 10} && {_hcFpsValue >= 0}) then {
					_hcFresh = _hcFresh + 1;
					_hcFpsNow = _hcFpsNow min _hcFpsValue;
				};
			};
		} forEach _ackRows;
		if (_hcFresh < 1) then {_hcFpsNow = -1};
		_groups = count allGroups;
		_vehicles = count vehicles;
		_tracked = missionNamespace getVariable ["WASP_LAB_TRACKED_GROUPS", []];
		_activeTracked = 0;
		_activeMembers = 0;
		_stuck = 0;
		{
			_group = _x;
			if (!isNull _group && {count units _group > 0}) then {
				_activeTracked = _activeTracked + 1;
				if (_partitionModeNow) then {_activeMembers = _activeMembers + count units _group};
				_leader = leader _group;
				_target = _group getVariable "wasp_lab_target";
				if (isNil "_target") then {_target = []};
				_lastPos = _group getVariable "wasp_lab_last_pos";
				if (isNil "_lastPos") then {_lastPos = getPos _leader};
				_lastMove = _group getVariable "wasp_lab_last_move_t";
				if (isNil "_lastMove") then {_lastMove = time};
				if (!isNull _leader && {alive _leader} && {_leader distance _lastPos > 10}) then {
					_group setVariable ["wasp_lab_last_pos", getPos _leader];
					_group setVariable ["wasp_lab_last_move_t", time];
					if ((missionNamespace getVariable ["WASP_LAB_SYNTHETIC_MODE", "none"]) == "combat") then {_group setVariable ["wasp_lab_moved", true]};
					_lastMove = time;
				};
				if ((missionNamespace getVariable ["WASP_LAB_SYNTHETIC_MODE", "none"]) == "path-loop" && {!isNull _leader} && {alive _leader} && {typeName _target == "ARRAY"} && {count _target > 1} &&
					{_leader distance _target > 100} && {(time - _lastMove) > 60}) then {_stuck = _stuck + 1};
			};
		} forEach _tracked;
		_sampleAt = if (_partitionModeNow) then {time} else {-1};
		if (_partitionModeNow) then {
			_phaseNow = missionNamespace getVariable ["WASP_LAB_PHASE", "SPAWN"];
			_measureStartNow = missionNamespace getVariable ["WASP_LAB_MEASURE_START", -1];
		};
		if (_partitionModeNow && {_phaseNow == "MEASURE"} && {
			(missionNamespace getVariable ["WASP_LAB_MEASURE_CLOSING", false]) ||
			{_sampleAt > (missionNamespace getVariable ["WASP_LAB_END", _sampleAt])}
		}) exitWith {
			missionNamespace setVariable ["WASP_LAB_SAMPLE_INFLIGHT", ((missionNamespace getVariable ["WASP_LAB_SAMPLE_INFLIGHT", 1]) - 1) max 0];
		};
		_probeMs = round ((diag_tickTime - _probeStart) * 10000) / 10;
		_fps = round (diag_fps * 10) / 10;
		if (!_partitionModeNow) then {_sampleAt = time};
		_elapsed = round (_sampleAt - (missionNamespace getVariable ["WASP_LAB_START", 0]));
		if (!_partitionModeNow) then {
			_phaseNow = missionNamespace getVariable ["WASP_LAB_PHASE", "SPAWN"];
			_measureStartNow = missionNamespace getVariable ["WASP_LAB_MEASURE_START", -1];
		};
		_measureT = if (_measureStartNow >= 0) then {round (_sampleAt - _measureStartNow)} else {-1};
		_isBenchmark = if (_partitionModeNow) then {_phaseNow == "MEASURE"} else {_elapsed >= _warmupSec};
		_schedMode = missionNamespace getVariable ["WASP_LAB_SCHEDULER_MODE", "off"];
		_schedAgeMs = if (_schedMode == "off") then {-1} else {round ((diag_tickTime - (missionNamespace getVariable ["WASP_SCHED_HEALTH_AT", diag_tickTime])) * 1000)};
		_schedControlAgeMs = if (_schedMode == "off") then {-1} else {round ((diag_tickTime - (missionNamespace getVariable ["WASP_SCHED_CONTROL_AT", diag_tickTime])) * 1000)};
		_sample = _sample + 1;
		if (_isBenchmark) then {
			if (_partitionModeNow) then {
				_exposureLast = missionNamespace getVariable ["WASP_LAB_EXPOSURE_LAST", time];
				_exposureNow = _sampleAt min (missionNamespace getVariable ["WASP_LAB_END", _sampleAt]);
				missionNamespace setVariable ["WASP_LAB_MEMBER_SECONDS", (missionNamespace getVariable ["WASP_LAB_MEMBER_SECONDS", 0]) + (_activeMembers * (_exposureNow - _exposureLast))];
				missionNamespace setVariable ["WASP_LAB_GROUP_SECONDS", (missionNamespace getVariable ["WASP_LAB_GROUP_SECONDS", 0]) + (_activeTracked * (_exposureNow - _exposureLast))];
				missionNamespace setVariable ["WASP_LAB_EXPOSURE_LAST", _exposureNow];
			};
			missionNamespace setVariable ["WASP_LAB_FPS_N", (missionNamespace getVariable ["WASP_LAB_FPS_N", 0]) + 1];
			missionNamespace setVariable ["WASP_LAB_FPS_SUM", (missionNamespace getVariable ["WASP_LAB_FPS_SUM", 0]) + _fps];
			missionNamespace setVariable ["WASP_LAB_FPS_MIN", (missionNamespace getVariable ["WASP_LAB_FPS_MIN", 1000]) min _fps];
			missionNamespace setVariable ["WASP_LAB_AI_PEAK", (missionNamespace getVariable ["WASP_LAB_AI_PEAK", 0]) max _ai];
			missionNamespace setVariable ["WASP_LAB_GROUPS_PEAK", (missionNamespace getVariable ["WASP_LAB_GROUPS_PEAK", 0]) max _groups];
			missionNamespace setVariable ["WASP_LAB_STUCK_MAX", (missionNamespace getVariable ["WASP_LAB_STUCK_MAX", 0]) max _stuck];
			if (_activeTracked > 0) then {
				missionNamespace setVariable ["WASP_LAB_STUCK_PCT_MAX", (missionNamespace getVariable ["WASP_LAB_STUCK_PCT_MAX", 0]) max ((_stuck / _activeTracked) * 100)];
			};
			missionNamespace setVariable ["WASP_LAB_TRACKED_PEAK", (missionNamespace getVariable ["WASP_LAB_TRACKED_PEAK", 0]) max _activeTracked];
			if (_ai >= 40) then {
				missionNamespace setVariable ["WASP_LAB_HCPCT_N", (missionNamespace getVariable ["WASP_LAB_HCPCT_N", 0]) + 1];
				missionNamespace setVariable ["WASP_LAB_HCPCT_MIN", (missionNamespace getVariable ["WASP_LAB_HCPCT_MIN", 100]) min _hcPct];
				missionNamespace setVariable ["WASP_LAB_HCS_MIN", (missionNamespace getVariable ["WASP_LAB_HCS_MIN", 99]) min (count _owners)];
			};
			if (_ai >= 40 && {(missionNamespace getVariable ["WASP_LAB_EXPECTED_HCS", 0]) > 1}) then {
				missionNamespace setVariable ["WASP_LAB_HC_BALANCE_N", (missionNamespace getVariable ["WASP_LAB_HC_BALANCE_N", 0]) + 1];
				if (count _owners < (missionNamespace getVariable ["WASP_LAB_EXPECTED_HCS", 0])) then {_hcImbalance = 100};
				missionNamespace setVariable ["WASP_LAB_HC_IMBALANCE_LAST", _hcImbalance];
				missionNamespace setVariable ["WASP_LAB_HC_GROUP_IMBALANCE_LAST", _hcGroupImbalance];
				missionNamespace setVariable ["WASP_LAB_HC_IMBALANCE_MAX", (missionNamespace getVariable ["WASP_LAB_HC_IMBALANCE_MAX", 0]) max _hcImbalance];
				if (_hcImbalance > (missionNamespace getVariable ["WASP_LAB_MAX_HC_IMBALANCE_PCT", 35])) then {
					missionNamespace setVariable ["WASP_LAB_HC_IMBALANCED_N", (missionNamespace getVariable ["WASP_LAB_HC_IMBALANCED_N", 0]) + 1];
				};
			};
			if (_bus > 0 && {_hcFresh >= (missionNamespace getVariable ["WASP_LAB_EXPECTED_HCS", 0])} && {_hcFpsNow >= 0}) then {
				missionNamespace setVariable ["WASP_LAB_HC_FPS_N", (missionNamespace getVariable ["WASP_LAB_HC_FPS_N", 0]) + 1];
				missionNamespace setVariable ["WASP_LAB_HC_FPS_MIN", (missionNamespace getVariable ["WASP_LAB_HC_FPS_MIN", 1000]) min _hcFpsNow];
			};
		};
		diag_log ("WASPLAB|v1|SAMPLE|run=" + (missionNamespace getVariable ["WASP_LAB_RUN_ID", "?"]) +
			"|t=" + str _elapsed + (if (_partitionModeNow) then {"|phase=" + _phaseNow + "|measureT=" + str _measureT} else {""}) +
			"|fps=" + str _fps + "|ai=" + str _ai + "|groups=" + str _groups +
			"|srvAi=" + str _srvAi + "|hcAi=" + str _hcAi + "|otherAi=" + str _otherAi +
			"|remotePct=" + str _remotePct + "|hcPct=" + str _hcPct + "|hcs=" + str (count _owners) +
			"|hcMinAi=" + str _hcMinAi + "|hcMaxAi=" + str _hcMaxAi + "|hcImbalancePct=" + str _hcImbalance +
			"|hcMinGroups=" + str _hcMinGroups + "|hcMaxGroups=" + str _hcMaxGroups + "|hcGroupImbalancePct=" + str _hcGroupImbalance +
			"|hcFresh=" + str _hcFresh + "|hcFpsMin=" + str (round (_hcFpsNow * 10) / 10) +
			"|vehicles=" + str _vehicles + "|tracked=" + str _activeTracked + "|arrived=" + str (missionNamespace getVariable ["WASP_LAB_PATH_ARRIVALS", 0]) +
			"|stuck=" + str _stuck + "|probeMs=" + str _probeMs + "|schedulerMode=" + _schedMode +
			"|schedAgeMs=" + str _schedAgeMs + "|schedControlAgeMs=" + str _schedControlAgeMs +
			(if (_partitionModeNow) then {"|" + (Call WASP_LAB_FNC_CompositionText)} else {""}));

		if (_bus > 0) then {
			_sent = missionNamespace getVariable ["WASP_LAB_BUS_SENT_TOTAL", 0];
			_ack = missionNamespace getVariable ["WASP_LAB_BUS_ACK_TOTAL", 0];
			_drop = missionNamespace getVariable ["WASP_LAB_BUS_DROP_TOTAL", 0];
			_latAvg = if (_ack > 0) then {round ((missionNamespace getVariable ["WASP_LAB_BUS_LAT_SUM", 0]) / _ack)} else {-1};
			diag_log ("WASPLAB|v1|BUS|run=" + (missionNamespace getVariable ["WASP_LAB_RUN_ID", "?"]) +
				"|t=" + str _elapsed + "|sentTotal=" + str _sent + "|ackTotal=" + str _ack + "|dropTotal=" + str _drop +
				"|latencyMs=" + str _latAvg + "|dup=" + str (missionNamespace getVariable ["WASP_LAB_BUS_ACK_DUP", 0]));
		};

		// The old live alert checked remote==0. This test tripwire catches the observed 7% case.
		if (_isBenchmark && {_ai >= 40} && {(missionNamespace getVariable ["WASP_LAB_MIN_HC_PCT", 0]) > 0}) then {
			if (_hcPct < 25) then {_collapseN = _collapseN + 1} else {_collapseN = 0};
			if (_hcPct < (missionNamespace getVariable ["WASP_LAB_MIN_HC_PCT", 60])) then {_lowN = _lowN + 1} else {_lowN = 0};
			_status = "OK";
			if (_lowN >= 3) then {_status = "DEGRADED"};
			if (_collapseN >= 2) then {_status = "COLLAPSED"};
			if (_status != _lastState) then {
				diag_log ("WASPLAB|v1|ALERT|run=" + (missionNamespace getVariable ["WASP_LAB_RUN_ID", "?"]) +
					"|t=" + str _elapsed + "|state=" + _status + "|hcPct=" + str _hcPct + "|ai=" + str _ai);
				_lastState = _status;
			};
		};
		if (_partitionModeNow) then {missionNamespace setVariable ["WASP_LAB_SAMPLE_INFLIGHT", ((missionNamespace getVariable ["WASP_LAB_SAMPLE_INFLIGHT", 1]) - 1) max 0]};
		sleep _interval;
	};
};

if (_partitionMode) then {
	_spawnDeadline = time + (((ceil (_totalGroups / _batchGroups)) max 1) * _batchInterval * 2) + 120;
	waitUntil {
		sleep 1;
		(missionNamespace getVariable ["WASP_LAB_SPAWN_DONE", false]) || {time >= _spawnDeadline} ||
		{missionNamespace getVariable ["WASP_LAB_STOP", false]} || {WFBE_GameOver}
	};
	if (!(missionNamespace getVariable ["WASP_LAB_SPAWN_DONE", false]) && {!WFBE_GameOver}) then {
		diag_log ("WASPLAB|v1|SPAWN_FAIL|run=" + _run + "|reason=spawn_barrier_timeout");
		missionNamespace setVariable ["WASP_LAB_STOP", true];
	};
	if (!(missionNamespace getVariable ["WASP_LAB_STOP", false]) && {!WFBE_GameOver}) then {
		missionNamespace setVariable ["WASP_LAB_PHASE", "SETTLE"];
		missionNamespace setVariable ["WASP_LAB_PHASE_SEQ", 2];
		Call WASP_LAB_FNC_LogPhase;
		Call WASP_LAB_FNC_LogComposition;
		_settleEnd = time + _settleSec;
		waitUntil {sleep 1; time >= _settleEnd || {missionNamespace getVariable ["WASP_LAB_STOP", false]} || {WFBE_GameOver}};
	};
	if (!(missionNamespace getVariable ["WASP_LAB_STOP", false]) && {!WFBE_GameOver}) then {
		_measureStart = time;
		missionNamespace setVariable ["WASP_LAB_MEASURE_START", _measureStart];
		missionNamespace setVariable ["WASP_LAB_PHASE", "GO"];
		missionNamespace setVariable ["WASP_LAB_PHASE_SEQ", 3];
		Call WASP_LAB_FNC_ResetMeasure;
		Call WASP_LAB_FNC_LogPhase;
		Call WASP_LAB_FNC_StartOrders;
		Call WASP_LAB_FNC_LogComposition;
		missionNamespace setVariable ["WASP_LAB_PHASE", "MEASURE"];
		missionNamespace setVariable ["WASP_LAB_PHASE_SEQ", 4];
		_end = _measureStart + _duration;
		missionNamespace setVariable ["WASP_LAB_END", _end];
		Call WASP_LAB_FNC_LogPhase;
		waitUntil {sleep 1; time >= _end || {missionNamespace getVariable ["WASP_LAB_STOP", false]} || {WFBE_GameOver}};
	};
	missionNamespace setVariable ["WASP_LAB_MEASURE_CLOSING", true];
	missionNamespace setVariable ["WASP_LAB_STOP", true];
	_drainDeadline = diag_tickTime + 30;
	waitUntil {
		sleep 0.01;
		((missionNamespace getVariable ["WASP_LAB_SAMPLE_INFLIGHT", 0]) < 1 &&
		{(missionNamespace getVariable ["WASP_LAB_PATH_INFLIGHT", 0]) < 1}) ||
		{diag_tickTime >= _drainDeadline}
	};
	_drainTimedOut = (missionNamespace getVariable ["WASP_LAB_SAMPLE_INFLIGHT", 0]) > 0 ||
		{(missionNamespace getVariable ["WASP_LAB_PATH_INFLIGHT", 0]) > 0};
	if (_drainTimedOut) then {
		missionNamespace setVariable ["WASP_LAB_DRAIN_FAILED", true];
		diag_log ("WASPLAB|v1|ABORT|run=" + _run + "|reason=measure_worker_drain_timeout");
		waitUntil {
			sleep 0.01;
			(missionNamespace getVariable ["WASP_LAB_SAMPLE_INFLIGHT", 0]) < 1 &&
			{(missionNamespace getVariable ["WASP_LAB_PATH_INFLIGHT", 0]) < 1}
		};
	};
	Call WASP_LAB_FNC_AccumulateExposure;
	missionNamespace setVariable ["WASP_LAB_PHASE", "CLEANUP"];
	missionNamespace setVariable ["WASP_LAB_PHASE_SEQ", 5];
	Call WASP_LAB_FNC_LogPhase;
} else {
	waitUntil {sleep 1; time >= _end || {missionNamespace getVariable ["WASP_LAB_STOP", false]} || {WFBE_GameOver}};
};
missionNamespace setVariable ["WASP_LAB_STOP", true];
sleep 5; // allow final Common_Send acknowledgements to arrive before the verdict.

_fpsN = missionNamespace getVariable ["WASP_LAB_FPS_N", 0];
_fpsAvg = if (_fpsN > 0) then {round (((missionNamespace getVariable ["WASP_LAB_FPS_SUM", 0]) / _fpsN) * 10) / 10} else {-1};
_fpsMin = missionNamespace getVariable ["WASP_LAB_FPS_MIN", -1];
_sampleExpected = if (_partitionMode) then {floor (_duration / _sampleSec)} else {floor (((_duration - _warmup) max 0) / _sampleSec)};
_sampleCoveragePct = if (_sampleExpected > 0) then {round ((_fpsN / _sampleExpected) * 1000) / 10} else {100};
_aiPeak = missionNamespace getVariable ["WASP_LAB_AI_PEAK", 0];
_groupsPeak = missionNamespace getVariable ["WASP_LAB_GROUPS_PEAK", 0];
_hcPctMin = if ((missionNamespace getVariable ["WASP_LAB_HCPCT_N", 0]) > 0) then {missionNamespace getVariable ["WASP_LAB_HCPCT_MIN", 0]} else {-1};
_stuckMax = missionNamespace getVariable ["WASP_LAB_STUCK_MAX", 0];
_stuckPctMax = missionNamespace getVariable ["WASP_LAB_STUCK_PCT_MAX", 0];
_trackedPeak = missionNamespace getVariable ["WASP_LAB_TRACKED_PEAK", 0];
_busSent = missionNamespace getVariable ["WASP_LAB_BUS_SENT_TOTAL", 0];
_busAck = missionNamespace getVariable ["WASP_LAB_BUS_ACK_TOTAL", 0];
_busDrop = missionNamespace getVariable ["WASP_LAB_BUS_DROP_TOTAL", 0];
_busLoss = (_busSent - _busAck) max 0;
_busLatAvg = if (_busAck > 0) then {round ((missionNamespace getVariable ["WASP_LAB_BUS_LAT_SUM", 0]) / _busAck)} else {-1};
_busAttemptPost = missionNamespace getVariable ["WASP_LAB_BUS_ATTEMPT_POST", 0];
_busSentPost = missionNamespace getVariable ["WASP_LAB_BUS_SENT_POST", 0];
_busAckPost = missionNamespace getVariable ["WASP_LAB_BUS_ACK_POST", 0];
_busExpected = if (_partitionMode) then {round (_duration * _busRate)} else {round (((_duration - _warmup) max 0) * _busRate)};
_busAttainPct = if (_busExpected > 0) then {round ((_busSentPost / _busExpected) * 1000) / 10} else {-1};
_busLoss = (_busSentPost - _busAckPost) max 0;
_busLatAvg = if (_busAckPost > 0) then {round ((missionNamespace getVariable ["WASP_LAB_BUS_LAT_SUM_POST", 0]) / _busAckPost)} else {-1};
_hcOwnersFinal = Call WASP_LAB_FNC_HCOwners;
_busFreshEndpoints = {typeName _x == "ARRAY" && {count _x >= 4} && {typeName (_x select 0) == "SCALAR"} &&
	{typeName (_x select 1) == "SCALAR"} && {typeName (_x select 2) == "SCALAR"} && {((_x select 0) in _hcOwnersFinal)} &&
	{(_x select 1) >= 4} && {(diag_tickTime - (_x select 2)) <= 10}} count (missionNamespace getVariable ["WASP_LAB_BUS_ACK_ENDPOINTS", []]);
_schedRuns = missionNamespace getVariable ["WASP_SCHED_RUN_TOTAL", 0];
_schedDeferred = missionNamespace getVariable ["WASP_SCHED_DEFER_TOTAL", 0];
_schedOverruns = missionNamespace getVariable ["WASP_SCHED_OVERRUN_TOTAL", 0];
_schedErrors = missionNamespace getVariable ["WASP_SCHED_ERROR_TOTAL", 0];
_schedMaxElapsed = missionNamespace getVariable ["WASP_SCHED_MAX_SPENT_MS", 0];
_schedAge = if (_schedulerMode == "off") then {-1} else {(diag_tickTime - (missionNamespace getVariable ["WASP_SCHED_HEALTH_AT", diag_tickTime])) * 1000};
_schedControlAge = if (_schedulerMode == "off") then {-1} else {(diag_tickTime - (missionNamespace getVariable ["WASP_SCHED_CONTROL_AT", diag_tickTime])) * 1000};
_spawnedTotal = missionNamespace getVariable ["WASP_LAB_SPAWNED_TOTAL", 0];
_arrivals = missionNamespace getVariable ["WASP_LAB_PATH_ARRIVALS", 0];
_hcImbalanceLast = missionNamespace getVariable ["WASP_LAB_HC_IMBALANCE_LAST", -1];
_hcGroupImbalanceLast = missionNamespace getVariable ["WASP_LAB_HC_GROUP_IMBALANCE_LAST", -1];
_hcsMin = missionNamespace getVariable ["WASP_LAB_HCS_MIN", 99];
_hcBalanceN = missionNamespace getVariable ["WASP_LAB_HC_BALANCE_N", 0];
_hcImbalancedN = missionNamespace getVariable ["WASP_LAB_HC_IMBALANCED_N", 0];
_hcImbalanceMax = missionNamespace getVariable ["WASP_LAB_HC_IMBALANCE_MAX", 0];
_hcImbalancedPct = if (_hcBalanceN > 0) then {round ((_hcImbalancedN / _hcBalanceN) * 1000) / 10} else {-1};
_hcFpsN = missionNamespace getVariable ["WASP_LAB_HC_FPS_N", 0];
_hcFpsMin = if (_hcFpsN > 0) then {missionNamespace getVariable ["WASP_LAB_HC_FPS_MIN", -1]} else {-1};
_combatInitial = missionNamespace getVariable ["WASP_LAB_COMBAT_INITIAL_UNITS", 0];
_combatAlive = {!(isNull _x) && {_x isKindOf "Man"} && {alive _x}} count (missionNamespace getVariable ["WASP_LAB_TRACKED_OBJECTS", []]);
_combatCasualties = (_combatInitial - _combatAlive) max 0;
_combatGroups = missionNamespace getVariable ["WASP_LAB_TRACKED_GROUPS", []];
_combatMovedGroups = {!(isNull _x) && {!isNil {_x getVariable "wasp_lab_moved"}} && {_x getVariable "wasp_lab_moved"}} count _combatGroups;
_combatMovedPct = if (count _combatGroups > 0) then {round ((_combatMovedGroups / count _combatGroups) * 1000) / 10} else {0};
_measureStart = missionNamespace getVariable ["WASP_LAB_MEASURE_START", -1];
_measureElapsed = if (_partitionMode && {_measureStart >= 0}) then {round (((time min (_measureStart + _duration)) - _measureStart) max 0)} else {0};
_realizedGroups = missionNamespace getVariable ["WASP_LAB_REALIZED_GROUPS", 0];
_requestedInfantry = missionNamespace getVariable ["WASP_LAB_REQUESTED_INFANTRY", 0];
_createdInfantry = missionNamespace getVariable ["WASP_LAB_CREATED_INFANTRY", 0];
_createdCrew = missionNamespace getVariable ["WASP_LAB_CREATED_CREW", 0];
_createdVehicles = missionNamespace getVariable ["WASP_LAB_CREATED_VEHICLES", 0];
_finalMembers = missionNamespace getVariable ["WASP_LAB_FINAL_MEMBERS", 0];
_underfillGroups = missionNamespace getVariable ["WASP_LAB_UNDERFILL_GROUPS", 0];
_oversizeGroups = missionNamespace getVariable ["WASP_LAB_OVERSIZE_GROUPS", 0];
_createFailures = missionNamespace getVariable ["WASP_LAB_CREATE_FAILURES", 0];
_createFailureGroups = missionNamespace getVariable ["WASP_LAB_CREATE_FAILURE_GROUPS", 0];
_memberSeconds = missionNamespace getVariable ["WASP_LAB_MEMBER_SECONDS", 0];
_groupSeconds = missionNamespace getVariable ["WASP_LAB_GROUP_SECONDS", 0];
_pathLegsStarted = missionNamespace getVariable ["WASP_LAB_PATH_LEGS_STARTED", 0];

_status = "PASS";
_reason = "gates_met";
if (_fpsN < 1) then {_status = "FAIL"; _reason = "no_post_warmup_samples"};
if (_status == "PASS" && {_sampleExpected > 0} && {_sampleCoveragePct < 80}) then {_status = "FAIL"; _reason = "sample_coverage"};
if (_status == "PASS" && {missionNamespace getVariable ["WASP_LAB_DRAIN_FAILED", false]}) then {_status = "FAIL"; _reason = "measure_worker_drain"};
if (_status == "PASS" && {_fpsMin >= 0} && {_fpsMin < (missionNamespace getVariable ["WASP_LAB_MIN_FPS", 30])}) then {_status = "FAIL"; _reason = "fps_floor"};
if (_status == "PASS" && {_expectedHcs > 0} && {(count (Call WASP_LAB_FNC_HCOwners)) < _expectedHcs}) then {_status = "FAIL"; _reason = "hc_count"};
if (_status == "PASS" && {(missionNamespace getVariable ["WASP_LAB_MIN_HC_PCT", 0]) > 0} && {_aiPeak >= 40} && {_hcPctMin < 0}) then {_status = "FAIL"; _reason = "no_hc_ownership_samples"};
if (_status == "PASS" && {(missionNamespace getVariable ["WASP_LAB_MIN_HC_PCT", 0]) > 0} && {_hcPctMin >= 0} && {_hcPctMin < (missionNamespace getVariable ["WASP_LAB_MIN_HC_PCT", 60])}) then {_status = "FAIL"; _reason = "hc_ownership"};
if (_status == "PASS" && {_expectedHcs > 0} && {_aiPeak >= 40} && {_hcsMin < _expectedHcs}) then {_status = "FAIL"; _reason = "hc_count_transient"};
if (_status == "PASS" && {_expectedHcs > 1} && {(missionNamespace getVariable ["WASP_LAB_MIN_HC_PCT", 0]) > 0} && {_hcImbalancedPct > 20}) then {_status = "FAIL"; _reason = "hc_imbalance"};
if (_status == "PASS" && {_stuckPctMax > (missionNamespace getVariable ["WASP_LAB_MAX_STUCK_PCT", 20])}) then {_status = "FAIL"; _reason = "stuck_groups"};
if (_status == "PASS" && {_totalGroups > 0} && {_spawnedTotal < _totalGroups}) then {_status = "FAIL"; _reason = "spawn_target_missed"};
if (_status == "PASS" && {_partitionMode} && {_targetSyntheticUnits > 0} && {_requestedInfantry != _targetSyntheticUnits}) then {_status = "FAIL"; _reason = "synthetic_request_mismatch"};
if (_status == "PASS" && {_partitionMode} && {_targetSyntheticUnits > 0} && {_createdInfantry < _targetSyntheticUnits}) then {_status = "FAIL"; _reason = "synthetic_unit_target_missed"};
if (_status == "PASS" && {_mode == "path-loop"} && {_trackedPeak > 0} && {_arrivals < 1}) then {_status = "FAIL"; _reason = "no_path_arrivals"};
if (_status == "PASS" && {_mode == "combat"} && {_combatMovedPct < 50}) then {_status = "FAIL"; _reason = "combat_no_movement"};
if (_status == "PASS" && {_mode == "combat"} && {_combatCasualties < 1}) then {_status = "FAIL"; _reason = "combat_no_casualties"};
if (_status == "PASS" && {_busRate > 0} && {_expectedHcs > 0} && {_busDrop > 2}) then {_status = "FAIL"; _reason = "bus_no_target"};
if (_status == "PASS" && {_busRate > 0} && {_expectedHcs > 0} && {_busFreshEndpoints < _expectedHcs}) then {_status = "FAIL"; _reason = "bus_endpoint_stale"};
if (_status == "PASS" && {_busRate > 0} && {_expectedHcs > 0} && {_hcFpsN < 1}) then {_status = "FAIL"; _reason = "hc_fps_missing"};
if (_status == "PASS" && {_busRate > 0} && {_expectedHcs > 0} && {_hcFpsMin >= 0} && {_hcFpsMin < (missionNamespace getVariable ["WASP_LAB_MIN_HC_FPS", 25])}) then {_status = "FAIL"; _reason = "hc_fps_floor"};
if (_status == "PASS" && {_busRate > 0} && {_busExpected > 0} && {_busAttainPct < (missionNamespace getVariable ["WASP_LAB_MIN_BUS_ATTAINMENT_PCT", 80])}) then {_status = "FAIL"; _reason = "bus_throughput"};
if (_status == "PASS" && {_busRate > 0} && {_busSentPost > 0} && {_busLoss > ((_busSentPost * 0.01) max 2)}) then {_status = "FAIL"; _reason = "bus_loss"};
if (_status == "PASS" && {_schedulerMode != "off"} && {_schedErrors > 0}) then {_status = "FAIL"; _reason = "scheduler_job_error"};
if (_status == "PASS" && {_schedulerMode != "off"} && {(_schedAge > 10000) || {_schedControlAge > 10000}}) then {_status = "FAIL"; _reason = "scheduler_stale"};
if (_status == "PASS" && {WFBE_GameOver}) then {_status = "FAIL"; _reason = "unexpected_gameover"};

_cleanupObjectsRemaining = -1;
_cleanupGroupsRemaining = -1;
if (_cleanup) then {
	_cleanupObjects = missionNamespace getVariable ["WASP_LAB_TRACKED_OBJECTS", []];
	_cleanupGroups = missionNamespace getVariable ["WASP_LAB_TRACKED_GROUPS", []];
	{if (!isNull _x) then {deleteVehicle _x}} forEach _cleanupObjects;
	{if (!isNull _x) then {deleteGroup _x}} forEach _cleanupGroups;
	sleep 1;
	_cleanupObjectsRemaining = {!isNull _x} count _cleanupObjects;
	_cleanupGroupsRemaining = {!isNull _x} count _cleanupGroups;
	diag_log ("WASPLAB|v1|CLEANUP|run=" + _run + "|objectsAttempted=" + str (count _cleanupObjects) +
		"|groupsAttempted=" + str (count _cleanupGroups) + "|objectsRemaining=" + str _cleanupObjectsRemaining +
		"|groupsRemaining=" + str _cleanupGroupsRemaining);
	if (_status == "PASS" && {(_cleanupObjectsRemaining + _cleanupGroupsRemaining) > 0}) then {_status = "FAIL"; _reason = "cleanup_incomplete"};
};

diag_log ("WASPLAB|v1|RESULT|run=" + _run + "|status=" + _status + "|duration=" + str (round (time - _start)) +
	(if (_partitionMode) then {"|measureDuration=" + str _measureElapsed + "|phase=CLEANUP|measureT=" + str _measureElapsed} else {""}) +
	"|reason=" + _reason + "|fpsMin=" + str _fpsMin + "|fpsAvg=" + str _fpsAvg + "|fpsSamples=" + str _fpsN +
	"|fpsExpected=" + str _sampleExpected + "|fpsCoveragePct=" + str _sampleCoveragePct + "|aiPeak=" + str _aiPeak +
	"|groupsPeak=" + str _groupsPeak + "|hcPctMin=" + str _hcPctMin + "|hcImbalanceLast=" + str _hcImbalanceLast +
	"|hcGroupImbalanceLast=" + str _hcGroupImbalanceLast + "|hcsMin=" + str _hcsMin + "|hcImbalanceMax=" + str _hcImbalanceMax +
	"|hcImbalancedPct=" + str _hcImbalancedPct + "|hcFpsSamples=" + str _hcFpsN + "|hcFpsMin=" + str (round (_hcFpsMin * 10) / 10) +
	"|stuckMax=" + str _stuckMax + "|stuckPctMax=" + str (round (_stuckPctMax * 10) / 10) +
	"|trackedPeak=" + str _trackedPeak + "|spawnedTotal=" + str _spawnedTotal + "|arrivals=" + str _arrivals +
	"|combatInitial=" + str _combatInitial + "|combatCasualties=" + str _combatCasualties + "|combatMovedGroups=" + str _combatMovedGroups + "|combatMovedPct=" + str _combatMovedPct +
	"|busSent=" + str _busSentPost + "|busAck=" + str _busAckPost + "|busSentTotal=" + str _busSent + "|busAckTotal=" + str _busAck +
	"|busDrop=" + str _busDrop + "|busLoss=" + str _busLoss +
	"|busAttemptPost=" + str _busAttemptPost + "|busSentPost=" + str _busSentPost + "|busAckPost=" + str _busAckPost + "|busExpected=" + str _busExpected + "|busAttainPct=" + str _busAttainPct +
	"|busFreshEndpoints=" + str _busFreshEndpoints +
	"|busLatencyAvgMs=" + str _busLatAvg + "|busLatencyMaxMs=" + str (round (missionNamespace getVariable ["WASP_LAB_BUS_LAT_MAX_POST", 0])) +
	"|schedulerMode=" + _schedulerMode + "|schedRuns=" + str _schedRuns + "|schedDeferred=" + str _schedDeferred +
	"|schedOverruns=" + str _schedOverruns + "|schedErrors=" + str _schedErrors + "|schedMaxElapsedMs=" + str (round (_schedMaxElapsed * 10) / 10) +
	"|schedAgeMs=" + str (round _schedAge) + "|schedControlAgeMs=" + str (round _schedControlAge) +
	"|cleanupObjectsRemaining=" + str _cleanupObjectsRemaining + "|cleanupGroupsRemaining=" + str _cleanupGroupsRemaining +
	(if (_partitionMode) then {"|" + (Call WASP_LAB_FNC_CompositionText)} else {""}) + "|complete=1");
