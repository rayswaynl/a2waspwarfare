"CLIENT_INIT_READY" addPublicVariableEventHandler {
    private ["_player"];

    _player = _this select 1;

    //--- Set attack mode status properly.
    if (side (_player) == west && ATTACK_WAVE_ACTIVE_WEST) then {
        [(_player), "HandleSpecial", ["attack-wave", ATTACK_WAVE_WEST_PRICE_MODIFIER]] Call WFBE_CO_FNC_SendToClient;
        [(_player), "LocalizeMessage", ["AttackModeActiveJIP"]] call WFBE_CO_FNC_SendToClient;
    } else {
        if (side (_player) == east && ATTACK_WAVE_ACTIVE_EAST) then {
            [(_player), "HandleSpecial", ["attack-wave", ATTACK_WAVE_EAST_PRICE_MODIFIER]] Call WFBE_CO_FNC_SendToClient;
            [(_player), "LocalizeMessage", ["AttackModeActiveJIP"]] call WFBE_CO_FNC_SendToClient;
        };
    };

    //--- FOB-JIP replay (moved from Server_OnPlayerConnected.sqf, sqf-fn-binding r122): replay ACTIVE GUER
    //--- FOB markers to a GUER joiner (#846 known gap). Fired from CLIENT_INIT_READY - published by the
    //--- client at the END of Init_Client, after commonInitComplete (WFBE_PVF_* PVEHs installed) and the
    //--- WFBE_CL_FNC_HandlePVF compile - so the joiner can actually consume the push; the old connect-time
    //--- fire raced that init and was silently dropped. Targeted publicVariableClient (only the joiner
    //--- re-receives, no side-wide re-create), ledger copied (+) against concurrent clears, client handler
    //--- idempotent (delete-then-create), sleep keeps successive writes to the same PV name from coalescing.
    //--- NOTE: the var-write + publicVariableClient pair is not atomic across overlapping joiner threads,
    //--- but every GUER replay iterates the same ledger, so a crossover still delivers a valid FOB payload
    //--- (same worst case as the original connect-time design).
    if ((side _player) == resistance) then {
        [_player] Spawn {
            private ["_fobOwner","_fobPlayer","_fobReplay"];
            _fobPlayer = _this select 0;
            _fobReplay = + (missionNamespace getVariable ["WFBE_GUER_FOB_ACTIVE", []]);
            if ((count _fobReplay) > 0) then {
                _fobOwner = owner _fobPlayer;
                if (_fobOwner > 0) then {
                    diag_log Format ["[WFBE][FOB-JIP] replaying %1 active FOB marker(s) to ready joiner %2", count _fobReplay, name _fobPlayer];
                    {
                        WFBE_PVF_WildcardMarker = [resistance, "CLTFNCWildcardMarker", ["create", _x select 0, _x select 1, "ColorGreen", "mil_objective", Format ["FOB %1", _x select 2], "forward base active - spawn and resupply here"]];
                        _fobOwner publicVariableClient "WFBE_PVF_WildcardMarker";
                        sleep 0.5;
                    } forEach _fobReplay;
                };
            };
        };
    };

    //--- DESIGN-4 (Star Fortress ally-only marker JIP replay): same CLIENT_INIT_READY timing and
    //--- targeted publicVariableClient idiom as the FOB-JIP replay above, but reads the Star Fortress
    //--- registry/keepalive vars directly instead of a ledger array - RequestStarFort.sqf GATE 0 keeps
    //--- this WEST/EAST-only and GATE 2 allows at most one live fort per side, so there is nothing to
    //--- iterate. No-op when the flag is off or when no fort of the joiner's side is currently alive.
    if (((side _player) in [west, east]) && {(missionNamespace getVariable ["WFBE_C_STARFORT_ALLYMARKER", 0]) > 0}) then {
        [_player] Spawn {
            private ["_sfPlayer","_sfSide","_sfAliveKey","_sfRegKey","_sfKeep","_sfOwner","_sfMarkerName","_sfColor"];
            _sfPlayer = _this select 0;
            _sfSide = side _sfPlayer;
            _sfAliveKey = if (_sfSide == west) then {"wfbe_starfort_keepalive_west"} else {"wfbe_starfort_keepalive_east"};
            _sfRegKey = if (_sfSide == west) then {"WFBE_STARFORT_WEST"} else {"WFBE_STARFORT_EAST"};
            _sfKeep = missionNamespace getVariable [_sfRegKey, objNull];
            if ((missionNamespace getVariable [_sfAliveKey, false]) && {!isNull _sfKeep} && {alive _sfKeep}) then {
                _sfOwner = owner _sfPlayer;
                if (_sfOwner > 0) then {
                    _sfMarkerName = Format ["wfbe_starfort_%1", if (_sfSide == west) then {"west"} else {"east"}];
                    _sfColor = if (_sfSide == west) then {"ColorBlue"} else {"ColorRed"};
                    WFBE_PVF_WildcardMarker = [_sfSide, "CLTFNCWildcardMarker", ["create", _sfMarkerName, getPos _sfKeep, _sfColor, "mil_warning", "STAR FORTRESS", "forward hard-spawn - defend the keep"]];
                    _sfOwner publicVariableClient "WFBE_PVF_WildcardMarker";
                    diag_log Format ["[WFBE][STARFORT-JIP] replayed ally Star Fortress marker to ready joiner %1 (side %2).", name _sfPlayer, _sfSide];
                };
            };
        };
    };


    //--- ARTY/ICBM/RADZONE JIP marker-style replay (fix/marker-style-jip-replay, GR-2026-07-08a): WF_createMarker
    //--- (Common_CreateMarker.sqf) creates these markers GLOBALLY so a JIP client already sees the bare dot at the
    //--- right position, but type/text/color are only ever applied via the one-shot "MARKER_CREATION" publicVariable
    //--- (Client_onEventHandler_MARKER_CREATION.sqf, wired at Client/FSM/updateclient.sqf:14-16) - A2 OA never
    //--- replays an earlier publicVariable to a LATER joiner, so a joiner who connects after the marker was created
    //--- sees it untyped/untitled/uncoloured forever. WFBE_MARKER_STYLE_LEDGER (captured passively below for the
    //--- CLIENT-originated ARTY/ICBM families, and appended explicitly at RADZONE's own 2 call sites since that
    //--- script runs server-side and never reaches its own PVEH) holds every live marker's original creation
    //--- payload; replay it verbatim on the SAME "MARKER_CREATION" channel via a TARGETED publicVariableClient so
    //--- the existing, unmodified client receiver applies it exactly as it would a live create. TTL-sweep here
    //--- (1500s, above the 1200s max of both WFBE_ICBM_TIME_TO_IMPACT and WFBE_RADZONE_TIME, Rsc/Parameters.hpp)
    //--- is the only prune path for ICBM, whose sole delete is client-local/silent (GUI_Menu_Tactical.sqf's
    //--- WFBE_CL_FNC_Delete_Marker); ARTY and RADZONE prune the ledger explicitly at their own server-side deletes.
    private ["_styleLedger","_styleKept","_styleEntry","_styleAge","_styleOwner"];
    _styleLedger = missionNamespace getVariable ["WFBE_MARKER_STYLE_LEDGER", []];
    if ((count _styleLedger) > 0) then {
        _styleKept = [];
        {
            _styleEntry = _x;
            _styleAge = time - (_styleEntry select 2);
            if (_styleAge < 1500) then {_styleKept = _styleKept + [_styleEntry]};
        } forEach _styleLedger;
        missionNamespace setVariable ["WFBE_MARKER_STYLE_LEDGER", _styleKept];
        if ((count _styleKept) > 0) then {
            _styleOwner = owner _player;
            if (_styleOwner > 0) then {
                [_player, _styleOwner, _styleKept] Spawn {
                    private ["_stylePlayer","_styleOwnerId","_styleEntries","_styleRow"];
                    _stylePlayer = _this select 0;
                    _styleOwnerId = _this select 1;
                    _styleEntries = _this select 2;
                    diag_log Format ["[WFBE][MARKER-STYLE-JIP] replaying %1 marker style(s) to ready joiner %2", count _styleEntries, name _stylePlayer];
                    {
                        _styleRow = _x;
                        missionNamespace setVariable ["MARKER_CREATION", (_styleRow select 1)];
                        _styleOwnerId publicVariableClient "MARKER_CREATION";
                        sleep 0.5;
                    } forEach _styleEntries;
                };
            };
        };
    };
};


