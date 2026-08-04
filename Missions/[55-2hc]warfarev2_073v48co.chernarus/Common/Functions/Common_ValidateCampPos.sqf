/*
	Common_ValidateCampPos.sqf
	Shared 6-gate position validator, ported from the proven AICOM structure-placement gates in
	Server\AI\Commander\AI_Commander_Base.sqf:181-261 (building/spacing/road/slope/tree helpers) plus the
	inline surfaceIsWater checks in that file's _findBuildPos (:317,:399). Gate logic/order is byte-identical
	to those helpers; callers supply their own thresholds so AICOM's live-tuned values and any camp-placement
	caller's values stay fully independent. Any threshold <= 0 disables that gate (same "0 = OFF" idiom
	already used throughout AI_Commander_Base.sqf).

	NOTE (fable/fix-camp-placement, 2026-07-08): this is a standalone extraction. It is NOT yet wired into
	AI_Commander_Base.sqf's own call sites - that file's _findBuildPos interleaves these gates with a
	multi-tier road/spacing fallback search loop (near-road standoff, spaced-along-road mode, diagnostic
	"via" tracing) that is hot, live-tuned, and under active adjustment (see the file's own dated comments).
	Rewiring it safely needs a dedicated, carefully-verified follow-up pass that confirms byte-identical
	AICOM behaviour via RPT AICOMPLACE lines before/after - out of scope for this correctness bundle. See
	PR body for the full rationale. Nothing in the mission tree calls this function yet; shipping it has
	zero runtime effect on its own.

	Parameters:
		_this select 0 - Position (the candidate to validate).
		_this select 1 - Array of already-placed Positions/Objects to spacing-check against (caller-supplied;
		                 e.g. a camp caller must NOT reuse WFBE_CO_FNC_GetSideStructures - that is AICOM's
		                 own building list, not a camp concern).
		_this select 2 - Spacing minimum (metres). <= 0 disables gate 6 (SPACING).
		_this select 3 - Building clearance (metres). <= 0 disables gate 3 (BUILDING).
		_this select 4 - Road buffer (metres). <= 0 disables gate 5 (ROAD).
		_this select 5 - Minimum flat surfaceNormal Z. <= 0 disables gate 2 (SLOPE).
		_this select 6 - Tree clearance (metres). <= 0 disables gate 4 (TREE); documented A2-OA no-op on
		                 unplaced map vegetation (nearestTerrainObjects is A3-only - AI_Commander_Base.sqf:237).

	Returns: Boolean - true iff the position passes ALL 6 gates.
*/

Private ["_pos","_spacingList","_spacingMin","_buildClear","_roadBuffer","_minFlatZ","_treeClear","_ok","_p2"];

_pos = _this select 0;
_spacingList = _this select 1;
_spacingMin = _this select 2;
_buildClear = _this select 3;
_roadBuffer = _this select 4;
_minFlatZ = _this select 5;
_treeClear = _this select 6;

_ok = true;

//--- GATE 1 WATER (ports the inline surfaceIsWater checks, AI_Commander_Base.sqf:317,399). Never gated off.
if (_ok && {surfaceIsWater _pos}) then {_ok = false};

//--- GATE 2 SLOPE (ports _slopeOK, AI_Commander_Base.sqf:228-234).
if (_ok && {_minFlatZ > 0} && {((surfaceNormal _pos) select 2) < _minFlatZ}) then {_ok = false};

//--- GATE 3 BUILDING (ports _buildPosClear, AI_Commander_Base.sqf:181-189).
if (_ok && {_buildClear > 0}) then {
	{ if (!isNull _x && {(_x distance _pos) < _buildClear}) exitWith {_ok = false} } forEach (nearestObjects [_pos, ["House","Building","Wall","Fence"], _buildClear + 4]);
};

//--- GATE 4 TREE (ports _treeClearOK, AI_Commander_Base.sqf:239-245; documented A2-OA no-op on map vegetation).
if (_ok && {_treeClear > 0} && {(count (nearestObjects [_pos, ["Tree","SmallTree"], _treeClear])) > 0}) then {_ok = false};

//--- GATE 5 ROAD (ports _roadClearOK, AI_Commander_Base.sqf:215-222; nearRoads is A2-OA-safe, isOnRoad/getRoadInfo are A3-only).
if (_ok && {_roadBuffer > 0} && {(count (_pos nearRoads _roadBuffer)) > 0}) then {_ok = false};

//--- GATE 6 SPACING (ports _farFromStructs, AI_Commander_Base.sqf:197-205). _spacingList is caller-supplied,
//--- NOT WFBE_CO_FNC_GetSideStructures - camps are not AICOM structures.
if (_ok && {_spacingMin > 0}) then {
	{ _p2 = if (typeName _x == "OBJECT") then {getPos _x} else {_x}; if ((_pos distance _p2) < _spacingMin) exitWith {_ok = false} } forEach _spacingList;
};

_ok
