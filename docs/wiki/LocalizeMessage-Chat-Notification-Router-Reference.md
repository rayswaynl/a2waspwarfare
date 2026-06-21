# Client LocalizeMessage (chat / notification router and its tag-case table)

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

`Client\PVFunctions\LocalizeMessage.sqf` is the client-side router that turns a string **message tag** plus its arguments into a localized chat line, then prints that line to either the command channel or the group channel. It is one of two "second-level routers" in the PVF family (the other being `HandleSpecial`): the server (or a client GUI) sends one PVF named `"LocalizeMessage"`, and the first array element selects which `case` builds the text. A handful of tags also mutate the receiving player's funds locally — the optimistic-client economy reconciliation — so the file is both a notification surface and a money-touching surface.

This page enumerates every `case`, its parameter layout, the localized string it formats, whether it changes local funds, and which channel it prints on. It also documents the dispatch/registration chain and the three classname-string-vs-number refund branches.

## Dispatch and registration chain

The tag is never compiled per-message; the file is compiled once into the alias `CLTFNCLocalizeMessage`, and senders address it by the short name `"LocalizeMessage"`.

| Step | Where | Detail |
| --- | --- | --- |
| Registered in client PV list | `Common/Init/Init_PublicVariables.sqf:39` | `_l = _l + ["LocalizeMessage"]` adds it to `_clientCommandPV`. |
| Compiled into alias | `Common/Init/Init_PublicVariables.sqf:55` | `CLTFNC%1 = compile preprocessFileLineNumbers 'Client\PVFunctions\%1.sqf'` → `CLTFNCLocalizeMessage`. |
| PV event handler bound | `Common/Init/Init_PublicVariables.sqf:56` | `WFBE_PVF_LocalizeMessage` `addPublicVariableEventHandler` → `(_this select 1) Spawn WFBE_CL_FNC_HandlePVF`. |
| Targeted send (one client / UID) | `Common/Functions/Common_SendToClient.sqf:14` | sets slot 1 to `Format["CLTFNC%1",_func]`, broadcasts `WFBE_PVF_LocalizeMessage` to one owner. |
| Broadcast send (side / all) | `Common/Functions/Common_SendToClients.sqf:12,15` | same alias rewrite, then `publicVariable 'WFBE_PVF_LocalizeMessage'`. |
| Receiver invokes alias | `Client/Functions/Client_HandlePVF.sqf:32-33` | `_code = missionNamespace getVariable _script` (the `CLTFNC...` name) then `_parameters Spawn _code`. |
| Hosted-server local short-circuit | e.g. `Client/GUI/GUI_Menu_Economy.sqf:142,162` | `if (!isHostedServer) then {...} else {[...] Spawn CLTFNCLocalizeMessage}` — runs the case directly without a round trip. |

The destination filter in `Client_HandlePVF.sqf:28-30` is what makes a `SIDE`-addressed send reach only members of that side, and a UID-string send reach only the matching player. Headless clients are dropped for `LocalizeMessage` (only `CLTFNCHandleSpecial` delegate tags pass the headless gate at `Client_HandlePVF.sqf:19-24`).

## Router preamble

| Behavior | Path:line | Detail |
| --- | --- | --- |
| Tag read | `Client/PVFunctions/LocalizeMessage.sqf:3` | `_localize = _this select 0`. |
| Structure object pre-extract | `Client/PVFunctions/LocalizeMessage.sqf:4` | `_object` = `_this select 3` for `StructureSell`, `_this select 2` for `StructureSold`; used by `GetClosestLocation`. |
| Default channel | `Client/PVFunctions/LocalizeMessage.sqf:5` | `_commandChat = true` — cases set it `false` to use group chat. |
| Channel select (epilogue) | `Client/PVFunctions/LocalizeMessage.sqf:181-185` | `if (_commandChat) then {_txt Call CommandChatMessage} else {_txt Call GroupChatMessage}`. |

The two channel helpers are one-liners: `CommandChatMessage` = `player commandChat _this` (`Client/Functions/Client_CommandChatMessage.sqf:1`); `GroupChatMessage` = `player groupChat _this` (`Client/Functions/Client_GroupChatMessage.sqf:1`).

