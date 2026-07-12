# Live-config snapshot — 2026-07-12

Captured by the SPOF/backup automation described in `LAUNCH-PLAYBOOK-2026-07.md` Section 5.2
(Fleet vault: `W:\Mijn vualt\Fleet\Docs\LAUNCH-PLAYBOOK-2026-07.md`), gate G3. This is a dated,
point-in-time pull from the live box's off-box backup chain (box → Game PC → Main PC → this repo),
not the hand-maintained `server-config/{basic.cfg,server-pr8.cfg}` at the parent path (which is a
curated, redacted reference copy last refreshed 2026-07-02 — see its own README).

## Secret scan

Both files pulled from the box on 2026-07-12 were scanned with
`Select-String -Pattern 'password|rcon|token' -CaseSensitive:$false` before anything was staged
for commit.

| File | Scan result | Included here? |
| --- | --- | --- |
| `basic.cfg` | No match | Yes — included in this folder, byte-identical to the box copy |
| `server-pr8.cfg` | 1 match — key `passwordAdmin` present (line 3) | **No — excluded.** Value never viewed/logged/echoed; only the key name is recorded here. |

`server-pr8.cfg` is intentionally **not present** in this dated snapshot folder. The daily
off-box backup chain (Game PC `C:\Users\Game\wasp-config-backups\2026-07-12\` → Main PC
`C:\Users\Steff\wasp-config-backups\2026-07-12\`) still retains it locally on both machines —
outside git — as the actual disaster-recovery copy; only the repo-committed layer excludes it.

Note for the owner: the parent `server-config/server-pr8.cfg` reference copy already
established a different convention (redact `passwordAdmin` to `__REDACTED_SET_ON_BOX__` and keep
the file). This dated snapshot instead excludes the file outright, per this task's explicit
instruction. Worth reconciling the two approaches — redact-and-include may be preferable long
term since it lets `server-pr8.cfg`'s non-secret settings (MaxSizeGuaranteed, hardening flags,
etc.) be diffed dated snapshot over dated snapshot.

## Provenance

- Box path: `C:\WASP\profiles-pr8\basic.cfg` (Hetzner livehost, IP redacted — see private ops runbook)
- Pulled via: Game PC `WaspCfgBackup` scheduled task (daily 03:30) → Main PC `PullWaspCfgBackup`
  scheduled task (daily 04:00)
- basic.cfg size at capture: 286 bytes
