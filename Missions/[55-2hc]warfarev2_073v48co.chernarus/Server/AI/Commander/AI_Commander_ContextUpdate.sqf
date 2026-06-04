/*
	AI Commander context update pass.
	Phase 2: consumes structured CONTACT/INTEL/LOSS logs into bounded beliefs.
	Parameter: _side
*/

Private ["_side","_logik","_lastSeq","_records","_context","_record","_seq","_kind","_source","_payload","_candidate","_enemy","_category","_pos","_countMin","_countMax","_conf","_label","_town","_townName","_townRadius","_status","_sources","_debugLast","_newestSeq","_relevant"];

_side = _this;
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNil "_logik") exitWith {};
if (isNil "WFBE_SE_FNC_AI_Com_LogDrain") exitWith {};

_lastSeq = _logik getVariable ["wfbe_aicom_context_last_seq", 0];
_records = [_side, _lastSeq] Call WFBE_SE_FNC_AI_Com_LogDrain;
if (typeName _records != "ARRAY") exitWith {};

_context = _logik getVariable ["wfbe_aicom_context", []];
if (typeName _context != "ARRAY") then {_context = []};
_newestSeq = _lastSeq;

{
	_record = _x;
	if (typeName _record == "ARRAY") then {
		if (count _record >= 6) then {
			_seq = _record select 0;
			_kind = _record select 1;
			_source = _record select 4;
			_payload = _record select 5;
			if (_seq > _newestSeq) then {_newestSeq = _seq};
			_candidate = [];
			_relevant = false;
			_enemy = _side;
			_category = "unknown";
			_pos = [];
			_countMin = 0;
			_countMax = -1;
			_conf = 0;
			_label = "";
			_status = "rumor";

			if (typeName _payload == "ARRAY") then {
				if (_kind == "CONTACT" && {count _payload >= 7}) then {
					_enemy = _payload select 0;
					_category = _payload select 1;
					_pos = _payload select 2;
					_countMin = _payload select 3;
					_countMax = _payload select 4;
					_conf = 0 max (1 min (_payload select 5));
					_label = _payload select 6;
					_status = "active";
					_relevant = true;
				};
				if (_kind == "INTEL" && {count _payload >= 8}) then {
					_enemy = _payload select 0;
					_category = _payload select 1;
					_pos = _payload select 2;
					_countMin = _payload select 3;
					_countMax = _payload select 4;
					_conf = 0 max (0.60 min (_payload select 5));
					_label = _payload select 6;
					_status = "rumor";
					_relevant = true;
				};
				if (_kind == "LOSS" && {count _payload >= 5}) then {
					_enemy = if (_side == west) then {east} else {west};
					_category = _payload select 3;
					_pos = _payload select 1;
					_countMin = 0;
					_countMax = -1;
					_conf = 0 max (0.70 min (_payload select 4));
					_label = _payload select 2;
					_status = "active";
					_relevant = true;
				};

				if (_relevant && {typeName _pos == "ARRAY"}) then {
					_town = objNull;
					_townName = "";
					_townRadius = if (_category == "air") then {2500} else {1500};
					if (count towns > 0) then {
						_town = [_pos, towns] Call WFBE_CO_FNC_GetClosestEntity;
						if (!isNil "_town") then {
							if (!isNull _town) then {
								if ((_pos distance _town) <= _townRadius) then {_townName = _town getVariable ["name", "town"]} else {_town = objNull};
							};
						};
					};
					_sources = [_source];
					_candidate = [Format ["contact-%1-%2", str _side, _seq], _enemy, _category, _pos, _town, _townName, _countMin, _countMax, _conf, time, time, _sources, _status];
				};
			};

			if (count _candidate > 0) then {
				if (!isNil "WFBE_SE_FNC_AI_Com_BeliefMerge") then {_context = [_side, _context, _candidate] Call WFBE_SE_FNC_AI_Com_BeliefMerge};
			};
		};
	};
} forEach _records;

if (!isNil "WFBE_SE_FNC_AI_Com_BeliefDecay") then {_context = [_side, _context] Call WFBE_SE_FNC_AI_Com_BeliefDecay};

_logik setVariable ["wfbe_aicom_context", _context];
_logik setVariable ["wfbe_aicom_context_last_seq", _newestSeq];
_logik setVariable ["wfbe_aicom_context_last_update", time];

_debugLast = _logik getVariable ["wfbe_aicom_context_last_debug", 0];
if (time - _debugLast > 120) then {
	if (!isNil "WFBE_SE_FNC_AI_Com_ContextDebug") then {[_side, _context] Call WFBE_SE_FNC_AI_Com_ContextDebug};
	_logik setVariable ["wfbe_aicom_context_last_debug", time];
};

_context;
