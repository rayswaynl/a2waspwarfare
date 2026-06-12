Private ["_lock","_position","_side","_type","_vehicle"];
_vehicle = _this select 0;
_type = typeof _vehicle;

switch (_type) do {
	case "M2A2_EP1": {
		if (IS_chernarus_map_dependent) then { // Woodland came is required
			_vehicle setVehicleInit "this setObjectTexture [0,""Textures\base_co.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [1,""Textures\a3_co.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [2,""Textures\ultralp_co.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [3,""Textures\base_co.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [4,""Textures\base_co.paa""]";
		};
		
	};

	case "AAV": {
		if !(IS_chernarus_map_dependent) then {
			_vehicle setVehicleInit "this setObjectTexture [0,""Textures\aav_ext_coD.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [1,""Textures\aav_ext2_coD.paa""]";
		};
		
	};

	case "LAV25": {
		if !(IS_chernarus_map_dependent) then {
			_vehicle setVehicleInit "this setObjectTexture [0,""Textures\lavbody_coD.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [1,""Textures\lavbody2_coD.paa""]";
		};
		
	};

	case "BMP3": {
		if !(IS_chernarus_map_dependent) then {
			_vehicle setVehicleInit "this setObjectTexture [0,""Textures\bmp3_body_co.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [1,""Textures\bmp3_body2_co.paa""]";
		};
		 
	};


	case "M2A3_EP1": {
		if (IS_chernarus_map_dependent) then {
			_vehicle setVehicleInit "this setObjectTexture [0,""Textures\base_co.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [1,""Textures\a3_co.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [2,""Textures\ultralp_co.paa""]";
		};
		
	};

	case "M6_EP1":{
		if (IS_chernarus_map_dependent) then {
			_vehicle setVehicleInit "this setObjectTexture [0,""Textures\base_co.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [1,""Textures\a3_co.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [2,""Textures\ultralp_co.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [3,""Textures\base_co.paa""]";
		};
		
	};

	case "BTR90": {
		if !(IS_chernarus_map_dependent) then {
			_vehicle setVehicleInit "this setObjectTexture [0,""Textures\btr_body_co.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [1,""Textures\btr_body2_co.paa""]";
		};
		 
	};

	case "2S6M_Tunguska": {
		if !(IS_chernarus_map_dependent) then {
			_vehicle setVehicleInit "this setObjectTexture [0,""Textures\tunguska_co.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [2,""Textures\tunguska_turret_co.paa""]";
		};
		
	};

	case "M1128_MGS_EP1":{
		if (IS_chernarus_map_dependent) then {
			_vehicle setVehicleInit "this setObjectTexture [0,""Textures\stryker_mgs_body1.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [1,""Textures\stryker_body2.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [2,""Textures\stryker_mgs_1.paa""]";
		};
		
	};

	case "M1129_MC_EP1":{
		if (IS_chernarus_map_dependent) then {
			_vehicle setVehicleInit "this setObjectTexture [0,""Textures\stryker_mgs_body1.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [1,""Textures\stryker_body2.paa""]";
		};
	
	};

	case "M1135_ATGMV_EP1":{
		if (IS_chernarus_map_dependent) then {
			_vehicle setVehicleInit "this setObjectTexture [0,""Textures\stryker_mgs_body1.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [1,""Textures\stryker_body2.paa""]";
		};
	
	};

	case "M1126_ICV_mk19_EP1":{
		if (IS_chernarus_map_dependent) then {
			_vehicle setVehicleInit "this setObjectTexture [0,""Textures\stryker_mgs_body1.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [1,""Textures\stryker_body2.paa""]";
		};
	
	};

	case "M1126_ICV_M2_EP1":{
		if (IS_chernarus_map_dependent) then {
			_vehicle setVehicleInit "this setObjectTexture [0,""Textures\stryker_mgs_body1.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [1,""Textures\stryker_body2.paa""]";
		};
	
	};

	case "HMMWV_M1151_M2_DES_EP1":{
		if (IS_chernarus_map_dependent) then {
			_vehicle setVehicleInit "this setObjectTexture [0,""Textures\base_3.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [1,""Textures\base_2.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [2,""Textures\base_0.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [3,""Textures\hmmwv_gpk_tower.paa""]";
		};
	};

	case "HMMWV_M998A2_SOV_DES_EP1":{
		if (IS_chernarus_map_dependent) then {
			_vehicle setVehicleInit "this setObjectTexture [0,""Textures\base_3.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [1,""Textures\base_2.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [2,""Textures\base_0.paa""]";
		};
	};

	case "HMMWV_M1035_DES_EP1": {
		if (IS_chernarus_map_dependent) then {
			_vehicle setVehicleInit "this setObjectTexture [0,""Textures\base_3.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [1,""Textures\base_2.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [3,""Textures\hmmwv_up_1.paa""]";
		};
	};

	case "HMMWV_M998_crows_MK19_DES_EP1":{
		if (IS_chernarus_map_dependent) then {
			_vehicle setVehicleInit "this setObjectTexture [0,""Textures\base_3.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [1,""Textures\base_2.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [2,""Textures\base_0.paa""]";
		};
	};

	case "HMMWV_M998_crows_M2_DES_EP1":{
		if (IS_chernarus_map_dependent) then {
			_vehicle setVehicleInit "this setObjectTexture [0,""Textures\base_3.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [1,""Textures\base_2.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [2,""Textures\base_0.paa""]";
		};
	};

	case "M113Ambul_TK_EP1":{
		if (IS_chernarus_map_dependent) then {
			_vehicle setVehicleInit "this setObjectTexture [0,""Textures\m113a3_01.paa""]";
		};
	};

	case "M113_TK_EP1":{
		if (IS_chernarus_map_dependent) then {
			_vehicle setVehicleInit "this setObjectTexture [0,""Textures\m113a3_01.paa""]";
		};
	};

	case "Mi24_D_TK_EP1":{
		if !(IS_chernarus_map_dependent) then {
			_vehicle setVehicleInit "this setObjectTexture [0,""\ca\air2\mi35\data\mi24p_001_co.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [1,""\ca\air2\mi35\data\mi24p_002_co.paa""]";
		};
	
	};

	case "Mi24_V":{
		if !(IS_chernarus_map_dependent) then {
			_vehicle setVehicleInit "this setObjectTexture [0,""\Ca\Air_E\Data\mi35_001_IND_co.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [1,""\Ca\Air_E\Data\mi35_002_IND_co.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [2,""\Ca\Air_E\Data\mi35_mlod_IND_co.paa""]";
		};
 
	};

	case "Mi24_P":{
		if !(IS_chernarus_map_dependent) then {
			_vehicle setVehicleInit "this setObjectTexture [0,""\Ca\Air_E\Data\mi35_001_IND_co.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [1,""\Ca\Air_E\Data\mi35_002_IND_co.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [2,""\Ca\Air_E\Data\mi35_mlod_IND_co.paa""]";
		};

	};

	case "BTR60_TK_EP1":{
		if (IS_chernarus_map_dependent) then {
			_vehicle setVehicleInit "this setObjectTexture [0,""Textures\btr60_body_cw.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [1,""Textures\btr60_details_cw.paa""]";
		};

	};
	case "T34_TK_EP1":{
		if (IS_chernarus_map_dependent) then {
			_vehicle setVehicleInit "this setObjectTexture [0,""Textures\t34_body01_co.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [1,""Textures\t34_body02_co.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [2,""Textures\t34_turret_co.paa""]";
		};
	
	};

	case "T90":{
		if !(IS_chernarus_map_dependent) then {
			_vehicle setVehicleInit "this setObjectTexture [0,""Textures\t901_co_des.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [1,""Textures\t902_co_des.paa""]";
			_vehicle setVehicleInit "this setObjectTexture [2,""Textures\t903_co_des.paa""]";
		};
	};

	case "BVP1_TK_ACR": {
	    if (IS_chernarus_map_dependent) then {
	        _vehicle setVehicleInit "this setObjectTexture [0,""Textures\trup_ext0_co.paa""]";
	    };
	};

	//--- Salvage helicopters: amber tint to distinguish them from standard transport.
	//--- Note: A2 OA helicopters often ignore setObjectTexture on body selections;
	//--- apply best-effort and verify in-engine — selection 0 is the fuselage on most variants.
	//--- NEEDS-IN-ENGINE-VERIFY: confirm the tint is visible on Mi17_medevac_CDF.
	//--- Implementation note: we do NOT use setVehicleInit here because Common_CreateVehicle.sqf
	//--- calls setVehicleInit again (for Init_Unit.sqf) AFTER this function returns, which would
	//--- overwrite the texture command before processInitCommands sees it — killing JIP visibility.
	//--- Instead we store the texture command string on the vehicle; Common_CreateVehicle reads it
	//--- and appends it to the Init_Unit setVehicleInit so both run in one processInitCommands call.
	// Marty: WEST salvage heli (UH1H_EP1) removed - invalid class on live box; re-add with validated airframe (claude-inbox#2 item 1).
	case "Mi17_medevac_CDF": {
		_vehicle setVariable ["wfbe_pending_texture", "this setObjectTexture [0,'#(argb,8,8,3)color(0.8,0.5,0.0,0.5,ca)']"];
	};


	};

processinitcommands;
_vehicle