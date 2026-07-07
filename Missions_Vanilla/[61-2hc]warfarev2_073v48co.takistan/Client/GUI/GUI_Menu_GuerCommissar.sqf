disableSerialization;
/*
	GUI_Menu_GuerCommissar.sqf  (A1 Commissar Panel - UX v2)
	GUIDE-REV GR-2026-07-03a

	onLoad handler for WFBE_GDirCommissarMenu (idd=31000).
	UX v2 additions vs v1:
	  - Quote round-trip: on town select, sends a "quote" verb (read-only, no debit) to
	    server which replies via GDirPanelResult with a price array; cost labels updated.
	  - Minimap (idc 31060): mouse click selects nearest GUER-eligible town; selection
	    synced bidirectionally with the list box (LB_Towns idc 31010).
	    Map click highlight: local marker "wfbe_commissar_sel_<townId>" tracks selection.
	  - Wallet + town fund readout (idc 31070): refreshed each loop tick.
	  - Button enable gate: ctrlEnable false when estimated wallet < estimated cost.
	  - Cooldown display (idc 31079): shows remaining cooldown for selected town.
	  - Back button (MenuAction 90): closes dialog and re-opens WF_Menu.
	  - Status text (idc 31078): pending/error messages.

	A2-OA-1.64 safe: array-form private only, no params/pushBack/isEqualTo/apply/findIf.
*/

//--- Guards: must be called as onLoad (display in _this select 0).
if (count _this < 1) exitWith {hint "GDirCommissar: bad call.";};

//--- Panel + lane guard.
if (!((missionNamespace getVariable ["AICOMV2_LANE_GUER_DIRECTOR", 0]) > 0)) exitWith {
	hint "GUER Director lane is not active this round.";
	closeDialog 0;
};
if (!((missionNamespace getVariable ["AICOMV2_GDIR_PANEL", 0]) > 0)) exitWith {
	hint "GUER Commissar Panel is not enabled this round.";
	closeDialog 0;
};
if (!(sideJoined == resistance)) exitWith {
	hint "GUER actions are for resistance players only.";
	closeDialog 0;
};

private ["_display","_map"];
_display = _this select 0;
_map = _display displayCtrl 31060;

//--- Populate town list (idc 31010) from WFBE_CL_Towns.
private ["_towns","_firstTown"];
_towns    = if (isNil "towns") then {[]} else {towns}; //--- fable/commissar-fix: WFBE_CL_Towns was never written; towns[] is populated on every client by Init_Town.sqf
_firstTown = "";

{
	private ["_name"];
	_name = _x getVariable ["name", ""];
	if (_name != "") then {
		private ["_idx"];
		_idx = lbAdd [31010, _name];
		//--- fable/commissar-fix: tint by owner side (sideID broadcast by Init_Town/camp FSM).
		private ["_sid","_lbCol"];
		_sid = _x getVariable ["sideID", -1];
		_lbCol = [0.7, 0.7, 0.7, 1];
		if (_sid == WESTID) then {_lbCol = [0.4, 0.7, 1, 1]};
		if (_sid == EASTID) then {_lbCol = [1, 0.35, 0.3, 1]};
		if (_sid == WFBE_C_GUER_ID) then {_lbCol = [0.25, 0.85, 0.4, 1]};
		lbSetColor [31010, _idx, _lbCol];
		if (_firstTown == "") then {_firstTown = _name};
	};
} forEach _towns;

if (_firstTown != "") then {lbSetCurSel [31010, 0]};

//--- Local highlight marker for the selected town on the minimap.
//--- Created once; position updated when selection changes.
private ["_selMarker"];
_selMarker = "wfbe_commissar_sel";
createMarkerLocal [_selMarker, getPos player];
_selMarker setMarkerTypeLocal "mil_circle";
_selMarker setMarkerColorLocal "ColorGreen";
_selMarker setMarkerSizeLocal [0.8, 0.8];
_selMarker setMarkerTextLocal "";

//--- Centre minimap on the world centre initially; will snap to selected town below.
private ["_worldCentre"];
private ["_wSz"];
	_wSz = getNumber (configFile >> "CfgWorlds" >> worldName >> "worldSize");
	if (_wSz <= 0) then {_wSz = 5120}; //--- A2 safe: no worldSize command
	_worldCentre = [(_wSz / 2), (_wSz / 2), 0];
_map ctrlMapAnimAdd [0, 0.03, _worldCentre];
ctrlMapAnimCommit _map;

