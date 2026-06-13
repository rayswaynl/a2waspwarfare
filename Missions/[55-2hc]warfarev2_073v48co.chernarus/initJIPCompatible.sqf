//--- Global Init, first file called.

//--- Define which 'part' of the game to run.
#include "version.sqf"

LOG_CONTENT_STATE = "";

//WF_LOG_CONTENT
#ifdef WF_LOG_CONTENT
	LOG_CONTENT_STATE = "ACTIVATED";
#else 
	LOG_CONTENT_STATE = "NOT ACTIVATED";
#endif

IS_naval_map = false;
#ifdef IS_NAVAL_MAP
	IS_naval_map = true; // if the map can support boats then global variable boolean is true.
#endif



startingDistance = STARTING_DISTANCE;

CBA_display_ingame_warnings = false;
publicVariable "CBA_display_ingame_warnings";
//--- Mission is starting.
for '_i' from 0 to 3 do {diag_log "################################"};
diag_log format ["## Island Name: [%1]", worldName];
diag_log format ["## Mission Name: [%1]", WF_MISSIONNAME];
diag_log "## Build: WASP Experital TEST (experimental feature branch)";
diag_log format ["## Starting Distance: [%1]", startingDistance];
diag_log format ["## Max players Defined: [%1]", WF_MAXPLAYERS];
diag_log format ["## LOG CONTENT : [%1]", LOG_CONTENT_STATE];
for '_i' from 0 to 3 do {diag_log "################################"};

townModeSet = false;

WFBE_CO_FNC_LogContent = Compile preprocessFileLineNumbers "Common\Functions\Common_LogContent.sqf"; //--- Define the log function earlier.
WFBE_LogLevel = 0; //--- Logging level (0: Trivial, 1: Information, 2: Warnnings, 3: Errors).

["INITIALIZATION", "initJIPCompatible.sqf: Starting JIP Initialization"] Call WFBE_CO_FNC_LogContent;

//--- Versioning (determine if some script can be run or not). Note that the script will throw an error which can be ignored on version < 1.62 (or vanilla).
ARMA_VERSION = 1;
ARMA_RELEASENUMBER = 0;

execVM "Common\Init\Init_Version.sqf";

//--- As we handle the error in the file scope, we wait for the returned value
waitUntil {!isNil 'VERSION_SET'};
VERSION_SET = nil;

isHostedServer = if (!isMultiplayer || (isServer && !isDedicated)) then {true} else {false};
isHeadLessClient = false;

//--- Headless Client?
isHeadLessClient = Call Compile preprocessFileLineNumbers "Headless\Functions\HC_IsHeadlessClient.sqf";
//--- Debug/logging support: HCs always log verbosely - an HC's RPT is its only observable
//--- channel, and the cost lands on the HC machine, never on players or the server.
if (isHeadLessClient) then {LOG_CONTENT_STATE = "ACTIVATED"};
if (isHeadLessClient) then {["INITIALIZATION", "initJIPCompatible.sqf: Detected an headless client."] Call WFBE_CO_FNC_LogContent};


//--- Server JIP Information
if ((isHostedServer || isDedicated) && !isHeadLessClient) then { //--- JIP Handler, handle connection & disconnection.
	WFBE_SE_FNC_OnPlayerConnected = Compile preprocessFileLineNumbers "Server\Functions\Server_OnPlayerConnected.sqf";
	WFBE_SE_FNC_OnPlayerDisconnected = Compile preprocessFileLineNumbers "Server\Functions\Server_OnPlayerDisconnected.sqf";

	onPlayerConnected {[_uid, _name, _id] Spawn WFBE_SE_FNC_OnPlayerConnected};
	onPlayerDisconnected {[_uid, _name, _id] Spawn WFBE_SE_FNC_OnPlayerDisconnected};
};

//--- Client initialization, either hosted or pure client. Part I
if (isHostedServer || (!isHeadLessClient && !isDedicated)) then {
	["INITIALIZATION", "initJIPCompatible.sqf: Client detected... waiting for non null result..."] Call WFBE_CO_FNC_LogContent;
	waitUntil {!isNull player};
	["INITIALIZATION", "initJIPCompatible.sqf: Client is not null..."] Call WFBE_CO_FNC_LogContent;
	//--- Client Init - Begin the blackout on Layer 12452.
	12452 cutText [(localize 'STR_WF_Loading')+"...","BLACK FADED",50000];
};

