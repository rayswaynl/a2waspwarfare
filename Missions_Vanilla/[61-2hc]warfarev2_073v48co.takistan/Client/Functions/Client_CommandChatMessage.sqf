//--- r73b: command-chat channel fail-clean. Callers (LocalizeMessage, WildcardMarker, etc.) can pass
//--- non-STRING / empty / run before player exists — bare `player commandChat _this` then throws and
//--- aborts the caller mid-notification fan-out.
if (isNil "player" || {isNull player}) exitWith {};
if (isNil "_this") exitWith {};
if (typeName _this != "STRING") exitWith {};
if (_this == "") exitWith {};
player commandChat _this;
