# BattlEye Filters — WASP Warfare Anti-Cheat (Layers 1 & 2)

These filters are the **engine-level, zero-server-cost** layer of the anti-cheat. BattlEye
evaluates them in native code, so they cost nothing on the SQF scheduler / server FPS.

## Files

| File | Scans | Posture as shipped |
|------|-------|--------------------|
| `publicvariable.txt` | the **name** of every public variable a **client** broadcasts | **log-only** default-deny + 38-channel whitelist; `kickAFK` feature rule kept armed |
| `scripts.txt` | the **text** of every script a **client** compiles/executes | `0` default (no-op) + **armed kicks** for 5 verified A3/cheat signatures + **log-only** for dual-use commands |

## Action codes (verified)

`0` = no action · `1` = log to file · `2` = log to console · `3` = log to both ·
`4` = kick (no log) · `5` = kick + log file · `6` = kick + log console · `7` = kick + log both.

Matching is **substring** and **case-insensitive**. `!="exact"` is an exact-match exception;
`!"sub"` is a substring exception.

## Why log-only on `publicvariable.txt`

The mission has **38 legitimate client→server channels** plus whatever the engine and any
loaded mods (CBA_A2, JSRS, etc.) legitimately broadcast. An *armed* default-deny (`5 ""`)
without a full whitelist would mass-kick real players. So the catch-all ships as `1` (log).

## Tuning workflow → arming enforcement

1. Deploy these files to the server's BattlEye path (see below). Leave the catch-all at `1`.
2. Run **one full, populated session** (include construction, respawn, supply use, ICBM,
   commander actions — the legitimate paths that look like cheats).
3. Read `publicvariable.log` and `scripts.log` in the BE working directory.
4. For every line that is a **legitimate** channel/script not already excepted, add an
   exception: `!="ChannelName"` (publicvariable) or `!"unique-substring"` (scripts).
5. Once a full session produces **no legitimate hits**, change the `publicvariable.txt`
   catch-all from `1 ""` to `5 ""` to arm kick-on-forged-PV. Raise individual `scripts.txt`
   dual-use lines to `5`/`7` the same way, each with its legitimate-use exceptions.

> Do **not** arm before a clean tuning session. A false positive here kicks paying players.

## Deployment / BEpath caveat

- BattlEye must be enabled on the server (`BattlEye=1` in the server cfg) and the server must
  load filters from its configured `BEpath` (the folder next to `server.cfg`, or the path
  given by the `-bepath` launch parameter).
- **The live production server may already load BE filters from an external path not tracked
  in this repo.** Confirm the production `BEpath` before assuming these files are active.
  Treat this repo copy as the canonical, version-controlled source to deploy.
- **Do not remove the `kickAFK` rule** — it is live AFK-kick feature plumbing, not security.

## Optional follow-up filters (not shipped here)

Add as separate tuning efforts once the two above are armed:
- `createvehicle.txt` — filter spawned classnames (log-only first; WASP construction spawns
  many legitimate classes).
- `setvariable.txt` — filter broadcast `setVariable` names (e.g. `wfbe_funds`).
- `setpos.txt` / `setdamage.txt` / `deletevehicle.txt` — per-command teleport/god-mode/grief filters.

These complement, but do not replace, the **server-side authority** fixes (Layers 3, 5b, 6)
in the mission code, which are the durable fix. BattlEye is defense-in-depth.