## Tag-case table

Parameters are listed as `_this select N`; `select 0` is always the tag. "Funds" marks cases that call `ChangePlayerFunds` (= `Client\Functions\Client_ChangePlayerFunds.sqf`, compiled at `Client/Init/Init_Client.sqf:72`). "Channel" is command unless the case sets `_commandChat = false`.

| Tag | Params (after tag) | Localized string | Funds | Channel | Path:line |
| --- | --- | --- | --- | --- | --- |
| `BuildingTeamkill` | [1]=killerName [2]=killerUID [3]=type | `STR_WF_CHAT_Teamkill_Building` (+ `displayName`) | — | command | `:11` |
| `AttackModeActivated` | [1]=priceMod% [2]=minutes | inline EN string + `playSound "attackMode"` | — | command | `:12` |
| `AttackModeActiveJIP` | none | inline EN string + `playSound "attackMode"` | — | command | `:13` |
| `AttackModeEnd` | none | inline EN string | — | command | `:14` |
| `Teamswap` | [3]=joinedConfirmed [4]=side | `STR_WF_CHAT_Teamswap` | — | command | `:15` |
| `Teamstack` | (sender passes name/uid/side) | `STR_WF_CHAT_Teamstack` after `waitUntil` on `WFBE_BLUFOR/OPFOR_SCORE_JOIN` | — | command | `:16-46` |
| `CommanderDisconnected` | none | `strwfcommanderdisconnected` | — | command | `:47` |
| `TacticalLaunch` | none | `STR_WF_CHAT_ICBM_Launch` | — | command | `:48` |
| `CBRadarNeedsAAR` | none | `CBRadarNeedsAAR` | — | command | `:49` |
| `BankAlreadyBuilt` | none | `BankAlreadyBuilt` | — | command | `:50` |
| `BankTooCloseToBase` | none | `BankTooCloseToBase` | — | command | `:51` |
| `BankDestroyed` | [1]=killerName [2]=sideName | `BankDestroyed` (broadcast, both sides) | — | command | `:52-55` |
| `BankDividend` | [1]=amount | `BankDividend` | — | **group** | `:56-60` |
| `SiteClearanceCommanderOnly` | none | `SiteClearanceCommanderOnly` | — | command | `:61` |
| `SiteClearanceNeedsBarracks1` | none | `SiteClearanceNeedsBarracks1` | — | command | `:62` |
| `SiteClearanceNoTrees` | none | `SiteClearanceNoTrees` | — | command | `:63` |
| `SiteClearanceNoSupply` | [1]=cost | `SiteClearanceNoSupply` | — | command | `:64` |
| `SiteClearanceDone` | [1]=felled [2]=supplies | `SiteClearanceDone` | — | command | `:65` |
| `SiteClearanceOutsideBase` | none | `SiteClearanceOutsideBase` | — | command | `:66` |
| `Teamkill` | none | `STR_WF_CHAT_Teamkill` (penalty value) | **−penalty** | command | `:67` |
| `FundsTransfer` | [1]=amount [2]=senderName | `STR_WF_CHAT_FundsTransfer` + `playSound "cashierSound"` | — | **group** | `:68` |
| `StructureSold` | [1]=type [2]=object | `STR_WF_CHAT_Structure_Sold` (+ closest town) | — | command | `:69` |
| `StructureSell` | [1]=type [2]=delay [3]=object | `STR_WF_CHAT_Structure_Sell` (+ closest town + delay) | — | command | `:70` |
| `SecondaryAward` | [1]=label [2]=amount | `STR_WF_CHAT_Secondary_Award` | **+amount** | command | `:71` |
| `StructureTK` | [1]=name [2]=uid [3]=type [4]=extra | `STR_WF_CHAT_SatchelTK` | — | command | `:72` |
| `HeadHunterReceiveBounty` | [1]=killerName [2]=bounty [3]=kind [4]=side | bounty / friendly / enemy variant | **+bounty (own kill only)** | own=group, else command | `:75-100` |
| `HeadHunterReceiveBountyInSupplies` | [1]=sideKiller [2]=kind [3]=supplies [4]=side | `STR_WF_HeadHunterReceiveSuppliesEnemy` | — | command | `:101-114` |
| `BuildingKilledByError` | [1]=kind [2]=side | friendly / enemy variant | — | command | `:116-130` |
| `DefenseBudgetFull` | [1]=category [2]=used [3]=cap [4]=refund(num|classname) | `DefenseBudgetFull` | **+refund** | command | `:132-145` |
| `WddmCompositionCapReached` | [1]=count [2]=cap [3]=anchorClass | `WddmCompositionCapReached` | **+anchor price** | command | `:147-157` |
| `AIComDonation` | [1]=donorName [2]=amount | `STR_WF_CHAT_AIComDonation` | — | command | `:160` |
| `Wildcard` | [1]=display-ready text | passthrough (already localized) | — | command | `:163` |
| `DefenseThreatGate` | [1]=refund(num|classname) | `DefenseThreatGate` | **+refund** | command | `:165-178` |