//--- ARTY/ICBM marker-style capture (fix/marker-style-jip-replay, GR-2026-07-08a): Common_CreateMarker.sqf
//--- (WF_createMarker) broadcasts "MARKER_CREATION" once so already-connected same-side clients can apply
//--- type/text/color locally (Client_onEventHandler_MARKER_CREATION.sqf) - A2 OA never replays that publicVariable
//--- to a LATER joiner. ARTY (Client_RequestFireMission.sqf) and ICBM (GUI_Menu_Tactical.sqf) both call
//--- WF_createMarker from a CLIENT machine, so their broadcast lands here passively (the server is never the
//--- originating machine, so its own PVEH still fires) - zero changes needed in either creator file. RADZONE
//--- (Client/Module/Nuke/radzone.sqf) runs SERVER-side so its own broadcast never reaches this handler
//--- (publicVariable does not fire the ORIGINATING machine's own PVEH) - it is appended explicitly at its own
//--- 2 call sites instead. INSERT-IF-ABSENT (never overwrite an existing row's timestamp): this keeps a
//--- same-name re-fire from growing a duplicate ledger row WITHOUT resetting that row's TTL clock - safest
//--- given it is not independently confirmed here whether this server's own replay publicVariableClient below
//--- loops back into this same handler on the sending machine; if it ever does, the row is simply left alone
//--- instead of having its TTL silently extended forever by a steady stream of joiners. Consumed + TTL-swept
//--- by the CLIENT_INIT_READY replay above.
"MARKER_CREATION" addPublicVariableEventHandler {
    private ["_capInfos","_capName","_capLedger","_capExists","_capRow"];
    _capInfos = _this select 1;
    if (typeName _capInfos == "ARRAY" && {count _capInfos >= 6}) then {
        _capName = _capInfos select 0;
        if (typeName _capName == "STRING" && {_capName != ""}) then {
            _capLedger = missionNamespace getVariable ["WFBE_MARKER_STYLE_LEDGER", []];
            _capExists = false;
            {
                _capRow = _x;
                if ((_capRow select 0) == _capName) then {_capExists = true};
            } forEach _capLedger;
            if (!_capExists) then {
                _capLedger = _capLedger + [[_capName, _capInfos, time]];
                missionNamespace setVariable ["WFBE_MARKER_STYLE_LEDGER", _capLedger];
            };
        };
    };
};


