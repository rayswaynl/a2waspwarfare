Private ["_actionID","_caller","_index","_lifter","_param","_sorted","_type","_vehicle","_vehicles","_dir","_dropX","_dropY","_hq","_offset"];

_lifter = _this select 0;
_caller = _this select 1;
_actionID = _this select 2;
_param = _this select 3;
_vehicle = _param select 0;

_lifter setVariable ["Attached",false];
detach _vehicle;

//--- Trello #87: drop on the GROUND behind the lifter for ALL vehicles (was Zeta_Special-only),
//--- so airlifted vehicles no longer land on the HQ roof / on top of the lifter.
_dir = getDir _lifter;
_offset = 15;
_dropX = (getPos _lifter select 0) - (_offset * sin _dir);
_dropY = (getPos _lifter select 1) - (_offset * cos _dir);

//--- If the friendly side HQ is right under the drop point, push the drop further out behind the lifter.
_hq = (side _caller) Call WFBE_CO_FNC_GetSideHQ;
if (!isNull _hq) then {
	if ([_dropX,_dropY,0] distance _hq < 25) then {
		_offset = _offset + 25;
		_dropX = (getPos _lifter select 0) - (_offset * sin _dir);
		_dropY = (getPos _lifter select 1) - (_offset * cos _dir);
	};
};

_vehicle setPos [_dropX,_dropY,0];

_vehicle setVelocity (velocity _lifter);
_lifter removeAction _actionID;

sleep 1;

if ((getPos _vehicle) select 2 < 0) then {_vehicle setPos [(getPos _vehicle) select 0,(getPos _vehicle) select 1,0];_vehicle setVelocity [0,0,-0.1]};