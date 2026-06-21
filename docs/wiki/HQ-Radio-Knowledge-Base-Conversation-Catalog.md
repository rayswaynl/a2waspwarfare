# HQ Radio Knowledge-Base Conversation Catalog (kbTell sentences, FSM reactions)

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted (other roots: Server/). Arma 2 OA 1.64.

Warfare's HQ radio announcer speaks through Arma 2's knowledge-base conversation system, not through `playSound`/`sideChat`. A logic-side announcer object (`wfbe_radio_hq`) is given an identity and a knowledge-base topic via `kbAddTopic`; gameplay code then calls `unit kbTell [receiver, topic, sentenceClass, ...args, true]`, and the engine renders the sentence's `text =` line into the radio subtitle while playing the per-word `speech[]` samples from the faction's `RadioAnnouncers_Config`. This page catalogs the three files that define that system — `Client/kb/hq.bikb` (the sentence database), `Client/kb/hq.fsm` (the reaction FSM), `Client/kb/hq.sqf` (the topic callback) — plus the `kbAddTopic` registration and every `kbTell` callsite.

This is the *client-side spoken-radio* half. The *server-side payload table* that decides which sentence class fires for which game event (the `SideMessage` switch over `Lost`/`Captured`/`Constructed`/...) lives in `Server/Functions/Server_SideMessage.sqf` and is documented as the "SideMessage Pipeline" in [Server-Gameplay-Runtime-Atlas](Server-Gameplay-Runtime-Atlas); the bottom of this page maps the two together.

## The three knowledge-base files

| File | Role | Size |
|---|---|---|
| `Client/kb/hq.bikb` | Sentence database — `class Sentences` of spoken-line classes (config text, not SQF) | 173 lines |
| `Client/kb/hq.fsm` | `WF_HQ` reaction FSM run when a sentence is *received* (BIS-FSM-editor config, not SQF) | 109 lines |
| `Client/kb/hq.sqf` | Topic callback compiled at registration — **empty** (single blank line) | 1 line |

The `hq.sqf` callback (`Client/kb/hq.sqf:1`) is an empty stub. It is the fourth argument to every `kbAddTopic` call and is compiled via `call compile preprocessFileLineNumbers "Client\kb\hq.sqf"`, but since the file is blank the topic has no per-sentence script callback — all reaction behaviour comes from the FSM, and the *meaningful* per-sentence rendering is the `text`/`speech[]` from the .bikb.

## Registration: kbAddTopic

The same topic id, .bikb, .fsm and (empty) .sqf callback are registered three times — twice on the client (the announcer object and the player both need the topic so the engine can speak and the player can receive), and once on the server when it builds the per-side announcer.

| Site (path:line) | Registrant | Topic id |
|---|---|---|
| `Client/Init/Init_Client.sqf:458` | `_HQRadio` (the `wfbe_radio_hq` announcer logic) | `WFBE_V_HQTopicSide` |
| `Client/Init/Init_Client.sqf:459` | `player` | `WFBE_V_HQTopicSide` |
| `Server/Init/Init_Server.sqf:491` | `_radio_hq1` (per-side announcer) | `_radio_hq_id` |

Client setup, in order: `_HQRadio = WFBE_Client_Logic getVariable "wfbe_radio_hq"` (`Client/Init/Init_Client.sqf:450`); `WFBE_V_HQTopicSide = WFBE_Client_Logic getVariable "wfbe_radio_hq_id"` (`:453`); `_HQRadio setIdentity WFBE_V_HQTopicSide` (`:455`); `setRank "COLONEL"` (`:456`); `setGroupId ["HQ"]` (`:457`); the two `kbAddTopic` calls (`:458-459`); then `sideHQ = _HQRadio` (`:460`) — `sideHQ` is the variable every client `kbTell` callsite names as the speaker.

Server side, the announcer identity is a *random* pick from the faction's announcer pool: `_radio_hq_id = (_announcers) select floor(random (count _announcers))` (`Server/Init/Init_Server.sqf:485`), then the same `setIdentity`/`setRank "COLONEL"`/`setGroupId ["HQ"]`/`kbAddTopic` sequence (`:488-491`), and `_logik setVariable ["wfbe_radio_hq_id", _radio_hq_id, true]` (`:492`) publishes it so the client reads the matching id at `Init_Client.sqf:453`.

## Sentence database — `Client/kb/hq.bikb`

