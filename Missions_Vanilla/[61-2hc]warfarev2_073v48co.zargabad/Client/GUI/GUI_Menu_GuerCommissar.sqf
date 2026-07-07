disableSerialization;
/*
	GUI_Menu_GuerCommissar.sqf  (A1 Commissar Panel)
	GUIDE-REV GR-2026-07-03a

	onLoad handler for WFBE_GDirCommissarMenu (idd=31000).
	Buttons in the dialog set MenuAction (global); this loop reads and dispatches.
	Sends requests to the server via WFBE_CO_FNC_SendToServer using the
	RequestGDirPanel PVF registered in Init_PublicVariables.sqf.

	A2-OA-1.64 safe.
*/

//--- Guards: must be called as onLoad (display in _this select 0).
if (count _this < 1) exitWith {hint "GDirCommissar: bad call.";};

//--- Panel + lane guard (belt-and-suspenders; hub button is ctrlShow-gated too).
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

private ["_display"];
_display = _this select 0;

//--- Populate town list (idc 31010) from WFBE_CL_Towns.
private ["_towns","_firstTown"];
_towns     = if (isNil "WFBE_CL_Towns") then {[]} else {WFBE_CL_Towns};
_firstTown = "";

{
	private ["_name"];
	_name = _x getVariable ["wfbe_name", ""];
	if (_name != "") then {
		private ["_idx"];
		_idx = lbAdd [31010, _name];
		if (_firstTown == "") then {_firstTown = _name};
	};
} forEach _towns;

if (_firstTown != "") then {lbSetCurSel [31010, 0]};

//--- Main interaction loop.
MenuAction = -1;

waitUntil {
	sleep 0.1;
	//--- Read selected town.
	private ["_lbCur","_selTownId"];
	_lbCur     = lbCurSel 31010;
	_selTownId = if (_lbCur >= 0) then {lbText [31010, _lbCur]} else {_firstTown};

	//--- Dispatch on button press.
	if (MenuAction == 21) then {
		MenuAction = -1;
		["RequestGDirPanel", [player, "buy", _selTownId, "convoy"]] Call WFBE_CO_FNC_SendToServer;
		hint "Buy Convoy order sent. Await result...";
	};
	if (MenuAction == 22) then {
		MenuAction = -1;
		["RequestGDirPanel", [player, "buy", _selTownId, "instant"]] Call WFBE_CO_FNC_SendToServer;
		hint "Buy Instant order sent. Await result...";
	};
	if (MenuAction == 31) then {
		MenuAction = -1;
		["RequestGDirPanel", [player, "qrf", _selTownId, "qrfInsert"]] Call WFBE_CO_FNC_SendToServer;
		hint "QRF Insert contract sent. Await result...";
	};
	if (MenuAction == 32) then {
		MenuAction = -1;
		["RequestGDirPanel", [player, "qrf", _selTownId, "qrfGunship"]] Call WFBE_CO_FNC_SendToServer;
		hint "QRF Gunship contract sent. Await result...";
	};
	if (MenuAction == 33) then {
		MenuAction = -1;
		["RequestGDirPanel", [player, "qrf", _selTownId, "qrfCombo"]] Call WFBE_CO_FNC_SendToServer;
		hint "QRF Combo contract sent. Await result...";
	};
	if (MenuAction == 41) then {
		MenuAction = -1;
		["RequestGDirPanel", [player, "counter", _selTownId, "none"]] Call WFBE_CO_FNC_SendToServer;
		hint "Counter-attack contract sent. Await result...";
	};
	if (MenuAction == 51) then {
		MenuAction = -1;
		["RequestGDirPanel", [player, "donate", _selTownId, "none"]] Call WFBE_CO_FNC_SendToServer;
		hint "Donate order sent. Await result...";
	};

	(!alive player) || {!isDialog}
};
