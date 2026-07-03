/*
	HandleDamage handler for player JETS (fixed-wing Planes).

	Goal: make jets survivable like helicopters. The FIRST hit from a ground SPAAG
	(Tunguska 2S6M / M6 Linebacker) drains the jet's fuel to 0 and applies only slight,
	non-lethal damage, so the pilot can attempt a dead-stick glide/landing and escape.
	A SECOND, separate SPAAG hit always destroys the jet. Repairing the jet at a service
	point (Client\Functions\Client_SupportRepair.sqf) restores fuel to 100% and re-arms
	this mechanic. A jet that then crashes still rewards the shooter via the existing
	delayed last-hit attribution (Server\PVFunctions\RequestOnUnitKilled.sqf).

	HandleDamage params: [unit, selection, damage, source, ammo]
	Returns: the damage value the engine applies for this selection.

	Arma 2 OA only — no params/pushBack/selectRandom/isEqualTo/etc.
*/

private ["_unit","_dmg","_source","_ammo","_result","_isAA","_srcType","_srcVehType","_hits","_last","_newEvent"];

_unit   = _this select 0;
_dmg    = _this select 2;
_source = _this select 3;
_ammo   = _this select 4;

_result = _dmg; //--- Default: pass the engine's proposed damage through unchanged.

//--- Detect a hit from a ground anti-air vehicle (Tunguska / Linebacker): by firing vehicle, or by their AA projectile.
_isAA = false;
if (!isNull _source) then {
	_srcType = typeOf _source;
	_srcVehType = typeOf (vehicle _source);
	if (_srcType in ["2S6M_Tunguska","M6_EP1"] || _srcVehType in ["2S6M_Tunguska","M6_EP1"]) then {_isAA = true};
};
if (_ammo in ["M_9M311_AA","M_Stinger_AA"]) then {_isAA = true};

if (_isAA) then {
	//--- A single missile/burst fires HandleDamage several times (one per hit-point). Debounce so
	//--- one engagement counts as one logical hit and only drains fuel once.
	_last = _unit getVariable ["wfbe_jet_aa_lasthit", -100];
	_newEvent = (time - _last) > 1.5;
	_unit setVariable ["wfbe_jet_aa_lasthit", time, true];

	_hits = _unit getVariable ["wfbe_jet_aa_hits", 0];
	if (_newEvent) then {
		_hits = _hits + 1;
		_unit setVariable ["wfbe_jet_aa_hits", _hits, true];
		if (_hits == 1) then {_unit setFuel 0}; //--- forced dead-stick glide/landing
	};

	if (_hits <= 1) then {
		//--- First engagement (and all of its sub-selections): slight, never lethal.
		_result = _dmg min ((getDammage _unit) + 0.25) min 0.9;
	} else {
		//--- Second (or later) separate SPAAG engagement: always destroy.
		_result = 1;
	};
};

_result
