private ["_u","_am","_rkt","_jetSide","_aa","_nearest","_shots",
"_fp","_sspd","_spd","_sltd","_acc","_agl","_prd","_t",
"_dis","_trvldis","_trgp","_trgv","_ttimp",
"_vl","_vlnr","_vlnrd","_vc","_vcnr","_vcnrd","_vg","_vgnr","_vgnrd"];

//--- SEAD missile guidance (Build 93). Spawned via Fired EH on tier-5 jets.
//--- Guides Maverick (F35B) or Ch29 (Su34) toward the nearest enemy AA radar vehicle
//--- within 5 km. Limited to 2 shots per jet spawn via WFBE_sead_shots vehicle variable.
//--- Flag: WFBE_C_SEAD (default 0 - inert when off).

_u  = _this select 0;
_am = _this select 4;

//--- Feature gate
if (!((missionNamespace getVariable ["WFBE_C_SEAD", 0]) > 0)) exitWith {};

//--- Tier-5 high-tier jets only
if (!(typeOf _u in ["F35B","Su34"])) exitWith {};

//--- SEAD-capable ammo: M_Maverick_AT (F35B) or M_Ch29_AT (Su34 Kh-29)
if (!(_am in ["M_Maverick_AT","M_Ch29_AT"])) exitWith {};

//--- Shot limit: 2 SEAD uses per spawn
_shots = _u getVariable ["WFBE_sead_shots", 0];
if (_shots >= 2) exitWith {};

//--- Find the launched missile projectile
_rkt = nearestObject [_u, _am];
if (isNull _rkt) exitWith {};

//--- Find nearest enemy AA radar vehicle within 5 km
_jetSide = side (group _u);
_aa = nearestObjects [getPos _u, ["2S6M_Tunguska","M6_EP1","ZSU_INS","ZSU_CDF","ZSU_TK_EP1"], 5000];

_nearest = objNull;
_dis = 5001;
{
    if (alive _x && {side _x != _jetSide}) then {
        private ["_d"];
        _d = _rkt distance _x;
        if (_d < _dis) then {
            _dis = _d;
            _nearest = _x;
        };
    };
} forEach _aa;

if (isNull _nearest) exitWith {};

//--- Consume one SEAD shot and log
_u setVariable ["WFBE_sead_shots", _shots + 1];
["INFORMATION", Format ["SEAD: %1 shot %2/2 toward %3", typeOf _u, _shots + 1, typeOf _nearest]] Call WFBE_CO_FNC_LogContent;

//--- Guidance parameters (radar-hunting: moderate turn rate, locks onto grounded AA vehicle)
_sltd = 750;
_acc  = 0.8;
_agl  = 0.012;
_prd  = 0.4;
_t    = 0;
_fp   = getPosASL _rkt;
_sspd = (velocity _rkt) distance [0,0,0];
_spd  = _sspd;

sleep 0.05;

While {!isNull _rkt} do {

    _dis     = _fp distance (getPosASL _nearest);
    _trvldis = _fp distance _rkt;
    _trgv    = velocity _nearest;

    _ttimp = _prd * ((_rkt distance _nearest) / ((velocity _rkt) distance [0,0,0]));
    _trgp  = [
        ((getPosASL _nearest) select 0) + _ttimp * (_trgv select 0),
        ((getPosASL _nearest) select 1) + _ttimp * (_trgv select 1),
        ((getPosASL _nearest) select 2) + _ttimp * (_trgv select 2)
    ];

    if (_trvldis > _dis) then { breakTo "OUT" };

    _vl   = velocity _rkt;
    _vlnr = _vl distance [0,0,0];
    if (_vlnr != 0) then {
        _vlnrd = [(_vl select 0) / _vlnr, (_vl select 1) / _vlnr, (_vl select 2) / _vlnr];
    } else {
        _vlnrd = [0,0,0];
    };

    _vcnr = _trgp distance (getPosASL _rkt);
    _vc   = [
        (_trgp select 0) - ((getPosASL _rkt) select 0),
        (_trgp select 1) - ((getPosASL _rkt) select 1),
        (_trgp select 2) - ((getPosASL _rkt) select 2)
    ];
    if (_vcnr != 0) then {
        _vcnrd = [(_vc select 0) / _vcnr, (_vc select 1) / _vcnr, (_vc select 2) / _vcnr];
    } else {
        _vcnrd = [0,0,0];
    };

    _t    = _trvldis / _spd;
    _spd  = _sltd - (_sltd - _sspd) * exp((-1) * _acc * _t);

    _vg    = [
        _agl * (_vcnrd select 0) + (_vlnrd select 0),
        _agl * (_vcnrd select 1) + (_vlnrd select 1),
        _agl * (_vcnrd select 2) + (_vlnrd select 2)
    ];
    _vgnr  = _vg distance [0,0,0];
    _vgnrd = [(_vg select 0) / _vgnr, (_vg select 1) / _vgnr, (_vg select 2) / _vgnr];

    _rkt setVectorDirAndUp [
        [(_vgnrd select 0),(_vgnrd select 1),(_vgnrd select 2)],
        [0,0,1]
    ];
    _rkt setVelocity [
        (_vgnrd select 0) * _spd,
        (_vgnrd select 1) * _spd,
        (_vgnrd select 2) * _spd
    ];

};

scopeName "OUT";
exit;
