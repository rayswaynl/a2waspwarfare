/*
This script allows air vehicles and Linebacker and Tunguska to use Tablock, but prohibits anything else doing so
return value: true (tablock disabled), false (tablock enabled for Air and ground vehicles Linebacker/Tunguska with their rockets)

NOTE: On-foot player infantry (vehicle player == player) already passes tablock through, covering player-held Stinger and Igla. BRDM AA vehicle support remains deferred (add explicit typeOf+currentWeapon check when that vehicle is re-added).

Author: Die neunte Seele / Midnattsol, Miksuu
*/

private ["_key", "_handled", "_tabbuttons", "_vehicle"];

_key = _this select 1;
_handled = false;
_tabbuttons = actionKeys "VehLockTargets";

_vehicle = vehicle player;

if ((_vehicle == player) || // Fixes not being able to use tablock for bipod
    (_vehicle isKindOf "Air") ||
    ((typeOf _vehicle == "M6_EP1") && (currentWeapon _vehicle == "9M311Laucher")) ||
    ((typeOf _vehicle == "2S6M_Tunguska") && (currentWeapon _vehicle == "9M311Laucher")) ||
    ((typeOf _vehicle == "HMMWV_Avenger") && (currentWeapon _vehicle == "StingerLaucher")) ||
    ((typeOf _vehicle == "HMMWV_Avenger_DES_EP1") && (currentWeapon _vehicle == "StingerLaucher")) ||
    ((typeOf _vehicle == "ZSU_INS") && (currentWeapon _vehicle == "AZP85")) ||
    ((typeOf _vehicle == "ZSU_CDF") && (currentWeapon _vehicle == "AZP85")) ||
    ((typeOf _vehicle == "ZSU_TK_EP1") && (currentWeapon _vehicle == "AZP85"))
    ) then
{
    _handled = false
}
else
{
    if (_key in _tabbuttons) then
    {
        // hintsilent "Tablock was disabled";
        _handled = true
    }
};

_handled