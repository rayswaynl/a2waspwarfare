Private ['_boundariesXY'];
_boundariesXY = -1;

switch (toLower(worldName)) do {
    case 'chernarus': {_boundariesXY = 15360};
    case 'eden': {_boundariesXY = 12800};
    case 'isladuala': {_boundariesXY = 10240};
    case 'takistan': {_boundariesXY = 12800};
    case 'utes': {_boundariesXY = 5120};
    case 'tasmania2010': {_boundariesXY = 25360};
    case 'napf': {_boundariesXY = 20500};
    case 'lingor': {_boundariesXY = 10300};
    case 'smd_sahrani_a2': {_boundariesXY = 20480};
    case 'tavi': {_boundariesXY = 25600};
    case 'dingor': {_boundariesXY = 10300};
    case 'zargabad': {_boundariesXY = 6000}; //--- Tight box (6km) centred on the valley; clips the steep edge-hills. Paired with the centre override below.
};

//--- Zargabad is a central valley ringed by steep mountains. The default boundary centre is
//--- [size/2,size/2] (map-corner-derived), which would shift a tight box toward the SW; instead
//--- pin the box centre on the valley (~map centre) so a 6km box symmetrically excludes the
//--- exploitable hills on all sides. Adjust the size/centre after an in-engine recon pass.
if (toLower worldName == 'zargabad') then { missionNamespace setVariable ['WFBE_BOUNDARIES_CENTER', [4096, 4096]] };


if ((missionNamespace getVariable "WFBE_C_GAMEPLAY_BOUNDARIES_ENABLED") > 0) then {
	if (_boundariesXY == -1) then {
		missionNamespace setVariable ["WFBE_C_GAMEPLAY_BOUNDARIES_ENABLED", 0];
		if (local player) then {
			BoundariesIsOnMap = nil;
			BoundariesHandleOnMap = nil;
		};
		["INFORMATION", Format ["Init_Boundaries.sqf: There is no proper boundaries set for island [%1]", worldName]] Call WFBE_CO_FNC_LogContent;
	} else {
		missionNamespace setVariable ['WFBE_BOUNDARIESXY',_boundariesXY];
		["INFORMATION", Format ["Init_Boundaries.sqf: Boundaries [%1] found for island [%2]", _boundariesXY, worldName]] Call WFBE_CO_FNC_LogContent;
	};
} else {
	if (_boundariesXY == -1) then {
		["INFORMATION", Format ["Init_Boundaries.sqf: There is no proper boundaries set for island [%1]", worldName]] Call WFBE_CO_FNC_LogContent;
	} else {
		missionNamespace setVariable ['WFBE_BOUNDARIESXY',_boundariesXY];
		["INFORMATION", Format ["Init_Boundaries.sqf: Boundaries [%1] found for island [%2] {Boundaries parameter is disabled}", _boundariesXY, worldName]] Call WFBE_CO_FNC_LogContent;
	};
};