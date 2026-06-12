/*
	Whenever a missile is shot at the tank...
*/

Private ["_ammo","_lastFired","_projectile","_shooter","_vehicle","_upgrades","_irSmokeUpgradeLevel"];

_vehicle = _this select 0;
_ammo = _this select 1;
_shooter = _this select 2;

//--- Make sure that the target is alive.
if (alive _vehicle) then {
	//--- Get the projectile.
	_projectile = nearestObject[_shooter, _ammo];
	if (isNull _projectile) exitWith {};

	//--- Only triggered upon IR Lock Ammo.
	if (getNumber(configFile >> "CfgAmmo" >> _ammo >> "irLock") == 1) then {
		//--- Vehicle specific.
		if (local _vehicle) then {
			if (alive driver _vehicle || alive gunner _vehicle || alive commander _vehicle) then {
				_lastFired = _vehicle getVariable "wfbe_irs_lastfired";
				if (isNil '_lastFired') then {_lastFired = -100};
				if ((_vehicle getVariable "wfbe_irs_flares") > 0 && (time - _lastFired > (missionNamespace getVariable "WFBE_IRS_FLARE_DELAY"))) then {
					(_vehicle) Spawn WFBE_CO_MOD_IRS_DeploySmoke;
					_vehicle setVariable ["wfbe_irs_lastfired", time];
					_vehicle setVariable ["wfbe_irs_flares", (_vehicle getVariable "wfbe_irs_flares") - 1, true];
					if ((local player) && (player in crew _vehicle)) then {
						
						_upgrades = (sideJoined) Call WFBE_CO_FNC_GetSideUpgrades;
						_irSmokeUpgradeLevel = _upgrades select WFBE_UP_IRSMOKE;

						_vehicle vehicleChat Format[localize "STR_WF_CHAT_IRS_Deployed",_vehicle getVariable "wfbe_irs_flares"];

						// Play the regular sound if the upgrade level is less than 2 (just like before)
						if (_irSmokeUpgradeLevel < 2) then {
					    	playSound ["inboundMissileGround", true];
						} 
						// Play the continious sound effect if the upgrade level is 2 or higher
						else { 
							[_projectile] spawn {
							_projectile = _this select 0;
											
							while {!(isNull _projectile)} do {
								playSound["inboundMissileGround_cont",true];
								sleep 0.2;
								};
							};
						};
                    };
				};
			};
		};
		
		//--- Missile specific.
		if (local _projectile) then {[_vehicle, _projectile, _ammo] Spawn WFBE_CO_MOD_IRS_HandleMissile};
	};
};