The file is a `class Sentences` block (`hq.bikb:27`) of sentence classes. Each class has a `text =` subtitle string (literal or a `$STR...` stringtable key) and a `speech[] =` array of per-word sample tokens resolved against the faction `RadioAnnouncers_Config`. `%1`/`%2`/`%3`/`%4` are positional argument slots filled by the `kbTell` call; each filled slot is declared in a `class Arguments` sub-block of `type = "simple"`.

### Macros

Three preprocessor macros generate the bulk of the one-word and keyed sentences:

| Macro (path:line) | Expands to | Subtitle source | speech[] shape |
|---|---|---|---|
| `SENTENCE(NAME)` | `hq.bikb:1-7` | `text = $STR<NAME>` (stringtable key `STR` + class name) | `{%1, NAME, %2}` (announcer word sits between two arg slots) |
| `SENTENCE1(NAME)` | `hq.bikb:9-15` | `text = $STR<NAME>` | `{NAME, %1, %2}` (announcer word first) |
| `SENTENCE_KEY(NAME,KEY)` | `hq.bikb:18-24` | `text = $<KEY>` (explicit stringtable key) | `{%1, NAME, %2}` |

### Explicit (hand-written) sentence classes

These are spelled out in full rather than macro-generated. The `text` column is the literal subtitle template as it appears in the file.

| Class (path:line) | `text` subtitle | `speech[]` words | args |
|---|---|---|---|
| `Test` (`hq.bikb:30`) | `Test` | `{lopotev_present_in_hideout_1_R_1}` | none — leftover test class |
| `HQ` (`hq.bikb:34`) | `$STR_DN_WARFARE_HQ_BASE_UNFOLDED` | `{HQ}` | none |
| `CapturedNear` (`hq.bikb:36`) | `%1 captured near %2` | `{%1, CapturedNear, %2}` | 1, 2 |
| `LostAt` (`hq.bikb:46`) | `%1 lost at %2` | `{%1, LostAt, %2}` | 1, 2 |
| `OrderSent` (`hq.bikb:52`) | `%1 %2, %3` | `{%1, %2, %3}` | 1, 2, 3, 4 |
| `OrderSentAll` (`hq.bikb:63`) | `%1, %2, %3` | `{%1, %2, %3}` | 1, 2, 3 |
| `OrderDone` (`hq.bikb:73`) | `%1, %2 %3 %4` | `{%1, %2, %3, %4}` | 1, 2, 3 |
| `simple` (`hq.bikb:83`) | `%1` | `{%1}` | 1 |
| `ExtractionTeam` (`hq.bikb:91`) | `This is HQ, %1 is on the way, out.` | `{ThisIs, HQ, %1, Is, OnTheWay, Out}` | 1 |
| `ExtractionTeamCancel` (`hq.bikb:99`) | `This is HQ, Abort the op, %1 is in danger, out.` | `{ThisIs, HQ, aborttheop, %1, Is, In, DangerE, Out}` | 1 |
| `MMissionFailed` (`hq.bikb:107`) | `This is HQ, Mission Failure, carry on with your prior tasks, over.` | `{ThisIs, HQ, MissionFailure, CarryOnWithYourPriorTasksOver}` | none |
| `MMissionComplete` (`hq.bikb:113`) | `This is HQ, %1` | `{ThisIs, HQ, %1}` | 1 |

### Macro-generated sentence classes

All resolve through the macros above. `SENTENCE`/`SENTENCE1` keys derive from the class name (`$STR<name>`); `SENTENCE_KEY` names an explicit stringtable key. Grouped by use, in file order.