//--- Helper: get the nearest GUER-eligible town object to a world position.
//--- Returns objNull if no town found.
WFBE_COMM_FNC_NearestTown = {
	private ["_pos","_best","_bestDist","_d"];
	_pos = _this select 0;
	_best = objNull;
	_bestDist = 1e9;
	{
		_d = _pos distance (getPos _x);
		if (_d < _bestDist) then {
			_best = _x;
			_bestDist = _d;
		};
	} forEach _towns;
	_best
};

//--- Helper: select town by name in LB_Towns and update highlight marker.
WFBE_COMM_FNC_SelectTownByName = {
	private ["_name","_idx","_tObj","_tPos"];
	_name = _this select 0;
	_idx = 0;
	{
		if ((lbText [31010, _x]) == _name) then {
			_idx = _x;
		};
	} forEach (lbSize 31010 - 1);
	//--- Find index by scanning
	private ["_found","_i","_sz"];
	_found = -1;
	_sz = lbSize 31010;
	_i = 0;
	while {_i < _sz && {_found < 0}} do {
		if ((lbText [31010, _i]) == _name) then {_found = _i};
		_i = _i + 1;
	};
	if (_found >= 0) then {lbSetCurSel [31010, _found]};

	//--- Move highlight marker to this town.
	_tObj = objNull;
	{
		if ((_x getVariable ["name", ""]) == _name) then {_tObj = _x};
	} forEach _towns;
	if (!isNull _tObj) then {
		_tPos = getPos _tObj;
		_selMarker setMarkerPosLocal _tPos;
		_map ctrlMapAnimAdd [0.3, 0.1, _tPos];
		ctrlMapAnimCommit _map;
	};
};

//--- Helper: read wallet + town fund for current selection and refresh readout.
WFBE_COMM_FNC_RefreshWallet = {
	private ["_team","_wallet","_townFundKey","_townFund","_walletTxt"];
	_team = group player;
	_wallet = _team getVariable "wfbe_funds";
	if (isNil "_wallet") then {_wallet = 0};
	private ["_selTownId"];
	_selTownId = _this select 0;
	_townFundKey = Format ["AICOMV2_GDIR_TOWN_FUND_%1", _selTownId];
	_townFund = missionNamespace getVariable [_townFundKey, 0];
	_walletTxt = Format ["Wallet: $%1 | Town Fund: $%2", round _wallet, round _townFund];
	ctrlSetText [31070, _walletTxt];
	[_wallet, _townFund]
};

//--- Helper: update cost labels from a price array [convoy, instant, qrfIns, qrfGun, qrfCombo, counter, donate].
//--- If price array is empty, shows "~est. $--".
WFBE_COMM_FNC_SetCostLabels = {
	private ["_prices","_p"];
	_prices = _this select 0;
	if (count _prices < 7) then {
		ctrlSetText [31071, "~est. $--"];
		ctrlSetText [31072, "~est. $--"];
		ctrlSetText [31073, "~est. $--"];
		ctrlSetText [31074, "~est. $--"];
		ctrlSetText [31075, "~est. $--"];
		ctrlSetText [31076, "~est. $--"];
	} else {
		ctrlSetText [31071, Format ["~est. $%1", _prices select 0]];
		ctrlSetText [31072, Format ["~est. $%1", _prices select 1]];
		ctrlSetText [31073, Format ["~est. $%1", _prices select 2]];
		ctrlSetText [31074, Format ["~est. $%1", _prices select 3]];
		ctrlSetText [31075, Format ["~est. $%1", _prices select 4]];
		ctrlSetText [31076, Format ["~est. $%1", _prices select 5]];
	};
};

