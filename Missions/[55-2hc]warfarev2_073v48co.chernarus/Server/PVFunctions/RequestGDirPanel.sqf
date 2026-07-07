/*
	RequestGDirPanel.sqf  (A1 Commissar Panel - Amendment to Lane 800 GUER Director)
	GUIDE-REV GR-2026-07-03a

	Client -> server request for a GUER player panel action (buy/qrf/counter/donate).
	Validates sender is resistance, panel+lane gates are on, then:
	  - Checks anti-spam (cooldown, contract limit)
	  - Checks group-budget headroom (AICOMV2_GDIR_GROUP_BUDGET_MAX)
	  - Debits wallet (personal + town donate-fund)
	  - Writes a GDIR_ORDER row to AICOMV2_GDIR_PENDING_ORDERS for the Director tick
	  - Emits GDIR_PANEL telemetry
	  - Pushes accept/deny result back to requesting client via GDirPanelResult PVF

	Parameters (from client via RequestGDirPanel SendToServer):
	  0 - player body (Object)
	  1 - verb   (String): "buy" | "qrf" | "counter" | "donate"
	  2 - townId (String): getVariable ["wfbe_name",""] of the target town
	  3 - product (String): "convoy"|"instant"|"qrfInsert"|"qrfGunship"|"qrfCombo"|"none"

	A2-OA-1.64 safe: no params/pushBack/isEqualTo/apply/findIf/selectRandom/distance2D/remoteExec.
	NSFETVAR3: never setVariable with a 3rd arg on missionNamespace.
	GROUPGETVAR: group getVariable 1-arg + isNil form only.
*/

private ["_player","_verb","_townId","_product"];

_player  = _this select 0;
_verb    = if (count _this > 1) then {_this select 1} else {"none"};
_townId  = if (count _this > 2) then {_this select 2} else {"none"};
_product = if (count _this > 3) then {_this select 3} else {"none"};

//--- Gate 1: lane + panel must be on.
if (!((missionNamespace getVariable ["AICOMV2_LANE_GUER_DIRECTOR", 0]) > 0)) exitWith {
	diag_log "AICOMSTAT|v3|DIRECTOR|GUER|0|GDIR_PANEL|verb=panel|deny=laneOff";
};
if (!((missionNamespace getVariable ["AICOMV2_GDIR_PANEL", 0]) > 0)) exitWith {
	diag_log "AICOMSTAT|v3|DIRECTOR|GUER|0|GDIR_PANEL|verb=panel|deny=panelOff";
};

//--- Gate 2: sender must be a live resistance player in a registered GUER team.
if (isNull _player || {!alive _player}) exitWith {};

private ["_senderSide"];
_senderSide = side _player;
if (!(_senderSide == resistance)) exitWith {
	diag_log Format ["AICOMSTAT|v3|DIRECTOR|GUER|0|GDIR_PANEL|verb=%1|town=%2|deny=wrongSide|sender=%3", _verb, _townId, name _player];
};

private ["_team"];
_team = grpNull;
if (!isNil {(group _player) getVariable "wfbe_side"}) then {_team = group _player};
if (isNull _team) exitWith {
	diag_log Format ["AICOMSTAT|v3|DIRECTOR|GUER|0|GDIR_PANEL|verb=%1|town=%2|deny=noTeam|sender=%3", _verb, _townId, name _player];
};

private ["_elmin"];
_elmin = floor (diag_tickTime / 60);

//--- Gate 2.5: towns list must be initialised (a hand-crafted PV can arrive pre-init and
//--- the forEach below would crash on nil).
if (isNil "WFBE_SE_Towns" || {count WFBE_SE_Towns == 0}) exitWith {
	diag_log Format ["AICOMSTAT|v3|DIRECTOR|GUER|%1|GDIR_PANEL|verb=%2|deny=townsNotReady|fundedBy=%3|pricePaid=0", _elmin, _verb, getPlayerUID _player];
};

//--- Gate 3: locate the town in WFBE_SE_Towns.
private ["_townObj","_townFound"];
_townObj   = objNull;
_townFound = false;
{
	if (!_townFound) then {
		if ((_x getVariable ["wfbe_name", ""]) == _townId) then {
			_townObj   = _x;
			_townFound = true;
		};
	};
} forEach WFBE_SE_Towns;
if (!_townFound || {isNull _townObj}) exitWith {
	diag_log Format ["AICOMSTAT|v3|DIRECTOR|GUER|%1|GDIR_PANEL|verb=%2|town=%3|deny=townNotFound|fundedBy=%4|pricePaid=0", _elmin, _verb, _townId, getPlayerUID _player];
	[getPlayerUID _player, "GDirPanelResult", ["deny", "Town not found.", _verb, _townId]] Call WFBE_CO_FNC_SendToClient;
};

