// WASP Vehicle Radio stations - used by 2D playMusic (the default radio mode).
// sound[] = { file, volume(0-1), pitch }. Paths are PBO-prefix relative (see $PBOPREFIX$.txt).
// The shipped sounds\radio_N.ogg are PLACEHOLDERS (~2s silence) - drop your finished tracks in
// and keep the same filenames (or rename here + in CfgSounds.hpp + Radio_Config.sqf).
class CfgMusic
{
    tracks[] = {};

    class mkswf_radio_1 { name = "WASP Radio 1"; sound[] = { "\mkswf_vehicle_radio\sounds\radio_1.ogg", 1.0, 1.0 }; };
    class mkswf_radio_2 { name = "WASP Radio 2"; sound[] = { "\mkswf_vehicle_radio\sounds\radio_2.ogg", 1.0, 1.0 }; };
    class mkswf_radio_3 { name = "WASP Radio 3"; sound[] = { "\mkswf_vehicle_radio\sounds\radio_3.ogg", 1.0, 1.0 }; };
    class mkswf_radio_4 { name = "WASP Radio 4"; sound[] = { "\mkswf_vehicle_radio\sounds\radio_4.ogg", 1.0, 1.0 }; };
    class mkswf_radio_5 { name = "WASP Radio 5"; sound[] = { "\mkswf_vehicle_radio\sounds\radio_5.ogg", 1.0, 1.0 }; };
    class mkswf_radio_6 { name = "WASP Radio 6"; sound[] = { "\mkswf_vehicle_radio\sounds\radio_6.ogg", 1.0, 1.0 }; };
};