//--- Helper: enable/disable action buttons based on wallet vs estimated prices.
//--- Also gates contract buttons on group budget headroom.
WFBE_COMM_FNC_UpdateButtonStates = {
	private ["_wallet","_townFund","_prices","_grpBudgetMax","_guerGrpCount","_grpOk"];
	_wallet = _this select 0;
	_townFund = _this select 1;
	_prices = _this select 2;

	_grpBudgetMax = missionNamespace getVariable ["AICOMV2_GDIR_GROUP_BUDGET_MAX", 110];
	_guerGrpCount = 0;
	{
		if (side _x == resistance) then {_guerGrpCount = _guerGrpCount + 1};
	} forEach allGroups;
	_grpOk = (_guerGrpCount < _grpBudgetMax);

	if (count _prices < 7) then {
		//--- Prices not yet known - disable all action buttons.
		ctrlEnable [31021, false];
		ctrlEnable [31022, false];
		ctrlEnable [31031, false];
		ctrlEnable [31032, false];
		ctrlEnable [31033, false];
		ctrlEnable [31041, false];
		ctrlEnable [31051, false];
	} else {
		//--- Buy: town fund covers first, shortfall from wallet.
		private ["_canBuyConvoy","_canBuyInstant","_shortConvoy","_shortInstant"];
		_shortConvoy  = (_prices select 0) - _townFund;
		_shortInstant = (_prices select 1) - _townFund;
		if (_shortConvoy < 0)  then {_shortConvoy  = 0};
		if (_shortInstant < 0) then {_shortInstant = 0};
		_canBuyConvoy  = (_grpOk && {_wallet >= _shortConvoy});
		_canBuyInstant = (_grpOk && {_wallet >= _shortInstant});
		ctrlEnable [31021, _canBuyConvoy];
		ctrlEnable [31022, _canBuyInstant];

		//--- QRF: same fund+wallet logic.
		private ["_shortIns","_shortGun","_shortCombo"];
		_shortIns   = (_prices select 2) - _townFund;
		_shortGun   = (_prices select 3) - _townFund;
		_shortCombo = (_prices select 4) - _townFund;
		if (_shortIns   < 0) then {_shortIns   = 0};
		if (_shortGun   < 0) then {_shortGun   = 0};
		if (_shortCombo < 0) then {_shortCombo = 0};
		ctrlEnable [31031, (_grpOk && {_wallet >= _shortIns})];
		ctrlEnable [31032, (_grpOk && {_wallet >= _shortGun})];
		ctrlEnable [31033, (_grpOk && {_wallet >= _shortCombo})];

		//--- Counter.
		private ["_shortCtr"];
		_shortCtr = (_prices select 5) - _townFund;
		if (_shortCtr < 0) then {_shortCtr = 0};
		ctrlEnable [31041, (_grpOk && {_wallet >= _shortCtr})];

		//--- Donate: fixed $200 from wallet only.
		ctrlEnable [31051, (_wallet >= 200)];
	};
};

//--- Store quote prices in a local variable (updated by GDirPanelResult "quote" path).
WFBE_COMM_QUOTE_PRICES = [];
WFBE_COMM_QUOTE_TOWN = "";

//--- Request a quote for the currently selected town.
WFBE_COMM_FNC_RequestQuote = {
	private ["_townId"];
	_townId = _this select 0;
	WFBE_COMM_QUOTE_PRICES = [];   //--- clear stale prices
	WFBE_COMM_QUOTE_TOWN = _townId;
	ctrlSetText [31078, "Fetching prices..."];
	["RequestGDirPanel", [player, "quote", _townId, "none"]] Call WFBE_CO_FNC_SendToServer;
};

//--- Snap minimap to selected town on open.
if (_firstTown != "") then {
	[_firstTown] Call WFBE_COMM_FNC_SelectTownByName;
	[_firstTown] Call WFBE_COMM_FNC_RequestQuote;
};

//--- Main interaction loop.
MenuAction = -1;
mouseButtonUp = -1;
mouseButtonDown = -1;

private ["_lastLbSel","_lastQuoteTown","_cooldownSec","_panelCooldowns","_nowT"];
_lastLbSel = lbCurSel 31010;
_lastQuoteTown = "";
_cooldownSec = missionNamespace getVariable ["AICOMV2_GDIR_PANEL_COOLDOWN_SEC", 600];

