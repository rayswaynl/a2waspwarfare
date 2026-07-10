/* Test-only Common_Send round-trip acknowledgement. Registered only in a generated proving ground. */

Private ["_run","_seq","_sentAt","_latency","_seen","_endpoint","_postWarmup","_hcFps","_rows","_ids","_idx","_row","_pending"];

if (typeName _this != "ARRAY" || {count _this < 7}) exitWith {
	diag_log "WASPLAB|v1|BUS_REJECT|side=server|reason=shape";
};

_run = _this select 0;
_seq = _this select 1;
_sentAt = _this select 2;
_hcFps = _this select 4;
_endpoint = _this select 5;
_postWarmup = _this select 6;

if (typeName _run != "STRING" || {typeName _seq != "SCALAR"} || {typeName _sentAt != "SCALAR"} || {typeName _hcFps != "SCALAR"} || {_hcFps < 0} || {typeName _endpoint != "SCALAR"} || {_endpoint <= 2} || {typeName _postWarmup != "BOOL"}) exitWith {
	diag_log "WASPLAB|v1|BUS_REJECT|side=server|reason=type";
};
if (_run != (missionNamespace getVariable ["WASP_LAB_RUN_ID", ""])) exitWith {};

_seen = missionNamespace getVariable ["WASP_LAB_BUS_ACK_SEEN", []];
if (_seq in _seen) exitWith {
	missionNamespace setVariable ["WASP_LAB_BUS_ACK_DUP", (missionNamespace getVariable ["WASP_LAB_BUS_ACK_DUP", 0]) + 1];
};

_pending = missionNamespace getVariable ["WASP_LAB_BUS_PENDING", []];
_ids = [];
{_ids set [count _ids, _x select 0]} forEach _pending;
_idx = _ids find _seq;
if (_idx < 0) exitWith {diag_log "WASPLAB|v1|BUS_REJECT|side=server|reason=not_pending"};
_row = _pending select _idx;
if ((_row select 1) != _endpoint || {(_row select 2) != _postWarmup} || {(_row select 3) != _sentAt}) exitWith {diag_log "WASPLAB|v1|BUS_REJECT|side=server|reason=token"};
_seen set [count _seen, _seq];
if (count _seen > 256) then {_seen set [0, -1]; _seen = _seen - [-1]};
missionNamespace setVariable ["WASP_LAB_BUS_ACK_SEEN", _seen];
_pending set [_idx, -1];
_pending = _pending - [-1];
missionNamespace setVariable ["WASP_LAB_BUS_PENDING", _pending];

_latency = ((time - _sentAt) max 0) * 1000;
missionNamespace setVariable ["WASP_LAB_BUS_ACK_TOTAL", (missionNamespace getVariable ["WASP_LAB_BUS_ACK_TOTAL", 0]) + 1];
missionNamespace setVariable ["WASP_LAB_BUS_LAT_SUM", (missionNamespace getVariable ["WASP_LAB_BUS_LAT_SUM", 0]) + _latency];
missionNamespace setVariable ["WASP_LAB_BUS_LAT_MAX", (missionNamespace getVariable ["WASP_LAB_BUS_LAT_MAX", 0]) max _latency];
if (_postWarmup) then {
	missionNamespace setVariable ["WASP_LAB_BUS_ACK_POST", (missionNamespace getVariable ["WASP_LAB_BUS_ACK_POST", 0]) + 1];
	missionNamespace setVariable ["WASP_LAB_BUS_LAT_SUM_POST", (missionNamespace getVariable ["WASP_LAB_BUS_LAT_SUM_POST", 0]) + _latency];
	missionNamespace setVariable ["WASP_LAB_BUS_LAT_MAX_POST", (missionNamespace getVariable ["WASP_LAB_BUS_LAT_MAX_POST", 0]) max _latency];
};

_rows = missionNamespace getVariable ["WASP_LAB_BUS_ACK_ENDPOINTS", []];
_ids = [];
{_ids set [count _ids, _x select 0]} forEach _rows;
_idx = _ids find _endpoint;
if (_idx < 0) then {
	_rows set [count _rows, [_endpoint, 1, diag_tickTime, _hcFps]];
} else {
	_row = _rows select _idx;
	_row set [1, (_row select 1) + 1];
	_row set [2, diag_tickTime];
	_row set [3, _hcFps];
	_rows set [_idx, _row];
};
missionNamespace setVariable ["WASP_LAB_BUS_ACK_ENDPOINTS", _rows];
