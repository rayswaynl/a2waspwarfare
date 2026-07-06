private ["_side","_sideMatches","_teamSkill","_playerStats","_playerScoreTotal","_playerTimePlayedTotal","_miniSleep","_playerScore","_playerSkill"];

_side = _this select 0;

_teamSkill = 0;
_miniSleep = 0.10;

["INFORMATION", Format ["GetTeamScoreMonitor.sqf: Checking stats of side: [%1].", _side]] Call WFBE_CO_FNC_LogContent;

{
	_sideMatches = (_side == side _x);
	
	if (isPlayer _x && _sideMatches) then {
		_playerScore = score _x;
		// ["INFORMATION", Format["GetTeamScore.sqf: Calling database: RETRIEVE: player UID: %1, _playerScore: %2", getPlayerUID _x, _playerScore]] Call WFBE_CO_FNC_LogContent;
		_playerStats = ["RETRIEVE", getPlayerUID _x] call WFBE_SE_FNC_CallDatabaseRetrieve;
		// ["INFORMATION", Format["GetTeamScore.sqf: Called database! RETRIEVE: results: _playerStats: %1", _playerStats]] Call WFBE_CO_FNC_LogContent;
		_playerScoreTotal = _playerStats select 0;
		_playerTimePlayedTotal = _playerStats select 1;

		//--- tp2 (claude): _playerSkill not in original private list; callDatabaseRetrieve's own
		//--- private ["_playerSkill"] resets it to nil in the shared call scope. Pre-init to 0
		//--- ensures line 30 (_teamSkill + _playerSkill) never reads nil even if the division
		//--- path throws (e.g. _playerScoreTotal nil from a DB race on ZG/TK).
		_playerSkill = 0;
		//--- task46 (claude): zero-guard the divisor. A never-seen UID returns _playerTimePlayedTotal=0
		//--- (DB sentinel can also drift to 0) -> div-by-zero. Mirror the [1,1] fallback used in
		//--- mainLoop.sqf: 0 time means "no playtime yet", so contribute 0 skill rather than crash.
		if (_playerTimePlayedTotal == 0) then {
			_playerSkill = 0;
		} else {
			_playerSkill = _playerScoreTotal / _playerTimePlayedTotal;
		};

		_teamSkill = _teamSkill + _playerSkill;
		
		uiSleep _miniSleep;
	};

} forEach playableUnits; //--- PERF: player slots not 300+ AI (isPlayer guard keeps behaviour identical; see mainLoop.sqf)

// ["INFORMATION", Format["GetTeamScoreMonitor.sqf: Team [%1] total skill is: [%2].", _side, _teamSkill]] Call WFBE_CO_FNC_LogContent;

_teamSkill