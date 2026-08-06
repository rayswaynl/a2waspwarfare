
fnc_marker_removeKeyEHs =
{
    private ["_display"];
    _display = _this select 0;

    //--- Only remove the two handlers this helper registered on this exact marker dialog.
    //--- displayRemoveAllEventHandlers also erased unrelated display-54 key handlers.
    if (!isNil "WASP_MarkerKeyEHDisplay" && {WASP_MarkerKeyEHDisplay == _display}) then {
        if (!isNil "WASP_MarkerKeyUpEH") then {
            _display displayRemoveEventHandler ["KeyUp", WASP_MarkerKeyUpEH];
            WASP_MarkerKeyUpEH = nil;
        };
        if (!isNil "WASP_MarkerKeyDownEH") then {
            _display displayRemoveEventHandler ["KeyDown", WASP_MarkerKeyDownEH];
            WASP_MarkerKeyDownEH = nil;
        };
        WASP_MarkerKeyEHDisplay = nil;
    };
};

fnc_marker_keyUp_EH =
{
    private["_handled","_display","_dikCode","_control","_text"];
    _display = _this select 0;
    _dikCode = _this select 1;
    _out = false;

    if ((_dikCode == 28) || (_dikCode == 156)) then
    {
		_control = _display displayCtrl 101;
        _text = ctrlText _control;
        if (_text == "") then
        {
            _text = format ["%1", name player];
        }
        else
        {
            _text = format ["%1: %2", name player, _text];
        };
		_control ctrlSetText _text;		
        [_display] call fnc_marker_removeKeyEHs;

    };

    _out;
};

fnc_marker_keyDown_EH =
{
    private
    [
        "_handled",
        "_display",
        "_dikCode"
    ];
    _display = _this select 0;
    _dikCode = _this select 1;
    _out = false;

    if (_dikCode == 1) then
    {
        [_display] call fnc_marker_removeKeyEHs;

    };

    _out;
};

fnc_map_mouseButtonDblClick_EH =
{
    private
    ["_display"];

    disableUserInput true;
    (time + 2) spawn
    {
        disableSerialization;

        while {time < _this} do
        {
            sleep 0.1;
            _display = findDisplay 54;
            if (!isNull _display) exitWith
            {
                
                //--- Repeated map double-clicks can revisit this dialog; replace only our prior pair.
                [_display] call fnc_marker_removeKeyEHs;
                WASP_MarkerKeyEHDisplay = _display;
                WASP_MarkerKeyUpEH = _display displayAddEventHandler ["KeyUp", "_this call fnc_marker_keyUp_EH"];
                WASP_MarkerKeyDownEH = _display displayAddEventHandler ["KeyDown", "_this call fnc_marker_keyDown_EH"];

            };
        };
        disableUserInput false;
    };
    true;
};

if (local player) then
{
    waitUntil {sleep 0.1; !isNull (findDisplay 12)};
    ((findDisplay 12) displayCtrl 51) ctrlAddEventHandler ["mouseButtonDblClick", "call fnc_map_mouseButtonDblClick_EH"];
};