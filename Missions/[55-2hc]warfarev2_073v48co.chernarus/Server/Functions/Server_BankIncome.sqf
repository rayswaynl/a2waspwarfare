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
Private ["_bank","_side","_interval","_payout","_logik","_hqAlive"];

_bank   = _this select 0;
_side   = _this select 1;

_interval = 300;   //--- 5 minutes between payouts.
_payout   = 2500;  //--- Per-player dividend.

["INFORMATION", Format ["Server_BankIncome.sqf: [%1] Income drip started for bank [%2].", str _side, _bank]] Call WFBE_CO_FNC_LogContent;

while {alive _bank} do {
	sleep _interval;

	if !(alive _bank) exitWith {};

	//--- Skip payout if the side has no deployed HQ (side is effectively defeated).
	_hqAlive = (_side) Call WFBE_CO_FNC_GetSideHQDeployStatus;
	if (!_hqAlive) then {
		["INFORMATION", Format ["Server_BankIncome.sqf: [%1] Payout skipped — no deployed HQ.", str _side]] Call WFBE_CO_FNC_LogContent;
	} else {
		//--- Pay every player on the owning side via the BankPayout client PVF.
		[_side, "BankPayout", [_payout]] Call WFBE_CO_FNC_SendToClients;
		["INFORMATION", Format ["Server_BankIncome.sqf: [%1] Dividend $%2 sent to all side players.", str _side, _payout]] Call WFBE_CO_FNC_LogContent;
	};
};

["INFORMATION", Format ["Server_BankIncome.sqf: [%1] Bank destroyed — income drip ended.", str _side]] Call WFBE_CO_FNC_LogContent;
