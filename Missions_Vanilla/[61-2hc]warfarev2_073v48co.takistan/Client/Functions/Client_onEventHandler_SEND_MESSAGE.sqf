/* 
	Original Author: Marty
	Name: Client_onEventHandler_SEND_MESSAGE.sqf
	Parameters:
	Parameters are given by the EH "SEND_MESSAGE" addPublicVariableEventHandler
	0 - string - correspond to the name of the public variable braodcasted, here it is "SEND_MESSAGE"
	1 - _SEND_MESSAGE_infos : array containing all the value given by the addPublicVariableEventHandler, here it the infos about the message to be send.

	Description: This function is meant to create a message only visible and heard for a specific side (west or east).
	    
*/

//[_messageText, _messageSoundName, _side_who_receive_message ] call WF_sendMessage ;

_SEND_MESSAGE_infos = _this select 1; // select 1 not 0 to get the value !

// Extract the value from the array to get specific infos for the message creation :
_messageText				= _SEND_MESSAGE_infos select 0;
_messageSoundName			= _SEND_MESSAGE_infos select 1;
_side_who_receive_message	= _SEND_MESSAGE_infos select 2;
_is_multi_language_message	= _SEND_MESSAGE_infos select 3;

if (playerSide == _side_who_receive_message) then
{
	private "_displayText";
	_displayText = _messageText;
	if _is_multi_language_message then
	{
		// SECURITY (RCE fix): this handler fires on EVERY client whenever the SEND_MESSAGE
		// publicVariable arrives, and that variable is forge-able by any connected client. The old
		// "call compile _messageText" therefore allowed arbitrary remote code execution. The multi-language
		// payload is now structured data [stringtableKey, formatArgs] which we resolve with localize + format
		// (pure data, never executed). A malformed/forged payload simply renders nothing.
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

	// Send a text and audio message to all clients who are supposed to receive it.
	systemChat _displayText;
	//playSound _messageSoundName;
	if (_messageSoundName != "") then {playSound [_messageSoundName, true]}; //--- empty-name guard (livetest 2026-07-06): notable-kill feed passes "" for "text, no sound"; playSound ["",true] pops a "Sound not found" dialog. Empty = silent, not an error.
	//player say3D _messageSoundName;
};


