/*
	WASP Vehicle Radio - configuration (idempotent; safe to call repeatedly).

	EDIT THIS FILE to define your stations once the .ogg files exist in the
	@mkswf_vehicle_radio modpack addon.

	WASP_RADIO_MODE     : 0 = off (feature disabled), 1 = 2D personal (occupant hears, DEFAULT),
	                      2 = 3D diegetic (reserved/experimental - see Radio_Manager.sqf).
	WASP_RADIO_PLAYLIST : CfgMusic class names defined by the addon (see Mods\mkswf_vehicle_radio).
	WASP_RADIO_DUR      : length in SECONDS of each track above (same order + length) - playMusic gives
	                      no end event, so the manager advances the playlist using these durations.
	WASP_RADIO_RANGE    : metres a vehicle's radio carries in 3D mode (reserved).
	WASP_RADIO_AUTOPLAY : reserved; the radio is manual-toggle by design.

	The audio ships in the modpack addon, NOT the mission PBO, so this costs ~0 against JIP transfer.
*/

if (isNil "WASP_RADIO_MODE")     then { WASP_RADIO_MODE = 1; };

if (isNil "WASP_RADIO_PLAYLIST") then {
	WASP_RADIO_PLAYLIST = ["mkswf_radio_1","mkswf_radio_2","mkswf_radio_3","mkswf_radio_4","mkswf_radio_5","mkswf_radio_6"];
};

if (isNil "WASP_RADIO_DUR")      then {
	// Placeholder seconds (the shipped placeholder .ogg files are ~2s of silence).
	// Replace with the REAL length of each finished track, in the same order as the playlist.
	WASP_RADIO_DUR = [120,120,120,120,120,120];
};

if (isNil "WASP_RADIO_RANGE")    then { WASP_RADIO_RANGE = 40; };
if (isNil "WASP_RADIO_AUTOPLAY") then { WASP_RADIO_AUTOPLAY = false; };

if (isNil "WASP_RADIO_STATIONS") then {
	// Station name -> ordered list of CfgMusic slots (from WASP_RADIO_PLAYLIST) to cycle.
	// TODO: Nostalgia FM reuses the same addon slots as Miksuu Radio until dedicated
	// CfgMusic classes ship in @mkswf_vehicle_radio; split the lists once new tracks exist.
	WASP_RADIO_STATIONS = [
		["Miksuu Radio",   ["mkswf_radio_1","mkswf_radio_2","mkswf_radio_3"]],
		["Nostalgia FM",   ["mkswf_radio_4","mkswf_radio_5","mkswf_radio_6"]]
	];
};

if (isNil "WASP_RADIO_MENU_TIMEOUT") then { WASP_RADIO_MENU_TIMEOUT = 15; };
if (isNil "WASP_RADIO_VOLUME")       then { WASP_RADIO_VOLUME = 1; }; // client-side persisted volume (0..1), see Radio_SetVolume.sqf
