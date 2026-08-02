Private ["_vehicle"];

_vehicle = _this select 0;

//--- WFBE_EASA_FNC_AttachSEADRow (owner ruling 2026-08-02, flag WFBE_C_SEAD_EASA_ROW default 0).
//--- Applies the opt-in "[SEAD] Anti-radar guidance" EASA row: attaches the same Fired EH used by
//--- the master-gated auto-attach (Common_HandleSEADMissile.sqf, still gated by WFBE_C_SEAD internally),
//--- WITHOUT going through EASA_Equip.sqf - that call removes the old loadout weapons and adds the new
//--- row weapons, which would strip the current ordnance since this row carries an empty [[],[]] pair.
//--- Idempotent: re-selecting the row while already active does not stack a second Fired EH.

if (typeName _vehicle != "OBJECT") exitWith {["ERROR", Format ["EASA_AttachSEADRow.sqf: Invalid Parameter (_vehicle), expected object instead of [%1]", _vehicle]] Call WFBE_CO_FNC_LogContent};

if (!(_vehicle getVariable ["WFBE_SEAD_EasaRowActive", false])) then {
	private ["_ehIdx"];
	_ehIdx = _vehicle addEventHandler ["Fired", {_this spawn WFBE_CO_FNC_HandleSEADMissile}];
	_vehicle setVariable ["WFBE_SEAD_EhIndex", _ehIdx, true];
	_vehicle setVariable ["WFBE_SEAD_EasaRowActive", true, true];
	["INFORMATION", Format ["SEADROW|v1|attach|%1", typeOf _vehicle]] Call WFBE_CO_FNC_LogContent;
};
