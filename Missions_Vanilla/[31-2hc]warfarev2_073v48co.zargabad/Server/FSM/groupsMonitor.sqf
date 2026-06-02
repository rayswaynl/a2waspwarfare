while {!gameOver} do {
    _totalUnits = 0;

	{
		_groupCount = count units _x;
        _totalUnits = _totalUnits + _groupCount;
		["DEBUG", Format ["groupsMonitor.sqf: Debug info [_groupCount] [%1]", _groupCount]] Call WFBE_CO_FNC_LogContent;
	} forEach allGroups;

    ["DEBUG", Format ["groupsMonitor.sqf: Total units in all groups: %1", _totalUnits]] Call WFBE_CO_FNC_LogContent;
	["DEBUG", Format ["groupsMonitor.sqf: Total groups monitored: %1", count allGroups]] Call WFBE_CO_FNC_LogContent;
	
	sleep 30;
};