/* Server_BankIncome.sqf — per-bank income drip loop.
   Spawned server-side from Construction_MediumSite.sqf when a bank is built.
   Pays a fixed $6,000 side pool split among living owning-side players every 5 minutes.
   Skips payout if the owning side has no deployed (alive) HQ — prevents free income
   while the side is wiped.

   Parameters:
     0 - bank object (the core structure)
     1 - owning side

   Payout mechanism (J1 funds authority): the server credits each eligible player group directly
   with an exact base-and-remainder split; the side-targeted BankPayout PVF keeps only the chat notification.
   This mirrors TownCaptured.sqf's pattern for side-targeted client payouts.
*/
Private ["_bank","_side","_interval","_pool","_share","_playerCount","_logik","_hqAlive","_eligible","_i","_remainder","_payout"];

_bank   = _this select 0;
_side   = _this select 1;

_interval = 300;   //--- 5 minutes between payouts.
_pool     = 6000;  //--- FIXED dividend pool per tick, split among living side players. (Steff 2026-06-11: 5000 -> 6000)
                   //--- Balance review 2026-06-10: a flat per-player 2500 scaled to $50k/tick on a
                   //--- 20-player side (3-5x town income); a fixed pool caps total injection.

["INFORMATION", Format ["Server_BankIncome.sqf: [%1] Income drip started for bank [%2].", str _side, _bank]] Call WFBE_CO_FNC_LogContent;

while {alive _bank && {!WFBE_GameOver}} do {
	sleep _interval;

	if !(alive _bank) exitWith {};

	//--- Skip payout if the side has no deployed HQ (side is effectively defeated).
	_hqAlive = (_side) Call WFBE_CO_FNC_GetSideHQDeployStatus;
	if (!_hqAlive) then {
		["INFORMATION", Format ["Server_BankIncome.sqf: [%1] Payout skipped — no deployed HQ.", str _side]] Call WFBE_CO_FNC_LogContent;
	} else {
		//--- Split the fixed pool exactly among living players on the owning side. A rounded per-player
		//--- share can mint or lose funds whenever the player count does not divide the pool.
		_eligible = [];
		{
			if ((isPlayer _x) && {alive _x} && {side _x == _side} && {!((name _x) call WFBE_CO_FNC_IsHcName)}) then {
				_eligible set [count _eligible, _x];
			};
		} forEach playableUnits;
		_playerCount = count _eligible;
		if (_playerCount > 0) then {
			_share = floor (_pool / _playerCount);
			_remainder = _pool - (_share * _playerCount);
			_i = 0;
			{
				_payout = _share;
				if (_i < _remainder) then {_payout = _payout + 1};
				[group _x, _payout] Call WFBE_CO_FNC_ChangeTeamFunds;
				_i = _i + 1;
			} forEach _eligible;
			[_side, "BankPayout", [_pool, _playerCount]] Call WFBE_CO_FNC_SendToClients;
			["INFORMATION", Format ["Server_BankIncome.sqf: [%1] Exact dividend pool %2: base $%3 x %4 players, remainder %5.", str _side, _pool, _share, _playerCount, _remainder]] Call WFBE_CO_FNC_LogContent;
		};
	};
};

["INFORMATION", Format ["Server_BankIncome.sqf: [%1] Bank destroyed — income drip ended.", str _side]] Call WFBE_CO_FNC_LogContent;
