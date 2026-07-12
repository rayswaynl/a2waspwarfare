/*
	WASP Vehicle Radio - configuration (idempotent; safe to call repeatedly).

	WASP_RADIO_MODE     : 0 = off (feature disabled), 1 = 2D personal (occupant hears, DEFAULT).
	                      Mode 2 (3D diegetic) is not achievable under streaming playback - an
	                      extension can only return strings to SQF, it cannot inject decoded
	                      audio into Arma's positional sound engine, so streaming stays
	                      occupant-only. This is not a regression (Mode 1 was already the
	                      default), just no longer a "coming later" placeholder.
	WASP_RADIO_STATIONS : station name -> live internet stream URL (music.miksuu.com), played via
	                      the "a2waspwarfare_Extension" callExtension RADIO,PLAY/STOP/VOLUME
	                      commands (BASS-backed, see Extension\src\BaseExtensionClass\
	                      Implementations\RADIO.cs). No CfgMusic classes or bundled audio
	                      involved - nothing here adds to the mission PBO or modpack download size.
	WASP_RADIO_RANGE    : metres a vehicle's radio carries in 3D mode (reserved; unused, see above).
	WASP_RADIO_AUTOPLAY : reserved; the radio is manual-toggle by design.

	Third-party dependency: music.miksuu.com is an external service the mission doesn't control.
	If it's unreachable, RADIO.cs fails closed (no sound, no crash, no RPT spam loop) - a station
	pick will simply stay silent until the stream is reachable again.
*/

if (isNil "WASP_RADIO_MODE")     then { WASP_RADIO_MODE = 1; };

if (isNil "WASP_RADIO_RANGE")    then { WASP_RADIO_RANGE = 40; };
if (isNil "WASP_RADIO_AUTOPLAY") then { WASP_RADIO_AUTOPLAY = false; };

if (isNil "WASP_RADIO_STATIONS") then {
	// Station name -> live stream URL, played by the client-side RADIO extension.
	WASP_RADIO_STATIONS = [
		["Miksuu Radio",       "https://music.miksuu.com/stream"],
		["Suwalki FM",         "https://music.miksuu.com/stream/nostalgia"],
		["Operating Systems",  "https://music.miksuu.com/stream/opsys"],
		["Radio Rasman",       "https://music.miksuu.com/stream/rasman"]
	];
};

if (isNil "WASP_RADIO_MENU_TIMEOUT") then { WASP_RADIO_MENU_TIMEOUT = 15; };
if (isNil "WASP_RADIO_VOLUME")       then { WASP_RADIO_VOLUME = 1; }; // client-side persisted volume (0..1); sent to the extension as round(vol*100), see Radio_SetVolume.sqf
