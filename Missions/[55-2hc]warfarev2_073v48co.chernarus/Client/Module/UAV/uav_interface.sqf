disableSerialization;
Private ['_IGUI_update','_alt','_defaultTeamswitch','_defaultvalue','_displayEH_keydown','_displayEH_mousebuttondown','_displayEH_mousezchanged','_driver','_locked','_logic','_mapEH_mousebttondown','_newalt','_newspeed','_ppBlur','_ppColor','_ppGrain','_ppInversion','_speed','_uav'];
_defaultTeamswitch = teamswitchenabled;

startLoadingScreen ["UAV","RscDisplayLoadMission"];

_uav = playerUAV;

//--- UAV destroyed
if (isnull _uav) exitwith {endLoadingScreen;hintc format [localize "strwfbasestructuredestroyed",localize "str_uav_action"]};
_driver = driver _uav;

//--- Switch view
//--- r78 handover: pick live control unit (gunner preferred; OPFOR has no gunner slot).
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
_ppInversion = 0;

//--- Disable HC
hcshowbar false;

//--- Save prior group-icon visibility (classic path never did; restore was BIS_UAV_visible=nil).
if (isnil "BIS_UAV_visible") then {BIS_UAV_visible = groupiconsvisible};
setGroupIconsVisible [true,true];

//--- Postprocess effects
_ppColor = ppEffectCreate ["ColorCorrections", 1999];
_ppColor ppEffectEnable true;
_ppColor ppEffectAdjust [1, 1, 0, [1, 1, 1, 0], [1, 1, 1, 0.0], [1, 1, 1, 1.0]];
_ppColor ppEffectCommit 0;
_ppBlur = ppEffectCreate ["dynamicBlur", 505];
_ppBlur ppEffectEnable true;  
_ppBlur ppEffectAdjust [.5];
_ppBlur ppEffectCommit 0;
_ppGrain = ppEffectCreate ["filmGrain", 2005];
_ppGrain ppEffectEnable true;
_ppGrain ppEffectAdjust [0.02, 1, 1, 0, 1];
_ppGrain ppEffectCommit 0;

//--- RSC
1124 cutrsc ["RscUnitInfoUAV","plain"];
waituntil {!isnil {uinamespace getvariable "BIS_UAV_DISPLAY"}};
progressLoadingScreen 0.5;

//--- Minimap update
((uinamespace getvariable "BIS_UAV_DISPLAY") displayctrl 112410) mapcenteroncamera true;

//--- Default aperture
if (isnil {BIS_UAV_PLANE getvariable 'BIS_UAV_aperture'}) then {
	_defaultvalue = if (daytime > 5 && daytime < 19) then {24} else {0.07};
	BIS_UAV_PLANE setvariable ['BIS_UAV_aperture',_defaultValue];
	setaperture _defaultvalue;
} else {
	setaperture (BIS_UAV_PLANE getvariable 'BIS_UAV_aperture');
};

//--- Default height
_newalt = BIS_UAV_PLANE getvariable 'BIS_UAV_height';
if (isnil "_newalt") then {
	_alt = position _uav select 2;
	_newalt = (round (_alt / 50)) * 50;
	if (_newalt < 100) then {_newalt = 100};
	_uav flyinheight _newalt;
	_uav setvariable ['BIS_UAV_height',_newalt];
};
((uinamespace getvariable 'BIS_UAV_DISPLAY') displayctrl 112413) ctrlsettext str (_newalt);
((uinamespace getvariable 'BIS_UAV_DISPLAY') displayctrl 112413) ctrlcommit 0;

//--- Default speed
_newspeed = BIS_UAV_PLANE getvariable 'BIS_UAV_speed';
if (isnil "_newspeed") then {
	_speed = speed _uav;
	_newspeed = (round (_speed / 50)) * 50;
	if (_newalt < 200) then {_newalt = 200};
	driver _uav forcespeed _newspeed;;
	_uav setvariable ['BIS_UAV_speed',_newspeed];
};
((uinamespace getvariable 'BIS_UAV_DISPLAY') displayctrl 112412) ctrlsettext str (_newspeed);
((uinamespace getvariable 'BIS_UAV_DISPLAY') displayctrl 112412) ctrlcommit 0;

BIS_UAV_GUIinit = {scriptName "UAV\data\scripts\uav_interface.sqf: GUI Init";
	disableserialization;
	Private ['_control','_controlHint','_controls','_display'];
	_display = uinamespace getvariable "BIS_UAV_DISPLAY";
	_controls = [112401,112402,112403,112404];
	{
		_control = _display displayctrl _x;
		_control ctrlshow false;
		_control ctrlcommit 0;
	} foreach _controls;
	_controlHint = _display displayctrl 112414;
	_controlHint ctrlsettext (
		localize "str_coin_exit" + " " + localize "str_input_device_mouse_1" + "\n\n" + 
		localize "str_disp_opt_bright" + " " + localize "str_input_device_mouse_axis_z" + "\n" + 
		localize "str_arcmark_title1" + ": " + call compile actionkeysnames ["Binocular",2]
	);
	_controlHint ctrlcommit 0;
};
[] spawn BIS_UAV_GUIinit;