## Local-funds cases (economy authority surface)

Six cases mutate the receiving player's funds locally rather than waiting on a server fund broadcast. Treat any change to these as an economy change, not cosmetic text.

| Case | Effect | Path:line |
| --- | --- | --- |
| `Teamkill` | charges `-(WFBE_C_PLAYERS_PENALTY_TEAMKILL) Call ChangePlayerFunds` | `:67` |
| `SecondaryAward` | pays `(_this select 2) Call ChangePlayerFunds` | `:71` |
| `HeadHunterReceiveBounty` | pays `_bounty call ChangePlayerFunds` only when `name player == _killer_name` | `:82-86` |
| `DefenseBudgetFull` | refund branch (see below) | `:137-143` |
| `WddmCompositionCapReached` | refund of anchor price (see below) | `:153-155` |
| `DefenseThreatGate` | refund branch (see below) | `:170-176` |

## The classname-string-vs-number refund branches

`DefenseBudgetFull`, `DefenseThreatGate`, and `WddmCompositionCapReached` exist because the WDDM defense-purchase path charges the client optimistically at placement time (the client subtracts the price locally), and when the server later rejects the placement the client must refund the exact amount it charged. The server cannot always price a WDDM anchor from a single global, so the refund argument is polymorphic.

| Case | Refund arg | Resolution | Path:line |
| --- | --- | --- | --- |
| `DefenseBudgetFull` | `_this select 4` | if `STRING`: `(missionNamespace getVariable _arg) select QUERYUNITPRICE Call ChangePlayerFunds`; if `NUMBER>0`: refund directly | `:137-143` |
| `WddmCompositionCapReached` | `_this select 3` (anchor classname, always string) | `(missionNamespace getVariable _anchorClass) select QUERYUNITPRICE Call ChangePlayerFunds` | `:153-155` |
| `DefenseThreatGate` | `_this select 1` | same string-vs-number test as `DefenseBudgetFull` | `:170-176` |

`QUERYUNITPRICE = 2` (`Common/Init/Init_CommonConstants.sqf:8`) — the price slot in the unit-config global. The string branch guards with `if (!isNil "_refGet")` so an unresolved classname is a no-op refund rather than an error. The corresponding server senders pass either a numeric price or the classname string from `Server/PVFunctions/RequestDefense.sqf:256,259,261,269,272,274`.

## The Teamstack join-order dependency

`Teamstack` does not format immediately. It blocks on `waitUntil { !(isNil {missionNamespace getVariable "WFBE_BLUFOR_SCORE_JOIN"}) && !(isNil {missionNamespace getVariable "WFBE_OPFOR_SCORE_JOIN"}) }` (`Client/PVFunctions/LocalizeMessage.sqf:30`), then reads both join-score globals, trims them to one decimal via `BIS_fnc_cutDecimals` (`:35-36`), and formats `STR_WF_CHAT_Teamstack` (`:38`). This relies on the join-answer path having already set those two variables; the older `while`/`sleep` retry loop is commented out (`:18-28,40-45`). Sender: `Server/Module/AntiStack/compareTeamScores.sqf:73,80`.

## Call sites (which tag comes from where)

