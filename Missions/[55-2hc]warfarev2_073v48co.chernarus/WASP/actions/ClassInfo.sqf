/*
    Script: WASP\actions\ClassInfo.sqf
    Description: Shows the player a hint listing their current class and its abilities.
    Called automatically from Skill_Init.sqf on join/class change (auto mode, guarded),
    and on demand via player addAction (always shows).

    _this when called via execVM from Skill_Init:   ["auto"]
    _this when called via addAction:                [target, caller, id, args]
*/

//--- Determine call mode: ["auto"] from Skill_Init means apply the changed-class guard.
_auto = false;
if (typeName _this == "ARRAY" && {count _this == 1} && {typeName (_this select 0) == "STRING"}) then {
    _auto = ((_this select 0) == "auto");
};

//--- Read current class (re-evaluate live in case WFBE_SK_V_Type updated).
_classType = if (isNil "WFBE_SK_V_Type") then {""} else {WFBE_SK_V_Type};

//--- Guard: in auto mode, skip display if the class hasn't changed since last hint.
if (_auto) then {
    _lastShown = missionNamespace getVariable ["WFBE_WASP_ClassInfo_LastShown", "UNINIT"];
    if (_lastShown == _classType) exitWith {};
};

//--- Record last-shown class so repeated Skill_Init runs don't re-spam.
missionNamespace setVariable ["WFBE_WASP_ClassInfo_LastShown", _classType];

//--- Build hint text.
_txt = "";

switch (_classType) do {
    case "Engineer": {
        _txt = "<t size='1.1' color='#00CFFF'>Engineer</t><br/>" +
               "- Repair nearby vehicles<br/>" +
               "- Salvage wrecks for resources<br/>" +
               "- Restore captured Camps<br/>" +
               "- Use EASA at repair-truck service points";
    };
    case "Soldier": {
        _txt = "<t size='1.1' color='#00CFFF'>Soldier</t><br/>" +
               "- 1.5x AI team size cap<br/>" +
               "- Restore captured Camps";
    };
    case "SpecOps": {
        _txt = "<t size='1.1' color='#00CFFF'>SpecOps</t><br/>" +
               "- Lockpick enemy vehicles<br/>" +
               "- Run supply missions";
    };
    case "Spotter": {
        _txt = "<t size='1.1' color='#00CFFF'>Spotter (Sniper)</t><br/>" +
               "- Spot enemies as map marks<br/>" +
               "- Lockpick enemy vehicles<br/>" +
               "- Restore captured Camps";
    };
    case "Medic": {
        _txt = "<t size='1.1' color='#00CFFF'>Medic</t><br/>" +
               "- Fast healing<br/>" +
               "- Restore captured Camps<br/>" +
               "- Spawn at Medic Redeployment Truck";
    };
    default {
        _txt = "<t size='1.1' color='#AAAAAA'>No special class</t><br/>" +
               "Pick a unit type at the Barracks<br/>to gain class abilities.";
    };
};

hintSilent parseText _txt;
