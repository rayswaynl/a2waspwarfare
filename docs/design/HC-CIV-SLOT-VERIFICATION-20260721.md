# HC CIV slot verification — `forceHeadlessClient` on A2 OA 1.64

Card: `wasp-zg-civ-hc-slots-20260719` — owner live report (ZG match 2026-07-19 ~15:20):
`HC-AI-Control-2` visible in a **GUER** lobby slot.
Status: proposal + evidence for review. Nothing here has been deployed.

---

## 0. What changed on master since the card was written

PR **#1162** merged 2026-07-21 05:03Z (`de7475e9d9`). Master now carries two dedicated
`side="CIV"`, `forceHeadlessClient=1` slots per rotation mission:

| Terrain | HC slot ids | mission.sqm lines |
|---|---|---|
| Chernarus | 9009 / 9010 | 5303, 5324 |
| Takistan  | 7034 / 7035 | 3715, 3736 |
| Zargabad  | 114 / 115   | 1634, 1655 |

The two legacy `description="RESERVED -- HC / do not use"` CIV rows (CH ids 229/230) are
still present and untouched. This document does **not** re-litigate that shape — it answers
the owner's STEP ONE question about it, repairs one regression it introduced, and closes the
stats half of the card.

---

## 1. STEP ONE — is `forceHeadlessClient` honoured on our exact build?

The owner's 2026-07-20 spec flagged this as a known false-fact trap ("A2-vs-A3 attribute
support; prove, do not assume"). `Headless/Init/Init_HC.sqf:22-23` asserts it exists but is
unreliable:

> `forceHeadlessClient=1 exists in A2 OA 1.63+, but it has not been reliable`
> `enough across boot/restart slot races in this mission, so the script reseat remains authoritative.`

Per `a2oa-verify-command`, an in-source comment is a **lead, not proof**. So it was probed
against the shipped engine.

### Method

Byte-scan the installed A2 OA executables for the literal token. A mission.sqm attribute
name must exist as a string in the binary that parses it; absence from every engine binary
would mean the attribute is silently ignored. Positive and negative controls validate that
the scan discriminates. Reproducible: `Tools/Probe/Probe-EngineString.ps1`.

### Result — `ArmA2OA.exe` and `arma2oaserver.exe`, ProductVersion **1.64.0.144629**

```
XWT|enginestr|PRESENT|forceHeadlessClient|hits=1|firstOffset=0x848D98   <- target
XWT|enginestr|PRESENT|disabledAI          |hits=1|firstOffset=0x83E758  <- control (known-good)
XWT|enginestr|PRESENT|synchronizations    |hits=1|firstOffset=0x843CF0  <- control (known-good)
XWT|enginestr|PRESENT|descriptionShort    |hits=2|firstOffset=0x858144  <- control (known-good)
XWT|enginestr|ABSENT |isPlayable          |hits=0                       <- control (A3-only)
XWT|enginestr|PRESENT|headlessClient      |hits=1|firstOffset=0x83F2D4
```

Both binaries returned identical verdicts. The A3-only control is correctly absent, so a
PRESENT result is meaningful rather than an artifact of scanning a 13 MB file.

Neighbourhood dumps place the tokens precisely:

- `0x848D98` — `... markers | health | forceHeadlessClient | forceInServer | special |
  presenceCondition | presence | Sensors | Waypoints | Vehicles | Markers | Groups | Intel ...`
  This is the **mission.sqm entity-attribute table**, sitting between `health` and
  `forceInServer` and immediately before the mission.sqm class names.
- `0x83F2D4` — `... missionVotes | missions | hostname | headlessClient | build | fullname |
  squad | ... | playerid | steamID | desync | avgPing | nick ...`
  This is the **per-client network record**: the engine tracks headless-client identity as a
  field on a connected client.

### Verdict

**`forceHeadlessClient` is a real, parsed A2 OA 1.64 mission.sqm attribute.** It is not an
Arma 3 false fact, and the slots merged in #1162 are not inert markup. Headless-client
identity also exists at the engine's network layer on this build.

