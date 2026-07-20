//--- Client_ChatRelayTap.sqf
//--- One-way game->Discord chat bridge, client tap half (owner decision 2026-07-20,
//--- fleet task wasp-discord-chat-bridge-20260720: no BattlEye, no RCon, no DLLs).
//--- Watches the engine chat display (IDD 24, edit IDC 101 - engine-probed on an offline
//--- OA 1.64.144629 rig, probe evidence in the PR body): when the player submits a chat line
//--- (Enter), the typed text is relayed to the server via publicVariableServer
//--- "WFBE_CHATRELAY" as [uid, name, side, text]. The server half (Init_Server.sqf PVEH)
//--- diag_logs CHATRELAY|v1| lines for the Hetzner box RPT-tail producer -> Discord.
//---
//--- The KeyDown EH always returns false, so the engine's normal chat flow is untouched
//--- (the message is sent exactly as without the tap). Escaped/aborted chat relays nothing.
//--- Gated by WFBE_C_CHATRELAY (default 0): Init_Client.sqf only spawns this loop when
//--- armed, so flag-off is runtime byte-identical to HEAD. Players only: Init_Client never
//--- runs on the dedicated server or headless clients (initJIPCompatible.sqf gate).
if (!hasInterface) exitWith {};
if ((missionNamespace getVariable ["WFBE_C_CHATRELAY", 0]) == 0) exitWith {};

private ["_lastText", "_lastTime", "_keyHandler"];

_lastText = "";
_lastTime = -10;

_keyHandler = {
	private ["_dik", "_text"];
	_dik = _this select 1;
	//--- DIK_RETURN (28) / DIK_NUMPADENTER (156): the engine consumes the line right after
	//--- this EH (we return false), so ctrlText still holds the submitted text here.
	if (_dik == 28 || _dik == 156) then {
		_text = ctrlText ((findDisplay 24) displayCtrl 101);
		if (_text != "") then {
			//--- 2s same-text dedupe: a double-Enter bounce must not double-post to Discord.
			if (!(_text == _lastText && (time - _lastTime) < 2)) then {
				_lastText = _text;
				_lastTime = time;
				WFBE_CHATRELAY = [getPlayerUID player, name player, str playerSide, _text];
				publicVariableServer "WFBE_CHATRELAY";
			};
		};
	};
	false
};

//--- Re-attach on every chat-display open; the engine creates a fresh display each time.
while {!(missionNamespace getVariable ["WFBE_GameOver", false])} do {
	waitUntil {!isNull (findDisplay 24)};
	(findDisplay 24) displayAddEventHandler ["KeyDown", _keyHandler];
	waitUntil {isNull (findDisplay 24)};
};
