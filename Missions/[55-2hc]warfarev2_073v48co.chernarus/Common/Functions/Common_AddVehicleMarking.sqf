/*
	Common_AddVehicleMarking.sqf
	Per-side team recognition markings for freshly-created vehicles (Miksuu experital set).
	Input : [_vehicle, _side]   (_side = numeric side id; WEST 0 / EAST 1 / GUER 2)
	Output: _vehicle

	Markings are APPENDED to the vehicle's wfbe_pending_texture so they ride the single
	Init_Unit processInitCommands broadcast in Common_CreateVehicle.sqf (JIP-safe) and never
	clobber a per-class tint/skin set elsewhere - see the Mi17_medevac_CDF salvage case and the
	WEST matte-black block in Common_AddVehicleTexture.sqf. setVehicleInit keeps only the LAST
	string set, so APPEND (never overwrite) is mandatory here.

	Gate: WFBE_C_VEHICLE_MARKINGS (Init_CommonConstants.sqf). 0 = no markings AND no side-skins.
	Kill tally marker gate: WFBE_C_KILL_TALLY_DECAL (default 1 since the 2026-07-04 Ray pick).
	Independent from the side lights/tints; heat-ramp amber -> orange -> red -> white-hot, one dim local light.

	Implementation: the zero-art "ships now" markings are dim LOCAL #lightpoint glows attached per
	side (recognition-panel colour + side running light + a faint IR-strobe stand-in). Each marking
	string runs on every machine (incl. JIP) so createVehicleLocal makes one local light per client.
	The high-fidelity per-side SHAPE (WEST chevron / EAST inverted-V) is STUBBED below as an attached
	billboard pending the .paa art from image-gen + an in-engine attach-object test.
	PERF: this attaches up to 3 dim lights per created vehicle by default - if server FPS dips, set
	WFBE_C_VEHICLE_MARKINGS = 0 (it is the first lever to cut).
	NEEDS-IN-ENGINE-VERIFY: light offset/brightness, daytime visibility (lightpoints favour night),
	and the per-vehicle FPS cost at full vehicle counts.
*/

Private ["_vehicle","_side","_mk","_pending","_tallyMk"];
_vehicle = _this select 0;
_side    = _this select 1;

//--- Lane 205: JIP-safe kill-tally marker. The server owns wfbe_kill_tally in RequestOnUnitKilled.sqf;
//--- each client runs this tiny local watcher from the vehicle init string and updates one local light.
//--- Heat-ramp tier picker (Ray 2026-07-04 visual pass): 1-2 kills amber, 3-5 orange, 6-9 red, 10+ white-hot.
//--- Deliberately warm/military - no cool or neon hues - and hull-hugging so the glow reads as a marking.
if ((missionNamespace getVariable ["WFBE_C_KILL_TALLY_DECAL", 0]) > 0) then {
	_tallyMk = "this spawn {private ['_veh','_last','_cnt','_tier','_light','_bright','_color']; _veh = _this; _last = -1; while {alive _veh} do {_cnt = _veh getVariable ['wfbe_kill_tally',0]; if ((abs (_cnt - _last)) > 0) then {_last = _cnt; _light = _veh getVariable ['mks_tally',objNull]; if (_cnt <= 0) then {if !(isNull _light) then {deleteVehicle _light; _veh setVariable ['mks_tally',objNull]}} else {if (isNull _light) then {_light = '#lightpoint' createVehicleLocal (position _veh); _veh setVariable ['mks_tally',_light]; _light attachTo [_veh,[0,0.5,1.1]]}; _tier = 1; if (_cnt >= 3) then {_tier = 2}; if (_cnt >= 6) then {_tier = 3}; if (_cnt >= 10) then {_tier = 4}; _bright = 0.025; _color = [1.0,0.55,0.05]; switch (_tier) do {case 2: {_bright = 0.032; _color = [1.0,0.33,0.02]}; case 3: {_bright = 0.040; _color = [1.0,0.08,0.0]}; case 4: {_bright = 0.050; _color = [1.0,0.85,0.6]};}; _light setLightBrightness _bright; _light setLightColor _color; _light setLightAmbient _color};}; sleep 2;}; _light = _veh getVariable ['mks_tally',objNull]; if !(isNull _light) then {deleteVehicle _light};}";
	_pending = _vehicle getVariable ["wfbe_pending_texture", ""];
	if ((count _pending) > 0) then {_pending = _pending + "; " + _tallyMk} else {_pending = _tallyMk};
	_vehicle setVariable ["wfbe_pending_texture", _pending];
};
//--- Master gate (also governs the side-skins in Common_AddVehicleTexture.sqf).
if ((missionNamespace getVariable ["WFBE_C_VEHICLE_MARKINGS", 1]) != 1) exitWith {_vehicle};

//--- Stamp the resolved side id so the texture pass can read it without re-deriving side.
_vehicle setVariable ["wfbe_side_id", _side];

_mk = "";

