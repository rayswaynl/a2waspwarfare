disableSerialization;
Private ['_action_leave','_defaultTeamswitch','_displayEH_keydown','_displayEH_mousebuttondown','_driver','_locked','_logic','_mapEH_mousebttondown','_ppColor','_uav'];
_defaultTeamswitch = teamswitchenabled;

startLoadingScreen ["UAV","RscDisplayLoadMission"];

_uav = playerUAV;

//--- UAV destroyed
if (isnull _uav) exitwith {endLoadingScreen;hint format [localize "strwfbasestructuredestroyed",localize "str_uav_action"]};
_driver = driver _uav;

//--- Switch view
//--- r78 handover: OPFOR UAV has no gunner slot (uav.sqf) - remoteControl gunner was a no-op and
//--- exit always released gunner even when driver was possessed. Pick a live control unit once.
Private ["_rcUnit","_weps"];
_rcUnit = gunner _uav;
if (isNull _rcUnit) then {_rcUnit = driver _uav};
if (!isNull _rcUnit) then {_rcUnit removeweapon "nvgoggles"};
_uav switchcamera "internal";
if (!isNull _rcUnit) then {player remoteControl _rcUnit};
_locked = locked _uav;
_uav lock true;
_weps = weapons _uav;
if (count _weps > 0) then {_uav selectweapon (_weps select 0)};
enableteamswitch false;
titletext ["","black in"];
BIS_UAV_TIME = 0;
BIS_UAV_PLANE = _uav;

//--- Action!
_action_leave = _uav addaction [
	localize "STR_EP1_UAV_action_exit",
	"ca\modules_e\uav\data\scripts\uav_actionCommit.sqf",
	[0],
	1,
	false,
	true,
	"PersonView",
	"isnil 'BIS_UAV_noExit'"
];

//--- Disable HC
if (hcShownBar) then {hcshowbar false};

if (isnil "BIS_UAV_visible") then {BIS_UAV_visible = groupiconsvisible};
setGroupIconsVisible [true,true];

//--- Prostprocess effects
//setaperture 24;
_ppColor = ppEffectCreate ["ColorCorrections", 1999];
_ppColor ppEffectEnable true;
_ppColor ppEffectAdjust [1, 1, 0, [1, 1, 1, 0], [1, 1, 1, 0.0], [0.2, 0.2, 0.2, 0]];
_ppColor ppEffectCommit 0;


//--- RSC
progressLoadingScreen 0.5;

//--- Detect pressed keys (temporary solution)
BIS_UAV_HELI_keydown = {
	Private ['_id','_key','_marker','_markertime','_newHeight','_uav','_worldpos'];
	_key = _this select 1;
	_uav = BIS_UAV_PLANE;

	//--- END
	//if (_key in (actionkeys 'menuback') && isnil 'BIS_UAV_noExit') then {bis_uav_terminate = true};

	//--- MARKER
	if (_key in (actionkeys 'binocular') && !visiblemap) then {
		_id = 1;
		while {markertype format ['_user_defined_UAV_MARKER_%1',_id] != ''} do {
			_id = _id + 1;
		};
		_worldpos = screentoworld [0.5,0.5];
		_marker = createmarker [format ['_user_defined_UAV_MARKER_%1',_id],_worldpos];
		_marker setmarkertype 'mil_destroy';
		_marker setmarkercolor 'colorred';
		_marker setmarkersize [0.5,0.5];
		_markertime = [daytime] call bis_fnc_timetostring;
		_marker setmarkertext format ['UAV %1: %2',_id,_markertime];
	};

	//--- UP
	if (_key in (actionkeys 'HeliUp')) then {
		_newHeight = (position _uav select 2) + 50;
		if (_newHeight > 1000) then {_newHeight = 1000};
		if (speed _uav < 1) then {_uav domove position _uav;};
		_uav land 'none';
		_uav flyinheight _newHeight;
	};

	//--- DOWN
	if (_key in (actionkeys 'HeliDown')) then {
		_newHeight = (position _uav select 2) - 50;
		if (_newHeight < 100) then {_newHeight = 100};
		_uav land 'none';
		_uav flyinheight _newHeight;
	};
};
_displayEH_keydown = (finddisplay 46) displayaddeventhandler ["keydown","Private['_sqf']; _sqf = _this spawn BIS_UAV_HELI_keydown"];

