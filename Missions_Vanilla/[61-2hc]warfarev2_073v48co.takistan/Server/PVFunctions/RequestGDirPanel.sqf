/*
	RequestGDirPanel.sqf  (A1 Commissar Panel - Amendment to Lane 800 GUER Director)
	GUIDE-REV GR-2026-07-08a

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
	  2 - townId (String): getVariable ["name",""] of the target town
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
if (isNil "towns" || {count towns == 0}) exitWith { //--- #815: master roster is `towns`
	diag_log Format ["AICOMSTAT|v3|DIRECTOR|GUER|%1|GDIR_PANEL|verb=%2|deny=townsNotReady|fundedBy=%3|pricePaid=0", _elmin, _verb, getPlayerUID _player];
};


//--- Hotfix: _nowT is used by the quote verb below (rate-limit + scarcity age) but was
//--- first assigned only in the paid path further down - undefined here killed every
//--- quote reply, leaving the panel stuck on "Fetching prices...".
private ["_nowT"];
_nowT = diag_tickTime;

//--- QUOTE VERB: read-only price estimate, no debit, no cooldown, no contract write.
//--- Passes Gate 1/2/2.5 (side+lane+towns), skips Gate 3-6 (town-find is done to get scarcity).
//--- Rate limited: 2s per player to prevent spam.
if (_verb == "quote") exitWith {
	private ["_quoteRateKey","_quoteLastT"];
	_quoteRateKey = Format ["AICOMV2_GDIR_QUOTE_RATE_%1", getPlayerUID _player];
	_quoteLastT   = missionNamespace getVariable [_quoteRateKey, -99];
	if ((_nowT - _quoteLastT) < 2) exitWith {
		diag_log Format ["AICOMSTAT|v3|DIRECTOR|GUER|%1|GDIR_PANEL|verb=quote|town=%2|deny=rateLimit|fundedBy=%3", _elmin, _townId, getPlayerUID _player];
	};
	missionNamespace setVariable [_quoteRateKey, _nowT];

	//--- Locate town for scarcity calc (no error reply on miss - client just keeps ~est. labels).
	private ["_qTownObj","_qFound"];
	_qTownObj = objNull;
	_qFound   = false;
	{
		if (!_qFound) then {
			if ((_x getVariable ["name", ""]) == _townId) then {
				_qTownObj = _x;
				_qFound   = true;
			};
		};
	} forEach towns;

	//--- Compute scarcity for this town.
	private ["_qScarcityStep","_qScarcityDecay","_qScarcityRec","_qScarcity"];
	_qScarcityStep  = missionNamespace getVariable ["AICOMV2_GDIR_PANEL_SCARCITY_STEP", 0.2];
	_qScarcityDecay = missionNamespace getVariable ["AICOMV2_GDIR_PANEL_SCARCITY_DECAY", 120];
	_qScarcityRec   = missionNamespace getVariable ["AICOMV2_GDIR_SCARCITY_MAP", []];
	_qScarcity = 1.0;
	{
		if ((_x select 0) == _townId) then {
			private ["_qAge","_qDecayed","_qRawSteps"];
			_qAge       = _nowT - (_x select 1);
			_qDecayed   = floor (_qAge / _qScarcityDecay);
			_qRawSteps  = (_x select 2) - _qDecayed;
			if (_qRawSteps < 0) then {_qRawSteps = 0};
			_qScarcity = 1.0 + (_qScarcityStep * _qRawSteps);
		};
	} forEach _qScarcityRec;

	//--- loadFactor at quote time (server FPS, same formula as real request).
	private ["_qLfMin","_qLfMax","_qFps","_qLf"];
	_qLfMin = missionNamespace getVariable ["AICOMV2_GDIR_PANEL_LF_MIN", 1.0];
	_qLfMax = missionNamespace getVariable ["AICOMV2_GDIR_PANEL_LF_MAX", 2.5];
	_qFps   = diag_fps;
	_qLf    = _qLfMin;
	if (_qFps < 10) then {_qLf = _qLfMax};
	if (_qFps >= 10 && {_qFps < 20}) then {_qLf = _qLfMin + (_qLfMax - _qLfMin) * 0.5};
	private ["_qGrpBudgetMax","_qGuerGrpCount"];
	_qGrpBudgetMax = missionNamespace getVariable ["AICOMV2_GDIR_GROUP_BUDGET_MAX", 110];
	_qGuerGrpCount = 0;
	{
		if (side _x == resistance) then {_qGuerGrpCount = _qGuerGrpCount + 1};
	} forEach allGroups;
	if ((_qGrpBudgetMax - _qGuerGrpCount) < 10) then {
		if (_qLf < _qLfMax) then {_qLf = _qLfMax};
	};

	//--- Compute estimated prices for all 6 actions.
	private ["_qBaseReinf","_qBaseInstMult","_qBaseIns","_qBaseGun","_qBaseCtr","_qBaseRelief"];
	_qBaseReinf   = missionNamespace getVariable ["AICOMV2_GDIR_PANEL_PRICE_REINF", 1600];
	_qBaseInstMult = missionNamespace getVariable ["AICOMV2_GDIR_PANEL_INSTANT_MULT", 1.5];
	_qBaseIns     = missionNamespace getVariable ["AICOMV2_GDIR_PANEL_PRICE_QRF_INS", 1200];
	_qBaseGun     = missionNamespace getVariable ["AICOMV2_GDIR_PANEL_PRICE_QRF_GUN", 2400];
	_qBaseCtr     = missionNamespace getVariable ["AICOMV2_GDIR_PANEL_PRICE_CTR_ATK", 1000];
	//--- fable/ew-guer: relief squad base price (same key RequestGDirPanel reads for the real debit below).
	_qBaseRelief  = missionNamespace getVariable ["AICOMV2_GDIR_PANEL_PRICE_RELIEF", 800];

	private ["_qPConvoy","_qPInstant","_qPIns","_qPGun","_qPCombo","_qPCtr","_qPRelief"];
	_qPConvoy  = round (_qBaseReinf * _qScarcity * _qLf);
	if (_qPConvoy  < _qBaseReinf) then {_qPConvoy  = _qBaseReinf};
	_qPInstant = round (_qBaseReinf * _qBaseInstMult * _qScarcity * _qLf);
	if (_qPInstant < round (_qBaseReinf * _qBaseInstMult)) then {_qPInstant = round (_qBaseReinf * _qBaseInstMult)};
	_qPIns     = round (_qBaseIns  * _qScarcity * _qLf);
	if (_qPIns   < _qBaseIns)  then {_qPIns  = _qBaseIns};
	_qPGun     = round (_qBaseGun  * _qScarcity * _qLf);
	if (_qPGun   < _qBaseGun)  then {_qPGun  = _qBaseGun};
	_qPCombo   = round (_qBaseIns * _qScarcity * _qLf + _qBaseGun * _qScarcity * _qLf * 0.85);
	if (_qPCombo < round (_qBaseIns + _qBaseGun * 0.85)) then {_qPCombo = round (_qBaseIns + _qBaseGun * 0.85)};
	_qPCtr     = round (_qBaseCtr  * _qScarcity * _qLf);
	if (_qPCtr   < _qBaseCtr)  then {_qPCtr  = _qBaseCtr};
	_qPRelief  = round (_qBaseRelief * _qScarcity * _qLf);
	if (_qPRelief < _qBaseRelief) then {_qPRelief = _qBaseRelief};

	//--- Reply: status "quote", message = comma-joined prices, verb = "quote", townId = townId.
	//--- Payload: [convoy, instant, qrfInsert, qrfGunship, qrfCombo, counter, donate(fixed 200), relief].
	//--- fable/ew-guer: appended relief as index 7 (8th value) - existing "count _prices < 7" client
	//--- gates in GUI_Menu_GuerCommissar.sqf stay backward-compatible (8 >= 7).
	private ["_qPriceStr"];
	_qPriceStr = Format ["%1,%2,%3,%4,%5,%6,200,%7", _qPConvoy, _qPInstant, _qPIns, _qPGun, _qPCombo, _qPCtr, _qPRelief];
	diag_log Format ["AICOMSTAT|v3|DIRECTOR|GUER|%1|GDIR_PANEL|verb=quote|town=%2|fundedBy=%3|prices=%4", _elmin, _townId, getPlayerUID _player, _qPriceStr];
	[_player, "GDirPanelResult", ["quote", _qPriceStr, "quote", _townId]] Call WFBE_CO_FNC_SendToClient;
};

//--- Gate 3: locate the town in `towns`.
private ["_townObj","_townFound"];
_townObj   = objNull;
_townFound = false;
{
	if (!_townFound) then {
		if ((_x getVariable ["name", ""]) == _townId) then {
			_townObj   = _x;
			_townFound = true;
		};
	};
} forEach towns;
if (!_townFound || {isNull _townObj}) exitWith {
	diag_log Format ["AICOMSTAT|v3|DIRECTOR|GUER|%1|GDIR_PANEL|verb=%2|town=%3|deny=townNotFound|fundedBy=%4|pricePaid=0", _elmin, _verb, _townId, getPlayerUID _player];
	[_player, "GDirPanelResult", ["deny", "Town not found.", _verb, _townId]] Call WFBE_CO_FNC_SendToClient;
};

//--- P0 (fable/gdir-ledger-conservation): validate CURRENT permitted ownership BEFORE any debit. The panel
//--- previously validated existence only - a paid order on a town GUER no longer holds debited the wallet,
//--- then no-opped downstream. Same permitted set as the Director ledger (GUER or UNKNOWN). "counter" and
//--- "mortar" are excluded by design: they legitimately target enemy-held towns. "quote" never debits.
private ["_ownGateSide"];
_ownGateSide = _townObj getVariable ["sideID", WFBE_C_UNKNOWN_ID];
if ((_verb == "buy" || {_verb == "qrf"} || {_verb == "cache"} || {_verb == "vehicle"} || {_verb == "relief"} || {_verb == "donate"}) && {!(_ownGateSide == WFBE_C_GUER_ID || {_ownGateSide == WFBE_C_UNKNOWN_ID})}) exitWith {
	diag_log Format ["AICOMSTAT|v3|DIRECTOR|GUER|%1|GDIR_PANEL|verb=%2|town=%3|deny=notGuerOwned|fundedBy=%4|pricePaid=0", _elmin, _verb, _townId, getPlayerUID _player];
	[_player, "GDirPanelResult", ["deny", "Town is no longer resistance-held.", _verb, _townId]] Call WFBE_CO_FNC_SendToClient;
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
	[_player, "GDirPanelResult", ["deny", Format ["Cooldown active. %1s remaining.", _remaining], _verb, _townId]] Call WFBE_CO_FNC_SendToClient;
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
	[_player, "GDirPanelResult", ["deny", Format ["Contract limit (%1) reached on this town.", _contractsMax], _verb, _townId]] Call WFBE_CO_FNC_SendToClient;
};

//--- Gate 6: group-budget headroom (enforced here - base Lane 800 declared but never checked).
private ["_grpBudgetMax","_guerGrpCount"];
_grpBudgetMax = missionNamespace getVariable ["AICOMV2_GDIR_GROUP_BUDGET_MAX", 110];
_guerGrpCount = 0;
{
	if (side _x == resistance) then {_guerGrpCount = _guerGrpCount + 1};
} forEach allGroups;
//--- donate/cache/mortar are pure economy - never materialise units, always safe.
if (!(_verb == "donate") && {!(_verb == "cache")} && {!(_verb == "mortar")} && {_guerGrpCount >= _grpBudgetMax}) exitWith {
	diag_log Format ["AICOMSTAT|v3|DIRECTOR|GUER|%1|GDIR_PANEL|verb=%2|town=%3|deny=groupBudgetExceeded|fundedBy=%4|pricePaid=0|budget=%5/%6", _elmin, _verb, _townId, getPlayerUID _player, _guerGrpCount, _grpBudgetMax];
	[_player, "GDirPanelResult", ["deny", "Group cap reached. Try again when units despawn.", _verb, _townId]] Call WFBE_CO_FNC_SendToClient;
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
	_basePrice = missionNamespace getVariable ["AICOMV2_GDIR_PANEL_PRICE_REINF", 1600];
	if (_product == "instant") then {
		_basePrice = round (_basePrice * (missionNamespace getVariable ["AICOMV2_GDIR_PANEL_INSTANT_MULT", 1.5]));
	};
};
if (_verb == "qrf") then {
	if (_product == "qrfInsert")  then {_basePrice = missionNamespace getVariable ["AICOMV2_GDIR_PANEL_PRICE_QRF_INS", 600]};
	if (_product == "qrfGunship") then {_basePrice = missionNamespace getVariable ["AICOMV2_GDIR_PANEL_PRICE_QRF_GUN", 1200]};
	if (_product == "qrfCombo") then {
		_basePrice = round (
			(missionNamespace getVariable ["AICOMV2_GDIR_PANEL_PRICE_QRF_INS", 1200]) +
			(missionNamespace getVariable ["AICOMV2_GDIR_PANEL_PRICE_QRF_GUN", 2400]) * 0.85
		);
	};
};
if (_verb == "counter") then {_basePrice = missionNamespace getVariable ["AICOMV2_GDIR_PANEL_PRICE_CTR_ATK", 1000]};
//--- P3 cache verb (fable/gdir-harden-shop).
if (_verb == "cache") then {
    if (_product == "t1") then {_basePrice = missionNamespace getVariable ["AICOMV2_GDIR_PANEL_PRICE_CACHE_T1", 3200]};
    if (_product == "t2") then {_basePrice = missionNamespace getVariable ["AICOMV2_GDIR_PANEL_PRICE_CACHE_T2", 6400]};
    if (_product == "t3") then {_basePrice = missionNamespace getVariable ["AICOMV2_GDIR_PANEL_PRICE_CACHE_T3", 9600]};
};

//--- P5 vehicle verb (fable/gdir-vehicle-verb, GR-2026-07-08a): sibling of the cache verb above -
//--- same t1/t2/t3 product shape, same town-fund-first/wallet-shortfall debit path below, same
//--- persist-on-town-object pattern.
if (_verb == "vehicle") then {
    if (_product == "t1") then {_basePrice = missionNamespace getVariable ["AICOMV2_GDIR_PANEL_PRICE_VEHICLE_T1", 4800]};
    if (_product == "t2") then {_basePrice = missionNamespace getVariable ["AICOMV2_GDIR_PANEL_PRICE_VEHICLE_T2", 9600]};
    if (_product == "t3") then {_basePrice = missionNamespace getVariable ["AICOMV2_GDIR_PANEL_PRICE_VEHICLE_T3", 14400]};
};
//--- P4 MORTAR (relocated cmdcon45): pure pass-through to the existing guer-mortar-strike call-in,
//--- which charges its OWN cost (WFBE_C_GUER_MORTAR_COST) + cooldown + range in Server_HandleSpecial.
//--- Placed ABOVE the panel pricing/debit block so the panel NEVER debits for mortar (was a double-charge:
//--- panel price + HandleSpecial cost). A short panel cooldown still gates spam-clicking for UI feedback.
if (_verb == "mortar") exitWith {
    private ["_mortarCdKey","_mortarCdSec","_lastMortarT"];
    _mortarCdKey = Format ["AICOMV2_GDIR_MORTAR_CD_%1", _townId];
    _mortarCdSec = missionNamespace getVariable ["AICOMV2_GDIR_MORTAR_COOLDOWN_SEC", 900];
    _lastMortarT = missionNamespace getVariable [_mortarCdKey, -9999];
    if ((_nowT - _lastMortarT) < _mortarCdSec) exitWith {
        private ["_mRem"];
        _mRem = round (_mortarCdSec - (_nowT - _lastMortarT));
        [_player, "GDirPanelResult", ["deny", Format ["Mortar cooling down. %1s remaining.", _mRem], "mortar", _townId]] Call WFBE_CO_FNC_SendToClient;
    };
    private ["_mortarPos"];
    _mortarPos = getPos _townObj;
    missionNamespace setVariable [_mortarCdKey, _nowT];
    //--- HandleSpecial does the funds check/charge; if the team cannot afford it, it refuses + refunds its own cooldown.
    ["guer-mortar-strike", _mortarPos, _player] call HandleSpecial;
    diag_log Format ["AICOMSTAT|v3|DIRECTOR|GUER|%1|GDIR_PANEL|verb=mortar|town=%2|fundedBy=%3|deny=none|cost=viaHandleSpecial",
        _elmin, _townId, getPlayerUID _player];
    [_player, "GDirPanelResult", ["accept", Format ["Mortar strike called on %1.", _townId], "mortar", _townId]] Call WFBE_CO_FNC_SendToClient;
};

//--- P4 relief squad + mortar harassment verbs (fable/gdir-harden-shop).
if (_verb == "relief") then {_basePrice = missionNamespace getVariable ["AICOMV2_GDIR_PANEL_PRICE_RELIEF", 800]};
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
		[_player, "GDirPanelResult", ["deny", "Not enough funds to donate.", "donate", _townId]] Call WFBE_CO_FNC_SendToClient;
	};
	_wallet = _wallet - _donateAmt;
	_team setVariable ["wfbe_funds", _wallet, true];
	missionNamespace setVariable [_townFundKey, _townFund + _donateAmt];
	[_team] Call WFBE_SE_FNC_SyncFundsRecord;
	diag_log Format ["AICOMSTAT|v3|DIRECTOR|GUER|%1|GDIR_PANEL|verb=donate|town=%2|product=none|price=%3|fundedBy=%4|deny=none", _elmin, _townId, _donateAmt, getPlayerUID _player];
	[_player, "GDirPanelResult", ["accept", Format ["Donated $%1 to %2 town fund.", _donateAmt, _townId], "donate", _townId]] Call WFBE_CO_FNC_SendToClient;
};

//--- Town fund covers price first, shortfall from personal wallet.
private ["_shortfall"];
_shortfall = _price - _townFund;
if (_shortfall < 0) then {_shortfall = 0};
if (_shortfall > _wallet) exitWith {
	diag_log Format ["AICOMSTAT|v3|DIRECTOR|GUER|%1|GDIR_PANEL|verb=%2|town=%3|product=%4|deny=insufficientFunds|fundedBy=%5|pricePaid=0|price=%6|wallet=%7|fund=%8", _elmin, _verb, _townId, _product, getPlayerUID _player, _price, _wallet, _townFund];
	[_player, "GDirPanelResult", ["deny", Format ["Costs $%1. Wallet $%2, Town fund $%3.", _price, round _wallet, round _townFund], _verb, _townId]] Call WFBE_CO_FNC_SendToClient;
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

//--- P3: CACHE verb - persist tier on town object + telemetry. No Director tick needed.
if (_verb == "cache") exitWith {
    if (!((missionNamespace getVariable ["AICOMV2_GDIR_CACHE", 1]) > 0)) exitWith {
        [_player, "GDirPanelResult", ["deny", "Weapons cache not enabled this round.", "cache", _townId]] Call WFBE_CO_FNC_SendToClient;
    };
    private ["_newTier","_curTier"];
    _newTier = 0;
    if (_product == "t1") then {_newTier = 1};
    if (_product == "t2") then {_newTier = 2};
    if (_product == "t3") then {_newTier = 3};
    if (_newTier < 1) exitWith {
        [_player, "GDirPanelResult", ["deny", "Unknown cache tier.", "cache", _townId]] Call WFBE_CO_FNC_SendToClient;
    };
    _curTier = _townObj getVariable ["AICOMV2_GDIR_CACHE_TIER", 0];
    if (_newTier <= _curTier) exitWith {
        [_player, "GDirPanelResult", ["deny", Format ["Cache tier %1 already active on %2.", _curTier, _townId], "cache", _townId]] Call WFBE_CO_FNC_SendToClient;
    };
    //--- fable/gdir-cache-materializer (GR-2026-07-08a): Debit already done above. Persist tier on
    //--- town object, PUBLIC (3rd arg true) - town-defender group creation can run on the server,
    //--- a delegated client, or a headless client (Common_CreateTownUnits.sqf is called from all
    //--- three: Client_DelegateTownAI.sqf, Server_FNC_Delegation.sqf, server_town_ai.sqf), so a
    //--- local-only (broadcast=false) tier would be invisible on any machine except the one that
    //--- set it. Mirrors the WFBE_IsTownDefenderAI PUBLIC-tag pattern already used in
    //--- Common_CreateTownUnits.sqf for the identical cross-machine-visibility problem.
    //--- Materializer hook: Common_CreateTownUnits.sqf, per-unit forEach right after the
    //--- town-defender skill spread.
    _townObj setVariable ["AICOMV2_GDIR_CACHE_TIER", _newTier, true];
    diag_log Format ["AICOMSTAT|v3|DIRECTOR|GUER|%1|GDIR_PANEL|verb=cache|town=%2|product=%3|tier=%4|price=%5|fundedBy=%6|deny=none",
        _elmin, _townId, _product, _newTier, _price, getPlayerUID _player];
    [_player, "GDirPanelResult", ["accept", Format ["Cache tier %1 purchased for %2. Defenders will spawn with enhanced loadouts.", _newTier, _townId], "cache", _townId]] Call WFBE_CO_FNC_SendToClient;
};

//--- P5: VEHICLE verb (fable/gdir-vehicle-verb, GR-2026-07-08a) - sibling of the cache verb
//--- above: persist tier on town object, PUBLIC (broadcast=true, same cross-machine reason as
//--- cache - see the cache verb's comment). ONE-SHOT unlike cache: consumed by the
//--- materializer on the town's next garrison spawn/regrow (Common_CreateTownUnits.sqf), so
//--- there is no "current tier" guard once delivered - the persisted value resets to 0 there.
if (_verb == "vehicle") exitWith {
    if (!((missionNamespace getVariable ["AICOMV2_GDIR_VEHICLE", 0]) > 0)) exitWith {  //--- FIX-931/night-sweep: fallback default was 1 (copy-pasted from the cache verb's own
    //--- check), now matches AICOMV2_GDIR_VEHICLE's actual default of 0 in Init_CommonConstants.sqf.
        [_player, "GDirPanelResult", ["deny", "Defensive vehicle purchase not enabled this round.", "vehicle", _townId]] Call WFBE_CO_FNC_SendToClient;
    };
    private ["_newVehTier","_curVehTier"];
    _newVehTier = 0;
    if (_product == "t1") then {_newVehTier = 1};
    if (_product == "t2") then {_newVehTier = 2};
    if (_product == "t3") then {_newVehTier = 3};
    if (_newVehTier < 1) exitWith {
        [_player, "GDirPanelResult", ["deny", "Unknown vehicle tier.", "vehicle", _townId]] Call WFBE_CO_FNC_SendToClient;
    };
    _curVehTier = _townObj getVariable ["AICOMV2_GDIR_VEHICLE_TIER", 0];
    if (_curVehTier > 0) exitWith {
        [_player, "GDirPanelResult", ["deny", Format ["A vehicle order (tier %1) is already pending delivery on %2.", _curVehTier, _townId], "vehicle", _townId]] Call WFBE_CO_FNC_SendToClient;
    };
    //--- Debit already done above. Persist tier on town object (PUBLIC - see header comment above).
    _townObj setVariable ["AICOMV2_GDIR_VEHICLE_TIER", _newVehTier, true];
    diag_log Format ["AICOMSTAT|v3|DIRECTOR|GUER|%1|GDIR_PANEL|verb=vehicle|town=%2|product=%3|tier=%4|price=%5|fundedBy=%6|deny=none",
        _elmin, _townId, _product, _newVehTier, _price, getPlayerUID _player];
    [_player, "GDirPanelResult", ["accept", Format ["Vehicle tier %1 ordered for %2. Delivered on next garrison spawn.", _newVehTier, _townId], "vehicle", _townId]] Call WFBE_CO_FNC_SendToClient;
};

//--- P4: RELIEF SQUAD verb - infantry-only fast variant of buy (conserves group cap).
if (_verb == "relief") then {
    _orderKind = "reinforce"; //--- Reuses reinforce Director path.
    //--- Note: product field carries relief marker for smaller-spawn hint (future TODO in Director).
};

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
[_player, "GDirPanelResult", ["accept", Format ["Order placed: $%1 debited. Action: %2.", _price, _verb], _verb, _townId]] Call WFBE_CO_FNC_SendToClient;

//--- WFBE_C_GDIR_VIS: broadcast accepted order to all GUER clients side-wide.
if ((missionNamespace getVariable ["WFBE_C_GDIR_VIS", 1]) > 0) then {
	private ["_visLabel"];
	if (_verb == "buy" && {_product == "convoy"}) then {_visLabel = "Convoy Reinforcements"};
	if (_verb == "buy" && {_product == "instant"}) then {_visLabel = "Instant Reinforcements"};
	if (_verb == "qrf" && {_product == "qrfInsert"}) then {_visLabel = "QRF Insert"};
	if (_verb == "qrf" && {_product == "qrfGunship"}) then {_visLabel = "QRF Gunship"};
	if (_verb == "qrf" && {_product == "qrfCombo"}) then {_visLabel = "QRF Combo"};
	if (_verb == "counter") then {_visLabel = "Counter-Attack"};
	if (_verb == "donate") then {_visLabel = "Donation"};
	if (isNil "_visLabel") then {_visLabel = _verb};
	WFBE_GDIR_ORDER_MSG = Format ["COMMISSAR: %1 ordered for %2", _visLabel, _townId];
	publicVariable "WFBE_GDIR_ORDER_MSG";
};

["INFORMATION", Format ["RequestGDirPanel: verb=%1 product=%2 town=%3 price=%4 fundedBy=%5.", _verb, _product, _townId, _price, name _player]] Call WFBE_CO_FNC_LogContent;