waitUntil {
	sleep 0.15;

	//--- Read selected town from list box.
	private ["_lbCur","_selTownId"];
	_lbCur     = lbCurSel 31010;
	_selTownId = if (_lbCur >= 0) then {lbText [31010, _lbCur]} else {_firstTown};

	//--- Detect list box selection change -> update marker + re-request quote.
	if (_lbCur != _lastLbSel) then {
		_lastLbSel = _lbCur;
		if (_selTownId != "") then {
			[_selTownId] Call WFBE_COMM_FNC_SelectTownByName;
			[_selTownId] Call WFBE_COMM_FNC_RequestQuote;
		};
	};

	//--- Map click: select nearest town.
	if (mouseButtonUp == 0) then {
		mouseButtonUp = -1;
		private ["_clickPos","_nearObj","_nearName"];
		_clickPos = _map posScreenToWorld [mouseX, mouseY];
		_nearObj = [_clickPos] Call WFBE_COMM_FNC_NearestTown;
		if (!isNull _nearObj) then {
			_nearName = _nearObj getVariable ["name", ""];
			if (_nearName != "" && {_nearName != _selTownId}) then {
				_selTownId = _nearName;
				[_selTownId] Call WFBE_COMM_FNC_SelectTownByName;
				[_selTownId] Call WFBE_COMM_FNC_RequestQuote;
			};
		};
	};

	//--- Apply quote prices if the result came back for this town.
	if (WFBE_COMM_QUOTE_TOWN == _selTownId && {count WFBE_COMM_QUOTE_PRICES >= 7}) then {
		if (_selTownId != _lastQuoteTown || {count WFBE_COMM_QUOTE_PRICES >= 7}) then {
			_lastQuoteTown = _selTownId;
			[WFBE_COMM_QUOTE_PRICES] Call WFBE_COMM_FNC_SetCostLabels;
			ctrlSetText [31078, ""];
		};
	};

	//--- Refresh wallet + fund readout each tick.
	private ["_walletPair","_wallet","_townFund"];
	_walletPair = [_selTownId] Call WFBE_COMM_FNC_RefreshWallet;
	_wallet    = _walletPair select 0;
	_townFund  = _walletPair select 1;

	//--- Update button enable states.
	[_wallet, _townFund, WFBE_COMM_QUOTE_PRICES] Call WFBE_COMM_FNC_UpdateButtonStates;

	//--- Cooldown display for the selected town.
	_panelCooldowns = missionNamespace getVariable ["AICOMV2_GDIR_COOLDOWN_MAP", []];
	_nowT = diag_tickTime;
	private ["_townCooldown","_cdRemaining"];
	_townCooldown = 0;
	{
		if ((_x select 0) == _selTownId) then {_townCooldown = _x select 1};
	} forEach _panelCooldowns;
	_cdRemaining = _cooldownSec - (_nowT - _townCooldown);
	if (_cdRemaining > 0) then {
		ctrlSetText [31079, Format ["Cooldown: %1s remaining on %2", round _cdRemaining, _selTownId]];
	} else {
		ctrlSetText [31079, ""];
	};

	//--- Button dispatches.
	if (MenuAction == 21) then {
		MenuAction = -1;
		["RequestGDirPanel", [player, "buy", _selTownId, "convoy"]] Call WFBE_CO_FNC_SendToServer;
		ctrlSetText [31078, "Convoy order sent. Awaiting result..."];
	};
	if (MenuAction == 22) then {
		MenuAction = -1;
		["RequestGDirPanel", [player, "buy", _selTownId, "instant"]] Call WFBE_CO_FNC_SendToServer;
		ctrlSetText [31078, "Instant order sent. Awaiting result..."];
	};
	if (MenuAction == 31) then {
		MenuAction = -1;
		["RequestGDirPanel", [player, "qrf", _selTownId, "qrfInsert"]] Call WFBE_CO_FNC_SendToServer;
		ctrlSetText [31078, "QRF Insert contract sent. Awaiting result..."];
	};
	if (MenuAction == 32) then {
		MenuAction = -1;
		["RequestGDirPanel", [player, "qrf", _selTownId, "qrfGunship"]] Call WFBE_CO_FNC_SendToServer;
		ctrlSetText [31078, "QRF Gunship contract sent. Awaiting result..."];
	};
	if (MenuAction == 33) then {
		MenuAction = -1;
		["RequestGDirPanel", [player, "qrf", _selTownId, "qrfCombo"]] Call WFBE_CO_FNC_SendToServer;
		ctrlSetText [31078, "QRF Combo contract sent. Awaiting result..."];
	};
	if (MenuAction == 41) then {
		MenuAction = -1;
		["RequestGDirPanel", [player, "counter", _selTownId, "none"]] Call WFBE_CO_FNC_SendToServer;
		ctrlSetText [31078, "Counter-attack contract sent. Awaiting result..."];
	};
	if (MenuAction == 51) then {
		MenuAction = -1;
		["RequestGDirPanel", [player, "donate", _selTownId, "none"]] Call WFBE_CO_FNC_SendToServer;
		ctrlSetText [31078, "Donate order sent. Awaiting result..."];
	};
	if (MenuAction == 90) then {
		MenuAction = -1;
		deleteMarkerLocal _selMarker;
		closeDialog 0;
		createDialog "WF_Menu";
	};

	(!alive player) || {!dialog} //--- fable/tonight-hotfixes: isDialog is not a command on A2 OA (undefined-variable spam every frame); `dialog` is the engine bool
};

//--- Cleanup: remove local selection marker.
deleteMarkerLocal _selMarker;
