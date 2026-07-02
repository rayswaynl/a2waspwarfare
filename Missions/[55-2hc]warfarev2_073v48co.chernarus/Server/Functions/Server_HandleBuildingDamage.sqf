Private ["_difference","_building","_redu"];
_building =_this select 0;
_ammo = _this select 2;


//--- cmdcon41 (REAL-BASE-ASSAULT part 1): when WFBE_C_STRUCTURES_ENEMY_DESTROYABLE (default 1) is on,
//--- swap the never-dies divisor (HQ 5 / factory WFBE_C_STRUCTURES_DAMAGES_REDUCTION=6) for the smaller
//--- enemy-assault divisor WFBE_C_STRUCTURES_ENEMY_REDU (default 2 for factories, default+1 for the HQ) so
//--- a real AT/armour assault kills the base in a realistic window. Flag off -> legacy 5/6 verbatim.
if ((missionNamespace getVariable ["WFBE_C_STRUCTURES_ENEMY_DESTROYABLE", 1]) > 0) then {
	private "_eRedu";
	_eRedu = missionNamespace getVariable ["WFBE_C_STRUCTURES_ENEMY_REDU", 2];
	_redu = if (_building isKindOf "Warfare_HQ_base_unfolded") then {_eRedu + 1} else {_eRedu};
} else {
	_redu = if (_building isKindOf "Warfare_HQ_base_unfolded") then {5} else {missionNamespace getVariable "WFBE_C_STRUCTURES_DAMAGES_REDUCTION"};
};

switch (_ammo) do {
	case "B_30mm_HE" :{_redu = 20};
	case "B_23mm_AA" :{_redu = 20};
};


_difference = ((_this select 1) - (getDammage (_this select 0)))/(_redu);
((getDammage (_this select 0))+_difference)