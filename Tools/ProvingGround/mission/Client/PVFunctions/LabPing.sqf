/* Test-only Common_Send round-trip receiver. Registered only in a generated proving ground. */

Private ["_run","_seq","_sentAt","_postWarmup","_endpoint"];

if (typeName _this != "ARRAY" || {count _this < 5}) exitWith {
	diag_log "WASPLAB|v1|BUS_REJECT|side=client|reason=shape";
};

_run = _this select 0;
_seq = _this select 1;
_sentAt = _this select 2;
_postWarmup = _this select 3;
_endpoint = _this select 4;

if (typeName _run != "STRING" || {typeName _seq != "SCALAR"} || {typeName _sentAt != "SCALAR"} || {typeName _postWarmup != "BOOL"} || {typeName _endpoint != "SCALAR"}) exitWith {
	diag_log "WASPLAB|v1|BUS_REJECT|side=client|reason=type";
};

if (isNil "WASP_LAB_HC_PING_COUNT") then {WASP_LAB_HC_PING_COUNT = 0};
WASP_LAB_HC_PING_COUNT = WASP_LAB_HC_PING_COUNT + 1;

["LabPong", [_run, _seq, _sentAt, time, diag_fps, _endpoint, _postWarmup]] Call WFBE_CO_FNC_SendToServer;
