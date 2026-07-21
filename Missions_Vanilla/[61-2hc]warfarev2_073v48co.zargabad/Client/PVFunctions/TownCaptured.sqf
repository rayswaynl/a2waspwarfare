/*
	Triggered everytime a capture is done (town captured or lost).
	 Parameters:
		- Town
		- Old side ID.
		- New side ID.
*/

Private ["_captureText","_color","_musicCooldown","_musicLast","_musicNow","_musicTrack","_town","_townMarker","_town_side_value","_town_side_value_new","_sv"];

_town = _this select 0;
_town_side_value = _this select 1;
_town_side_value_new = _this select 2;
_sv = _town getVariable "supplyValue";
if (isNil "WFBE_Client_SideID") exitWith {};
_side_captured = (_town_side_value_new) Call WFBE_CO_FNC_GetSideFromID;

//--- Color the town depending on the side which captured. This is client-local and must not be
//--- hidden behind the information/fog-of-war gate, otherwise the Depot marker lies forever.
_color = missionNamespace getVariable (Format ["WFBE_C_%1_COLOR", _side_captured]);
_townMarker = Format ["WFBE_%1_CityMarker", _town];
_townMarker setMarkerColorLocal _color;

//--- Make sure that the client is concerned by the capture either by capturing or having a town captured.
//--- Optional title/chat broadcast is separate from the always-correct marker update.
if (!(WFBE_Client_SideID in [_town_side_value,_town_side_value_new,WFBE_C_GUER_ID]) && {!((missionNamespace getVariable ["WFBE_C_TOWN_FLIP_BROADCAST", 0]) > 0)}) exitWith {};

//--- Display a title message.
_side_label = switch (_side_captured) do {case west: {localize "STR_WF_PARAMETER_Side_West"}; case east: {localize "STR_WF_PARAMETER_Side_East"}; case resistance: {localize "STR_WF_Side_Resistance"};	default {"Civilian"}};
_captureText = Format[Localize "STR_WF_CHAT_Town_Captured", _town getVariable "name", _side_label];
[_captureText] Call TitleTextMessage;
//--- Chat fallback for players who hide or miss the title text channel.
_captureText Call CommandChatMessage;

//--- Lane 51: optional town-capture music. Client-local and cooldowned so mass flips do not restart the track every town.
if ((missionNamespace getVariable ["WFBE_C_MUSIC_ENABLE", 0]) > 0) then {
	_musicTrack = missionNamespace getVariable ["WFBE_C_MUSIC_TOWN_CAPTURE_TRACK", ""];
	if ((count (toArray _musicTrack)) > 0) then {
		_musicNow = time;
		_musicLast = missionNamespace getVariable ["WFBE_Client_LastCaptureMusic", -9999];
		_musicCooldown = missionNamespace getVariable ["WFBE_C_MUSIC_TOWN_CAPTURE_COOLDOWN", 180];
		if (_musicCooldown < 0) then {_musicCooldown = 0};
		if ((_musicNow - _musicLast) >= _musicCooldown) then {
			missionNamespace setVariable ["WFBE_Client_LastCaptureMusic", _musicNow];
			playMusic _musicTrack;
		};
	};
};

//--- Task.
_task = _town getVariable 'taskLink';
_ptask = currentTask player;
if (isNil '_task') then {_task = objNull};

//--- Taskman
// ["TownUpdate", _town] Spawn TaskSystem;

//--- Client side capture.
if (_town_side_value_new == WFBE_Client_SideID) then {
	//--- Retrieve the closest unit of the town.
	_closest = [_town, (units group player) Call WFBE_CO_FNC_GetLiveUnits] Call WFBE_CO_FNC_GetClosestEntity;
	
	//--- Client reward.
	if !(isNull _closest) then {
		//--- Check if the closest unit of the town in in range.
		_distance = _closest distance _town;
		
		_bonus = -1;
		_score = -1;
		if (_distance <= (missionNamespace getVariable "WFBE_C_TOWNS_CAPTURE_RANGE")) then {
			//--- Capture
			_bonus= 150*_sv;
			_score = missionNamespace getVariable "WFBE_C_PLAYERS_SCORE_CAPTURE";
		} else {
			//--- Is it an assist?.
			if (_distance <= (missionNamespace getVariable "WFBE_C_TOWNS_CAPTURE_ASSIST")) then {
				//--- Assist.
				_bonus= 150*_sv;
				_score = missionNamespace getVariable "WFBE_C_PLAYERS_SCORE_CAPTURE_ASSIST";
			};
		};
		
		//--- Update the funds if necessary.
		if (_bonus != -1) then {
			(_bonus) Call WFBE_CL_FNC_ChangeClientFunds;
			Format[Localize "STR_WF_CHAT_Town_Bounty_Full", _town getVariable "name", _bonus] Call CommandChatMessage;
		};
		
		//--- Update the score necessary.
		if (_score != -1) then {["RequestChangeScore", [player,score player + _score]] Call WFBE_CO_FNC_SendToServer};
	};
	
	//--- Commander reward (if the player is the commander)
	if !(isNull commanderTeam) then {
		if (commanderTeam == group player) then {
			_bonus = (_town getVariable "startingSupplyValue") * (missionNamespace getVariable "WFBE_C_PLAYERS_COMMANDER_BOUNTY_CAPTURE_COEF");
			(_bonus) Call WFBE_CL_FNC_ChangeClientFunds;
			["RequestChangeScore", [player,score player + (missionNamespace getVariable "WFBE_C_PLAYERS_COMMANDER_SCORE_CAPTURE")]] Call WFBE_CO_FNC_SendToServer;
			Format[Localize "STR_WF_CHAT_Commander_Bounty_Town", _bonus, _town getVariable "name"] Call CommandChatMessage;
		};
	};
	
	//--- Taskman
	if !(isNull _task) then {
		if (_ptask == _task) then {
			// ["TownAssignClosest"] Spawn TaskSystem;
		};
	};
};
