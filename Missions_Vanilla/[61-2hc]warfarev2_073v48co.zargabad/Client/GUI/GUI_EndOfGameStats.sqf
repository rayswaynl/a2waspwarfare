disableSerialization;

12450 cutText ["","PLAIN",0];

_side = _this Select 0;
_sideText = Localize "STR_WF_PARAMETER_Side_East";
if (_side == West) then {_sideText = Localize "STR_WF_PARAMETER_Side_West"};
//--- B67 [wiki-wins]: resistance previously fell through to the East label. Name it correctly.
if (_side == Resistance) then {_sideText = Localize "STR_WF_PARAMETER_Side_Guer"};
_sideName = Format[Localize "STR_WF_END_Victory",_sideText];

_guerPanel = (missionNamespace getVariable ["WFBE_C_FIX_GUER_ENDGAME_STATS_PANEL", 0]) > 0;
_width = if (_guerPanel) then {0.27} else {0.4};
TitleText["","PLAIN"];
sleep 0.5;
CutRsc["EndOfGameStats","PLAIN",0];

_eastUnitsCreated = WF_Logic getVariable "EASTUnitsCreated";
_eastCasualties = WF_Logic getVariable "EASTCasualties";
_eastVehiclesCreated = WF_Logic getVariable "EASTVehiclesCreated";
_eastVehiclesLost = WF_Logic getVariable "EASTVehiclesLost";
_westUnitsCreated = WF_Logic getVariable "WESTUnitsCreated";
_westCasualties = WF_Logic getVariable "WESTCasualties";
_westVehiclesCreated = WF_Logic getVariable "WESTVehiclesCreated";
_westVehiclesLost = WF_Logic getVariable "WESTVehiclesLost";

if (_guerPanel) then {
	_guerUnitsCreated = WF_Logic getVariable ["GUERUnitsCreated",0];
	_guerCasualties = WF_Logic getVariable ["GUERCasualties",0];
	_guerVehiclesCreated = WF_Logic getVariable ["GUERVehiclesCreated",0];
	_guerVehiclesLost = WF_Logic getVariable ["GUERVehiclesLost",0];
};

_eastCreatedRate = _eastVehiclesCreated / 5 * .1;
_eastLostRate = _eastVehiclesLost / 5 * .1;
_eastRecruitedRate = _eastUnitsCreated / 5 * .1;
_eastCasualtiesRate = _eastCasualties / 5 * .1;

_westCreatedRate = _westVehiclesCreated / 5 * .1;
_westLostRate = _westVehiclesLost / 5 * .1;
_westRecruitedRate = _westUnitsCreated / 5 * .1;
_westCasualtiesRate = _westCasualties / 5 * .1;

if (_guerPanel) then {
	_guerCreatedRate = _guerVehiclesCreated / 5 * .1;
	_guerLostRate = _guerVehiclesLost / 5 * .1;
	_guerRecruitedRate = _guerUnitsCreated / 5 * .1;
	_guerCasualtiesRate = _guerCasualties / 5 * .1;
};

waitUntil {!isNull (["currentCutDisplay"] call BIS_FNC_GUIget)};
((["currentCutDisplay"] call BIS_FNC_GUIget) DisplayCtrl 90001) CtrlSetText _sideName;

_westRecruitedCounter = (["currentCutDisplay"] call BIS_FNC_GUIget) DisplayCtrl 90200;
_westRecruitedBar = (["currentCutDisplay"] call BIS_FNC_GUIget) DisplayCtrl 90201;
_westCasualtyCounter = (["currentCutDisplay"] call BIS_FNC_GUIget) DisplayCtrl 90202;
_westCasualtyBar = (["currentCutDisplay"] call BIS_FNC_GUIget) DisplayCtrl 90203;
_westCreatedCounter = (["currentCutDisplay"] call BIS_FNC_GUIget) DisplayCtrl 90204;
_westCreatedBar = (["currentCutDisplay"] call BIS_FNC_GUIget) DisplayCtrl 90205;
_westLostCounter = (["currentCutDisplay"] call BIS_FNC_GUIget) DisplayCtrl 90206;
_westLostBar = (["currentCutDisplay"] call BIS_FNC_GUIget) DisplayCtrl 90207;
_playerSummary = (["currentCutDisplay"] call BIS_FNC_GUIget) DisplayCtrl 90010;