//--- Gate 4: anti-spam - per-town cooldown.
private ["_cooldownSec","_panelCooldowns","_townCooldown","_nowT"];
_cooldownSec    = missionNamespace getVariable ["AICOMV2_GDIR_PANEL_COOLDOWN_SEC", 600];
_panelCooldowns = missionNamespace getVariable ["AICOMV2_GDIR_COOLDOWN_MAP", []];
_nowT           = diag_tickTime;
_townCooldown   = 0;
{
	if ((_x select 0) == _townId) then {
		_townCooldown = _x select 1;
	};
} forEach _panelCooldowns;
if ((_nowT - _townCooldown) < _cooldownSec) exitWith {
	private ["_remaining"];
	_remaining = round (_cooldownSec - (_nowT - _townCooldown));
	diag_log Format ["AICOMSTAT|v3|DIRECTOR|GUER|%1|GDIR_PANEL|verb=%2|town=%3|deny=cooldownActive|fundedBy=%4|pricePaid=0", _elmin, _verb, _townId, getPlayerUID _player];
	[getPlayerUID _player, "GDirPanelResult", ["deny", Format ["Cooldown active. %1s remaining.", _remaining], _verb, _townId]] Call WFBE_CO_FNC_SendToClient;
};

//--- Gate 5: contract limit (only for contract verbs).
private ["_contractsMax","_contracts","_townContractCount"];
_contractsMax      = missionNamespace getVariable ["AICOMV2_GDIR_PANEL_CONTRACTS_MAX", 2];
_contracts         = missionNamespace getVariable ["AICOMV2_GDIR_CONTRACT_RECORDS", []];
_townContractCount = 0;
{
	if ((_x select 2) == _townId && {(_x select 7) == "armed"}) then {
		_townContractCount = _townContractCount + 1;
	};
} forEach _contracts;
if ((_verb == "qrf" || {_verb == "counter"}) && {_townContractCount >= _contractsMax}) exitWith {
	diag_log Format ["AICOMSTAT|v3|DIRECTOR|GUER|%1|GDIR_PANEL|verb=%2|town=%3|deny=contractLimitReached|fundedBy=%4|pricePaid=0", _elmin, _verb, _townId, getPlayerUID _player];
	[getPlayerUID _player, "GDirPanelResult", ["deny", Format ["Contract limit (%1) reached on this town.", _contractsMax], _verb, _townId]] Call WFBE_CO_FNC_SendToClient;
};

//--- Gate 6: group-budget headroom (enforced here - base Lane 800 declared but never checked).
private ["_grpBudgetMax","_guerGrpCount"];
_grpBudgetMax = missionNamespace getVariable ["AICOMV2_GDIR_GROUP_BUDGET_MAX", 110];
_guerGrpCount = 0;
{
	if (side _x == resistance) then {_guerGrpCount = _guerGrpCount + 1};
} forEach allGroups;
//--- donate is pure economy - never materialises units, always safe.
if (!(_verb == "donate") && {_guerGrpCount >= _grpBudgetMax}) exitWith {
	diag_log Format ["AICOMSTAT|v3|DIRECTOR|GUER|%1|GDIR_PANEL|verb=%2|town=%3|deny=groupBudgetExceeded|fundedBy=%4|pricePaid=0|budget=%5/%6", _elmin, _verb, _townId, getPlayerUID _player, _guerGrpCount, _grpBudgetMax];
	[getPlayerUID _player, "GDirPanelResult", ["deny", "Group cap reached. Try again when units despawn.", _verb, _townId]] Call WFBE_CO_FNC_SendToClient;
};

//--- Compute dynamic price.
private ["_lfMin","_lfMax","_fps","_loadFactor"];
_lfMin = missionNamespace getVariable ["AICOMV2_GDIR_PANEL_LF_MIN", 1.0];
_lfMax = missionNamespace getVariable ["AICOMV2_GDIR_PANEL_LF_MAX", 2.5];
_fps   = diag_fps;
_loadFactor = _lfMin;
if (_fps < 10) then {_loadFactor = _lfMax};
if (_fps >= 10 && {_fps < 20}) then {_loadFactor = _lfMin + (_lfMax - _lfMin) * 0.5};
if ((_grpBudgetMax - _guerGrpCount) < 10) then {
	if (_loadFactor < _lfMax) then {_loadFactor = _lfMax};
};