setViewDistance 3500; //--- Server & Client default View Distance.

clientInitComplete = false;
commonInitComplete = false;
serverInitComplete = false;
serverInitFull = false;
gameOver = false;
WFBE_GameOver = false;
townInitServer = false;
townInit = false;
modACE = false;
towns = [];

WF_A2_Vanilla = false;
#ifdef VANILLA
	WF_A2_Vanilla = true;
#endif

WF_A2_Arrowhead = false;
#ifdef ARROWHEAD
	WF_A2_Arrowhead = true;
#endif

WF_A2_CombinedOps = false;
#ifdef COMBINEDOPS
	WF_A2_CombinedOps = true;
#endif

WF_Debug = false;
#ifdef WF_DEBUG
	WF_Debug = true;
#endif

IS_chernarus_map_dependent = false;
#ifdef IS_CHERNARUS_MAP_DEPENDENT
	IS_chernarus_map_dependent = true; // if the map content depend on chernarus feature then global variable boolean is true.
#endif

IS_mod_map_dependent = false;
#ifdef IS_MOD_MAP_DEPENDENT
	IS_mod_map_dependent = true; // if the map content depend on modded vehicles then global variable boolean is true.
#endif

if (isMultiplayer) then {Call Compile preprocessFileLineNumbers "Common\Init\Init_Parameters.sqf"}; //--- In MP, we get the parameters.

Call Compile preprocessFileLineNumbers "Common\Init\Init_CommonConstants.sqf"; //--- Set the constants and the parameters, skip the params if they're already defined.

//--- AICOM: +50% starting economy. MUST live here: in MP Init_Parameters always sets these from paramsArray,
//--- so the isNil fallbacks in Init_CommonConstants never fire on a dedicated server (why earlier raises had no effect).
//--- Air-event/WF_Debug overrides below still take precedence. AI commander seed funds scale with this (FUNDS_START * 1.5 in Init_Server).
if (isMultiplayer) then {
	{
		Private "_v";
		_v = missionNamespace getVariable _x;
		if (!isNil "_v") then {missionNamespace setVariable [_x, round(_v * 1.5)]};
	} forEach ["WFBE_C_ECONOMY_FUNDS_START_WEST","WFBE_C_ECONOMY_FUNDS_START_EAST","WFBE_C_ECONOMY_SUPPLY_START_WEST","WFBE_C_ECONOMY_SUPPLY_START_EAST"];
	diag_log Format ["[WFBE (INIT)] EconomyBoost +50pct ACTIVE: fundsW=%1 fundsE=%2 supplyW=%3 supplyE=%4",
		missionNamespace getVariable "WFBE_C_ECONOMY_FUNDS_START_WEST",
		missionNamespace getVariable "WFBE_C_ECONOMY_FUNDS_START_EAST",
		missionNamespace getVariable "WFBE_C_ECONOMY_SUPPLY_START_WEST",
		missionNamespace getVariable "WFBE_C_ECONOMY_SUPPLY_START_EAST"];
};

//--- A/B EXPERIMENT (Steff 2026-06-13): ample starting economy so legacy-vs-next matches
//--- develop fast (AI never economy-stalls -> quick captures -> rapid metric feedback).
//--- Shared by BOTH arms (matched condition). Set WFBE_C_AB_AMPLE_ECON=0 to disable.
if ((missionNamespace getVariable ["WFBE_C_AB_AMPLE_ECON", 1]) > 0) then {
	missionNamespace setVariable ["WFBE_C_ECONOMY_FUNDS_START_WEST", 150000];
	missionNamespace setVariable ["WFBE_C_ECONOMY_FUNDS_START_EAST", 150000];
	missionNamespace setVariable ["WFBE_C_ECONOMY_SUPPLY_START_WEST", 80000];
	missionNamespace setVariable ["WFBE_C_ECONOMY_SUPPLY_START_EAST", 80000];
	diag_log "[WFBE (INIT)] AB-AMPLE-ECON ACTIVE: funds=150000 supply=80000 per side (fast-feedback test)";
};