_eastRecruitedCounter = (["currentCutDisplay"] call BIS_FNC_GUIget) DisplayCtrl 90101;
_eastRecruitedBar = (["currentCutDisplay"] call BIS_FNC_GUIget) DisplayCtrl 90102;
_eastCasualtyCounter = (["currentCutDisplay"] call BIS_FNC_GUIget) DisplayCtrl 90103;
_eastCasualtyBar = (["currentCutDisplay"] call BIS_FNC_GUIget) DisplayCtrl 90104;
_eastCreatedCounter = (["currentCutDisplay"] call BIS_FNC_GUIget) DisplayCtrl 90105;
_eastCreatedBar = (["currentCutDisplay"] call BIS_FNC_GUIget) DisplayCtrl 90106;
_eastLostCounter = (["currentCutDisplay"] call BIS_FNC_GUIget) DisplayCtrl 90107;
_eastLostBar = (["currentCutDisplay"] call BIS_FNC_GUIget) DisplayCtrl 90108;

if (_guerPanel) then {
	_guerRecruitedCounter = (["currentCutDisplay"] call BIS_FNC_GUIget) DisplayCtrl 90300;
	_guerRecruitedBar = (["currentCutDisplay"] call BIS_FNC_GUIget) DisplayCtrl 90301;
	_guerCasualtyCounter = (["currentCutDisplay"] call BIS_FNC_GUIget) DisplayCtrl 90302;
	_guerCasualtyBar = (["currentCutDisplay"] call BIS_FNC_GUIget) DisplayCtrl 90303;
	_guerCreatedCounter = (["currentCutDisplay"] call BIS_FNC_GUIget) DisplayCtrl 90304;
	_guerCreatedBar = (["currentCutDisplay"] call BIS_FNC_GUIget) DisplayCtrl 90305;
	_guerLostCounter = (["currentCutDisplay"] call BIS_FNC_GUIget) DisplayCtrl 90306;
	_guerLostBar = (["currentCutDisplay"] call BIS_FNC_GUIget) DisplayCtrl 90307;

	{
		_position = CtrlPosition (_x select 0);
		_position Set[0, _x select 1];
		_position Set[2, _x select 2];
		(_x select 0) CtrlSetPosition _position;
		(_x select 0) CtrlCommit 0;
	} forEach [
		[_eastRecruitedCounter,0.03,0.13],[_eastRecruitedBar,0.03,_width],[_eastCasualtyCounter,0.03,0.13],[_eastCasualtyBar,0.03,_width],[_eastCreatedCounter,0.03,0.13],[_eastCreatedBar,0.03,_width],[_eastLostCounter,0.03,0.13],[_eastLostBar,0.03,_width],
		[_guerRecruitedCounter,0.365,0.13],[_guerRecruitedBar,0.365,_width],[_guerCasualtyCounter,0.365,0.13],[_guerCasualtyBar,0.365,_width],[_guerCreatedCounter,0.365,0.13],[_guerCreatedBar,0.365,_width],[_guerLostCounter,0.365,0.13],[_guerLostBar,0.365,_width],
		[_westRecruitedCounter,0.70,0.13],[_westRecruitedBar,0.70,_width],[_westCasualtyCounter,0.70,0.13],[_westCasualtyBar,0.70,_width],[_westCreatedCounter,0.70,0.13],[_westCreatedBar,0.70,_width],[_westLostCounter,0.70,0.13],[_westLostBar,0.70,_width]
	];
};

_playerScore = score player;
_playerFunds = 0;
_playerIncome = 0;
if (!isNil "GetPlayerFunds" && {!isNil "clientTeam"}) then {_playerFunds = Call GetPlayerFunds};
if (!isNil "GetIncome") then {_playerIncome = (sideJoined) Call GetIncome};
_playerSummary CtrlSetText Format ["Your round  |  Score %1  |  Funds $%2  |  Income $%3/min", _playerScore, round _playerFunds, round _playerIncome];

_position = CtrlPosition _westRecruitedBar;
_recruited = _width * (_westUnitsCreated / 500);
if (_recruited > _width) then {_recruited = _width};
_position Set[2,0];
_westRecruitedBar CtrlSetPosition _position;
_westRecruitedBar CtrlCommit 0;
_position Set[2,_recruited];
_westRecruitedBar CtrlSetPosition _position;
_westRecruitedBar CtrlCommit 8;

_position = CtrlPosition _westCasualtyBar;
_casualties = _width * (_westCasualties / 500);
if (_casualties > _width) then {_casualties = _width};
_position Set[2,0];
_westCasualtyBar CtrlSetPosition _position;
_westCasualtyBar CtrlCommit 0;
_position Set[2,_casualties];
_westCasualtyBar CtrlSetPosition _position;
_westCasualtyBar CtrlCommit 8;

