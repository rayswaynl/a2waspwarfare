/*
	Common_GuerArmor.sqf — GUER "improvised armour": adds a HandleDamage to a resistance light vehicle that
	models scrappy, up-armoured technicals. NON-AT incoming fire is mitigated on a graded scale; AT/HEAT/ATGM
	rounds punch straight through so technicals stay killable. No visual. Reuses the Common_ModifyVehicle
	_rearmor pattern (HandleDamage closure returning a single numeric damage value).

	Nuanced model (per incoming hit, all percentages are of the inflicted damage):
	  effective%  = base + (tier * tierstep), capped at MAX.
	    base     = WFBE_C_GUER_IMPROVISED_ARMOR            (% reduction floor; 0 = whole feature off)
	    tier     = WFBE_GUER_VEHICLE_TIER                  (faction upgrade level, 0 if unset)
	    tierstep = WFBE_C_GUER_IMPROVISED_ARMOR_TIERSTEP   (% per tier)
	    MAX      = WFBE_C_GUER_IMPROVISED_ARMOR_MAX        (hard cap)
	  Damage tiers by incoming ammo class (_this select 4), checked in order:
	    1. AT / HEAT / ATGM  -> NO reduction (round defeats improvised plating).
	    2. EXPLOSIVE/HE/FRAG/ROCKET -> reduce by HALF the effective%.
	    3. else (small-arms / autocannon bullets) -> reduce by the FULL effective%.
	  Mobility-part protection: if the hit selection (_this select 1) names a drivetrain part, NON-AT hits get
	    an EXTRA WFBE_C_GUER_IMPROVISED_ARMOR_MOBILITY_BONUS% (still capped at MAX) so the technical stays mobile
	    under fire. NOTE: selection-name matching is HEURISTIC in Arma 2 OA (engine selection names vary per
	    model / addon), so this is best-effort, not guaranteed per vehicle.

	Input: [_vehicle]. Runs where the vehicle is local (called from Common_CreateVehicle). Arma 2 OA only.
*/
private ["_vehicle","_armor"];
_vehicle = _this select 0;
if (isNull _vehicle) exitWith {};

_armor = {
	private ["_sel","_dam","_ammo","_base","_tier","_step","_max","_eff","_class","_isMob","_out"];
	_sel  = _this select 1;
	_dam  = _this select 2;
	_ammo = _this select 4;

	//--- nothing to do for a null/zero hit or before ammo is resolved.
	if (isNil "_dam") exitWith {0};
	if (_dam <= 0) exitWith {_dam};

	_base = missionNamespace getVariable ["WFBE_C_GUER_IMPROVISED_ARMOR", 0];
	if (_base <= 0) exitWith {_dam};   //--- feature off.
	_step = missionNamespace getVariable ["WFBE_C_GUER_IMPROVISED_ARMOR_TIERSTEP", 0];
	_max  = missionNamespace getVariable ["WFBE_C_GUER_IMPROVISED_ARMOR_MAX", 45];
	_tier = missionNamespace getVariable ["WFBE_GUER_VEHICLE_TIER", 0];

	//--- effective reduction floor, scaled by faction tier and hard-capped.
	_eff = _base + (_tier * _step);
	if (_eff > _max) then {_eff = _max};

	//--- classify the incoming round. 0 = AT (no reduction), 1 = explosive/HE (half), 2 = small-arms (full).
	_class = 2;
	if (isNil "_ammo") then {_ammo = ""};
	if (typeName _ammo != "STRING") then {_ammo = ""};
	if (_ammo != "") then {
		if (
			(_ammo find "_AT") >= 0 || {(_ammo find "PG7") >= 0} || {(_ammo find "PG9") >= 0}
			|| {(_ammo find "HEAT") >= 0} || {(_ammo find "TOW") >= 0} || {(_ammo find "Maverick") >= 0}
			|| {(_ammo find "Hellfire") >= 0} || {(_ammo find "AT13") >= 0} || {(_ammo find "Metis") >= 0}
			|| {(_ammo find "Kornet") >= 0} || {(_ammo find "Vikhr") >= 0} || {(_ammo find "AT5") >= 0}
			|| {(_ammo find "AT4") >= 0} || {(_ammo find "SVIR") >= 0} || {(_ammo find "M_47") >= 0}
			|| {(_ammo find "RPG") >= 0}
		) then {
			_class = 0;
		} else {
			if (
				(_ammo find "_HE") >= 0 || {(_ammo find "Sh_") >= 0} || {(_ammo find "FFAR") >= 0}
				|| {(_ammo find "S8") >= 0} || {(_ammo find "Hydra") >= 0} || {(_ammo find "GRAD") >= 0}
				|| {(_ammo find "FAB") >= 0} || {(_ammo find "Rocket") >= 0} || {(_ammo find "Grenade") >= 0}
				|| {(_ammo find "G_") >= 0}
			) then {
				_class = 1;
			};
		};
	};

	//--- AT defeats improvised plating: pass the damage through untouched.
	if (_class == 0) exitWith {_dam};

	//--- mobility-part bonus (non-AT only). HEURISTIC: engine selection names vary per model in A2 OA.
	_isMob = false;
	if (typeName _sel == "STRING" && {_sel != ""}) then {
		if (
			(_sel find "wheel") >= 0 || {(_sel find "motor") >= 0} || {(_sel find "engine") >= 0}
			|| {(_sel find "palivo") >= 0} || {(_sel find "fuel") >= 0}
		) then {
			_isMob = true;
			_eff = _eff + (missionNamespace getVariable ["WFBE_C_GUER_IMPROVISED_ARMOR_MOBILITY_BONUS", 0]);
			if (_eff > _max) then {_eff = _max};
		};
	};

	//--- explosive/HE is mitigated at half effectiveness; small-arms at full.
	if (_class == 1) then {_eff = _eff / 2};

	_out = _dam * (1 - (_eff / 100));
	if (_out < 0) then {_out = 0};

	//--- light, WF_Debug-gated telemetry for tuning: only log when the saved damage is meaningful (>5%).
	if (!isNil "WF_Debug" && {WF_Debug} && {(_dam - _out) > 0.05}) then {
		["INFORMATION", format ["Common_GuerArmor: ammo[%1] sel[%2] class[%3] mob[%4] eff[%5%%] dam %6 -> %7", _ammo, _sel, _class, _isMob, _eff, _dam, _out]] Call WFBE_CO_FNC_LogContent;
	};

	_out
};
_vehicle addEventHandler ["HandleDamage", format ["_this Call %1", _armor]];
