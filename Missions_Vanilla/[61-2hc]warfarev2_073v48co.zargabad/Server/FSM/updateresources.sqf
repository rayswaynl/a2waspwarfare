private["_is","_ii","_awaits","_incomeCoef","_divisor","_commander_enabled","_currency_system","_logik","_playerOldScore","_playerNewScore","_scoreDiff","_income","_income_player","_income_commander","_supply","_comTeam","_paycheck", "_supply_max_limit"];

_is = missionNamespace getVariable "WFBE_C_ECONOMY_INCOME_SYSTEM";
_ii = missionNamespace getVariable "WFBE_C_ECONOMY_INCOME_INTERVAL";

_awaits = _ii;
_incomeCoef = 1;
_divisor = 0;
_commander_enabled = if ((missionNamespace getVariable "WFBE_C_AI_COMMANDER_ENABLED") > 0) then {true} else {false};
_currency_system = missionNamespace getVariable "WFBE_C_ECONOMY_CURRENCY_SYSTEM";
_supply_max_limit = missionNamespace getVariable "WFBE_C_ECONOMY_SUPPLY_MAX_TEAM_LIMIT";
_playerOldScore = 0;
_playerNewScore = 0;

if (_is == 3) then {
	_incomeCoef = missionNamespace getVariable "WFBE_C_ECONOMY_INCOME_COEF";
	_divisor = missionNamespace getVariable "WFBE_C_ECONOMY_INCOME_DIVIDED";
};

