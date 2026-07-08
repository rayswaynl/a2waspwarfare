/*
	Common_IsMobileArtillery.sqf  (Ray 2026-06-29)

	Classifier: is _unit a TRACKED or WHEELED self-propelled artillery hull?
	Ray's directive: "AI comm can only field TRACKED or WHEELED heavy/light
	artillery. NO statics or weapon teams."

	Parameters:  _this select 0 = unit/vehicle OBJECT
	             _this select 1 = side (for the IsArtillery family lookup)
	Returns:     BOOL - true only for a self-propelled arty hull (GRAD/MLRS/
	             RM70/M1129 etc); false for towed howitzers (D30/M119) and
	             mortars (2b14/M252), which are StaticWeapon emplacements, and
	             for anything that is not artillery at all.

	Rule (Ray, verbatim): ([typeOf _x,_side] Call IsArtillery) != -1
	  AND ((_x isKindOf "Tank") || (_x isKindOf "Car")
	       || (_x isKindOf "Wheeled_APC") || (_x isKindOf "Tracked_APC"))
	  AND NOT (_x isKindOf "StaticWeapon").

	A2-OA-1.64 safe: typeOf/isKindOf/Call, no A3 primitives, no params.
*/
private ["_unit","_side","_isArty","_isMobileHull"];
_unit = _this select 0;
_side = _this select 1;

if (isNull _unit) exitWith {false};

//--- Must be a known artillery class for the side (towed/mortar/SPG all match here).
_isArty = ([typeOf _unit, _side] Call IsArtillery) != -1;
if (!_isArty) exitWith {false};

//--- Self-propelled = on a vehicle chassis (tracked/wheeled), NOT a static emplacement.
_isMobileHull = (_unit isKindOf "Tank")
             || (_unit isKindOf "Car")
             || (_unit isKindOf "Wheeled_APC")
             || (_unit isKindOf "Tracked_APC");

(_isMobileHull && {!(_unit isKindOf "StaticWeapon")})
