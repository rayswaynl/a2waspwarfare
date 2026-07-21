private["_delay","_lastCheck","_lastSID","_lastUpdate","_txt","_colorBlue","_colorGreen","_colorRed","_colorBlack","_colorFriendly","_colorEnemy","_colorResistance","_ui_bg","_town_capture_mode","_captureDetail","_lastEntity","_lastSV","_nearest","_update","_sideID","_curSV","_maxSV","_safeMaxSV","_camp","_campActive","_campBunker","_baseText","_trendText","_trendSecs","_trendDelta","_trendPerMin","_barColor","_control","_backgroundControl","_textControl","_maxWidth","_position","_campTotal","_campHeld","_campStartSV"];

disableSerialization;
_delay = 4;
_lastCheck = "";
_lastSID = -1;
_lastUpdate = time;
_txt = "";

_colorBlue = [0,0,0.7,0.6];
_colorGreen = [0,0.7,0,0.6];
_colorRed = [0.7,0,0,0.6];
_colorBlack = [0,0,0,0.6];

_colorFriendly = _colorGreen;
_colorEnemy =_colorRed;
_colorResistance =_colorBlue;

_ui_bg = [0,0,0,0.7];
_town_capture_mode = missionNamespace getVariable ["WFBE_C_TOWNS_CAPTURE_MODE", 0];
_captureDetail = (missionNamespace getVariable ["WFBE_C_TOWNS_CAPTURE_BAR_DETAIL", 0]) > 0;
_lastEntity = objNull;
_lastSV = -1;

while {!WFBE_GameOver} do {
	_nearest = [player,towns] Call WFBE_CO_FNC_GetClosestEntity;
	_update = if (!isNull _nearest && {player distance _nearest < (_nearest getVariable "range")} && {alive player}) then {true} else {false};
	
	if(_update && !WFBE_GameOver)then{
		_sideID = _nearest getVariable ["sideID", WFBE_C_UNKNOWN_ID];
		_curSV = _nearest getVariable ["supplyValue", 0];
		_maxSV = _nearest getVariable ["maxSupplyValue", 30];
		_safeMaxSV = _maxSV;
		if (_safeMaxSV < 1) then {_safeMaxSV = 1};

		_camp = [vehicle player, 12, true] Call WFBE_CL_FNC_GetClosestCamp;
		_campActive = false;
		if (_captureDetail && {_town_capture_mode == 2}) then {
			//--- Match server_town.sqf: only live camp bunkers belong to the mode-2 tally.
			_campTotal = 0;
			_campHeld = 0;
			{
				if (!isNull _x) then {
					_campBunker = _x getVariable ["wfbe_camp_bunker", objNull];
					if (!isNull _campBunker && {alive _campBunker}) then {
						_campTotal = _campTotal + 1;
						if ((_x getVariable ["sideID", WFBE_C_UNKNOWN_ID]) == WFBE_Client_SideID) then {_campHeld = _campHeld + 1};
					};
				};
			} forEach (_nearest getVariable ["camps", []]);
		};

		if (_town_capture_mode != 0 && !isNull _camp) then {
			_campBunker = _camp getVariable ["wfbe_camp_bunker", objNull];
			if (!isNull _campBunker && {alive _campBunker}) then {
				_campActive = true;
				_sideID = _camp getVariable ["sideID", WFBE_C_UNKNOWN_ID];
				_curSV = _camp getVariable ["supplyValue", 0];
				_campStartSV = _nearest getVariable ["startingSupplyValue", _safeMaxSV];
				_txt = "";
				if (_captureDetail) then {
					_baseText = Format ["%1  -  Camp SV %2/%3", (_nearest getVariable ["name", ""]), _curSV, _campStartSV];
					_txt = _baseText;
					if (_town_capture_mode == 2) then {_txt = Format ["%1  |  Camps %2/%3", _baseText, _campHeld, _campTotal]};
				};
				if (_lastCheck == "Town") then {_delay = 0};
				_lastCheck = "Camp";
				_lastEntity = objNull;
				_lastSV = -1;
				_lastUpdate = time;
			};
		};

		if (!_campActive) then {
			_baseText = Format ["%1  -  %2", (_nearest getVariable ["name",""]), (Format [localize "STR_WF_TownSV", _curSV,_maxSV])];
			_txt = _baseText;
			if (_captureDetail) then {
				_trendText = "Watching";
				if (_nearest == _lastEntity && _sideID == _lastSID && _lastSV >= 0) then {
					_trendSecs = time - _lastUpdate;
					if (_trendSecs > 0) then {
						_trendDelta = _curSV - _lastSV;
						if (_trendDelta < 0) then {
							_trendPerMin = round (((0 - _trendDelta) * 60) / _trendSecs);
							_trendText = Format ["Contested -%1/m", _trendPerMin];
						} else {
							if (_trendDelta > 0) then {
								_trendPerMin = round ((_trendDelta * 60) / _trendSecs);
								_trendText = Format ["Recovering +%1/m", _trendPerMin];
							} else {
								_trendText = "Stalled";
							};
						};
					};
				};
				_txt = Format ["%1  |  %2", _baseText, _trendText];
				if (_town_capture_mode == 2) then {_txt = Format ["%1  |  Camps %2/%3", _txt, _campHeld, _campTotal]};
			};
			_lastEntity = _nearest;
			_lastSV = _curSV;
			_lastUpdate = time;
			_lastCheck = "Town";
		};

		if (_sideID != _lastSID) then {_delay = 0};
		if (isNull (uiNamespace getVariable "wfbe_title_capture")) then {600200 cutRsc["CaptureBar","PLAIN",0];_delay = 0};
		if !(isNull (uiNamespace getVariable "wfbe_title_capture")) then {
	
			_barColor = _colorResistance;
			if ((_sideID == WESTID)&&(sideID == WESTID) || (_sideID == EASTID)&&(sideID == EASTID)) then {_barColor = _colorFriendly}; //--- Green
			if ((_sideID == WESTID)&&(sideID == EASTID) || (_sideID == EASTID)&&(sideID == WESTID)) then {_barColor = _colorEnemy};

			_control = (uiNamespace getVariable "wfbe_title_capture") displayCtrl 601001;
			_control ctrlShow true;
			_control ctrlSetBackgroundColor _barColor;
			_backgroundControl = (uiNamespace getVariable "wfbe_title_capture") displayCtrl 601000;
			_backgroundControl ctrlShow true;
			_backgroundControl ctrlSetBackgroundColor _ui_bg;
			_textControl = (uiNamespace getVariable "wfbe_title_capture") displayCtrl 601002;
			_textControl ctrlShow true;
			_textControl ctrlSetText _txt;
			_maxWidth = (ctrlPosition _backgroundControl Select 2) - 0.02;
			_position = ctrlPosition _control;
			_position set [2,_maxWidth * _curSV / _safeMaxSV];
			_control ctrlSetPosition _position;
			_control ctrlCommit _delay;
			_delay = 4;
			_lastSID = _sideID;
		};
	};
	if(!_update && !WFBE_GameOver)then{
		_delay = 0;
		if (isNull (uiNamespace getVariable "wfbe_title_capture")) then {600200 cutRsc["CaptureBar","PLAIN",0]};
		if (!isNull (uiNamespace getVariable "wfbe_title_capture")) then {
			{((uiNamespace getVariable "wfbe_title_capture") displayCtrl _x) ctrlShow false} forEach [601000,601001,601002];
		};
		_lastEntity = objNull;
		_lastSV = -1;
		_lastUpdate = time;
	};
	sleep 2;
};