//--- Scarcity: 1.0 + (step * recent buys on this town, decayed over time).
private ["_scarcityStep","_scarcityDecay","_scarcityRec","_scarcity"];
_scarcityStep  = missionNamespace getVariable ["AICOMV2_GDIR_PANEL_SCARCITY_STEP", 0.2];
_scarcityDecay = missionNamespace getVariable ["AICOMV2_GDIR_PANEL_SCARCITY_DECAY", 120];
_scarcityRec   = missionNamespace getVariable ["AICOMV2_GDIR_SCARCITY_MAP", []];
_scarcity = 1.0;
{
	if ((_x select 0) == _townId) then {
		private ["_age","_decayed","_rawSteps"];
		_age      = _nowT - (_x select 1);
		_decayed  = floor (_age / _scarcityDecay);
		_rawSteps = (_x select 2) - _decayed;
		if (_rawSteps < 0) then {_rawSteps = 0};
		_scarcity = 1.0 + (_scarcityStep * _rawSteps);
	};
} forEach _scarcityRec;

//--- Base price by verb+product.
private ["_basePrice"];
_basePrice = 0;
if (_verb == "buy") then {
	_basePrice = missionNamespace getVariable ["AICOMV2_GDIR_PANEL_PRICE_REINF", 800];
	if (_product == "instant") then {
		_basePrice = round (_basePrice * (missionNamespace getVariable ["AICOMV2_GDIR_PANEL_INSTANT_MULT", 1.5]));
	};
};
if (_verb == "qrf") then {
	if (_product == "qrfInsert")  then {_basePrice = missionNamespace getVariable ["AICOMV2_GDIR_PANEL_PRICE_QRF_INS", 600]};
	if (_product == "qrfGunship") then {_basePrice = missionNamespace getVariable ["AICOMV2_GDIR_PANEL_PRICE_QRF_GUN", 1200]};
	if (_product == "qrfCombo") then {
		_basePrice = round (
			(missionNamespace getVariable ["AICOMV2_GDIR_PANEL_PRICE_QRF_INS", 600]) +
			(missionNamespace getVariable ["AICOMV2_GDIR_PANEL_PRICE_QRF_GUN", 1200]) * 0.85
		);
	};
};
if (_verb == "counter") then {_basePrice = missionNamespace getVariable ["AICOMV2_GDIR_PANEL_PRICE_CTR_ATK", 500]};
//--- donate handled separately below.

private ["_price"];
_price = round (_basePrice * _scarcity * _loadFactor);
if (_price < _basePrice) then {_price = _basePrice}; //--- floor at base.

//--- Read wallet (team group variable).
private ["_wallet","_townFundKey","_townFund"];
_townFundKey = Format ["AICOMV2_GDIR_TOWN_FUND_%1", _townId];
_townFund    = missionNamespace getVariable [_townFundKey, 0];
_wallet      = _team getVariable "wfbe_funds";
if (isNil "_wallet") then {_wallet = 0};

//--- DONATE: debit wallet into town fund only, no unit action. cmdcon45: exitWith-form (was
//--- then{} + a bare inner exitWith - bare exitWith is a COMPILE error ("Missing ;", rc16 live)
//--- that nils the whole handler; and even compiled, then{} would FALL THROUGH into the buy
//--- pricing below after a donate. Top-scope if+exitWith ends the script here, both paths.
if (_verb == "donate") exitWith {
	private ["_donateAmt"];
	_donateAmt = 200; //--- fixed chunk per click.
	if (_wallet < _donateAmt) exitWith {
		diag_log Format ["AICOMSTAT|v3|DIRECTOR|GUER|%1|GDIR_PANEL|verb=donate|town=%2|deny=insufficientFunds|fundedBy=%3|pricePaid=0", _elmin, _townId, getPlayerUID _player];
		[getPlayerUID _player, "GDirPanelResult", ["deny", "Not enough funds to donate.", "donate", _townId]] Call WFBE_CO_FNC_SendToClient;
	};
	_wallet = _wallet - _donateAmt;
	_team setVariable ["wfbe_funds", _wallet, true];
	missionNamespace setVariable [_townFundKey, _townFund + _donateAmt];
	[_team] Call WFBE_SE_FNC_SyncFundsRecord;
	diag_log Format ["AICOMSTAT|v3|DIRECTOR|GUER|%1|GDIR_PANEL|verb=donate|town=%2|product=none|price=%3|fundedBy=%4|deny=none", _elmin, _townId, _donateAmt, getPlayerUID _player];
	[getPlayerUID _player, "GDirPanelResult", ["accept", Format ["Donated $%1 to %2 town fund.", _donateAmt, _townId], "donate", _townId]] Call WFBE_CO_FNC_SendToClient;
};

