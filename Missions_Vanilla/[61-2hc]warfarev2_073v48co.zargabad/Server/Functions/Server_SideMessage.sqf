Private ["_logik","_message","_parameters","_receiver","_side","_speaker","_topicside","_rlName","_dub","_localizedString","_value","_cfgWords","_townObj","_nearLabel","_struct","_town"];

//--- r73b: radio SideMessage fail-clean — null receiver/topic and nil town dubbing used to throw mid-kbTell and silence the HQ radio channel for that side.
if (isNil "_this" || {typeName _this != "ARRAY"} || {count _this < 2}) exitWith {};

_side = _this select 0;
_message = _this select 1;
_parameters = if (count _this > 2) then {_this select 2} else {[]};

if (isNil "_side" || {isNil "_message"}) exitWith {};
if (typeName _message != "STRING" || {_message == ""}) exitWith {};

_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNull _logik) exitWith {};

_speaker = _logik getVariable ["wfbe_radio_hq", objNull];
if (isNull _speaker) exitWith {}; //--- base-less GUER has no radio HQ -> skip the radio side-message (no-command-center guard, 2026-06-17)
//--- r73b: receiver was a bare getVariable (nil when unset) and topic id was unchecked — kbTell with nil/empty aborts the script.
_receiver = _logik getVariable ["wfbe_radio_hq_rec", objNull];
if (isNull _receiver) exitWith {};
_topicSide = _logik getVariable ["wfbe_radio_hq_id", ""];
if (isNil "_topicSide" || {typeName _topicSide != "STRING"} || {_topicSide == ""}) exitWith {};