_IGUI_update = [] spawn {scriptName "UAV\data\scripts\uav_interface.sqf: IGUI Update";
	Private ['_uav'];
	_uav = BIS_UAV_PLANE;
	while {cameraon == BIS_UAV_PLANE} do {
		//--- r78: display lost -> terminate only. Re-ExecVM of the BI module path stacked a second
		//--- interface (duplicate display EHs / remoteControl) on top of the still-running teardown.
		if (isnull (uinamespace getvariable "BIS_UAV_DISPLAY")) then {bis_uav_terminate = true};
		if (visiblemap) then {
			if (ctrlshown ((uinamespace getvariable "BIS_UAV_DISPLAY") displayctrl 112411)) then {
				{
					((uinamespace getvariable "BIS_UAV_DISPLAY") displayctrl _x) ctrlshow false;
					((uinamespace getvariable "BIS_UAV_DISPLAY") displayctrl _x) ctrlcommit 0;
				} foreach [112410,112411,112412,112413,112414];
			};
		} else {
			if !(ctrlshown ((uinamespace getvariable "BIS_UAV_DISPLAY") displayctrl 112411)) then {
				{
					((uinamespace getvariable "BIS_UAV_DISPLAY") displayctrl _x) ctrlshow true;
					((uinamespace getvariable "BIS_UAV_DISPLAY") displayctrl _x) ctrlcommit 0;
				} foreach [112410,112411,112412,112413,112414];
			};
		};
		((uinamespace getvariable "BIS_UAV_DISPLAY") displayctrl 112411) ctrlsettext str (round speed _uav);
		((uinamespace getvariable "BIS_UAV_DISPLAY") displayctrl 112411) ctrlcommit 0;
		sleep 1;
	};
};