//--- Detect pressed mouse buttons
_displayEH_mousebuttondown = (finddisplay 46) displayaddeventhandler ["mousebuttondown","
	disableserialization;
	Private ['_button'];
	_button = _this select 1;
"];


//_display = findDisplay 12;
//_map = _display displayCtrl 51;
_mapEH_mousebttondown = ((findDisplay 12) displayCtrl 51) ctrladdeventhandler ["mousebuttondown", "
	Private ['_button','_uav','_worldpos','_wp'];
	_button = _this select 1;
	if (_button == 0) then {
		_uav = BIS_UAV_PLANE;

		while {count (waypoints _uav) > 0} do {deletewaypoint ((waypoints _uav) select 0)};

		_worldpos = (_this select 0) posscreentoworld [_this select 2,_this select 3];
		_wp = (group _uav) addwaypoint [_worldpos,0];
		_wp setWaypointType 'MOVE';
		(group _uav) setcurrentwaypoint _wp;
	};
"];

//////////////////////////////////////////////////
endLoadingScreen;
//////////////////////////////////////////////////


//--- TERMINATE
waituntil {!isnil "bis_uav_terminate" || !alive _uav || !alive player};
Private ["_playerDied","_mkId","_mkName"];
_playerDied = !alive player;
if (!alive _uav) then {
	hint format [localize "strwfbasestructuredestroyed",localize "str_uav_action"];
};
//--- Restore the originally disabled pilot even if the UAV hull was destroyed first.
if (!isNull _driver && {alive _driver}) then {{_driver enableAI _x} forEach ["TARGET","AUTOTARGET"]};

if (!isNull _uav) then {_uav lock _locked};
titletext ["","black in"];
bis_uav_terminate = nil;
BIS_UAV_TIME = nil;
BIS_UAV_PLANE = nil;
//--- Release the same unit we possessed (not hard-coded gunner).
if (!isNull _rcUnit) then {objnull remoteControl _rcUnit};
player switchcamera "internal";
enableteamswitch _defaultTeamswitch;

if (!isNull _uav) then {_uav removeaction _action_leave};

//--- Clear operator-placed UAV map markers so a later session does not inherit overlays.
_mkId = 1;
_mkName = format ['_user_defined_UAV_MARKER_%1',_mkId];
while {markerType _mkName != ''} do {
	deleteMarker _mkName;
	_mkId = _mkId + 1;
	_mkName = format ['_user_defined_UAV_MARKER_%1',_mkId];
};

//--- Death: drop operator binding so respawn cannot re-open the terminal on a ghost session.
if (_playerDied) then {
	if (!isNil "playerUAV" && {playerUAV == _uav}) then {playerUAV = objNull};
};
//--- Destroyed hull: also drop binding (alive check in uav.sqf is a second line of defence).
if (!alive _uav || {isNull _uav}) then {
	if (!isNil "playerUAV" && {playerUAV == _uav}) then {playerUAV = objNull};
};

if (!isNil "BIS_UAV_visible") then {
	setGroupIconsVisible BIS_UAV_visible;
	BIS_UAV_visible = nil;
};

ppEffectDestroy _ppColor;

//1124 cuttext ["","plain"];
(finddisplay 46) displayremoveeventhandler ["keydown",_displayEH_keydown];
(finddisplay 46) displayremoveeventhandler ["mousebuttondown",_displayEH_mousebuttondown];
//(finddisplay 46) displayremoveeventhandler ["mousezchanged",_displayEH_mousezchanged];
((findDisplay 12) displayCtrl 51) ctrlremoveeventhandler ["mousebuttondown",_mapEH_mousebttondown];
