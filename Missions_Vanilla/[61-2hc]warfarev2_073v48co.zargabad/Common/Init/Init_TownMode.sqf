Private ['_towns','_value','_wParameters'];

if (isNil "WFBE_Parameters_Ready") then {
	WFBE_Parameters_Ready = false;
};

//--- J6 HANGGUARD: missing parameter readiness must not freeze town-mode setup forever.
_wParameters = 0;
while {(!WFBE_Parameters_Ready) && (_wParameters < 240)} do { uiSleep 0.25; _wParameters = _wParameters + 1; };
if (!WFBE_Parameters_Ready) then {
	diag_log "[WFBE (INIT)] HANGGUARD| Init_TownMode.sqf: parameters were not ready after 60s - proceeding with town-mode setup.";
};

TownTemplate = [];
switch (missionNamespace getVariable "WFBE_C_TOWNS_AMOUNT") do {
	case 0: {TownTemplate = WF_Logic getVariable "Towns_RemovedXSmall"};
	case 1: {TownTemplate = WF_Logic getVariable "Towns_RemovedSmall"};
	case 2: {TownTemplate = WF_Logic getVariable "Towns_RemovedMedium"};
	case 3: {TownTemplate = WF_Logic getVariable "Towns_RemovedLarge"};
	case 5: {TownTemplate = WF_Logic getVariable "Towns_RemovedBigTowns"};
	case 6: {TownTemplate = WF_Logic getVariable "Towns_RemovedCentralLine"};
	case 7: {TownTemplate = WF_Logic getVariable "Towns_RemovedSmallTowns"};
};

if (isNil "TownTemplate") then {TownTemplate = []};//--- The field is not defined, we use the default island setting.

_towns = [7000,7500,0] nearEntities [["LocationLogicDepot"], 30000];
totalTowns = (count _towns) - (count TownTemplate);

townModeSet = true;

["INITIALIZATION", Format["Init_TownMode.sqf: Towns mode initialization is done for island [%1].",worldName]] Call WFBE_CO_FNC_LogContent;
