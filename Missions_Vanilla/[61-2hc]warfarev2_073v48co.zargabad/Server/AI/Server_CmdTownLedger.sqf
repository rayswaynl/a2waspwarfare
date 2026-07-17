// Server_CmdTownLedger.sqf
// Commander Town Ledger (CTL): virtual per-town strength ledger + paid AI investment
// for WEST/EAST towns. Structurally mirrors Server_GuerDirector.sqf (Lane 800).
// Flag gate: AICOMV2_LANE_CMD_TOWN_LEDGER (default 0 = inert; flag-off = byte-identical).
// See docs/design/v2/aicom-v2-commander-town-ledger.md for full spec.
//
// A2 OA 1.64 compliant: array-append via set[count,v], private ["x"] declarations,
// lazy && {} / || {}, no exitWith inside forEach.

if (!((missionNamespace getVariable ["AICOMV2_LANE_CMD_TOWN_LEDGER", 0]) > 0)) exitWith {};

//--- Singleton guard (GUER Director precedent: duplicate instances would double-write
//--- wfbe_ctl_str and desync the ledger).
if ((missionNamespace getVariable ["AICOMV2_CTL_INSTANCE", 0]) > 0) exitWith {
	diag_log "CTLSTAT|v1|BOTH|CTL_DUPLICATE_BLOCKED";
};
AICOMV2_CTL_INSTANCE = 1;

["INITIALIZATION", "Server_CmdTownLedger.sqf: CTL starting."] Call WFBE_CO_FNC_LogContent;

waitUntil {!isNil "towns"};
waitUntil {count towns > 0};
sleep 5;

private ["_tickSec","_regenFullSec","_captureSeed"];
_tickSec       = missionNamespace getVariable ["AICOMV2_CTL_TICK_SEC",         30];
_regenFullSec  = missionNamespace getVariable ["AICOMV2_CTL_REGEN_FULL_SEC",   1800];
_captureSeed   = missionNamespace getVariable ["AICOMV2_CTL_CAPTURE_SEED",     0.25];

private ["_fnClamp"];
_fnClamp = {
	private ["_val","_lo","_hi"];
	_val = _this select 0;
	_lo  = _this select 1;
	_hi  = _this select 2;
	if (_val < _lo) then {_val = _lo};
	if (_val > _hi) then {_val = _hi};
	_val
};

//===================================================================================
// SEED: build the initial per-side ledgers from the current town roster.
// Record layout: [0]=town, [1]=baselineGroups, [2]=strength, [3]=lastSpawnUnits,
//                [4]=investT0, [5]=seedT0.
//===================================================================================
private ["_fnSeedSide"];
_fnSeedSide = {
	private ["_sideId","_side","_logik","_ledger","_n"];
	_sideId = _this select 0;
	_side   = _this select 1;
	_logik  = (_side) Call WFBE_CO_FNC_GetSideLogic;
	_ledger = [];
	_n      = 0;
	{
		private ["_town","_tSide"];
		_town  = _x;
		_tSide = _town getVariable ["sideID", WFBE_C_UNKNOWN_ID];
		if (_tSide == _sideId) then {
			private ["_baseGroups","_rec"];
			_baseGroups = count ([_town, _side] Call WFBE_SE_FNC_GetTownGroups);
			//--- clear any stale pending/counter scalars (restart hygiene - same reason as the tick seed)
			_town setVariable ["wfbe_ctl_pending_ratio", -1];
			_town setVariable ["wfbe_ctl_pending_invest", 0];
			_town setVariable ["wfbe_ctl_pending_invest_cost", 0];
			_town setVariable ["wfbe_ctl_lastspawn", 0];
			_rec = [_town, _baseGroups, 1.0, 0, 0, diag_tickTime];
			_ledger set [count _ledger, _rec];
			_n = _n + 1;
			diag_log Format ["CTLSTAT|v1|%1|SEED|town=%2|str=%3", str _side, _town getVariable ["name", "?"], 1.0];
		};
	} forEach towns;
	_logik setVariable ["WFBE_CTL_LEDGER", _ledger];
	_logik setVariable ["WFBE_CTL_DENY_COUNT", 0];
	diag_log Format ["CTLSTAT|v1|%1|towns=%2|totalStr=%3|totalBase=%4|invested=0|denied=0", str _side, _n, _n, _n];
	_n
};

