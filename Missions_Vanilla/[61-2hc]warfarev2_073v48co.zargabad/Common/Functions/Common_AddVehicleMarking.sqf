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

Private ["_vehicle","_side","_mk","_pending"];
_vehicle = _this select 0;
_side    = _this select 1;

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

//--- TODO v2: kill-tally livery (needs kill-attribution design; tally count -> decal/number).

//--- Append to wfbe_pending_texture (NEVER overwrite - preserves any salvage tint / side-skin).
if (_mk != "") then {
	_pending = _vehicle getVariable ["wfbe_pending_texture", ""];
	if (_pending != "") then {_pending = _pending + "; " + _mk} else {_pending = _mk};
	_vehicle setVariable ["wfbe_pending_texture", _pending];
};

_vehicle
