//--- r73b: group-chat channel fail-clean (twin of CommandChatMessage). Empty / non-string payloads
//--- (sound-only LocalizeMessage cases, fall-throughs) must not hit groupChat.
if (isNil "player" || {isNull player}) exitWith {};
if (isNil "_this") exitWith {};
if (typeName _this != "STRING") exitWith {};
if (_this == "") exitWith {};
player groupChat _this;