//--- Detect pressed keys (temporary solution)
_displayEH_keydown = (finddisplay 46) displayaddeventhandler ["keydown","
	Private ['_id','_key','_level','_marker','_markertime','_ppInversion','_uav','_worldpos'];
	_key = _this select 1;

	comment '--- END';
	if (_key in (actionkeys 'menuback')) then {bis_uav_terminate = true};

	comment '--- NVG';
	if (_key in (actionkeys 'NightVision')) then {
		_uav = BIS_UAV_PLANE;
		if (isnil {_uav getvariable 'BIS_UAV_pp_NVG'}) then {
			_ppInversion = ppEffectCreate ['colorInversion', 2555];
			_ppInversion ppEffectEnable true;
			_ppInversion ppEffectAdjust [1,1,1];
			_ppInversion ppEffectCommit 0;
			_uav setvariable ['BIS_UAV_pp_NVG',_ppInversion];
		} else {
			ppEffectDestroy (_uav getvariable 'BIS_UAV_pp_NVG');
			_uav setvariable ['BIS_UAV_pp_NVG',nil];
		};
	};

	comment '--- MARKER';
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

	comment '--- UP';
	if (_key in (actionkeys 'HeliUp')) then {
		_uav = BIS_UAV_PLANE;
		_level = _uav getvariable 'BIS_UAV_height';
		_level = _level + 50;
		if (_level > 1000) then {_level = 1000};
		_uav flyinheight _level;
		_uav setvariable ['BIS_UAV_height',_level];
		((uinamespace getvariable 'BIS_UAV_DISPLAY') displayctrl 112413) ctrlsettext str (_level);
		((uinamespace getvariable 'BIS_UAV_DISPLAY') displayctrl 112413) ctrlcommit 0;
	};

	comment '--- DOWN';
	if (_key in (actionkeys 'HeliDown')) then {
		_uav = BIS_UAV_PLANE;
		_level = _uav getvariable 'BIS_UAV_height';
		_level = _level - 50;
		if (_level < 100) then {_level = 100};
		_uav flyinheight _level;
		_uav setvariable ['BIS_UAV_height',_level];
		((uinamespace getvariable 'BIS_UAV_DISPLAY') displayctrl 112413) ctrlsettext str (_level);
		((uinamespace getvariable 'BIS_UAV_DISPLAY') displayctrl 112413) ctrlcommit 0;
	};

	comment '--- FORWARD';
	if (_key in (actionkeys 'HeliForward')) then {
		_uav = BIS_UAV_PLANE;
		_level = _uav getvariable 'BIS_UAV_speed';
		_level = _level + 50;
		if (_level > 500) then {_level = 500};
		if (_level < 200) then {_level = 200};
		driver _uav forcespeed (_level / 3.6);
		_uav setvariable ['BIS_UAV_speed',_level];
		((uinamespace getvariable 'BIS_UAV_DISPLAY') displayctrl 112412) ctrlsettext str (_level);
		((uinamespace getvariable 'BIS_UAV_DISPLAY') displayctrl 112412) ctrlcommit 0;
	};

	comment '--- BACK';
	if (_key in (actionkeys 'HeliBack')) then {
		_uav = BIS_UAV_PLANE;
		_level = _uav getvariable 'BIS_UAV_speed';
		_level = _level - 50;
		if (_level > 500) then {_level = 500};
		if (_level < 200) then {_level = 200};
		driver _uav forcespeed (_level / 3.6);
		_uav setvariable ['BIS_UAV_speed',_level];
		((uinamespace getvariable 'BIS_UAV_DISPLAY') displayctrl 112412) ctrlsettext str (_level);
		((uinamespace getvariable 'BIS_UAV_DISPLAY') displayctrl 112412) ctrlcommit 0;
	};
"];

//--- Detect pressed mouse buttons
_displayEH_mousebuttondown = (finddisplay 46) displayaddeventhandler ["mousebuttondown","
	disableserialization;
	Private ['_button','_control','_controls','_display'];
	_button = _this select 1;
	if (_button == 007 && !visiblemap) then {comment 'DISABLED';
		_display = uinamespace getvariable 'BIS_UAV_DISPLAY';
		_controls = [112401,112402,112403,112404];
		{
			_control = _display displayctrl _x;
			_control ctrlshow !(ctrlshown _control);
			_control ctrlcommit 0;
		} foreach _controls;
	};
	if (_button == 1 && !visiblemap && 65665 in (actionkeys 'menuback')) then {bis_uav_terminate = true};
"];

//--- Detect mouse wheel rotation
_displayEH_mousezchanged = (finddisplay 46) displayaddeventhandler ["mousezchanged","
	Private ['_aperture','_oldAperture','_zChangeFinal','_zchange'];
	_zchange = _this select 1;
	_oldAperture = BIS_UAV_PLANE getvariable 'BIS_UAV_aperture';
	_zChangeFinal = _zChange / 2;
	if (_oldAperture <= 1.0) then {_zChangeFinal = _zChange / 10};
	if (_oldAperture <= 0.1) then {_zChangeFinal = _zChange / 1000};
	_aperture = _oldAperture + _zchangeFinal;
	if (_oldaperture > 1.0 && _aperture < 1.0) then {_aperture = 1.0};
	if (_oldaperture > 0.1 && _aperture < 0.1) then {_aperture = 0.1};
	if (_aperture < 0.001) then {_aperture = 0.001};
	BIS_UAV_PLANE setvariable ['BIS_UAV_aperture',_aperture];
	setaperture _aperture;
"];

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

endLoadingScreen;

//--- TERMINATE
waituntil {!isnil "bis_uav_terminate" || !alive _uav || !alive player};
Private ["_playerDied","_mkId","_mkName","_ppNvg"];
_playerDied = !alive player;
if (!alive _uav) then {
	hintc format [localize "strwfbasestructuredestroyed",localize "str_uav_action"];
};
//--- Restore the originally disabled pilot even if the UAV hull was destroyed first.
if (!isNull _driver && {alive _driver}) then {{_driver enableAI _x} forEach ["TARGET","AUTOTARGET"]};
if (!isNull _uav) then {_uav lock _locked};
titletext ["","black in"];
bis_uav_terminate = nil;
BIS_UAV_TIME = nil;
BIS_UAV_PLANE = nil;
if (!isNull _rcUnit) then {objnull remoteControl _rcUnit};
player switchcamera "internal";
enableteamswitch _defaultTeamswitch;

//--- Clear operator-placed UAV map markers.
_mkId = 1;
_mkName = format ['_user_defined_UAV_MARKER_%1',_mkId];
while {markerType _mkName != ''} do {
	deleteMarker _mkName;
	_mkId = _mkId + 1;
	_mkName = format ['_user_defined_UAV_MARKER_%1',_mkId];
};

//--- Death / destroyed hull: drop operator binding so respawn does not inherit control.
if (_playerDied || {!alive _uav} || {isNull _uav}) then {
	if (!isNil "playerUAV" && {playerUAV == _uav}) then {playerUAV = objNull};
};

if (!isNil "BIS_UAV_visible") then {
	setGroupIconsVisible BIS_UAV_visible;
	BIS_UAV_visible = nil;
};

setaperture -1;
ppEffectDestroy _ppColor;
ppEffectDestroy _ppBlur;
if (!isNull _uav) then {
	_ppNvg = _uav getvariable 'BIS_UAV_pp_NVG';
	if (!isNil "_ppNvg") then {ppEffectDestroy _ppNvg};
};
ppEffectDestroy _ppGrain;

1124 cuttext ["","plain"];
(finddisplay 46) displayremoveeventhandler ["keydown",_displayEH_keydown];
(finddisplay 46) displayremoveeventhandler ["mousebuttondown",_displayEH_mousebuttondown];
(finddisplay 46) displayremoveeventhandler ["mousezchanged",_displayEH_mousezchanged];
((findDisplay 12) displayCtrl 51) ctrlremoveeventhandler ["mousebuttondown",_mapEH_mousebttondown];
