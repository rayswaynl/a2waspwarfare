Private ['_args'];
_args = _this select 3;
if ((_args select 0) == "boom") then {WFBE_FPV_Boom = true};
if ((_args select 0) == "leave") then {WFBE_FPV_Terminate = true};
