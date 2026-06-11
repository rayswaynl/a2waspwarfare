/*
	coin_cards.sqf — WFBE_CL_FNC_CoinCard
	Builds the structured-text string shown in the item-card panel (idc 112217).

	Parameters:
	  _this select 0 : classname (String)
	  _this select 1 : category  (Number — index into BIS_COIN_categories)
	  _this select 2 : cost      (Number or Array [cashIndex, Number])
	  _this select 3 : displayName (String)

	Returns: String — structured text ready for ctrlSetStructuredText / parseText.

	Compiled once into WFBE_CL_FNC_CoinCard inside coin_interface.sqf.
	Remove entire feature: set WFBE_C_COIN_CARDS = 0 in Init_CommonConstants.sqf,
	or delete this file and the gated blocks in coin_interface.sqf.
*/

private [
	"_class","_category","_cost","_displayName",
	"_cashIndex","_costNum",
	"_pic","_picData","_picLine",
	"_catStr","_catLine",
	"_isAnchor","_anchorLine",
	"_currencyLabel",
	"_out"
];

_class       = _this select 0;
_category    = _this select 1;
_cost        = _this select 2;
_displayName = _this select 3;

//--- Parse dual-currency cost.
_cashIndex = 0;
_costNum   = 0;
if (typeName _cost == "ARRAY") then {
	_cashIndex = _cost select 0;
	_costNum   = _cost select 1;
} else {
	if (typeName _cost == "SCALAR") then {_costNum = _cost};
};
if (isNil "_costNum" || {typeName _costNum != "SCALAR"}) then {_costNum = 0};

//--- Currency label (mirrors coin_interface.sqf funds branch).
_currencyLabel = if (_cashIndex == 0) then {"Supply"} else {"Cash"};

//--- Display name header (bold via size).
_out = format ["<t size='1.2' shadow='1' align='center' color='#eef8ff'>%1</t><br />", _displayName];

//--- Picture: read from the unit data global (index 1 = QUERYUNITPICTURE).
//--- Guard: isNil on the global; structures often have none.
_picLine = "";
_picData = missionNamespace getVariable _class;
if (!isNil "_picData") then {
	if (typeName _picData == "ARRAY" && {count _picData > 1}) then {
		_pic = _picData select 1;
		if (typeName _pic == "STRING" && {_pic != ""}) then {
			_picLine = format ["<t align='center'><img image='%1' width='64' height='64'/></t><br />", _pic];
		};
	};
};
_out = _out + _picLine;

//--- Cost line.
_out = _out + format ["<t size='0.9' color='#ffc342' align='center'>%1 %2</t><br />", _costNum, _currencyLabel];

//--- Defense category (call only for defenses; guard with isNil fallback).
_catStr  = "";
_catLine = "";
private "_catResult";
_catResult = [_class, sideJoined] Call WFBE_CO_FNC_GetDefenseCategory;
if (!isNil "_catResult" && {typeName _catResult == "STRING"} && {_catResult != ""}) then {
	_catStr = _catResult;
};
if (_catStr != "") then {
	_catLine = format ["<t size='0.85' color='#aaccff' align='center'>%1</t><br />", _catStr];
};
_out = _out + _catLine;

//--- WDDM composition anchor tag.
_anchorLine = "";
_isAnchor = (!isNil "WFBE_POSITION_ANCHOR_NAMES" && {(WFBE_POSITION_ANCHOR_NAMES find _class) != -1});
if (_isAnchor) then {
	_anchorLine = "<t size='0.85' color='#88ffcc' align='center'>Composition</t><br />";
};
_out = _out + _anchorLine;

_out
