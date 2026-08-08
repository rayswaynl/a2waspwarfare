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
//--- fix0808e (owner live evidence 2026-08-08): group chat NEVER renders on live clients even with
//--- channel 3 enabled (three builds of proof), and systemChat does NOT exist on A2 OA 1.64 (A3-only
//--- command; the 0808b line was silent). Command chat provably renders (wildcard/first-blood lines).
//--- Route through commandChat; local display only, same pattern as Client_CommandChatMessage.sqf.
player commandChat _this;
