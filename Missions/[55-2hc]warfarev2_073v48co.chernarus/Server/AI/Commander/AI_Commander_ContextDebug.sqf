/*
	AI Commander context debug helper.
	Phase 2: emits slow summary-only RPT output.
	Parameter: [_side, _context]
*/

Private ["_side","_context","_sideText","_tracked","_belief","_best","_bestScore","_score","_age","_sources","_sourceText","_src"];

if (count _this < 2) exitWith {};

_side = _this select 0;
_context = _this select 1;
if (typeName _context != "ARRAY") exitWith {};

_sideText = str _side;
_tracked = 0;
_best = [];
_bestScore = -1;
{
	_belief = _x;
	if (typeName _belief == "ARRAY") then {
		if (count _belief >= 13) then {
			if ((_belief select 12) != "expired") then {
				_tracked = _tracked + 1;
				_score = _belief select 8;
				if (_score > _bestScore) then {_bestScore = _score; _best = _belief};
			};
		};
	};
} forEach _context;

if (count _best >= 13) then {
	_age = round (time - (_best select 10));
	_sources = _best select 11;
	_sourceText = "";
	if (typeName _sources == "ARRAY") then {
		{
			_src = str _x;
			if (_sourceText == "") then {_sourceText = _src} else {_sourceText = Format ["%1,%2", _sourceText, _src]};
		} forEach _sources;
	};
	["INFORMATION", Format ["AI_Commander_Context: [%1] %2 tracked beliefs, top=%3/%4 near %5 conf=%6 age=%7s sources=%8.", _sideText, _tracked, _best select 12, _best select 2, _best select 5, _best select 8, _age, _sourceText]] Call WFBE_CO_FNC_LogContent;
} else {
	["INFORMATION", Format ["AI_Commander_Context: [%1] 0 tracked beliefs.", _sideText]] Call WFBE_CO_FNC_LogContent;
};