private ["_seedW","_seedE"];
_seedW = [WFBE_C_WEST_ID, west] call _fnSeedSide;
_seedE = [WFBE_C_EAST_ID, east] call _fnSeedSide;

["INFORMATION", Format ["Server_CmdTownLedger.sqf: Ledgers seeded. WEST=%1 EAST=%2 towns.", _seedW, _seedE]] Call WFBE_CO_FNC_LogContent;

//===================================================================================
// MAIN LOOP - one pass covers both sides per tick.
//===================================================================================
private ["_tick","_regenPerTick","_lastAuditT"];
_tick         = 0;
_regenPerTick = 1.0 / (_regenFullSec / _tickSec);
_lastAuditT   = 0;

while {!WFBE_GameOver} do {

	sleep _tickSec;
	_tick  = _tick + 1;

	private ["_fnTickSide"];
	_fnTickSide = {
		private ["_side","_logik","_ledger"];
		_side   = _this select 0;
		_logik  = (_side) Call WFBE_CO_FNC_GetSideLogic;
		_ledger = _logik getVariable ["WFBE_CTL_LEDGER", []];

		//--- Pick up newly-captured towns not yet in the ledger (pure array walk over
		//--- `towns`, which the seed pass already does once - no extra world scan added
		//--- beyond what B1 already budgets for).
		private ["_sideId"];
		_sideId = if (_side == west) then {WFBE_C_WEST_ID} else {WFBE_C_EAST_ID};
		{
			private ["_town","_tSide","_found"];
			_town  = _x;
			_tSide = _town getVariable ["sideID", WFBE_C_UNKNOWN_ID];
			if (_tSide == _sideId) then {
				_found = false;
				{if ((_x select 0) == _town) then {_found = true}} forEach _ledger;
				if (!_found) then {
					private ["_baseGroups","_rec"];
					_baseGroups = count ([_town, _side] Call WFBE_SE_FNC_GetTownGroups);
					_rec = [_town, _baseGroups, _captureSeed, 0, 0, diag_tickTime];
					_ledger set [count _ledger, _rec];
					_town setVariable ["wfbe_ctl_pending_ratio", -1];
					//--- Preserve a paid pre-capture investment for the new owner; the old-side
					//--- record drops below and this tick's normal apply pass consumes it once.
					if ((_town getVariable ["wfbe_ctl_pending_invest", 0]) <= 0) then {
						_town setVariable ["wfbe_ctl_pending_invest", 0];
						_town setVariable ["wfbe_ctl_pending_invest_cost", 0];
					};
					_town setVariable ["wfbe_ctl_lastspawn", 0];
					diag_log Format ["CTLSTAT|v1|%1|SEED|town=%2|str=%3", str _side, _town getVariable ["name", "?"], _captureSeed];
				};
			};
		} forEach towns;

		//--- Drop records for towns no longer owned by this side. Snapshot a staged paid
		//--- investment before dropping: the new owner's pickup above preserves it and the existing
		//--- apply pass credits it exactly once, rather than silently deleting paid strength.
		private ["_kept"];
		_kept = [];
		{
			private ["_rec","_town","_tSide","_pendingInvest"];
			_rec   = _x;
			_town  = _rec select 0;
			_tSide = _town getVariable ["sideID", WFBE_C_UNKNOWN_ID];
			_pendingInvest = _town getVariable ["wfbe_ctl_pending_invest", 0];
			if (_tSide == _sideId) then {
				_kept set [count _kept, _rec];
			} else {
				if (_pendingInvest > 0) then {diag_log Format ["CTLSTAT|v1|%1|CTL_INVEST_TRANSFER|town=%2|invest=%3|newSideId=%4", str _side, _town getVariable ["name", "?"], _pendingInvest, _tSide]};
			};
		} forEach _ledger;
		_ledger = _kept;
		
		//--- APPLY PENDING (fable/ctl-readback-singlewriter): the tick is the SOLE writer of
		//--- WFBE_CTL_LEDGER. External sites (deactivation readback, commander invest) publish
		//--- per-town scalars; apply them here in one single-threaded pass so there are no lost
		//--- updates. Order: attrition ratio first, then invest repair. Sentinel -1 = none pending.
		{
			private ["_recP","_pTown","_pRatio","_pInvest"];
			_recP   = _x;
			_pTown  = _recP select 0;
			_pRatio = _pTown getVariable ["wfbe_ctl_pending_ratio", -1];
			if (_pRatio >= 0) then {
				_recP set [2, ((_recP select 2) * _pRatio) max 0];
				_pTown setVariable ["wfbe_ctl_pending_ratio", -1];
				diag_log Format ["CTLSTAT|v1|%1|READBACK|town=%2|str=%3", str _side, _pTown getVariable ["name", "?"], _recP select 2];
			};
			_pInvest = _pTown getVariable ["wfbe_ctl_pending_invest", 0];
			if (_pInvest > 0) then {
				_recP set [2, ((_recP select 2) + _pInvest) min (missionNamespace getVariable ["AICOMV2_CTL_PAID_MAX", 1.5])];
				_recP set [4, time];
				_pTown setVariable ["wfbe_ctl_pending_invest", 0];
				_pTown setVariable ["wfbe_ctl_pending_invest_cost", 0];
				diag_log Format ["CTLSTAT|v1|%1|INVEST_APPLY|town=%2|str=%3", str _side, _pTown getVariable ["name", "?"], _recP select 2];
			};
			_recP set [3, _pTown getVariable ["wfbe_ctl_lastspawn", 0]];
		} forEach _ledger;

		//--- REGEN (B4) + publish wfbe_ctl_str for the materialization read-site (Task 4).
		{
			private ["_rec","_str","_regen","_regenTown"];
			_rec       = _x;
			_str       = _rec select 2;
			_regenTown = _rec select 0;
			if (_str < 1.0 && {!(_regenTown getVariable ["wfbe_active", false])}) then {
				_regen = [_regenPerTick, 0, 1.0 - _str] call _fnClamp;
				_rec set [2, _str + _regen];
			};
			_regenTown setVariable ["wfbe_ctl_str", _rec select 2];
		} forEach _ledger;

		_logik setVariable ["WFBE_CTL_LEDGER", _ledger];
		_ledger
	};

	private ["_ledgerW","_ledgerE"];
	_ledgerW = [west] call _fnTickSide;
	_ledgerE = [east] call _fnTickSide;

	//--------------------------------------------------------------------
	// AUDIT - every 300s, per side: towns/totalStr/totalBase/invested/denied.
	//--------------------------------------------------------------------
	if ((diag_tickTime - _lastAuditT) >= 300) then {
		_lastAuditT = diag_tickTime;
		private ["_fnAuditSide"];
		_fnAuditSide = {
			private ["_side","_ledger","_logik","_totalStr","_totalBase","_invested","_denied"];
			_side      = _this select 0;
			_ledger    = _this select 1;
			_logik     = (_side) Call WFBE_CO_FNC_GetSideLogic;
			_totalStr  = 0;
			_totalBase = count _ledger;
			_invested  = 0;
			{
				private ["_str"];
				_str = _x select 2;
				_totalStr = _totalStr + _str;
				_invested = _invested + ((_str - 1.0) max 0);
			} forEach _ledger;
			_denied = _logik getVariable ["WFBE_CTL_DENY_COUNT", 0];
			_logik setVariable ["WFBE_CTL_DENY_COUNT", 0];
			diag_log Format ["CTLSTAT|v1|%1|towns=%2|totalStr=%3|totalBase=%4|invested=%5|denied=%6",
				str _side, count _ledger, _totalStr, _totalBase, _invested, _denied];
		};
		[west, _ledgerW] call _fnAuditSide;
		[east, _ledgerE] call _fnAuditSide;
	};

};

["INFORMATION", "Server_CmdTownLedger.sqf: WFBE_GameOver detected. CTL exiting."] Call WFBE_CO_FNC_LogContent;
