# Capture Notification Fallback Audit

Date: 2026-07-02
Lane: 161 - capture notification fallback
Branch: `codex/lane161-capture-notification-fallback`
Base: `claude/build84-cmdcon36`

## Verdict

Lane 161 is already fixed on the current target. No source change is needed.

The prompt row described town capture/loss notifications as `titleText`-only in `LocalizeMessage.sqf`.
Current source does not route town captures through a `LocalizeMessage` city case. The maintained path is
the dedicated `TownCaptured` PVF, and it already emits a chat-visible fallback.

## Evidence

- Chernarus `Server/FSM/server_town.sqf:300` broadcasts `[nil, "TownCaptured", [_location, _sideID, _newSID]]`.
- Takistan `Server/FSM/server_town.sqf:300` has the same broadcast path.
- Chernarus `Client/PVFunctions/TownCaptured.sqf:28-31` formats `STR_WF_CHAT_Town_Captured`, calls `TitleTextMessage`, then calls `CommandChatMessage`.
- Takistan `Client/PVFunctions/TownCaptured.sqf:28-31` has the same title-plus-chat fallback.
- `Common/Init/Init_PublicVariables.sqf:48` registers `TownCaptured` in both maintained roots.
- `git diff --no-index` shows the Chernarus and Takistan `TownCaptured.sqf` copies match.

## Scope Notes

- No mission source was changed.
- No stringtable row was added because the existing `STR_WF_CHAT_Town_Captured` string is already reused for both channels.
- No map marker flash was added; the current fallback already satisfies the chat-visible part of the lane, while marker recolor remains the existing local `setMarkerColorLocal` behavior.

## Suggested Smoke

On a local or live smoke where a town changes owner:

- Watch for the existing capture title.
- Confirm the same capture text also appears in command/chat history.
- Confirm the town marker still recolors to the new owner.