//--- Town fund covers price first, shortfall from personal wallet.
private ["_shortfall"];
_shortfall = _price - _townFund;
if (_shortfall < 0) then {_shortfall = 0};
if (_shortfall > _wallet) exitWith {
	diag_log Format ["AICOMSTAT|v3|DIRECTOR|GUER|%1|GDIR_PANEL|verb=%2|town=%3|product=%4|deny=insufficientFunds|fundedBy=%5|pricePaid=0|price=%6|wallet=%7|fund=%8", _elmin, _verb, _townId, _product, getPlayerUID _player, _price, _wallet, _townFund];
	[getPlayerUID _player, "GDirPanelResult", ["deny", Format ["Costs $%1. Wallet $%2, Town fund $%3.", _price, round _wallet, round _townFund], _verb, _townId]] Call WFBE_CO_FNC_SendToClient;
};

//--- Debit: town fund first, then wallet for remainder.
private ["_fundUsed"];
_fundUsed = _price - _shortfall;
if (_fundUsed > 0) then {
	missionNamespace setVariable [_townFundKey, _townFund - _fundUsed];
};
_wallet = _wallet - _shortfall;
_team setVariable ["wfbe_funds", _wallet, true];
[_team] Call WFBE_SE_FNC_SyncFundsRecord;

//--- Write cooldown entry.
private ["_newCooldowns","_cdReplaced"];
_newCooldowns = [];
_cdReplaced   = false;
{
	if ((_x select 0) == _townId) then {
		_newCooldowns set [count _newCooldowns, [_townId, _nowT]];
		_cdReplaced = true;
	} else {
		_newCooldowns set [count _newCooldowns, _x];
	};
} forEach _panelCooldowns;
if (!_cdReplaced) then {_newCooldowns set [count _newCooldowns, [_townId, _nowT]]};
missionNamespace setVariable ["AICOMV2_GDIR_COOLDOWN_MAP", _newCooldowns];

//--- Update scarcity counter.
private ["_newScarcity","_scReplaced"];
_newScarcity = [];
_scReplaced  = false;
{
	if ((_x select 0) == _townId) then {
		private ["_existSteps"];
		_existSteps = _x select 2;
		_newScarcity set [count _newScarcity, [_townId, _nowT, _existSteps + 1]];
		_scReplaced = true;
	} else {
		_newScarcity set [count _newScarcity, _x];
	};
} forEach _scarcityRec;
if (!_scReplaced) then {_newScarcity set [count _newScarcity, [_townId, _nowT, 1]]};
missionNamespace setVariable ["AICOMV2_GDIR_SCARCITY_MAP", _newScarcity];

//--- Emit GDIR_ORDER for the Director tick to consume.
private ["_pendingOrders","_orderKind"];
_orderKind = "reinforce";
if (_verb == "qrf")     then {_orderKind = "qrfContract"};
if (_verb == "counter") then {_orderKind = "counterContract"};
_pendingOrders = missionNamespace getVariable ["AICOMV2_GDIR_PENDING_ORDERS", []];
_pendingOrders set [count _pendingOrders, [_orderKind, _townId, _product, getPlayerUID _player, _price, _nowT]];
missionNamespace setVariable ["AICOMV2_GDIR_PENDING_ORDERS", _pendingOrders];

//--- Write contract record for qrf/counter verbs.
if (_verb == "qrf" || {_verb == "counter"}) then {
	private ["_contractId","_contractKind","_newContracts"];
	_contractId   = Format ["ctr_%1_%2", _townId, round (_nowT * 1000)];
	_contractKind = _product;
	if (_verb == "counter") then {_contractKind = "counterAttack"};
	_newContracts = missionNamespace getVariable ["AICOMV2_GDIR_CONTRACT_RECORDS", []];
	_newContracts set [count _newContracts, [_contractId, _contractKind, _townId, getPlayerUID _player, _price, _nowT, 0, "armed"]];
	missionNamespace setVariable ["AICOMV2_GDIR_CONTRACT_RECORDS", _newContracts];
};

//--- Telemetry.
diag_log Format ["AICOMSTAT|v3|DIRECTOR|GUER|%1|GDIR_PANEL|verb=%2|town=%3|product=%4|price=%5|fundedBy=%6|deny=none", _elmin, _verb, _townId, _product, _price, getPlayerUID _player];

//--- Push result to client.
[getPlayerUID _player, "GDirPanelResult", ["accept", Format ["Order placed: $%1 debited. Action: %2.", _price, _verb], _verb, _townId]] Call WFBE_CO_FNC_SendToClient;

["INFORMATION", Format ["RequestGDirPanel: verb=%1 product=%2 town=%3 price=%4 fundedBy=%5.", _verb, _product, _townId, _price, name _player]] Call WFBE_CO_FNC_LogContent;
