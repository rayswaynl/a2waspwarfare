/* Client_SpectatorDirector.sqf
   WASP Spectator v8 DEFINITIVE auto-director (owner mandate 2026-08-01; Codex council design).
   AUTO candidates are TOWNS and PERSISTENT FIGHT TRACKS ONLY - a fight is an integer track id,
   never a unit. ACTION comes from server-forwarded Fired/Killed events (Common_SpectatorEventFeed.sqf
   -> WFBE_SPECTATOR_EVENTS), never from proximity. The 1s poll here owns SCORING and the SHOT
   SNAPSHOT (WFBE_C_VAR_SpectShot); Client_SpectatorAimFrame.sqf is the only camera writer and
   consumes the snapshot at render rate. Polls update scoring - they never drag the live camera.
   Deleted from v3-v7 (Codex list): auto PLAYER/TEAM/GUER/HQ/base candidates (builders kept for
   manual N/B), proximity contact scoring + 1000-weights, anchor-unit identity, centroid-as-aim,
   moving-unit look-ahead, the 120s establish interpretation, ALL scheduled camera writes.
   No Display references, no serialization directive, A2-OA-1.64 commands only.
*/

WFBE_CL_FNC_DirectorPosObject = {
	getPos _this
};

WFBE_CL_FNC_DirectorContactCount = {
	//--- MANUAL-MODE helper only (N/B pools); the AUTO director never scores by proximity.
	Private ["_origin","_radius","_originSide","_count","_unitSide"];
	_origin = _this select 0;
	_radius = _this select 1;
	_originSide = _this select 2;
	_count = 0;
	{
		if (!isNull _x && {alive _x} && {!(captive _x)} && {(count (weapons _x)) > 0} && {(side _x) in [west, east, resistance]}) then {
			_unitSide = side _x;
			if (_unitSide != _originSide) then {_count = _count + 1};
		};
	} forEach (_origin nearEntities [["Man"], _radius]);
	_count
};

WFBE_CL_FNC_DirectorPollTowns = {
	Private ["_oldData","_newData","_radius","_town","_units","_sides","_headcount","_unitSide","_current","_oldValue","_delta","_entry","_contact","_hot","_hotSet","_hotIdx","_hotFound","_linger"];
	_oldData = missionNamespace getVariable ["WFBE_C_VAR_DirectorTownData", []];
	_newData = [];
	_radius = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_TOWN_CONTEST_RADIUS", 200];
	_linger = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_TOWN_LINGER_SEC", 45];
	_hotSet = missionNamespace getVariable ["WFBE_C_VAR_DirectorTownHot", []];
	{
		_town = _x;
		_units = _town nearEntities [["Man"], _radius];
		_sides = [];
		_headcount = 0;
		{
			if (!isNull _x && {alive _x}) then {
				_unitSide = side _x;
				//--- belligerents only - a parked CIV caster body or neutral crew must not fake a contest.
				if (_unitSide in [west, east, resistance]) then {
					_headcount = _headcount + 1;
					if !(_unitSide in _sides) then {_sides = _sides + [_unitSide]};
				};
			};
		} forEach _units;
		_current = _town getVariable ["supplyValue", 0];
		_oldValue = _current;
		{
			_entry = _x;
			if ((_entry select 0) == _town) then {_oldValue = _entry select 1};
		} forEach _oldData;
		_delta = _current - _oldValue;
		_contact = ((count _sides) - 1) max 0;
		if (_contact > 0) then {
			_hotFound = false;
			_hotIdx = 0;
			{
				if (!isNil "_x") then {
					if ((_x select 0) == _town) then {_hotSet set [_hotIdx, [_town, time]]; _hotFound = true};
				};
				_hotIdx = _hotIdx + 1;
			} forEach _hotSet;
			if (!_hotFound) then {
				_hotSet = _hotSet + [[_town, time]];
			};
		};
		_hot = (_contact > 0);
		if (!_hot) then {
			{
				if (!isNil "_x") then {
					if ((_x select 0) == _town && {(time - (_x select 1)) < _linger}) then {_hot = true};
				};
			} forEach _hotSet;
		};
		_newData = _newData + [[_town, _current, _delta, count _sides, _headcount, _contact, _hot]];
	} forEach towns;
	WFBE_C_VAR_DirectorTownData = _newData;
	WFBE_C_VAR_DirectorTownHot = _hotSet;
	_newData
};

//--- MANUAL N/B pools (kept per owner ruling: unit follow lives ONLY behind manual keys).
WFBE_CL_FNC_DirectorBuildPlayers = {
	Private ["_list"];
	_list = [];
	{
		if (!isNil "_x") then {
			if (alive _x && {isPlayer _x} && {(side _x) != civilian} && {!(_x == player)} && {!((name _x) in (missionNamespace getVariable ["WFBE_C_HC_NAMES", []]))}) then {
				_list = _list + [[name _x, _x, "PLAYER", WFBE_CL_FNC_DirectorPosObject, 0, 0]];
			};
			if (alive _x && {!(isPlayer _x)} && {_x == (leader (group _x))} && {(side _x) != civilian} && {(count (weapons _x)) > 0} && {!((name _x) in (missionNamespace getVariable ["WFBE_C_HC_NAMES", []]))}) then {
				if ((side _x) == resistance) then {
					_list = _list + [[Format ["GUER squad (%1)", {alive _x} count (units (group _x))], _x, "GUER", WFBE_CL_FNC_DirectorPosObject, 0, 0]];
				} else {
					_list = _list + [[Format ["%1 squad (%2)", side _x, {alive _x} count (units (group _x))], _x, "TEAM", WFBE_CL_FNC_DirectorPosObject, 0, 0]];
				};
			};
		};
	} forEach allUnits;
	_list
};

WFBE_CL_FNC_DirectorBuildTeams = {
	Private ["_list","_feed","_entry","_leader","_sid","_grp","_alive","_label"];
	_list = [];
	_feed = missionNamespace getVariable ["WFBE_ACTIVE_AICOM_TEAMS", []];
	{
		_entry = _x;
		if (typeName _entry == "ARRAY" && {count _entry >= 4}) then {
			_leader = _entry select 0;
			_sid = _entry select 1;
			_grp = _entry select 3;
			if (typeName _grp == "GROUP") then {
				_leader = leader _grp;
				if (!isNull _leader && {alive _leader}) then {
					_alive = ({alive _x} count units _grp);
					_label = Format ["TEAM %1 (%2)", _sid, _alive];
					_list = _list + [[_label, _leader, "TEAM", WFBE_CL_FNC_DirectorPosObject, 0, 0]];
				};
			};
		};
	} forEach _feed;
	_list
};

