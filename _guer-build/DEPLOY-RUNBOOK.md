# GUER Insurgents — Deploy & Shakedown Runbook (2026-06-16)

Build: branch `feat/guer-insurgents-faction` (pushed). Worktree `C:/Users/Steff/a2wasp-guer`.
Mission: `Missions/[55-2hc]warfarev2_073v48co.chernarus` — **deploy-complete** (version.sqf carried in).
Gate: lobby param **WFBE_C_GUER_PLAYERSIDE** — set to **Enabled** for the test (default is OFF).

> A WASP mission only fully boots when a HUMAN joins a slot. So a test ALWAYS needs you in a GUER slot —
> there is no purely-headless gameplay validation. Headless can only confirm the mission LOADS without script errors.

---
## OPTION A — Local LAN host (FASTEST, no blockers, ~5–10 min) ⭐ recommended for a pre-meeting smoke
You have A2OA installed locally. This sidesteps the Hetzner access wall entirely.
1. Copy the mission folder into your local MP missions:
   `Documents\ArmA 2\MPMissions\[55-2hc]warfarev2_073v48co.chernarus`  (copy the WHOLE folder incl. version.sqf)
2. Launch Arma 2: Combined Operations with mods `@CBA_CO;@adwasp;@admkswf` (your usual WASP launch).
3. Multiplayer → New → host LAN/internet → pick the mission.
4. In the lobby PARAMETERS: set **GUER Insurgents (playable faction) = Enabled**.
5. Start → pick a RESISTANCE/GUER slot (Engineer / Sniper / Medic).
6. SHAKEDOWN CHECKS (see list below).
> version.sqf currently has WF_DEBUG ON → instant 900k funds + all tiers unlocked = you can buy the Ka-137 and
> every GUER vehicle immediately to exercise them fast. Good for a smoke; NOT representative of the real economy.

---
## OPTION B — Hetzner box (78.46.107.142) — you must drive it; I can't reach it autonomously
WHY I can't: OpenSSH won't pass the password non-interactively; Posh-SSH gets KEX-dropped by the box's newer SSH;
no plink; key path needs credential-dir access I'm not allowed. You have RDP set up (cmdkey stored on Main PC).
NOTE: this box currently runs **Miksuu's NEXT / AI-commander** tests with scheduled tasks + auto-start + HCs.
Dropping a GUER mission means a manual launch in a free window — don't clobber a live round.

1. RDP in: `mstsc /v:78.46.107.142` (Administrator). After any reboot: `tscon 2 /dest:console` first.
2. Get the mission onto the box WITH version.sqf. Either git-fetch the branch and carry version.sqf, OR zip the
   worktree mission folder and copy it via the RDP drive into MPMissions. (git pull alone won't bring version.sqf
   — it's gitignored; carry it from the worktree.)
3. Stop whatever's running; launch the dedicated server pointed at this mission (proven line, NO -profiles/-name):
   `arma2oaserver.exe -port=2302 -config=C:\WASP\profiles-pr8\server-pr8.cfg -cfg=C:\WASP\profiles-pr8\basic.cfg "-mod=C:\Program Files (x86)\Steam\steamapps\common\Arma 2;expansion;ca;@CBA_CO;@adwasp;@admkswf" -world=empty -nosplash -noPause`
   (run via the /it scheduled task so it lands in the interactive session). BattlEye is OFF on this box by design.
4. Join from your client, enable the GUER param in lobby, pick a GUER slot, run the shakedown checks.
5. RPT (errors): window from the LAST `MISSINIT` line — the box RPT spans many boots, whole-file greps lie.

---
## SHAKEDOWN CHECKS (what to verify — these are the bug-prone spots)
- [ ] Mission LOADS, no "Wait for host" hang, no red script errors on join.
- [ ] You spawn WITH gear (not naked) — the CRITICAL bug we fixed; verify all 3 roles (Eng/Sniper/Medic).
- [ ] GUER funds tick up over time (stipend 150/min; rises as towns are lost).
- [ ] Buy menu opens and shows the GUER pool (technicals now; BRDM @30m, T-55 @90m, T-72 @3h — debug ON unlocks all).
- [ ] Ka-137 buyable + flyable; EASA loadout swap works; **pilot can manually fire** the MG / AT / AA loadouts.
      ⚠ confirm the stock-MG mag classname (in-game: it just works, or check RPT); AT9/Igla fire geometry on the
      recon airframe — if missiles fire from origin, fall back to 57mm rockets.
- [ ] Markers: you (GUER) see your side; W/E factions unaffected.
- [ ] Telemetry: PLAYERSTAT rows for GUER show side=3 + |td= (towns-denied) — box-side dashboard parser still TODO.

## KNOWN DEFERRED (won't block the test; see JOURNAL Discovered Issues)
- GUER lobby slots not auto-hidden when the gate is OFF (fix server-side later; irrelevant with gate ON).
- Takistan port NOT started (resistance there = TKGUE, not PMC; ~4 steps scoped in JOURNAL).
