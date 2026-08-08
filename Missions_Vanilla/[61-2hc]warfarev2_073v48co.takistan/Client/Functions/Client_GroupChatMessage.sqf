//--- r73b: group-chat channel fail-clean (twin of CommandChatMessage). Empty / non-string payloads
//--- (sound-only LocalizeMessage cases, fall-throughs) must not hit groupChat.
if (isNil "player" || {isNull player}) exitWith {};
if (isNil "_this") exitWith {};
if (typeName _this != "STRING") exitWith {};
if (_this == "") exitWith {};
//--- fix0808b (owner live test 2026-08-08): channel-3 re-enable (#2439) made the engine ACCEPT group
//--- chat again but the feed line still does not RENDER on live clients - money paid, message invisible.
//--- systemChat renders unconditionally (local-only, no channel gating); evidence: KILLMONEY CLIRECV
//--- receipts with owner seeing nothing. Keep the groupChat call too so squadmates still get the line
//--- if/when the engine-side display recovers.
player groupChat _this;
systemChat _this;
