/* 
	Original Author: 
	Contributor : Marty
	Name: damage.sqf
	Parameters:
	0 - _target	: object - Used as a coordinates location for impact.
		
	Description: This function is called as NukeDammage in Server_HandleSpecial.sqf after an ICBM has been requested.
	It's purpose is to annhilate everything around a specific range	including building, trees, factories...
	It will NOT destroy ALL logic objects in order to preserved the game mechanic.   
*/
Private ["_range","_all_objects_in_range","_objects_to_not_remove","_bo","_objects_to_damage","_target","_z"];
_target = _this select 0;
_range = missionNamespace getVariable "ICBM_DAMAGE_RADIUS";
//destruction nuke range around target.
_all_objects_in_range = nearestObjects [_target,[], _range]; // Marty : Do not use the nearObjects command! It's the [] that seems to do the trick : If I had declared any type there it would leave the trees/walls etc, even if ["All"] was used. This doesnt work with command nearObjects.
_logic_class = ["AliceManager","AlternativeInjurySimulation","AmbientCombatManager","BattleFieldClearance","BIS_animals_Logic","BIS_ARTY_Logic","BIS_ARTY_Virtual_Artillery","BIS_clouds_Logic","BIS_Effect_Day","BIS_Effect_FilmGrain","BIS_Effect_MovieNight","BIS_Effect_Sepia","BIS_SRRS_Logic","ConstructionManager","FirstAidSystem","FunctionsManager","GarbageCollector","HighCommand ","HighCommandSubordinate","LocationLogicAirport","LocationLogicFlat","LocationLogicCamp","LocationLogicCityCenter","LocationLogicCity","LocationLogicCityLink","LocationLogicCityFlatArea","LocationLogicDepot","LocationLogicOwnerCivilian","LocationLogicOwnerEast","LocationLogicOwnerWest","LocationLogicOwnerResistance","LocationLogicStart","MartaManager","PreloadManager","SecOpManager","SilvieManager","StrategicReferenceLayer","UAVManager","Warfare","ZoraManager"];
_objects_to_not_remove =  _logic_class + [missionNamespace getVariable "WFBE_C_CAMP_FLAG"] + [missionNamespace getVariable "WFBE_C_DEPOT"] + [missionNamespace getVariable "WFBE_C_CAMP"] + ["land_nav_pier_c","land_nav_pier_c2","land_nav_pier_c2_end","land_nav_pier_c_270","land_nav_pier_c_90","land_nav_pier_c_big","land_nav_pier_C_L","land_nav_pier_C_L10","land_nav_pier_C_L30","land_nav_pier_C_R","land_nav_pier_C_R10","land_nav_pier_C_R30","land_nav_pier_c_t15","land_nav_pier_c_t20","land_nav_pier_F_17","land_nav_pier_F_23","land_nav_pier_m","land_nav_pier_m_1","land_nav_pier_m_end","land_nav_pier_M_fuel","land_nav_pier_pneu","land_nav_pier_uvaz"];

_objects_to_damage = _all_objects_in_range;
{
	if ((typeOf _x) in _objects_to_not_remove) then 
	{
		_objects_to_damage = _objects_to_damage - [_x];
	}
} forEach _all_objects_in_range;

{
	_x setDamage 1;
	//"Bo_GBU12_LGB" createVehicle (getPos _x);
} forEach _objects_to_damage;

//--- Radiations.
[_target] Spawn NukeRadiation;
	