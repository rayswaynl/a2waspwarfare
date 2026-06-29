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
	if (isNil "WFBE_CLIENT_BLACKFADE_APPLIED") then { WFBE_CLIENT_BLACKFADE_APPLIED = true; 12452 cutText [(localize 'STR_WF_Loading')+"...","BLACK FADED",180]; }; //--- B65 Fix-2 (one-shot black-fade guard): a JIP state re-push must not re-darken an already-initialised client. missionNamespace global persists across re-runs in a session; re-arms on a genuine new mission. A2-OA-safe. Original note: //--- B56: was 50000s. Bounded so a stalled JIP init can never strand a client on permanent black; the Init_Client fade-clear still cuts it early on success.
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

//--- GUER PLAYERSIDE force (dedicated-MP): WFBE_C_GUER_PLAYERSIDE is the LAST mission param, so on a dedicated
//--- server the cached paramsArray can be stale/short for it (an out-of-range `select` -> nil -> 0), which makes
//--- the lobby value unreliable (esp. on a map that previously ran with fewer params). Re-read it from the param
//--- DEFAULT the build sets (1 live / 0 git gate-off) - same dedicated-MP override pattern as the economy block
//--- below; keeps the gate-off design working (git default stays 0).
WFBE_C_GUER_PLAYERSIDE = getNumber (missionConfigFile >> "Params" >> "WFBE_C_GUER_PLAYERSIDE" >> "default");

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

