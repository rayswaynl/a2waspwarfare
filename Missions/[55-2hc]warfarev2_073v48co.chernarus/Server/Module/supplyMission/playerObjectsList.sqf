"WFBE_C_PLAYER_OBJECT" addPublicVariableEventHandler {
	(_this select 1) spawn {
		private ["_playerObject","_currentPlayerUID","_i","_arrayPosMatch","_iteratedPlayerUID","_matchFound"];

		_playerObject = _this select 0;
		//--- SECURITY (harden-supplymission Finding 3): identity is derived from the object itself, never
		//--- the client-claimed UID (_this select 1). A forged [attackerObj, victimUID] pair used to poison
		//--- this table with a false object<->UID binding, which supplyMissionStarted.sqf's delivery
		//--- attribution scan trusts. getPlayerUID on ANY object reliably returns its real owning player's
		//--- UID server-side regardless of what the sender claimed - the only legitimate caller
		//--- (Client/Init/Init_Client.sqf: "WFBE_C_PLAYER_OBJECT = [player, getPlayerUID player];") already
		//--- sends this exact value, so re-deriving it here is provably a no-op for every honest client and
		//--- ships unflagged (no WFBE_C_SEC_HARDENING gate needed).
		_currentPlayerUID = getPlayerUID _playerObject;

		_matchFound = false;
		_arrayPosMatch = 0;

		if (isNil "WFBE_SE_PLAYERLIST") then {
			WFBE_SE_PLAYERLIST = [[objNull, "0"]];
		};

		// diag_log format ["WFBE_SE_PLAYERLIST: %1", WFBE_SE_PLAYERLIST];

		_i = 0; //--- wiki-wins: was reset INSIDE the forEach, so _arrayPosMatch was always 0 (every UID match overwrote slot 0)
		{
			_iteratedPlayerUID = _x select 1;

			// diag_log format ["_iteratedPlayerUID: %1, _currentPlayerUID: %2", _iteratedPlayerUID, _currentPlayerUID];

			if (_iteratedPlayerUID == _currentPlayerUID) then {
				_matchFound = true;
				_arrayPosMatch = _i; 
			};

			_i = _i + 1;
		} forEach WFBE_SE_PLAYERLIST;

		if (_matchFound && !(isNull _playerObject)) then {
			WFBE_SE_PLAYERLIST set [_arrayPosMatch, [_playerObject, _currentPlayerUID]];
		} else {
			WFBE_SE_PLAYERLIST set [count WFBE_SE_PLAYERLIST, [_playerObject, _currentPlayerUID]];
		};

		// diag_log format ["WFBE_SE_PLAYERLIST after iterating: %1", WFBE_SE_PLAYERLIST];
		
	};
};