### Honest limit

This proves the token is **read**. It does not prove the **seating outcome** — whether the
engine assigns an HC to those slots first, how it behaves across the boot/restart slot races
`Init_HC.sqf` complains about, or what happens when an HC reconnects mid-match. That is a
runtime question, and §2 makes it answerable on the next boot without new code.

Not recorded to the wiki `Arma-2-OA-Command-Version-Reference` page (ladder rung 5): agents
do not publish public content. Recommend the owner add it.

---

## 2. Getting the seating answer from the next boot — no new mission code

`Server/Functions/Server_HandleSpecial.sqf:1574` already emits, on every HC connect:

```
HCSIDE|v1|preseat|name=<hc>|engineSide=<side>
```

This is logged **before** `WFBE_HC_FNC_ReseatCivilian` runs, so it records the side the
*engine* chose. That is exactly the STEP ONE runtime answer:

| `engineSide=` | Meaning |
|---|---|
| `CIV` | The engine seated the HC into a dedicated `forceHeadlessClient` slot. Attribute honoured. |
| `WEST` / `EAST` / `GUER` | The engine grabbed a faction slot. Attribute not honoured on this build — the owner's live report reproduced. |

`Tools/Smoke/Test-WaspBootSmoke.ps1` gains an **`HCPRESEAT`** check that grades this
automatically. It is advisory by design: it reports `WARN` and never trips the boot verdict,
because `HCSEAT` already gates the outcome that matters (side ends up CIV) and the script
reseat repairs a faction preseat either way. Once a boot shows `engineSide=CIV`, set
`RequireHcPreseat = true` to lock the behaviour in as a hard gate.

The bundled PASS fixture (`Tools/Smoke/fixtures/boot_pass.server.rpt`) predates the dedicated
slots and records `engineSide=WEST` — i.e. the repo's own fixture documents the bug. The
self-test asserts all four states (WARN / PASS on CIV / FAIL under `RequireHcPreseat` / SKIP
when no preseat line exists).

**Owner action:** boot the test box on current master and run

```powershell
pwsh -File Tools\Smoke\Test-WaspBootSmoke.ps1 -ServerRpt <arma2oaserver.RPT>
```

The `HCPRESEAT` row is the answer. A bare `findstr "HCSIDE|v1|preseat"` on the RPT works too.

---

## 3. Staged join window — the design as specified cannot be built today

The 2026-07-20 spec: boot passworded → HCs connect with `-password` → automation strips the
password via **rcon** once HCs are seated → players join. Each leg was checked against the repo:

| Requirement | State today | Source |
|---|---|---|
| Lobby join `password` in server cfg | **Absent.** Only `passwordAdmin` (redacted, set on box). | `server-config/server-pr8.cfg:3` |
| `-password` on the HC startup lines | **Absent.** Both HCs connect to `127.0.0.1` with no join password. | `server-config/hc_launch.cmd:6`, `hc2_launch.cmd:14` |
| An rcon path to strip it at runtime | **Does not exist.** No BattlEye RCon client or library anywhere in the repo. | repo-wide search |
| BattlEye enabled (prerequisite for BE RCon) | **`BattlEye = 0`** on the box, which makes BE RCon inert. | `server-config/server-pr8.cfg:6` |

So the staged window needs, at minimum: a lobby password added to the live cfg, `-password`
added to both HC launch commands, BattlEye turned **on**, a BE RCon password configured, and
a new rcon client written and scheduled — on box scripts that live only at `C:\WASP\*` and are
outside this repo. Enabling BattlEye also collides with `server-config/README.md:37`, which
records that `verifySignatures`/`BattlEye` were deliberately disabled for the optional-mods box.

That is an owner-only infrastructure decision, not a draft-PR change, so nothing here
implements it.

### Cheaper alternatives, in the order worth trying