switch (true) do {
	case (_message in ["Lost","Captured","HostilesDetectedNear"]): {
		if (isNil "_parameters" || {typeName _parameters != "OBJECT"} || {isNull _parameters}) exitWith {};
		_rlName = _parameters getVariable ["name", ""];
		if (isNil "_rlName" || {typeName _rlName != "STRING"}) then {_rlName = ""};
		//--- Bare getVariable "wfbe_town_dubbing" returned nil; `nil != "Town"` threw (Type Any, expected String).
		_dub = _parameters getVariable ["wfbe_town_dubbing", "Town"];
		if (isNil "_dub" || {typeName _dub != "STRING"} || {_dub == ""}) then {_dub = "Town"};
		if (_dub != "Town") then {
			_cfgWords = missionNamespace getVariable Format ["WFBE_%1_RadioAnnouncers_Config", _side];
			if (!isNil "_cfgWords" && {typeName _cfgWords == "STRING"} && {_cfgWords != ""}) then {
				if (count (getArray (configFile >> _cfgWords >> "Words" >> _dub)) == 0) then {_dub = "Town"};
			};
		};
		_speaker kbTell [_receiver, _topicSide, _message,["1","",_rlName,[_dub]],true];
	};
	case (_message in ["CapturedNear","LostAt"]): {
		if (isNil "_parameters" || {typeName _parameters != "ARRAY"} || {count _parameters < 2}) exitWith {};
		_nearLabel = _parameters select 0;
		_townObj = _parameters select 1;
		if (isNil "_townObj" || {typeName _townObj != "OBJECT"} || {isNull _townObj}) exitWith {};
		if (isNil "_nearLabel") then {_nearLabel = ""};
		if (typeName _nearLabel != "STRING") then {_nearLabel = str _nearLabel};
		_rlName = _townObj getVariable ["name", ""];
		if (isNil "_rlName" || {typeName _rlName != "STRING"}) then {_rlName = ""};
		_dub = _townObj getVariable ["wfbe_town_dubbing", "Town"];
		if (isNil "_dub" || {typeName _dub != "STRING"} || {_dub == ""}) then {_dub = "Town"};
		if (_dub != "Town") then {
			_cfgWords = missionNamespace getVariable Format ["WFBE_%1_RadioAnnouncers_Config", _side];
			if (!isNil "_cfgWords" && {typeName _cfgWords == "STRING"} && {_cfgWords != ""}) then {
				if (count (getArray (configFile >> _cfgWords >> "Words" >> _dub)) == 0) then {_dub = "Town"};
			};
		};
		_speaker kbTell [_receiver, _topicSide, _message,["1","",_nearLabel,[_nearLabel]],["2","",_rlName,[_dub]],true];
	};
	case (_message in ["Constructed","Destroyed","Deployed","Mobilized","IsUnderAttack"]): {
		if (isNil "_parameters" || {typeName _parameters != "ARRAY"} || {count _parameters < 2}) exitWith {};
		_localizedString = "";
		_value = "";
		if ((_parameters select 0) == "Base") then {
			_struct = _parameters select 1;
			if (isNil "_struct" || {typeName _struct != "OBJECT"} || {isNull _struct}) exitWith {};
			switch (_struct getVariable ["wfbe_structure_type", ""]) do {
				case "Headquarters": {_localizedString = localize "STRHeadquarters";_value = "Headquarters"};
				case "Barracks": {_localizedString = localize "strwfbarracks";_value = "Barracks"};
				case "Light": {_localizedString = localize "STRLightVehicleSupply";_value = "LightVehicleSupply"};
				case "CommandCenter": {
					_localizedString = localize "STR_WF_CommandCenter";
					_value = "UAVTerminal";
					if (WF_A2_Arrowhead || (WF_A2_CombinedOps && _side == west)) then {_value = "CommandPost"};
				};
				case "Heavy": {_localizedString = localize "STRHeavyVehicleSupply";_value = "HeavyVehicleSupply"};
				case "Aircraft": {_localizedString = localize "STRHelipad";_value = "Helipad"};
				case "ServicePoint": {_localizedString = localize "STRServicePoint";_value = "ServicePoint"};
				case "AARadar": {_localizedString = localize "STRAntiAirRadar";_value = "AntiAirRadar"};
				//--- STRINGTABLE-R30: Bank/CBRadar/ArtilleryRadar/Reserve were live structure types but never localized here,
				//--- so Constructed/Destroyed/IsUnderAttack radio kbTell used empty name/value for those sites.
				case "CBRadar": {_localizedString = localize "STR_WF_UPGRADE_CBRadar";_value = "AntiAirRadar"};
				case "ArtilleryRadar": {_localizedString = localize "RB_Artillery_Radar";_value = "AntiAirRadar"};
				case "Bank": {_localizedString = localize "STR_WF_STRUCTURE_Bank";_value = "Headquarters"};
				case "Reserve": {_localizedString = localize "RB_Reserve";_value = "Barracks"};
			};
		} else {
			_town = _parameters select 1;
			if (isNil "_town" || {typeName _town != "OBJECT"} || {isNull _town}) exitWith {};
			_localizedString = _town getVariable ["name", ""];
			if (isNil "_localizedString" || {typeName _localizedString != "STRING"}) then {_localizedString = ""};
			_dub = _town getVariable ["wfbe_town_dubbing", "Town"];
			if (isNil "_dub" || {typeName _dub != "STRING"} || {_dub == ""}) then {_dub = "Town"};
			if (_dub != "Town") then {
				_cfgWords = missionNamespace getVariable Format ["WFBE_%1_RadioAnnouncers_Config", _side];
				if (!isNil "_cfgWords" && {typeName _cfgWords == "STRING"} && {_cfgWords != ""}) then {
					if (count (getArray (configFile >> _cfgWords >> "Words" >> _dub)) == 0) then {_dub = "Town"};
				};
			};
			_value = _dub;
		};
		_speaker kbTell [_receiver, _topicSide, _message,["1","",_localizedString,[_value]],true];
	};
	case (_message in ["VotingForNewCommander","NewIntelAvailable","MMissionFailed","NewMissionAvailable"]): {
		_speaker kbTell [_receiver, _topicSide, _message, true]
	};
	case (_message in ["MMissionComplete","ExtractionTeam","ExtractionTeamCancel"]): {
		if (isNil "_parameters" || {typeName _parameters != "ARRAY"} || {count _parameters < 2}) exitWith {};
		_speaker kbTell [_receiver, _topicSide, _message,["1","",_parameters select 0,[_parameters select 1]],true];
	};
};
