/* Server_BankIncome.sqf — per-bank income drip loop.
   Spawned server-side from Construction_MediumSite.sqf when a bank is built.
   Pays every player on the owning side 2500 every 5 minutes while the bank lives.
   Skips payout if the owning side has no deployed (alive) HQ — prevents free income
   while the side is wiped.

   Parameters:
     0 - bank object (the core structure)
     1 - owning side

   Payout mechanism: side-targeted BankPayout PVF which calls
   WFBE_CL_FNC_ChangeClientFunds on each receiving client.
   This mirrors TownCaptured.sqf's pattern for side-targeted client payouts.
*/
Private ["_bank","_side","_interval","_pool","_share","_playerCount","_logik","_hqAlive"];

_bank   = _this select 0;
_side   = _this select 1;

_interval = 300;   //--- 5 minutes between payouts.
_pool     = 6000;  //--- FIXED dividend pool per tick, split among living side players. (Steff 2026-06-11: 5000 -> 6000)
                   //--- Balance review 2026-06-10: a flat per-player 2500 scaled to $50k/tick on a
                   //--- 20-player side (3-5x town income); a fixed pool caps total injection.

["INFORMATION", Format ["Server_BankIncome.sqf: [%1] Income drip started for bank [%2].", str _side, _bank]] Call WFBE_CO_FNC_LogContent;

while {alive _bank} do {
	sleep _interval;

	if !(alive _bank) exitWith {};

	//--- Skip payout if the side has no deployed HQ (side is effectively defeated).
	_hqAlive = (_side) Call WFBE_CO_FNC_GetSideHQDeployStatus;
	if (!_hqAlive) then {
		["INFORMATION", Format ["Server_BankIncome.sqf: [%1] Payout skipped — no deployed HQ.", str _side]] Call WFBE_CO_FNC_LogContent;
	} else {
		//--- Split the pool among living players on the owning side.
		_playerCount = 0;
		{if ((isPlayer _x) && (alive _x) && (side _x == _side)) then {_playerCount = _playerCount + 1}} forEach playableUnits;
		_share = round (_pool / (_playerCount max 1));
		[_side, "BankPayout", [_share]] Call WFBE_CO_FNC_SendToClients;
		["INFORMATION", Format ["Server_BankIncome.sqf: [%1] Dividend $%2 x %3 players sent (pool %4).", str _side, _share, _playerCount, _pool]] Call WFBE_CO_FNC_LogContent;
	};
};

["INFORMATION", Format ["Server_BankIncome.sqf: [%1] Bank destroyed — income drip ended.", str _side]] Call WFBE_CO_FNC_LogContent;