1. **Do nothing yet.** If §2's boot shows `engineSide=CIV`, the ordering problem is solved by
   the engine: humans cannot select a `forceHeadlessClient` slot, so "players before HCs" stops
   mattering. Test before building.
2. **`#lock` / `#unlock`.** A logged-in admin can lock the lobby during HC seating with no
   password, no BattlEye, and no cfg change. Still needs an admin identity to issue it, but it
   is a far smaller change than the rcon path.
3. **Serialised HC launch.** `docs/design/HC-SLOT-SEATING.md` §6.2 already recommends replacing
   the current kill/relaunch dance with a serialised launch + fixed wait — this reduces the
   boot/restart slot race that `Init_HC.sqf:22` blames, independently of any lobby lock.

---

## 4. Regression repaired: slot-count gate

`Tools/Ops/Test-WaspSlotCountConsistency.ps1` compares `WF_MAXPLAYERS` against `player=`
declarations. PR #1162 added two declarations per mission, so Chernarus went 36 → 38 against a
template of 36 and the gate started failing:

| Commit | Chernarus | Takistan | Zargabad |
|---|---|---|---|
| `80c690257f` (pre-#1162 base) | 36 vs 36 **PASS** | 61 vs 34 FAIL | 61 vs 34 FAIL |
| `b716e32cab` (master, post-merge) | 36 vs 38 **FAIL (new)** | 61 vs 36 FAIL | 61 vs 36 FAIL |

Takistan/Zargabad were already mismatched long before this card; only the Chernarus row is new.

**Fix: the checker, not the mission.** `WF_MAXPLAYERS` reaches the engine as
`Rsc/Header.hpp` → `maxPlayers`, which is human capacity — it is what the server browser
advertises and what `Server/Init/Init_Server.sqf:207` reads back into
`MATCH|v1|START|maxPlayers=`. A slot reserved for a headless client is not human capacity, and
the mission-folder convention (`[55-2hc]`) already makes that split. Bumping the template to 38
would assert the lobby grew by two human seats — which is the opposite of what this card fixed —
and would misreport in MATCH telemetry.

The checker now counts `forceHeadlessClient=1` slots separately and compares `WF_MAXPLAYERS`
against human slots only:

```
PASS  Chernarus: WF_MAXPLAYERS=36, playable slots=36 (38 declared - 2 headless-client slot(s))
FAIL  Takistan:  WF_MAXPLAYERS=61, playable slots=34 (36 declared - 2 headless-client slot(s))
FAIL  Zargabad:  WF_MAXPLAYERS=61, playable slots=34 (36 declared - 2 headless-client slot(s))
```

That is exactly the pre-#1162 state restored. **No mission.sqm or template file was touched**,
so this carries zero runtime risk. Slot detection is a brace-scan of the enclosing entity block
(not a naive count), so an `init="...{...}..."` string cannot skew it, and a real human slot
added alongside HC slots still trips the gate — both covered by new fixture tests.

The legacy TK/ZG `61 vs 34` mismatch is left alone: it predates this card, and changing those
templates is a lobby-capacity decision for the owner.

---

## 5. Stats pollution closed

Card item (d): HC UID `76561198689465519` appeared inside `WASPSTAT` stat lines.

The root cause is that every stat call site treats `getPlayerUID != ""` as the HC filter, while
`Server/Functions/Server_HandleSpecial.sqf:1626-1627` states outright that **"A2 HCs can report
an empty/shared UID"**. When an HC reports a non-empty UID its rows enter the pipeline exactly
like a human's. Secondary cause: three disagreeing HC-name arrays exist in the tree, and the one
in `StatsFlush.sqf` does not know `"HC-AI-Control-3"`.

Fix — reuse the stamp the connected-hc handler already writes (`WFBE_HEADLESS_<uid>`), which
`Server/Functions/Server_OnPlayerConnected.sqf:28` calls *"the SOLE HC-identification gate:
stamp-based, un-spoofable"*. New shared predicate `WFBE_SE_FNC_IsHeadlessUid`, O(1), no new state:

| File | Change |
|---|---|
| `Server/Stats/RecordStat.sqf` | Predicate defined here; `RecordStat` + `RecordStatSide` reject stamped HC uids. This is the funnel for **all 13** RecordStat call sites, so one guard covers town/camp captures, structures, defenses, supply runs, kills, deaths and factory/HQ kills. |
| `Server/Stats/StatsFlush.sqf` | Stamp check added next to the name list (covers HC names the list does not know); plus a **retroactive purge** at flush — rows buffered during the window between an HC connecting and registration stamping it are dropped, never emitted, with one `HCSTAT\|v1\|PURGE\|<uid>` RPT line as evidence. |
| `Server/PVFunctions/RequestOnUnitKilled.sqf` | The raw `WASPSTAT\|v1\|..\|KILL\|` emitter builds its own UID fields from `isPlayer`; a stamped HC uid is blanked to `""`, the same field shape a non-player killer already produces, so RPT parsers need no change. |

Deliberately **not** touched: `Server_HandleSpecial.sqf`'s connected-hc registration and the
rest of the HC/enrollment path (owner constraint). The retroactive purge lives entirely inside
the stats layer for that reason.

Not fixed here (out of scope, worth a card): the three divergent HC-name arrays should be one
shared constant, and `Server/FSM/server_playerstat_loop.sqf:49` performs an array subtraction of
a Group array from an Object array that cannot remove anything — harmless only because the
explicit per-unit check on line 58 does the real work.

---

## 6. Deferred with rationale: the mission-side kick guard

Spec item (3) — kick a non-HC seated in an HC-CIV slot, and kick an HC seated outside CIV — is
**not** implemented here, for two reasons:

1. It is squarely inside `CLAUDE.md`'s *"Never touch: HC architecture, player enrollment/JIP
   flow"* owner constraint. It needs the owner's explicit go-ahead, not an agent's inference
   from a relayed chat note.
2. Its necessity is unknown until §2's boot runs. If the engine honours the attribute, a human
   *cannot* select an HC slot and half the guard is dead code; the other half (HC outside CIV)
   is already handled non-destructively by the existing reseat + the 15s watcher.

`docs/design/HC-SLOT-SEATING.md` §7.B also records that a name-based HCGUARD block was
**deliberately removed** from `Server_OnPlayerConnected.sqf` because *"player names are user-set
and cannot serve as an authentication signal"* — a human named `HC` was stuck in lobby forever.
Any future guard must key off the server-side owner stamp, never a name, or it will reintroduce
that bug.

If the owner wants it after the boot test, the safe shape is: detection + one always-on WARNING
line unconditionally, and the kick itself behind a new flag defaulting to 0.

---

## 7. Verification performed

| Gate | Result |
|---|---|
| `Tools/Ops/Test-WaspSlotCountConsistency.ps1` | Chernarus PASS restored; TK/ZG unchanged legacy FAIL |
| `Tools/Ops/Test-WaspSlotCountConsistency.Tests.ps1` | 14/14 assertions PASS (4 new, incl. HC split + drift-still-caught) |
| `Tools/Smoke/Test-WaspBootSmoke.ps1 -SelfTest` | 15/15 PASS (5 new HCPRESEAT assertions) |
| `Tools/Ops/Test-WaspVersionTemplates.ps1` | PASS (all terrains) |
| SQF lint gate (19 codes) | 0 findings in all 9 edited SQF files |
| Bracket delta per edited SQF file | curly 0, square 0 (9/9) |
| LoadoutManager mirror + `--check` | TK and ZG drift: none |
| TK/ZG `version.sqf.template` | restored to `origin/master`, guard PASS |

**Not verified — needs the test box:** that an HC actually lands in a CIV slot at boot, and
that it still does after a mid-match reconnect. §2 is the procedure; the `HCPRESEAT` row is the
verdict. No live-server action was taken.
