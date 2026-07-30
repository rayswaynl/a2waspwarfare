/*
	Set a variable in the profile namespace.
	 Parameters:
		- Variable name.
		- Value.
*/

Private ['_var','_value'];

_var = _this select 0;
_value = _this select 1;

profileNamespace setVariable [_var, _value];
//--- fix(ns-persist r34): persist to disk. Set without save only lasts the process;
//--- Settings_Open called this helper and never saved (skin/Team menus did).
saveProfileNamespace;