| Class (path:line) | Macro | Subtitle key |
|---|---|---|
| `10MinutesLeft` (`hq.bikb:122`) | SENTENCE | `$STR10MinutesLeft` |
| `20MinutesLeft` (`hq.bikb:123`) | SENTENCE | `$STR20MinutesLeft` |
| `5MinutesLeft` (`hq.bikb:124`) | SENTENCE | `$STR5MinutesLeft` |
| `Accomplished` (`hq.bikb:125`) | SENTENCE | `$STRAccomplished` |
| `BaseUnderAtack` (`hq.bikb:127`) | SENTENCE_KEY | `$STRwfbaseunderattack` |
| `Cancelled` (`hq.bikb:128`) | SENTENCE | `$STRCancelled` |
| `CanDoWereOnIt` (`hq.bikb:129`) | SENTENCE | `$STRCanDoWereOnIt` |
| `Captured` (`hq.bikb:130`) | SENTENCE | `$STRCaptured` |
| `HC_OrderReceived` (`hq.bikb:131`) | SENTENCE_KEY | `$Order Received` |
| `CiviliansUnderEnemyFireIn` (`hq.bikb:132`) | SENTENCE1 | `$STRCiviliansUnderEnemyFireIn` |
| `Constructed` (`hq.bikb:133`) | SENTENCE_KEY | `$STRwfstructureconstructed` |
| `Deployed` (`hq.bikb:134`) | SENTENCE | `$STRDeployed` |
| `Destroyed` (`hq.bikb:135`) | SENTENCE_KEY | `$STRwfbasestructuredestroyed` |
| `EnemyBaseLocated` (`hq.bikb:136`) | SENTENCE | `$STREnemyBaseLocated` |
| `EnemyForcesDetected` (`hq.bikb:137`) | SENTENCE | `$STREnemyForcesDetected` |
| `Failed` (`hq.bikb:138`) | SENTENCE | `$STRFailed` |
| `HostilesDetectedNear` (`hq.bikb:139`) | SENTENCE1 | `$STRHostilesDetectedNear` |
| `Insufficient` (`hq.bikb:140`) | SENTENCE1 | `$STRInsufficient` |
| `IsUnderAttack` (`hq.bikb:141`) | SENTENCE_KEY | `$STRwftownunderattack` |
| `Lost` (`hq.bikb:143`) | SENTENCE | `$STRLost` |
| `Mobilized` (`hq.bikb:145`) | SENTENCE | `$STRMobilized` |
| `NegativeWeCannotDivert` (`hq.bikb:146`) | SENTENCE | `$STRNegativeWeCannotDivert` |
| `NewIntelAvailable` (`hq.bikb:147`) | SENTENCE | `$STRNewIntelAvailable` |
| `NewMissionAvailable` (`hq.bikb:148`) | SENTENCE | `$STRNewMissionAvailable` |
| `NewSupportAvailable` (`hq.bikb:149`) | SENTENCE | `$STRNewSupportAvailable` |
| `UnderAttack` (`hq.bikb:151`) | SENTENCE_KEY | `$STRisunderattack` |
| `VotingForNewCommander` (`hq.bikb:152`) | SENTENCE_KEY | `$STRwfvoteforcommanderinprogress` |

The trailing block (`hq.bikb:154-168`) is the *structure/resource noun* vocabulary used as the `%1` fill-word (`[_value]`) of `Constructed`/`Destroyed`/etc. — not standalone announcements:

| Class (path:line) | Macro | Subtitle key |
|---|---|---|
| `AntiAirRadar` (`hq.bikb:154`) | SENTENCE | `$STRAntiAirRadar` |
| `ArtilleryBattery` (`hq.bikb:155`) | SENTENCE | `$STRArtilleryBattery` |
| `ArtilleryRadar` (`hq.bikb:156`) | SENTENCE | `$STRArtilleryRadar` |
| `Barracks` (`hq.bikb:157`) | SENTENCE_KEY | `$STRwfbarracks` |
| `Funds` (`hq.bikb:158`) | SENTENCE | `$STRFunds` |
| `Headquarters` (`hq.bikb:159`) | SENTENCE | `$STRHeadquarters` |
| `HeavyVehicleSupply` (`hq.bikb:160`) | SENTENCE | `$STRHeavyVehicleSupply` |
| `Helipad` (`hq.bikb:161`) | SENTENCE | `$STRHelipad` |
| `LightVehicleSupply` (`hq.bikb:162`) | SENTENCE | `$STRLightVehicleSupply` |
| `Mission` (`hq.bikb:163`) | SENTENCE | `$STRMission` |
| `Resources` (`hq.bikb:164`) | SENTENCE | `$STRResources` |
| `ServicePoint` (`hq.bikb:165`) | SENTENCE | `$STRServicePoint` |
| `Strongpoint` (`hq.bikb:166`) | SENTENCE | `$STRStrongpoint` |
| `Supplies` (`hq.bikb:167`) | SENTENCE | `$STRSupplies` |
| `UAVTerminal` (`hq.bikb:168`) | SENTENCE | `$STRUAVTerminal` |

### Trailer (outside `class Sentences`)