| Tag(s) | Sender | Path:line |
| --- | --- | --- |
| `BuildingTeamkill`, `BankDestroyed`, `HeadHunterReceiveBounty`, `HeadHunterReceiveBountyInSupplies` | building-killed handler | `Server/Functions/Server_BuildingKilled.sqf:19,55,56,61,108` |
| `BuildingTeamkill`, `HeadHunterReceiveBounty` | HQ-killed handler | `Server/Functions/Server_OnHQKilled.sqf:71,75` |
| `CommanderDisconnected` | disconnect handler | `Server/Functions/Server_OnPlayerDisconnected.sqf:148` |
| `SiteClearance*` (6 tags) | site-clearance flow | `Server/Functions/Server_SiteClearance.sqf:46,57,78,136,145,167` |
| `Teamstack` | anti-stack comparator | `Server/Module/AntiStack/compareTeamScores.sqf:73,80` |
| `AttackModeActiveJIP`, `AttackModeActivated`, `AttackModeEnd` | attack-wave PVF | `Server/PVFunctions/AttackWave.sqf:9,13,46,60` |
| `AIComDonation` | AI-commander donate | `Server/PVFunctions/RequestAIComDonate.sqf:88` |
| `Wildcard` | AI-commander wildcard | `Server/Functions/AI_Commander_Wildcard.sqf:1297,1299` |
| `DefenseThreatGate`, `WddmCompositionCapReached`, `DefenseBudgetFull` | defense-request rejection | `Server/PVFunctions/RequestDefense.sqf:256,259,261,269,272,274` |
| `Teamswap` | join handler | `Server/PVFunctions/RequestJoin.sqf:22,38` |
| `Teamkill` | on-unit-killed | `Server/PVFunctions/RequestOnUnitKilled.sqf:247` |
| `CBRadarNeedsAAR`, `BankAlreadyBuilt`, `BankTooCloseToBase` | structure request | `Server/PVFunctions/RequestStructure.sqf:28,39,51` |
| `StructureSell`, `StructureSold` | sell-structure GUI | `Client/GUI/GUI_Menu_Economy.sqf:141,142,161,162` |
| `FundsTransfer` | transfer GUIs | `Client/GUI/GUI_Menu_Team.sqf:99`, `Client/GUI/GUI_TransferMenu.sqf:102` |
| `StructureTK` | on-fired satchel-TK | `Client/Functions/Client_FNC_OnFired.sqf:32` |

## Handler-only cases (no current LocalizeMessage sender)

Four cases are defined in the router but have no live `"LocalizeMessage"` sender in master:

- `BankDividend` (`:56-60`) — the live dividend notification is sent by a different path: `Client/PVFunctions/BankPayout.sqf:19` formats `Localize "BankDividend"` and calls `GroupChatMessage` directly, bypassing this router. The router case is redundant but harmless.
- `SecondaryAward` (`:71`) — no `"LocalizeMessage"` caller passes this tag in master (handler retained; verify before relying on it for awards).
- `TacticalLaunch` (`:48`) — no live sender found.
- `BuildingKilledByError` (`:116-130`) — friendly/enemy variant; no live `"LocalizeMessage"` sender in master (only the router case + stringtable keys `STR_WF_BuildingKilledByErrorFriendly/Enemy` exist). It is the only router case absent from both the Call-sites table and this section. Verify before wiring.

Confirm with a fresh `grep -rn '"<tag>"' --include=*.sqf` before wiring any of these, since a future feature may add a sender.

## Continue Reading

- [Networking And Public Variables](Networking-And-Public-Variables) — the PVF security model; this router is the "second-level router" / economy-authority surface it flags.
- [PVF Dispatch Implementation Playbook](PVF-Dispatch-Implementation-Playbook) — the `CLTFNC%1` / `SRVFNC%1` compile-and-dispatch mechanism end to end.
- [Public Variable Channel Index](Public-Variable-Channel-Index) — the full `WFBE_PVF_*` channel catalog this tag rides on.
- [Kill And Score Pipeline](Kill-And-Score-Pipeline) — `AwardBounty` and the head-hunter bounty source that feeds the `HeadHunterReceiveBounty` tag.
- [Economy Authority First Cut](Economy-Authority-First-Cut) — where local `ChangePlayerFunds` mutations fit in the client-optimistic economy.
