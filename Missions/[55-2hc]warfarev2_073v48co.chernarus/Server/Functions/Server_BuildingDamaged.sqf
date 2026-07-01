Private["_damage","_damagedBy","_logik","_side","_structure","_redu"];

_structure = _this select 0;
_damagedBy = _this select 1;
_damage = _this select 2;
_redu = if (_structure isKindOf "Warfare_HQ_base_unfolded") then {5} else {missionNamespace getVariable "WFBE_C_STRUCTURES_DAMAGES_REDUCTION"};
_side = _structure getVariable "wfbe_side";
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;

if ((getDammage _structure) + (_damage / (_redu)) < 1) then {
	//--- claude/guer-radio-announcer: default to 0. wfbe_structure_lasthit is only initialized on the WEST/EAST
	//--- side logics (Init_Server.sqf ~607, east/west-only loop); base-less GUER (WFBE_L_GUE) never gets it, so a
	//--- bare read returned nil and `time - nil` threw - aborting this handler BEFORE the IsUnderAttack SideMessage
	//--- below (so a GUER FOB under fire emitted no radio call + one RPT type error per hit). Line below writes the
	//--- real `time` back, so the default only ever applies to the first hit on any side missing the var.
	if (time - (_logik getVariable ["wfbe_structure_lasthit", 0]) > 2 && _damage > 0.05) then {
		_logik setVariable ["wfbe_structure_lasthit", time];
		[_side, "IsUnderAttack", ["Base", _structure]] Spawn SideMessage;
	};
};