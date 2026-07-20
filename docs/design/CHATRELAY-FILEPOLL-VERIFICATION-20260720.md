# Chat Relay — Engine Verification Report (game↔Discord bridge)

- **Date:** 2026-07-20 · **Lane:** kimi-main-0718184346-1 · **Task:** `wasp-discord-chat-bridge-20260720`
- **Engine:** Arma 2 OA **1.64.144629** (Steam `Arma 2 Operation Arrowhead\arma2oaserver.exe`, exact target build)
- **Method:** rung-4 offline engine probe per `a2oa-verify-command` — local dedicated server (`BattlEye = 0`, `persistent = 1`) + local client on 127.0.0.1, minimal mission `XWTChat.Desert_E`, all probes `diag_log "XWT|<id>|<expr>|<result>"`-tagged and read back from the RPTs. Ladder rungs 1–2 (repo wiki + BI wiki OA category) settled command *existence* (`loadFile`, `publicVariableServer` ≥ OA 1.62, `diag_log`, `findDisplay`/`displayCtrl`/`ctrlText`/`displayAddEventHandler` — the latter also in live source); the probes below settled *semantics*.
- **Owner decision covered:** one-way game→Discord now (no BattlEye, no RCon, no DLLs); Discord→game investigated here for a possible later two-way behind a default-0 flag.

---

## A. Outbound tap (game → Discord) — **PROVEN**

The client tap ships in PR #1198 (`Client/Functions/Client_ChatRelayTap.sqf` + server PVEH), the producer in miksuus-warfare PR #103. Probe verdicts:

| # | Construct | Result |
|---|---|---|
| A1 | Chat display identity | `findDisplay 24` goes non-null exactly while the chat line is open (`XWT|C10-display-appeared|idd=24`, `C20`, `C22`). |
| A2 | Chat edit control | IDC **101** is the only control on display 24; `ctrlText` of it tracks keystrokes live (`XWT|C21-idc|idc=101`, `C30-key|...|idc101=bigger` → `biggers`). |
| A3 | Capture point | A `KeyDown` `displayAddEventHandler` on display 24 fires **before** the engine consumes Enter (DIK 28 / numpad 156); full submitted text readable at EH time. |
| A4 | Non-interference | EH returning `false` leaves the engine send path intact (normal chat flow observed alongside capture). |
| A5 | Transport | `publicVariableServer "XWT_CHAT_PV"` from the client fired the server PVEH; server RPT: `XWT|CHAT-PV-RECV|payload=["xwtclient","\|idc101=biggers"]` (11:56:18Z run 2) — the exact path `WFBE_CHATRELAY` uses. |
| A6 | History keys | Up-arrow (DIK 200) also arrives via the EH — relay must fire on Enter only (it does). |

Note on probe noise: synthetic `SendKeys` input does **not** reliably land text in the edit box (DirectInput) — the definitive A2–A5 evidence is a real human-typed session on the rig; the mechanism itself was additionally re-confirmed by repeated EH fires across runs.

## B. Inbound channel (Discord → game) via file-poll — **VIABLE ONLY AS ONE-SHOT SLOTTED FILES**

The naive "server re-reads an externally rewritten file" design is **dead on OA 1.64**. One pattern survives.

### B1. Path resolution (`loadFile`)

| Probe | Path form | Result |
|---|---|---|
| F1 | `loadFile "poll_in.txt"` (mission-dir relative) | ✅ reads file |
| F2 | `loadFile "polldir\poll_sub.txt"` (mission subdir) | ✅ reads file |
| F3 | `loadFile "poll_root.txt"` (file in the **Arma 2 OA root dir**, outside the mission folder) | ✅ reads file — **no `-filePatching` needed on OA 1.64** (the BIKI comment claiming otherwise is A3-era) |
| F4 | `loadFile "C:\Users\...\xwt_poll_abs.txt"` (absolute) | ❌ returns `""` |

### B2. Re-read semantics — the killers