IS_air_war_event = false;
_airEventEnabledFromParameters = missionNamespace getVariable "WFBE_AIR_EVENT_ENABLED";

switch (_airEventEnabledFromParameters) do {
	case 0: {
		#ifdef IS_AIR_WAR_EVENT
			IS_air_war_event = true;
		#endif
	};
	case 1: { 
		IS_air_war_event = false; 
	};
	case 2: { 
		IS_air_war_event = true; 
	};
};

if (IS_air_war_event) then {
	missionNamespace setVariable ["WFBE_C_ECONOMY_SUPPLY_START_EAST", 50000];
	missionNamespace setVariable ["WFBE_C_ECONOMY_SUPPLY_START_WEST", 50000];
	missionNamespace setVariable ["WFBE_C_ECONOMY_FUNDS_START_EAST", 13370000];
	missionNamespace setVariable ["WFBE_C_ECONOMY_FUNDS_START_WEST", 13370000];
	missionNamespace setVariable ["WFBE_C_TOWNS_STARTING_MODE", 1];
	missionNamespace setVariable ["WFBE_C_GAMEPLAY_UPGRADES_CLEARANCE", 7];
};

if (WF_Debug) then { //--- Debug.
	missionNamespace setVariable ["WFBE_C_GAMEPLAY_UPGRADES_CLEARANCE", 7];
	missionNamespace setVariable ["WFBE_C_TOWNS_OCCUPATION", 1];
	missionNamespace setVariable ["WFBE_C_TOWNS_DEFENDER", 2];
	missionNamespace setVariable ["WFBE_C_AI_DELEGATION", 2];
	missionNamespace setVariable ["WFBE_C_TOWNS_STARTING_MODE", 2];
	missionNamespace setVariable ["WFBE_C_ECONOMY_SUPPLY_START_EAST", 999999];
	missionNamespace setVariable ["WFBE_C_ECONOMY_SUPPLY_START_WEST", 999999];
	missionNamespace setVariable ["WFBE_C_ECONOMY_FUNDS_START_EAST", 999999];
	missionNamespace setVariable ["WFBE_C_ECONOMY_FUNDS_START_WEST", 999999];
	missionNamespace setVariable ["WFBE_C_MODULE_WFBE_EASA", 1];
};

//--- Disable headless client if it is not supported.
if (ARMA_VERSION >= 162 && ARMA_RELEASENUMBER >= 101334 || ARMA_VERSION > 162) then {
	["INITIALIZATION", "initJIPCompatible.sqf: Headless client is supported."] Call WFBE_CO_FNC_LogContent
} else {
	if ((missionNamespace getVariable "WFBE_C_AI_DELEGATION") == 2) then {
		missionNamespace setVariable ["WFBE_C_AI_DELEGATION", 0];
		["INITIALIZATION", "initJIPCompatible.sqf: Headless client is not supported."] Call WFBE_CO_FNC_LogContent
	};
};

// Marty: Receive authoritative day/night dates without calling setDate on every broadcast.
if (!isDedicated && ((missionNamespace getVariable "WFBE_DAYNIGHT_ENABLED") == 1)) then {
	"WFBE_DAYNIGHT_DATE" addPublicVariableEventHandler {
		Private ["_server_date"];

		_server_date = _this select 1;
		if ((typeName _server_date) == "ARRAY" && (count _server_date >= 5)) then {
			WFBE_DAYNIGHT_SERVER_DATE = _server_date;
			WFBE_DAYNIGHT_PENDING_SYNC = true;
		};
	};
};