_position = CtrlPosition _westCreatedBar;
_created = _width * (_westVehiclesCreated / 150);
if (_created > _width) then {_created = _width};
_position Set[2,0];
_westCreatedBar CtrlSetPosition _position;
_westCreatedBar CtrlCommit 0;
_position Set[2,_created];
_westCreatedBar CtrlSetPosition _position;
_westCreatedBar CtrlCommit 8;

_position = CtrlPosition _westLostBar;
_lost = _width * (_westVehiclesLost / 150);
if (_lost > _width) then {_lost = _width};
_position Set[2,0];
_westLostBar CtrlSetPosition _position;
_westLostBar CtrlCommit 0;
_position Set[2,_lost];
_westLostBar CtrlSetPosition _position;
_westLostBar CtrlCommit 8;

_position = CtrlPosition _eastRecruitedBar;
_recruited = _width * (_eastUnitsCreated / 500);
if (_recruited > _width) then {_recruited = _width};
_position Set[2,0];
_eastRecruitedBar CtrlSetPosition _position;
_eastRecruitedBar CtrlCommit 0;
_position Set[2,_recruited];
_eastRecruitedBar CtrlSetPosition _position;
_eastRecruitedBar CtrlCommit 8;

_position = CtrlPosition _eastCasualtyBar;
_casualties = _width * (_eastCasualties / 500);
if (_casualties > _width) then {_casualties = _width};
_position Set[2,0];
_eastCasualtyBar CtrlSetPosition _position;
_eastCasualtyBar CtrlCommit 0;
_position Set[2,_casualties];
_eastCasualtyBar CtrlSetPosition _position;
_eastCasualtyBar CtrlCommit 8;

_position = CtrlPosition _eastCreatedBar;
_created = _width * (_eastVehiclesCreated / 150);
if (_created > _width) then {_created = _width};
_position Set[2,0];
_eastCreatedBar CtrlSetPosition _position;
_eastCreatedBar CtrlCommit 0;
_position Set[2,_created];
_eastCreatedBar CtrlSetPosition _position;
_eastCreatedBar CtrlCommit 8;

_position = CtrlPosition _eastLostBar;
_lost = _width * (_eastVehiclesLost / 150);
if (_lost > _width) then {_lost = _width};
_position Set[2,0];
_eastLostBar CtrlSetPosition _position;
_eastLostBar CtrlCommit 0;
_position Set[2,_lost];
_eastLostBar CtrlSetPosition _position;
_eastLostBar CtrlCommit 8;

if (_guerPanel) then {
	_position = CtrlPosition _guerRecruitedBar;
	_recruited = _width * (_guerUnitsCreated / 500);
	if (_recruited > _width) then {_recruited = _width};
	_position Set[2,0];
	_guerRecruitedBar CtrlSetPosition _position;
	_guerRecruitedBar CtrlCommit 0;
	_position Set[2,_recruited];
	_guerRecruitedBar CtrlSetPosition _position;
	_guerRecruitedBar CtrlCommit 8;

	_position = CtrlPosition _guerCasualtyBar;
	_casualties = _width * (_guerCasualties / 500);
	if (_casualties > _width) then {_casualties = _width};
	_position Set[2,0];
	_guerCasualtyBar CtrlSetPosition _position;
	_guerCasualtyBar CtrlCommit 0;
	_position Set[2,_casualties];
	_guerCasualtyBar CtrlSetPosition _position;
	_guerCasualtyBar CtrlCommit 8;

	_position = CtrlPosition _guerCreatedBar;
	_created = _width * (_guerVehiclesCreated / 150);
	if (_created > _width) then {_created = _width};
	_position Set[2,0];
	_guerCreatedBar CtrlSetPosition _position;
	_guerCreatedBar CtrlCommit 0;
	_position Set[2,_created];
	_guerCreatedBar CtrlSetPosition _position;
	_guerCreatedBar CtrlCommit 8;

	_position = CtrlPosition _guerLostBar;
	_lost = _width * (_guerVehiclesLost / 150);
	if (_lost > _width) then {_lost = _width};
	_position Set[2,0];
	_guerLostBar CtrlSetPosition _position;
	_guerLostBar CtrlCommit 0;
	_position Set[2,_lost];
	_guerLostBar CtrlSetPosition _position;
	_guerLostBar CtrlCommit 8;
};