| Declaration (path:line) | Meaning |
|---|---|
| `class Arguments{}` (`hq.bikb:170`) | Empty top-level args block — conversation-system boilerplate |
| `class Special{}` (`hq.bikb:171`) | Empty `Special` topic class — boilerplate; not referenced by any `kbTell` callsite in Client/Server/Common |
| `startWithVocal[] = {hour}` (`hq.bikb:172`) | Article-elision hint (a/an) |
| `startWithConsonant[] = {europe, university}` (`hq.bikb:173`) | Article-elision hint |

## Reaction FSM — `Client/kb/hq.fsm`

`fsmName = "WF_HQ"` (`hq.fsm:24`), compiled from the BIS FSM editor (header `WF_HQ`, `hq.fsm:1`). It runs on the *receiver* when a sentence arrives, with `_sentenceId`/`_from`/`_topic` in scope. The graph is a near-verbatim copy of the campaign `CooperGalkinaScene` reaction template — its conditions key on sentence ids (`Cooper_ComeOnWithMe`, `Interrupted`) that **no Warfare `kbTell` callsite ever sends**, so in normal play the React state immediately falls through its `true`-priority link to `END`. It is effectively an inert/no-op reaction graph kept as a stub. `initState = "React"` (`hq.fsm:102`); `finalStates[] = {"END", "___Nervous_anim", "Come_on__come"}` (`hq.fsm:103-108`).

| State (path:line) | Role | Links (to / condition) |
|---|---|---|
| `React` (`hq.fsm:28`) | Entry. `init` debug-logs the sentence if `BIS_DEBUG_DIALOG` is set (`hq.fsm:31`); otherwise inert | → `___Nervous_anim` if `_sentenceId in ["Cooper_ComeOnWithMe"]` (prio 1, `:39-41`); → `Come_on__come` if `_sentenceId in ["Interrupted"]` (prio 1, `:49-51`); → `END` on `true` (prio 0, `:59-61`) |
| `END` (`hq.fsm:69`) | Terminal no-op (`init = ""`) | none |
| `___Nervous_anim` (`hq.fsm:80`) | Galkina nervous-escape scene (spawns animation, `rKBTELL Galkina_NoNoMore`, `hq.fsm:83`) — dead campaign code, never reached in Warfare | none |
| `Come_on__come` (`hq.fsm:91`) | Sends `rKBTELL ... Cooper_ComeOnWithMe` (`hq.fsm:94`) — dead campaign code, never reached | none |

Because every `React` transition except the unconditional `→ END` requires a campaign-only sentence id, the practical behaviour is: receive sentence → (optional debug log) → END. The HQ radio's user-visible output is entirely the .bikb subtitle + speech samples; the FSM adds nothing in Warfare.

## kbTell trigger sites

Two distinct producers fire sentences from this topic: **player-initiated order chatter** (client GUI / task code, speaker = `sideHQ`, receiver = `player`) and the **server SideMessage dispatcher** (speaker/receiver = the per-side radio logic). Every call ends with the trailing `true` (the "force radio" / commit flag).

### Player-initiated (client)

| Site (path:line) | Sentence class | Trigger |
|---|---|---|
| `Client/GUI/GUI_Menu_Command.sqf:296` | `OrderSent` | Move order to a specific team set (`Team ...`, MenuAction move branch, `!_isAll`) |
| `Client/GUI/GUI_Menu_Command.sqf:303` | `OrderSentAll` | Move order to *all* teams (`_isAll`) |
| `Client/GUI/GUI_Menu_Command.sqf:330` | `OrderSent` | Set-Task order (MenuAction 306) to a specific team set |
| `Client/GUI/GUI_Menu_Command.sqf:340` | `OrderSentAll` | Set-Task order (MenuAction 306) to all teams |
| `Client/PVFunctions/SetTask.sqf:34` | `OrderDone` | A SimpleTask completes (`_succeed`) — squad reports "HQ, We are ready for orders, over." |

Example argument shape (`GUI_Menu_Command.sqf:296`): `player kbTell [sideHQ, WFBE_V_HQTopicSide, "OrderSent", ["1","",_sideTeam,[if (sideJoined == west) then {"blueTeam"} else {"redTeam"}]], ["2","","moving to position",["HC_MovingToPosition"]], ["3","","over.",["Over1"]], true]` — each `["idx","",displayString,[speechToken]]` tuple fills one positional `%n` with a subtitle fragment and its spoken word.

