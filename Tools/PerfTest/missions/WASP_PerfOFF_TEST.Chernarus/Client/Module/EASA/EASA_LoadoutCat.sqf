//--- WFBE_EASA_FNC_LoadoutCat
//--- Pure, display-only classifier for an EASA loadout row.
//--- Input  : an EASA data row's weapon/ammo pair => [[weapons...],[ammos...]] (i.e. _row select 2).
//--- Output : STRING role tag => '[MR]' (both AA & AG), '[AA]' (air-to-air only),
//---          '[AG]' (air-to-ground only), or '' (neither / unknown).
//--- Classification keys off the WEAPON-slot classes (launchers / gun pods), which are
//--- string literals defined in EASA_Init.sqf. Static lookups; no globals, no side effects.

private ["_pair","_weapons","_w","_hasAA","_hasAG","_aaList","_agList"];

//--- Air-to-air missile launchers.
_aaList = [
	'R73Launcher_2',
	'Igla_twice',
	'StingerLauncher_twice',
	'SidewinderLaucher_AH1Z',
	'SidewinderLaucher_F35'
];

//--- Air-to-ground: bombs, AT/AS missiles, rocket pods and gun pods.
_agList = [
	'AirBombLauncher',
	'BombLauncherF35',
	'HeliBombLauncher',
	'Mk82BombLauncher_6',
	'Ch29Launcher_Su34',
	'AT9Launcher',
	'AT5Launcher',
	'HellfireLauncher',
	'MaverickLauncher',
	'SpikeLauncher_ACR',
	'TOWLauncherSingle',
	'VikhrLauncher',
	'S8Launcher',
	'57mmLauncher',
	'FFARLauncher',
	'CRV7_HEPD',
	'CTWS',
	'PKT'
];

_pair = _this;
_weapons = if ((count _pair) > 0) then {_pair select 0} else {[]};

_hasAA = false;
_hasAG = false;

{
	_w = _x;
	if (_w in _aaList) then {_hasAA = true};
	if (_w in _agList) then {_hasAG = true};
} forEach _weapons;

if (_hasAA && _hasAG) exitWith {'[MR]'};
if (_hasAA) exitWith {'[AA]'};
if (_hasAG) exitWith {'[AG]'};
''
