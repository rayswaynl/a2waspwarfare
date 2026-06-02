/*
 Original author: 	Benny?
 Contributors : 	Marty
*/

disableSerialization;
_display = _this select 0;
MenuAction = -1;
mouseButtonUp = -1;
WF_MenuAction = -1; 

_cameraModes = ["Internal","External","Gunner","Group"];

// Marty : Modifying the script in order to display only human player and not bots (= empty slots) in the unit camera list :
private ["_list_Players"];
_list_Players = [];

_n = 1;
{
	if (isPlayer (leader _x)) then 
	{
		_list_Players = _list_Players + [_x] ;
		lbAdd[21002,Format["[%1] %2",_n,name (leader _x)]];
		_n = _n + 1;
	};
} forEach clientTeams;

_player_group = group player; 
_id = clientTeams find _player_group; 

lbSetCurSel[21002,_id];
_currentUnit = (player) Call GetUnitVehicle;
_currentMode = "Internal";
_currentUnit switchCamera _currentMode;
_units = (Units (group player) - [player]) Call GetLiveUnits;

{
	_unitNumber = (_x) Call GetAIDigit;
	lbAdd[21004,Format["[%1] (%2) %3", _unitNumber, GetText (configFile >> "CfgVehicles" >> (typeOf (vehicle _x)) >> "displayName"),name _x]];
} forEach _units;
// Marty end.

_type = if (!(difficultyEnabled "3rdPersonView")) then {["Internal"]} else {["Internal","External","Ironsight","Group"]};
{lbAdd[21006,_x]} forEach _type;
lbSetCurSel[21006,0];

_map = _display displayCtrl 21007;
_map ctrlMapAnimAdd [0,.25,getPos _currentUnit];
ctrlMapAnimCommit _map;

while {true} do {
	sleep 0.1;
	
	_cameraSwap = false;
	if (side group player != sideJoined || !dialog) exitWith {};

	//--- Map click.
	if (mouseButtonUp == 0) then {
		mouseButtonUp = -1;
		_near = _map PosScreenToWorld[mouseX,mouseY];
		_list = _near nearEntities [["Man","Car","Motorcycle","Ship","Tank","Air"],200];
		if (count _list > 0) then {
			_objects = [];
			{if (!(_x isKindOf "Man") && side _x != sideJoined) then {if (count (crew _x) == 0) then {_objects = _objects - [_x]}};if (side _x == sideJoined) then {_objects = _objects + [_x]}} forEach _list;
			if (count _objects > 0) then {
				_currentUnit = ([_near,_objects] Call WFBE_CO_FNC_GetClosestEntity) Call GetUnitVehicle;
				_cameraSwap = true;
			};
		};
	};	
	
	// Marty : Display the units ai owned to a selected player in the menu with their corresponding number, their type (vehicle, infantry...), their name given into the game :
	//--- Leader Selection.
	if (MenuAction == 101) then {
		MenuAction = -1;
		_selected = leader (_list_Players select (lbCurSel 21002));
		
		_currentUnit = (_selected) Call GetUnitVehicle;
		_units = (Units (group _selected) - [_selected]) Call GetLiveUnits;
		lbClear 21004;
		{
			_unitNumber = (_x) Call GetAIDigit;
			lbAdd[21004,Format["[%1] (%2) %3", _unitNumber, GetText (configFile >> "CfgVehicles" >> (typeOf (vehicle _x)) >> "displayName"),name _x]];			
		} forEach _units;
		_cameraSwap = true; 
	};
	// Marty end.
	
	//--- Leader commands AIs.
	if (MenuAction == 102) then {
		MenuAction = -1;
		_currentUnit = (_units select (lbCurSel 21004)) Call GetUnitVehicle;
		_cameraSwap = true;
	};
	
	//--- Camera Modes
	if (MenuAction == 103) then {
		MenuAction = -1;
		_currentMode = (_cameraModes select (lbCurSel 21006));
		_cameraSwap = true;
	};
	//--- Unflip button clicked
    if (WF_MenuAction == 140 && !(isNil "_currentUnit")) then {
        WF_MenuAction = -1;
        if(!(isNil "_currentUnit")) then {
            if(!(isPlayer (_currentUnit))) then {
                _vehicle = vehicle _currentUnit;            
            
                _vehicle setPos [getPos _vehicle select 0, getPos _vehicle select 1, 0.5];
                _vehicle setVelocity [0,0,-0.5];                
            };            
        };    
        _cameraSwap = true;
    };
	
	if !(alive _currentUnit) then {
		_currentUnit = (player) Call GetUnitVehicle;
		_cameraSwap = true;
	};
	
	//--- Update the Camera.
	if (_cameraSwap) then {
		ctrlMapAnimClear _map;
		_map ctrlMapAnimAdd [1,.25,getPos _currentUnit];
		ctrlMapAnimCommit _map;
		_currentUnit switchCamera _currentMode;
	};
};

closeDialog 0;
((player) Call GetUnitVehicle) switchCamera _currentMode;