_timePassed = 0;
_eastCasualtyCount = 0;
_eastRecruitedCount = 0;
_eastCreatedCount = 0;
_eastLostCount = 0;

_westCasualtyCount = 0;
_westRecruitedCount = 0;
_westCreatedCount = 0;
_westLostCount = 0;

if (_guerPanel) then {
	_guerCasualtyCount = 0;
	_guerRecruitedCount = 0;
	_guerCreatedCount = 0;
	_guerLostCount = 0;
};

while {_timePassed < 8} do {
	sleep 0.1;

	_eastRecruitedCount = _eastRecruitedCount + _eastRecruitedRate;
	if (_eastRecruitedCount > _eastUnitsCreated) then {_eastRecruitedCount = _eastUnitsCreated};
	_eastRecruitedCounter CtrlSetText Format["%1",_eastRecruitedCount - (_eastRecruitedCount % 1)];

	_eastCasualtyCount = _eastCasualtyCount + _eastCasualtiesRate;
	if (_eastCasualtyCount > _eastCasualties) then {_eastCasualtyCount = _eastCasualties};
	_eastCasualtyCounter CtrlSetText Format["%1",_eastCasualtyCount - (_eastCasualtyCount % 1)];

	_eastCreatedCount = _eastCreatedCount + _eastCreatedRate;
	if (_eastCreatedCount > _eastVehiclesCreated) then {_eastCreatedCount = _eastVehiclesCreated};
	_eastCreatedCounter CtrlSetText Format["%1",_eastCreatedCount - (_eastCreatedCount % 1)];

	_eastLostCount = _eastLostCount + _eastLostRate;
	if (_eastLostCount > _eastVehiclesLost) then {_eastLostCount = _eastVehiclesLost};
	_eastLostCounter CtrlSetText Format["%1",_eastLostCount - (_eastLostCount % 1)];

	if (_guerPanel) then {
		_guerRecruitedCount = _guerRecruitedCount + _guerRecruitedRate;
		if (_guerRecruitedCount > _guerUnitsCreated) then {_guerRecruitedCount = _guerUnitsCreated};
		_guerRecruitedCounter CtrlSetText Format["%1",_guerRecruitedCount - (_guerRecruitedCount % 1)];

		_guerCasualtyCount = _guerCasualtyCount + _guerCasualtiesRate;
		if (_guerCasualtyCount > _guerCasualties) then {_guerCasualtyCount = _guerCasualties};
		_guerCasualtyCounter CtrlSetText Format["%1",_guerCasualtyCount - (_guerCasualtyCount % 1)];

		_guerCreatedCount = _guerCreatedCount + _guerCreatedRate;
		if (_guerCreatedCount > _guerVehiclesCreated) then {_guerCreatedCount = _guerVehiclesCreated};
		_guerCreatedCounter CtrlSetText Format["%1",_guerCreatedCount - (_guerCreatedCount % 1)];

		_guerLostCount = _guerLostCount + _guerLostRate;
		if (_guerLostCount > _guerVehiclesLost) then {_guerLostCount = _guerVehiclesLost};
		_guerLostCounter CtrlSetText Format["%1",_guerLostCount - (_guerLostCount % 1)];
	};

	_westRecruitedCount = _westRecruitedCount + _westRecruitedRate;
	if (_westRecruitedCount > _westUnitsCreated) then {_westRecruitedCount = _westUnitsCreated};
	_westRecruitedCounter CtrlSetText Format["%1",_westRecruitedCount - (_westRecruitedCount % 1)];

	_westCasualtyCount = _westCasualtyCount + _westCasualtiesRate;
	if (_westCasualtyCount > _westCasualties) then {_westCasualtyCount = _westCasualties};
	_westCasualtyCounter CtrlSetText Format["%1",_westCasualtyCount - (_westCasualtyCount % 1)];

	_westCreatedCount = _westCreatedCount + _westCreatedRate;
	if (_westCreatedCount > _westVehiclesCreated) then {_westCreatedCount = _westVehiclesCreated};
	_westCreatedCounter CtrlSetText Format["%1",_westCreatedCount - (_westCreatedCount % 1)];

	_westLostCount = _westLostCount + _westLostRate;
	if (_westLostCount > _westVehiclesLost) then {_westLostCount = _westVehiclesLost};
	_westLostCounter CtrlSetText Format["%1",_westLostCount - (_westLostCount % 1)];

	_timePassed = _timePassed + 0.1;
};
