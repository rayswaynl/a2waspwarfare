/* 
	Original Author: Marty
	Name: Common_SendMessage.sqf
	Parameters:
	0 - _messageText				: string OR array - For a plain message this is the literal text for systemChat. For a multi-language message (param 3 true) this is structured data [stringtableKey (string), formatArgs (array)] which each receiver localizes itself. SECURITY: never an SQF code string (see below).
	1 - _messageSoundName			: string 		- Name sound from CfgSounds defined in description.ext.
	2 - _side_who_receive_message	: side object 	- can be east or west.
	3 - _is_multi_language_message	: boolean 		- In case of a multi language message, this parameter is set to true and the message text must be the structured [key, args] array (NOT compiled SQF). SECURITY: SEND_MESSAGE arrives via a forge-able publicVariable; we MUST NOT compile/execute its payload, so the message is resolved with localize+format on each client instead of "call compile".
	
	Description: This function is meant to broadcast an audio and text message to all clients, by triggering the SEND_MESSAGE EH on every client.
	This message will be only visible and heard for a specific side (west or east).
	IMPORTANT NOTE : You need to restart arma2ao when you add a new class in the stringrable file. Same with audio in the description.ext. This is not related to this function but its a bohemian limitation.
	    
*/

// Extract the value from the array to get specific infos for the marker creation :
_messageText				= _this select 0;
_messageSoundName			= _this select 1;
_side_who_receive_message	= _this select 2;
_is_multi_language_message	= _this select 3;

if (playerSide == _side_who_receive_message) then
{
	private "_displayText";
	_displayText = _messageText;
	if _is_multi_language_message then
	{
		// SECURITY (RCE fix): the old code ran "call compile _messageText" so each client could
		// localize the message in its own language. But _messageText originates from the forge-able
		// SEND_MESSAGE publicVariable, so compiling it = arbitrary SQF on every receiver. Instead the
		// multi-language payload is now structured data [stringtableKey, formatArgs]; we resolve it with
		// localize + format (pure data, never executed). Guard the shape so a malformed/forged payload
		// just shows nothing instead of erroring.
		if (typeName _messageText == "ARRAY") then
		{
			private ["_key","_args","_fmt"];
			_key  = _messageText select 0;
			_args = _messageText select 1;
			if (typeName _args != "ARRAY") then {_args = []};
			_fmt = [localize _key];
			_fmt = _fmt + _args;
			_displayText = format _fmt;
		}
		else
		{
			_displayText = "";
		};
	};

	systemChat _displayText;
	//playSound _messageSoundName;
	if (_messageSoundName != "") then {playSound [_messageSoundName, true]}; //--- empty-name guard (livetest 2026-07-06): notable-kill feed passes "" for "text, no sound"; playSound ["",true] pops a "Sound not found" dialog. Empty = silent, not an error.
};

// Broadcasting the publicVariable SEND_MESSAGE in order to trigger the EH running on every client.
_SEND_MESSAGE_infos =  _this ; 	// get the array containing all the parameters values given during the call of this function.

missionNamespace setVariable ["SEND_MESSAGE", _SEND_MESSAGE_infos];
publicVariable "SEND_MESSAGE"; // will trigger the SEND_MESSAGE addPublicVariableEventHandler 
