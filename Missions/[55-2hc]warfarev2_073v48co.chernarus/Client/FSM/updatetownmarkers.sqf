// Marty: Restore pre-May 2026 town SV marker behavior; keep supply-role labels without recent visibility/cache changes.
// QoL S3: SpecOps gets a cooldown MM:SS countdown on town markers + ARTY_cooldown_over sound when supply becomes ready.
private["_tcarm","_units","_canCollectSupply","_supplyCooldownWasActive","_mapVisible","_isSpecOps","_lastTownText","_desired"];

_tcarm = missionNamespace getVariable "WFBE_C_PLAYERS_MARKER_TOWN_RANGE";
//--- Per-town cooldown-was-active cache (parallel to towns array); used to detect the active->ready transition.
_supplyCooldownWasActive = [];
{_supplyCooldownWasActive set [_forEachIndex, false]} forEach towns;
//--- cmdcon41-w3c PERF4 skip-unchanged-writes: parallel per-town cache of the LAST text pushed to each
//--- city marker. This loop previously called setMarkerTextLocal on EVERY town EVERY 5s (and wrote "" to
//--- every out-of-range town every pass) regardless of whether the text changed. Supply values move rarely,
//--- so the vast majority of those were redundant local marker writes. Gate every write behind a compare
//--- against this cache - identical on-screen result, far fewer marker writes. Seeded to a sentinel so the
//--- first pass always writes. Same house idiom as updateteamsmarkers/patrol/AAR loops. A2-OA-1.64-safe.
_lastTownText = [];
{_lastTownText set [_forEachIndex, "~"]} forEach towns;

while {!gameOver} do {
	//--- client-FPS (PR #40): town SV markers are map-only; skip the per-town distance scan + marker
	//--- writes while the map is closed. SpecOps keeps running so its supply-ready cue + MM:SS countdown
	//--- still fire off-map. visibleMap/shownGPS are A2-OA-safe (already used across the marker scripts).
	_mapVisible = visibleMap || shownGPS;
	_isSpecOps = (!isNil "WFBE_SK_V_Type") && {WFBE_SK_V_Type == 'SpecOps'};
	if (!_mapVisible && !_isSpecOps) then { sleep 0.5 } else {
	_units = (Units Group player) Call GetLiveUnits;

	{

		_town = _x;
		_townIdx = _forEachIndex;
		_range = (_town getVariable "range") * _tcarm;
		_visible = false;

		if ((_town getVariable "sideID") == sideID) then {_visible = true} else {{if (_town distance _x < _range) then {_visible = true}} forEach _units};
		_marker = Format ["WFBE_%1_CityMarker", str _town];

		//--- cmdcon41-w3c PERF4: build the desired marker text in _desired, then write ONCE, gated on change.
		_desired = "";

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
					_desired = Format["  SV: %1/%2  [+SUPPLY]",_town getVariable "supplyValue",_town getVariable "maxSupplyValue"];
				} else {
					_desired = Format["  SV: %1/%2  [+]",_town getVariable "supplyValue",_town getVariable "maxSupplyValue"];
				};
			} else {
				//--- QoL S3: SpecOps sees MM:SS countdown until supply is ready again.
				if (!isNil "WFBE_SK_V_Type" && {WFBE_SK_V_Type == 'SpecOps'} && {!isNil "WFBE_CO_VAR_SupplyMissionRegenInterval"}) then {
					private ["_lastRun","_elapsed","_remaining","_mm","_ss"];
					_lastRun  = _town getVariable ["LastSupplyMissionRun", 0];
					_elapsed  = time - _lastRun;
					_remaining = (WFBE_CO_VAR_SupplyMissionRegenInterval - _elapsed) max 0;
					_mm = floor (_remaining / 60);
					_ss = floor (_remaining - (_mm * 60));
					_desired = Format["  SV: %1/%2  [%3:%4]",
						_town getVariable "supplyValue",
						_town getVariable "maxSupplyValue",
						_mm,
						if (_ss < 10) then {Format ["0%1", _ss]} else {str _ss}
					];
				} else {
					_desired = Format["  SV: %1/%2",_town getVariable "supplyValue",_town getVariable "maxSupplyValue"];
				};
			};
		} else {_desired = ""};

			//--- Naval HVT prepends the town name; compute against _desired (NOT a markerText read-back) so the
			//--- change-gate below stays correct and the name never double-prepends across ticks.
			if (_town getVariable ["wfbe_is_naval_hvt", false]) then {
				_desired = (_town getVariable ["name",""]) + _desired;
			};

			//--- cmdcon41-w3c PERF4 skip-unchanged-writes gate: only touch the marker when the text actually changed.
			if (_desired != (_lastTownText select _townIdx)) then {
				_marker setMarkerTextLocal _desired;
				_lastTownText set [_townIdx, _desired];
			};

	} forEach towns;

	sleep 5;
	};
};
