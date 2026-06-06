Private ["_target","_caller","_id","_args","_command","_callerName","_clientFps","_hasDialog","_vehicleType","_cursorType","_visibleMap","_groupUnits","_vehicleSpeed","_cameraView","_gpsBefore","_shownGps","_hasItemGps","_rubHud","_rubGps","_zoomGps","_wfDisplay","_wfMenuOpen","_wfTopText","_wfGpsButtonFound","_serviceDisplay","_serviceMenuOpen","_serviceStatusText","_serviceInfoPos","_serviceClipRisk","_tacticalMenuOpen","_buyMenuOpen"];

_target = _this select 0;
_caller = _this select 1;
_id = _this select 2;
_args = _this select 3;
_command = if ((typeName _args == "ARRAY") && {(count _args) > 0}) then {_args select 0} else {"snapshot"};
_callerName = if (isNull _caller) then {"unknown"} else {name _caller};
_clientFps = (round (diag_fps * 10)) / 10;
_hasDialog = dialog;
_vehicleType = if (isNull (vehicle _caller)) then {"objNull"} else {typeOf (vehicle _caller)};
_cursorType = if (isNull cursorTarget) then {"objNull"} else {typeOf cursorTarget};
_visibleMap = visibleMap;
_groupUnits = if (isNull _caller) then {0} else {count units group _caller};
_vehicleSpeed = if (isNull (vehicle _caller)) then {0} else {round speed (vehicle _caller)};
_cameraView = cameraView;
_gpsBefore = shownGPS;

if (_command == "gps-gain-toggle-audit") then {
	if (!isNull _caller && {!("ItemGPS" in weapons _caller)}) then {_caller addWeapon "ItemGPS"};
	showGPS !(shownGPS);
	sleep 0.2;
};

_shownGps = shownGPS;
_hasItemGps = if (isNull _caller) then {false} else {"ItemGPS" in weapons _caller};
_rubHud = if (isNil "RUBHUD") then {-1} else {RUBHUD};
_rubGps = if (isNil "RUBGPS") then {-1} else {RUBGPS};
_zoomGps = if (isNil "zoomgps") then {-1} else {zoomgps};
_wfDisplay = findDisplay 11000;
_wfMenuOpen = !(isNull _wfDisplay);
_wfTopText = "";
if (_wfMenuOpen) then {_wfTopText = ctrlText (_wfDisplay displayCtrl 11015)};
_wfGpsButtonFound = false;
if (_wfMenuOpen) then {_wfGpsButtonFound = !(isNull (_wfDisplay displayCtrl 11019))};
_serviceDisplay = findDisplay 20000;
_serviceMenuOpen = !(isNull _serviceDisplay);
_serviceStatusText = "";
_serviceInfoPos = [];
_serviceClipRisk = false;
if (_serviceMenuOpen) then {
	_serviceStatusText = ctrlText (_serviceDisplay displayCtrl 20021);
	_serviceInfoPos = ctrlPosition (_serviceDisplay displayCtrl 20021);
	_serviceClipRisk = (count _serviceStatusText) > 115;
};
_tacticalMenuOpen = !(isNull (findDisplay 17000));
_buyMenuOpen = !(isNull (findDisplay 12000));

if (isNil "WASP_PR8_STRESS_ENABLED") exitWith {hint "WASP PR8 stress is disabled"};
if (!WASP_PR8_STRESS_ENABLED) exitWith {hint "WASP PR8 stress is disabled"};

WASP_PR8_STRESS_CLIENT_COMMAND = [_command, _caller, time, _callerName, _clientFps, _hasDialog, _vehicleType, _cursorType, _visibleMap, _groupUnits, _vehicleSpeed, _cameraView, _shownGps, _hasItemGps, _rubGps, _zoomGps, _wfMenuOpen, _wfTopText, _serviceMenuOpen, _serviceStatusText, _tacticalMenuOpen, _buyMenuOpen, _gpsBefore, _rubHud, _wfGpsButtonFound, _serviceClipRisk];
publicVariableServer "WASP_PR8_STRESS_CLIENT_COMMAND";

diag_log Format ["[WASP-PR8-STRESS-CLIENT] command=%1 caller=%2 target=%3 actionId=%4 clientFps=%5 dialog=%6 vehicle=%7 cursor=%8 visibleMap=%9 shownGPS=%10 gpsBefore=%11 hasItemGPS=%12 wfMenuOpen=%13 serviceOpen=%14 tacticalOpen=%15 buyOpen=%16 groupUnits=%17 vehicleSpeed=%18 cameraView=%19", _command, _callerName, _target, _id, _clientFps, _hasDialog, _vehicleType, _cursorType, _visibleMap, _shownGps, _gpsBefore, _hasItemGps, _wfMenuOpen, _serviceMenuOpen, _tacticalMenuOpen, _buyMenuOpen, _groupUnits, _vehicleSpeed, _cameraView];
diag_log Format ["[WASP-PR8-STRESS-CLIENT] CLIENT_GPS_STATE command=%1 hasItemGPS=%2 shownGPS=%3 gpsBefore=%4 changed=%5 RUBHUD=%6 RUBGPS=%7 zoomgps=%8 visibleMap=%9 dialog=%10", _command, _hasItemGps, _shownGps, _gpsBefore, (_gpsBefore != _shownGps), _rubHud, _rubGps, _zoomGps, _visibleMap, _hasDialog];
diag_log Format ["[WASP-PR8-STRESS-CLIENT] CLIENT_UI_TEXT_STATE command=%1 wfMenu=%2 topStrip='%3' gpsButtonFound=%4 serviceMenu=%5 serviceLen=%6 tacticalMenu=%7 buyMenu=%8", _command, _wfMenuOpen, _wfTopText, _wfGpsButtonFound, _serviceMenuOpen, count _serviceStatusText, _tacticalMenuOpen, _buyMenuOpen];
if (_serviceMenuOpen) then {diag_log Format ["[WASP-PR8-STRESS-CLIENT] CLIENT_SERVICE_CLIP_AUDIT display=20000 infoIdc=20021 infoPos=%1 textLen=%2 clipRisk=%3 text='%4'", _serviceInfoPos, count _serviceStatusText, _serviceClipRisk, _serviceStatusText]};
hint Format ["WASP PR8 stress: %1", _command];