//--- Fix: extracted PVEH body into WFBE_SE_FNC_HandleAttackWaveDetails so Server_AttackWave.sqf
//--- can call it directly. publicVariableServer from the server never fires the server's own PVEH,
//--- so the handler was dead for both wave-start and wave-end. The PVEH below still calls this
//--- function so any future client->server ATTACK_WAVE_DETAILS publish also works.
//--- Calling convention: _this IS the payload array [side, priceModifier, attackLength].
//--- (Server_AttackWave.sqf calls directly; PVEH relay strips the varname with (_this select 1) Call.)
WFBE_SE_FNC_HandleAttackWaveDetails = {
	private ["_priceModifier", "_side", "_attackLength", "_attackLengthMinutes", "_priceModifierPercentage", "_requester"];

    if (typeName _this != "ARRAY") exitWith {
        ["WARNING", Format["AttackWave.sqf: rejected malformed ATTACK_WAVE_DETAILS payload type [%1].", typeName _this]] Call WFBE_CO_FNC_LogContent;
    };

    if (count _this < 3) exitWith {
        ["WARNING", Format["AttackWave.sqf: rejected short ATTACK_WAVE_DETAILS payload [%1] element(s).", count _this]] Call WFBE_CO_FNC_LogContent;
    };

	_side = _this select 0;
	_priceModifier = _this select 1;
    _attackLength = _this select 2;
    //--- fix(harden) [#1399]: optional 4th element - the acting player, threaded by Server_AttackWave.sqf
    //--- from Common_AttackWaveActivate.sqf. objNull when absent (legacy/forged short payload); the
    //--- requester-bind guard below rejects the activation branch for any non-side-matched requester.
    _requester = if (count _this > 3) then {_this select 3} else {objNull};

    if (typeName _side != "SIDE") exitWith {
        ["WARNING", Format["AttackWave.sqf: rejected ATTACK_WAVE_DETAILS with invalid side type [%1].", typeName _side]] Call WFBE_CO_FNC_LogContent;
    };

    if (!(_side in [west, east])) exitWith {
        ["WARNING", Format["AttackWave.sqf: rejected ATTACK_WAVE_DETAILS for unsupported side [%1].", _side]] Call WFBE_CO_FNC_LogContent;
    };

    if (typeName _priceModifier != "SCALAR") exitWith {
        ["WARNING", Format["AttackWave.sqf: rejected ATTACK_WAVE_DETAILS with invalid modifier type [%1].", typeName _priceModifier]] Call WFBE_CO_FNC_LogContent;
    };

    if (typeName _attackLength != "SCALAR") exitWith {
        ["WARNING", Format["AttackWave.sqf: rejected ATTACK_WAVE_DETAILS with invalid length type [%1].", typeName _attackLength]] Call WFBE_CO_FNC_LogContent;
    };

    _priceModifierPercentage = round (_priceModifier * 100);

    if (_attackLength > 0) then {
        _attackLengthMinutes = floor (_attackLength / 60);

        //--- fix(harden) [#1399]: requester-bind (ALWAYS-ON, C4/C2 ruling - same idiom as
        //--- RequestAIComDonate.sqf and the aicom-team-disband/rally/refit/hold binds, PR #1364).
        //--- This branch is the ONLY economy mutation in this handler (the full-supply debit a few
        //--- lines below), so only this branch is gated - a forged ATTACK_WAVE_INIT/ATTACK_WAVE_DETAILS
        //--- payload could otherwise assert any _side and wipe that side's entire supply as "activation
        //--- cost" regardless of the forger's own side. The sole honest caller is Server_AttackWave.sqf,
        //--- itself fed only by Common_AttackWaveActivate.sqf's addAction, which always threads the
        //--- clicking player's own live `player` object - no honest activation can trip this. The
        //--- wave-END/reset branch below performs no mutation and stays UNGATED so it composes cleanly
        //--- with the latch-release/staleness rework [#1373] in Server_AttackWave.sqf: that reset call
        //--- must keep landing even if the original requester later disconnects, dies, or changes side
        //--- mid-wave, or the side would latch ATTACK_WAVE_ACTIVE_* permanently active.
        if (isNull _requester || {!isPlayer _requester} || {!alive _requester} || {side _requester != _side}) exitWith {
            //--- fix(reject-release): clear the overlap-guard reservation Server_AttackWave.sqf took
            //--- unconditionally BEFORE spawning its worker - the worker detects this rejection by
            //--- reading the flag after the Call, so the clear must happen here, inside the reject
            //--- branch, or a forged/invalid requester latches the side's heavy attack for a full
            //--- wave-length sleep. Idempotent on the (BE-kicked) direct-publish path, where no
            //--- reservation exists.
            if (_side == west) then {ATTACK_WAVE_ACTIVE_WEST = false};
            if (_side == east) then {ATTACK_WAVE_ACTIVE_EAST = false};
            ["WARNING", Format["AttackWave.sqf: rejected ATTACK_WAVE_DETAILS activation for side [%1] - requester [%2] invalid, dead, not a player, or side-mismatched.", _side, _requester]] Call WFBE_CO_FNC_LogContent;
        };

        if (_side == west) then {
            ATTACK_WAVE_ACTIVE_WEST = true;
            ATTACK_WAVE_WEST_PRICE_MODIFIER = _priceModifier;
        } else {
            ATTACK_WAVE_ACTIVE_EAST = true;
            ATTACK_WAVE_EAST_PRICE_MODIFIER = _priceModifier;
        };

        //--- fix(hunt): ChangeSideSupply delivers via publicVariableServer - a silent no-op ON the server (the
        //--- exact trap the header of this file documents for the wave channel itself) - so the advertised
        //--- full-supply sacrifice was never charged and HEAVY ATTACK re-armed for free every wave. Route the
        //--- debit straight through the server-side supply handler instead.
        [[format ["wfbe_supply_temp_%1", _side], [_side, -(_side call GetSideSupply), "Heavy attack mode activated."]], _side, true] Call WFBE_SE_FNC_HandleSideSupplyChange;

        [_side, "HandleSpecial", ["attack-wave", _priceModifier]] Call WFBE_CO_FNC_SendToClients;

    	["INFORMATION", Format["AttackWave.sqf: Team [%1] has activated heavy attack mode with price modifier: [%2].", _side, _priceModifier]] Call WFBE_CO_FNC_LogContent;

        [_side, "LocalizeMessage", ["AttackModeActivated", _priceModifierPercentage, _attackLengthMinutes]] call WFBE_CO_FNC_SendToClients;
    } else {
        ["INFORMATION", Format["AttackWave.sqf: Team [%1] heavy attack mode ending.", _side]] Call WFBE_CO_FNC_LogContent;

        if (_side == west) then {
            ATTACK_WAVE_ACTIVE_WEST = false;
            ATTACK_WAVE_WEST_PRICE_MODIFIER = 1;
        } else {
            ATTACK_WAVE_ACTIVE_EAST = false;
            ATTACK_WAVE_EAST_PRICE_MODIFIER = 1;
        };

        [_side, "HandleSpecial", ["attack-wave", 1]] Call WFBE_CO_FNC_SendToClients;

        [_side, "LocalizeMessage", ["AttackModeEnd"]] call WFBE_CO_FNC_SendToClients;
    };
};

"ATTACK_WAVE_DETAILS" addPublicVariableEventHandler {
    //--- Relay any client->server ATTACK_WAVE_DETAILS publish through the extracted function.
    //--- No in-tree caller currently publishes this variable (Server_AttackWave.sqf calls
    //--- WFBE_SE_FNC_HandleAttackWaveDetails directly, and the name is not in the BE-allowlist
    //--- at BattlEyeFilter/publicvariable.txt), so a raw publish here still lands on the same
    //--- requester-bind guard above and cannot bypass it.
    (_this select 1) Call WFBE_SE_FNC_HandleAttackWaveDetails;
};