| Probe | Attempt | Result |
|---|---|---|
| F1/F5/F6 loop (300 × 2 s) with a live external writer (40 attempts, `[IO.File]::Open(...,'Write','ReadWrite')` + retries) | rewrite an already-read file | **0/40 writes succeeded** — after the first successful read the server process holds the file with a lock that blocks writers **for the process lifetime** (`The process cannot access the file ... being used by another process`) |
| copy-over replace (`[IO.File]::Copy(tmp, target, $true)`) | blocked the same way | ❌ |
| rename (`Move-Item`) then recreate | rename blocked (no delete-share) | ❌ |
| F7 | `loadFile` of a **missing** file | returns `""` silently; script survives (`XWT|F7b-survived`) ✅ |
| F7 | re-poll the same name **25 s after the file was externally created** (created 11:12:30.957, poll 11:12:39) | still `""` — **negative results are cached per path for the process lifetime** (`XWT|F7-loadFile-missing|second-poll-after-create|` empty) |
| F5 | `compile preprocessFileLineNumbers` re-read | same lock class — hot code reload impossible |

**Model:** OA 1.64's file layer resolves each path **once per process**; success pins the bytes + an OS write/delete lock, a miss pins `""`. Both are forever (until the server exe restarts; likely scoped to the process, so slot names must also be unique **across mission restarts** — use timestamps).

### B3. The surviving inbound pattern — one-shot slotted files

Writer (box-side producer) and reader (server SQF loop) agree on a **monotonic filename sequence**, e.g. `wasp_in_20260720T1145_000123.txt` in the **Arma 2 OA root dir** (works even when the mission runs from a `.pbo`, since B1/F3 needs no mission-folder write):

1. The writer **creates each slot file ahead of its scheduled read**, with the inbound payload (or an `EMPTY` marker); each name is used exactly once, ever.
2. The server loop polls each name **exactly once** at its slot time (`loadFile` → content or `""`), then never touches that name again.
3. Consumed slot files are undeletable while the server runs (B2) → they accumulate for the session and are cleaned at server restart. At one slot / 5 s that's ≈ 17k tiny files/day — acceptable, but the restart-cleanup script is part of the design.
4. The writer learns that slots were consumed via the one outbound channel that already exists: the RPT itself (server `diag_log`s an `INBOUND|v1|seq=<n>|status=...` line per slot; the producer tails the RPT — the same producer as PR #103).

**Consequences / open design points for the later two-way PR (default-0 flag):**

- **Latency** = slot cadence (seconds), not polling speed. Clock alignment between writer schedule and server loop must tolerate drift (writer stays ≥ 2 slots ahead; server treats `""` as "no payload this slot").
- **No flow control** beyond slot bookkeeping; a writer restart must resume from timestamped names, never reuse.
- **Security:** payload is data, never `compile`d (same RCE lesson as `SEND_MESSAGE`). If commands are ever needed, whitelist-parse tokens, never `call compile` file content.
- Alternative considered and rejected by the owner constraints: BE/RCon (excluded), `callExtension` DLL (excluded), client-side clipboard tricks (client-bound, not a server channel).

## C. Wiki-ready addendum (for `Arma-2-OA-Command-Version-Reference`, engine-verified section)

> - `loadFile` (OA 1.64): resolves mission-dir, mission-subdir and **game-root** relative paths (no `-filePatching` required); absolute paths return `""`. Missing file → `""`, no script error. **Per-path one-shot semantics:** after a successful read the file is OS-locked (no write/copy/rename/delete) for the process lifetime; a miss is negative-cached forever (later file creation is invisible). `preprocessFileLineNumbers` shares the lock class — no hot reload.
> - Chat capture (OA 1.64): chat display = IDD **24**, edit control = IDC **101**; a `KeyDown` display EH fires before the engine consumes Enter (28/156), `ctrlText` then holds the submitted line; return `false` to leave chat untouched.

## D. Evidence index

- Probe mission: `MPMissions/XWTChat.Desert_E` (init.sqf carries the full probe set, `XWT|`-tagged).
- Server RPT (run 3): `Temp\xwt\profiles_server\arma2oaserver.RPT` — 300× F1/F5/F6 iterations unchanged under live rewrite attempts; F7 sequence quoted above.
- Client RPT: `Temp\xwt\profiles_client\ArmA2OA.RPT` — C10/C20/C21/C22 display + IDC evidence.
- Writer-failure evidence: PowerShell exception transcripts (`WriteAllText`, `Copy`, `Move-Item` sharing violations), flipper tally `wins=0 fails=40`.
- Producer verification transcripts (offset tail, partial-line hold, FullScan, POST payload): `Temp\xwt\chatprod\` + PR miksuus-website-discord-bot#103 body.