//--- STARTING ECONOMY (Ray B36.1): THIS block is the real dedicated-MP override - the Init_CommonConstants 12800/30000 fallbacks NEVER fire here (Init_Parameters sets them from paramsArray first). Was the AB-ample fast-feedback experiment (150000/80000); now Ray's lean values
//--- develop fast (AI never economy-stalls -> quick captures -> rapid metric feedback).
//--- Shared by BOTH arms (matched condition). Set WFBE_C_AB_AMPLE_ECON=0 to disable.
if ((missionNamespace getVariable ["WFBE_C_AB_AMPLE_ECON", 1]) > 0) then {
	missionNamespace setVariable ["WFBE_C_ECONOMY_FUNDS_START_WEST", 30000];
	missionNamespace setVariable ["WFBE_C_ECONOMY_FUNDS_START_EAST", 30000];
	missionNamespace setVariable ["WFBE_C_ECONOMY_SUPPLY_START_WEST", 12800];
	missionNamespace setVariable ["WFBE_C_ECONOMY_SUPPLY_START_EAST", 12800];
	diag_log "[WFBE (INIT)] STARTING ECON (Ray B36.1): funds=30000 supply=12800 per side - the REAL dedicated-MP override (Init_CommonConstants never fires here). AI-cmdr seed = flat 200k (Init_Server).";
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
		//--- Taviana Air War features (forced with the event; reliable on dedicated where lobby params can be stale):
		missionNamespace setVariable ["WFBE_C_TOWNS_CAPTURE_AIR_HEIGHT", 100]; //--- low-flying crewed aircraft (<=100m) drain town SV
		missionNamespace setVariable ["WFBE_C_TOWNS_CAPTURE_AI_AIR", 0];       //--- AI aircraft never capture; camps still need ground
		WFBE_C_AICOM_ASSAULT_REACH_FOOT = 4500;                                 //--- 2500->4500: foot teams can advance across the 25.6km Taviana map
		//--- Taviana Air War: make the AI commander BUY aircraft heavily (air share up, online earlier, higher caps):
		WFBE_C_AICOM_TYPE_MIX_EARLY = [0.35, 0.25, 0.20, 0.20]; //--- 1% -> 20% air from the opening
		WFBE_C_AICOM_TYPE_MIX_MID   = [0.25, 0.20, 0.20, 0.35]; //--- 5% -> 35% air mid
		WFBE_C_AICOM_TYPE_MIX_LATE  = [0.15, 0.15, 0.20, 0.50]; //--- 15% -> 50% air late
		WFBE_C_AICOM_TYPE_MIX_MATURE_MID  = 2;                  //--- reach MID tier at 2 towns
		WFBE_C_AICOM_TYPE_MIX_MATURE_LATE = 4;                  //--- reach LATE tier at 4 towns
		WFBE_C_AICOM_AIR_MIN_TOWNS = 1;                         //--- air online from town 1 (was 3)
		WFBE_C_AICOM_ATTACKHELI_MAX = 10;                       //--- raise live attack-heli cap (was 4)
		WFBE_C_AICOM_AIR_TIME_BIAS_MAXMULT = 4.0;               //--- stronger air time-bias
		WFBE_C_AICOM_AIR_TIME_BIAS_RAMP_MIN = 15;               //--- ramp to max air bias in 15 min
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

//--- B74.2.5 (Ray 2026-06-24, P0): PRIMITIVE ROSTER RECEIVER. Installed in Part I (BEFORE the B56 wfbe_teams
//--- wait and BEFORE Init_Client) so the server's on-connect publicVariableClient roster push is NEVER dropped
//--- for arriving before the consumer existed. The handler stores the side-keyed primitive payload into globals
//--- the vote menus read (WFBE_JIP_ROSTER_PRIMS = [[name,isPlayer,funds,gid],...], WFBE_JIP_ROSTER_COUNT). A
//--- one-shot poll below also re-reads the var in case the push landed before this EH installed (PV vars persist
//--- in missionNamespace, so a late-installed EH still sees the value). A2-OA-1.64-safe: typeName ==, count, no
//--- A3 commands. Side-keyed to the TWO sides that have a commander vote (WEST/EAST); GUER has no vote roster.
if (!isDedicated && !isHeadLessClient) then {
	WFBE_JIP_ROSTER_PRIMS = [];
	WFBE_JIP_ROSTER_COUNT = 0;
	private "_rosterKeys";
	_rosterKeys = ["WFBE_JIP_ROSTER_WEST", "WFBE_JIP_ROSTER_EAST"];
	{
		_x addPublicVariableEventHandler {
			private ["_payload"];
			_payload = _this select 1;
			if ((typeName _payload) == "ARRAY" && {(count _payload) >= 2} && {(typeName (_payload select 1)) == "ARRAY"}) then {
				WFBE_JIP_ROSTER_COUNT = _payload select 0;
				WFBE_JIP_ROSTER_PRIMS = _payload select 1;
				diag_log format ["CLIENTROSTER|RECV|key=%1|rows=%2|at=%3s", (_this select 0), count (_payload select 1), round time];
			};
		};
	} forEach _rosterKeys;
	//--- One-shot poll: a push that beat this EH still sits in missionNamespace under its key; adopt it once.
	[] spawn {
		private ["_n", "_v"];
		private "_rosterKeys";
		_rosterKeys = ["WFBE_JIP_ROSTER_WEST", "WFBE_JIP_ROSTER_EAST"];
		_n = 0;
		while {(count WFBE_JIP_ROSTER_PRIMS) == 0 && {_n < 150}} do {
			{
				_v = missionNamespace getVariable _x;
				if (!isNil "_v" && {(typeName _v) == "ARRAY"} && {(count _v) >= 2} && {(typeName (_v select 1)) == "ARRAY"} && {(count (_v select 1)) > 0}) exitWith {
					WFBE_JIP_ROSTER_COUNT = _v select 0;
					WFBE_JIP_ROSTER_PRIMS = _v select 1;
					diag_log format ["CLIENTROSTER|POLL-ADOPT|key=%1|rows=%2|at=%3s", _x, count (_v select 1), round time];
				};
			} forEach _rosterKeys;
			_n = _n + 1;
			uiSleep 0.5;
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

		// Ray 2026-06-24 (directive #2): PERMANENT DAYLIGHT. With the accelerated cycle OFF the engine clock still drifts toward night over a long round, so the server clamps daytime into the [START, END] band (08:00->17:00) and loops back to START. Server-authoritative; setDate replicates to all clients/HC. Disable with WFBE_C_ENVIRONMENT_DAYLIGHT_CLAMP=0.
		if (isServer && {(missionNamespace getVariable "WFBE_C_ENVIRONMENT_DAYLIGHT_CLAMP") == 1}) then {
			[] Spawn {
				private ["_loStart","_loEnd","_check"];
				_loStart = missionNamespace getVariable "WFBE_C_ENVIRONMENT_DAYLIGHT_START";
				_loEnd   = missionNamespace getVariable "WFBE_C_ENVIRONMENT_DAYLIGHT_END";
				_check   = missionNamespace getVariable "WFBE_C_ENVIRONMENT_DAYLIGHT_CHECK";
				if (isNil "_loStart") then {_loStart = 8};
				if (isNil "_loEnd") then {_loEnd = 17};
				if (isNil "_check") then {_check = 30};
				diag_log format ["DAYLIGHT| clamp armed band=%1->%2 check=%3s start_daytime=%4", _loStart, _loEnd, _check, (round (daytime * 100) / 100)];
				while {(missionNamespace getVariable "WFBE_C_ENVIRONMENT_DAYLIGHT_CLAMP") == 1} do {
					if (daytime >= _loEnd || daytime < _loStart) then {
						setDate [(date select 0),(date select 1),(date select 2),_loStart,0];
						diag_log format ["DAYLIGHT| looped to %1:00 (was daytime %2)", _loStart, (round (daytime * 100) / 100)];
					};
					sleep _check;
				};
			};
		};
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
	//--- B56 JIP-HANG FIX: these waits are gated on server-synced team data. On a JIP client, a present side whose logic
	//--- never resolves wfbe_teams (the harass-only GUER/resistance side - cf. upgradeQueue.sqf + the many
	//--- "WFBE_PRESENTSIDES - [resistance]" exclusions elsewhere) would block here FOREVER, so Init_Client below + its
	//--- black-fade clear never ran -> permanent black for every JIP joiner. Bounded uiSleep loops (real-time; they tick
	//--- on the paused loading screen, unlike sleep/waitUntil/time) so the client init is ALWAYS reached.
	private "_w"; _w = 0;
	while {(isNil "WFBE_PRESENTSIDES") && (_w < 80)} do { uiSleep 0.25; _w = _w + 1; };
	if (!isNil "WFBE_PRESENTSIDES") then {
		{
			private ["_logik","_ws"];
			_logik = (_x) Call WFBE_CO_FNC_GetSideLogic;
			_ws = 0;
			while {(isNil {_logik getVariable "wfbe_teams"}) && (_ws < 120)} do { uiSleep 0.25; _ws = _ws + 1; };
			if (!isNil {_logik getVariable "wfbe_teams"}) then {
				missionNamespace setVariable [Format["WFBE_%1TEAMS",_x], _logik getVariable "wfbe_teams"];
			} else {
				diag_log format ["[WFBE][B56 JIP-FIX] side %1 wfbe_teams not synced in time - proceeding without it so the client never hangs on black.", _x];
			};
		} forEach WFBE_PRESENTSIDES;
	} else {
		diag_log "[WFBE][B56 JIP-FIX] WFBE_PRESENTSIDES not set in time - proceeding to client init anyway.";
	};

	["INITIALIZATION", "initJIPCompatible.sqf: Executing the Client Initialization."] Call WFBE_CO_FNC_LogContent;
	execVM "Client\Init\Init_Client.sqf";
};

//--- Run the headless client initialization.
if (isHeadLessClient) then {
	execVM "Headless\Init\Init_HC.sqf";
};

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
