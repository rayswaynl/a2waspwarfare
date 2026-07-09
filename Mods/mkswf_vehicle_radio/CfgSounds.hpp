// Same tracks as CfgMusic, also declared as CfgSounds so the reserved 3D mode (say3D) needs
// NO re-render - it reuses these exact .ogg files. sound[] = { file, volume, pitch, distance(m) }.
class CfgSounds
{
    sounds[] = {};

    class mkswf_radio_1 { name = "mkswf_radio_1"; sound[] = { "\mkswf_vehicle_radio\sounds\radio_1.ogg", 1.0, 1.0, 80 }; titles[] = {}; };
    class mkswf_radio_2 { name = "mkswf_radio_2"; sound[] = { "\mkswf_vehicle_radio\sounds\radio_2.ogg", 1.0, 1.0, 80 }; titles[] = {}; };
    class mkswf_radio_3 { name = "mkswf_radio_3"; sound[] = { "\mkswf_vehicle_radio\sounds\radio_3.ogg", 1.0, 1.0, 80 }; titles[] = {}; };
    class mkswf_radio_4 { name = "mkswf_radio_4"; sound[] = { "\mkswf_vehicle_radio\sounds\radio_4.ogg", 1.0, 1.0, 80 }; titles[] = {}; };
    class mkswf_radio_5 { name = "mkswf_radio_5"; sound[] = { "\mkswf_vehicle_radio\sounds\radio_5.ogg", 1.0, 1.0, 80 }; titles[] = {}; };
    class mkswf_radio_6 { name = "mkswf_radio_6"; sound[] = { "\mkswf_vehicle_radio\sounds\radio_6.ogg", 1.0, 1.0, 80 }; titles[] = {}; };
};
