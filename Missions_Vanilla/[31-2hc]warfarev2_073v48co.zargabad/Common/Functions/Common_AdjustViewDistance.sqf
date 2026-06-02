/*
This script allows the player to adjust view distance or target FPS with the custom action keys 18, 19 and 20.

Author: Miksuu
Contributors: Marty
*/
Private ["_key","_adjustViewDistanceBy","_newViewDistanceToBeSet","_adjustTargetFpsBy","_savedViewDistance"];
_key = _this select 1;

_adjustViewDistanceBy = 1000;
_adjustTargetFpsBy = 1;

_auto_distance_view_target_fps = missionNamespace getVariable "AUTO_DISTANCE_VIEW_TARGET_FPS";
_toggle_auto_distance_view = missionNamespace getVariable "TOOGLE_AUTO_DISTANCE_VIEW";

//--- Marty: Automatic view distance feature
if (_key in (actionKeys "User18")) then 
{
    if (_toggle_auto_distance_view) then 
    {
        missionNamespace setVariable ["TOOGLE_AUTO_DISTANCE_VIEW", false]; // deactivate the feature.
        "Automatic view distance is now OFF" call GroupChatMessage;
        playSound ["autoViewDistanceToggledOff",true];
        _savedViewDistance = missionNamespace getVariable "SAVED_VIEW_DISTANCE";
        setViewDistance _savedViewDistance;
    } else 
    {
        missionNamespace setVariable ["SAVED_VIEW_DISTANCE", viewDistance];
        missionNamespace setVariable ["TOOGLE_AUTO_DISTANCE_VIEW", true]; // activate the feature.
        "Automatic view distance is now ON" call GroupChatMessage;
        playSound ["autoViewDistanceToggledOn",true];
    };
};

//--- Decrease View Distance or Target FPS
if (_key in (actionKeys "User19")) then {
    if (_toggle_auto_distance_view) then {
        _auto_distance_view_target_fps = (_auto_distance_view_target_fps - _adjustTargetFpsBy) max 30;
        if !(isNil 'WFBE_CO_FNC_SetProfileVariable') then {['WFBE_TARGET_FPS', _auto_distance_view_target_fps] Call WFBE_CO_FNC_SetProfileVariable; _need_save = true};
        missionNamespace setVariable ["AUTO_DISTANCE_VIEW_TARGET_FPS", _auto_distance_view_target_fps];
        (format ["Target FPS has been set to be min. %1 max %2", _auto_distance_view_target_fps - 4, _auto_distance_view_target_fps + 4]) call GroupChatMessage;
    } else {
        if (newViewDistance == 0) then {
            _newViewDistanceToBeSet = viewDistance;
        } else {
            _newViewDistanceToBeSet = newViewDistance;
        };
        newViewDistance = _newViewDistanceToBeSet - _adjustViewDistanceBy max 1;
        (format ["Setting view distance to: %1", str(newViewDistance)]) call GroupChatMessage;
        execVm "Common\Functions\Common_AdjustViewDistanceTimerScript.sqf";
    };
};

//--- Increase View Distance or Target FPS
if (_key in (actionKeys "User20")) then {
    if (_toggle_auto_distance_view) then {
        _auto_distance_view_target_fps = (_auto_distance_view_target_fps + _adjustTargetFpsBy) min 240;
        missionNamespace setVariable ["AUTO_DISTANCE_VIEW_TARGET_FPS", _auto_distance_view_target_fps];
        if !(isNil 'WFBE_CO_FNC_SetProfileVariable') then {['WFBE_TARGET_FPS', _auto_distance_view_target_fps] Call WFBE_CO_FNC_SetProfileVariable; _need_save = true};
        (format ["Target FPS has been set to be min. %1 max %2", _auto_distance_view_target_fps - 4, _auto_distance_view_target_fps + 4]) call GroupChatMessage;
    } else {
        if (newViewDistance == 0) then {
            _newViewDistanceToBeSet = viewDistance;
        } else {
            _newViewDistanceToBeSet = newViewDistance;
        };
        newViewDistance = _newViewDistanceToBeSet + _adjustViewDistanceBy min WFBE_C_ENVIRONMENT_MAX_VIEW;
        (format ["Setting view distance to: %1", str(newViewDistance)]) call GroupChatMessage;
        [] execVm "Common\Functions\Common_AdjustViewDistanceTimerScript.sqf";
    };
};

false
