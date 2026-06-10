// Marty: Restore pre-May 2026 town SV marker behavior; keep supply-role labels without recent visibility/cache changes.
// QoL S3: SpecOps gets a cooldown MM:SS countdown on town markers + ARTY_cooldown_over sound when supply becomes ready.
private["_tcarm","_units","_canCollectSupply","_supplyCooldownWasActive"];

_tcarm = missionNamespace getVariable "WFBE_C_PLAYERS_MARKER_TOWN_RANGE";
//--- Per-town cooldown-was-active cache (parallel to towns array); used to detect the active->ready transition.
_supplyCooldownWasActive = [];
{_supplyCooldownWasActive set [_forEachIndex, false]} forEach towns;

while {!gameOver} do {
	_units = (Units Group player) Call GetLiveUnits;

	{

		_town = _x;
		_townIdx = _forEachIndex;
		_range = (_town getVariable "range") * _tcarm;
		_visible = false;

		if ((_town getVariable "sideID") == sideID) then {_visible = true} else {{if (_town distance _x < _range) then {_visible = true}} forEach _units};
		_marker = Format ["WFBE_%1_CityMarker", str _town];

		if (_visible) then {

			_townSupplyMissionCoolDownEnabled = _town getVariable "supplyMissionCoolDownEnabled";

			//--- QoL S3: detect cooldown expiry for SpecOps and play supply-ready sound.
			if (!isNil "WFBE_SK_V_Type") then {
				if (WFBE_SK_V_Type == 'SpecOps') then {
					if ((_supplyCooldownWasActive select _townIdx) && !_townSupplyMissionCoolDownEnabled) then {
						playSound "ARTY_cooldown_over";
					};
				};
			};
			_supplyCooldownWasActive set [_townIdx, _townSupplyMissionCoolDownEnabled];

			if (!_townSupplyMissionCoolDownEnabled) then {
				waitUntil { !(isNil "WFBE_SK_V_Type") };
				if (WFBE_SK_V_Type == 'SpecOps') then {
					_marker setMarkerTextLocal Format["  SV: %1/%2  [+SUPPLY]",_town getVariable "supplyValue",_town getVariable "maxSupplyValue"];
				} else {
					_marker setMarkerTextLocal Format["  SV: %1/%2  [+]",_town getVariable "supplyValue",_town getVariable "maxSupplyValue"];
				};
			} else {
				//--- QoL S3: SpecOps sees MM:SS countdown until supply is ready again.
				if (!isNil "WFBE_SK_V_Type" && {WFBE_SK_V_Type == 'SpecOps'}) then {
					private ["_lastRun","_elapsed","_remaining","_mm","_ss"];
					_lastRun  = _town getVariable ["LastSupplyMissionRun", 0];
					_elapsed  = time - _lastRun;
					_remaining = (WFBE_CO_VAR_SupplyMissionRegenInterval - _elapsed) max 0;
					_mm = floor (_remaining / 60);
					_ss = floor (_remaining - (_mm * 60));
					_marker setMarkerTextLocal Format["  SV: %1/%2  [%3:%4]",
						_town getVariable "supplyValue",
						_town getVariable "maxSupplyValue",
						_mm,
						if (_ss < 10) then {Format ["0%1", _ss]} else {str _ss}
					];
				} else {
					_marker setMarkerTextLocal Format["  SV: %1/%2",_town getVariable "supplyValue",_town getVariable "maxSupplyValue"];
				};
			};
		} else {_marker setMarkerTextLocal ""};

	} forEach towns;

	sleep 5;
};
