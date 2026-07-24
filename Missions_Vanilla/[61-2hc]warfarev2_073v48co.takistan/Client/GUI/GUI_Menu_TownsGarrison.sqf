disableSerialization;
/*
	Read-only Towns tab garrison view.
	The panel deliberately uses only already-replicated town ownership/name/range state and
	the public WFBE_IsTownDefenderAI unit tag. It never requests or publishes new intel.
	Enemy and unknown towns are excluded before any garrison count is built.
*/

if (count _this < 1) exitWith {hint "Town garrison: bad call.";};

private ["_display","_towns","_ownSideID","_refresh","_rows","_sel","_row"];
_display = _this select 0;
_towns = if (isNil "towns") then {[]} else {towns};
_ownSideID = sideJoined Call GetSideID;

_refresh = {
	private ["_rowsLocal","_town","_name","_range","_near","_unit","_units","_groups","_grp","_rowIndex","_row","_lbCol","_totalUnits"];
	_rowsLocal = [];
	_totalUnits = 0;
	{
		_town = _x;
		//--- Own-side-only intel gate: do not enumerate enemy/unknown town garrisons.
		if ((_town getVariable ["sideID", -1]) == _ownSideID) then {
			_name = _town getVariable ["name", ""];
			if (_name != "") then {
				_range = _town getVariable ["range", 600];
				if (_range < 700) then {_range = 700};
				_near = _town nearEntities [["Man"], _range];
				_units = 0;
				_groups = [];
				{
					_unit = _x;
					if (alive _unit && {(_unit getVariable ["WFBE_IsTownDefenderAI", false]) && {side _unit == sideJoined}}) then {
						_units = _units + 1;
						_grp = group _unit;
						if (!(_grp in _groups)) then {_groups = _groups + [_grp]};
					};
				} forEach _near;
				_totalUnits = _totalUnits + _units;
				_rowsLocal set [count _rowsLocal, [_name, count _groups, _units]];
			};
		};
	} forEach _towns;

	lbClear 31110;
	if (count _rowsLocal == 0) then {
		lbAdd [31110, "No owned towns available."];
	} else {
		{
			_row = _x;
			_rowIndex = lbAdd [31110, Format ["%1  |  %2 groups / %3 units", _row select 0, _row select 1, _row select 2]];
			_lbCol = [0.7, 0.7, 0.7, 1];
			if ((_row select 2) > 0) then {_lbCol = [0.35, 0.9, 0.45, 1]};
			lbSetColor [31110, _rowIndex, _lbCol];
		} forEach _rowsLocal;
	};
	ctrlSetText [31112, Format ["OWNED TOWNS: %1  |  LIVE GARRISON: %2 units", count _rowsLocal, _totalUnits]];
	_rowsLocal
};

MenuAction = -1;
_rows = [] call _refresh;

while {alive player && {dialog}} do {
	if (MenuAction == 90) exitWith {
		MenuAction = -1;
		closeDialog 0;
		createDialog "WF_Menu";
	};
	if (MenuAction == 91) then {
		MenuAction = -1;
		_rows = [] call _refresh;
	};
	_sel = lbCurSel 31110;
	if (_sel >= 0 && {_sel < count _rows}) then {
		_row = _rows select _sel;
		ctrlSetText [31111, Format ["%1: %2 live garrison groups / %3 tagged defenders in range.", _row select 0, _row select 1, _row select 2]];
	} else {
		ctrlSetText [31111, "Select an owned town to inspect its live garrison."];
	};
	sleep 0.5;
};