### Server SideMessage dispatcher

`Server/Functions/Server_SideMessage.sqf` is the bound `SideMessage` function (`SideMessage = Compile preprocessFile "Server\Functions\Server_SideMessage.sqf"`, `Server/Init/Init_Server.sqf:39`). It resolves the per-side radio logic (`wfbe_radio_hq` speaker, `wfbe_radio_hq_rec` receiver, `wfbe_radio_hq_id` topic, `:8-12`), guards against a base-less faction (`if (isNull _speaker) exitWith {}`, `:10`), then `switch (true)` selects the `kbTell` form by message class:

| Site (path:line) | Sentence classes handled | Argument fill |
|---|---|---|
| `Server/Functions/Server_SideMessage.sqf:22` | `Lost`, `Captured`, `HostilesDetectedNear` | one arg: town/object real name (`_rlName`) with `_dub` speech token |
| `:31` | `CapturedNear`, `LostAt` | two args: capturing-side label + the town name/dub |
| `:57` | `Constructed`, `Destroyed`, `Deployed`, `Mobilized`, `IsUnderAttack` | one arg: localized structure noun + its vocabulary token (`Headquarters`/`Barracks`/`LightVehicleSupply`/...) |
| `:60` | `VotingForNewCommander`, `NewIntelAvailable`, `MMissionFailed`, `NewMissionAvailable` | no args (bare `kbTell [_receiver,_topicSide,_message,true]`) |
| `:63` | `MMissionComplete`, `ExtractionTeam`, `ExtractionTeamCancel` | one arg: `_parameters select 0` text with `select 1` speech token |

The `Constructed`/`Destroyed` branch (`:34-56`) is where the structure-noun vocabulary block from the .bikb is consumed: it maps `wfbe_structure_type` (`Headquarters`/`Barracks`/`Light`/`CommandCenter`/`Heavy`/`Aircraft`/`ServicePoint`/`AARadar`) to a localized string + a `_value` token that becomes the `%1` speech word. Note `CommandCenter` resolves its spoken token to `UAVTerminal`, switching to `CommandPost` for Arrowhead / west-CombinedOps (`:43-45`).

## How the two halves connect

```
                 client GUI / task                  server game events
                 (move/task orders)                 (town capture, build, votes...)
                       |                                     |
   player kbTell [sideHQ, topic, "OrderSent"...]   [side,"Lost",town] call SideMessage
                       |                                     |
                       |                            Server_SideMessage.sqf switch
                       |                              picks sentence class + args
                       +------------------+------------------+
                                          |
                          hq.bikb  class <Name> { text=...; speech[]=... }
                                          |
                          engine renders subtitle + plays speech[] words
                                          |
                          receiver runs hq.fsm (WF_HQ) -> React -> END (no-op)
                                          |
                          hq.sqf topic callback (empty) -> nothing
```

The .bikb is the shared vocabulary both producers draw from; the client GUI path and the server SideMessage path are independent triggers into it. The FSM and .sqf callback are stubs that add no behaviour in Warfare — the radio's entire observable output is the .bikb `text`/`speech[]` rendering. For the *event→class* decision table on the server side (which game event maps to `Lost` vs `CapturedNear` vs `Constructed`), see the SideMessage section of [Server-Gameplay-Runtime-Atlas](Server-Gameplay-Runtime-Atlas).

## Continue Reading

- [Server-Gameplay-Runtime-Atlas](Server-Gameplay-Runtime-Atlas) — the server-side SideMessage payload table: which game event maps to which sentence class, the sibling of this client-side spoken catalog.
- [LocalizeMessage-Chat-Notification-Router-Reference](LocalizeMessage-Chat-Notification-Router-Reference) — the *text-chat* notification router (a separate, non-radio channel for player-facing messages).
- [Mission-Audio-Catalog](Mission-Audio-Catalog) — the `CfgSounds`/`CfgMusic` registry and `playSound` cues, the other audio path distinct from kbTell speech samples.
- [Commander-HQ-Lifecycle-Atlas](Commander-HQ-Lifecycle-Atlas) — the HQ/commander lifecycle behind the announcer logic and the `wfbe_radio_hq` per-side object.
- [Quad-AI-Commander](Quad-AI-Commander) — the AI commander that drives many of the server events feeding the SideMessage radio announcements.
