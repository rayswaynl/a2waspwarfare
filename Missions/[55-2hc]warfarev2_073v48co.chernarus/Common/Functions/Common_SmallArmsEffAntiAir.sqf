/*
	Common_SmallArmsEffAntiAir.sqf

	Author: fable (fable/smallarms-air-envelope, GR-2026-07-08a)

	Description:
		Effectiveness classifier for the small-arms x AIR engagement envelope
		(WFBE_C_SMALLARMS_AIR_ENVELOPE). Returns TRUE when this unit can
		MEANINGFULLY damage aircraft - i.e. it personally carries a man-portable
		AA launcher / AA missile - and is therefore IMMUNE to air-lock steering at
		ANY range. Everything else (rifles, MGs, even AT launchers) returns FALSE
		and may be steered off an air lock BEYOND the effective envelope.

		Classified by WEAPON CAPABILITY, never by name substring: the
		Soldier_Bodyguard_AA12_PMC carries an AA-12 SHOTGUN, not anti-air, so a
		"_AA" name test would wrongly immunise it (recon-flagged trap). The AA set
		is the canonical A2-OA MANPAD launcher / missile classnames, all in-tree:
		Stinger (US/USMC), Igla (RU/INS/TK/GUE/PMC), Strela (CDF - added at
		Common_CreateTownUnits.sqf) + the turret AA reload mags 2Rnd_Stinger /
		2Rnd_Igla (a dismounted crewman keeping an AA pod mag still reads AA).

		AA-VEHICLE crews and AA-STATIC gunners are handled by the manager's
		mounted-unit skip (vehicle _u != _u), not here - their weapon is the hull's,
		so a personal-loadout scan would miss it and the mounted skip covers them.

		A2-OA-safe: secondaryWeapon / magazines getters, `in` membership, a plain
		boolean flag (no ==/!= on booleans, no forEach-exitWith, no A3 commands).
		_this = unit. Returns BOOL.
*/

private ["_u", "_isAA", "_sw"];

_u = _this;
_isAA = false;

if (isNull _u) exitWith {false};

//--- Personal AA launcher in the secondary (launcher) slot => can engage air.
_sw = secondaryWeapon _u;
if (_sw in ["Stinger", "Igla", "Strela"]) then {_isAA = true};

//--- Or an AA missile magazine on the man (MANPAD reload / retained AA pod magazine).
if (!_isAA) then {
	{
		if (_x in ["Stinger", "Igla", "Strela", "2Rnd_Stinger", "2Rnd_Igla"]) then {_isAA = true};
	} forEach (magazines _u);
};

_isAA
