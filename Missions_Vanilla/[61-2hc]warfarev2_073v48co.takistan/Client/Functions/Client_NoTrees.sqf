//--- cmdcon43-a (Build 88) — Chernarus "No Trees" visual toggle.
//---
//--- Ray's ask: a server-side ON/OFF setting so EVERYONE gets a tree-free Chernarus
//--- (client-side vegetation mods are banned for fairness; a server-wide setting is fair
//--- because everyone runs the same pass).
//---
//--- MECHANISM: nearestObjects [cellCentre, [], radius] (A2-OA v1.50; the empty [] class
//--- array is what returns classless WRP terrain trees/bushes) -> hideObject true on each
//--- matched tree/bush.  Proven in-repo by Server\Functions\Server_SiteClearance.sqf, which
//--- uses the same enumerate+filter on the Chernarus tree-model prefix.  hideObject is LOCAL (there
//--- is NO hideObjectGlobal in 1.64; nearestTerrainObjects is Arma-3-only) so this pass runs
//--- on EVERY machine — server, HCs, and every player client incl. JIP joiners (registered
//--- from Init_Client.sqf).
//---
//--- ⚠️ FAIRNESS CAVEAT (see docs/design/CH-NOTREES-FEASIBILITY.md): in A2-OA 1.64 hideObject
//--- hides RENDER only; the object's Geometry + View-Geometry LODs PERSIST.  So AI still SEE
//--- and shoot through the visually-cleared trees, and bullets/vehicles still collide with the
//--- invisible trunks.  This is uniform for all players (not player-vs-player unfair) but it is
//--- player-vs-engine confusing.  Hence the toggle is EXPERIMENTAL and DEFAULT OFF.
//---
//--- PERF: a whole-map nearestObjects is a non-starter (our cleaners measure a 20km scan at
//--- ~230ms; BI wiki warns ~100ms/7000-object sort; Chernarus has tens of thousands of trees).
//--- We sweep a grid of cells and uiSleep between them so the cost is spread over background
//--- time and never frame-spikes.  hideObject is a one-shot flag, so cost is paid once per join.

private ["_mapSize","_cell","_reach","_slept","_hidden","_scanned","_x0","_y0","_cx","_cy",
         "_centre","_objs","_o","_s","_isVeg","_matchAny","_perfStart"];

//--- Gate 1: Chernarus only.  worldName is authoritative; the toggle is CH-scoped by design.
if (worldName != "Chernarus") exitWith {};

//--- Gate 2: feature enabled (default OFF).  Read live so a mid-mission flip is honoured on
//--- the next JIP; the value is set from the WFBE_C_CH_NOTREES lobby param / constant.
if ((missionNamespace getVariable ["WFBE_C_CH_NOTREES", 0]) == 0) exitWith {};

//--- A2-safe substring matcher (String find is Arma-3-only and throws on A2-OA).
//--- _this = [haystackLower (String), [needle1, needle2, ...]] -> Bool.
//--- Lifted from Server\Functions\Server_SiteClearance.sqf (toArray sliding-window).
_matchAny = {
	private ["_hayA","_needles","_found","_nA","_hl","_nl","_i","_j","_ok"];
	_hayA = toArray (_this select 0);
	_needles = _this select 1;
	_hl = count _hayA;
	_found = false;
	{
		if (!_found) then {
			_nA = toArray _x;
			_nl = count _nA;
			if (_nl > 0 && _nl <= _hl) then {
				for "_i" from 0 to (_hl - _nl) do {
					if (!_found) then {
						_ok = true;
						for "_j" from 0 to (_nl - 1) do {
							if ((_hayA select (_i + _j)) != (_nA select _j)) exitWith {_ok = false};
						};
						if (_ok) then {_found = true};
					};
				};
			};
		};
	} forEach _needles;
	_found
};

//--- Grid sweep params.  Chernarus is a fixed 15360m terrain — HARDCODED, NOT `worldSize` (that command
//--- is Arma-3-only / a latent bug on A2-OA 1.64; see Common_RunCommanderTeam.sqf's worldSize note and the
//--- Tools\Lint check_sqf.py A3-trap list).  Since this pass is gated to worldName=="Chernarus" above, a
//--- constant is exact.  A 480m cell with a 360m scan reach (over half the 480m step's half-diagonal, so
//--- cells overlap and no tree is missed at a boundary) keeps each nearestObjects return to a few hundred.
_mapSize = 15360;
_cell    = 480;
_reach   = 360;

_hidden  = 0;
_scanned = 0;
_perfStart = diag_tickTime;

//--- Sweep every cell.  hideObject each classless object whose stringified name contains a
//--- Chernarus vegetation prefix.  On Chernarus, tree models stringify with a colon-space-t-underscore
//--- prefix and bushes with a colon-space-b-underscore prefix; those two needles cover all vegetation.
_slept = 0;
_x0 = 0;
while {_x0 < _mapSize} do {
	_y0 = 0;
	while {_y0 < _mapSize} do {
		_cx = _x0 + (_cell / 2);
		_cy = _y0 + (_cell / 2);
		_centre = [_cx, _cy, 0];

		//--- Empty class array -> classless terrain objects (trees/bushes/stones).
		_objs = nearestObjects [_centre, [], _reach];
		{
			_o = _x;
			_scanned = _scanned + 1;
			_isVeg = false;
			//--- Only touch classless map vegetation (typeOf is empty for WRP terrain objects).
			//--- The stringified form carries the model path we prefix-match (see Server_SiteClearance.sqf,
			//--- which matches the same colon-space-t-underscore tree prefix).
			_s = toLower (str _o);
			if ([_s, [": t_", ": b_"]] call _matchAny) then { _isVeg = true };
			if (_isVeg) then {
				//--- isObjectHidden is Arma-3-only; there is no A2 read-back, so we hide
				//--- unconditionally (hideObject true is idempotent — re-hiding is a no-op).
				_o hideObject true;
				_hidden = _hidden + 1;
			};
		} forEach _objs;

		//--- Yield between cells so the whole-map sweep never frame-spikes.
		_slept = _slept + 1;
		if (_slept >= 2) then { _slept = 0; uiSleep 0.05 };

		_y0 = _y0 + _cell;
	};
	_x0 = _x0 + _cell;
};

//--- Always-on state line so the tester can confirm the pass ran + its cost (per CLAUDE.md).
["INFORMATION", Format ["Client_NoTrees.sqf: Chernarus tree-hide pass done — hidden:%1 scanned:%2 ms:%3 (machine=%4).",
	_hidden, _scanned, round ((diag_tickTime - _perfStart) * 1000),
	(if (isDedicated) then {"server"} else {if (!hasInterface) then {"HC"} else {"client"}})]] Call WFBE_CO_FNC_LogContent;