switch (_side) do {
	//--- WEST: VS-17 orange recognition glow + blue running light.
	case WFBE_C_WEST_ID: {
		_mk = "this setVariable ['mks_rec', '#lightpoint' createVehicleLocal (position this)]; (this getVariable 'mks_rec') setLightBrightness 0.04; (this getVariable 'mks_rec') setLightColor [0.9,0.45,0.0]; (this getVariable 'mks_rec') setLightAmbient [0.9,0.45,0.0]; (this getVariable 'mks_rec') attachTo [this,[0,0,1.4]]";
		_mk = _mk + "; this setVariable ['mks_run', '#lightpoint' createVehicleLocal (position this)]; (this getVariable 'mks_run') setLightBrightness 0.03; (this getVariable 'mks_run') setLightColor [0.0,0.2,1.0]; (this getVariable 'mks_run') setLightAmbient [0.0,0.2,1.0]; (this getVariable 'mks_run') attachTo [this,[0,-1,1.2]]";
	};
	//--- EAST: VS-17 orange recognition glow + red running light.
	case WFBE_C_EAST_ID: {
		_mk = "this setVariable ['mks_rec', '#lightpoint' createVehicleLocal (position this)]; (this getVariable 'mks_rec') setLightBrightness 0.04; (this getVariable 'mks_rec') setLightColor [0.9,0.45,0.0]; (this getVariable 'mks_rec') setLightAmbient [0.9,0.45,0.0]; (this getVariable 'mks_rec') attachTo [this,[0,0,1.4]]";
		_mk = _mk + "; this setVariable ['mks_run', '#lightpoint' createVehicleLocal (position this)]; (this getVariable 'mks_run') setLightBrightness 0.03; (this getVariable 'mks_run') setLightColor [1.0,0.0,0.0]; (this getVariable 'mks_run') setLightAmbient [1.0,0.0,0.0]; (this getVariable 'mks_run') attachTo [this,[0,-1,1.2]]";
	};
	//--- GUER: green recognition panel glow + green running light.
	case WFBE_C_GUER_ID: {
		_mk = "this setVariable ['mks_rec', '#lightpoint' createVehicleLocal (position this)]; (this getVariable 'mks_rec') setLightBrightness 0.04; (this getVariable 'mks_rec') setLightColor [0.0,0.7,0.0]; (this getVariable 'mks_rec') setLightAmbient [0.0,0.7,0.0]; (this getVariable 'mks_rec') attachTo [this,[0,0,1.4]]";
		_mk = _mk + "; this setVariable ['mks_run', '#lightpoint' createVehicleLocal (position this)]; (this getVariable 'mks_run') setLightBrightness 0.03; (this getVariable 'mks_run') setLightColor [0.0,0.7,0.0]; (this getVariable 'mks_run') setLightAmbient [0.0,0.7,0.0]; (this getVariable 'mks_run') attachTo [this,[0,-1,1.2]]";
	};
};

//--- IR strobe stand-in (all marked sides): a very faint local light. A true IR-only strobe needs an
//--- NV-gated source the engine does not expose cleanly to script, so this is a placeholder marker.
//--- NEEDS-IN-ENGINE-VERIFY: swap for a proper IR object/proxy if one reads correctly under NV.
if (_mk != "") then {
	_mk = _mk + "; this setVariable ['mks_ir', '#lightpoint' createVehicleLocal (position this)]; (this getVariable 'mks_ir') setLightBrightness 0.015; (this getVariable 'mks_ir') setLightColor [1.0,1.0,1.0]; (this getVariable 'mks_ir') setLightAmbient [1.0,1.0,1.0]; (this getVariable 'mks_ir') attachTo [this,[0,1,1.5]]";
};

//--- STUB: WEST chevron / EAST inverted-V SHAPE as an attached billboard textured with the per-side
//--- .paa. Needs in-engine attach-object test + the .paa from image-gen. The proxy/billboard class
//--- below ('<billboard_class>') is a placeholder - pick a flat sign/proxy that accepts setObjectTexture.
//--- WEST: Textures\mks_west_chevron_ca.paa ; EAST: Textures\mks_east_invv_ca.paa
//if (_side == WFBE_C_WEST_ID) then { _mk = _mk + "; this setVariable ['mks_shape', '<billboard_class>' createVehicleLocal (position this)]; (this getVariable 'mks_shape') setObjectTexture [0,'Textures\mks_west_chevron_ca.paa']; (this getVariable 'mks_shape') attachTo [this,[0,0,1.6]]"; };
//if (_side == WFBE_C_EAST_ID) then { _mk = _mk + "; this setVariable ['mks_shape', '<billboard_class>' createVehicleLocal (position this)]; (this getVariable 'mks_shape') setObjectTexture [0,'Textures\mks_east_invv_ca.paa']; (this getVariable 'mks_shape') attachTo [this,[0,0,1.6]]"; };

//--- Lane 205 kill-tally livery is installed above so it can run even when side markings stay disabled.

//--- Append to wfbe_pending_texture (NEVER overwrite - preserves any salvage tint / side-skin).
if (_mk != "") then {
	_pending = _vehicle getVariable ["wfbe_pending_texture", ""];
	if (_pending != "") then {_pending = _pending + "; " + _mk} else {_pending = _mk};
	_vehicle setVariable ["wfbe_pending_texture", _pending];
};

_vehicle
