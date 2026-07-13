# BattlEye Enablement — Setup Notes & Test-Box Status (2026-07-12)

This documents how to turn on BattlEye + the filters in this folder, and the current
blocking finding on the Hetzner test box (`<test box public IP>`, service `Arma2OA-PR8`).
See `README-anticheat.md` for the filter design/tuning workflow itself.

## Enablement steps (when safe to do — see blocker below)

1. Confirm the server's active BattlEye engine-module path. On the test box this is the
   folder directly beside the game exe: `<Arma 2 OA install>\BattlEye\` (root — **not**
   `Expansion\BattlEye` and **not** an `-bepath` override; both were tried historically and
   do not get loaded by the dedicated server for the DLL lookup). Confirm `BEClient.dll` +
   `BEServer.dll` are present there and are a matched pair.
2. Copy `publicvariable.txt` and `scripts.txt` from this folder into that same active
   `BattlEye\` directory (same location as the DLLs — BE auto-loads filter `.txt` files by
   name, no separate registration needed).
3. Take a dated backup of the live `server-pr8.cfg` before editing it.
4. Set `BattlEye = 1;` in `server-pr8.cfg`.
5. Config changes need a full server (re)start to take effect — gate any restart on an
   empty server (no players on either side) and use the box's service-restart task, never a
   bare service/process start (it stops the server without bringing the two headless
   clients back up in sequence).
6. Verify post-restart: clean boot to a running state, both headless clients reattach and
   stay attached (not just connect-then-drop), BE reports initialized, and an idle server
   produces no unexpected kick/restriction spam over an extended window.

## Current status on the test box — NOT enabled, and should stay that way for now

`server-pr8.cfg` on the box currently reads `BattlEye = 0;` with an inline comment left by a
prior session: BE was enabled once (build "rc22"), and the BE client handshake killed both
headless clients, so it was reverted the same day. This matches a documented, actively-worked
investigation from the preceding week:

- The **server-side** BE init/freeze issue (BE deleting or failing to find its own DLL at
  boot) **is solved** — the fix is the DLL-location detail in step 1 above.
- The **headless-client-under-BE** problem is **not solved**. Every headless-client launch
  path tried so far either skips the BE handshake entirely (server then holds the HC as "no
  identity" and drops it) or fails to launch at all under the BE-aware launcher. Multiple
  candidate fixes were identified but not yet verified working.
- **A real account-level risk was flagged during that investigation and has not been
  cleared**: historical BattlEye policy treats more than one headless client under BE per
  server as bannable, and this server runs two. Whether that enforcement is still live on
  the EOL A2OA BE master is unknown — the risk is at the Steam-account level, not just
  "the test restarts," so it is not something to trial-and-error casually.

**Net effect:** flipping `BattlEye = 1` on this box today would very likely reproduce the
same headless-client drop it did before, and carries an unresolved, owner-flagged ban-risk
question on top of that. This is a materially different and more serious problem than filter
tuning (log-only vs. armed) — it exists independent of anything in `publicvariable.txt` /
`scripts.txt`.

## What's staged vs. what's not

- **Staged (safe, inert while `BattlEye = 0`):** this recovered filter payload is ready to
  drop into the active BattlEye folder the moment the headless-client blocker above is
  resolved and the owner clears the account-risk question.
- **Not done in this pass:** `BattlEye = 1` was **not** set on the box, and no server
  restart was performed. The box's existing headless-client-under-BE investigation
  (fixes ranked and queued for a future attempt) should be finished — and the ban-risk
  question explicitly answered — before the next attempt, rather than re-discovering the
  same failure mode.

## Filter whitelist staleness (log-only, so not a safety issue — a tuning note)

The recovered `publicvariable.txt` whitelist was authored against the mission code as of
late June. The mission has since added roughly two dozen more legitimate client↔server
channels. Under the shipped **log-only** posture this only means some current legitimate
traffic will show up in the log as "not yet whitelisted" — it will **not** be kicked. Before
this filter is ever armed (catch-all `1` → `5`), run the tuning pass described in
`README-anticheat.md` against a session on **current** code, not just against the original
June whitelist, so the newer channels get added.

## 1.0 posture recommendation

- Keep `BattlEye = 0` on this test box until the headless-client-under-BE question is
  resolved and the account-ban risk is explicitly cleared by the owner (and ideally
  cross-checked with Miksuu — see below).
- The repo's committed public-1.0 posture (`BattlEye = 0`, set by PR #1076) should stay as
  it is; this change set only carries the filter payload and documentation, it does not
  change that posture.
- For real parity with Miksuu's main server, request his exact filter files and, just as
  importantly, how his headless clients (if any) run under BattlEye — that's the variable
  most likely to explain why BE works there and not here. Do not attempt to reach his server
  directly to find out; ask him for the specifics.
