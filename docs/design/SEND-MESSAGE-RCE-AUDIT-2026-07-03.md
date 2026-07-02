# SEND_MESSAGE RCE Audit - 2026-07-03

Lane: fleet lane 73, DR-46
Base checked: `origin/claude/build84-cmdcon36@b1608b096`

## Scope

The fleet prompt flags `Client_onEventHandler_SEND_MESSAGE.sqf` as a public
variable RCE surface because the old multi-language message path evaluated
inbound message text with `call compile`.

This pass checks the current target's SEND_MESSAGE path across the three
maintained roots:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad`

No mission source, generated mirror output, BattleEye filters, live runtime
settings, package artifacts, or JIP/enrollment code are changed here.

## Verdict

Lane 73 is already fixed on the current target.

The SEND_MESSAGE public variable handler is still intentionally registered on
every client, but the multi-language branch no longer executes inbound text.
The current handler requires structured data in the form:

`[stringtableKey, formatArgs]`

It type-checks the payload shape, resolves the stringtable key with
`localize`, appends the format arguments, and calls `format` on that data
array. If a forged multi-language payload is not an array, the handler renders
an empty string instead of compiling it.

The old expression `call compile _messageText` now appears only inside
security comments that explain the removed behavior. It is not executable code
in the SEND_MESSAGE handler or the common sender.

## Evidence Table

| Surface | Evidence | Result |
| --- | --- | --- |
| Client PV registration | `Client/FSM/updateclient.sqf:10-12` compiles `Client_onEventHandler_SEND_MESSAGE.sqf` and registers `"SEND_MESSAGE" addPublicVariableEventHandler` in all three roots. | The public-variable entry point is still present, so this is the right path to audit. |
| Client receiver | `Client/Functions/Client_onEventHandler_SEND_MESSAGE.sqf:29-46` documents the removed RCE behavior, requires `typeName _messageText == "ARRAY"`, normalizes non-array args to `[]`, builds `_fmt = [localize _key]`, appends args, then uses `format _fmt`. Non-array multi-language payloads become `""`. | Inbound structured message data is formatted, not executed. |
| Common sender/local echo | `Common/Functions/Common_SendMessage.sqf:5-8` documents the structured `[key, args]` contract, and `:28-46` mirrors the same localize-plus-format handling before local system chat. | Local sender-side display follows the same no-eval contract. |
| Network broadcast | `Common/Functions/Common_SendMessage.sqf:58-59` stores `_SEND_MESSAGE_infos` and `publicVariable`s `SEND_MESSAGE`. | The value still crosses the network, but it is handled as data on receipt. |
| Arty callsite | `Client/Functions/Client_RequestFireMission.sqf:61-65` calls out the old player-name injection risk and now sends `["STR_WF_INFO_Arty_called_message", [_playerName, _ammoName, _gunCount]]`; `:76` sends it through `WF_sendMessage`. | The attacker-controlled player name is a format argument, not source text. |
| ICBM callsites | `Client/Module/Nuke/ICBM_EnemySide_Message.sqf:15-16` and `ICBM_friendlySide_Message.sqf:14-16` document structured payloads resolved with localize plus format; both call `WF_sendMessage` at `:24`. | The old localization snippet pattern has been replaced for the checked nuke message paths. |
| Server PVF comparison | `Server/Functions/Server_HandlePVF.sqf:15-20` rejects unregistered handlers and requires registered handlers to be CODE in all three roots. | The related audit-v2 server PVF hardening is present; this lane's client SEND_MESSAGE path is separately hardened too. |

## Out Of Scope

This is not a repository-wide `call compile` audit. Other legacy uses remain in
unrelated UI, preprocessed script loading, and the AntiStack database extension
module. The fleet prompt explicitly marks AntiStack as off-limits for this
tranche, and those surfaces are not changed or assessed by this lane.

This audit also does not claim to prevent SEND_MESSAGE spam or spoofed benign
messages. It only verifies that the flagged arbitrary-code-execution shape is
absent from the current SEND_MESSAGE multi-language path.

## Verification

- `rg` confirmed `call compile _messageText` matches only comments in
  `Client_onEventHandler_SEND_MESSAGE.sqf` and `Common_SendMessage.sqf` across
  Chernarus, Takistan, and Zargabad.
- `rg` confirmed the three maintained roots use `typeName _messageText ==
  "ARRAY"`, `localize _key`, and `format _fmt` in the SEND_MESSAGE
  multi-language path.
- `rg` confirmed the known arty and ICBM SEND_MESSAGE callsites now pass
  structured `[key, args]` data instead of executable localization snippets.
- `rg` confirmed `Server_HandlePVF.sqf` still carries the audit-v2 registered
  CODE-handler hardening in all three roots.
- This PR is docs-only. LoadoutManager was not run because no mission source or
  generated mirror source changed.