WFBE_CL_FNC_DirectorBuildTowns = {
	Private ["_list","_data","_town","_headcount","_label"];
	_data = missionNamespace getVariable ["WFBE_C_VAR_DirectorTownData", []];
	if (count _data == 0) then {_data = Call WFBE_CL_FNC_DirectorPollTowns};
	_list = [];
	{
		_town = _x select 0;
		_headcount = _x select 4;
		_label = _town getVariable ["name", "Town"];
		_list = _list + [[_label, _town, "TOWN", WFBE_CL_FNC_DirectorPosObject, _headcount, _x select 5]];
	} forEach _data;
	_list
};

WFBE_CL_FNC_DirectorBuildHQs = {
	Private ["_list","_sides","_side","_reveal","_hq","_label"];
	_list = [];
	_sides = [west, east, resistance];
	_reveal = (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_REVEAL_ENEMY_HQ", 0]) > 0;
	{
		_side = _x;
		if (_reveal || {_side == side player}) then {
			_hq = _side Call WFBE_CO_FNC_GetSideHQ;
			if (!isNull _hq) then {
				_label = switch (_side) do {case west: {"WEST HQ"}; case east: {"EAST HQ"}; default {"GUER HQ"}};
				_list = _list + [[_label, _hq, "HQ", WFBE_CL_FNC_DirectorPosObject, 0, 0]];
			};
		};
	} forEach _sides;
	_list
};

WFBE_CL_FNC_DirectorBuildActive = {
	Private ["_class"];
	_class = missionNamespace getVariable ["WFBE_C_VAR_SpectatorDirectorClass", "PLAYER"];
	switch (_class) do {
		case "TEAM": {Call WFBE_CL_FNC_DirectorBuildTeams};
		case "TOWN": {Call WFBE_CL_FNC_DirectorBuildTowns};
		case "HQ": {Call WFBE_CL_FNC_DirectorBuildHQs};
		default {Call WFBE_CL_FNC_DirectorBuildPlayers};
	}
};

//--- Deadspawn pen/park exclusion points (owner ruling: nothing within 200m of the pens may
//--- enter the candidate pool). Per-side AI pens sit at the shared pen +sideID*200m on X
//--- (Server\AI\AI_AdvancedRespawn.sqf:45); the player deadspawn park is the base point itself.
WFBE_CL_FNC_DirectorPenPoints = {
	Private ["_pts","_base","_i"];
	_pts = missionNamespace getVariable ["WFBE_C_VAR_DirPenPts", []];
	if ((count _pts) > 0) exitWith {_pts};
	_base = [];
	if (!isNil "WFBE_CO_FNC_DeadspawnPenPos") then {_base = [] Call WFBE_CO_FNC_DeadspawnPenPos};
	if ((typeName _base) != "ARRAY" || {(count _base) < 2}) exitWith {[]};
	_pts = [];
	_i = 0;
	while {_i < 3} do {
		_pts = _pts + [[(_base select 0) + (_i * 200), _base select 1]];
		_i = _i + 1;
	};
	WFBE_C_VAR_DirPenPts = _pts;
	_pts
};

WFBE_CL_FNC_DirectorNearestTownName = {
	Private ["_px","_py","_best","_bestD","_tp","_d"];
	_px = _this select 0;
	_py = _this select 1;
	_best = "the front";
	_bestD = 1e9;
	{
		if (!isNull _x) then {
			_tp = getPos _x;
			_d = (((_tp select 0) - _px) ^ 2) + (((_tp select 1) - _py) ^ 2);
			if (_d < _bestD) then {_bestD = _d; _best = _x getVariable ["name", "the front"]};
		};
	} forEach towns;
	_best
};

/* Track registry: WFBE_C_VAR_DirTracks - one entry per persistent fight track:
   [0 id, 1 cx, 2 cy, 3 radius, 4 members, 5 wN, 6 eN, 7 gN, 8 armedN, 9 movingN,
    10 lastSeen(time), 11 lastFire(time), 12 lastKill(time), 13 evF, 14 evK, 15 score, 16 sidesN]
   evF/evK entries: [birthTick(diag_tickTime domain), x, y].
   Reconcile every 1s poll: same-side member overlap >= 25 percent first, else centroid distance
   <= max(100, oldR+newR+50). Split/merge keeps the strongest-overlap old id; a new id only when
   nothing matches. THIS is what kills camera-pans-away - locks and dwell survive re-forms. */
WFBE_CL_FNC_DirectorTracksUpdate = {
	Private ["_penPts","_penR2","_link","_hcNames","_clusters","_u","_pos","_px","_py","_sideIdx","_best","_bestD","_c","_cx","_cy","_d","_i","_n","_penOk","_pp","_members","_radius","_mx","_my","_moving","_tracks","_pairs","_mOld","_mNew","_shared","_ov","_ci","_ti","_usedC","_usedT","_bestOv","_bestPair","_pair","_newTracks","_cl","_tr","_newR","_oldR","_ttl","_nid","_movingN","_mm"];
	_penPts = Call WFBE_CL_FNC_DirectorPenPoints;
	_penR2 = (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_PEN_EXCLUDE_M", 200]) ^ 2;
	_link = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_CLUSTER_LINK_M", 300];
	_hcNames = missionNamespace getVariable ["WFBE_C_HC_NAMES", []];
	_clusters = []; //--- per cluster: [sumX, sumY, n, wN, eN, gN, memberObjs]
	{
		if (!isNil "_x") then {
			_u = _x; //--- capture before the inner forEach rebinds _x (A2-OA gotcha)
			if (alive _u && {!(captive _u)} && {(side _u) in [west, east, resistance]} && {(count (weapons _u)) > 0} && {!((name _u) in _hcNames)}) then {
				_pos = getPos _u;
				_px = _pos select 0;
				_py = _pos select 1;
				//--- pen/park eligibility gate (owner): parked bodies must not fabricate fights.
				_penOk = true;
				{
					_pp = _x;
					if (((( _pp select 0) - _px) ^ 2) + (((_pp select 1) - _py) ^ 2) < _penR2) then {_penOk = false};
				} forEach _penPts;
				if (_penOk) then {
					_sideIdx = 2;
					if ((side _u) == west) then {_sideIdx = 0};
					if ((side _u) == east) then {_sideIdx = 1};
					_best = -1;
					_bestD = _link;
					_i = 0;
					{
						_cx = (_x select 0) / ((_x select 2) max 1);
						_cy = (_x select 1) / ((_x select 2) max 1);
						_d = sqrt (((_px - _cx) ^ 2) + ((_py - _cy) ^ 2));
						if (_d < _bestD) then {_bestD = _d; _best = _i};
						_i = _i + 1;
					} forEach _clusters;
					if (_best < 0) then {
						_c = [_px, _py, 1, 0, 0, 0, [_u]];
						_c set [3 + _sideIdx, 1];
						_clusters = _clusters + [_c];
					} else {
						_c = _clusters select _best;
						_c set [0, (_c select 0) + _px];
						_c set [1, (_c select 1) + _py];
						_c set [2, (_c select 2) + 1];
						_c set [3 + _sideIdx, (_c select (3 + _sideIdx)) + 1];
						_c set [6, (_c select 6) + [_u]];
					};
				};
			};
		};
	} forEach allUnits;
	//--- finalize cluster geometry: [cx, cy, radius, members, wN, eN, gN, movingN]
	Private ["_fin"];
	_fin = [];
	{
		_c = _x;
		_n = _c select 2;
		_cx = (_c select 0) / (_n max 1);
		_cy = (_c select 1) / (_n max 1);
		_members = _c select 6;
		_radius = 0;
		_movingN = 0;
		{
			if (!isNull _x && {alive _x}) then {
				_pos = getPos _x;
				_mx = _pos select 0;
				_my = _pos select 1;
				_d = sqrt (((_mx - _cx) ^ 2) + ((_my - _cy) ^ 2));
				if (_d > _radius) then {_radius = _d};
				if ((speed _x) > 3) then {_movingN = _movingN + 1};
			};
		} forEach _members;
		_fin = _fin + [[_cx, _cy, _radius, _members, _c select 3, _c select 4, _c select 5, _movingN]];
	} forEach _clusters;
	//--- reconcile against the persistent registry.
	_tracks = missionNamespace getVariable ["WFBE_C_VAR_DirTracks", []];
	_pairs = [];
	_ci = 0;
	{
		_cl = _x;
		_mNew = _cl select 3;
		_ti = 0;
		{
			_tr = _x;
			_mOld = _tr select 4;
			_shared = 0;
			{
				_mm = _x;
				if (!isNull _mm && {_mm in _mOld}) then {_shared = _shared + 1};
			} forEach _mNew;
			_ov = _shared / (((count _mOld) min (count _mNew)) max 1);
			if (_ov >= (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_TRACK_MATCH_OVERLAP", 0.25])) then {
				_pairs = _pairs + [[_ov, _ci, _ti]];
			};
			_ti = _ti + 1;
		} forEach _tracks;
		_ci = _ci + 1;
	} forEach _fin;
	//--- greedy strongest-overlap assignment (no A3 sort on 1.64; pair counts are tiny).
	_usedC = [];
	_usedT = [];
	Private ["_matchC","_matchT","_go"];
	_matchC = []; //--- parallel arrays: cluster idx -> track idx
	_matchT = [];
	_go = true;
	while {_go} do {
		_bestOv = -1;
		_bestPair = [];
		{
			_pair = _x;
			if (!((_pair select 1) in _usedC) && {!((_pair select 2) in _usedT)} && {(_pair select 0) > _bestOv}) then {
				_bestOv = _pair select 0;
				_bestPair = _pair;
			};
		} forEach _pairs;
		if ((count _bestPair) == 0) then {
			_go = false;
		} else {
			_usedC = _usedC + [_bestPair select 1];
			_usedT = _usedT + [_bestPair select 2];
			_matchC = _matchC + [_bestPair select 1];
			_matchT = _matchT + [_bestPair select 2];
		};
	};
	//--- centroid fallback for unmatched clusters: distance <= max(100, oldR+newR+50), nearest wins.
	_ci = 0;
	{
		_cl = _x;
		if (!(_ci in _usedC)) then {
			_best = -1;
			_bestD = 1e9;
			_ti = 0;
			{
				_tr = _x;
				if (!(_ti in _usedT)) then {
					_oldR = _tr select 3;
					_newR = _cl select 2;
					_d = sqrt ((((_cl select 0) - (_tr select 1)) ^ 2) + (((_cl select 1) - (_tr select 2)) ^ 2));
					if (_d <= (((_oldR + _newR + 50) max 100)) && {_d < _bestD}) then {_bestD = _d; _best = _ti};
				};
				_ti = _ti + 1;
			} forEach _tracks;
			if (_best >= 0) then {
				_usedC = _usedC + [_ci];
				_usedT = _usedT + [_best];
				_matchC = _matchC + [_ci];
				_matchT = _matchT + [_best];
			};
		};
		_ci = _ci + 1;
	} forEach _fin;
	//--- build the new registry (copy-on-write; whole-variable assign at the end).
	_newTracks = [];
	_i = 0;
	{
		_cl = _x;
		_ti = -1;
		Private ["_mi"];
		_mi = 0;
		{
			if (_x == _i) then {_ti = _matchT select _mi};
			_mi = _mi + 1;
		} forEach _matchC;
		if (_ti >= 0) then {
			_tr = _tracks select _ti;
			_newTracks = _newTracks + [[_tr select 0, _cl select 0, _cl select 1, _cl select 2, _cl select 3, _cl select 4, _cl select 5, _cl select 6, count (_cl select 3), _cl select 7, time, _tr select 11, _tr select 12, _tr select 13, _tr select 14, 0, 0]];
		} else {
			_nid = missionNamespace getVariable ["WFBE_C_VAR_DirTrackNextId", 1];
			WFBE_C_VAR_DirTrackNextId = _nid + 1;
			_newTracks = _newTracks + [[_nid, _cl select 0, _cl select 1, _cl select 2, _cl select 3, _cl select 4, _cl select 5, _cl select 6, count (_cl select 3), _cl select 7, time, -999, -999, [], [], 0, 0]];
		};
		_i = _i + 1;
	} forEach _fin;
	//--- unmatched old tracks age out on TRACK_TTL, so a pausing fight keeps its identity.
	_ttl = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_TRACK_TTL_SEC", 15];
	_ti = 0;
	{
		_tr = _x;
		if (!(_ti in _usedT) && {(time - (_tr select 10)) < _ttl}) then {
			_newTracks = _newTracks + [_tr];
		};
		_ti = _ti + 1;
	} forEach _tracks;
	WFBE_C_VAR_DirTracks = _newTracks;
	_newTracks
};

//--- Consume the server event feed (seq-guarded, consume-once) and assign each fresh event to
//--- the nearest track (within radius+150m) else the nearest town (within 250m); else drop.
WFBE_CL_FNC_DirectorEvConsume = {
	Private ["_pkt","_seq","_srvNow","_arr","_arrTick","_ev","_age0","_birth","_ex","_ey","_kind","_tracks","_best","_bestD","_ti","_tr","_d","_evArr","_tApprox","_townReg","_bt","_bd","_town","_te","_found","_idx"];
	_pkt = missionNamespace getVariable ["WFBE_CL_SpectEvPkt", []];
	if ((typeName _pkt) != "ARRAY" || {(count _pkt) < 3}) exitWith {};
	_seq = _pkt select 0;
	if (_seq == (missionNamespace getVariable ["WFBE_C_VAR_DirEvSeq", -1])) exitWith {};
	WFBE_C_VAR_DirEvSeq = _seq;
	_srvNow = _pkt select 1;
	_arr = _pkt select 2;
	_arrTick = missionNamespace getVariable ["WFBE_CL_SpectEvPktTick", diag_tickTime];
	_tracks = missionNamespace getVariable ["WFBE_C_VAR_DirTracks", []];
	_townReg = missionNamespace getVariable ["WFBE_C_VAR_DirTownEv", []];
	{
		_ev = _x;
		if ((typeName _ev) == "ARRAY" && {(count _ev) >= 5}) then {
			_age0 = (_srvNow - (_ev select 0)) max 0;
			_birth = _arrTick - _age0;
			if ((diag_tickTime - _birth) <= 10) then {
				_ex = _ev select 1;
				_ey = _ev select 2;
				_kind = _ev select 4;
				_tApprox = time - (diag_tickTime - _birth);
				_best = -1;
				_bestD = 1e9;
				_ti = 0;
				{
					_tr = _x;
					_d = sqrt ((((_tr select 1) - _ex) ^ 2) + (((_tr select 2) - _ey) ^ 2));
					if (_d <= ((_tr select 3) + (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_EV_ASSIGN_TRACK_M", 150])) && {_d < _bestD}) then {_bestD = _d; _best = _ti};
					_ti = _ti + 1;
				} forEach _tracks;
				if (_best >= 0) then {
					_tr = _tracks select _best;
					if (_kind == 1) then {
						_evArr = _tr select 14;
						_tr set [14, _evArr + [[_birth, _ex, _ey]]];
						_tr set [12, _tApprox];
					} else {
						_evArr = _tr select 13;
						_tr set [13, _evArr + [[_birth, _ex, _ey]]];
						_tr set [11, _tApprox];
					};
				} else {
					//--- nearest town fallback (arty strikes, one-sided raids still watchable).
					_bt = objNull;
					_bd = 1e9;
					{
						if (!isNull _x) then {
							_d = sqrt ((((getPos _x) select 0) - _ex) ^ 2 + ((((getPos _x) select 1) - _ey) ^ 2));
							if (_d <= (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_EV_ASSIGN_TOWN_M", 250]) && {_d < _bd}) then {_bd = _d; _bt = _x};
						};
					} forEach towns;
					if (!isNull _bt) then {
						_found = false;
						_idx = 0;
						{
							_te = _x;
							if ((_te select 0) == _bt) then {
								if (_kind == 1) then {
									_te set [2, (_te select 2) + [[_birth, _ex, _ey]]];
									_te set [4, _tApprox];
								} else {
									_te set [1, (_te select 1) + [[_birth, _ex, _ey]]];
									_te set [3, _tApprox];
								};
								_found = true;
							};
							_idx = _idx + 1;
						} forEach _townReg;
						if (!_found) then {
							if (_kind == 1) then {
								_townReg = _townReg + [[_bt, [], [[_birth, _ex, _ey]], -999, _tApprox]];
							} else {
								_townReg = _townReg + [[_bt, [[_birth, _ex, _ey]], [], _tApprox, -999]];
							};
						};
					};
				};
			};
		};
	} forEach _arr;
	WFBE_C_VAR_DirTownEv = _townReg;
};

//--- Weighted event terms per the binding spec: Fired 1.0 (<=2s) / 0.5 (2-5s) cap 3;
//--- Killed 1.0 (<=3s) / 0.5 (3-10s) cap 2. _this = [evF, evK]; returns [F, K, prunedF, prunedK].
WFBE_CL_FNC_DirectorEvTerms = {
	Private ["_evF","_evK","_f","_k","_pf","_pk","_age","_nowTick"];
	_evF = _this select 0;
	_evK = _this select 1;
	_nowTick = diag_tickTime;
	_f = 0;
	_k = 0;
	_pf = [];
	_pk = [];
	{
		if (!isNil "_x") then {
			_age = _nowTick - (_x select 0);
			if (_age <= 10) then {
				_pf = _pf + [_x];
				if (_age <= 2) then {_f = _f + 1} else {
					if (_age <= 5) then {_f = _f + 0.5};
				};
			};
		};
	} forEach _evF;
	{
		if (!isNil "_x") then {
			_age = _nowTick - (_x select 0);
			if (_age <= 10) then {
				_pk = _pk + [_x];
				if (_age <= 3) then {_k = _k + 1} else {_k = _k + 0.5};
			};
		};
	} forEach _evK;
	if (_f > 3) then {_f = 3};
	if (_k > 2) then {_k = 2};
	[_f, _k, _pf, _pk]
};

//--- Stamp the SHOT SNAPSHOT (the only channel from the poll to the camera).
//--- _this = [kind, key, centerXY, aimXYZ, radiusM(track spread), label, sidesText, score, samePoi,
//---          allowPreloadWait]
//--- allowPreloadWait (optional, default false) is passed ONLY by the AUTO poll path - it permits
//--- the bounded preload suspension below. Never pass it from an unscheduled caller (key handlers):
//--- waitUntil outside a scheduled script is an engine error.
WFBE_CL_FNC_DirectorStamp = {
	Private ["_kind","_key","_cxy","_aim","_spread","_label","_sidesText","_score","_same","_compact","_stand","_hgt","_fov","_odir","_osw","_base","_shotType","_reason","_cutId","_oldShot","_ring","_pref","_ost","_prog","_allowWait","_pcam","_pcap","_pt0","_pwait"];
	_kind = _this select 0;
	_key = _this select 1;
	_cxy = _this select 2;
	_aim = _this select 3;
	_spread = _this select 4;
	_label = _this select 5;
	_sidesText = _this select 6;
	_score = _this select 7;
	_same = _this select 8;
	_allowWait = false;
	if ((count _this) > 9) then {_allowWait = _this select 9};
	_compact = (_spread < (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_FIGHT_COMPACT_M", 120]));
	_shotType = "MEDIUM";
	_reason = "CONTACT";
	if (_kind == "FIGHT" && {_compact}) then {
		//--- zoom tight only when the track is compact (<120m) - never TIGHT a spread battle.
		_stand = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_FIGHT_STAND_M", 70];
		_hgt = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_FIGHT_STAND_H", 30];
		_fov = ((missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_TIGHT_FOV_MIN", 0.12]) + (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_TIGHT_FOV_MAX", 0.2])) / 2;
		_shotType = "TIGHT";
	} else {
		_stand = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_WIDE_RADIUS", 180];
		_hgt = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_WIDE_HEIGHT", 110];
		_fov = ((missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_MEDIUM_FOV_MIN", 0.28]) + (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_MEDIUM_FOV_MAX", 0.4])) / 2;
	};
	if (_kind == "GLANCE") then {
		_fov = ((missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_WIDE_FOV_MIN", 0.8]) + (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_WIDE_FOV_MAX", 0.95])) / 2;
		_shotType = "WIDE";
		_reason = "GLANCE";
	};
	if (_kind == "MANUAL") then {_reason = "MANUAL"};
	//--- ORBIT = reveal only: after 3s static, 6 deg/s, 60-90 degrees; glances stay static.
	_odir = 0;
	_osw = 0;
	_base = random 360;
	_pref = missionNamespace getVariable ["WFBE_C_VAR_SpectatorOrbit", true];
	_oldShot = missionNamespace getVariable ["WFBE_C_VAR_SpectShot", []];
	if (_same && {(count _oldShot) >= 16}) then {
		//--- same-POI re-stamp: keep angle continuity (current effective angle becomes the base).
		_base = _oldShot select 11;
		if ((_oldShot select 8) != 0) then {
			_ost = _oldShot select 9;
			if (time >= _ost) then {
				_prog = (time - _ost) * (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_ORBIT_REVEAL_RATE", 6]);
				if (_prog > (_oldShot select 10)) then {_prog = _oldShot select 10};
				_base = _base + ((_oldShot select 8) * _prog);
			};
		};
	};
	if (_pref && {_kind != "GLANCE"}) then {
		WFBE_C_VAR_DirOrbitFlip = !(missionNamespace getVariable ["WFBE_C_VAR_DirOrbitFlip", false]);
		_odir = 1;
		if (missionNamespace getVariable ["WFBE_C_VAR_DirOrbitFlip", false]) then {_odir = -1};
		_osw = (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_ORBIT_REVEAL_SWEEP_MIN", 60]) + (random (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_ORBIT_REVEAL_SWEEP_RAND", 30]));
	};
	_cutId = missionNamespace getVariable ["WFBE_C_VAR_SpectShotCutN", 0];
	if (!_same) then {
		_cutId = _cutId + 1;
		WFBE_C_VAR_SpectShotCutN = _cutId;
		//--- last-2-shown ring for the repeat penalty.
		_ring = missionNamespace getVariable ["WFBE_C_VAR_DirShownRing", []];
		_ring = _ring + [[_key, time]];
		if ((count _ring) > 2) then {_ring = [_ring select ((count _ring) - 2), _ring select ((count _ring) - 1)]};
		WFBE_C_VAR_DirShownRing = _ring;
	};
	//--- PRELOAD (flag WFBE_C_SPECTATOR_PRELOAD, default 0): on a REAL cut from the AUTO poll only,
	//--- stream the incoming shot's camera position before the snapshot flips. Without it the frame
	//--- handler snaps the camera onto the new POI on the very next frame and the opening moments
	//--- of the shot render unloaded terrain - the most visible defect on a broadcast. Position
	//--- mirrors the cut-frame geometry in Client_SpectatorAimFrame.sqf (centre + standoff at
	//--- _base angle, height _hgt); the orbit reveal has not started yet at cut time.
	if (_allowWait && {!_same} && {(missionNamespace getVariable ["WFBE_C_SPECTATOR_PRELOAD", 0]) > 0}) then {
		_pcam = [(_cxy select 0) + (_stand * sin _base), (_cxy select 1) + (_stand * cos _base), _hgt];
		_pcap = missionNamespace getVariable ["WFBE_C_SPECTATOR_PRELOAD_MAX_SEC", 1.5];
		_pt0 = diag_tickTime;
		waitUntil {(preloadCamera _pcam) || {(diag_tickTime - _pt0) > _pcap}};
		//--- always-on: this is the only evidence a box smoke can quote. capped=true means the
		//--- preload did NOT finish in time and the cut went ahead anyway (still correct, just
		//--- not fully preloaded) - a run of those means PRELOAD_MAX_SEC is too tight.
		_pwait = diag_tickTime - _pt0;
		diag_log Format ["SPECTATE|v8|preload|cut=%1|key=%2|wait=%3|capped=%4", _cutId, _key, ((round (_pwait * 100)) / 100), str (_pwait > _pcap)];
	};
	WFBE_C_VAR_SpectShot = [_cutId, _key, [_cxy select 0, _cxy select 1, 0], _aim, _stand, _hgt, _fov, time, _odir, time + (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_ORBIT_REVEAL_DELAY_SEC", 3]), _osw, _base, _label, _shotType, _reason, _sidesText];
	WFBE_C_VAR_SpectatorDirectorTargetLabel = _label;
	WFBE_C_VAR_SpectatorDirectorShotType = _shotType;
	WFBE_C_VAR_DirectorCutReason = _reason;
	WFBE_C_VAR_DirCurKey = _key;
	WFBE_C_VAR_DirCurKind = _kind;
	WFBE_C_VAR_DirCurStart = time;
	WFBE_C_VAR_DirCurStampScore = _score;
	WFBE_C_VAR_DirCurPushed = false;
	diag_log Format ["SPECTATE|v8|stamp|kind=%1|key=%2|score=%3|shot=%4|same=%5|label=%6", _kind, _key, round _score, _shotType, _same, _label];
};

//--- Density-peak aim for a track (NEVER the raw centroid - the centroid of a spread fight is
//--- the empty dirt between the sides). Peak = member with the most fellow members within
//--- DENSITY_M, event positions (<=10s) count double; ties resolve toward the centroid.
WFBE_CL_FNC_DirectorTrackAim = {
	Private ["_tr","_cx","_cy","_members","_evs","_densR2","_bestCnt","_bestDist","_ax","_ay","_m","_mx","_my","_dc","_cnt","_pos","_e"];
	_tr = _this;
	_cx = _tr select 1;
	_cy = _tr select 2;
	_members = _tr select 4;
	_evs = (_tr select 13) + (_tr select 14);
	_densR2 = (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_CLUSTER_DENSITY_M", 75]) ^ 2;
	_bestCnt = -1;
	_bestDist = 1e9;
	_ax = _cx;
	_ay = _cy;
	{
		if (!isNull _x && {alive _x}) then {
			_m = _x; //--- capture before the inner forEach rebinds _x (A2-OA gotcha)
			_pos = getPos _m;
			_mx = _pos select 0;
			_my = _pos select 1;
			_dc = sqrt (((_mx - _cx) ^ 2) + ((_my - _cy) ^ 2));
			_cnt = 0;
			{
				if (!isNull _x && {alive _x}) then {
					if (((((getPos _x) select 0) - _mx) ^ 2) + ((((getPos _x) select 1) - _my) ^ 2) <= _densR2) then {_cnt = _cnt + 1};
				};
			} forEach _members;
			{
				_e = _x;
				if (!isNil "_e") then {
					if ((diag_tickTime - (_e select 0)) <= 10 && {((((_e select 1) - _mx) ^ 2) + (((_e select 2) - _my) ^ 2)) <= _densR2}) then {_cnt = _cnt + 2};
				};
			} forEach _evs;
			if ((_cnt > _bestCnt) || {(_cnt == _bestCnt) && {_dc < _bestDist}}) then {
				_bestCnt = _cnt;
				_bestDist = _dc;
				_ax = _mx;
				_ay = _my;
			};
		};
	} forEach _members;
	[_ax, _ay, 1.5]
};

//--- The 1s auto brain: reconcile, consume events, score, hold/cut per the binding rules.
WFBE_CL_FNC_DirectorAutoStep = {
	Private ["_tracks","_tr","_terms","_f","_k","_m2","_sidesN","_mult","_score","_cands","_townReg","_te","_town","_row","_head","_rSidesN","_label","_curKey","_curKind","_curScore","_curLF","_curLK","_curTrack","_nowT","_lockUntil","_holdMin","_holdMax","_best","_bestEff","_entry","_eff","_ring","_penalized","_cool","_glTown","_glBest","_cx","_cy","_aim","_sidesText","_curStart","_shot","_newCool","_keep","_intensity","_bestEntry","_townName"];
	_nowT = time;
	Call WFBE_CL_FNC_DirectorTracksUpdate;
	Call WFBE_CL_FNC_DirectorEvConsume;
	_tracks = missionNamespace getVariable ["WFBE_C_VAR_DirTracks", []];
	_cands = []; //--- [key, kind, score, ref, label, sidesText, lastFire, lastKill, aimSrc]
	{
		_tr = _x;
		_terms = [_tr select 13, _tr select 14] Call WFBE_CL_FNC_DirectorEvTerms;
		_f = _terms select 0;
		_k = _terms select 1;
		_tr set [13, _terms select 2];
		_tr set [14, _terms select 3];
		_sidesN = 0;
		{if (_x > 0) then {_sidesN = _sidesN + 1}} forEach [_tr select 5, _tr select 6, _tr select 7];
		_tr set [16, _sidesN];
		_score = 0;
		//--- FIGHT requires 2 armed belligerent sides AND F+K>0 within 10s. ACTION = events, not proximity.
		if (_sidesN >= 2 && {((count (_tr select 13)) + (count (_tr select 14))) > 0}) then {
			_mult = 1;
			if (_sidesN == 2) then {_mult = 1.2};
			if (_sidesN >= 3) then {_mult = 1.35};
			_m2 = (_tr select 9) min 3;
			_score = _mult * ((40 * _f) + (100 * _k) + (8 * _m2) + (4 * ((_tr select 8) min 8)));
		};
		_tr set [15, _score];
		if (_score > 0) then {
			_townName = [_tr select 1, _tr select 2] Call WFBE_CL_FNC_DirectorNearestTownName;
			_sidesText = "";
			if ((_tr select 5) > 0) then {_sidesText = "WEST"};
			if ((_tr select 6) > 0) then {if (_sidesText != "") then {_sidesText = _sidesText + " vs EAST"} else {_sidesText = "EAST"}};
			if ((_tr select 7) > 0) then {if (_sidesText != "") then {_sidesText = _sidesText + " vs GUER"} else {_sidesText = "GUER"}};
			_cands = _cands + [[Format ["F:%1", _tr select 0], "FIGHT", _score, _tr, Format ["FIRE FIGHT near %1", _townName], _sidesText, _tr select 11, _tr select 12]];
		};
	} forEach _tracks;
	//--- event-towns (arty strikes / raids with no reconciled track nearby).
	_townReg = missionNamespace getVariable ["WFBE_C_VAR_DirTownEv", []];
	Private ["_newReg"];
	_newReg = [];
	{
		_te = _x;
		_town = _te select 0;
		if (!isNull _town) then {
			_terms = [_te select 1, _te select 2] Call WFBE_CL_FNC_DirectorEvTerms;
			_f = _terms select 0;
			_k = _terms select 1;
			_te set [1, _terms select 2];
			_te set [2, _terms select 3];
			if (((count (_te select 1)) + (count (_te select 2))) > 0) then {
				_newReg = _newReg + [_te];
				_row = [];
				{
					if ((_x select 0) == _town) then {_row = _x};
				} forEach (missionNamespace getVariable ["WFBE_C_VAR_DirectorTownData", []]);
				_head = 0;
				_rSidesN = 1;
				if ((count _row) >= 5) then {_head = _row select 4; _rSidesN = _row select 3};
				_mult = 1;
				if (_rSidesN == 2) then {_mult = 1.2};
				if (_rSidesN >= 3) then {_mult = 1.35};
				_score = _mult * ((40 * _f) + (100 * _k) + (4 * (_head min 8)));
				if (_score > 0) then {
					_label = _town getVariable ["name", "Town"];
					_cands = _cands + [[Format ["T:%1", _label], "TOWN", _score, _town, _label, Format ["%1 under fire", _label], _te select 3, _te select 4]];
				};
			};
		};
	} forEach _townReg;
	WFBE_C_VAR_DirTownEv = _newReg;
	//--- current-shot bookkeeping.
	_curKey = missionNamespace getVariable ["WFBE_C_VAR_DirCurKey", ""];
	_curKind = missionNamespace getVariable ["WFBE_C_VAR_DirCurKind", ""];
	_curStart = missionNamespace getVariable ["WFBE_C_VAR_DirCurStart", -999];
	_curScore = 0;
	_curLF = -999;
	_curLK = -999;
	_curTrack = [];
	{
		_entry = _x;
		if ((_entry select 0) == _curKey) then {
			_curScore = _entry select 2;
			_curLF = _entry select 6;
			_curLK = _entry select 7;
			if ((_entry select 1) == "FIGHT") then {_curTrack = _entry select 3};
		};
	} forEach _cands;
	_intensity = "QUIET";
	if (_curScore > 0) then {_intensity = "CONTACT"};
	if (_curScore >= 80) then {_intensity = "SKIRMISH"};
	if (_curScore >= 250) then {_intensity = "HEAVY"};
	WFBE_C_VAR_DirIntensity = _intensity;
	//--- best OTHER candidate with the last-2-shown penalty (25 percent for 30s, bypass at 2x current).
	_ring = missionNamespace getVariable ["WFBE_C_VAR_DirShownRing", []];
	_best = -1;
	_bestEff = 0;
	_bestEntry = [];
	{
		_entry = _x;
		if ((_entry select 0) != _curKey) then {
			_eff = _entry select 2;
			_penalized = false;
			{
				if ((_x select 0) == (_entry select 0) && {(_nowT - (_x select 1)) < (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_RECENT_SEC", 30])}) then {_penalized = true};
			} forEach _ring;
			if (_penalized && {(_entry select 2) < (2 * (_curScore max 1))}) then {
				_eff = _eff * (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_RECENT_PENALTY", 0.75]);
			};
			if (_eff > _bestEff) then {_bestEff = _eff; _bestEntry = _entry};
		};
	} forEach _cands;
	_holdMin = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_HOLD_MIN_SEC", 7];
	_holdMax = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_HOLD_MAX_SEC", 12];
	//--- GLANCE shots: 3s wide look then 45s cooldown on that town.
	if (_curKind == "GLANCE") then {
		if ((_nowT - _curStart) >= (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_GLANCE_SEC", 3])) then {
			_glTown = missionNamespace getVariable ["WFBE_C_VAR_DirCurTown", objNull];
			if (!isNull _glTown) then {
				_cool = missionNamespace getVariable ["WFBE_C_VAR_DirTownCool", []];
				_cool = _cool + [[_glTown, _nowT + (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_TOWN_COOLDOWN_SEC", 45])]];
				WFBE_C_VAR_DirTownCool = _cool;
			};
			WFBE_C_VAR_DirCurKey = "";
			_curKey = "";
			_curKind = "";
		};
	};
	if (_curKey != "" && {_curKind != "GLANCE"}) then {
		//--- FIGHT/TOWN hold: lockUntil = max(shotStart+7, lastFire+7, lastKill+2), capped at start+12.
		_lockUntil = _curStart + _holdMin;
		if ((_curLF + _holdMin) > _lockUntil) then {_lockUntil = _curLF + _holdMin};
		if ((_curLK + 2) > _lockUntil) then {_lockUntil = _curLK + 2};
		if (_lockUntil > (_curStart + _holdMax)) then {_lockUntil = _curStart + _holdMax};
		if (_curScore > 0 && {_nowT < _lockUntil}) then {
			//--- PUSH-IN = escalation only (score >= 1.5x the stamp sample), compact tracks only, once.
			if (!(missionNamespace getVariable ["WFBE_C_VAR_DirCurPushed", false]) && {_curKind == "FIGHT"} && {(count _curTrack) > 0} && {(_curTrack select 3) < (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_FIGHT_COMPACT_M", 120])} && {_curScore >= ((missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_PUSH_RATIO", 1.5]) * ((missionNamespace getVariable ["WFBE_C_VAR_DirCurStampScore", 1]) max 1))}) then {
				_shot = missionNamespace getVariable ["WFBE_C_VAR_SpectShot", []];
				if ((count _shot) >= 16) then {
					_shot set [4, (_shot select 4) * (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_PUSH_SCALE", 0.85])];
					_shot set [5, (_shot select 5) * (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_PUSH_SCALE", 0.85])];
					WFBE_C_VAR_DirCurPushed = true;
					diag_log Format ["SPECTATE|v8|push-in|key=%1|score=%2", _curKey, round _curScore];
				};
			};
		} else {
			if (_curScore > 0) then {
				//--- lock expired, action continues: cut only on a 1.5x better rival, else extend to 12s
				//--- then re-stamp the SAME POI continuously (fresh framing, no hard cut).
				if (_bestEff >= (_curScore * (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_CUT_RATIO", 1.5])) && {(count _bestEntry) > 0}) then {
					[_bestEntry] Call WFBE_CL_FNC_DirectorCutTo;
				} else {
					if ((_nowT - _curStart) >= _holdMax) then {
						{
							_entry = _x;
							if ((_entry select 0) == _curKey) then {[_entry, true] Call WFBE_CL_FNC_DirectorCutTo};
						} forEach _cands;
					};
				};
			} else {
				//--- current shot's action died: move on to the best candidate or a glance.
				if ((count _bestEntry) > 0) then {
					[_bestEntry] Call WFBE_CL_FNC_DirectorCutTo;
				} else {
					WFBE_C_VAR_DirCurKey = "";
					_curKey = "";
				};
			};
		};
	};
	if (_curKey == "") then {
		if ((count _bestEntry) > 0) then {
			[_bestEntry] Call WFBE_CL_FNC_DirectorCutTo;
		} else {
			//--- nothing fights anywhere: 3s WIDE town glances on rotation (45s cooldown each).
			//--- Empty bases/HQs are NEVER shown (owner ruling).
			_cool = missionNamespace getVariable ["WFBE_C_VAR_DirTownCool", []];
			_newCool = [];
			{
				if (!isNil "_x") then {
					if ((_x select 1) > _nowT) then {_newCool = _newCool + [_x]};
				};
			} forEach _cool;
			WFBE_C_VAR_DirTownCool = _newCool;
			_glBest = [];
			Private ["_glHead"];
			_glHead = -1;
			{
				_row = _x;
				_town = _row select 0;
				_keep = true;
				{
					if ((_x select 0) == _town) then {_keep = false};
				} forEach _newCool;
				if (_keep && {(_row select 4) > _glHead}) then {_glHead = _row select 4; _glBest = _row};
			} forEach (missionNamespace getVariable ["WFBE_C_VAR_DirectorTownData", []]);
			if ((count _glBest) > 0) then {
				_town = _glBest select 0;
				_cx = (getPos _town) select 0;
				_cy = (getPos _town) select 1;
				WFBE_C_VAR_DirCurTown = _town;
				WFBE_C_VAR_SpectatorTarget = _town;
				["GLANCE", Format ["T:%1", _town getVariable ["name", "Town"]], [_cx, _cy], [_cx, _cy, 1.5], 500, _town getVariable ["name", "Town"], "", 0, false, true] Call WFBE_CL_FNC_DirectorStamp;
			};
		};
	};
};

//--- Cut/extend helper: _this = [candEntry] (hard cut to a new POI) or [candEntry, true]
//--- (same-POI continuous re-stamp after the 12s ceiling).
WFBE_CL_FNC_DirectorCutTo = {
	Private ["_entry","_same","_kind","_tr","_aim","_town","_cx","_cy"];
	_entry = _this select 0;
	_same = false;
	if ((count _this) > 1) then {_same = _this select 1};
	_kind = _entry select 1;
	if (_kind == "FIGHT") then {
		_tr = _entry select 3;
		_aim = _tr Call WFBE_CL_FNC_DirectorTrackAim;
		WFBE_C_VAR_DirCurTown = objNull;
		WFBE_C_VAR_SpectatorTarget = objNull;
		[_kind, _entry select 0, [_tr select 1, _tr select 2], _aim, _tr select 3, _entry select 4, _entry select 5, _entry select 2, _same, true] Call WFBE_CL_FNC_DirectorStamp;
	} else {
		_town = _entry select 3;
		if (!isNull _town) then {
			_cx = (getPos _town) select 0;
			_cy = (getPos _town) select 1;
			WFBE_C_VAR_DirCurTown = _town;
			WFBE_C_VAR_SpectatorTarget = _town;
			[_kind, _entry select 0, [_cx, _cy], [_cx, _cy, 1.5], 500, _entry select 4, _entry select 5, _entry select 2, _same, true] Call WFBE_CL_FNC_DirectorStamp;
		};
	};
};

//--- MANUAL N/B: arms the next/previous entry in the pinned class. In director mode a manual
//--- pick pauses auto and stamps a STATIC framing of the pick (F/V still engage unit modes).
WFBE_CL_FNC_DirectorCycleTarget = {
	Private ["_step","_list","_current","_index","_i","_entry","_pos","_stand","_hgt","_fov","_cls"];
	_step = _this;
	_list = Call WFBE_CL_FNC_DirectorBuildActive;
	if (count _list == 0) exitWith {
		WFBE_C_VAR_SpectatorTarget = objNull;
		systemChat "[WASP] Director: no live targets in this class.";
	};
	_current = missionNamespace getVariable ["WFBE_C_VAR_SpectatorTarget", objNull];
	_index = -1;
	_i = 0;
	{
		if ((_x select 1) == _current) then {_index = _i};
		_i = _i + 1;
	} forEach _list;
	if (_index < 0) then {_index = 0} else {_index = (_index + _step + (count _list)) % (count _list)};
	_entry = _list select _index;
	WFBE_C_VAR_SpectatorTarget = _entry select 1;
	WFBE_C_VAR_SpectatorDirectorTargetLabel = _entry select 0;
	if ((missionNamespace getVariable ["WFBE_C_VAR_SpectatorMode", "free"]) == "director") then {
		if (missionNamespace getVariable ["WFBE_C_VAR_SpectatorDirectorAuto", false]) then {
			WFBE_C_VAR_SpectatorDirectorAuto = false;
			systemChat "[WASP] Director auto paused for manual browsing (G resumes).";
		};
		_pos = getPos (_entry select 1);
		_cls = _entry select 2;
		if (_cls == "TOWN" || {_cls == "HQ"}) then {
			_stand = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_WIDE_RADIUS", 180];
			_hgt = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_WIDE_HEIGHT", 110];
			_fov = 0.6;
		} else {
			_stand = 30;
			_hgt = 15;
			_fov = 0.5;
		};
		WFBE_C_VAR_DirCurTown = objNull;
		["MANUAL", Format ["M:%1:%2", _entry select 0, missionNamespace getVariable ["WFBE_C_VAR_SpectShotCutN", 0]], [_pos select 0, _pos select 1], [_pos select 0, _pos select 1, 1.5], (_stand min 119), _entry select 0, "", 0, false] Call WFBE_CL_FNC_DirectorStamp;
		//--- MANUAL framing overrides the compact/spread geometry from the stamp.
		Private ["_shot"];
		_shot = missionNamespace getVariable ["WFBE_C_VAR_SpectShot", []];
		if ((count _shot) >= 16) then {
			_shot set [4, _stand];
			_shot set [5, _hgt];
			_shot set [6, _fov];
		};
	};
	systemChat Format ["[WASP] Director target: %1", _entry select 0];
};

WFBE_CL_FNC_DirectorLoopStart = {
	[] spawn {
		Private ["_pollSec"];
		diag_log "SPECTATE|v8|director-thread-start";
		while {missionNamespace getVariable ["WFBE_C_VAR_SpectatorActive", false] && {!(missionNamespace getVariable ["WFBE_gameover", false])}} do {
			sleep 1;
			if ((missionNamespace getVariable ["WFBE_C_VAR_SpectatorMode", "free"]) == "director") then {
				_pollSec = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_TOWN_POLL_SEC", 8];
				if ((time - (missionNamespace getVariable ["WFBE_C_VAR_DirectorLastTownPoll", 0])) >= _pollSec) then {
					Call WFBE_CL_FNC_DirectorPollTowns;
					WFBE_C_VAR_DirectorLastTownPoll = time;
				};
				if (missionNamespace getVariable ["WFBE_C_VAR_SpectatorDirectorAuto", false]) then {
					Call WFBE_CL_FNC_DirectorAutoStep;
				};
			};
		};
	};
};
