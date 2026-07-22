/*
	GDirPanelResult.sqf  (A1 Commissar Panel - UX v2)
	GUIDE-REV GR-2026-07-03a

	Server pushes the action result back to the requesting GUER client.
	UX v2: handles "quote" status to update the cost labels + enable gates via
	shared globals WFBE_COMM_QUOTE_PRICES and WFBE_COMM_QUOTE_TOWN (set in
	GUI_Menu_GuerCommissar.sqf).

	For "accept"/"deny": displays a hint as before.
	For "quote": _msg is a comma-joined price string "p1,p2,p3,p4,p5,p6,p7";
	  parse and populate WFBE_COMM_QUOTE_PRICES + WFBE_COMM_QUOTE_TOWN so the
	  loop can pick them up without a separate panel refresh call.

	Parameters (pushed by server via GDirPanelResult SendToClient):
	  _this = [status (String: "accept"|"deny"|"quote"), message (String), verb (String), townId (String)]

	A2-OA-1.64 safe.
*/


//--- Malformed-payload guard: ensure _this is ARRAY (all accesses below use count checks).
if (!((typeName _this) in ["ARRAY"])) exitWith {};
private ["_status","_msg","_verb","_townId"];

_status = if (count _this > 0) then {_this select 0} else {"deny"};
_msg    = if (count _this > 1) then {_this select 1} else {"Unknown error."};
_verb   = if (count _this > 2) then {_this select 2} else {"?"};
_townId = if (count _this > 3) then {_this select 3} else {"?"};

//--- Quote path: parse comma-joined price string into WFBE_COMM_QUOTE_PRICES.
//--- The loop in GUI_Menu_GuerCommissar.sqf reads these globals and updates labels/enable states.
if (_status == "quote") exitWith {
	private ["_parts","_prices","_i","_ch","_num","_cur"];
	//--- Manual CSV parse using toArray (A2-safe; no select[i,n] string-slice).
	//--- toArray returns array of ASCII codes; comma = 44.
	_parts = [];
	_cur = "";
	private ["_msgArr","_code","_charArr"];
	_msgArr = toArray _msg;
	{
		_code = _x;
		if (_code == 44) then {
			_parts set [count _parts, _cur];
			_cur = "";
		} else {
			_charArr = [_code];
			_cur = _cur + (toString _charArr);
		};
	} forEach _msgArr;
	if (_cur != "") then {_parts set [count _parts, _cur]};

	_prices = [];
	{
		_num = parseNumber _x;
		_prices set [count _prices, _num];
	} forEach _parts;

	WFBE_COMM_QUOTE_PRICES = _prices;
	WFBE_COMM_QUOTE_TOWN   = _townId;
};

//--- Accept / deny path (unchanged from v1).
if (_status == "accept") then {
	hint Format ["[GUER Director]\n%1\n(%2 -> %3)", _msg, _verb, _townId];
} else {
	hint Format ["[GUER Director - DENIED]\n%1\n(%2 -> %3)", _msg, _verb, _townId];
};
