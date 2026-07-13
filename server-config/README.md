# server-config — live server / headless-client configuration (source of truth)

These files are the **live WASP server + headless-client configuration**, captured from the
production box (the live host, `C:\WASP\`) on 2026-07-02. They are versioned here so a
box rebuild, migration, or wipe can restore the exact working setup instead of falling back to
Arma 2 OA defaults.

> **Secrets are redacted.** `server-pr8.cfg`'s `passwordAdmin` is replaced with
> `__REDACTED_SET_ON_BOX__`. The real value lives ONLY on the box — never commit it. Restore it
> by hand on deploy. No other secret fields are present in these files.

## Files

| File | Box path | Purpose |
| --- | --- | --- |
| `basic.cfg` | `C:\WASP\profiles-pr8\basic.cfg` | Network tuning (`-cfg`) |
| `server-pr8.cfg` | `C:\WASP\profiles-pr8\server-pr8.cfg` | Server config (`-config`) — **passwordAdmin redacted** |
| `hc_launch.cmd` | `C:\WASP\hc_launch.cmd` | Headless client 1 launcher |
| `hc2_launch.cmd` | `C:\WASP\hc2_launch.cmd` | Headless client 2 launcher (Sandboxie-isolated 2nd Steam) |

## Why this matters — the load-bearing settings

- **`MaxSizeGuaranteed = 512`** in `basic.cfg` is the fix for the permanent-black
  "Receiving mission" JIP failure (a prior value of 1024 caused JIP message fragmentation). If a
  rebuild reverts this to the engine default, the black-screen-on-join incident returns. This is
  the single most important line to preserve.
- Companion network values: `MaxMsgSend = 512`, `MaxSizeNonguaranteed = 512`,
  `MinBandwidth = 131072`, `MaxBandwidth = 104857600`, `MinErrorToSend = 0.005`,
  `MaxCustomFileSize = 0`.
- **HC launch lines** carry `-mod=...;@CBA_CO;@adwasp;@admkswf` — `@adwasp` bundles ASR AI, which
  is locality-scoped, so AICOM combat teams (100% HC-local) only get ASR AI behavior because the
  HC mod line includes it. Do not drop `@adwasp` from the HC line. CBA must precede `@adwasp`.
- HC allocator: `-malloc=tbb4malloc_bi` (the DLL is present in `…\Arma 2 OA\Dll\`); the dedicated
  server itself runs `-malloc=mimalloc`. Both custom allocators are engaged.
- `headlessClients[] = {"127.0.0.1"}` + `localClient[] = {"127.0.0.1"}` register the two local
  HCs. `verifySignatures = 0` and `BattlEye = 0` are intentional (optional client mods permitted).
- **Hardening caveat — this file is the box-rebuild source of truth (see top).** `verifySignatures = 0`, `BattlEye = 0`, and `kickDuplicate = 0` are scoped to this optional-mods **test** box. Before reusing this config for any **public / competitive / hardened** deployment, restore `verifySignatures = 2` and `BattlEye = 1` (as in the secure `Configs/serverconfig.cfg` sample). The `passwordAdmin` redaction policy above still applies.

## Not versioned here (box-only)

`hc-profile\hc-video.cfg`, the Sandboxie box definition for HC2, Steam credentials, and the
`min*_launch.cmd` variants. The mission PBOs are produced by `Tools/LoadoutManager`, not stored here.

## ACR asymmetric / client-HC-only mount (terrain test path)

The live topology (as of 2026-07-11 preflight) runs the dedicated server **without** the ACR mod while both HCs carry `;ACR;` in their `-mod` lines (see `hc_launch.cmd`, `hc2_launch.cmd`). This is permitted because `server-pr8.cfg` has `verifySignatures = 0`.

- Server mod line (baked in Arma2OA-PR8 service): ends at `@admkswf` (no ACR).
- HC mod lines: `...;expansion;ACR;@CBA_CO;@adwasp;@admkswf` (full ACR present on clients/HCs only).

**Purpose for terrains**: the full ACR product includes terrain pbos `Woodland_ACR.pbo` (Bukovina) and `Mountains_ACR.pbo` (Bystrica) plus `plants_e2.pbo`. These hard-crash `arma2oaserver.exe` when loaded server-side (even with real product key). Client/HC-only mount is the fallback experiment (see Fleet task `acr-terrain-client-only-mount` and game-pc-handoffs ACR-TERRAIN-CLIENTMOUNT-PREFLIGHT-20260711.md).

**Scope reality**: a dedi cannot host a mission on a world the server binary has not loaded. Client/HC-only ACR can never enable Bukovina/Bystrica *rotation maps*. It can however:
- Prove that full-product terrain pbos load cleanly on HC/client processes.
- Enable a **split-mount** for ACR *units* on stock terrains: server carries only the non-terrain ACR pbos (wheeled_acr, tracked_acr, characters_acr, weapons_acr for T72M4CZ + roster) while terrains stay HC/client-only.

**Test matrix (to be executed in restore-clean window after ACR-FULL steps 1-2 on box)**:
- a) Dedi no terrain pbos + HCs with full ACR: Zargabad mission, clean HC join, no ACR-terrain RPT errors.
- b) Split: non-terrain ACR pbos on dedi+HCs; exercise T72M4CZ/CAWheeled_ACR classes on stock map.
- c) Real client with full ACR joins (verifySignatures=0 expects no kick).
- Rollback: restore the .cmd files + service definition from this source + prior snapshots.

When the full server-side terrain path succeeds, this client-only config remains available for perf/optional reasons. Update this section with evidence (RPT excerpts, pbo hashes vs ACR-FULL-MANIFEST) after any run.
