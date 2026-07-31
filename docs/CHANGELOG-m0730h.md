# WASP m0730h — HC lobby lock armed (and Takistan finally on the current build)

Eighth build of 2026-07-30. One behaviour change, one rotation catch-up, three stale
comments corrected. Chernarus **and** Takistan both move to m0730h in the same restart
window, so the rotation is no longer split across builds.

---

## 1. HC lobby lock: ON

`WFBE_C_HC_LOBBY_LOCK` 0 → **1**.

A player joining during the cold-start window is now held in the deadspawn holding area —
invulnerable, captive, position-locked — until **both** headless clients have registered,
and sees `Server initialising - headless clients seating, N of 2...` while they wait. Then
they are released into the normal base-placement flow. Nobody enters play while AI
delegation is still cold.

What it is *not*: A2 OA gives a mission no hook on the engine's own role/slot screen, so
this does not stop anyone **picking** a slot — it stops them entering play. The two
engine-level locks are both unavailable on this box (`password` in server.cfg is read at
startup only and the running server holds the file open; `#lock`/serverCommand needs a
logged-in admin or BattlEye, and BattlEye is deliberately off here).

Headless clients cannot deadlock on it: an HC never runs `Init_Client.sqf` at all —
`initJIPCompatible.sqf` gates client init on `!isHeadLessClient` and hands the HC
`Headless\Init\Init_HC.sqf` instead. The gate is physically absent from the HC boot path,
so it cannot starve the very machines it waits for.

### The blocker that had to be fixed first

Arming went through a 13-agent adversarial review — four independent lenses (fail-open,
seated-count correctness, deadspawn-budget interaction, A2 language correctness), with every
finding handed to a second agent whose job was to *refute* it. Eight findings were raised,
two survived as blockers, and both pointed at the same thing:

**The timeout clock starts too early.** `Init_Server.sqf` ExecVMs the lock at :198. The
`waitUntil {commonInitComplete && townInit}` is at :225, and `MATCH|v1|START|` — the exact
marker `Start-Wasp-2HC.ps1` waits on before it launches *either* HC — is only logged at
:246. So the lock's clock has a head start over the entire HC launch sequence. At the old
90s default the lobby would open via the **timeout** branch rather than the **seated**
branch on ordinary cold starts: early joiners held for 90 seconds, and nothing gained.

`WFBE_C_HC_LOBBY_TIMEOUT` 90 → **150**, derived from measurement rather than guesswork. In
the live m0730g session the server RPT shows `HC-AI-Control-1` registering at mission time
≈3s and `HC-AI-Control-2` at ≈57s, so 150 carries about 2.6× margin over the observed worst
case.

Going past the ~120s deadspawn-transit invulnerability budget is safe **for this hold
specifically**, and the constant now says why: the client-side hold re-asserts
`allowDamage false` on every tick it holds you, and re-arms a fresh 120s watchdog on
release. The number must not be copied to any other hold lacking both guarantees.

### Comments corrected (no behaviour change)

The review proved three comments actively misleading, each of which would have cost the next
reader a wrong diagnosis:

- the expected-count constant still said "4 today" after this morning's drop to 2;
- the lock's own header still claimed all three terrains carry 4 forced CIV slots;
- `WFBE_C_HCREG_HEAL`'s trailing comment advertised "0=off (default)" when its actual
  fallback is **1 — armed**, by owner call on 2026-07-23. Anyone reading that tail would
  have gone looking for a registry healer that is in fact running every 60s.

---

## 2. Takistan is on m0730h

Until now the rotation was split: Chernarus on m0730g, Takistan still on m0728i — the build
whose four "Headless Client" slots carried `forceHeadlessClient` on **none** of them. Both
entries are repointed in this one stop window, so a Takistan rotation now gets the 2-slot
CIV topology, the spectator fixes and the armed lock like Chernarus. The waiter task that
was standing by to swap Takistan alone has been retired to keep two writers off
`server-pr8.cfg`.

Zargabad is still out of the rotation and unpacked; its tree already carries every change
above for whenever it is next built.

---

## 3. How to tell it is working, and when to roll back

**Working** — on a fresh boot the server RPT should show:

```
HCLOBBY|v1|ARMED|expected=2|source=flag|timeout=150|delegation=2|open=false
HCLOBBY|v1|OPEN|reason=seated|seated=2|expected=2|at=<t>
```

`reason=seated` with `seated=2` is the proof. Players who joined during the window also get
a `CLIENT-HOLD` and a matching `CLIENT-RELEASE` line with how long they waited.

**Roll back** (set the flag to 0 and rebuild) if you see:

```
HCLOBBY|v1|OPEN|reason=timeout|seated=0|expected=2
```

That means the fail-open fired anyway — the hold cost joiners time and bought nothing.
Also roll back on any "released on the local Ns backstop (mission time stalled)" line, which
would indicate a much more serious problem than this feature, or if a player reports being
killed by AI in the deadspawn while a `CLIENT-HOLD` was active for their name.

---

## 4. Two follow-ups deliberately not bundled here

Both came out of the same review. Neither is safe to fold into a live build mid-playtest.

**a) A clock-drift race in the join path (pre-existing, confirmed).** The join-ACK gate in
`Init_Client.sqf` bounds its 120s failover with a hand-incremented counter
(`_totalWait += 0.1` per `sleep 0.1`), while the deadspawn invulnerability watchdog uses the
mission clock (`time - _t0 > 120`). Since `sleep` is a *minimum* wait, the counter
under-counts under load, so on a stalled join ACK the watchdog can restore damage while the
player is still stuck in that earlier loop — vulnerable, among the holding-area AI. Arming
the lock does not create this, but it does raise cold-start congestion in exactly that
window, so exposure is up.

**b) The HC launch gate never actually holds on this box.** `Start-Wasp-2HC.ps1` is supposed
to wait for `MATCH|v1|START|` before launching the HCs, but its 420s timeout is shorter than
this hardware's ~540s to that marker, so the wait always expires and the legacy fixed 45s
settle fires instead (provable from the restart log: step 4 took 566s = 420 + 45 + 40 + 60).
That is why the HCs connected *before* the mission went live and why
`HCSIDE|v1|preseat|name="HC-AI-Control-1"|engineSide=WEST` still shows an HC taking a BLUFOR
slot before the mission reseats it to CIV. Fixing it is coupled to this build: gate the HC
launch properly and the HCs will register at mission time ~150-200s instead of ~3-57s, which
would make even the new 150s timeout fail open. The durable fix is to re-anchor the lock's
clock to `MATCH|v1|START` and raise both numbers together.