while {!gameOver} do {

	//--- B36.1 (Ray 2026-06-15): scale AI-commander CASH income INVERSELY to HUMAN player count. The team
	//--- curve in AI_Commander_Teams.sqf fields the MOST teams at LOW pop, so the funding need is HIGHEST on
	//--- a near-empty server. So the income boost is +BONUS per player UNDER the REF pop (highest at 0
	//--- players, tapering to base income at REF+) - the MIRROR of a normal up-with-players scaler. Capped.
	//--- + capped. Human count mirrors MonitorPlayerCount.sqf (isPlayer in allUnits minus live HCs).
	private ["_pcN2","_hcN2","_pcMult","_baseMult"];
	_pcN2 = {isPlayer _x} count allUnits;
	_hcN2 = {!isNull _x && {!isNull leader _x} && {alive leader _x}} count (missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []]);
	_pcN2 = (_pcN2 - _hcN2) max 0;
	_baseMult = missionNamespace getVariable ["WFBE_C_AI_COMMANDER_INCOME_MULT", 1.5];
	_pcMult = _baseMult * (1 + ((if ((missionNamespace getVariable ["WFBE_C_AICOM_BANKING_VALVE", 1]) > 0) then {missionNamespace getVariable ["WFBE_C_AICOM_INCOME_PC_BONUS_VALVE", 0.045]} else {missionNamespace getVariable ["WFBE_C_AICOM_INCOME_PC_BONUS", 0.06]}) * (((missionNamespace getVariable ["WFBE_C_AICOM_INCOME_PC_REF", 10]) - _pcN2) max 0)));  //--- B36.1 INVERTED (Ray 2026-06-15): boost is +BONUS per player UNDER REF (default 10) so CASH income is HIGHEST at LOW pop (funds the 8-team curve flood), tapering to base at REF+ players. Was (* _pcN2) = boost-with-MORE-players; flipped to (* (REF-pc)).
	_pcMult = _pcMult min (missionNamespace getVariable ["WFBE_C_AICOM_INCOME_MULT_MAX", 3.0]);

	//--- punchy-AICOM TIME-CURVE (Ray 2026-06-17): gentle, LATE income boost composed onto _pcMult.
	//--- Flat (=FLOOR) until START, then a smoothstep S-curve over WINDOW up to CEIL - rewards long
	//--- matches with late-game punch, NOT an early snowball. 'time' = mission elapsed seconds (server clock).
	private ["_tcFloor","_tcCeil","_tcStart","_tcWindow","_tcRamp","_tcMult"];
	_tcFloor  = missionNamespace getVariable ["WFBE_C_AICOM_TIMECURVE_FLOOR", 1.0];
	_tcCeil   = missionNamespace getVariable ["WFBE_C_AICOM_TIMECURVE_CEIL", 1.8];
	_tcStart  = missionNamespace getVariable ["WFBE_C_AICOM_TIMECURVE_START", 7200];
	_tcWindow = (missionNamespace getVariable ["WFBE_C_AICOM_TIMECURVE_WINDOW", 3600]) max 1;
	_tcRamp   = (((time - _tcStart) max 0) min _tcWindow) / _tcWindow;   //--- 0.0 -> 1.0 linear within the window
	_tcRamp   = _tcRamp * _tcRamp * (3 - (2 * _tcRamp));                 //--- smoothstep 3t^2-2t^3 (gentle start AND gentle finish)
	_tcMult   = _tcFloor + ((_tcCeil - _tcFloor) * _tcRamp);
	_pcMult   = _pcMult * _tcMult;

	//--- ENDGAME SOFT-FORCING (claude-gaming 2026-06-29, SYSTEM 2): fold the global income-taper multiplier
	//--- published by server_victory_threeway.sqf into _pcMult so the escalating squeeze reaches every AICOM
	//--- town-income credit below (the four ChangeAICommanderFunds town-income paths). Default 1.0 when the
	//--- feature is dark (server_victory_threeway publishes a neutral 1) so this is a strict no-op until armed.
	//--- Applied to AICOM CASH income only (never player paychecks or the side-wide supply credit). A2-OA-safe.
	if ((missionNamespace getVariable ["WFBE_C_ENDGAME_FORCE_ENABLE", 0]) > 0) then {
		_pcMult = _pcMult * (missionNamespace getVariable ["WFBE_ENDGAME_FORCE_MULT", 1]);
	};


	{
		_logik = (_x) Call WFBE_CO_FNC_GetSideLogic;
		_income = 0;
		_income_player = 0;
		_income_commander = 0;
		_supply = 0;

		_supply =  (_x) Call WFBE_CO_FNC_GetTownsSupply;
		private "_sideNow"; _sideNow = _x; //--- patch4: capture side at forEach-body scope so the TOWN-STALL FIX + FUNDS-SINK blocks below (outside the supply<cap then-block) see a live side.
		//--- B74.1 (Ray 2026-06-23): AICOM income TAPER for the territorial leader - diminishing per-town funds above
		//--- TAPER_TOWNS so a runaway leader's treasury can't compound unbounded (soak: leader ran to +281k/tick). Each
		//--- town beyond the threshold contributes only TAPER_RATE of a normal town. AICOM-ONLY: applied ONLY to the
		//--- ChangeAICommanderFunds calls below, never to player paychecks or supply. _aicomTaper = 1.0 at/below threshold.
		private ["_aicomTaper","_taperTowns","_townCnt"];
		_aicomTaper = 1;
		_taperTowns = missionNamespace getVariable ["WFBE_C_AICOM_INCOME_TAPER_TOWNS", 8];
		_townCnt = (_x) Call GetTownsHeld;
		if (_townCnt > _taperTowns) then {
			_aicomTaper = (_taperTowns + ((_townCnt - _taperTowns) * (missionNamespace getVariable ["WFBE_C_AICOM_INCOME_TAPER_RATE", 0.4]))) / _townCnt;
		};
		//////
		if(_supply  < _supply_max_limit) then {

			_income = if (_is != 3) then {_supply} else {round(_supply * _incomeCoef)};

			switch (_is) do {
				case 2: {_income = round(_income / 2)};
				case 3: {
					_income_player = round(_income * (((100 - (_logik getVariable "wfbe_commander_percent"))/100)/((_logik getVariable "wfbe_teams_count") max 1)));
					_income_commander = round((_income * ((_logik getVariable "wfbe_commander_percent")/100)) / _divisor) + _income_player;
				};
				case 4: {
					_income_player = round(_income * 1.5 * (100 - (_logik getVariable "wfbe_commander_percent"))/100);
					_income_commander = round((_income * 1.5 - _income_player)*(_logik getVariable "wfbe_teams_count")) + _income_player;
				};
			};

			//--- rc27 hotfix (patch4): _sideNow now captured at forEach-body scope above; was declared INSIDE the _income>0 block but read
			//--- by the stipend/town-stall blocks after it - a zero-income side (GUER at round start, now that the
			//--- lockout is off) skipped the declaration and flooded the RPT with Undefined variable _sideNow,
			//--- killing the AI stipend/stall-refill for that side. Capture the side BEFORE the branch.
			if (_income > 0) then {
				// diag_log format ["Calling update tick (town supply income) for team %1, supply addition: %2",_x, _supply];
				if (_currency_system == 0) then {[_x, round(_supply * (missionNamespace getVariable ["WFBE_C_ECONOMY_SUPPLY_INCOME_MULT", 1])), format ["Update tick (town supply income) for team %1.",_x], true] Call ChangeSideSupply};

				_comTeam = (_x) Call WFBE_CO_FNC_GetCommanderTeam;
				if (isNull _comTeam) then {_comTeam = grpNull};

				{
					if !(isNil '_x') then {
						_paycheck = 0;
						switch (_is) do {
							case 3: {_paycheck = if (_comTeam != _x) then {_income_player} else {_income_commander}};
							case 4: {_paycheck = if (_comTeam != _x) then {_income_player} else {_income_commander}};
							default {if !(isPlayer (leader _x)) then {_paycheck = _income}};
						};

						if (_paycheck != 0) then {[_x, _paycheck] Call WFBE_CO_FNC_ChangeTeamFunds};
					};
				} forEach (_logik getVariable "wfbe_teams");

				if ((isNull(_sideNow Call WFBE_CO_FNC_GetCommanderTeam) || {(missionNamespace getVariable ["WFBE_C_AI_COMMANDER_HYBRID_REFILL", 1]) > 0}) && _commander_enabled) then {
					if (((_sideNow) Call GetAICommanderFunds) < (missionNamespace getVariable ["WFBE_C_AICOM_WEALTH_CAP", 1500000])) then {[_sideNow, round(_income * _pcMult * _aicomTaper)] Call ChangeAICommanderFunds}; //--- B752 (Ray 2026-06-25) anti-hoard funds-cap: stop town income above WFBE_C_AICOM_WEALTH_CAP (the 12h soak ballooned to 18M; the side still keeps millions to spend, the number just stops being meaningless).
				};
			};

			//--- V0.4.1: synthetic MONEY drip for the AI commander - never synthetic supply.
			//--- Flows even with zero town income so PvE on a near-empty server stays fun
			//--- (the AI keeps fielding armies); supply remains the real shared war resource.
			if ((isNull(_sideNow Call WFBE_CO_FNC_GetCommanderTeam) || {(missionNamespace getVariable ["WFBE_C_AI_COMMANDER_HYBRID_REFILL", 1]) > 0}) && _commander_enabled) then {
				if (((_sideNow) Call GetAICommanderFunds) < (missionNamespace getVariable ["WFBE_C_AICOM_WEALTH_CAP", 1500000])) then {[_sideNow, missionNamespace getVariable ["WFBE_C_AI_COMMANDER_INCOME_STIPEND", 25]] Call ChangeAICommanderFunds}; //--- B752: same anti-hoard cap on the stipend drip.
			};

		};

		//--- TOWN-STALL FIX (funds-famine): AI-commander FUNDS must keep flowing even when the
		//--- side's SUPPLY is at/over the cap. The supply-cap gate above correctly stops SUPPLY
		//--- accumulation past the limit, but it ALSO suppressed the AI commander's funds income
		//--- and stipend - so when the AI banked supply past the cap (it hoards supply), its funds
		//--- drained to $0, it could no longer buy units, and the war stalled (towns stopped
		//--- changing hands all night; AI stuck ~8 towns). Funds are a SEPARATE currency from
		//--- supply, so top them up here whenever the cap suppressed them. Never synthesises supply.
		if (_supply >= _supply_max_limit && {isNull(_sideNow Call WFBE_CO_FNC_GetCommanderTeam) || {(missionNamespace getVariable ["WFBE_C_AI_COMMANDER_HYBRID_REFILL", 1]) > 0}} && {_commander_enabled}) then {
			_income = if (_is != 3) then {_supply} else {round(_supply * _incomeCoef)};
			if (_is == 2) then {_income = round(_income / 2)};
			if (_income > 0) then {
				if (((_sideNow) Call GetAICommanderFunds) < (missionNamespace getVariable ["WFBE_C_AICOM_WEALTH_CAP", 1500000])) then {[_sideNow, round(_income * _pcMult * _aicomTaper)] Call ChangeAICommanderFunds}; //--- B752 (Ray 2026-06-25) anti-hoard funds-cap: stop town income above WFBE_C_AICOM_WEALTH_CAP (the 12h soak ballooned to 18M; the side still keeps millions to spend, the number just stops being meaningless).
			};
			if (((_sideNow) Call GetAICommanderFunds) < (missionNamespace getVariable ["WFBE_C_AICOM_WEALTH_CAP", 1500000])) then {[_sideNow, missionNamespace getVariable ["WFBE_C_AI_COMMANDER_INCOME_STIPEND", 25]] Call ChangeAICommanderFunds}; //--- B752: same anti-hoard cap on the stipend drip.
		};

		//--- FUNDS-SINK (claude-gaming 2026-06-29, SYSTEM 1): on this same income cadence, give a rich AICOM somewhere to
		//--- spend its hoard - convert money over WFBE_C_AICOM_FUNDS_SINK_THRESHOLD into OFFENSE (heavy push wave + veteran
		//--- founding + a discounted drain). Hooked HERE (a place this cluster owns) instead of editing AI_Commander.sqf.
		//--- DEFAULT-OFF + nil-guarded: the worker self-gates on WFBE_C_AICOM_FUNDS_SINK_ENABLE and early-exits when dark,
		//--- so this is a no-op until armed. _x = side (commander treasury is per-side; GUER already excluded by the forEach).
		if ((missionNamespace getVariable ["WFBE_C_AICOM_FUNDS_SINK_ENABLE", 0]) > 0 && _commander_enabled && {!isNil "WFBE_SE_FNC_AI_Com_FundsSink"}) then {
			(_sideNow) Call WFBE_SE_FNC_AI_Com_FundsSink;
		};

	} forEach (WFBE_PRESENTSIDES - [resistance]); //--- GUER excluded: funds-only stipend, no supply/commander economy

	_awaits = (_ii) Call GetSleepFPS;
	sleep _awaits;
};