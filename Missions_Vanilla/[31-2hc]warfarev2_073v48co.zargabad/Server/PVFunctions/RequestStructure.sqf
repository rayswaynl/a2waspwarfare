Private ['_dir','_index','_pos','_script','_side','_structure','_structureType','_structures','_structuresNames','_rlType'];

_side = _this select 0;
_structureType = _this select 1;
_pos = _this select 2;
_dir = _this select 3;

_structures = missionNamespace getVariable Format ['WFBE_%1STRUCTURES',str _side];
_structuresNames = missionNamespace getVariable Format ['WFBE_%1STRUCTURENAMES',str _side];
_rlType = _structures select (_structuresNames find _structureType);

["DEBUG (RequestStructure.sqf)", Format ["Building: %1", _rlType]] Call WFBE_CO_FNC_LogContent;

if (_rlType in ["Barracks", "Light", "CommandCenter", "Heavy", "Aircraft", "ServicePoint", "AARadar"]) then {
    [_side, "HandleSpecial", ['building-started', _rlType, _pos]] Call WFBE_CO_FNC_SendToClients;
};

_index = (missionNamespace getVariable Format ["WFBE_%1STRUCTURENAMES",str _side]) find _structureType;
if (_index != -1) then {
	_script = (missionNamespace getVariable Format ["WFBE_%1STRUCTURESCRIPTS",str _side]) select _index;
	[_structureType,_side,_pos,_dir,_index] ExecVM (Format["Server\Construction\Construction_%1.sqf",_script]);
};