//--- Apply the time-environment (don't halt).
[] Spawn {
	waitUntil {time > 0}; //--- Await for the mission to start / JIP.

	// Marty: Enabled cycle uses the server date for JIP; disabled cycle preserves the old mission-time skipTime sync.
	if ((missionNamespace getVariable "WFBE_DAYNIGHT_ENABLED") == 1) then {
		if (!isNil "WFBE_DAYNIGHT_DATE") then {
			setDate WFBE_DAYNIGHT_DATE;
		} else {
			// Marty: The accelerated cycle phase boundaries are calibrated for Chernarus on 28 June.
			setDate [(date select 0),(missionNamespace getVariable "WFBE_DAYNIGHT_FORCED_MONTH"),(missionNamespace getVariable "WFBE_DAYNIGHT_FORCED_DAY"),(missionNamespace getVariable "WFBE_C_ENVIRONMENT_STARTING_HOUR"),(date select 4)]; //--- Apply the date and time.
		};
	} else {
		setDate [(date select 0),(missionNamespace getVariable "WFBE_C_ENVIRONMENT_STARTING_MONTH"),(date select 2),(missionNamespace getVariable "WFBE_C_ENVIRONMENT_STARTING_HOUR"),(date select 4)]; //--- Apply the date and time.

		if (local player) then {skipTime (time / 3600)}; //--- If we're dealing with a client, he may have JIP half way through the game. Sync him via skipTime with the mission time.
	};
	sleep 2;
};

// Marty: Remote clients animate day/night locally with small skipTime steps and only use server dates for drift correction.
if (!isDedicated && !isServer && !isHeadLessClient && ((missionNamespace getVariable "WFBE_DAYNIGHT_ENABLED") == 1)) then {
	[] execVM "Client\Functions\Client_DayNightCycle.sqf";
};

WFBE_Parameters_Ready = true; //--- All parameters are set and ready.

ExecVM "Common\Init\Init_Common.sqf"; //--- Execute the common files.
ExecVM "Common\Init\Init_Towns.sqf"; //--- Execute the towns file.

//--- Server initialization.
if (isHostedServer || isDedicated) then { //--- Run the server's part.
	["INITIALIZATION", "initJIPCompatible.sqf: Executing the Server Initialization."] Call WFBE_CO_FNC_LogContent;
	ExecVM "Server\Init\Init_Server.sqf";
};

//--- Client initialization, either hosted or pure client. Part II
if (isHostedServer || (!isHeadLessClient && !isDedicated)) then {
	waitUntil {!isNil 'WFBE_PRESENTSIDES'}; //--- Await for teams to be set before processing the client init.
	{
		_logik = (_x) Call WFBE_CO_FNC_GetSideLogic;
		waitUntil {!isNil {_logik getVariable "wfbe_teams"}};
		missionNamespace setVariable [Format["WFBE_%1TEAMS",_x], _logik getVariable "wfbe_teams"];
	} forEach WFBE_PRESENTSIDES;

	["INITIALIZATION", "initJIPCompatible.sqf: Executing the Client Initialization."] Call WFBE_CO_FNC_LogContent;
	execVM "Client\Init\Init_Client.sqf";
};

//--- Run the headless client initialization.
if (isHeadLessClient) then {
	execVM "Headless\Init\Init_HC.sqf";
};

/* Marty : old wasp script using resources unecessarely. Will be removed after some days if its ok.
//// Wasp part
WASP_procInitComm=Compile PreprocessFile "WASP\common\procInitComm.sqf";
if(local player)then{ExecVM "WASP\Init_Client.sqf"};
*/

/* Marty : Creation of global variable than can be used everywhere to determine the faction on the map. */
// If the map running is chernarus then east faction must be russian and NOT takistanish (useful to customize audio sounds and so on). West faction is always american whatever the map :
IS_Takistan_Faction_On_This_Map = false;
IS_Russian_Faction_On_This_Map  = false;
IS_American_Faction_on_this_map = false; 

// If map is chernarus dependent :
if (IS_chernarus_map_dependent) then 
{
	IS_Russian_Faction_On_This_Map = true  ;
	IS_Takistan_Faction_On_This_Map = false;
	IS_American_Faction_on_this_map = true ; // for west side it is always american faction on every maps.
};

// If map is takistant dependent (= not chernarus dependant) :
if !(IS_chernarus_map_dependent) then  
{
	IS_Russian_Faction_On_This_Map  = false;
	IS_Takistan_Faction_On_This_Map = true ;
	IS_American_Faction_on_this_map = true ; // for west side it is always american faction on every maps.
};
